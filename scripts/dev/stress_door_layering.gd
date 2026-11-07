extends SceneTree
## Empirical Stress Test: Feature 2 (Gothic Door Visual Layering Across All 30 Rooms)
## Run: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/stress_door_layering.gd

var failures := 0
var tests_run := 0

const ROOM_PATHS: Array[String] = [
	"res://scenes/rooms/awakening.tscn",
	"res://scenes/rooms/awakening_balcony.tscn",
	"res://scenes/rooms/awakening_crypt.tscn",
	"res://scenes/rooms/awakening_passage.tscn",
	"res://scenes/rooms/awakening_seal.tscn",
	"res://scenes/rooms/core.tscn",
	"res://scenes/rooms/core_bloom_garden.tscn",
	"res://scenes/rooms/core_memory_vault.tscn",
	"res://scenes/rooms/core_seal_chamber.tscn",
	"res://scenes/rooms/core_threshold.tscn",
	"res://scenes/rooms/decay_catacombs.tscn",
	"res://scenes/rooms/decay_garden.tscn",
	"res://scenes/rooms/decay_shilda_wall.tscn",
	"res://scenes/rooms/decay_vines.tscn",
	"res://scenes/rooms/decay_weight.tscn",
	"res://scenes/rooms/experiment_authority.tscn",
	"res://scenes/rooms/experiment_cells.tscn",
	"res://scenes/rooms/experiment_circuit.tscn",
	"res://scenes/rooms/experiment_core_conduit.tscn",
	"res://scenes/rooms/experiment_quarantine.tscn",
	"res://scenes/rooms/library_forbidden_wing.tscn",
	"res://scenes/rooms/library_hall.tscn",
	"res://scenes/rooms/library_page.tscn",
	"res://scenes/rooms/library_upper_stacks.tscn",
	"res://scenes/rooms/library_witness.tscn",
	"res://scenes/rooms/mirrors_dual.tscn",
	"res://scenes/rooms/mirrors_labyrinth.tscn",
	"res://scenes/rooms/mirrors_reverse.tscn",
	"res://scenes/rooms/mirrors_shrine.tscn",
	"res://scenes/rooms/mirrors_unbroken.tscn",
]

func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run_audit")

func check(ok: bool, label: String, detail: String = "") -> void:
	tests_run += 1
	if ok:
		print("DOOR_AUDIT PASS [%03d] %s" % [tests_run, label])
	else:
		failures += 1
		print("DOOR_AUDIT FAIL [%03d] %s :: %s" % [tests_run, label, detail])

func _get_effective_z(node: CanvasItem) -> int:
	var z := node.z_index
	if node.z_as_relative:
		var p := node.get_parent()
		while p is CanvasItem:
			z += (p as CanvasItem).z_index
			if not (p as CanvasItem).z_as_relative:
				break
			p = p.get_parent()
	return z

