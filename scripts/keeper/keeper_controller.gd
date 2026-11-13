extends CharacterBody2D

const LorePointScript := preload("res://scripts/world/lore_point.gd")
## Bekçi — senaryolu koruyucu. Klasik düşman değil. Erken oyunda öldürmez.

enum Mode { OBSERVE, WARN, INTERVENE, MOURNING, INTIMACY, COMBAT }

signal mode_changed(new_mode: Mode)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hint: Label = $HintLabel
@onready var blocker: StaticBody2D = $Blocker
@onready var blocker_shape: CollisionShape2D = $Blocker/CollisionShape2D

@export var home_position: Vector2 = Vector2(480, 280)
@export var silhouette_position: Vector2 = Vector2(580, 280)
@export var approach_speed: float = 95.0

var mode: Mode = Mode.OBSERVE
var _player: Node2D
var _busy: bool = false
var _block_enabled: bool = false
var _approach_target: Vector2 = Vector2.ZERO
var _intervening: bool = false
var _shadow_beat_running: bool = false
## Oda her değiştiğinde artar; bekleyen siluet beat'i / otomatik isim sahnesi eski nesil ise kendini iptal eder.
var _beat_gen: int = 0
var _auto_naming_running: bool = false
## Geç bölgelerde Shilda "present" ise ve ad hâlâ bilinmiyorsa isim sahnesi bir kez otomatik oynar.
## Sahne hiç çalışamıyorsa (ör. doğrudan core_final yüklemesi: Shilda gizli) son çare sessiz isimlendirme.
const NAME_FALLBACK_PREFIXES := ["experiment", "mirrors", "core"]
var _warn_counts: Dictionary = {}
var _strikes: int = 0
const STRIKES_TO_BAD := 3
## Oda başına Shilda varlığı: present (etkileşimli), silhouette (arka planda izler), yoksa gizli.
## Oda sahnesinde Spawns/keeper_observe (veya keeper_intervene / keeper_ambush) Marker2D varsa konum onu kullanır.
const ROOM_PRESENCE := {
	"awakening": {"mode": "hidden", "pos": Vector2(480, 280)},
	"awakening_vigil": {"mode": "present", "pos": Vector2(640, 280)},
	"decay_greenhouse": {"mode": "silhouette", "pos": Vector2(980, 280)},
	"library_clockroom": {"mode": "silhouette", "pos": Vector2(640, 280)},
	"library_reading_cell": {"mode": "hidden", "pos": Vector2(720, 280)},
	"experiment_intake": {"mode": "silhouette", "pos": Vector2(980, 280)},
	"mirrors_gallery": {"mode": "present", "pos": Vector2(900, 280)},
	"mirrors_1927": {"mode": "silhouette", "pos": Vector2(760, 280)},
	"core_ascent": {"mode": "present", "pos": Vector2(980, 280)},
	"awakening_passage": {"mode": "silhouette", "pos": Vector2(1150, 280)},
	"awakening_balcony": {"mode": "silhouette", "pos": Vector2(820, 280)},
	"decay_garden": {"mode": "present", "pos": Vector2(700, 280)},
	"decay_shilda_wall": {"mode": "present", "pos": Vector2(760, 280)},
	"library_witness": {"mode": "present", "pos": Vector2(702, 280)},
	"library_forbidden_wing": {"mode": "silhouette", "pos": Vector2(140, 280)},
	"experiment_authority": {"mode": "silhouette", "pos": Vector2(820, 280)},
	"experiment_quarantine": {"mode": "silhouette", "pos": Vector2(860, 280)},
	"experiment_observation": {"mode": "hidden", "pos": Vector2(860, 280)},
	"mirrors_unbroken": {"mode": "present", "pos": Vector2(700, 280)},
	"mirrors_shrine": {"mode": "silhouette", "pos": Vector2(820, 280)},
	"core_threshold": {"mode": "present", "pos": Vector2(760, 280)},
	"core_seal_chamber": {"mode": "present", "pos": Vector2(700, 280)},
	"core": {"mode": "present", "pos": Vector2(560, 280)},
	"core_memory_vault": {"mode": "silhouette", "pos": Vector2(820, 280)},
	"core_bloom_garden": {"mode": "present", "pos": Vector2(760, 280)},
}
var presence: String = "present"
var _saved_layer: int = 8

## --- Savaş (yalnız senaryolu karşılaşmalarda) ---
const CLAW_RANGE := 64.0
const CLAW_WINDUP := 0.45
const CHARGE_WINDUP := 0.6
const CHARGE_SPEED := 320.0
const CHARGE_MAX_DIST := 460.0
var _combat_phase: StringName = &"idle"
var _combat_timer: float = 0.0
var _charge_dir: float = 1.0
var _charge_travel: float = 0.0
var _combat_hit_done: bool = false
var _encounter_id: StringName = &""
## Oyuncu yeniden doğduktan sonra kısa süre saldırı yok (doğar doğmaz ölmesin).
var _attack_grace: float = 0.0
const REBIRTH_GRACE := 2.0
signal encounter_finished(encounter_id: StringName)
var _zone_lines: Dictionary = {
	&"forbidden": {
		"warn": ["Buradan uzak dur.", "Orası güvenli değil."],
		"intervene": ["Dur.", "Oraya gitme."],
	},
	&"exit": {
		"warn": ["Oraya gitme.", "Çıkış henüz sana kapalı."],
		"intervene": ["Geri dön.", "Henüz değil."],
	},
	&"curse": {
		"warn": ["Yaklaşma.", "Kırmızı ışık seni yer."],
		"intervene": ["Uzak dur.", "Lanet uyanmasın."],
	},
}


