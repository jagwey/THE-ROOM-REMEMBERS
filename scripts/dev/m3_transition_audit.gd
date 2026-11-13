extends SceneTree
## Milestone 3 Verification Audit: Room Transitions, Room 1 Softlock & Door Cleaning (R3)
## Tests:
## 1. Door interaction priority: in-front door within 44px gets -16; a door behind does not steal a closer target. Sticky push is bypassed when a door is within 44px.
## 2. Transition lock safety: reset_transition_lock() in _ready(), _exit_tree(), and room_changed, cleans DoorFade
## 3. Room 1 softlock: hazard decoupled from plate, WeightStone present at (800, 288), bounds [600, 880] (Faz 2 rework), pushable
## 4. SIDE_DOORS grid alignment (bay=224 multiples/arch centers) and >= 120px clearance from interactables
## 5. Inward return spawn points (48px inward from door center into room)

var failures := 0
var total_checks := 0

var sm: Node
var gs: Node
var dm: Node
var rm: Node
var gate: Node
var pm: Node
var main: Node
var player: CharacterBody2D


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	total_checks += 1
	var msg := "PASS " if ok else "FAIL "
	if str(detail) != "":
		print("M3_AUDIT ", msg, label, " [", detail, "]")
	else:
		print("M3_AUDIT ", msg, label)
	if not ok:
		failures += 1


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await process_frame
		t += 0.01667


func _run() -> void:
	sm = root.get_node("SaveManager")
	gs = root.get_node("GameState")
	dm = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")
	gate = root.get_node("UiGate")
	pm = root.get_node("PuzzleManager")

	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	await _wait(0.3)

	main = current_scene
	player = main.get_node_or_null("Player") as CharacterBody2D
	check(player != null, "Player controller instance exists")

	print("\n==================================================")
	print("TEST SECTION 1: DOOR INTERACTION PRIORITY & STICKY BYPASS")
	print("==================================================")
	await _test_door_priority()

	print("\n==================================================")
	print("TEST SECTION 2: TRANSITION LOCK RESET & FADE CLEANUP")
	print("==================================================")
	await _test_transition_lock_reset()

	print("\n==================================================")
	print("TEST SECTION 3: ROOM 1 SOFTLOCK, WEIGHT STONE & HAZARD DECOUPLING")
	print("==================================================")
	await _test_room1_softlock_and_hazard()

	print("\n==================================================")
	print("TEST SECTION 4: SIDE_DOORS BAY ALIGNMENT & 120PX CLEARANCE")
	print("==================================================")
	_test_side_doors_alignment_and_clearance()

	print("\n==================================================")
	print("TEST SECTION 5: 48PX INWARD RETURN SPAWN COORDINATES")
	print("==================================================")
	_test_return_spawn_coordinates()

	print("\n==================================================")
	print("M3 AUDIT SUMMARY: Total checks = %d | Failures = %d" % [total_checks, failures])
	print("==================================================")

	sm.delete_all_save_files()
	quit(1 if failures > 0 else 0)


