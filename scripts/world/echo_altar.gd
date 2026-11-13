extends Area2D
## Yankı Sunağı — etkileşince oyuncunun 8 saniyelik hareketi kaydedilir; sonra yarı saydam
## bir Noroi ikizi (EchoTwin) bu hareketi dünyada fiziksel olarak tekrarlar. İkiz plakaya
## basar / kolu çeker; oyuncu eşzamanlı olarak diğer mekanizmayı tetikler.
## Tüm anahtarlar (EchoSwitch) aynı anda aktifse puzzle_id çözülür.

const TWIN_SCRIPT := preload("res://scripts/world/echo_twin.gd")
const SWITCH_SCRIPT := preload("res://scripts/world/echo_switch.gd")

@export var puzzle_id: StringName = &"experiment_circuit"
@export var record_seconds: float = 8.0
@export var intro_speaker: String = "Shilda"
@export_multiline var intro_text: String = "Sunağa dokun; yankın sekiz saniyeni tekrarlar."
@export var solved_text: String = "İki devre birleşti, yol açık."
## "plate" (üstünde durulmalı) veya "lever" (çekildikten sonra kısa süre aktif)
@export var switch_kinds: PackedStringArray = PackedStringArray(["plate", "lever"])
@export var switch_positions: PackedVector2Array = PackedVector2Array([Vector2(-180, 32), Vector2(230, 0)])
@export var lever_hold_seconds: float = 1.6
## true: tüm anahtarlar aktifken puzzle_id yalnız "canlı" olur (çözülmez); biri düşünce canlılık söner.
@export var live_only: bool = false

var _recording: bool = false
var _elapsed: float = 0.0
var _frames: Array = [] ## [t, pos, facing, anim]
var _events: Array = [] ## [t, "interact"]
var _twin: Node2D
var _switches: Array = []
var _label: Label
var _intro_done: bool = false
var _start_pos: Vector2


func _ready() -> void:
	add_to_group("echo_altar")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr:
		spr.texture = load("res://assets/props/halo.png")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.modulate = Color(0.8, 0.7, 1.0, 1.0)
	_label = Label.new()
	_label.position = Vector2(-80, -78)
	_label.size = Vector2(160, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UiTheme.has_method("apply_outlined"):
		UiTheme.call("apply_outlined", _label, 14)
	else:
		UiTheme.apply_label(_label, 14)
	add_child(_label)
	RoomManager.room_changed.connect(_on_room_changed)
	call_deferred("_build_switches")
	_refresh_label()


func _build_switches() -> void:
	for i in switch_kinds.size():
		var sw := Area2D.new()
		sw.set_script(SWITCH_SCRIPT)
		sw.set("kind", switch_kinds[i])
		sw.set("hold_seconds", lever_hold_seconds)
		sw.position = position + (switch_positions[i] if i < switch_positions.size() else Vector2(120 * i, 0))
		get_parent().add_child(sw)
		sw.connect("state_changed", _on_switch_changed)
		_switches.append(sw)
		if RoomManager.get_active_room_id() != _room_id():
			if not sw.has_meta("room_physics_suspended"):
				sw.set_meta("room_saved_layer", sw.collision_layer)
				sw.set_meta("room_saved_mask", sw.collision_mask)
				sw.set_meta("room_physics_suspended", true)
			sw.collision_layer = 0
			sw.collision_mask = 0
	if PuzzleManager.is_solved(puzzle_id):
		for sw in _switches:
			sw.call("set_locked_on")


func on_interact(by: Node) -> void:
	if PuzzleManager.is_solved(puzzle_id):
		DialogueManager.say("Noroi", solved_text)
		return
	if _recording:
		_finish_recording()
		return
	if not _intro_done:
		_intro_done = true
		DialogueManager.say(intro_speaker, intro_text)
		var ok: bool = await DialogueManager.dialogue_finished
		if not ok:
			_intro_done = false
			return
	_start_recording(by as Node2D)


func _start_recording(player: Node2D) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_clear_twin()
	_recording = true
	_elapsed = 0.0
	_frames.clear()
	_events.clear()
	_start_pos = player.global_position
	if not MobileInputManager.interact_pressed.is_connected(_on_rec_interact):
		MobileInputManager.interact_pressed.connect(_on_rec_interact)
	if not MobileInputManager.attack_pressed.is_connected(_on_rec_attack):
		MobileInputManager.attack_pressed.connect(_on_rec_attack)
	if not MobileInputManager.skill_pressed.is_connected(_on_rec_skill):
		MobileInputManager.skill_pressed.connect(_on_rec_skill)
	_sfx(&"echo_record")
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.12)