func _ready() -> void:
	add_to_group("keeper")
	_vigil_hook()
	sprite.sprite_frames = load("res://assets/characters/keeper.tres")
	sprite.offset = Vector2(0, -59) ## ayak alt kenari (opak satir 122, doku 128 yuksek, ortali) node y = zemin ust yuzu (288)
	hint.text = ""
	hint.visible = false
	UiTheme.apply_outlined(hint, UiTheme.HINT)
	_set_blocker(false)
	home_position = global_position
	_saved_layer = collision_layer
	GameState.world_memory_state["keeper_mood"] = &"observe"
	if not GameState.room_changed.is_connected(_on_room_changed):
		GameState.room_changed.connect(_on_room_changed)
	DeathManager.death_started.connect(_on_player_death_started)
	DeathManager.rebirth_completed.connect(_on_player_reborn)
	## Açılışta Shilda odada değil; ad söylenene dek kimliği "???" (GameState.keeper_speaker_name).
	global_position = silhouette_position
	modulate = Color(0.15, 0.12, 0.18, 0.85)
	sprite.play("observe")
	set_mode(Mode.OBSERVE)
	presence = "hidden"
	visible = false
	collision_layer = 0


func _on_room_changed(room_id: StringName) -> void:
	call_deferred("place_for_room", room_id)


## Shilda'yı aktif odaya yerleştir; senaryosu yoksa gizle veya silüet yap.
func place_for_room(room_id: StringName) -> void:
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	if is_defeated():
		_hide_defeated()
		return
	## Oda değişimi: bekleyen siluet beat'i / otomatik isim sahnesi iptal; yerleşimi asla engellemez.
	_beat_gen += 1
	_shadow_beat_running = false
	_auto_naming_running = false
	var rid := String(room_id)
	var def: Dictionary = ROOM_PRESENCE.get(rid, {"mode": "hidden", "pos": Vector2(480, 280)})
	## Uyanış yatağı yalnız iz. Yüz yüze karşılaşma nöbet odasında.
	if rid == "awakening":
		def = {"mode": "hidden", "pos": def["pos"]}
	if rid == "awakening_vigil" and bool(GameState.player_progress_knowledge.get("vigil_parted", false)):
		def = {"mode": "hidden", "pos": def["pos"]}
	var late_room := false
	for pre in NAME_FALLBACK_PREFIXES:
		if rid.begins_with(pre):
			late_room = true
			break
	if late_room and not GameState.is_shilda_named() and String(def["mode"]) == "hidden":
		GameState.set_shilda_named(true) ## son çare: sahne bu odada oynatılamaz
	var pos: Vector2 = def["pos"]
	var marker := _room_marker(room_id)
	if marker:
		pos = marker.global_position
	if mode == Mode.COMBAT:
		end_encounter(false)
	presence = String(def["mode"])
	home_position = pos
	_busy = false
	_intervening = false
	_set_blocker(false)
	collision_mask = 0
	hint.visible = false
	global_position = pos
	match presence:
		"present":
			visible = true
			z_index = 0
			collision_layer = _saved_layer
			modulate = Color(0.45, 0.4, 0.48, 0.75) if bool(GameState.player_progress_knowledge.get("keeper_withdrew", false)) else Color.WHITE
			_apply_bandage()
			call_deferred("_maybe_bandage_line")
		"silhouette":
			visible = true
			z_index = -1
			collision_layer = 0
			modulate = Color(0.12, 0.1, 0.16, 0.5)
		_:
			visible = false
			collision_layer = 0
	if rid == "awakening_passage" and not GameState.has_story_flag(&"first_shadow_seen"):
		call_deferred("_run_shadow_beat")
	elif late_room and presence == "present" and not GameState.is_shilda_named():
		call_deferred("_run_auto_naming_scene", rid)


## Geç bölgede ad hâlâ bilinmiyorsa, Shilda ilk kez "present" olduğunda §17 isim sahnesi otomatik (bir kez).
func _run_auto_naming_scene(rid: String) -> void:
	if _auto_naming_running or GameState.is_shilda_named():
		return
	_auto_naming_running = true
	var gen := _beat_gen
	await get_tree().create_timer(1.0).timeout
	while gen == _beat_gen and (DialogueManager.is_open or _busy or UiGate.blocks_movement() or DeathManager.is_dying):
		await get_tree().process_frame
	if gen != _beat_gen:
		return ## oda değişti; sahne sonraki "present" odada denenir
	_auto_naming_running = false
	if not GameState.is_shilda_named() and String(RoomManager.get_active_room_id()) == rid and not is_defeated():
		await _run_naming_scene()


## İlk siluet beat'i (Kırık Geçit): oyuncu yaklaşınca "???" uyarır. Kilitlemez; diyalog kendiliğinden ilerler.
func _run_shadow_beat() -> void:
	if _shadow_beat_running or GameState.has_story_flag(&"first_shadow_seen") or is_defeated():
		return
	_shadow_beat_running = true
	var gen := _beat_gen
	while gen == _beat_gen and _in_passage():
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(_player) and not DialogueManager.is_open and not UiGate.blocks_movement() \
				and not DeathManager.is_dying \
				and absf(_player.global_position.x - global_position.x) < 560.0:
			break
		await get_tree().process_frame
	if gen != _beat_gen or not _in_passage():
		return ## oda değişti: place_for_room temizledi, yerleşime dokunma
	visible = true
	GameState.set_story_flag(&"first_shadow_seen")
	DialogueManager.whisper("???", "Dur.")
	DialogueManager.say("Noroi", "Kim var orada?")
	DialogueManager.whisper("???", "Oraya yaklaşma.")
	await _await_dialogue_or_smoke()
	GameState.set_story_flag(&"first_warning_heard")
	SaveManager.save_game()
	if gen == _beat_gen:
		_shadow_beat_running = false


