extends Area2D
## Ters kontrol bölgesi: içindeyken oyuncunun yatay girdisi tersine döner.
## Oda çıkışı, ölüm/yeniden doğuş ve bölgeden çıkışta sıfırlanır (player.invert_x).

@export var size: Vector2 = Vector2(400, 200)
@export var enter_line: String = ""

var _inside: bool = false
var _spoke: bool = false


func _ready() -> void:
	add_to_group("control_invert")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	_inside = true
	b.set("invert_x", true)
	if enter_line != "" and not _spoke:
		_spoke = true
		DialogueManager.say("Noroi", enter_line)


func _on_exit(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	_inside = false
	b.set("invert_x", false)


func _exit_tree() -> void:
	if _inside:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			p.set("invert_x", false)
