extends Node
## Lanet ölçeri — erken oyunda gizli; VFX/SFX için sinyal verir. Fail life → checkpoint.

signal curse_changed(value: float)
signal curse_failed_life

var curse: float = 0.0
const CURSE_MAX := 100.0
var visible_meter: bool = false ## erken oyun: false


func add_curse(amount: float, reason: StringName = &"") -> void:
	if amount <= 0.0:
		return
	curse = clampf(curse + amount, 0.0, CURSE_MAX)
	curse_changed.emit(curse)
	if reason != &"":
		var touched: Array = GameState.world_memory_state["forbidden_touched"]
		var key := String(reason)
		if not touched.has(key):
			touched.append(key)
	if curse >= CURSE_MAX:
		_fail_life()


func _fail_life() -> void:
	curse = 0.0
	curse_changed.emit(curse)
	curse_failed_life.emit()
	DeathManager.request_death(&"curse", false) ## full reset değil


func reset_for_new_life() -> void:
	curse = 0.0
	curse_changed.emit(curse)
