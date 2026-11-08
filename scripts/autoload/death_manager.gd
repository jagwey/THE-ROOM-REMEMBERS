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

var is_dying: bool = false
var phase: int = Phase.ALIVE
## Bu ölüm ilk ölüm mü (sinematik, uzun); sonrakiler hızlı.
var cinematic: bool = false
var _soul: Node2D = null


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func phase_name() -> String:
	return Phase.keys()[phase]


func request_death(reason: StringName = &"unknown", full_reset: bool = false) -> void:
	if is_dying or EndingManager.current != EndingManager.Ending.NONE:
		return
	is_dying = true
	_set_phase(Phase.DYING)
	cinematic = not bool(GameState.player_progress_knowledge.get("first_death_seen", false))
	## Lanet ele geçirmesi ölümden ayrıdır: ceset, yas ve ruh yok.
	var possession := reason == &"curse"
	death_started.emit(reason)
	MobileInputManager.vibrate(45)

	var death_pos := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		if (reason == &"hazard" or reason == &"thorn") and player.has_method("get_last_safe_floor_pos"):
			death_pos = player.get_last_safe_floor_pos()
		else:
			death_pos = player.global_position
		if player.has_method("play_death"):
			player.play_death()

	GameState.player_progress_knowledge["deaths"] = int(GameState.player_progress_knowledge["deaths"]) + 1
	GameState.player_progress_knowledge["first_death_seen"] = true

	# Ceset dünya hafızasına — karakter bilgisi henüz sıfırlanmadan konum alınır.
	var corpse_id := ""
	if not possession:
		corpse_id = CorpseManager.record_corpse_at(death_pos, reason)

	GameState.reset_character_life()
	CurseManager.reset_for_new_life()
	# Karakter bu hayatı unutur; dünya bayrakları durur.
	knowledge_note_after_death(reason)

	if full_reset:
		# Yalnız özel sonlar — FAZ 4'te kullanılmaz.
		pass

	SaveManager.save_game()
	## DYING: beden çöker (ilk ölüm daha uzun).
	await _wait(1.1 if cinematic else 0.55)

	if not possession:
		## SOUL_RELEASE: beden ceset olarak kalır, ruh yükselir; kamera ruhu izler.
		_set_phase(Phase.SOUL_RELEASE)
		if player:
			player.visible = false
		_spawn_soul(death_pos)
		await _rise_soul(1.5 if cinematic else 0.7)
		# Bekçi yas: çiçek bırakabilir (öldürmez). Ruh bu sırada bedenin üstünde bekler.
		var keeper := get_tree().get_first_node_in_group("keeper")
		if keeper and keeper.has_method("mourn_corpse"):
			await keeper.mourn_corpse(death_pos, corpse_id)
		if DialogueManager.is_open:
			DialogueManager.clear()

	await _respawn()


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


## Ruh yatağa süzülür. Oda farklıysa söner, odaya geçilir ve yatağın üstünde yeniden belirir.
func _soul_to_bed(cp: Vector2, cp_room: StringName) -> void:
	_set_phase(Phase.SOUL_TRANSITION)
	var above := cp + Vector2(0, -38)
	var same_room := cp_room == RoomManager.get_active_room_id() or not RoomManager.has_room(cp_room)
	if same_room:
		if is_instance_valid(_soul):
			var dist := _soul.global_position.distance_to(above)
			var sec := clampf(dist / 260.0, 0.6, 1.6 if cinematic else 1.1)
			var tw := _soul.create_tween()
			tw.tween_property(_soul, "global_position", above, _d(sec)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw.finished
		if RoomManager.has_room(cp_room):
			RoomManager.enter_room(cp_room, &"checkpoint", false)
		return
	if is_instance_valid(_soul):
		var tw2 := _soul.create_tween()
		tw2.tween_property(_soul, "modulate:a", 0.0, _d(0.35))
		await tw2.finished
	RoomManager.enter_room(cp_room, &"checkpoint", false)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = cp
		player.visible = false
	var cam := _camera()
	if cam and cam.has_method("snap_to_target"):
		cam.snap_to_target()
	if is_instance_valid(_soul):
		_soul.global_position = above + Vector2(0, -26)
		var tw3 := _soul.create_tween().set_parallel(true)
		tw3.tween_property(_soul, "modulate:a", 1.0, _d(0.3))
		tw3.tween_property(_soul, "global_position", above, _d(0.6)).set_trans(Tween.TRANS_SINE)
		await tw3.finished


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

func _respawn() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cp: Vector2 = GameState.get_checkpoint()
	var cp_room: StringName = GameState.character_current_life_knowledge.get("checkpoint_room", &"awakening")
	if is_instance_valid(_soul):
		await _soul_to_bed(cp, cp_room)
	elif RoomManager.has_room(cp_room):
		_set_phase(Phase.SOUL_TRANSITION)
		RoomManager.enter_room(cp_room, &"checkpoint", false)
	elif cp_room != RoomManager.get_active_room_id():
		_set_phase(Phase.SOUL_TRANSITION)

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
	_free_soul()
	if player and player.has_method("play_wake"):
		player.play_wake(_d(0.6))
	elif player:
		player.visible = true
	var cam := _camera()
	if cam and cam.has_method("snap_to_target"):
		cam.snap_to_target()
	await _wait(0.45 if cinematic else 0.25)

	DialogueManager.clear()
	## Karakter unutkanlığı — ilk ölümde tam, sonra sessiz (hızlı döngü).
	if cinematic:
		DialogueManager.say("Noroi", "…Neredeyim?")
		DialogueManager.say("Noroi", "Bir şey… unuttum.")
		if _fast_mode():
			await get_tree().create_timer(0.05).timeout
			if DialogueManager.is_open:
				DialogueManager.clear()
	CorpseManager.rebuild_world_corpses()
	GameState.set_story_flag(&"first_death_completed")
	SaveManager.save_game()
	is_dying = false
	_set_phase(Phase.ALIVE)
	rebirth_completed.emit()