func _in_passage() -> bool:
	return RoomManager.get_active_room_id() == &"awakening_passage"


func _room_marker(room_id: StringName) -> Marker2D:
	if not RoomManager.has_room(room_id):
		return null
	var root: Node = RoomManager._rooms[room_id].get("root")
	if root == null:
		return null
	for n in ["Spawns/keeper_observe", "Spawns/keeper_intervene", "Spawns/keeper_ambush"]:
		var m := root.get_node_or_null(n) as Marker2D
		if m:
			return m
	return null


func is_present() -> bool:
	return visible and presence == "present"


## Önceki yaşamda yaralandıysa sargı izi (görsel) — keeper_bandaged.
func _apply_bandage() -> void:
	var b := get_node_or_null("Bandage") as Line2D
	var on := bool(GameState.world_memory_state.get("keeper_bandaged", false))
	if on and b == null:
		b = Line2D.new()
		b.name = "Bandage"
		b.width = 3.0
		b.default_color = Color(0.88, 0.82, 0.78, 0.95)
		b.points = PackedVector2Array([Vector2(-9, -58), Vector2(-3, -54), Vector2(3, -58), Vector2(9, -54)])
		add_child(b)
	if b:
		b.visible = on


func _physics_process(delta: float) -> void:
	if presence != "present" or not visible:
		return
	_attack_grace = maxf(0.0, _attack_grace - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_player):
		return
	if mode != Mode.COMBAT or _combat_phase != &"charge":
		sprite.flip_h = _player.global_position.x < global_position.x
	# Modal: yaklaşma/engel mantığı dursun; idle animasyon sürsün.
	if UiGate.pauses_world_threats():
		_face_idle()
		return

	match mode:
		Mode.OBSERVE:
			_face_idle()
			if not _busy and global_position.distance_to(_player.global_position) < 90.0:
				_show_hint("…")
			elif not _busy:
				hint.visible = false
		Mode.WARN:
			_face_idle()
			_show_hint("Uzak dur.")
		Mode.INTERVENE:
			_process_intervene(delta)
		Mode.MOURNING:
			_face_idle()
			_show_hint("Sessizce bekle.")
		Mode.INTIMACY:
			_face_idle()
		Mode.COMBAT:
			_process_combat(delta)
		_:
			_face_idle()


func _face_idle() -> void:
	if _intervening:
		return
	var anim := "observe"
	if mode == Mode.MOURNING:
		anim = "grieve"
	if sprite.animation != anim:
		sprite.play(anim)


func _process_intervene(delta: float) -> void:
	if not _intervening:
		return
	var to_target := _approach_target - global_position
	to_target.y = 0.0
	if absf(to_target.x) > 6.0:
		var step := signf(to_target.x) * approach_speed * delta
		global_position.x += step
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		global_position.x = _approach_target.x
		_intervening = false
		_set_blocker(true)
		if sprite.animation != "observe":
			sprite.play("observe")
		_show_hint("Dur.")


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode and new_mode != Mode.INTERVENE:
		return
	mode = new_mode
	var mood: StringName = &"observe"
	match new_mode:
		Mode.OBSERVE:
			mood = &"observe"
		Mode.WARN:
			mood = &"warn"
		Mode.INTERVENE:
			mood = &"intervene"
		Mode.MOURNING:
			mood = &"mourning"
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("grieve"):
				sprite.play("grieve")
		Mode.INTIMACY:
			mood = &"intimacy"
		_:
			mood = &"observe"
	GameState.world_memory_state["keeper_mood"] = mood
	mode_changed.emit(new_mode)


func on_trigger_zone(zone_id: StringName, _body: Node) -> void:
	## Yasak / çıkış / lanet → önce uyar, tekrarında yumuşak engelle. Ölüm yok.
	if _busy:
		return
	if mode == Mode.MOURNING:
		return
	var key := String(zone_id)
	var count: int = int(_warn_counts.get(key, 0))
	_warn_counts[key] = count + 1

	if zone_id == &"curse":
		CurseManager.add_curse(8.0, zone_id)
		# Lanet yakını: tek fısıltı + hafif lanet; engel yok.
		if count <= 0:
			_busy = true
			set_mode(Mode.WARN)
			DialogueManager.whisper(GameState.keeper_speaker_name(), "Yaklaşma.")
			DialogueManager.whisper(GameState.keeper_speaker_name(), "Kırmızı ışık seni yer.")
			await DialogueManager.dialogue_finished
			if DeathManager.is_dying:
				return
			set_mode(Mode.OBSERVE)
			_busy = false
		return

	if count <= 0:
		_do_warn(zone_id)
	else:
		_do_intervene(zone_id)


## Yasak bölge uyarısı bölgeye göre kısa varyant alır (aşama tonu: mesafeli -> ortak amaç).
func _warn_lines(zone_id: StringName) -> Array:
	if zone_id == &"forbidden":
		var room := String(RoomManager.get_active_room_id())
		if room.begins_with("library"):
			return ["Oraya girme.", "Merak etmen yetmez."]
		if room.begins_with("experiment"):
			return ["Orası seni tutar.", "Geri gel."]
		if room.begins_with("mirrors"):
			return ["Yalnız girme.", "Beni bekle."]
		if room.begins_with("core"):
			return ["Birlikte gireceğiz.", "Önce hazırlan."]
	return _zone_lines.get(zone_id, {}).get("warn", ["Yaklaşma."])


