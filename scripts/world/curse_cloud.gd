extends Area2D
## Yoğun kırmızı lanet bulutu — canlı girersen saniyede +50 lanet.
## İçinde ölmüş bir bedenin (ceset) etrafındaki safe_radius px laneti sünger gibi emer:
## orada güvenli bir koridor açılır (Lanet Paratoneri).

@export var size: Vector2 = Vector2(420, 150)
@export var curse_per_second: float = 50.0
@export var safe_radius: float = 120.0

var _player_inside: bool = false
var _t: float = 0.0
var _puffs: Array = []


func _ready() -> void:
	add_to_group("curse_cloud")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = Vector2(0, -size.y * 0.5)
	add_child(cs)
	body_entered.connect(func(b): if b.is_in_group("player"): _player_inside = true)
	body_exited.connect(func(b): if b.is_in_group("player"): _player_inside = false)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name))
	for i in 34:
		_puffs.append([Vector2(rng.randf_range(-size.x * 0.5, size.x * 0.5), rng.randf_range(-size.y, 0)), rng.randf_range(18, 34), rng.randf() * TAU])
	z_index = 4


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if not _player_inside or UiGate.pauses_world_threats() or DeathManager.is_dying:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if _is_safe(player.global_position):
		return
	if player.has_method("is_shadow_dashing") and player.is_shadow_dashing():
		return
	CurseManager.add_curse(curse_per_second * delta, &"curse_cloud")


func _is_safe(at: Vector2) -> bool:
	for c in get_tree().get_nodes_in_group("corpse"):
		if c is Node2D and (c as Node2D).is_visible_in_tree() and _contains((c as Node2D).global_position):
			if absf((c as Node2D).global_position.x - at.x) <= safe_radius:
				return true
	return false


func _contains(p: Vector2) -> bool:
	var local := to_local(p)
	return absf(local.x) <= size.x * 0.5 + 8.0 and local.y <= 8.0 and local.y >= -size.y - 8.0


func _draw() -> void:
	var corpses: Array = []
	for c in get_tree().get_nodes_in_group("corpse"):
		if c is Node2D and (c as Node2D).is_visible_in_tree() and _contains((c as Node2D).global_position):
			corpses.append(to_local((c as Node2D).global_position).x)
	for p in _puffs:
		var pos: Vector2 = p[0] + Vector2(sin(_t * 0.6 + p[2]) * 8.0, cos(_t * 0.4 + p[2]) * 4.0)
		var a := 0.22 + 0.08 * sin(_t * 1.3 + p[2])
		for cx in corpses:
			var d := absf(pos.x - float(cx))
			if d < safe_radius:
				a *= clampf((d - safe_radius * 0.6) / (safe_radius * 0.4), 0.0, 1.0)
		if a > 0.01:
			draw_circle(pos, float(p[1]), Color(0.72, 0.08, 0.16, a))
