extends Area2D
## SoulSpark — Parçalanmış ruhun kıvılcımı. Dokunulunca ruh toplanır (+%10 Berraklık).
## ~5 sn içinde alınmazsa kaybolur; ruh geri döner ve düşman yeniden belirir.

const MAGNET_RADIUS: float = 36.0
const PULL_SPEED: float = 120.0
const LIFETIME: float = 5.0

var soul_id: String = ""
var _ttl: float = LIFETIME
var _claimed: bool = false
var _expired: bool = false
var mote: Sprite2D


static func spawn_at(parent: Node, at: Vector2, p_soul_id: String) -> Area2D:
	if parent == null:
		return null
	var spark := Area2D.new()
	spark.name = "SoulSpark"
	spark.set_script(load("res://scripts/world/soul_spark.gd"))
	spark.set("soul_id", p_soul_id)
	spark.add_to_group("soul_spark")
	parent.add_child(spark)
	spark.global_position = at
	return spark


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 ## LAYER_PLAYER
	monitoring = true
	monitorable = false
	mote = Sprite2D.new()
	mote.texture = load("res://assets/props/memory_mote.png")
	mote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mote.modulate = Color(0.85, 0.95, 1.0, 0.98)
	add_child(mote)
	var halo_tex = load("res://assets/props/halo.png")
	if halo_tex:
		var halo := Sprite2D.new()
		halo.texture = halo_tex
		halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		halo.scale = Vector2(0.4, 0.4)
		halo.modulate = Color(0.7, 0.8, 1.0, 0.55)
		add_child(halo)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = MAGNET_RADIUS
	cs.shape = circle
	add_child(cs)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	var tw := create_tween().set_loops()
	tw.tween_property(mote, "scale", Vector2(1.25, 1.25), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mote, "scale", Vector2(0.9, 0.9), 0.4).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	step(delta)


## Tek adım (denetimler doğrudan çağırabilir). Ömür, UI/ölüm kapısında akmaz.
func step(delta: float) -> void:
	if _claimed or _expired:
		return
	if UiGate.pauses_world_threats() or DeathManager.is_dying:
		return
	_ttl -= delta
	if mote:
		mote.modulate.a = 0.98 if _ttl > 1.5 else (0.45 + 0.5 * absf(sin(_ttl * 14.0)))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and is_instance_valid(player):
		var target := player.global_position + Vector2(0, -16)
		var dist := (target - global_position).length()
		if dist <= MAGNET_RADIUS and dist > 0.5:
			global_position = global_position.move_toward(target, PULL_SPEED * delta)
		if dist <= 14.0:
			claim()
			return
	if _ttl <= 0.0:
		expire()


func time_left() -> float:
	return _ttl


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		claim()


func claim() -> void:
	if _claimed or _expired:
		return
	_claimed = true
	SoulManager.collect(soul_id)
	CurseManager.clear_curse(10.0)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"seal_open")
	## Modal diyalog yerine savaşı kesmeyen, yükselip sönen dünya yazısı.
	_float_label("Ruh serbest · +%10 Berraklık")
	queue_free()


func _float_label(text: String) -> void:
	var host := get_parent()
	if host == null:
		return
	var lbl := Label.new()
	lbl.name = "SoulFreedLabel"
	lbl.text = text
	lbl.add_to_group("soul_float_label")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.size = Vector2(260, 28)
	var at := global_position
	if host is Node2D:
		at = (host as Node2D).to_local(at)
	lbl.position = at - Vector2(130, 70)
	lbl.z_index = 50
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, 1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.6).set_delay(0.5)
	tw.chain().tween_callback(lbl.queue_free)


func expire() -> void:
	if _claimed or _expired:
		return
	_expired = true
	var root := get_parent()
	var sid := soul_id
	var at := global_position
	queue_free()
	SoulManager.on_spark_expired(sid, root, at)
