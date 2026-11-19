extends Area2D
## Vana: etkileşimde bağlı WaterLevel'ı `delta` kadar kaydırır.

@export var water: NodePath
@export var delta: int = 1

const COOLDOWN_MSEC := 300
var _last_use_msec: int = -COOLDOWN_MSEC


func _ready() -> void:
	add_to_group("valve")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_interact_label() -> String:
	return "Vana ↑" if delta > 0 else "Vana ↓"


## Sınırdaki vana (ör. dipte "↓") hiçbir şey yapmaz; hedef olmasın ki üst üste duran
## sayfa / plaka seçilebilsin (Sarnıç: dipteki sayfa ortadaki vananın tam altında).
func can_interact() -> bool:
	var w := get_node_or_null(water)
	if w == null:
		return false
	var lvl := int(w.get("level"))
	var lo := 0 if bool(w.get("drain_open")) else 1
	return clampi(lvl + delta, lo, 3) != lvl


func on_interact(_by: Node) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_use_msec < COOLDOWN_MSEC:
		return
	var w := get_node_or_null(water)
	if w == null:
		push_warning("valve '%s': water node not found (%s)" % [name, water])
		return
	if w.has_method("step"):
		_last_use_msec = now
		w.step(delta)
