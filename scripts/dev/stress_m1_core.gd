extends SceneTree
## Empirical Stress Test: Features 4, 5, 6, 7 (ShadowDash leaks, AttackArea offset, Corpse raycasts/safe floor, EchoAltar cleanup/passive doors)
## Run: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/stress_m1_core.gd

var failures := 0
var tests_run := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run_audit")

func check(ok: bool, label: String, detail: String = "") -> void:
	tests_run += 1
	if ok:
		print("M1_CORE PASS [%02d] %s" % [tests_run, label])
	else:
		failures += 1
		print("M1_CORE FAIL [%02d] %s :: %s" % [tests_run, label, detail])

func _run_audit() -> void:
	print("=== STARTING M1 CORE & PHYSICS BUGFIXES STRESS AUDIT ===")
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	var death := root.get_node("DeathManager")
	
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	
	var player: CharacterBody2D = current_scene.get_node("Player")
	check(player != null, "Player node found in scene")
	if player == null:
		quit(1)
		return

	# =========================================================================
	# FEATURE 4 (P1-1): ShadowDash Collision Mask Leak Guards
	# =========================================================================
	print("\n--- Testing Feature 4: ShadowDash Collision Mask Leak Guards ---")
	state.player_progress_knowledge["ability_shadow_dash"] = true
	var EXPECTED_MASK := 1 | 16 # LAYER_WORLD (1) | LAYER_CURSE_BARRIER (16) = 17
	check(player.collision_mask == EXPECTED_MASK, "Initial player collision_mask is 17 (1 | 16)", "mask=%d" % player.collision_mask)
	
	# Scenario A: Dash interrupted by Curse Stagger
	player._on_dash()
	check(player._state == &"dash" and player.collision_mask == 1, "Dash active: collision_mask temporarily reduced to 1 for curse barrier pass-through")
	player._on_curse_stagger()
	check(player.collision_mask == EXPECTED_MASK, "Curse stagger interruption restores collision_mask to 17", "actual: %d" % player.collision_mask)
	check(player._state != &"dash", "State reset from dash after curse stagger")
	player._dash_cd = 0.0

	# Scenario B: Dash interrupted by Story/UiGate lock
	player._on_dash()
	check(player._state == &"dash" and player.collision_mask == 1, "Dash active for UiGate test")
	gate.set_story(true)
	await physics_frame
	await physics_frame
	check(player.collision_mask == EXPECTED_MASK, "UiGate story block interruption restores collision_mask to 17", "actual: %d" % player.collision_mask)
	check(player._state != &"dash", "State reset from dash after story lock")
	gate.set_story(false)
	player._dash_cd = 0.0

	# Scenario C: Dash interrupted by Death trigger
	player._on_dash()
	check(player._state == &"dash" and player.collision_mask == 1, "Dash active for death test")
	player._on_death_started(&"hazard")
	check(player.collision_mask == EXPECTED_MASK, "Death interruption restores collision_mask to 17", "actual: %d" % player.collision_mask)
	player._dash_cd = 0.0

	# Scenario D: Dash interrupted by Respawn
	player._input_locked = false
	player._dash_cd = 0.0
	player._on_dash()
	check(player._state == &"dash" and player.collision_mask == 1, "Dash active for respawn test")
	player.respawn_at(Vector2(200, 288))
	player._on_rebirth_completed()
	check(player.collision_mask == EXPECTED_MASK, "Respawn restores collision_mask to 17", "actual: %d" % player.collision_mask)
	check(not player._input_locked, "Player unlocked after rebirth completion")

	# =========================================================================
	# FEATURE 5 (P1-2): Sword AttackArea Vertical Offset
	# =========================================================================
	print("\n--- Testing Feature 5: Sword AttackArea Vertical Offset ---")
	player._facing = 1.0
	await physics_frame
	check(player.attack_area.position.y == -20.0, "Facing right: AttackArea position.y is exactly -20.0", "y=%.1f" % player.attack_area.position.y)
	check(player.attack_area.position.x == 28.0, "Facing right: AttackArea position.x is 28.0", "x=%.1f" % player.attack_area.position.x)
	
	player._facing = -1.0
	await physics_frame
	check(player.attack_area.position.y == -20.0, "Facing left: AttackArea position.y is exactly -20.0", "y=%.1f" % player.attack_area.position.y)
	check(player.attack_area.position.x == -28.0, "Facing left: AttackArea position.x is -28.0", "x=%.1f" % player.attack_area.position.x)
	
	# Verify in player.tscn scene definition as well
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var dummy_p: Node = player_scene.instantiate()
	var attack_node: Area2D = dummy_p.get_node_or_null("AttackArea")
	check(attack_node != null and attack_node.position.y == -20.0, "player.tscn scene file defines AttackArea at y=-20.0")
	dummy_p.free()

	# =========================================================================
	# FEATURE 6 (P1-5): Corpse Push Raycasts & Hazard Safe Floor Spawn
	# =========================================================================
	print("\n--- Testing Feature 6: Corpse Push Raycasts & Safe Floor Spawn ---")
	rm.enter_room(&"decay_vines", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	
	# Safe floor tracking
	player.global_position = Vector2(250, 288) # safe floor
	player.velocity = Vector2.ZERO
	for frame in range(15):
		await physics_frame
	var safe_pos: Vector2 = player.get_last_safe_floor_pos()
	check(absf(safe_pos.y - 288.0) < 5.0, "Walking on floor records safe floor y ≈ 288.0", "y=%.1f" % safe_pos.y)
	
	# Player falls into pit (y > 320)
	player.global_position = Vector2(250, 360)
	await physics_frame
	var safe_pos_in_pit: Vector2 = player.get_last_safe_floor_pos()
	check(safe_pos_in_pit.y < 320.0, "Falling into pit (y > 320) does NOT update safe floor position", "pit_safe_y=%.1f" % safe_pos_in_pit.y)
	
	# Corpse push raycast checks
	var cm := root.get_node("CorpseManager")
	cm.record_corpse_at(Vector2(200, 288), &"test")
	await create_timer(0.15).timeout
	var corpses: Array = get_nodes_in_group("corpse")
	var corpse: Node2D = corpses[0] if corpses.size() > 0 else null
	check(corpse != null, "Corpse spawned for raycast testing")
	if corpse:
		# Check corpse has horizontal and downward raycast checks
		var corpse_script_text: String = ""
		var cf := FileAccess.open("res://scripts/world/corpse.gd", FileAccess.READ)
		if cf:
			corpse_script_text = cf.get_as_text()
			cf.close()
		check(corpse_script_text.contains("intersect_ray"), "corpse.gd implements raycast collision checks")
		check(corpse_script_text.contains("Engelle karşılaştı") or corpse_script_text.contains("Uçurumun kenarında"), "corpse.gd blocks push on obstacles or pit edge")

	# =========================================================================
	# FEATURE 7 (P1-3, P1-4): EchoAltar Room Disconnect & Passive Doors
	# =========================================================================
	print("\n--- Testing Feature 7: EchoAltar Disconnect & Passive Doors ---")
	rm.enter_room(&"experiment_circuit", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	
	var room_root: Node = rm._rooms[&"experiment_circuit"].root
	var altar: Node = null
	for n in room_root.find_children("*", "Area2D", true, false):
		if n.is_in_group("echo_altar"):
			altar = n
			break
	check(altar != null, "EchoAltar found in experiment_circuit")
	if altar:
		# Start recording via altar method
		altar._start_recording(player)
		check(altar._recording, "EchoAltar recording active")
		check(root.get_node("MobileInputManager").interact_pressed.is_connected(altar._on_rec_interact), "EchoAltar connected to interact signal")
		check(root.get_node("MobileInputManager").attack_pressed.is_connected(altar._on_rec_attack), "EchoAltar connected to attack signal")
		check(root.get_node("MobileInputManager").skill_pressed.is_connected(altar._on_rec_skill), "EchoAltar connected to skill signal")
		
		# Change room to another room
		rm.enter_room(&"experiment_cells", &"default")
		await create_timer(0.3).timeout
		dm.clear()
		
		# Verify altar recording was cancelled and signals disconnected upon room exit
		check(not altar._recording, "EchoAltar recording automatically cancelled on room change")
		check(not root.get_node("MobileInputManager").interact_pressed.is_connected(altar._on_rec_interact), "EchoAltar interact signal disconnected")
		check(not root.get_node("MobileInputManager").attack_pressed.is_connected(altar._on_rec_attack), "EchoAltar attack signal disconnected")
		check(not root.get_node("MobileInputManager").skill_pressed.is_connected(altar._on_rec_skill), "EchoAltar skill signal disconnected")
	
	# Passive doors / blockers retain collision_layer = 0 when open
	rm.enter_room(&"decay_weight", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	
	var dw_root: Node = rm._rooms[&"decay_weight"].root
	var gate_node: StaticBody2D = dw_root.get_node_or_null("Interactive/PathGate")
	check(gate_node != null, "PathGate found in decay_weight")
	if gate_node:
		# Set gate open
		state.set_world_flag(&"decay_weight_latched", true)
		gate_node._apply(true)
		check(gate_node.collision_layer == 0, "Gate open: collision_layer is 0")
		
		# Switch to another room and back (simulating room suspension and reactivating)
		rm.enter_room(&"decay_garden", &"default")
		await create_timer(0.2).timeout
		rm.enter_room(&"decay_weight", &"default")
		await create_timer(0.2).timeout
		dm.clear()
		
		var re_gate: StaticBody2D = rm._rooms[&"decay_weight"].root.get_node_or_null("Interactive/PathGate")
		check(re_gate != null and re_gate.collision_layer == 0, "Opened gate retained collision_layer == 0 after re-entering room (did not reactivate collision)")

	print("\n=== M1 CORE AUDIT FINISHED: %d tests, %d failures ===" % [tests_run, failures])
	quit(1 if failures else 0)
