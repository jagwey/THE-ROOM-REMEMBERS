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
	## Stub — FAZ 4+ ölüm sonrası çiçek bırakma için hazır.
	_busy = true
	_set_blocker(false)
	_intervening = false
	set_mode(Mode.MOURNING)
	DialogueManager.whisper("Bekçi", "…")
	DialogueManager.whisper("Bekçi", "Yine unuttun.")
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("grieve"):
		sprite.play("grieve")
	await DialogueManager.dialogue_closed
	await get_tree().create_timer(0.6).timeout
	set_mode(Mode.OBSERVE)
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
	if _busy or DialogueManager.is_open:
		DialogueManager.advance()
		return
	match mode:
		Mode.WARN:
			DialogueManager.say("Bekçi", "Söyledim… yaklaşma.")
		Mode.INTERVENE:
			DialogueManager.say("Bekçi", "Geri dön.")
		Mode.MOURNING:
			DialogueManager.say("Bekçi", "…")
		_:
			DialogueManager.say("Bekçi", "…Seni izliyorum.")
			DialogueManager.say("Bekçi", "Henüz hatırlama.")
