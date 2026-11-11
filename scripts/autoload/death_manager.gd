extends Node
## Ölüm / yeniden doğuş — karakter sıfırlanır; dünya kalır; checkpoint'e (yatak) dönüş.
## Faz: ALIVE → DYING → SOUL_RELEASE → SOUL_TRANSITION → RESPAWNING → ALIVE.
## Tek ölüm kilidi: is_dying true iken yeni ölüm isteği yok sayılır.

signal death_started(reason: StringName)
signal rebirth_completed
signal phase_changed(phase: int)

enum Phase { ALIVE, DYING, SOUL_RELEASE, SOUL_TRANSITION, RESPAWNING }

const SOUL_COLOR := Color(0.88, 0.82, 1.0, 0.62)
const SOUL_GLOW := Color(0.72, 0.55, 1.0, 0.38)
## Normal ölümde Noroi bulunduğu aktif odanın güvenli checkpoint/spawn noktasında doğar;
## yalnızca Uyanış odasındayken (Oda 01) rebirth_bed (120, 280) noktasında doğar.
const REBIRTH_ROOM := &"awakening"
const REBIRTH_SPAWN := &"rebirth_bed"
const REBIRTH_BED := Vector2(120, 280)

var is_dying: bool = false
var phase: int = Phase.ALIVE
## Bu ölüm ilk ölüm mü (sinematik, uzun); sonrakiler hızlı.
var cinematic: bool = false
var _soul: Node2D = null
## Tek sahip: hitstop ve ölüm ağır çekimi bu listede. Süre dolunca veya bırakılınca ölçek 1.0.
var _time_holds: Array = []
var _time_token: int = 0
var _scene_root: Window = null
## Yeni oyun / başlığa dönüş sırasında uçuştaki ölüm coroutine'i bayatlar: her sıfırlamada artar,
## await sonrası eşleşmeyen coroutine yeni oyuna dokunmadan çıkar (BUG-001).
var _gen: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene_root = get_tree().root
	_scene_root.child_exiting_tree.connect(_on_root_child_exiting)


func _process(_delta: float) -> void:
	if _time_holds.is_empty():
		if not is_equal_approx(Engine.time_scale, 1.0):
			Engine.time_scale = 1.0
		return
	_apply_time_holds()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_time_scale()


func _on_root_child_exiting(node: Node) -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene != null and node == scene:
		release_time_scale()


func _exit_tree() -> void:
	if _scene_root and _scene_root.child_exiting_tree.is_connected(_on_root_child_exiting):
		_scene_root.child_exiting_tree.disconnect(_on_root_child_exiting)
	_scene_root = null
	_time_holds.clear()
	Engine.time_scale = 1.0


## Yeni oyun / başlığa dönüş: ölüm durumunu temiz bırakır, uçuştaki ölüm coroutine'ini bayatlatır.
func reset_state() -> void:
	_gen += 1
	is_dying = false
	phase = Phase.ALIVE
	_free_soul()
	release_time_scale()


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func phase_name() -> String:
	return Phase.keys()[phase]


func request_death(reason: StringName = &"unknown", full_reset: bool = false) -> void:
	## Lanet ele geçirmesi sürerken ölüm başlamaz (çukur/hasar yarışı; ceset + yatak oluşmaz).
	if is_dying or CurseManager.possessing or EndingManager.current != EndingManager.Ending.NONE:
		return
	## Önceki hitstop, ölüm ağır çekiminin üstünde asılı kalmasın.
	release_time_scale()
	is_dying = true
	var gen := _gen
	_set_phase(Phase.DYING)
	cinematic = not bool(GameState.player_progress_knowledge.get("first_death_seen", false))
	death_started.emit(reason)
	MobileInputManager.vibrate(45)

	var death_pos := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		if (reason == &"hazard" or reason == &"thorn" or reason == &"pit" or reason == &"void") and player.has_method("get_last_safe_floor_pos"):
			var safe: Vector2 = player.get_last_safe_floor_pos()
			death_pos = safe if safe != Vector2.ZERO else player.global_position
		else:
			death_pos = player.global_position
		if player.has_method("play_death"):
			player.play_death()

	GameState.player_progress_knowledge["deaths"] = int(GameState.player_progress_knowledge["deaths"]) + 1
	GameState.player_progress_knowledge["first_death_seen"] = true

	# Ceset dünya hafızasına — karakter bilgisi henüz sıfırlanmadan konum alınır.
	var corpse_id := CorpseManager.record_corpse_at(death_pos, reason)

	GameState.reset_character_life()
	# Karakter bu hayatı unutur; dünya bayrakları durur.
	knowledge_note_after_death(reason)

	if full_reset:
		# Yalnız özel sonlar — FAZ 4'te kullanılmaz.
		pass

	SaveManager.save_game()
	await _death_presentation()
	if gen != _gen:
		return
	## DYING: beden çöker (ilk ölüm daha uzun).
	await _wait(1.1 if cinematic else 0.55)
	if gen != _gen:
		return

	## SOUL_RELEASE: beden ceset olarak kalır, ruh yükselir; kamera ruhu izler.
	_set_phase(Phase.SOUL_RELEASE)
	if player:
		player.visible = false
	_spawn_soul(death_pos)
	await _rise_soul(1.5 if cinematic else 0.7)
	if gen != _gen:
		return
	# Bekçi yas: çiçek bırakabilir (öldürmez). Ruh bu sırada bedenin üstünde bekler.
	var keeper := get_tree().get_first_node_in_group("keeper")
	if keeper and keeper.has_method("mourn_corpse"):
		await keeper.mourn_corpse(death_pos, corpse_id)
		if gen != _gen:
			return
	if DialogueManager.is_open:
		DialogueManager.clear()

	await _respawn(gen)