func _run_audit() -> void:
	print("=== STARTING 30-ROOM GOTHIC DOOR LAYERING STRESS AUDIT ===")
	check(ROOM_PATHS.size() == 30, "Exactly 30 room scenes defined for audit")
	
	var total_doors := 0
	var rooms_with_doors := 0
	var room_door_counts := {}
	
	for path in ROOM_PATHS:
		var room_name := path.get_file().get_basename()
		var scene: PackedScene = load(path)
		check(scene != null, "Room scene loaded successfully: " + room_name)
		if scene == null:
			continue
		
		var instance: Node = scene.instantiate()
		root.add_child(instance)
		await process_frame
		
		# Find all background elements in the room
		var max_bg_z := -9999
		for child in instance.find_children("*", "Node", true, false):
			var cname := String(child.name).to_lower()
			var is_bg := false
			if child.is_class("Parallax2D") or child.is_class("ParallaxBackground") or child.is_class("ParallaxLayer"):
				is_bg = true
			elif cname.contains("background") or cname.contains("parallax") or cname.contains("bg"):
				is_bg = true
			elif child is Sprite2D and (child as Sprite2D).texture:
				var tpath := String((child as Sprite2D).texture.resource_path).to_lower()
				if tpath.contains("/backgrounds/"):
					is_bg = true
			if is_bg and child is CanvasItem:
				var eff_z := _get_effective_z(child as CanvasItem)
				if eff_z > max_bg_z:
					max_bg_z = eff_z
			elif is_bg and child is CanvasLayer:
				var lyr_z := (child as CanvasLayer).layer
				if lyr_z > max_bg_z:
					max_bg_z = lyr_z
		
		if max_bg_z == -9999:
			max_bg_z = 0 # default fallback parallax at z=0
		
		# Find all doors in the room
		var doors_in_room := []
		for child in instance.find_children("*", "Area2D", true, false):
			var scr = child.get_script()
			if scr and String(scr.resource_path).ends_with("room_transition.gd"):
				doors_in_room.append(child)
		
		room_door_counts[room_name] = doors_in_room.size()
		if doors_in_room.size() > 0:
			rooms_with_doors += 1
			total_doors += doors_in_room.size()
			
			for door in doors_in_room:
				var door_name: String = door.name
				var target: String = String(door.target_room_id)
				var d_label := "%s::%s (-> %s)" % [room_name, door_name, target]
				
				# 1. Collision layer
				check(door.collision_layer == 8, "%s collision_layer == 8 (Interact)" % d_label, "actual: %d" % door.collision_layer)
				
				# 2. Door layers exist
				var back: Sprite2D = door.get_node_or_null("DoorBack")
				var inner_light: Sprite2D = door.get_node_or_null("DoorInnerLight")
				var frame: Sprite2D = door.get_node_or_null("DoorFrame")
				var seal: Sprite2D = door.get_node_or_null("DoorSeal")
				var label: Label = door.get_node_or_null("DoorLabel")
				
				check(back != null, "%s has DoorBack" % d_label)
				check(inner_light != null, "%s has DoorInnerLight" % d_label)
				check(frame != null, "%s has DoorFrame" % d_label)
				check(seal != null, "%s has DoorSeal" % d_label)
				check(label != null, "%s has DoorLabel" % d_label)
				
				# 3. Z-Index of components
				if back:
					var back_eff_z := _get_effective_z(back)
					check(back.z_index >= 1, "%s DoorBack local z_index >= 1" % d_label, "actual: %d" % back.z_index)
					check(back_eff_z >= 1, "%s DoorBack effective z_index >= 1" % d_label, "actual: %d" % back_eff_z)
					check(back_eff_z > max_bg_z, "%s DoorBack above parallax bg (eff_z=%d > bg_z=%d)" % [d_label, back_eff_z, max_bg_z])
				
				if inner_light:
					var light_eff_z := _get_effective_z(inner_light)
					check(inner_light.z_index >= 1, "%s DoorInnerLight local z_index >= 1" % d_label, "actual: %d" % inner_light.z_index)
					check(light_eff_z >= 1, "%s DoorInnerLight effective z_index >= 1" % d_label, "actual: %d" % light_eff_z)
				
				if frame:
					var frame_eff_z := _get_effective_z(frame)
					check(frame.z_index >= 1, "%s DoorFrame local z_index >= 1" % d_label, "actual: %d" % frame.z_index)
					check(frame_eff_z >= 1, "%s DoorFrame effective z_index >= 1" % d_label, "actual: %d" % frame_eff_z)
					check(frame_eff_z > max_bg_z, "%s DoorFrame above parallax bg (eff_z=%d > bg_z=%d)" % [d_label, frame_eff_z, max_bg_z])
				
				if seal:
					var seal_eff_z := _get_effective_z(seal)
					check(seal.z_index >= 1, "%s DoorSeal local z_index >= 1" % d_label, "actual: %d" % seal.z_index)
					check(seal_eff_z >= 1, "%s DoorSeal effective z_index >= 1" % d_label, "actual: %d" % seal_eff_z)
				
				if label:
					var label_eff_z := _get_effective_z(label)
					check(label_eff_z >= 4, "%s DoorLabel effective z_index >= 4" % d_label, "actual: %d" % label_eff_z)
		else:
			print("NOTE: Room %s has 0 doors (expected for terminal/shrine rooms like core before M2)" % room_name)
		
		instance.queue_free()
		await process_frame

	print("\n--- SUMMARY OF DOORS ACROSS ALL 30 ROOMS ---")
	print("Total rooms inspected: %d" % ROOM_PATHS.size())
	print("Rooms with doors: %d" % rooms_with_doors)
	print("Total doors validated: %d" % total_doors)
	check(total_doors >= 40, "Total doors across all rooms is substantial (>= 40)", "actual: %d" % total_doors)
	
	print("=== GOTHIC DOOR AUDIT FINISHED: %d tests, %d failures ===" % [tests_run, failures])
	quit(1 if failures else 0)
