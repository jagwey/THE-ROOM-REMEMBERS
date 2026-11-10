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


func record_corpse_at(pos: Vector2, reason: StringName = &"unknown") -> String:
	var room: StringName = GameState.character_current_life_knowledge.get("room", &"awakening")
	var corpses: Array = GameState.world_memory_state["corpses"]
	var id := "corpse_%d_%d" % [int(GameState.player_progress_knowledge["deaths"]), Time.get_ticks_msec()]
	pos = _snap_to_ground(pos)
	var facing := 1.0
	var trail: Array = []
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("get_facing"):
		facing = float(pl.get_facing())
	if pl and pl.has_method("get_trail"):
		var bounds: Rect2 = RoomManager.get_room_bounds(room)
		for s in pl.get_trail():
			if s is Array and s.size() >= 4 and (bounds.size.x <= 0.0 or bounds.grow(8.0).has_point(Vector2(float(s[0]), float(s[1])))):
				trail.append(s)
	var entry := {
		"id": id,
		"position": {"x": pos.x, "y": pos.y},
		"room": String(room),
		"life_index": int(GameState.player_progress_knowledge["deaths"]),
		"has_flower": false,
		"echo_id": "echo_%s" % id,
		"weight": 1,
		"usable_for_puzzle": true,
		"reason": String(reason),
		"anchored": false,
		"anchoring": false,
		"facing": facing,
		"curse": CurseManager.curse,
		"time_unix": int(Time.get_unix_time_from_system()),
		"trail": trail,
	}
	corpses.append(entry)
	_trim_excess()
	corpses_changed.emit(corpses.size())
	rebuild_world_corpses()
	return id


## Ceset havada/duvarda kalmasın: aşağı ışın (dünya katmanı), cesetler ve oyuncu hariç.
func _snap_to_ground(pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null or vp.world_2d == null:
		return pos
	var space := vp.world_2d.direct_space_state
	if space == null:
		return pos
	var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -6), pos + Vector2(0, 160), 1)
	var ex: Array[RID] = []
	for n in get_tree().get_nodes_in_group("corpse"):
		if n is CollisionObject2D:
			ex.append((n as CollisionObject2D).get_rid())
	var pl := get_tree().get_first_node_in_group("player")
	if pl is CollisionObject2D:
		ex.append((pl as CollisionObject2D).get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return pos
	return Vector2(pos.x, (hit["position"] as Vector2).y)


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
		## Aktif bulmacayı tutan cesetler silinmez.
		var idx := -1
		for i in corpses.size():
			var c: Dictionary = corpses[i] as Dictionary
			if not bool(c.get("anchoring", false)) and not bool(c.get("anchored", false)):
				idx = i
				break
		if idx < 0:
			# Tüm cesetler plakalarda kilitli/anchored; bulmacayı bozmamak için hepsi korunur
			break
		var old: Dictionary = corpses.pop_at(idx)
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


func set_corpse_anchored(corpse_id: String, anchored: bool = true) -> void:
	for c in GameState.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == corpse_id:
			c["anchored"] = anchored
			c["anchoring"] = anchored
			break
	for node in _spawned:
		if is_instance_valid(node) and "corpse_id" in node and String(node.corpse_id) == corpse_id:
			if node.has_method("set_anchored"):
				node.set_anchored(anchored)
			elif node.has_method("set_anchoring"):
				node.set_anchoring(anchored)
			elif "is_anchored" in node:
				node.is_anchored = anchored


func mark_flower_on_corpse(corpse_id: String) -> void:
	for c in GameState.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == corpse_id:
			c["has_flower"] = true
			GameState.world_memory_state["flowers_left"] = int(GameState.world_memory_state["flowers_left"]) + 1
			break
	rebuild_world_corpses()


func _find_active_corpses_root() -> Node:
	## Aktif odanın corpses_root'unu seç — gruptaki ilk (çoğunlukla Uyanış) değil.
	var active_id := RoomManager.get_active_room_id()
	var room := String(active_id) if active_id != &"" else String(GameState.character_current_life_knowledge.get("room", &"awakening"))
	var fallback: Node = null
	for n in get_tree().get_nodes_in_group("corpses_root"):
		if fallback == null:
			fallback = n
		var room_node := _find_room_ancestor(n)
		if room_node == null:
			continue
		var rid: StringName = room_node.get("room_id") if "room_id" in room_node else &""
		if String(rid) == room:
			# Görünmez/disabled odaya ekleme
			if room_node is CanvasItem and not (room_node as CanvasItem).visible:
				continue
			if room_node.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			return n
	return fallback


func _find_room_ancestor(n: Node) -> Node:
	var p: Node = n
	while p:
		if p.get_script() != null and p.get("room_id") != null:
			return p
		p = p.get_parent()
	return null


func rebuild_world_corpses() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()

	var root := _find_active_corpses_root()
	if root == null:
		return
	var active_id := RoomManager.get_active_room_id()
	var room := String(active_id) if active_id != &"" else String(GameState.character_current_life_knowledge.get("room", &"awakening"))
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
	for p in get_tree().get_nodes_in_group("pressure_plate"):
		if p.has_method("_recompute"):
			p._recompute()


func _spawn_traces(root: Node, room: String) -> void:
	var script: Script = load("res://scripts/world/trace_marker.gd")
	for t in GameState.world_memory_state["traces"]:
		if not (t is Dictionary):
			continue
		if String(t.get("room", "")) != room:
			continue
		var marker := Area2D.new()
		marker.set_script(script)
		root.add_child(marker)
		if marker.has_method("setup"):
			marker.setup(t)
		_spawned.append(marker)
