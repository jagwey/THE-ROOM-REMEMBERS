extends Area2D
## Yetenek / mühür parçası sunağı. Etkileşince player_progress_knowledge[grant_key] = true,
## ya da world flag (seal_shard_*) yazar. Bir kez alınır.

@export var grant_key: String = "ability_soul_slash"
@export var grant_world_flag: StringName = &""
@export var title: String = "Ruh Kesimi"
@export var texture_path: String = "res://assets/props/halo.png"
@export var tint: Color = Color(0.8, 0.6, 1.0, 1.0)
@export var lines: PackedStringArray = PackedStringArray()
@export var tutorial: String = ""

var _spr: Sprite2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 56)
	cs.shape = rect
	cs.position = Vector2(0, -16)
	add_child(cs)
	_spr = Sprite2D.new()
	_spr.texture = load(texture_path)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.modulate = tint
	_spr.position = Vector2(0, -28)
	_spr.scale = Vector2(0.7, 0.7)
	add_child(_spr)
	var tw := _spr.create_tween().set_loops()
	tw.tween_property(_spr, "position:y", -34.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_spr, "position:y", -26.0, 1.1).set_trans(Tween.TRANS_SINE)
	if is_taken():
		_spr.modulate = Color(0.4, 0.38, 0.45, 0.5)


func is_taken() -> bool:
	if grant_world_flag != &"":
		return bool(GameState.get_world_flag(grant_world_flag, false))
	return bool(GameState.player_progress_knowledge.get(grant_key, false))


func on_interact(_by: Node) -> void:
	if is_taken():
		DialogueManager.say("Noroi", "Buradaki ışık artık bende.")
		return
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("zoom_to"):
		cam.zoom_to(1.22, 3.0)
	for l in lines:
		var parts := l.split("|", true, 1)
		if parts.size() == 2:
			DialogueManager.say(parts[0], parts[1])
		else:
			DialogueManager.say("Noroi", l)
	DialogueManager.say("", "%s kazanıldı." % title)
	if tutorial != "":
		var tip := tutorial.replace("%DASH%", MobileInputManager.control_name(&"dash"))
		tip = tip.replace("X / Dash", MobileInputManager.control_name(&"dash"))
		tip = tip.replace("X / Atıl", MobileInputManager.control_name(&"dash"))
		DialogueManager.say("", tip)
	if grant_world_flag != &"":
		GameState.set_world_flag(grant_world_flag, true)
	else:
		GameState.player_progress_knowledge[grant_key] = true
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("stinger"):
		am.stinger(&"discovery")
	_spr.modulate = Color(0.4, 0.38, 0.45, 0.5)
	SaveManager.save_game()
	await DialogueManager.dialogue_finished
