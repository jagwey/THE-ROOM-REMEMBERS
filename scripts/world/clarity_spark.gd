extends Area2D
## ClaritySpark — +%10 Berraklık. Oyuncuya 28px mıknatıs yarıçapıyla çekilir.
## Tüm düşman düşüşleri bu fabrika ile spawn edilmeli (magnet tek yerde).

const MAGNET_RADIUS: float = 28.0
const PULL_SPEED: float = 110.0

var _claimed: bool = false


## Ortak spawn: yürüyen/kalkanlı gölge ve diğer düşman düşüşleri.
static func spawn_at(parent: Node, at: Vector2) -> Area2D:
	if parent == null:
		return null
	var spark := Area2D.new()
	spark.name = "ClaritySpark"
	spark.set_script(load("res://scripts/world/clarity_spark.gd"))
	spark.global_position = at
	var mote := Sprite2D.new()
	mote.texture = load("res://assets/props/memory_mote.png")
	mote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mote.modulate = Color(0.6, 0.9, 1.0, 0.95)
	spark.add_child(mote)
	var halo_tex = load("res://assets/props/halo.png")
	if halo_tex:
		var halo := Sprite2D.new()
		halo.texture = halo_tex
		halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		halo.scale = Vector2(0.35, 0.35)
		halo.modulate = Color(0.4, 0.8, 1.0, 0.5)
		spark.add_child(halo)
	parent.add_child(spark)
	var tw := spark.create_tween().set_loops()
	tw.tween_property(mote, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mote, "scale", Vector2(0.9, 0.9), 0.5).set_trans(Tween.TRANS_SINE)
	return spark


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
	if not body_entered.is_connected(_on_body_entered):
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