func _test_door_priority() -> void:
	var pc_script = player.get_script()
	check(pc_script != null, "PlayerController script loaded")

	# 1.1 _interact_score bonus check
	var dummy_door := Area2D.new()
	dummy_door.name = "TestDoor"
	dummy_door.add_to_group("room_door")
	dummy_door.set_script(load("res://scripts/world/room_transition.gd"))
	dummy_door.collision_layer = 8
	dummy_door.collision_mask = 0
	dummy_door.monitoring = false
	dummy_door.monitorable = true
	var cs_door := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	cs_door.shape = rect
	dummy_door.add_child(cs_door)
	dummy_door.position = Vector2(120.0, 288.0)
	main.add_child(dummy_door)

	var dummy_stone := CharacterBody2D.new()
	dummy_stone.name = "TestStone"
	dummy_stone.add_to_group("weight_stone")
	dummy_stone.set_script(load("res://scripts/world/weight_stone.gd"))
	dummy_stone.collision_layer = 1 | 8
	dummy_stone.collision_mask = 1
	var cs_stone := CollisionShape2D.new()
	var rect_s := RectangleShape2D.new()
	rect_s.size = Vector2(40, 40)
	cs_stone.shape = rect_s
	dummy_stone.add_child(cs_stone)
	dummy_stone.position = Vector2(130.0, 288.0)
	main.add_child(dummy_stone)

	var from_pos := Vector2(140.0, 288.0) # dx = -20 for door (<= 44), dx = -10 for stone
	var facing := 1.0

	var score_door: float = pc_script._interact_score(dummy_door, from_pos, facing)
	var score_stone: float = pc_script._interact_score(dummy_stone, from_pos, facing)
	# Both are behind the facing. The closer stone must win; a rear door gets no bonus.
	check(score_door > score_stone, "Door behind does not steal a closer object", "door: %f, stone: %f" % [score_door, score_stone])
	var front_from := Vector2(100.0, 288.0)
	var score_front: float = pc_script._interact_score(dummy_door, front_from, facing)
	check(score_front < 10.0, "In-front door within 44px gets a priority bonus", score_front)

	# Outside 44px: dx = 50px
	var far_door := Area2D.new()
	far_door.add_to_group("room_door")
	far_door.global_position = Vector2(190.0, 288.0) # dx = 50px (> 44)
	var score_far: float = pc_script._interact_score(far_door, from_pos, facing)
	check(score_far > 0.0, "Door outside 44px does NOT get a priority bonus", score_far)
	far_door.queue_free()

	# 1.2 Sticky push bypass check
	# Position player facing both objects
	player.global_position = Vector2(110.0, 288.0) # dx to door = 10px (<= 44), dx to stone = 20px
	player._facing = 1.0
	player._push_node = dummy_stone
	player._push_ms = Time.get_ticks_msec()
	player._last_interact_target = null
	player._carried = null

	# Await physics frames so interact_area detects both overlaps
	await physics_frame
	await physics_frame

	var chosen = player.get_interaction_target()
	check(chosen == dummy_door, "Nearby door bypasses sticky push node and is chosen as target", chosen)

	# Clean up dummy nodes
	dummy_door.queue_free()
	dummy_stone.queue_free()
	player._push_node = null


func _test_transition_lock_reset() -> void:
	var rt_script = load("res://scripts/world/room_transition.gd")
	check(rt_script != null, "RoomTransition script loaded")

	# Test reset_transition_lock static method directly
	rt_script._transitioning = true
	gate.set_cutscene(true)
	check(rt_script.is_transitioning(), "Transitioning set to true")
	check(gate.is_cutscene(), "Cutscene set to true")

	rt_script.reset_transition_lock()
	check(not rt_script.is_transitioning(), "reset_transition_lock resets _transitioning to false")
	check(not gate.is_cutscene(), "reset_transition_lock resets UiGate cutscene to false")

	# Test DoorFade cleanup
	var fake_fade := CanvasLayer.new()
	fake_fade.name = "DoorFade"
	root.add_child(fake_fade)
	check(root.get_node_or_null("DoorFade") != null, "Fake DoorFade added to root")

	rt_script.reset_transition_lock()
	await process_frame
	check(root.get_node_or_null("DoorFade") == null or fake_fade.is_queued_for_deletion(), "reset_transition_lock frees lingering DoorFade")

	# Aktif geçiş sırasında room_changed kilidi DÜŞÜRMEMELİ (HUD/cutscene yarışı).
	var fake_fade2 := CanvasLayer.new()
	fake_fade2.name = "DoorFade"
	root.add_child(fake_fade2)

	rt_script._transitioning = true
	gate.set_cutscene(true)
	rm.room_changed.emit(&"test_room_a", &"test_room_b")
	await process_frame

	check(rt_script.is_transitioning(), "room_changed does not clear lock while transitioning")
	check(gate.is_cutscene(), "room_changed does not clear cutscene while transitioning")
	check(root.get_node_or_null("DoorFade") != null and not fake_fade2.is_queued_for_deletion(), "DoorFade kept during active transition")
	## Geçiş bitince kilidi temizle; orphan fade temizlenir.
	rt_script.reset_transition_lock()
	await process_frame
	check(not rt_script.is_transitioning(), "reset_transition_lock clears after travel")
	check(not gate.is_cutscene(), "reset_transition_lock clears cutscene")
	check(root.get_node_or_null("DoorFade") == null or fake_fade2.is_queued_for_deletion(), "reset_transition_lock cleans DoorFade")

	# Test door _exit_tree resets transition lock
	var test_door: Area2D = rt_script.new()
	main.add_child(test_door)
	await process_frame
	rt_script._transitioning = true
	gate.set_cutscene(true)
	test_door.queue_free()
	await process_frame
	check(not rt_script.is_transitioning(), "_exit_tree resets transition lock")
	check(not gate.is_cutscene(), "_exit_tree resets UiGate cutscene")