func _do_warn(zone_id: StringName) -> void:
	_busy = true
	set_mode(Mode.WARN)
	CurseManager.add_curse(6.0, zone_id)
	var lines: Array = _warn_lines(zone_id)
	for line in lines:
		DialogueManager.whisper(GameState.keeper_speaker_name(), String(line))
	_show_hint(String(lines[0]))
	await DialogueManager.dialogue_finished
	if DeathManager.is_dying:
		return
	await get_tree().create_timer(0.35).timeout
	if mode != Mode.INTERVENE:
		set_mode(Mode.OBSERVE)
		hint.visible = false
	_busy = false


func _do_intervene(zone_id: StringName) -> void:
	_busy = true
	set_mode(Mode.INTERVENE)
	var lines: Array = _zone_lines.get(zone_id, {}).get("intervene", ["Dur."])
	for line in lines:
		DialogueManager.whisper(GameState.keeper_speaker_name(), String(line))
	# Oyuncu ile yasak nokta arasına yumuşak yerleş.
	if _player:
		var px: float = _player.global_position.x
		var side := 1.0
		if zone_id == &"exit":
			side = -1.0 ## çıkışın soluna (oyuncuyu geri it)
			_approach_target = Vector2(clampf(px + 40.0, _room_min_x() + 120.0, _room_max_x() - 20.0), home_position.y)
		else:
			_approach_target = Vector2(clampf(px + 36.0 * side, _room_min_x() + 100.0, _room_max_x() - 40.0), home_position.y)
	else:
		_approach_target = home_position
	_intervening = true
	_set_blocker(false)
	await DialogueManager.dialogue_finished
	if DeathManager.is_dying:
		_intervening = false
		return
	# Kısa bekle; yaklaşma _physics_process'te biter.
	await get_tree().create_timer(0.8).timeout
	if DeathManager.is_dying:
		_intervening = false
		return
	_intervening = false
	_set_blocker(true)
	if sprite.animation != "observe":
		sprite.play("observe")
	_show_hint("Dur.")
	await get_tree().create_timer(1.2).timeout
	if DeathManager.is_dying:
		_set_blocker(false)
		return
	# Engeli kaldır, eve dön — öldürme yok.
	_set_blocker(false)
	global_position = home_position
	set_mode(Mode.OBSERVE)
	hint.visible = false
	_busy = false


func _room_min_x() -> float:
	return RoomManager.get_room_bounds(RoomManager.get_active_room_id()).position.x


func _room_max_x() -> float:
	var b := RoomManager.get_room_bounds(RoomManager.get_active_room_id())
	return b.end.x if b.size.x > 0.0 else 640.0


func enter_mourning() -> void:
	await mourn_corpse(home_position, "")


func mourn_corpse(death_pos: Vector2, corpse_id: String) -> void:
	## Yas — çiçek bırakır. Oyuncuyu öldürmez.
	if is_defeated():
		return
	_abort_combat()
	_busy = true
	_set_blocker(false)
	_intervening = false
	set_mode(Mode.MOURNING)
	## Hangi odada olursa olsun yas için belirir (silüetten).
	visible = true
	z_index = 0
	if death_pos != Vector2.ZERO:
		global_position = Vector2(death_pos.x + 34.0, home_position.y)
	modulate = Color(0.2, 0.16, 0.24, 0.0)
	var first := DeathManager.cinematic
	var fade := create_tween()
	fade.tween_property(self, "modulate", Color.WHITE, DeathManager._d(0.7 if first else 0.3))
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("flower"):
		sprite.play("flower")
	if corpse_id != "":
		CorpseManager.mark_flower_on_corpse(corpse_id)
	else:
		GameState.world_memory_state["flowers_left"] = int(GameState.world_memory_state["flowers_left"]) + 1
	if first:
		## İlk ölüm: Shilda bedenin başında diz çöker, ilk kez konuşur.
		await DeathManager._wait(0.6)
		DialogueManager.whisper(GameState.keeper_speaker_name(), "…")
		DialogueManager.whisper(GameState.keeper_speaker_name(), "Bedenin soğuyor. Oda onu bırakmayacak.")
		DialogueManager.whisper(GameState.keeper_speaker_name(), "Uyan. Bu sefer hatırla.")
		_show_hint("Sessizce bekle.")
		## Dokunuşla geçilir; geçilmezse kendiliğinden ilerler — ölüm akışı asla kilitlenmez.
		await DeathManager.wait_dialogue()
		await DeathManager._wait(0.25)
	else:
		## Sonraki ölümler: diyalog kutusu yok, kısa fısıltı + çiçek.
		_show_hint("Yine unuttun.")
		await DeathManager._wait(1.0)
	set_mode(Mode.OBSERVE)
	hint.visible = false
	_busy = false
	place_for_room(RoomManager.get_active_room_id())


func _set_blocker(enabled: bool) -> void:
	_block_enabled = enabled
	if blocker_shape:
		blocker_shape.disabled = not enabled
	if blocker:
		blocker.visible = enabled


func _show_hint(text: String) -> void:
	hint.text = text
	hint.clip_text = false
	hint.visible = true
	## 104×128 kare, offset (0,-51): tepe yaklaşık y=-115. Etiket gövdenin üstünde, kırpılmadan.
	var top := -115.0
	if sprite and sprite.sprite_frames and String(sprite.animation) != "" and sprite.sprite_frames.has_animation(sprite.animation):
		var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if tex:
			top = sprite.offset.y - tex.get_height() * absf(sprite.scale.y) * 0.5
	var w := maxf(168.0, float(text.length()) * 8.0)
	hint.offset_left = -w * 0.5
	hint.offset_right = w * 0.5
	hint.offset_bottom = top - 8.0
	hint.offset_top = hint.offset_bottom - 22.0


## Shilda yalnız sakinken konuşulabilir (savaş modunda etkileşim hedefi olmaz).
func can_interact() -> bool:
	return mode != Mode.COMBAT