## Aktif tutuş yoksa ölçek 1.0. Sahne, ölüm sonu, diriliş, duraklatma ve lanet bitişi bunu çağırır.
func release_time_scale() -> void:
	_time_holds.clear()
	_time_token += 1
	Engine.time_scale = 1.0


func _skip_time_holds() -> bool:
	## Headless smoke akışı beklemez. TORIMON_TIME_HOLDS=1 gerçek tutuşu ölçer.
	if OS.get_environment("TORIMON_TIME_HOLDS") == "1":
		return false
	return _fast_mode()


## Tutuşu başlatır (senkron). Süre bitince ölçek, kalan tutuş yoksa 1.0 olur. Token, atlanırsa -1.
func begin_time_hold(scale: float, real_sec: float) -> int:
	if _skip_time_holds():
		release_time_scale()
		return -1
	_time_token += 1
	var token := _time_token
	var dur := maxf(real_sec, 0.0)
	_time_holds.append({
		"token": token,
		"until": Time.get_ticks_msec() + int(dur * 1000.0),
		"scale": clampf(scale, 0.02, 1.0),
	})
	_apply_time_holds()
	if dur > 0.0:
		get_tree().create_timer(dur, true, false, true).timeout.connect(_end_time_hold.bind(token), CONNECT_ONE_SHOT)
	else:
		_end_time_hold(token)
	return token


func _end_time_hold(token: int) -> void:
	_remove_time_hold(token)
	_apply_time_holds()


## scale 1'in altında, real_sec gerçek saniye. Coroutine iptal olsa da zamanlayıcı ölçeği 1'e döndürür.
func hold_time_scale(scale: float, real_sec: float) -> void:
	var token := begin_time_hold(scale, real_sec)
	if token < 0 or real_sec <= 0.0:
		return
	await get_tree().create_timer(maxf(real_sec, 0.0), true, false, true).timeout
	_end_time_hold(token)


func _remove_time_hold(token: int) -> void:
	var kept: Array = []
	for h in _time_holds:
		if int(h.get("token", -1)) != token:
			kept.append(h)
	_time_holds = kept


func _apply_time_holds() -> void:
	var now := Time.get_ticks_msec()
	var kept: Array = []
	for h in _time_holds:
		if int(h.get("until", 0)) > now:
			kept.append(h)
	_time_holds = kept
	if kept.is_empty():
		Engine.time_scale = 1.0
		return
	## En son başlayan tutuş ölçeğin tek sahibi (iç içe hitstop / ölüm birbirini silmez, süre bitince 1.0).
	Engine.time_scale = float(kept[kept.size() - 1]["scale"])


func _death_presentation() -> void:
	if _fast_mode():
		return
	var cam := _camera()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(1.0)
	_flash_red_vignette()
	await hold_time_scale(0.35, 0.3)


func _flash_red_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "DeathVignette"
	var rect := ColorRect.new()
	rect.name = "Flash"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.WHITE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5));\n\tfloat vig = smoothstep(0.2, 0.78, d);\n\tCOLOR = vec4(0.62, 0.02, 0.05, vig);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	rect.modulate = Color(1, 1, 1, 0)
	layer.add_child(rect)
	add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.04)
	tw.tween_property(rect, "modulate:a", 0.0, 0.2)
	tw.tween_callback(layer.queue_free)


func _fast_mode() -> bool:
	return OS.get_environment("TORIMON_SMOKE") == "1" or DisplayServer.get_name() == "headless"


func _wait(sec: float) -> void:
	await get_tree().create_timer(0.02 if _fast_mode() else sec).timeout


func _d(sec: float) -> float:
	return 0.02 if _fast_mode() else sec


