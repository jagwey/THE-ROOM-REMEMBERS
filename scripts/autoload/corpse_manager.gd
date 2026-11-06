extends Node
## Fiziksel cesetler — max 3. Fazlası çiçek/leke/silüete dönüşür.
## Kullanım kancaları: ağırlık (weight), Echo, hikâye.

signal corpses_changed(count: int)
signal trace_added(trace: Dictionary)

const MAX_CORPSES := 3
const CORPSE_SCENE := preload("res://scenes/world/corpse.tscn")

var _spawned: Array[Node] = []


func _ready() -> void:
	call_deferred("rebuild_world_corpses")


func record_corpse_at(pos: Vector2) -> String:
	var room: StringName = GameState.character_current_life_knowledge.get("room", &"awakening")
	var corpses: Array = GameState.world_memory_state["corpses"]
	var id := "corpse_%d_%d" % [int(GameState.player_progress_knowledge["deaths"]), Time.get_ticks_msec()]
	var entry := {
		"id": id,
		"position": {"x": pos.x, "y": pos.y},
		"room": String(room),
		"life_index": int(GameState.player_progress_knowledge["deaths"]),
		"has_flower": false,
		"echo_id": "echo_%s" % id,
		"weight": 1,
		"usable_for_puzzle": true,
	}
	corpses.append(entry)
	_trim_excess()
	corpses_changed.emit(corpses.size())
	rebuild_world_corpses()
	return id


func record_corpse_at_player() -> String:
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector2.ZERO
	if player:
		pos = player.global_position
	return record_corpse_at(pos)


func _trim_excess() -> void:
	var corpses: Array = GameState.world_memory_state["corpses"]
	var traces: Array = GameState.world_memory_state["traces"]
	while corpses.size() > MAX_CORPSES:
		var old: Dictionary = corpses.pop_front()
		var kind := "stain"
		var n := traces.size() % 3
		if n == 0:
			kind = "flower"
		elif n == 1:
			kind = "silhouette"
		else:
			kind = "stain"
		var trace := {
			"kind": kind,
			"from_corpse": old.get("id", ""),
			"position": old.get("position", {"x": 0, "y": 0}),
			"room": old.get("room", "awakening"),
		}
		traces.append(trace)
		if kind == "flower":
			GameState.world_memory_state["flowers_left"] = int(GameState.world_memory_state["flowers_left"]) + 1
		trace_added.emit(trace)


func get_corpses() -> Array:
	return GameState.world_memory_state["corpses"]


func get_traces() -> Array:
	return GameState.world_memory_state["traces"]


func mark_flower_on_corpse(corpse_id: String) -> void:
	for c in GameState.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == corpse_id:
			c["has_flower"] = true
			GameState.world_memory_state["flowers_left"] = int(GameState.world_memory_state["flowers_left"]) + 1
			break
	rebuild_world_corpses()


func rebuild_world_corpses() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()

	var root := get_tree().get_first_node_in_group("corpses_root")
	if root == null:
		return
	var room := String(GameState.character_current_life_knowledge.get("room", &"awakening"))
	for c in GameState.world_memory_state["corpses"]:
		if not (c is Dictionary):
			continue
		if String(c.get("room", "")) != room:
			continue
		var node: Node = CORPSE_SCENE.instantiate()
		root.add_child(node)
		if node.has_method("setup_from_data"):
			node.setup_from_data(c)
		_spawned.append(node)
	_spawn_traces(root, room)


func _spawn_traces(root: Node, room: String) -> void:
	for t in GameState.world_memory_state["traces"]:
		if not (t is Dictionary):
			continue
		if String(t.get("room", "")) != room:
			continue
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		var pos: Dictionary = t.get("position", {"x": 0, "y": 0})
		spr.position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
		var kind := String(t.get("kind", "stain"))
		match kind:
			"flower":
				spr.texture = load("res://assets/props/red_flower.png")
				spr.modulate = Color(1, 1, 1, 0.95)
			"silhouette":
				spr.texture = load("res://assets/props/body_echo.png")
				spr.modulate = Color(0.4, 0.35, 0.45, 0.45)
			_:
				spr.texture = load("res://assets/props/curse.png")
				spr.modulate = Color(0.5, 0.2, 0.25, 0.35)
				spr.scale = Vector2(0.5, 0.5)
		root.add_child(spr)
		_spawned.append(spr)