## Etkileşim etiketi: ad söylenene dek "???", sonra "Shilda".
func get_interact_label() -> String:
	return GameState.keeper_speaker_name()


func on_interact(_by: Node) -> void:
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	if not can_interact():
		return
	if _busy or DialogueManager.is_open:
		DialogueManager.advance()
		return
	# Barışma / Onarım mekaniği (Pillar 5)
	if bool(GameState.player_progress_knowledge.get("keeper_withdrew", false)) or mode == Mode.MOURNING:
		DialogueManager.say("Noroi", "Özür dilerim, seni incitmek istemedim.")
		DialogueManager.say(GameState.keeper_speaker_name(), "…Acıdı. Ama affettim. Yanımda dur.")
		await _await_dialogue_or_smoke()
		GameState.player_progress_knowledge["keeper_withdrew"] = false
		GameState.player_progress_knowledge["keeper_hurt"] = false
		var trust_state := GameState.get_shilda_trust_state()
		trust_state["reconciled"] = true
		modulate = Color.WHITE
		set_mode(Mode.OBSERVE)
		SaveManager.save_game()
		return
	## Ad yalnız bahçede (veya geç bölge yedeğinde) açılır. Nöbet odası yüz yüze ama adsızdır.
	if not GameState.is_shilda_named():
		var rid := String(RoomManager.get_active_room_id())
		if rid == "awakening_vigil" and not bool(GameState.player_progress_knowledge.get("vigil_parted", false)):
			await _run_vigil_meeting()
			return
		var late := false
		for pre in NAME_FALLBACK_PREFIXES:
			if rid.begins_with(pre):
				late = true
				break
		if rid == "decay_garden" or late:
			await _run_naming_scene()
			return
		_queue_stage_talk(rid)
		await _await_dialogue_or_smoke()
		return
	var active_room := String(RoomManager.get_active_room_id())
	if active_room == "awakening":
		_queue_stage_talk(active_room)
		await _await_dialogue_or_smoke()
		return
	# İyi yol: hazırlık varsa güven teklifi
	var st: Dictionary = EndingManager.prep_status()
	if st["weight"] and st["code"] and st["echo"] and not st["trusted"]:
		DialogueManager.say(GameState.keeper_speaker_name(), "Bana… güvenebilir misin?")
		DialogueManager.say("Noroi", "…Güveniyorum.")
		DialogueManager.say(GameState.keeper_speaker_name(), "O zaman Çekirdek'e git. Birlikte mühürleyelim.")
		await _await_dialogue_or_smoke()
		GameState.player_progress_knowledge["trusted_keeper"] = true
		set_mode(Mode.INTIMACY)
		SaveManager.save_game()
		return
	if st["trusted"]:
		DialogueManager.say(GameState.keeper_speaker_name(), "Çekirdek seni bekliyor.")
		return
	match mode:
		Mode.WARN:
			DialogueManager.say(GameState.keeper_speaker_name(), "Söyledim, yaklaşma.")
		Mode.INTERVENE:
			DialogueManager.say(GameState.keeper_speaker_name(), "Geri dön.")
		Mode.MOURNING:
			DialogueManager.say(GameState.keeper_speaker_name(), "…")
		Mode.INTIMACY:
			DialogueManager.say(GameState.keeper_speaker_name(), "Yanındayım.")
		_:
			_queue_stage_talk(active_room)


## §19 asama konusmasi: bolgeye gore Shilda sozu (1 Mesafeli, 2 Merak, 3 Guven, 4 Aci, 5 Ortak amac).
func _queue_stage_talk(room: String) -> void:
	if room == "library_witness":
		DialogueManager.say("Shilda", "Ben seyrederim. Tanık olan sensin.")
	elif room.begins_with("library"):
		DialogueManager.say("Noroi", "Beni neden takip ediyorsun?")
		DialogueManager.say("Shilda", "Seni takip etmiyorum.")
		DialogueManager.say("Noroi", "O zaman neden sürekli karşıma çıkıyorsun?")
		DialogueManager.say("Shilda", "Çünkü sürekli tehlikeli yerlere giriyorsun.")
	elif room.begins_with("experiment"):
		DialogueManager.say("Shilda", "Burada kimse uzun kalamadı.")
		DialogueManager.say("Noroi", "Sen kaldın.")
		DialogueManager.say("Shilda", "Başka seçeneğim yoktu.")
	elif room.begins_with("mirrors"):
		DialogueManager.say("Shilda", "Aynalara uzun bakma.")
		DialogueManager.say("Noroi", "Neden?")
		DialogueManager.say("Shilda", "Bazıları kendini orada bıraktı.")
	elif room.begins_with("core"):
		DialogueManager.say("Shilda", "Sona yaklaştık.")
		DialogueManager.say("Noroi", "Korkuyor musun?")
		DialogueManager.say("Shilda", "Evet. Ama bu sefer yalnız değilim.")
	else:
		DialogueManager.say("Shilda", "Buradan uzak dur.")
		DialogueManager.say("Noroi", "Neden?")
		DialogueManager.say("Shilda", "Çünkü orası güvenli değil.")


## Perde 1 sonu: yüz yüze, konuşan ???. Ad söylenmez. Yol açılır, gölge gider.
## Her giriş [[sorucu, soru], [[Noroi, cevap0], [Noroi, cevap1]]]; çiftler dialogue_lint tarafından taranır.
const VIGIL_QUESTIONS: Array = [
	[["@shilda", "Neden buradasın?"],
		[["Noroi", "Kim olduğumu öğrenmem gerek."], ["Noroi", "Seni ilgilendirmez."]]],
	[["@shilda", "Bana güvenir misin?"],
		[["Noroi", "Henüz değil ama dinliyorum."], ["Noroi", "Hayır. Kimseye güvenmem."]]],
	[["@shilda", "Yarıktan gelen sesi duydun mu?"],
		[["Noroi", "Duydum. Kendi sesime benziyordu."], ["Noroi", "Hayır. Hiçbir şey duymadım."]]],
]
var _vigil_hooked: bool = false


