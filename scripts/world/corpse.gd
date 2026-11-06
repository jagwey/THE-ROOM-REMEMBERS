extends StaticBody2D
## Fiziksel ceset — ağırlık bulmacası / Echo / hikâye kancası (FAZ 4 stub).

@export var corpse_id: String = ""
@export var echo_id: StringName = &""
@export var weight: int = 1
@export var usable_for_puzzle: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var flower: Sprite2D = $Flower
@onready var interact: Area2D = $InteractArea

var _data: Dictionary = {}


func _ready() -> void:
	add_to_group("corpse")
	collision_layer = 1
	collision_mask = 0
	if interact:
		interact.collision_layer = 8
		interact.collision_mask = 0


func setup_from_data(data: Dictionary) -> void:
	_data = data
	corpse_id = String(data.get("id", ""))
	echo_id = StringName(String(data.get("echo_id", "echo_%s" % corpse_id)))
	weight = int(data.get("weight", 1))
	usable_for_puzzle = bool(data.get("usable_for_puzzle", true))
	var pos: Dictionary = data.get("position", {"x": 0, "y": 0})
	global_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	if sprite:
		sprite.texture = load("res://assets/props/body_echo.png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.offset = Vector2(0, -20)
	if flower:
		flower.texture = load("res://assets/props/red_flower.png")
		flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flower.visible = bool(data.get("has_flower", false))
		flower.position = Vector2(10, -8)


func on_interact(_by: Node) -> void:
	## Echo stub + ağırlık ipucu (FAZ 5 tam yankı).
	DialogueManager.say("Sen", "…Bu beden… benim miydi?")
	if usable_for_puzzle:
		DialogueManager.say("Sen", "Ağır… bir şeyi tutabilir.")
	if echo_id != &"":
		EchoManager.play_echo(echo_id)


func get_weight() -> int:
	## Weight-puzzle stub API.
	return weight if usable_for_puzzle else 0