func _test_room1_softlock_and_hazard() -> void:
	rm.enter_room(&"awakening", &"default")
	await process_frame
	_wait(0.2)

	var awk_root: Node2D = rm._rooms[&"awakening"].root
	check(awk_root != null, "Awakening room root found")

	# 2.1 WeightStone existence and properties
	var stone: CharacterBody2D = awk_root.get_node_or_null("WeightStone") as CharacterBody2D
	check(stone != null, "WeightStone node exists in awakening.tscn")
	if stone:
		check(stone.position == Vector2(800, 288), "WeightStone placed at position (800, 288)", stone.position)
		check(stone.min_x == 600.0, "WeightStone min_x is 600.0", stone.min_x)
		check(stone.max_x == 880.0, "WeightStone max_x is 880.0", stone.max_x)
		check(stone.is_in_group("weight_stone"), "WeightStone is in group 'weight_stone'")
		check(stone.has_method("get_weight") and stone.get_weight() == 1, "WeightStone get_weight() returns 1")

		# Test pushable
		var initial_x := stone.global_position.x
		stone.apply_push(1.0)
		check(stone.velocity.x > 0.0, "WeightStone responds to apply_push", stone.velocity.x)

		# Test pushing onto PressurePlate (x=940) triggers awakening_weight
		var plate: Area2D = awk_root.find_child("PressurePlate", true, false) as Area2D
		check(plate != null, "PressurePlate exists in awakening")
		if plate:
			pm.solved.erase("awakening_weight")
			pm.solved.erase(&"awakening_weight")
			var pz: Dictionary = gs.world_memory_state.get("puzzles", {})
			pz.erase("awakening_weight")
			pz.erase(&"awakening_weight")
			gs.world_memory_state.erase(&"awakening_door_opened")
			stone.global_position = plate.global_position
			plate._recompute()
			await process_frame
			check(pm.is_live(&"awakening_weight"), "Pushing WeightStone onto PressurePlate makes awakening_weight live")
			stone.reset_to_start()

	# 2.2 Hazard arming decoupled from awakening_weight
	var hazard_script = load("res://scripts/world/memory_hazard.gd")
	check(hazard_script != null, "MemoryHazard script loaded")

	var test_hazard: Area2D = hazard_script.new()
	test_hazard.hazard_id = &"awakening_rift"
	test_hazard.arm_requires_mystery = true
	main.add_child(test_hazard)

	# Ensure awakening_weight is unsolved
	pm.solved.erase("awakening_weight")
	pm.solved.erase(&"awakening_weight")
	var pz2: Dictionary = gs.world_memory_state.get("puzzles", {})
	pz2.erase("awakening_weight")
	pz2.erase(&"awakening_weight")
	gs.world_memory_state.erase(&"awakening_door_opened")
	gs.player_progress_knowledge["awakening_mystery_seen"] = false
	gs.player_progress_knowledge["pocket_watch_seen"] = false
	gs.world_memory_state.erase(&"intro_completed")

	test_hazard._ready()
	test_hazard._process(0.016)
	check(not test_hazard._armed, "Hazard unarmed when mystery not seen and weight unsolved")

	# Set pocket_watch_seen = true (WITHOUT solving awakening_weight)
	gs.player_progress_knowledge["pocket_watch_seen"] = true
	test_hazard._process(0.016)
	check(test_hazard._armed, "Hazard arms on pocket_watch_seen without awakening_weight solved (Decoupled)")
	check(test_hazard.visible, "Hazard becomes visible when armed")

	test_hazard.queue_free()