## Nöbet odası: tanışma + 3 soru (güven ±1) + iz gölgesi. `awakening_vigil` yalnız konuşma bitti
## VE iz çözüldüyse işaretlenir. Cevaplar kalıcıdır; yarım kalan konuşma kalan sorularla sürer.
func _run_vigil_meeting() -> void:
	_vigil_hook()
	if _busy:
		return
	var gs := GameState.player_progress_knowledge
	if not bool(gs.get("vigil_talk_done", false)) and not PuzzleManager.is_solved(&"awakening_vigil"):
		_busy = true
		var answers: Array = gs.get("vigil_answers", [])
		if answers.is_empty():
			for line in DialogueData.get_set(&"awakening_vigil", &"meeting"):
				DialogueManager.say(String(line[0]), String(line[1]))
			await _await_dialogue_or_smoke()
		while answers.size() < VIGIL_QUESTIONS.size():
			var q: Array = VIGIL_QUESTIONS[answers.size()]
			var opts: Array = []
			for o in q[1]:
				opts.append(String(o[1]))
			var pick: int = await _vigil_ask(String(q[0][1]), opts)
			if pick < 0:
				_busy = false
				return
			answers.append(pick)
			gs["vigil_answers"] = answers
			GameState.add_vigil_trust(1 if pick == 0 else -1)
		gs["vigil_talk_done"] = true
		_busy = false
		for sh in get_tree().get_nodes_in_group("vigil_shades"):
			sh.start_all()
	_vigil_try_finish()


func _vigil_hook() -> void:
	if _vigil_hooked:
		return
	_vigil_hooked = true
	PuzzleManager.puzzle_solved.connect(func(id: StringName) -> void:
		if id == &"awakening_vigil_trace" and RoomManager.get_active_room_id() == &"awakening_vigil":
			_vigil_try_finish())


