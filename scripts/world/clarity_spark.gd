extends Area2D
## ClaritySpark — +%10 Berraklık. Oyuncuya 28px mıknatıs yarıçapıyla çekilir.

const MAGNET_RADIUS: float = 28.0
const PULL_SPEED: float = 110.0

var _claimed: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 ## LAYER_PLAYER
	monitoring = true
	monitorable = false
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = MAGNET_RADIUS
		cs.shape = circle
		add_child(cs)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _claimed:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var d := player.global_position - global_position
	var dist := d.length()
	if dist <= MAGNET_RADIUS and dist > 0.5:
		global_position = global_position.move_toward(player.global_position + Vector2(0, -16), PULL_SPEED * delta)
	if dist <= 10.0:
		_claim()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_claim()


func _claim() -> void:
	if _claimed:
		return
	_claimed = true
	CurseManager.clear_curse(10.0)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"seal_open")
	DialogueManager.whisper("Noroi", "+%10 Berraklık")
	queue_free()
