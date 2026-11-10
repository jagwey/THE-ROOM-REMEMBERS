extends SceneTree
## Independent Forensic & Adversarial Audit Suite for Milestone 2 (R2)
## Author: Forensic Auditor (auditor_m2_1)

var failures := 0
var total_checks := 0

var sm: Node
var gs: Node
var dm: Node
var rm: Node
var curse: Node
var player: CharacterBody2D

func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")

func check(ok: bool, label: String, detail: Variant = "") -> void:
	total_checks += 1
	var msg := "PASS " if ok else "FAIL "
	if str(detail) != "":
		print("M2_FORENSIC ", msg, label, " [", detail, "]")
	else:
		print("M2_FORENSIC ", msg, label)
	if not ok:
		failures += 1

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _serial(path: String) -> int:
	var d: Variant = sm._read_save(path)
	return int((d as Dictionary).get("save_serial", -1)) if d is Dictionary else -1

func _find_seal(room_id: StringName) -> Node2D:
	var rt: Node = rm._rooms[room_id].root
	for n in rt.find_children("*", "Area2D", true, false):
		var sc: Script = n.get_script()
		if sc != null and String(sc.resource_path).ends_with("memory_seal_point.gd"):
			return n as Node2D
	return null

func _run() -> void:
	sm = root.get_node("SaveManager")
	gs = root.get_node("GameState")
	dm = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")
	curse = root.get_node("CurseManager")

	sm.delete_all_save_files()
	change_scene_to_file("res://scenes/main/main.tscn")
	await _wait(0.3)
	player = current_scene.get_node("Player")
	dm.clear()

	var save_path := String(sm.SAVE_PATH)

	print("\n==================================================")
	print("ADVERSARIAL SUITE 1: NUMERICAL BOUNDARY & EPSILON STRESS")
	print("==================================================")
	rm.enter_room(&"awakening", &"default")
	await _wait(0.15)
	dm.clear()
	var seal := _find_seal(&"awakening")
	check(seal != null, "Awakening seal exists")

	# Negative and zero bounds
	curse.curse = -0.00001
	check(seal.get_interact_label() == "Sessiz Mühür", "Negative epsilon gives 'Sessiz Mühür'", seal.get_interact_label())
	curse.curse = 0.0
	check(seal.get_interact_label() == "Sessiz Mühür", "Exact 0.0 gives 'Sessiz Mühür'", seal.get_interact_label())

	# Tiny positive epsilon
	curse.curse = 0.00001
	check(seal.get_interact_label() == "Laneti Mühürle (0%)", "Positive sub-half epsilon rounds to 0%", seal.get_interact_label())
	curse.curse = 0.4999
	check(seal.get_interact_label() == "Laneti Mühürle (0%)", "0.4999 rounds to 0%", seal.get_interact_label())
	curse.curse = 0.5001
	check(seal.get_interact_label() == "Laneti Mühürle (1%)", "0.5001 rounds to 1%", seal.get_interact_label())

	# High bounds
	curse.curse = 99.49
	check(seal.get_interact_label() == "Laneti Mühürle (99%)", "99.49 rounds to 99%", seal.get_interact_label())
	curse.curse = 99.51
	check(seal.get_interact_label() == "Laneti Mühürle (100%)", "99.51 rounds to 100%", seal.get_interact_label())
	curse.curse = 100.0
	check(seal.get_interact_label() == "Laneti Mühürle (100%)", "100.0 rounds to 100%", seal.get_interact_label())

	print("\n==================================================")
	print("ADVERSARIAL SUITE 2: ZERO CURSE REPETITIVE INFILTRATION")
	print("==================================================")
	curse.curse = 0.0
	sm.delete_all_save_files()
	var s_init := _serial(save_path)
	var cp_init: Vector2 = gs.get_checkpoint()

	# Fire 5 times rapidly
	for i in range(5):
		dm.clear()
		seal.on_interact(player)
		check(dm.is_open and dm._full_line == "Kanımda aktif bir lanet yok. Bu mühür sadece lanet altındayken uyanır.", "Interact %d rejected with canonical dialogue" % i)

	check(_serial(save_path) == s_init, "5 repetitive zero-curse interacts caused ZERO save commits")
	check(gs.get_checkpoint() == cp_init, "Checkpoint remained completely unchanged")
	check(get_nodes_in_group("seal_banner").is_empty(), "Zero seal banners created")
	dm.clear()

	print("\n==================================================")
	print("ADVERSARIAL SUITE 3: RAPID DOUBLE INTERACT & IMMEDIATE EXHAUSTION")
	print("==================================================")
	curse.curse = 45.0
	var s_before_double := _serial(save_path)
	
	# First interaction: curse=45.0 -> absorbed, save committed
	seal.on_interact(player)
	var glow1: float = seal._glow
	check(glow1 == 1.0, "First interact triggered seal glow")
	check(curse.curse == 0.0, "First interact cleared curse to 0.0")
	var s_mid := _serial(save_path)
	check(s_mid > s_before_double, "First interact incremented save serial")

	# Second immediate interaction: curse is now 0.0 -> must be rejected!
	dm.clear()
	seal.on_interact(player)
	await _wait(0.05)
	check(dm.is_open and dm._speaker == "Noroi", "Second interact immediately blocked by 0 curse")
	check(dm._full_line == "Kanımda aktif bir lanet yok. Bu mühür sadece lanet altındayken uyanır.", "Second interact displayed zero-curse line")
	check(_serial(save_path) == s_mid, "Second interact did NOT write another save commit")
	dm.clear()

	# Clean up banners
	for b in get_nodes_in_group("seal_banner"):
		b.queue_free()

	print("\n==================================================")
	print("ADVERSARIAL SUITE 4: END-TO-END ROUNDTRIP (SEAL -> TRAVEL -> POSSESSION)")
	print("==================================================")
	# 1. Player enters experiment_cells, gets cursed
	rm.enter_room(&"experiment_cells", &"default")
	await _wait(0.15)
	dm.clear()
	var exp_seal := _find_seal(&"experiment_cells")
	check(exp_seal != null, "experiment_cells seal exists")
	curse.curse = 80.0

	# 2. Interacts with seal in experiment_cells
	exp_seal.on_interact(player)
	await _wait(0.15)
	check(curse.curse == 0.0, "Curse cleared to 0 at experiment_cells seal")
	var exp_seal_pos := exp_seal.global_position

	# 3. Travel to mirrors_reverse and perform world edits
	rm.enter_room(&"mirrors_reverse", &"default")
	await _wait(0.15)
	dm.clear()
	gs.set_world_flag(&"adversarial_puzzle_solved", true)

	# 4. Trigger 100% curse possession
	curse.set_curse(100.0)
	check(curse.possessing, "Curse 100% triggered possession")
	var t0 := Time.get_ticks_msec()
	while curse.possessing and (Time.get_ticks_msec() - t0) < 25000:
		await process_frame
	await _wait(0.2)

	# 5. Verify Noroi resurrected at experiment_cells seal
	check(rm.get_active_room_id() == &"experiment_cells", "Possession returned player to committed room (experiment_cells)", rm.get_active_room_id())
	check(player.global_position.distance_to(exp_seal_pos) < 2.0, "Possession placed player precisely on experiment_cells seal", player.global_position)
	check(curse.curse == 50.0, "Possession reset curse to Band 1 (50.0)", curse.curse)
	check(gs.get_world_flag(&"adversarial_puzzle_solved", false), "World persistent changes preserved through possession")

	print("\n==================================================")
	print("ADVERSARIAL SUITE 5: CODEBASE INTEGRITY & AST INSPECTION")
	print("==================================================")
	var sc: Script = load("res://scripts/world/memory_seal_point.gd")
	var src: String = sc.source_code
	
	check(not src.contains("_open_travel"), "memory_seal_point.gd does NOT contain _open_travel")
	check(not src.contains("_close_travel"), "memory_seal_point.gd does NOT contain _close_travel")
	check(not src.contains("_travel_to"), "memory_seal_point.gd does NOT contain _travel_to")
	check(not src.contains("_other_seals"), "memory_seal_point.gd does NOT contain _other_seals")
	check(not src.contains("TRAVEL_LAYER"), "memory_seal_point.gd does NOT contain TRAVEL_LAYER")
	check(not src.contains("TRAVEL_GROUP"), "memory_seal_point.gd does NOT contain TRAVEL_GROUP")
	check(not src.contains("_travel_layer"), "memory_seal_point.gd does NOT contain _travel_layer")
	check(not src.contains("GothicModalPanel"), "memory_seal_point.gd does NOT contain GothicModalPanel")
	check(not src.contains("cheat") and not src.contains("bypass"), "No cheat or bypass words in memory_seal_point.gd")
	check(src.contains("CurseManager.clear_curse(absorbed)"), "Genuine clear_curse call exists")
	check(src.contains("SaveManager.commit_save"), "Genuine commit_save call exists")
	check(src.contains("CurseManager.set_curse(absorbed)"), "Genuine rollback on failure exists")

	# Clean up
	sm.delete_all_save_files()
	for b in get_nodes_in_group("seal_banner"):
		b.queue_free()

	print("\n==================================================")
	print("ADVERSARIAL AUDIT SUMMARY: Total = ", total_checks, " | Failures = ", failures)
	print("==================================================")
	quit(1 if failures > 0 else 0)
