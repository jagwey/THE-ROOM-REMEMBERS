extends Area2D
## Ruh Kesimi dalgası — mühürlü sarmaşık/ruh kapılarını (receive_soul_slash) açar,
## kırılabilirlere de kılıç darbesi gibi vurur.

var direction: float = 1.0
var speed: float = 360.0
var life: float = 0.45
var _hit: Array = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 | 8 | 32
	monitoring = true
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 44)
	shape.shape = rect
	add_child(shape)
	var arc := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(-1.1, 1.1, float(i) / 8.0)
		pts.append(Vector2(cos(a) * 16.0, sin(a) * 22.0))
	for i in range(8, -1, -1):
		var a := lerpf(-1.1, 1.1, float(i) / 8.0)
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 16.0))
	arc.polygon = pts
	arc.color = Color(0.78, 0.6, 1.0, 0.85)
	arc.scale.x = direction
	add_child(arc)
	z_index = 6
	area_entered.connect(_touch)
	body_entered.connect(_touch)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	life -= delta
	modulate.a = clampf(life / 0.2, 0.0, 1.0)
	## Yedek: fizik sorgusu kaçırırsa mühür/duvar hedeflerini mesafeyle yakala.
	for group in ["soul_seal", "cracked_wall"]:
		for t in get_tree().get_nodes_in_group(group):
			if t is Node2D and (t as Node2D).is_visible_in_tree() and not _hit.has(t):
				var d := (t as Node2D).global_position - global_position
				if absf(d.x) < 24.0 and d.y > -20.0 and d.y < 90.0:
					_touch(t)
	if life <= 0.0:
		queue_free()


func _touch(n: Node) -> void:
	var t: Node = n
	if not t.has_method("receive_soul_slash") and not t.has_method("receive_sword_hit"):
		t = n.get_parent()
	if t == null or _hit.has(t):
		return
	_hit.append(t)
	if t.has_method("receive_soul_slash"):
		t.receive_soul_slash(self)
	elif t.has_method("receive_sword_hit"):
		t.receive_sword_hit(self, direction, 1)
