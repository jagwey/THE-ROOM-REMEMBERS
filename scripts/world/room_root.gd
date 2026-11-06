extends "res://scripts/world/room_atmosphere.gd"
## Oda kökü — RoomManager kaydı + Marker2D spawn haritası + bounds/checkpoint.

@export var region_id: StringName = &""
@export var bounds: Rect2 = Rect2(0, 0, 640, 360)
@export var checkpoint: Vector2 = Vector2(120, 288)
@export var checkpoint_room: StringName = &""
@export var atmosphere_bg: String = ""


func _ready() -> void:
	super._ready()
	_register_room()


func _register_room() -> void:
	if RoomManager.has_room(room_id):
		return
	var spawns: Dictionary = {}
	var spawns_parent := get_node_or_null("Spawns") as Node2D
	if spawns_parent:
		for c in spawns_parent.get_children():
			if c is Marker2D:
				spawns[c.name] = (c as Marker2D).global_position
	var cp_room := checkpoint_room if checkpoint_room != &"" else room_id
	RoomManager.register_room(room_id, self, bounds, spawns, checkpoint, cp_room, atmosphere_bg)
