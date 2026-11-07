extends Area2D
## Kan Kristali / Lanet Dikeni — bilerek dokunulursa Noroi ölür ve bedeni plakada kalır.
## İlk "ağırlık cesedi" dersi: kapıyı açık tutmak için kendi cesedini bırak.

@export var anchor_x: float = 340.0 ## ölüm anında bedenin düşeceği x (plaka merkezi)
@export var puzzle_hint: StringName = &"awakening_seal_weight"

var _armed: bool = false


func _ready() -> void:
	add_to_group("blood_thorn")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite2D"
		add_child(spr)
	spr.texture = load("res://assets/props/crystal.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.modulate = Color(1.0, 0.25, 0.32, 1.0)
	spr.scale = Vector2(0.55, 0.7)
	spr.position = Vector2(0, -18)
	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "modulate", Color(1.3, 0.35, 0.4, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "modulate", Color(0.85, 0.2, 0.28, 1.0), 0.9).set_trans(Tween.TRANS_SINE)


func on_interact(by: Node) -> void:
	if DeathManager.is_dying:
		return
	if PuzzleManager.is_solved(puzzle_hint):
		DialogueManager.say("Noroi", "Kristal sustu. Bedenim plakayı tutuyor.")
		return
	if not _armed:
		_armed = true
		DialogueManager.say("Noroi", "Kırmızı kristal… dikenleri nabız gibi atıyor.")
		DialogueManager.say("Noroi", "Dokunursam ölürüm. Ama beden… burada, plakanın üstünde kalır.")
		DialogueManager.say("Noroi", "(Yine dokunursan bilerek ölürsün.)")
		await DialogueManager.dialogue_finished
		return
	_armed = false
	var player := by as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var tw := player.create_tween()
		tw.tween_property(player, "global_position:x", anchor_x, 0.22).set_trans(Tween.TRANS_QUAD)
		await tw.finished
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.5)
	DeathManager.request_death(&"thorn")
