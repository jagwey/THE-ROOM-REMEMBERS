extends CharacterBody2D
## Bekçi — senaryolu koruyucu. Klasik düşman değil. Erken oyunda öldürmez.

enum Mode { OBSERVE, WARN, INTERVENE, MOURNING, INTIMACY }

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
var _mystery_done: bool = false
var _warn_counts: Dictionary = {}
var _strikes: int = 0
const STRIKES_TO_BAD := 3
var _zone_lines: Dictionary = {
	&"forbidden": {
		"warn": ["Yaklaşma.", "O mühür… senin değil."],
		"intervene": ["Dur.", "Oraya gitme."],
	},
	&"exit": {
		"warn": ["Oraya gitme.", "Kapı henüz seni istemiyor."],
		"intervene": ["Geri dön.", "Henüz değil."],
	},
	&"curse": {
		"warn": ["Yaklaşma.", "Kırmızı ışık seni yer."],
		"intervene": ["Uzak dur.", "Lanet uyanmasın."],
	},
}


func _ready() -> void:
	add_to_group("keeper")
	sprite.sprite_frames = load("res://assets/characters/keeper.tres")
	sprite.offset = Vector2(0, -60)
	hint.text = ""
	hint.visible = false
	UiTheme.apply_label(hint, 10, false)
	_set_blocker(false)
	home_position = global_position
	GameState.world_memory_state["keeper_mood"] = &"observe"
	# Gizem beat: uzak silüet ile başla.
	global_position = silhouette_position
	modulate = Color(0.15, 0.12, 0.18, 0.85)
	sprite.play("observe")
	set_mode(Mode.OBSERVE)
	call_deferred("_run_mystery_beat")


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
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
			_show_hint("…çiçek")
		Mode.INTIMACY:
			_face_idle()
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
			DialogueManager.whisper("Bekçi", "Yaklaşma.")
			DialogueManager.whisper("Bekçi", "Kırmızı ışık seni yer.")
			await DialogueManager.dialogue_closed
			set_mode(Mode.OBSERVE)
			_busy = false
		return

	if count <= 0:
		_do_warn(zone_id)
	else:
		_do_intervene(zone_id)


func _do_warn(zone_id: StringName) -> void:
	_busy = true
	set_mode(Mode.WARN)
	CurseManager.add_curse(6.0, zone_id)
	var lines: Array = _zone_lines.get(zone_id, {}).get("warn", ["Yaklaşma."])
	for line in lines:
		DialogueManager.whisper("Bekçi", String(line))
	_show_hint(String(lines[0]))
	await DialogueManager.dialogue_closed
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
		DialogueManager.whisper("Bekçi", String(line))
	# Oyuncu ile yasak nokta arasına yumuşak yerleş.
	if _player:
		var px: float = _player.global_position.x
		var side := 1.0
		if zone_id == &"exit":
			side = -1.0 ## çıkışın soluna (oyuncuyu geri it)
			_approach_target = Vector2(clampf(px + 40.0, 160.0, 620.0), home_position.y)
		else:
			_approach_target = Vector2(clampf(px + 36.0 * side, 140.0, 600.0), home_position.y)
	else:
		_approach_target = home_position
	_intervening = true
	_set_blocker(false)
	await DialogueManager.dialogue_closed
	# Kısa bekle; yaklaşma _physics_process'te biter.
	await get_tree().create_timer(0.8).timeout
	_intervening = false
	_set_blocker(true)
	if sprite.animation != "observe":
		sprite.play("observe")
	_show_hint("Dur.")
	await get_tree().create_timer(1.2).timeout
	# Engeli kaldır, eve dön — öldürme yok.
	_set_blocker(false)
	global_position = home_position
	set_mode(Mode.OBSERVE)
	hint.visible = false
	_busy = false


func enter_mourning() -> void:
	await mourn_corpse(home_position, "")


func mourn_corpse(death_pos: Vector2, corpse_id: String) -> void:
	## Yas — çiçek bırakır. Oyuncuyu öldürmez.
	_busy = true
	_set_blocker(false)
	_intervening = false
	set_mode(Mode.MOURNING)
	if death_pos != Vector2.ZERO:
		global_position = Vector2(death_pos.x, home_position.y)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("grieve"):
		sprite.play("grieve")
	DialogueManager.whisper("Bekçi", "…")
	DialogueManager.whisper("Bekçi", "Yine unuttun.")
	if corpse_id != "":
		CorpseManager.mark_flower_on_corpse(corpse_id)
	else:
		GameState.world_memory_state["flowers_left"] = int(GameState.world_memory_state["flowers_left"]) + 1
	_show_hint("…çiçek")
	## Smoke/headless: diyalog kilitlenmesin
	if OS.get_environment("TORIMON_SMOKE") == "1" or DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.15).timeout
		if DialogueManager.is_open:
			DialogueManager.clear()
	else:
		await DialogueManager.dialogue_closed
	await get_tree().create_timer(0.25).timeout
	global_position = home_position
	set_mode(Mode.OBSERVE)
	hint.visible = false
	_busy = false