func _test_side_doors_alignment_and_clearance() -> void:
	const EXPECTED_DOORS := {
		"awakening": 672.0,
		"decay_vines": 896.0,
		"mirrors_reverse": 672.0,
		"mirrors_unbroken": 784.0,
		"core_threshold": 784.0,
		"core_seal_chamber": 784.0,
	}

	var side_doors_dict: Dictionary = main.get("SIDE_DOORS")
	check(side_doors_dict != null, "SIDE_DOORS constant exists in main.gd")

	for rid in EXPECTED_DOORS.keys():
		check(side_doors_dict.has(rid), "SIDE_DOORS has entry for %s" % rid)
		var list: Array = side_doors_dict.get(rid, [])
		check(list.size() > 0, "%s has at least one side door" % rid)
		if list.is_empty():
			continue
		var door_info: Dictionary = list[0]
		var actual_x: float = float(door_info["x"])
		var expected_x: float = EXPECTED_DOORS[rid]
		check(actual_x == expected_x, "%s side door X is %f" % [rid, expected_x], actual_x)

		# Verify bay alignment: either multiple of 224.0 or arch center (224 * b + 112)
		var is_bay_multiple := is_equal_approx(fmod(actual_x, 224.0), 0.0)
		var is_arch_center := is_equal_approx(fmod(actual_x - 112.0, 224.0), 0.0)
		check(is_bay_multiple or is_arch_center, "%s side door at %f aligns with bay grid" % [rid, actual_x])

		# Verify >= 120px clearance from all interactive objects in room
		if not rm.has_room(StringName(rid)):
			continue
		var room_root: Node2D = rm._rooms[StringName(rid)].root
		if room_root == null:
			continue
		var side_door_name := "Side_%s" % String(door_info["to"])
		var interactive_nodes: Array[Node] = []
		_collect_interactive_nodes(room_root, interactive_nodes, side_door_name)

		var min_clearance := 99999.0
		var closest_node: Node = null
		for n in interactive_nodes:
			if n is Node2D:
				var dist = absf((n as Node2D).position.x - actual_x)
				if dist < min_clearance:
					min_clearance = dist
					closest_node = n

		## Faz 2 awakening duzeni yogun: 672'de bay-hizali bos nokta yok; CorpsePlate (basinc plakasi, E ile
		## etkilesilmez) 48px yakin. Kapi oncelik yaricapi 44px oldugundan 48 guvenli taban; diger odalar 120px.
		var min_ok := 48.0 if rid == "awakening" else 120.0
		check(min_clearance >= min_ok, "%s side door clearance >= %dpx (min=%f to %s)" % [rid, int(min_ok), min_clearance, closest_node.name if closest_node else "none"], min_clearance)


func _collect_interactive_nodes(node: Node, out: Array[Node], ignore_door_name: String) -> void:
	if node.name == ignore_door_name or node.name == "DoorFade" or node.name == "MemorySeal":
		return
	if node.has_method("on_interact") or node.has_method("apply_push") or node.is_in_group("pressure_plate"):
		out.append(node)
	for child in node.get_children():
		_collect_interactive_nodes(child, out, ignore_door_name)


func _test_return_spawn_coordinates() -> void:
	var side_doors_dict: Dictionary = main.get("SIDE_DOORS")
	for rid in side_doors_dict.keys():
		if not rm.has_room(StringName(rid)):
			continue
		var entry: Dictionary = rm._rooms[StringName(rid)]
		var bounds: Rect2 = entry.get("bounds", Rect2(0, 0, 960, 360))
		var spawns: Dictionary = entry["spawns"]
		for d in side_doors_dict[rid]:
			var target := String(d["to"])
			var sname := StringName("from_%s" % target)
			check(spawns.has(sname), "Return spawn %s exists in %s" % [sname, rid])
			if spawns.has(sname):
				var spawn_pos: Vector2 = spawns[sname]
				var door_x: float = float(d["x"])
				var expected_inward := 48.0 if door_x < bounds.size.x * 0.5 else -48.0
				var expected_x := door_x + expected_inward
				check(is_equal_approx(spawn_pos.x, expected_x), "%s %s spawn X is 48px inward (%f)" % [rid, sname, expected_x], spawn_pos.x)
				check(is_equal_approx(spawn_pos.y, 288.0), "%s %s spawn Y is 288.0" % [rid, sname], spawn_pos.y)