## Konuşma bitti (veya eski kayıt çözülmüş) VE iz çözüldüyse nöbeti kapatır. Tekrar çağrılabilir.
func _vigil_try_finish() -> void:
	if PuzzleManager.is_solved(&"awakening_vigil") and bool(GameState.player_progress_knowledge.get("vigil_parted", false)):
		return
	var talk_ok: bool = bool(GameState.player_progress_knowledge.get("vigil_talk_done", false)) or PuzzleManager.is_solved(&"awakening_vigil")
	if not talk_ok or not PuzzleManager.is_solved(&"awakening_vigil_trace"):
		return
	PuzzleManager.mark_solved(&"awakening_vigil")
	LorePointScript.record_evidence("ev_vigil_meeting", "Nöbet", "Nöbet odasında bir gölge yolu gösterdi ve gitti. Adını söylemedi.", "izler")
	GameState.player_progress_knowledge["vigil_parted"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true
	place_for_room(&"awakening_vigil")
	SaveManager.save_game()


## Seçimli soru; seçilen indeksi döndürür, iptalde -1. Headless/smoke'ta advance() ile seçenek 0 seçilir.
func _vigil_ask(prompt: String, opts: Array) -> int:
	var res := [-2]
	var on_made := func(i: int) -> void: res[0] = i
	var on_cancel := func() -> void: res[0] = -1
	DialogueManager.choice_made.connect(on_made)
	DialogueManager.choice_cancelled.connect(on_cancel)
	DialogueManager.ask(GameState.keeper_speaker_name(), prompt, PackedStringArray(opts))
	var auto := OS.get_environment("TORIMON_SMOKE") == "1" or DisplayServer.get_name() == "headless"
	var frames := 0
	while res[0] == -2 and frames < (900 if auto else 72000):
		frames += 1
		if auto:
			DialogueManager.advance()
		await get_tree().process_frame
	DialogueManager.choice_made.disconnect(on_made)
	DialogueManager.choice_cancelled.disconnect(on_cancel)
	return res[0] if res[0] != -2 else -1


## Isim sahnesi: "???" konusur; "Ben Noroi." satirindan itibaren ad bilinir, kart "Shilda" olur.
func _run_naming_scene() -> void:
	_busy = true
	_queue_naming_lines()
	await _await_dialogue_or_smoke()
	_busy = false
	if not GameState.is_shilda_named():
		## 9. satırdan ("Ben Noroi.") önce iptal edildi/kesildi -> isim öğrenilmedi
		return
	GameState.player_progress_knowledge["shilda_talk_done"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true
	GameState.player_progress_knowledge["awakening_mystery_seen"] = true
	GameState.knowledge_changed.emit(&"player")
	SaveManager.save_game()


## §17 satırları (denetim bunu doğrudan kuyruğa alıp satır satır ilerletir).
func _queue_naming_lines() -> void:
	DialogueManager.say("Noroi", "Ne zamandır orada duruyorsun?")
	DialogueManager.say("???", "Buraya geldiğinden beri.")
	DialogueManager.say("Noroi", "Neden bana?")
	DialogueManager.say("???", "Daha önce de birilerinin geldiğini gördüm.")
	DialogueManager.say("Noroi", "Çıkan oldu mu?")
	DialogueManager.say("???", "Hiçbiri çıkamadı.")
	DialogueManager.say("Noroi", "Sana ne diyorlar?")
	DialogueManager.say("???", "Shilda.")
	DialogueManager.say_with("Noroi", "Ben Noroi.", func(): GameState.set_shilda_named(true))
	DialogueManager.say("Shilda", "Biliyorum.")
	DialogueManager.say("Noroi", "Adımı nereden biliyorsun?")
	DialogueManager.say("Shilda", "Şimdi değil. Oda senden önce konuşur.")


func receive_player_strike() -> void:
	## Erken saldırı = ilişki olayı. Kalıcı son yalnız Çekirdek bölgesinde.
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	## Aynı anda ölüm: önce oyuncunun ölümü çözülür, ölürken vuruş sayılmaz.
	if DeathManager.is_dying:
		return
	GameState.character_current_life_knowledge["struck_keeper"] = true
	_spawn_defensive_shield()
	var trust_state := GameState.get_shilda_trust_state()
	trust_state["strikes_dealt"] = int(trust_state.get("strikes_dealt", 0)) + 1
	if mode == Mode.COMBAT:
		## Karşılaşmada vuruş: geri sendeler, ilişki yine zedelenir ama son tetiklenmez.
		_combat_phase = &"stunned"
		_combat_timer = 0.6
		_flash(Color(1.6, 1.2, 1.2, 1))
		return
	if not bool(GameState.player_progress_knowledge.get("awakening_mystery_seen", false)):
		DialogueManager.whisper(GameState.keeper_speaker_name(), "…Henüz değil.")
		return
	_strikes += 1
	CurseManager.add_curse(10.0, &"strike_keeper")
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("grieve"):
		sprite.play("grieve")
	_show_hint("!")
	var in_core := String(GameState.character_current_life_knowledge.get("room", "")).begins_with("core")
	if _strikes == 1:
		DialogueManager.say(GameState.keeper_speaker_name(), "Bunu… yapma.")
		await _await_dialogue_or_smoke()
		return
	if _strikes == 2:
		DialogueManager.say(GameState.keeper_speaker_name(), "Lütfen. Ben düşmanın değilim.")
		await _await_dialogue_or_smoke()
		GameState.player_progress_knowledge["trusted_keeper"] = false
		GameState.player_progress_knowledge["keeper_hurt"] = true
		return
	if _strikes >= STRIKES_TO_BAD:
		if not in_core:
			## İlk bölgeler: ilişki kırılır; oyun bitmez. Onarım mümkün.
			DialogueManager.say(GameState.keeper_speaker_name(), "…Yeter.")
			DialogueManager.say(GameState.keeper_speaker_name(), "Geri çekiliyorum. Hazır olunca yine sorarsın.")
			await _await_dialogue_or_smoke()
			GameState.player_progress_knowledge["trusted_keeper"] = false
			GameState.player_progress_knowledge["keeper_hurt"] = true
			GameState.player_progress_knowledge["keeper_withdrew"] = true
			set_mode(Mode.MOURNING)
			modulate = Color(0.45, 0.4, 0.48, 0.75)
			_strikes = 0 ## onarım için sıfırla
			SaveManager.save_game()
			return
		else:
			## Çekirdekte Shilda düşmez: vuruş savuşturulur (öldürülemez).
			_strikes = 0
			_flash(Color(1.5, 1.4, 1.6, 1))
			DialogueManager.say(GameState.keeper_speaker_name(), "…Beni durduramazsın. Ben de seni durdurmayacağım.")
			await _await_dialogue_or_smoke()


# --- Sargı hafızası ---------------------------------------------------------------

func is_defeated() -> bool:
	## Shilda öldürülemez (v3). Eski çağrılar için sabit false.
	return false


func _hide_defeated() -> void:
	_abort_combat()
	presence = "hidden"
	_busy = false
	_set_blocker(false)
	visible = false
	collision_layer = 0
	collision_mask = 0
	hint.visible = false
	set_mode(Mode.OBSERVE)


## Karşılaşmayı anında kes: hitbox/çarpışma kapanır, atılma rengi ve hızı sıfırlanır.
func _abort_combat() -> void:
	if mode == Mode.COMBAT:
		end_encounter(false)
	_combat_phase = &"idle"
	_combat_timer = 1.0
	_combat_hit_done = false
	collision_mask = 0
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.0
	if modulate.r > 1.05 or modulate.g < 0.95:
		modulate = Color.WHITE
	hint.visible = false


func _on_player_reborn() -> void:
	_attack_grace = REBIRTH_GRACE
	_player = get_tree().get_first_node_in_group("player") as Node2D
	call_deferred("place_for_room", RoomManager.get_active_room_id())


func _on_player_death_started(_reason: StringName) -> void:
	## Ruh hedef alınmaz: savaş anında durur.
	_abort_combat()
	_attack_grace = REBIRTH_GRACE
	if bool(GameState.character_current_life_knowledge.get("struck_keeper", false)):
		GameState.world_memory_state["keeper_bandaged"] = true
		GameState.world_memory_state["keeper_bandage_line_pending"] = true


func _maybe_bandage_line() -> void:
	if not bool(GameState.world_memory_state.get("keeper_bandage_line_pending", false)):
		return
	if not is_present() or DialogueManager.is_open:
		return
	GameState.world_memory_state["keeper_bandage_line_pending"] = false
	DialogueManager.say("Shilda", "Vurduğun yer hâlâ sızlıyor.")
	DialogueManager.say("Shilda", "Sen unuttun. Ben unutmadım.")


# --- Savaş karşılaşması: pençe + atılma + çatlak duvar ------------------------------------

func start_encounter(encounter_id: StringName) -> void:
	if EndingManager.current != EndingManager.Ending.NONE or is_defeated() or DeathManager.is_dying:
		return
	_encounter_id = encounter_id
	presence = "present"
	visible = true
	z_index = 0
	collision_layer = _saved_layer
	collision_mask = 1
	modulate = Color.WHITE
	_busy = true
	_combat_phase = &"idle"
	_combat_timer = 1.0
	set_mode(Mode.COMBAT)


func end_encounter(success: bool) -> void:
	if mode != Mode.COMBAT:
		return
	collision_mask = 0
	_combat_phase = &"idle"
	_busy = false
	modulate = Color.WHITE
	set_mode(Mode.OBSERVE)
	encounter_finished.emit(_encounter_id if success else &"")


func _process_combat(delta: float) -> void:
	if not is_instance_valid(_player) or DeathManager.is_dying:
		return
	_combat_timer -= delta
	if _attack_grace > 0.0 and _combat_phase == &"idle":
		_combat_timer = maxf(_combat_timer, _attack_grace)
	var dx := _player.global_position.x - global_position.x
	match _combat_phase:
		&"idle":
			_face_player()
			if sprite.animation != "walk":
				sprite.play("walk")
			## Yaklaş ama dibine girme
			if absf(dx) > CLAW_RANGE * 1.4:
				velocity = Vector2(signf(dx) * 60.0, 0)
				move_and_slide()
			if _combat_timer <= 0.0:
				if absf(dx) <= CLAW_RANGE * 1.3:
					_combat_phase = &"claw_windup"
					_combat_timer = CLAW_WINDUP
				else:
					_combat_phase = &"charge_windup"
					_combat_timer = CHARGE_WINDUP
					_charge_dir = signf(dx) if dx != 0.0 else 1.0
				_flash(Color(1.8, 0.35, 0.4, 1))
				_show_hint("!")
				sprite.play("observe")
				_sfx(&"keeper_telegraph")
		&"claw_windup":
			_face_player()
			if _combat_timer <= 0.0:
				sprite.play("attack")
				_sfx(&"keeper_claw")
				_combat_hit_done = false
				if absf(dx) <= CLAW_RANGE and absf(_player.global_position.y - global_position.y) < 48.0:
					_hit_player()
				_combat_phase = &"recover"
				_combat_timer = 0.7
				modulate = Color.WHITE
				hint.visible = false
		&"charge_windup":
			if _combat_timer <= 0.0:
				_combat_phase = &"charge"
				_charge_travel = 0.0
				_combat_hit_done = false
				_sfx(&"keeper_charge")
				sprite.play("walk")
				sprite.speed_scale = 2.2
				modulate = Color(1.4, 0.75, 0.8, 1)
				hint.visible = false
		&"charge":
			var step := _charge_dir * CHARGE_SPEED * delta
			velocity = Vector2(_charge_dir * CHARGE_SPEED, 0)
			var col := move_and_collide(Vector2(step, 0))
			_charge_travel += absf(step)
			if not _combat_hit_done and absf(_player.global_position.x - global_position.x) < 26.0 and absf(_player.global_position.y - global_position.y) < 48.0:
				_combat_hit_done = true
				_hit_player()
			if col:
				var other := col.get_collider()
				if other and other.has_method("receive_keeper_charge"):
					other.receive_keeper_charge(self)
				_wall_impact()
			elif _charge_travel >= CHARGE_MAX_DIST or _out_of_room():
				_combat_phase = &"recover"
				_combat_timer = 0.8
				sprite.speed_scale = 1.0
				modulate = Color.WHITE
		&"stunned", &"recover":
			if sprite.animation != "grieve" and _combat_phase == &"stunned":
				sprite.play("grieve")
			elif _combat_phase == &"recover" and sprite.animation != "observe":
				sprite.play("observe")
			if _combat_timer <= 0.0:
				_combat_phase = &"idle"
				_combat_timer = randf_range(0.6, 1.1)
				sprite.speed_scale = 1.0
				modulate = Color.WHITE


func _wall_impact() -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.65)
	_combat_phase = &"stunned"
	_combat_timer = 1.4
	sprite.speed_scale = 1.0
	modulate = Color.WHITE
	global_position.x -= _charge_dir * 10.0


func _hit_player() -> void:
	if DeathManager.is_dying or _attack_grace > 0.0 or not is_instance_valid(_player):
		return
	if _player.has_method("receive_hazard_hit"):
		if _player.has_method("is_shadow_dashing") and _player.is_shadow_dashing():
			return
		_player.receive_hazard_hit(global_position.x)


func _out_of_room() -> bool:
	var b := RoomManager.get_room_bounds(RoomManager.get_active_room_id())
	return global_position.x < b.position.x + 20.0 or global_position.x > b.end.x - 20.0


func _face_player() -> void:
	if _player:
		sprite.flip_h = _player.global_position.x < global_position.x


func _spawn_defensive_shield() -> void:
	var shield := Node2D.new()
	shield.name = "DefensiveShield"
	shield.z_index = 6
	add_child(shield)
	var ring := Line2D.new()
	ring.width = 2.5
	ring.default_color = Color(0.7, 0.85, 1.0, 0.85)
	var pts := PackedVector2Array()
	for i in 17:
		var rad := i * TAU / 16.0
		pts.append(Vector2(cos(rad), sin(rad)) * 36.0)
	ring.points = pts
	shield.add_child(ring)
	shield.position = Vector2(0, -28)
	var tw := shield.create_tween().set_parallel(true)
	tw.tween_property(shield, "scale", Vector2(1.3, 1.3), 0.35)
	tw.tween_property(shield, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(shield.queue_free)
	_sfx(&"sword_hit")


func _flash(c: Color) -> void:
	modulate = c


func _sfx(id: StringName) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(id)


func _await_dialogue_or_smoke() -> void:
	if OS.get_environment("TORIMON_SMOKE") == "1" or DisplayServer.get_name() == "headless":
		var safety := 0
		while DialogueManager.is_open and safety < 100:
			safety += 1
			DialogueManager.advance()
			await get_tree().process_frame
		return
	await DialogueManager.dialogue_finished
