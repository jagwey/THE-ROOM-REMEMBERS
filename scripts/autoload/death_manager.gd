extends Node
## Ölüm / yeniden doğuş stub. Karakter bilgisi sıfırlanır; dünya kalır.

signal death_started(reason: StringName)
signal rebirth_completed

var is_dying: bool = false


func request_death(reason: StringName = &"unknown", full_reset: bool = false) -> void:
	if is_dying:
		return
	is_dying = true
	death_started.emit(reason)
	GameState.player_progress_knowledge["deaths"] = int(GameState.player_progress_knowledge["deaths"]) + 1
	CorpseManager.record_corpse_at_player()
	GameState.reset_character_life()
	CurseManager.reset_for_new_life()
	if full_reset:
		# Sadece özel sonlar — erken oyunda kullanılmaz.
		pass
	await get_tree().create_timer(0.35).timeout
	_respawn()


func _respawn() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("respawn_at"):
		var cp: Vector2 = GameState.character_current_life_knowledge.get("checkpoint", Vector2(120, 280))
		player.respawn_at(cp)
	is_dying = false
	rebirth_completed.emit()
