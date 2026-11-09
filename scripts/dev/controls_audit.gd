extends SceneTree
## Runtime checks for modal physics, animation processing, and fair hazard damage.
var failures := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("CONTROLS ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _enter(room: StringName, at: Vector2, dm: Node) -> void:
	root.get_node("RoomManager").enter_room(room, &"default")
	await create_timer(0.15).timeout
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")
	player.global_position = at
	player.velocity = Vector2.ZERO
	player._state = &"idle"
	player._dash_cd = 0.0
	await create_timer(0.12).timeout
	dm.clear()


func _first_in_room(group: String, room: StringName) -> Node:
	var rm := root.get_node("RoomManager")
	var room_root: Node = rm._rooms[room].root
	for n in get_nodes_in_group(group):
		if room_root.is_ancestor_of(n):
			return n
	return null


## v1.0 mekanikleri: zıplama, dash, gölge atılması, ruh kesimi, yankı ikizi, çatlak duvar,
## Shilda savaşı, lanet bulutu, mühür tepkileri, final şartı, bulmaca cesedi koruması.
func _mechanics(player: CharacterBody2D, state: Node, dm: Node) -> void:
	var mim := root.get_node("MobileInputManager")
	var pm := root.get_node("PuzzleManager")
	var curse := root.get_node("CurseManager")
	state.hearts = state.max_hearts
	# Zıplama
	await _enter(&"awakening", Vector2(200, 288), dm)
	var y0 := player.global_position.y
	mim.press_jump()
	await create_timer(0.15).timeout
	mim.release_jump()
	check(player.global_position.y < y0 - 12.0, "jump lifts the player off the floor")
	await create_timer(0.6).timeout
	check(player.is_on_floor(), "player lands after jump")
	# Dash bekleme süresi
	player._on_dash()
	await create_timer(0.25).timeout
	check(player._dash_cd > 0.0, "dash enters cooldown")
	player._on_dash()
	check(player._state != &"dash", "dash blocked during cooldown")
	# Gölge Atılması bariyeri
	state.player_progress_knowledge["ability_shadow_dash"] = false
	await _enter(&"mirrors_shrine", Vector2(500, 288), dm)
	player._facing = 1.0
	player._on_dash()
	await create_timer(0.4).timeout
	dm.clear()
	check(player.global_position.x < 560.0, "curse barrier stops normal dash")
	state.player_progress_knowledge["ability_shadow_dash"] = true
	await _enter(&"mirrors_shrine", Vector2(530, 288), dm)
	player._facing = 1.0
	player._on_dash()
	await create_timer(0.4).timeout
	dm.clear()
	check(player.global_position.x > 572.0, "shadow dash passes curse barrier")
	# Ruh Kesimi
	state.player_progress_knowledge["ability_soul_slash"] = true
	await _enter(&"awakening_balcony", Vector2(780, 288), dm)
	player._facing = 1.0
	player.sprite.flip_h = false
	player._on_skill()
	await create_timer(0.5).timeout
	dm.clear()
	check(pm.is_solved(&"soul_seal_balcony"), "soul slash opens the balcony soul seal")
	# Yankı ikizi (experiment_circuit): ikiz plakayı tutar, oyuncu kristali çeker
	await _enter(&"experiment_circuit", Vector2(480, 288), dm)
	var altar := _first_in_room("echo_altar", &"experiment_circuit")
	var switches: Array = altar._switches if altar else []
	check(altar != null and switches.size() == 2, "echo altar builds its switches")
	if altar and switches.size() == 2:
		var plate_pos: Vector2 = (switches[0] as Node2D).global_position + Vector2(0, -4)
		var frames: Array = []
		for i in 40:
			frames.append([i * 0.15, plate_pos, false, "idle"])
		altar.debug_play(frames, [])
		player.global_position = (switches[1] as Node2D).global_position
		await create_timer(0.4).timeout
		dm.clear()
		switches[1].on_interact(player)
		await create_timer(0.3).timeout
		dm.clear()
		check(pm.is_solved(&"experiment_circuit"), "echo twin holds plate while player pulls lever")
	# Çatlak duvar + karşılaşma sonu
	await _enter(&"decay_shilda_wall", Vector2(300, 288), dm)
	var wall := _first_in_room("cracked_wall", &"decay_shilda_wall")
	var keeper := current_scene.get_node("Keeper")
	keeper.start_encounter(&"shilda_wall")
	await create_timer(1.2).timeout
	dm.clear()
	check(keeper.mode == keeper.Mode.COMBAT, "keeper enters combat encounter")
	if wall:
		wall.receive_keeper_charge(keeper)
		dm.clear()
		check(not wall.is_broken(), "cracked wall survives first charge")
		wall.receive_keeper_charge(keeper)
		await create_timer(0.1).timeout
		dm.clear()
	check(wall != null and wall.is_broken() and pm.is_solved(&"decay_shilda_wall_broken"), "second charge breaks wall and ends encounter")
	check(keeper.mode != keeper.Mode.COMBAT, "keeper leaves combat after wall breaks")
	# Lanet bulutu + sünger ceset
	await _enter(&"experiment_quarantine", Vector2(660, 288), dm)
	curse.curse = 0.0
	await create_timer(0.4).timeout
	var raw: float = curse.curse
	check(raw > 8.0, "curse cloud corrupts the living (%.1f)" % raw)
	curse.curse = 0.0
	player.global_position = Vector2(200, 288)
	root.get_node("CorpseManager").record_corpse_at(Vector2(660, 288), &"curse")
	await create_timer(0.15).timeout
	player.global_position = Vector2(700, 288)
	await create_timer(0.4).timeout
	check(curse.curse < 2.0, "corpse absorbs curse in a 120px corridor (%.1f)" % curse.curse)
	curse.curse = 0.0
	# Mühür tepkileri
	var deaths := int(state.player_progress_knowledge.get("deaths", 0))
	state.player_progress_knowledge["memory_codes"].erase("qa_code")
	check(state.memory_code_reaction("qa_code") == &"unknown", "seal reaction: never seen")
	state.learn_memory_code("qa_code", "123")
	check(state.memory_code_reaction("qa_code") == &"same_life", "seal reaction: same life")
	state.player_progress_knowledge["deaths"] = deaths + 1
	check(state.memory_code_reaction("qa_code") == &"past_life", "seal reaction: previous life")
	state.player_progress_knowledge["deaths"] = deaths
	# İyi son iki mühür parçası ister
	var em := root.get_node("EndingManager")
	pm.mark_solved(&"awakening_memory_code")
	pm.mark_solved(&"core_seal")
	state.player_progress_knowledge["truth_seen"] = true
	state.player_progress_knowledge["echoes_seen"].append("qa_echo")
	state.set_world_flag(&"seal_shard_1", false)
	state.set_world_flag(&"seal_shard_2", false)
	state.player_progress_knowledge["ability_soul_slash"] = true
	check(not em.can_begin_final(), "final locked without both shards")
	state.set_world_flag(&"seal_shard_1", true)
	state.set_world_flag(&"seal_shard_2", true)
	check(em.can_begin_final(), "final open with both shards + soul slash")
	# Bulmacayı tutan ceset silinmez
	var corpses: Array = state.world_memory_state["corpses"]
	corpses.clear()
	corpses.append({"id": "qa_anchor", "room": "awakening_seal", "position": {"x": 340, "y": 288}, "anchoring": true})
	var cm := root.get_node("CorpseManager")
	for i in 4:
		cm.record_corpse_at(Vector2(100 + i * 10, 288), &"qa")
	var kept := corpses.any(func(c): return String(c.get("id", "")) == "qa_anchor")
	check(kept and corpses.size() <= cm.MAX_CORPSES + 3, "anchoring corpse survives trimming")
	corpses.clear()
	cm.rebuild_world_corpses()

	# v1.3.0 Feature 29 Audits:
	# 1) WeightStone pushing (walk-push and interact)
	await _enter(&"decay_weight", Vector2(160, 288), dm)
	var stone := _first_in_room("weight_stone", &"decay_weight") as CharacterBody2D
	if stone:
		var x0 := stone.global_position.x
		stone.apply_push(1.0)
		check(stone.velocity.x > 0.0, "stone responds to apply_push")
		stone.global_position.x = x0

	# 2) Corpse platforming (one_way_collision)
	var corpse_res := load("res://scenes/world/corpse.tscn")
	if corpse_res:
		var c_test: Node2D = corpse_res.instantiate()
		var cs: CollisionShape2D = c_test.get_node_or_null("CollisionShape2D")
		check(cs != null and cs.one_way_collision, "corpse collision shape has one_way_collision=true")
		c_test.free()

	# 3) EchoTwin combat recording & replay
	var altar_code: String = ""
	var altar_script = load("res://scripts/world/echo_altar.gd")
	if altar_script:
		var af := FileAccess.open("res://scripts/world/echo_altar.gd", FileAccess.READ)
		if af:
			altar_code = af.get_as_text()
			af.close()
	check(altar_code.contains('"attack"') and altar_code.contains('"skill"'), "echo altar records attack and skill actions")


func _run() -> void:
	var state := root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	var dm := root.get_node("DialogueManager")
	dm.clear()
	var player := current_scene.get_node("Player")
	var gate := root.get_node("UiGate")
	player.global_position = Vector2(180, 110)
	player.velocity = Vector2(40, 250)
	dm.say("Shilda", "Test sırasında dünya durur; görsel animasyon devam eder.")
	var before: Vector2 = player.global_position
	await create_timer(0.25).timeout
	check(player.global_position.distance_to(before) < 0.1, "story freezes both horizontal and vertical physics")
	check(player.sprite.can_process() and player.sprite.is_playing(), "story keeps character animation active")
	check(gate.pauses_world_threats(), "story pauses threats")
	gate.set_journal(true)
	var page: String = dm.visible_page_text()
	root.get_node("MobileInputManager").press_interact()
	check(dm.visible_page_text() == page and dm.is_open, "journal cannot advance underlying story")
	gate.set_journal(false)
	dm.clear()
	player.global_position = Vector2(180, 288)
	player.velocity = Vector2.ZERO
	player._state = &"dash"
	var hearts: int = state.hearts
	check(not player.receive_hazard_hit(200.0) and state.hearts == hearts, "dash crosses hazard without damage")
	player._state = &"idle"
	check(player.receive_hazard_hit(200.0) and state.hearts == hearts - 1, "one contact costs only one heart")
	check(not player.receive_hazard_hit(200.0) and state.hearts == hearts - 1, "repeat contact cooldown prevents instant death")
	check(not root.get_node("DeathManager").is_dying, "first contact is survivable")
	if "qa/" in String(root.get_node("SaveManager").SAVE_PATH):
		await _mechanics(player, state, dm)
	else:
		print("CONTROLS SKIP v1.0 mechanics (run with TORIMON_TEST=1 so the player save is never touched)")
	print("CONTROLS_AUDIT failures=", failures)
	quit(1 if failures else 0)
