extends Node
## Lanet — erken HUD yok; VFX/fısıltı. 100% → fail life (checkpoint), full reset yok.

signal curse_changed(value: float)
signal curse_failed_life
signal curse_stage_changed(stage: int)
signal curse_whisper(text: String)

var curse: float = 0.0
const CURSE_MAX := 100.0
var visible_meter: bool = false ## erken: kapalı; geç: küçük mühür
var stage: int = 0 ## 0–3
var _failing: bool = false


func add_curse(amount: float, reason: StringName = &"") -> void:
	if amount <= 0.0 or _failing:
		return
	var prev := curse
	curse = clampf(curse + amount, 0.0, CURSE_MAX)
	curse_changed.emit(curse)
	if reason != &"":
		var touched: Array = GameState.world_memory_state["forbidden_touched"]
		var key := String(reason)
		if not touched.has(key):
			touched.append(key)
	_update_stage(prev)
	# Geç oyun: küçük gösterge
	if curse >= 55.0:
		visible_meter = true
	if curse >= CURSE_MAX:
		_fail_life()


func clear_curse(amount: float) -> void:
	if amount <= 0.0 or _failing:
		return
	var prev := curse
	curse = clampf(curse - amount, 0.0, CURSE_MAX)
	curse_changed.emit(curse)
	_update_stage(prev)


func _update_stage(prev: float) -> void:
	var new_stage := 0
	if curse >= 75.0:
		new_stage = 3
	elif curse >= 50.0:
		new_stage = 2
	elif curse >= 25.0:
		new_stage = 1
	if new_stage != stage:
		stage = new_stage
		curse_stage_changed.emit(stage)
		match stage:
			1:
				curse_whisper.emit("…kulaklarında uğultu.")
			2:
				curse_whisper.emit("Kırmızı… her yerde.")
			3:
				curse_whisper.emit("Dayanamıyorum—")
			_:
				pass
	# Eşik geçiş fısıltıları
	if prev < 40.0 and curse >= 40.0:
		curse_whisper.emit("Bir şey… içimde büyüyor.")


func _fail_life() -> void:
	if _failing:
		return
	_failing = true
	curse_failed_life.emit()
	DialogueManager.clear()
	var reason: StringName = &"curse"
	var keeper := get_tree().get_first_node_in_group("keeper")
	if keeper and keeper.has_method("can_mercy_kill") and keeper.can_mercy_kill():
		## Shilda yakında: Noroi'yi Çekirdek'e kaptırmamak için kendisi öldürür.
		await keeper.mercy_kill()
		reason = &"mercy"
	else:
		## Tam ele geçirilme: kısa sahne; kalıcı bulmacalar silinmez, son güvenli kayıttan dönülür.
		DialogueManager.whisper("Çekirdek", "Gel… bana gel.")
		DialogueManager.whisper("Noroi", "Bu… benim sesim değil—")
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var tw := player.create_tween()
			tw.tween_property(player, "modulate", Color(1.6, 0.2, 0.3, 1.0), 0.5)
		GameState.player_progress_knowledge["possession_seen"] = true
		await get_tree().create_timer(0.35 if DisplayServer.get_name() == "headless" else 1.2).timeout
		if DialogueManager.is_open:
			DialogueManager.clear()
	curse = 0.0
	stage = 0
	visible_meter = false
	curse_changed.emit(curse)
	curse_stage_changed.emit(stage)
	# Full reset YOK — dünya kalır.
	DeathManager.request_death(reason, false)
	await DeathManager.rebirth_completed
	_failing = false


func reset_for_new_life() -> void:
	curse = 0.0
	stage = 0
	# Gösterge: meta olarak en az bir kez 55+ gördüyse açık kalabilir
	if not bool(GameState.player_progress_knowledge.get("curse_indicator_seen", false)):
		visible_meter = false
	curse_changed.emit(curse)
	curse_stage_changed.emit(stage)


func unlock_indicator() -> void:
	visible_meter = true
	GameState.player_progress_knowledge["curse_indicator_seen"] = true