func _run_mystery_beat() -> void:
	if _mystery_done:
		return
	if bool(GameState.player_progress_knowledge.get("awakening_mystery_seen", false)):
		# Meta: bir kez görüldüyse sessizce eve yerleş.
		modulate = Color.WHITE
		global_position = home_position
		_mystery_done = true
		return
	_busy = true
	await get_tree().create_timer(0.85).timeout
	# Oda girişi diyaloğu bitsin.
	if DialogueManager.is_open:
		await DialogueManager.dialogue_closed
	# Kısa beliriş (silüetten görünür forma)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.55)
	await tw.finished
	DialogueManager.whisper("???", "Oraya gitme.")
	DialogueManager.whisper("???", "Yaklaşma.")
	await DialogueManager.dialogue_closed
	await get_tree().create_timer(0.25).timeout
	# Gözlem konumuna çekil
	var tw2 := create_tween()
	tw2.tween_property(self, "global_position", home_position, 0.7)
	await tw2.finished
	GameState.player_progress_knowledge["awakening_mystery_seen"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true
	_mystery_done = true
	set_mode(Mode.OBSERVE)
	_busy = false


func _set_blocker(enabled: bool) -> void:
	_block_enabled = enabled
	if blocker_shape:
		blocker_shape.disabled = not enabled
	if blocker:
		blocker.visible = enabled


func _show_hint(text: String) -> void:
	hint.text = text
	hint.visible = true


func on_interact(_by: Node) -> void:
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	if _busy or DialogueManager.is_open:
		DialogueManager.advance()
		return
	# İyi yol: hazırlık varsa güven teklifi
	var st: Dictionary = EndingManager.prep_status()
	if st["weight"] and st["code"] and st["echo"] and not st["trusted"]:
		DialogueManager.say("Bekçi", "Bana… güvenebilir misin?")
		DialogueManager.say("Shiren", "…Güveniyorum.")
		DialogueManager.say("Bekçi", "O zaman Çekirdek'e git. Birlikte mühürleyelim.")
		await _await_dialogue_or_smoke()
		GameState.player_progress_knowledge["trusted_keeper"] = true
		set_mode(Mode.INTIMACY)
		SaveManager.save_game()
		return
	if st["trusted"]:
		DialogueManager.say("Bekçi", "Çekirdek seni bekliyor.")
		return
	match mode:
		Mode.WARN:
			DialogueManager.say("Bekçi", "Söyledim… yaklaşma.")
		Mode.INTERVENE:
			DialogueManager.say("Bekçi", "Geri dön.")
		Mode.MOURNING:
			DialogueManager.say("Bekçi", "…")
		Mode.INTIMACY:
			DialogueManager.say("Bekçi", "Yanındayım.")
		_:
			DialogueManager.say("Bekçi", "…Seni izliyorum.")
			DialogueManager.say("Bekçi", "Henüz hatırlama.")


func receive_player_strike() -> void:
	## Erken saldırı = ilişki olayı. Kalıcı son yalnız Çekirdek bölgesinde.
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	if not bool(GameState.player_progress_knowledge.get("awakening_mystery_seen", false)):
		DialogueManager.whisper("Bekçi", "…Henüz değil.")
		return
	_strikes += 1
	CurseManager.add_curse(10.0, &"strike_keeper")
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("grieve"):
		sprite.play("grieve")
	_show_hint("!")
	var in_core := String(GameState.character_current_life_knowledge.get("room", "")).begins_with("core")
	if _strikes == 1:
		DialogueManager.say("Bekçi", "Bunu… yapma.")
		await _await_dialogue_or_smoke()
		return
	if _strikes == 2:
		DialogueManager.say("Bekçi", "Lütfen. Ben düşmanın değilim.")
		await _await_dialogue_or_smoke()
		GameState.player_progress_knowledge["trusted_keeper"] = false
		GameState.player_progress_knowledge["keeper_hurt"] = true
		return
	if _strikes >= STRIKES_TO_BAD:
		if not in_core:
			## İlk bölgeler: ilişki kırılır; oyun bitmez. Onarım mümkün.
			DialogueManager.say("Bekçi", "…Yeter.")
			DialogueManager.say("Bekçi", "Bir gün bunu yeniden sorarsın diye… geri çekiliyorum.")
			await _await_dialogue_or_smoke()
			GameState.player_progress_knowledge["trusted_keeper"] = false
			GameState.player_progress_knowledge["keeper_hurt"] = true
			GameState.player_progress_knowledge["keeper_withdrew"] = true
			set_mode(Mode.MOURNING)
			modulate = Color(0.45, 0.4, 0.48, 0.75)
			_strikes = 0 ## onarım için sıfırla
			SaveManager.save_game()
			return
		DialogueManager.say("Bekçi", "…Öyle olsun.")
		await _await_dialogue_or_smoke()
		modulate = Color(0.4, 0.35, 0.4, 0.6)
		await EndingManager.trigger(EndingManager.Ending.BAD_KILL_KEEPER)


func _await_dialogue_or_smoke() -> void:
	if OS.get_environment("TORIMON_SMOKE") == "1" or DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.1).timeout
		if DialogueManager.is_open:
			DialogueManager.clear()
		return
	await DialogueManager.dialogue_closed
