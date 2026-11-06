extends Node
## Fiziksel cesetler — max 3. Ağırlık bulmacası / Echo / hikâye için stub.

signal corpses_changed(count: int)

const MAX_CORPSES := 3


func record_corpse_at_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector2.ZERO
	var room: StringName = GameState.character_current_life_knowledge.get("room", &"awakening")
	if player:
		pos = player.global_position
	var corpses: Array = GameState.world_memory_state["corpses"]
	corpses.append({
		"position": {"x": pos.x, "y": pos.y},
		"room": String(room),
		"life_index": GameState.player_progress_knowledge["deaths"],
	})
	while corpses.size() > MAX_CORPSES:
		corpses.pop_front()
	corpses_changed.emit(corpses.size())


func get_corpses() -> Array:
	return GameState.world_memory_state["corpses"]
