extends Node2D
## Fısıltı'nın yavaş mermisi. Düz gider; zıplayarak veya dash ile (dokunulmazlık) aşılır.
## Vuruş denetimi mesafe tabanlı: oyuncu kutusu (32x36) ile kesişirse receive_hazard_hit çağrılır.

const SPEED := 85.0
const TTL := 4.0

var dir: float = 1.0
var _ttl: float = TTL
var _spent: bool = false


func _ready() -> void:
	add_to_group("soul_projectile")
	var tex: Texture2D = load("res://assets/props/memory_mote.png")
	if tex:
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = Color(0.85, 0.6, 1.0, 0.95)
		add_child(s)
	var halo: Texture2D = load("res://assets/props/halo.png")
	if halo:
		var h := Sprite2D.new()
		h.texture = halo
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.scale = Vector2(0.25, 0.25)
		h.modulate = Color(0.8, 0.5, 1.0, 0.55)
		add_child(h)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	if UiGate.pauses_world_threats() or DeathManager.is_dying:
		return
	step(delta)


## Tek adım (denetimler doğrudan çağırabilir).
func step(delta: float) -> void:
	global_position.x += dir * SPEED * delta
	_ttl -= delta
	if _ttl <= 0.0:
		_spent = true
		queue_free()
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return
	var dx := absf(p.global_position.x - global_position.x)
	var feet_dy := p.global_position.y - global_position.y ## oyuncu ayağı mermiden ne kadar aşağıda
	if dx <= 12.0 and feet_dy >= -4.0 and feet_dy <= 38.0:
		## Dash/dokunulmazlıkta false döner: mermi içinden geçer.
		if p.has_method("receive_hazard_hit") and bool(p.receive_hazard_hit(global_position.x)):
			_spent = true
			queue_free()