## Ölüm sahnesi diyaloğu: dokunuşla geçilir; geçilmezse sayfa kendiliğinden ilerler,
## süre dolunca kapanır. Ölüm akışı hiçbir diyalogda kilitlenmez.
func wait_dialogue(max_sec: float = 7.0, auto_advance_sec: float = 2.4) -> void:
	if _fast_mode():
		await get_tree().create_timer(0.1).timeout
		if DialogueManager.is_open:
			DialogueManager.clear()
		return
	var total := 0.0
	var idle := 0.0
	var last_text := ""
	while DialogueManager.is_open and total < max_sec:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		total += dt
		var t := DialogueManager.visible_page_text()
		if t != last_text or DialogueManager.is_typing():
			last_text = t
			idle = 0.0
		else:
			idle += dt
			if idle >= auto_advance_sec:
				idle = 0.0
				DialogueManager.advance()
	if DialogueManager.is_open:
		DialogueManager.clear()


func knowledge_note_after_death(reason: StringName) -> void:
	# Meta katmanda ölüm nedeni izi (karakter bilmez).
	var touched: Array = GameState.world_memory_state["forbidden_touched"]
	var key := "death:%s" % String(reason)
	if not touched.has(key):
		touched.append(key)


# ---------------- ruh ----------------

func _camera() -> Node:
	return get_tree().get_first_node_in_group("follow_camera")


## Soluk beyaz-mor, yarı saydam Noroi silüeti + ışıltı. Saldıramaz, kapı/bulmaca kullanamaz
## (yalnız görsel; çarpışması yok).
func _spawn_soul(pos: Vector2) -> void:
	_free_soul()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var soul := Node2D.new()
	soul.name = "Soul"
	soul.z_index = 40
	soul.global_position = pos
	var frames: SpriteFrames = null
	var flip := false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var ps := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ps:
			frames = ps.sprite_frames
			flip = ps.flip_h
	if frames == null and ResourceLoader.exists("res://assets/characters/noroi.tres"):
		frames = load("res://assets/characters/noroi.tres")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if frames:
		var glow := AnimatedSprite2D.new()
		glow.sprite_frames = frames
		glow.animation = &"idle"
		glow.offset = Vector2(0, -44)
		glow.scale = Vector2(1.12, 1.08)
		glow.flip_h = flip
		glow.modulate = SOUL_GLOW
		glow.material = add
		soul.add_child(glow)
		var body := AnimatedSprite2D.new()
		body.sprite_frames = frames
		body.animation = &"idle"
		body.offset = Vector2(0, -44)
		body.flip_h = flip
		body.modulate = SOUL_COLOR
		soul.add_child(body)
	var motes := CPUParticles2D.new()
	motes.amount = 14
	motes.lifetime = 1.2
	motes.position = Vector2(0, -30)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(9, 18)
	motes.direction = Vector2(0, -1)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -18)
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 12.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	motes.color = Color(0.85, 0.75, 1.0, 0.7)
	motes.material = add
	soul.add_child(motes)
	soul.modulate = Color(1, 1, 1, 0)
	scene.add_child(soul)
	_soul = soul
	var cam := _camera()
	if cam and cam.has_method("set_focus"):
		cam.set_focus(soul)


