extends Node
## Merkezi oda geçişi — tek aktif oda (görünür + işlem); kamera sınırı; ceset yenileme.

signal room_changed(from_room: StringName, to_room: StringName)

## Oda meta: bounds, isimli spawn, checkpoint (spawn yoksa), atmosfer klasörü, sahne kökü.
var _rooms: Dictionary = {} ## StringName -> { root, bounds, spawns, checkpoint, checkpoint_room, atmosphere_bg }

var _current: StringName = &""
var _extra_bootstrapped: bool = false

## Ek odalar — `main.tscn` dokunulmadan yüklenir (sahne kökü `World` altına eklenir).
const EXTRA_ROOM_SCENE_PATHS: PackedStringArray = [
	"res://scenes/rooms/library_hall.tscn",
	"res://scenes/rooms/library_witness.tscn",
	"res://scenes/rooms/library_page.tscn",
	"res://scenes/rooms/experiment_cells.tscn",
	"res://scenes/rooms/experiment_circuit.tscn",
	"res://scenes/rooms/experiment_authority.tscn",
	"res://scenes/rooms/mirrors_reverse.tscn",
	"res://scenes/rooms/mirrors_dual.tscn",
	"res://scenes/rooms/mirrors_unbroken.tscn",
	"res://scenes/rooms/core_threshold.tscn",
	"res://scenes/rooms/core_seal_chamber.tscn",
]


func _ready() -> void:
	call_deferred("_bootstrap_extra_rooms")


func _bootstrap_extra_rooms() -> void:
	if _extra_bootstrapped:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var world := main.get_node_or_null("World") as Node
	if world == null:
		push_warning("RoomManager: Main içinde World yok; ek odalar yüklenemedi.")
		return
	for path in EXTRA_ROOM_SCENE_PATHS:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			push_warning("RoomManager: sahne yüklenemedi %s" % path)
			continue
		var inst := scene.instantiate() as Node2D
		if inst == null:
			continue
		## Sahne kökünün adı (ör. LibraryHall) main.gd ROOM_DEFS["node"] ile eşleşmeli — dosya adı değil.
		if world.has_node(NodePath(StringName(inst.name))):
			inst.queue_free()
			continue
		inst.visible = false
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(inst)
	_extra_bootstrapped = true


func register_room(
		room_id: StringName,
		root: Node2D,
		bounds: Rect2,
		spawns: Dictionary = {},
		checkpoint: Vector2 = Vector2.ZERO,
		checkpoint_room: StringName = &"",
		atmosphere_bg: String = ""
	) -> void:
	if root == null:
		push_warning("RoomManager.register_room: root null for %s" % String(room_id))
		return
	var cp_room := checkpoint_room if checkpoint_room != &"" else room_id
	var entry := {
		"root": root,
		"bounds": bounds,
		"spawns": spawns,
		"checkpoint": checkpoint,
		"checkpoint_room": cp_room,
		"atmosphere_bg": atmosphere_bg,
	}
	_rooms[room_id] = entry


func has_room(room_id: StringName) -> bool:
	return _rooms.has(room_id)


func get_active_room_id() -> StringName:
	return _current


func get_room_bounds(room_id: StringName) -> Rect2:
	var e: Variant = _rooms.get(room_id, null)
	if e == null:
		return Rect2()
	return e["bounds"] as Rect2


func enter_room(room_id: StringName, spawn_id: StringName = &"default", apply_room_checkpoint: bool = true) -> void:
	if not _rooms.has(room_id):
		push_warning("RoomManager.enter_room: unknown room %s" % String(room_id))
		return
	var from_id := _current
	_deactivate_all_rooms()
	_current = room_id
	var entry: Dictionary = _rooms[room_id]
	var root: Node2D = entry["root"]
	if root:
		root.visible = true
		root.process_mode = Node.PROCESS_MODE_INHERIT

	var bounds: Rect2 = entry["bounds"]
	var spawns: Dictionary = entry["spawns"]
	var spawn_pos: Vector2
	if spawn_id == &"checkpoint":
		spawn_pos = GameState.get_checkpoint()
	else:
		spawn_pos = spawns.get(spawn_id, Vector2.ZERO) as Vector2
		if spawn_pos == Vector2.ZERO:
			spawn_pos = entry["checkpoint"] as Vector2
		if spawn_pos == Vector2.ZERO:
			spawn_pos = Vector2(bounds.position.x + bounds.size.x * 0.5, 288.0)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = spawn_pos

	GameState.character_current_life_knowledge["spawn_id"] = spawn_id
	GameState.mark_room_visited(room_id)

	if apply_room_checkpoint:
		var cp: Vector2 = entry["checkpoint"] as Vector2
		var cp_room: StringName = entry["checkpoint_room"] as StringName
		if cp != Vector2.ZERO:
			GameState.set_checkpoint(cp, cp_room)

	_apply_camera(bounds)

	CorpseManager.rebuild_world_corpses()
	if from_id != &"" and from_id != room_id:
		room_changed.emit(from_id, room_id)


func _deactivate_all_rooms() -> void:
	for k in _rooms.keys():
		var entry: Dictionary = _rooms[k]
		var root: Node2D = entry["root"] as Node2D
		if root == null:
			continue
		root.visible = false
		root.process_mode = Node.PROCESS_MODE_DISABLED


func apply_initial_room(room_id: StringName, spawn_id: StringName = &"default", teleport_to_spawn: bool = true) -> void:
	## İlk yüklemede sinyal dökme — sadece durum kur. Kayıt yüklendiyse teleport false (konum zaten cp).
	if not _rooms.has(room_id):
		push_warning("RoomManager.apply_initial_room: unknown %s" % String(room_id))
		return
	_deactivate_all_rooms()
	_current = room_id
	var entry: Dictionary = _rooms[room_id]
	var root: Node2D = entry["root"]
	if root:
		root.visible = true
		root.process_mode = Node.PROCESS_MODE_INHERIT

	var bounds: Rect2 = entry["bounds"]
	if teleport_to_spawn:
		var spawns: Dictionary = entry["spawns"]
		var spawn_pos: Vector2
		if spawn_id == &"checkpoint":
			spawn_pos = GameState.get_checkpoint()
		else:
			spawn_pos = spawns.get(spawn_id, Vector2.ZERO) as Vector2
			if spawn_pos == Vector2.ZERO:
				spawn_pos = entry["checkpoint"] as Vector2
			if spawn_pos == Vector2.ZERO:
				spawn_pos = Vector2(bounds.position.x + bounds.size.x * 0.5, 288.0)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			player.global_position = spawn_pos

	_apply_camera(bounds)

	CorpseManager.rebuild_world_corpses()


func _apply_camera(bounds: Rect2) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera") as Camera2D
	if cam == null:
		return
	if cam.has_method("set_room_bounds"):
		cam.set_room_bounds(bounds)
	if cam.has_method("snap_to_target"):
		cam.snap_to_target()
