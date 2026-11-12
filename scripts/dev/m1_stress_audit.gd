extends SceneTree
## Challenger M1-2: Empirical Stress Test Suite for Milestone 1
## Tests:
## 1. ShadowDash collision mask leak guards across interruptions (InputLock, Dialogue, Stagger, Death, Respawn, Room Transition, Barrier walkback)
## 2. Sword AttackArea vertical center (y=-20) & reach across heights, destructibles, and combo chain
## 3. Corpse pushing raycasts (wall halt, pit drop prevention) & hazard death safe floor recording (y < 320)
## 4. EchoAltar transition cleanup (signal disconnections) & passive room door/gate collision persistence

var failures := 0
var total_checks := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: String = "") -> void:
	total_checks += 1
	var msg := "PASS " if ok else "FAIL "
	if detail != "":
		print("CHALLENGE ", msg, label, " [", detail, "]")
	else:
		print("CHALLENGE ", msg, label)
	if not ok:
		failures += 1


func _enter(room: StringName, at: Vector2, dm: Node) -> void:
	var rm := root.get_node("RoomManager")
	rm.enter_room(room, &"default")
	await create_timer(0.18).timeout
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")
	player.global_position = at
	player.velocity = Vector2.ZERO
	player._state = &"idle"
	player._dash_cd = 0.0
	player._input_locked = false
	await create_timer(0.08).timeout
	dm.clear()


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("CHALLENGE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return

	var state := root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout

	var dm := root.get_node("DialogueManager")
	var rm := root.get_node("RoomManager")
	var death := root.get_node("DeathManager")
	var mim := root.get_node("MobileInputManager")
	var pm := root.get_node("PuzzleManager")
	var gate := root.get_node("UiGate")
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")

	print("\n==================================================")
	print("CHALLENGE SUITE 1: SHADOWDASH COLLISION MASK LEAKS")
	print("==================================================")

	state.player_progress_knowledge["ability_shadow_dash"] = true
	await _enter(&"awakening", Vector2(200, 288), dm)

	# 1.1 Initial collision mask
	check(player.collision_mask == 17, "Initial player collision_mask is 17 (1 | LAYER_CURSE_BARRIER)", "mask=%d" % player.collision_mask)

	# 1.2 Normal dash completes and restores mask
	player._on_dash()
	await create_timer(0.04).timeout
	check(player._state == &"dash" and player.collision_mask == 1, "Mid-dash: mask is 1 (passes curse barriers)", "mask=%d" % player.collision_mask)
	await create_timer(0.25).timeout
	check(player._state != &"dash" and player.collision_mask == 17, "Normal dash completion: mask restored to 17", "mask=%d" % player.collision_mask)

	# 1.3 Interruption via Input Lock mid-dash
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.04).timeout
	check(player._state == &"dash" and player.collision_mask == 1, "InputLock prep: player dashing with mask 1")
	player._input_locked = true
	await create_timer(0.06).timeout # let _physics_process tick with locked input
	check(player.collision_mask == 17, "Interruption via _input_locked restores mask to 17", "mask=%d" % player.collision_mask)
	check(player._state != &"dash", "Interruption via _input_locked exits dash state", "state=%s" % String(player._state))
	player._input_locked = false

	# 1.4 Interruption via Dialogue freeze (UiGate.blocks_movement) mid-dash
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.04).timeout
	check(player._state == &"dash" and player.collision_mask == 1, "Dialogue prep: player dashing with mask 1")
	dm.say("Adversary", "Freeze mid-dash!")
	await create_timer(0.06).timeout
	check(player.collision_mask == 17, "Interruption via Dialogue freeze restores mask to 17", "mask=%d" % player.collision_mask)
	check(player._state != &"dash", "Interruption via Dialogue freeze exits dash state")
	dm.clear()

	# 1.5 Interruption via Curse stagger pulse mid-dash
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.04).timeout
	check(player._state == &"dash" and player.collision_mask == 1, "Stagger prep: player dashing with mask 1")
	player._on_curse_stagger()
	await create_timer(0.06).timeout
	check(player.collision_mask == 17, "Interruption via curse stagger restores mask to 17", "mask=%d" % player.collision_mask)
	check(player._state != &"dash", "Interruption via curse stagger exits dash state")

	# 1.6 Interruption via play_death() mid-dash
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.04).timeout
	check(player._state == &"dash" and player.collision_mask == 1, "Death prep: player dashing with mask 1")
	player.play_death()
	await create_timer(0.06).timeout
	check(player.collision_mask == 17, "Interruption via play_death() restores mask to 17", "mask=%d" % player.collision_mask)
	player._input_locked = false
	player._state = &"idle"

	# 1.7 Interruption via respawn_at()
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.04).timeout
	player.respawn_at(Vector2(200, 288))
	check(player.collision_mask == 17, "respawn_at() restores mask to 17", "mask=%d" % player.collision_mask)
	check(player._state == &"idle", "respawn_at() resets state to idle")
	player._input_locked = false

	# 1.8 Room transition mid-dash
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.04).timeout
	check(player._state == &"dash", "Transition prep: player dashing")
	rm.enter_room(&"mirrors_shrine", &"default")
	await create_timer(0.2).timeout
	dm.clear()
	player = current_scene.get_node("Player")
	check(player.collision_mask == 17, "Room transition during dash preserves mask 17 in new room", "mask=%d" % player.collision_mask)

	# 1.9 Physical curse barrier walkback challenge
	# In mirrors_shrine, curse barrier is at x ~ 560
	player.global_position = Vector2(530, 288)
	player._facing = 1.0
	player._dash_cd = 0.0
	player._on_dash()
	await create_timer(0.4).timeout
	dm.clear()
	check(player.global_position.x > 572.0, "Shadow dash traversed curse barrier to right side", "x=%.1f" % player.global_position.x)
	check(player.collision_mask == 17, "After passing barrier, collision_mask is 17", "mask=%d" % player.collision_mask)

	# Now face left and attempt to walk back through the barrier without dashing
	player._facing = -1.0
	player.sprite.flip_h = true
	for f in 20:
		player.velocity.x = -175.0
		player.move_and_slide()
		await process_frame
	check(player.global_position.x > 560.0, "Curse barrier blocks normal walkback (mask 17 prevents barrier bypass)", "x=%.1f" % player.global_position.x)


	print("\n==================================================")
	print("CHALLENGE SUITE 2: ATTACKAREA REACH & VERTICAL OFFSET")
	print("==================================================")

	await _enter(&"awakening", Vector2(300, 288), dm)
	player._facing = 1.0
	await create_timer(0.05).timeout

	# 2.1 AttackArea geometry and facing translation
	check(player.attack_area.position.y == -20.0, "AttackArea vertical center is y=-20.0 (chest level)", "y=%.1f" % player.attack_area.position.y)
	check(player.attack_area.position.x == 28.0, "AttackArea facing right is at x=28.0", "x=%.1f" % player.attack_area.position.x)
	player._facing = -1.0
	await create_timer(0.05).timeout
	check(player.attack_area.position == Vector2(-28.0, -20.0), "AttackArea facing left is at x=-28.0, y=-20.0")
	player._facing = 1.0
	await create_timer(0.05).timeout

	# 2.2 Hit registration at different heights using dynamic target
	var hit_box := Area2D.new()
	hit_box.collision_layer = 4
	hit_box.collision_mask = 0
	var hit_cs := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = Vector2(16, 16)
	hit_cs.shape = hit_rect
	hit_box.add_child(hit_cs)

	var target_script := GDScript.new()
	target_script.source_code = """
extends Area2D
var hits := 0
var last_combo := -1
func receive_sword_hit(_attacker, _dir, combo):
	hits += 1
	last_combo = combo
"""
	target_script.reload()
	hit_box.set_script(target_script)
	current_scene.add_child(hit_box)

	# Test 2.2a: Chest height (y=-20 relative -> global (328, 268))
	hit_box.global_position = player.global_position + Vector2(28, -20)
	hit_box.set("hits", 0)
	player._state = &"idle"
	player._on_attack()
	await create_timer(0.08).timeout
	check(int(hit_box.get("hits")) == 1, "Attack registers on chest-level target (y=-20)", "hits=%d" % int(hit_box.get("hits")))
	await create_timer(0.25).timeout

	# Test 2.2b: Low crawler height (y=-10 relative -> global (328, 278))
	hit_box.global_position = player.global_position + Vector2(28, -10)
	hit_box.set("hits", 0)
	player._state = &"idle"
	player._on_attack()
	await create_timer(0.08).timeout
	check(int(hit_box.get("hits")) == 1, "Attack registers on low crawler target (y=-10)", "hits=%d" % int(hit_box.get("hits")))
	await create_timer(0.25).timeout

	# Test 2.2c: Head height (y=-30 relative -> global (328, 258))
	hit_box.global_position = player.global_position + Vector2(28, -30)
	hit_box.set("hits", 0)
	player._state = &"idle"
	player._on_attack()
	await create_timer(0.08).timeout
	check(int(hit_box.get("hits")) == 1, "Attack registers on upper chest/head target (y=-30)", "hits=%d" % int(hit_box.get("hits")))
	await create_timer(0.25).timeout

	# Test 2.2d: High above (y=-60 relative -> out of reach)
	hit_box.global_position = player.global_position + Vector2(28, -60)
	hit_box.set("hits", 0)
	player._state = &"idle"
	player._on_attack()
	await create_timer(0.08).timeout
	check(int(hit_box.get("hits")) == 0, "Attack misses target high above reach (y=-60)", "hits=%d" % int(hit_box.get("hits")))
	await create_timer(0.25).timeout

	# Test 2.2e: Target behind player
	hit_box.global_position = player.global_position + Vector2(-28, -20)
	hit_box.set("hits", 0)
	player._state = &"idle"
	player._facing = 1.0
	player._on_attack()
	await create_timer(0.08).timeout
	check(int(hit_box.get("hits")) == 0, "Attack misses target behind facing direction", "hits=%d" % int(hit_box.get("hits")))
	await create_timer(0.25).timeout
	hit_box.queue_free()

	# 2.3 Destructible hit on CrackedWall
	await _enter(&"decay_shilda_wall", Vector2(300, 288), dm)
	var wall: Node = null
	for n in get_nodes_in_group("cracked_wall"):
		if rm._rooms[&"decay_shilda_wall"].root.is_ancestor_of(n):
			wall = n; break
	check(wall != null, "Found cracked wall in decay_shilda_wall")
	if wall:
		var wall_2d := wall as Node2D
		player.global_position = wall_2d.global_position - Vector2(26, 0)
		player._facing = 1.0
		player._state = &"idle"
		dm.clear()
		player._on_attack()
		await create_timer(0.12).timeout
		check(dm.is_open and (dm.get("_full_line").contains("Kılıcım") or dm.get("_full_line").contains("Shilda")), "Sword hit reliably hits destructible CrackedWall at chest level")
		dm.clear()
		await create_timer(0.25).timeout

	# 2.4 3-Hit combo finisher progression
	player._combo = 0
	player._combo_timer = 0.0
	player._state = &"idle"
	player._on_attack()
	check(player._combo == 0, "Combo swing 1 is combo 0")
	await create_timer(0.16).timeout
	player._on_attack()
	check(player._combo == 1, "Combo swing 2 is combo 1")
	await create_timer(0.16).timeout
	player._on_attack()
	check(player._combo == 2, "Combo swing 3 is combo 2 finisher")
	await create_timer(0.35).timeout


	print("\n==================================================")
	print("CHALLENGE SUITE 3: CORPSE PUSH RAYCASTS & SAFE FLOOR")
	print("==================================================")

	await _enter(&"awakening", Vector2(200, 288), dm)
	var corpse_res := load("res://scenes/world/corpse.tscn")
	check(corpse_res != null, "corpse.tscn loaded successfully")

	# 3.1 Corpse pushing raycast stops before solid wall
	var test_corpse: Node2D = corpse_res.instantiate()
	current_scene.add_child(test_corpse)
	test_corpse.global_position = Vector2(200, 288)
	test_corpse.set("usable_for_puzzle", true)
	test_corpse.set("_echo_done", true)

	var solid_wall := StaticBody2D.new()
	solid_wall.collision_layer = 1
	solid_wall.collision_mask = 0
	var wall_cs := CollisionShape2D.new()
	var wall_box := RectangleShape2D.new()
	wall_box.size = Vector2(20, 60)
	wall_cs.shape = wall_box
	solid_wall.add_child(wall_cs)
	solid_wall.global_position = Vector2(240, 270) # left surface at x = 230
	current_scene.add_child(solid_wall)
	await process_frame
	await process_frame

	# Corpse starts at 200. Wall left surface is 230. Push step is 60.
	# Without raycast, corpse would end at 260 (inside/past wall).
	# With raycast, stop_x = 230 - 14 = 216.
	test_corpse.call("_push", 1.0)
	await create_timer(0.25).timeout
	check(test_corpse.global_position.x <= 216.5, "Corpse push halted before wall (pos.x=%.1f <= 216.5)" % test_corpse.global_position.x)

	# Pushing again when already flush against wall
	dm.clear()
	test_corpse.call("_push", 1.0)
	await create_timer(0.05).timeout
	dm.advance()
	check(dm.is_open and dm.get("_full_line").contains("Önünde duvar var"), "Corpse flush against wall displays 'Önünde duvar var'")
	dm.clear()
	solid_wall.queue_free()
	test_corpse.queue_free()

	# 3.2 Corpse pit raycast prevents sliding off ledge into pit
	await _enter(&"decay_catacombs", Vector2(340, 288), dm)
	var pit_corpse: Node2D = corpse_res.instantiate()
	current_scene.add_child(pit_corpse)
	pit_corpse.global_position = Vector2(340, 288)
	pit_corpse.set("usable_for_puzzle", true)
	pit_corpse.set("_echo_done", true)
	dm.clear()

	# In decay_catacombs, second floor gap exists between x=820 and x=900.
	# Corpse starts at x=790. Push step is 60. Target would be x=850 (inside the pit gap!).
	# Downward raycast at x=850 finds no floor on layer 1, halting corpse with "…Uçurumun kenarında durdu."
	pit_corpse.global_position = Vector2(790, 288)
	pit_corpse.call("_push", 1.0)
	await create_timer(0.05).timeout
	dm.advance()
	check(dm.is_open and dm.get("_full_line").contains("Uçurumun kenarında durdu"), "Corpse push at ledge edge detects pit: 'Uçurumun kenarında durdu'")
	check(pit_corpse.global_position.x == 790.0, "Corpse did not move off edge into pit (x=%.1f)" % pit_corpse.global_position.x)
	dm.clear()
	pit_corpse.queue_free()

	# 3.3 Hazard death records corpse on safe floor (y < 320.0)
	player.global_position = Vector2(200, 288)
	player.velocity = Vector2.ZERO
	await create_timer(0.06).timeout # update _last_safe_floor_pos
	check(player.get_last_safe_floor_pos().y < 320.0, "Player _last_safe_floor_pos is safe (y=%.1f < 320.0)" % player.get_last_safe_floor_pos().y)

	# Simulate falling into deep pit (y = 352.0)
	player.global_position = Vector2(200, 352)
	player.velocity = Vector2(0, 200)
	death.request_death(&"hazard")
	var corpses: Array = state.world_memory_state.get("corpses", [])
	check(not corpses.is_empty(), "Hazard death recorded corpse in world memory")
	if not corpses.is_empty():
		var latest: Dictionary = corpses.back()
		var pos_y: float = float(latest.get("position", {}).get("y", 999.0))
		check(pos_y < 320.0, "Hazard death corpse spawned on safe floor (pos.y=%.1f < 320.0)" % pos_y)
		check(absf(pos_y - 288.0) <= 2.0, "Hazard death corpse y precisely matches last safe floor pos (~288.0)", "pos_y=%.1f" % pos_y)

	# Recover from death
	await create_timer(0.8).timeout
	death.is_dying = false
	death.phase = death.Phase.ALIVE
	player.respawn_at(Vector2(200, 288))
	player._input_locked = false
	dm.clear()

	# 3.4 Thorn death records corpse on safe floor
	player.global_position = Vector2(250, 288)
	await create_timer(0.06).timeout
	player.global_position = Vector2(250, 360)
	death.request_death(&"thorn")
	corpses = state.world_memory_state.get("corpses", [])
	if not corpses.is_empty():
		var latest_thorn: Dictionary = corpses.back()
		var pos_y_thorn: float = float(latest_thorn.get("position", {}).get("y", 999.0))
		check(pos_y_thorn < 320.0, "Thorn death corpse spawned on safe floor (pos.y=%.1f < 320.0)" % pos_y_thorn)

	await create_timer(0.8).timeout
	death.is_dying = false
	death.phase = death.Phase.ALIVE
	player.respawn_at(Vector2(200, 288))
	player._input_locked = false
	dm.clear()


	print("\n==================================================")
	print("CHALLENGE SUITE 4: ECHOALTAR DISCONNECT & PASSIVE DOORS")
	print("==================================================")

	# 4.1 EchoAltar signal cleanup on room transition
	await _enter(&"experiment_circuit", Vector2(480, 288), dm)
	var altar: Node = null
	for n in get_nodes_in_group("echo_altar"):
		if rm._rooms[&"experiment_circuit"].root.is_ancestor_of(n):
			altar = n; break
	check(altar != null, "Found EchoAltar in experiment_circuit")
	if altar:
		altar.call("_start_recording", player)
		check(bool(altar.get("_recording")), "EchoAltar started recording")
		check(mim.interact_pressed.is_connected(altar._on_rec_interact), "altar connected to interact_pressed")
		check(mim.attack_pressed.is_connected(altar._on_rec_attack), "altar connected to attack_pressed")
		check(mim.skill_pressed.is_connected(altar._on_rec_skill), "altar connected to skill_pressed")

		# Transition to another room while altar is actively recording
		rm.enter_room(&"awakening", &"default")
		await create_timer(0.2).timeout
		dm.clear()
		check(not bool(altar.get("_recording")), "EchoAltar cancelled recording upon room change")
		check(not mim.interact_pressed.is_connected(altar._on_rec_interact), "altar disconnected from interact_pressed")
		check(not mim.attack_pressed.is_connected(altar._on_rec_attack), "altar disconnected from attack_pressed")
		check(not mim.skill_pressed.is_connected(altar._on_rec_skill), "altar disconnected from skill_pressed")

		# Trigger inputs in new room: verify no orphan events appended
		mim.press_attack()
		mim.release_attack()
		mim.press_skill()
		mim.press_interact()
		var events: Array = altar.get("_events")
		check(events.is_empty(), "No ghost events recorded on altar after room exit", "events=%d" % events.size())

	# 4.2 EchoAltar switches in passive room have physics suspended
	var switches_suspended := true
	if altar:
		for sw in altar.get("_switches"):
			var so := sw as CollisionObject2D
			if so.collision_layer != 0 or so.collision_mask != 0 or not so.has_meta("room_physics_suspended"):
				switches_suspended = false
	check(switches_suspended, "EchoAltar switches in passive room have collision layers/masks set to 0")

	# 4.3 Passive room GateBlocker opening persistence across room transitions
	await _enter(&"decay_catacombs", Vector2(120, 288), dm)
	var catacomb_root: Node = rm._rooms[&"decay_catacombs"].root
	var bone_gate: StaticBody2D = null
	for n in catacomb_root.find_children("*", "StaticBody2D", true, false):
		if n.name == "BoneGate":
			bone_gate = n; break
	check(bone_gate != null, "Found BoneGate in decay_catacombs")
	if bone_gate:
		check(bone_gate.collision_layer == 1, "BoneGate initially closed with collision_layer=1")
		# Solve the puzzle opening the gate
		pm.mark_solved(&"decay_catacomb_seal")
		check(bone_gate.collision_layer == 0, "BoneGate opens with collision_layer=0 on puzzle solve")

		# Now leave decay_catacombs to another room so it becomes passive
		rm.enter_room(&"awakening", &"default")
		await create_timer(0.2).timeout
		dm.clear()
		check(bone_gate.collision_layer == 0, "BoneGate retains collision_layer=0 while in passive room")

		# Re-enter decay_catacombs: verify collision_layer does NOT reactivate to 1
		rm.enter_room(&"decay_catacombs", &"default")
		await create_timer(0.2).timeout
		dm.clear()
		check(bone_gate.collision_layer == 0, "BoneGate collision_layer REMAINS 0 after re-entering room (did not reactivate)", "layer=%d" % bone_gate.collision_layer)

	# 4.4 Passive room CrackedWall broken persistence across room transitions
	await _enter(&"decay_shilda_wall", Vector2(300, 288), dm)
	var cracked_wall: StaticBody2D = null
	for n in get_nodes_in_group("cracked_wall"):
		if rm._rooms[&"decay_shilda_wall"].root.is_ancestor_of(n):
			cracked_wall = n; break
	check(cracked_wall != null, "Found CrackedWall in decay_shilda_wall")
	if cracked_wall:
		var keeper := current_scene.get_node("Keeper")
		cracked_wall.receive_keeper_charge(keeper)
		cracked_wall.receive_keeper_charge(keeper)
		check(cracked_wall.is_broken(), "CrackedWall broken by 2 keeper charges")
		check((cracked_wall.get("_shape") as CollisionShape2D).disabled, "CrackedWall shape disabled after breaking")

		# Leave room and re-enter
		rm.enter_room(&"awakening", &"default")
		await create_timer(0.2).timeout
		dm.clear()
		rm.enter_room(&"decay_shilda_wall", &"default")
		await create_timer(0.2).timeout
		dm.clear()
		check(cracked_wall.collision_layer == 0, "Broken CrackedWall collision_layer REMAINS 0 after re-entering room", "layer=%d" % cracked_wall.collision_layer)


	print("\n==================================================")
	print("CHALLENGE VERDICT SUMMARY")
	print("==================================================")
	print("Total checks executed: ", total_checks)
	print("Total failures: ", failures)
	if failures == 0:
		print("VERDICT: ALL ADVERSARIAL STRESS CHALLENGES PASSED (0 FAILURES)")
	else:
		print("VERDICT: CHALLENGE REJECTED (%d FAILURES)" % failures)

	quit(1 if failures else 0)