func _rise_soul(sec: float) -> void:
	if not is_instance_valid(_soul):
		return
	var tw := _soul.create_tween().set_parallel(true)
	tw.tween_property(_soul, "modulate:a", 1.0, _d(sec * 0.4))
	tw.tween_property(_soul, "global_position:y", _soul.global_position.y - 34.0, _d(sec)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _get_respawn_position() -> Vector2:
	var active_room := RoomManager.get_active_room_id()
	if active_room == &"awakening" or active_room == &"":
		return REBIRTH_BED
	if not RoomManager.has_room(active_room):
		return REBIRTH_BED
	var entry: Dictionary = RoomManager._rooms.get(active_room, {})
	var spawns: Dictionary = entry.get("spawns", {})
	var last_spawn_id: Variant = GameState.character_current_life_knowledge.get("spawn_id", &"default")
	if entry.has("checkpoint") and (entry["checkpoint"] as Vector2) != Vector2.ZERO:
		return entry["checkpoint"]
	elif last_spawn_id != null and last_spawn_id != &"rebirth_bed" and spawns.has(last_spawn_id):
		return spawns[last_spawn_id]
	elif spawns.has(&"default"):
		return spawns[&"default"]
	var b: Rect2 = entry.get("bounds", Rect2(0, 0, 640, 360))
	return Vector2(b.position.x + b.size.x * 0.5, 288.0)


## Ruh doğuş noktasına süzülür (aynı odada kalır, oda geçişi/yeniden yükleme yapılmaz).
func _soul_to_bed(target_cp: Vector2 = Vector2.ZERO) -> void:
	var cp := target_cp if target_cp != Vector2.ZERO else _get_respawn_position()
	_set_phase(Phase.SOUL_TRANSITION)
	var above := cp + Vector2(0, -38)
	if is_instance_valid(_soul):
		var dist := _soul.global_position.distance_to(above)
		var sec := clampf(dist / 260.0, 0.6, 1.6 if cinematic else 1.1)
		var tw := _soul.create_tween()
		tw.tween_property(_soul, "global_position", above, _d(sec)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished


## Yatak mührü: yerde parlayan halka + yükselen kıvılcımlar.
func _bed_seal_fx(cp: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fx := Node2D.new()
	fx.z_index = 39
	fx.global_position = cp
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.8, 0.65, 1.0, 0.9)
	ring.material = add
	for i in 33:
		var a := TAU * float(i) / 32.0
		ring.add_point(Vector2(cos(a) * 22.0, sin(a) * 6.0))
	fx.add_child(ring)
	var sparks := CPUParticles2D.new()
	sparks.amount = 24
	sparks.lifetime = 0.9
	sparks.one_shot = true
	sparks.explosiveness = 0.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(20, 3)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 20.0
	sparks.gravity = Vector2(0, -30)
	sparks.initial_velocity_min = 18.0
	sparks.initial_velocity_max = 42.0
	sparks.color = Color(0.9, 0.8, 1.0, 0.85)
	sparks.material = add
	fx.add_child(sparks)
	fx.scale = Vector2(0.3, 0.3)
	scene.add_child(fx)
	sparks.emitting = true
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector2(1.2, 1.2), _d(0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, _d(0.7))
	tw.tween_callback(fx.queue_free)


func _free_soul() -> void:
	if is_instance_valid(_soul):
		_soul.queue_free()
	_soul = null
	var cam := _camera()
	if cam and cam.has_method("clear_focus"):
		cam.clear_focus()


# ---------------- doğuş ----------------

func _respawn(gen: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cp: Vector2 = _get_respawn_position()
	var active_room := RoomManager.get_active_room_id()
	if is_instance_valid(_soul):
		await _soul_to_bed(cp)
		if gen != _gen:
			return
	elif active_room == &"awakening" and RoomManager.has_room(REBIRTH_ROOM):
		_set_phase(Phase.SOUL_TRANSITION)
		RoomManager.enter_room(REBIRTH_ROOM, REBIRTH_SPAWN, false)

	## RESPAWNING: mühür parlar, ruh bedene iner, Noroi uyanır.
	_set_phase(Phase.RESPAWNING)
	if player and player.has_method("respawn_at"):
		player.respawn_at(cp)
		player.visible = false
	_bed_seal_fx(cp)
	if is_instance_valid(_soul):
		var tw := _soul.create_tween().set_parallel(true)
		tw.tween_property(_soul, "global_position", cp, _d(0.35))
		tw.tween_property(_soul, "modulate:a", 0.0, _d(0.4))
		await tw.finished
		if gen != _gen:
			return
	_free_soul()
	if player and player.has_method("play_wake"):
		player.play_wake(_d(0.6))
	elif player:
		player.visible = true
	var cam := _camera()
	if cam and cam.has_method("snap_to_target"):
		cam.snap_to_target()
	await _wait(0.45 if cinematic else 0.25)
	if gen != _gen:
		return

	DialogueManager.clear()
	## Karakter unutkanlığı — ilk ölümde tam, sonra sessiz (hızlı döngü).
	if cinematic:
		DialogueManager.say("Noroi", "…Neredeyim?")
		DialogueManager.say("Noroi", "Bir şey… unuttum.")
		if _fast_mode():
			await get_tree().create_timer(0.05).timeout
			if gen != _gen:
				return
			if DialogueManager.is_open:
				DialogueManager.clear()
	CorpseManager.rebuild_world_corpses()
	GameState.set_story_flag(&"first_death_completed")
	GameState.character_current_life_knowledge["checkpoint"] = cp
	GameState.character_current_life_knowledge["checkpoint_room"] = active_room
	GameState.character_current_life_knowledge["room"] = active_room
	SaveManager.save_game()
	is_dying = false
	_set_phase(Phase.ALIVE)
	release_time_scale()
	## Doğuş laneti ele geçirme başlatmaz: +25, taban 50, tavan 99.
	## Aynı karede 100'e çıkmış değer burada yeniden ele geçirmeye dönmesin.
	var born := clampf(maxf(CurseManager.curse + 25.0, 50.0), 0.0, CurseManager.CURSE_MAX - 1.0)
	CurseManager.restore_curse(born)
	rebirth_completed.emit()