func _on_rec_interact() -> void:
	if _recording and _elapsed > 0.05:
		_events.append([_elapsed, "interact"])


func _on_rec_attack() -> void:
	if _recording and _elapsed > 0.05:
		_events.append([_elapsed, "attack"])


func _on_rec_skill() -> void:
	if _recording and _elapsed > 0.05:
		_events.append([_elapsed, "skill"])


func _cleanup_recording_signals() -> void:
	if MobileInputManager.interact_pressed.is_connected(_on_rec_interact):
		MobileInputManager.interact_pressed.disconnect(_on_rec_interact)
	if MobileInputManager.attack_pressed.is_connected(_on_rec_attack):
		MobileInputManager.attack_pressed.disconnect(_on_rec_attack)
	if MobileInputManager.skill_pressed.is_connected(_on_rec_skill):
		MobileInputManager.skill_pressed.disconnect(_on_rec_skill)


func _cancel_recording() -> void:
	_recording = false
	_cleanup_recording_signals()
	_frames.clear()
	_events.clear()
	_refresh_label()


func _on_room_changed(from_room: StringName, to_room: StringName) -> void:
	if _recording and (from_room == _room_id() or to_room != _room_id()):
		_cancel_recording()


func _exit_tree() -> void:
	_cancel_recording()
	if live_only:
		PuzzleManager.set_live(puzzle_id, false)
	if RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.disconnect(_on_room_changed)


func _physics_process(delta: float) -> void:
	if not _recording:
		return
	if RoomManager.get_active_room_id() != _room_id():
		_cancel_recording()
		return
	if UiGate.pauses_world_threats():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_elapsed += delta
	var spr := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_frames.append([_elapsed, player.global_position, spr.flip_h if spr else false, String(spr.animation) if spr else "idle"])
	_label.text = "● Kayıt Süresi %.1f" % maxf(0.0, record_seconds - _elapsed)
	if _elapsed >= record_seconds:
		_finish_recording()


func _finish_recording() -> void:
	_recording = false
	_cleanup_recording_signals()
	if _frames.size() < 4:
		_refresh_label()
		return
	## Oyuncu "şimdiye" döner: kaydın başladığı yere.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = _start_pos
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
	_twin = Node2D.new()
	_twin.set_script(TWIN_SCRIPT)
	get_parent().add_child(_twin)
	_twin.call("play_recording", _frames.duplicate(), _events.duplicate())
	_twin.connect("finished", _on_twin_finished)
	_sfx(&"echo_playback")
	_label.text = "Yankın hareket ediyor…"


func _on_twin_finished() -> void:
	_twin = null
	if not PuzzleManager.is_solved(puzzle_id):
		_label.text = "Yankı söndü · yeniden kaydet"


func _on_switch_changed(_active: bool) -> void:
	if live_only:
		var all_on := not _switches.is_empty()
		for sw in _switches:
			if not bool(sw.get("active")):
				all_on = false
				break
		PuzzleManager.set_live(puzzle_id, all_on)
		return
	if PuzzleManager.is_solved(puzzle_id) or _switches.is_empty():
		return
	for sw in _switches:
		if not bool(sw.get("active")):
			return
	PuzzleManager.mark_solved(puzzle_id)
	for sw in _switches:
		sw.call("set_locked_on")
	_sfx(&"door_open")
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("zoom_to"):
		cam.zoom_to(1.22, 1.4)
	SaveManager.save_game()
	DialogueManager.say("Noroi", "Yankım geçmişi tuttu; ben yeni bir adım attım.")
	DialogueManager.say("Noroi", solved_text)
	_refresh_label()


func _clear_twin() -> void:
	if _twin and is_instance_valid(_twin):
		_twin.queue_free()
	_twin = null


func _refresh_label() -> void:
	if _label == null:
		return
	if PuzzleManager.is_solved(puzzle_id):
		_label.text = "Yankı Sunağı · çözüldü"
	else:
		_label.text = "Yankı Sunağı · %s: kaydet" % MobileInputManager.control_name(&"interact")


func _room_id() -> StringName:
	var p: Node = get_parent()
	while p:
		if "room_id" in p:
			return p.get("room_id")
		p = p.get_parent()
	return RoomManager.get_active_room_id()


func _sfx(id: StringName) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(id)


## Test/otomasyon kancası: kaydı doğrudan verilen karelerle başlat.
func debug_play(frames: Array, events: Array) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p:
		_start_pos = p.global_position
	_frames = frames
	_events = events
	_recording = true
	_finish_recording()
