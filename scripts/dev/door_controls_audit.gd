extends SceneTree
## Kapı geçişi sonrası kontroller: UiGate kilidi kalkmalı, HUD joystick/hareket görünür olmalı.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/door_controls_audit.gd

var failures := 0
var checked_rooms: Array[String] = []


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_TOUCH_UI", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("DOOR_CTRL ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _door_in(rm: Node, room_id: StringName, target: StringName) -> Area2D:
	if not rm._rooms.has(room_id):
		return null
	var root: Node = (rm._rooms[room_id] as Dictionary)["root"]
	for n in root.find_children("*", "Area2D", true, false):
		var sc = n.get_script()
		if sc != null and String(sc.resource_path).ends_with("room_transition.gd") \
				and n.target_room_id == target:
			return n
	return null


func _wait_transition() -> float:
	var DoorScript = load("res://scripts/world/room_transition.gd")
	var t := 0.0
	while DoorScript.is_transitioning() and t < 6.0:
		await create_timer(0.05).timeout
		t += 0.05
	return t


func _assert_controls_free(gate: Node, hud: Node, where: String) -> void:
	check(not gate.blocks_movement(), "%s: not UiGate.blocks_movement (layer=%s)" % [where, gate.current_layer()])
	check(not gate.is_cutscene(), "%s: cutscene cleared" % where)
	if hud:
		check(hud.safe_area.visible, "%s: HUD SafeArea visible" % where)
		check(hud.joystick_root.visible, "%s: joystick visible" % where)
		check(hud.btn_interact.visible, "%s: interact visible" % where)


func _travel_and_assert(rm: Node, gate: Node, hud: Node, player: Node, from_room: StringName, to_room: StringName, spawn: StringName = &"default") -> void:
	rm.enter_room(from_room, &"default", false)
	await create_timer(0.15).timeout
	root.get_node("DialogueManager").clear()
	gate.set_story(false)
	var door := _door_in(rm, from_room, to_room)
	check(door != null, "door %s → %s exists" % [from_room, to_room])
	if door == null:
		return
	player.global_position = door.global_position + Vector2(-28, 0)
	await create_timer(0.05).timeout
	var DoorScript = load("res://scripts/world/room_transition.gd")
	door.on_interact(player)
	check(DoorScript.is_transitioning() or gate.is_cutscene(), "transition started %s→%s" % [from_room, to_room])
	var waited := await _wait_transition()
	await create_timer(0.1).timeout
	root.get_node("DialogueManager").clear()
	gate.set_story(false)
	check(not DoorScript.is_transitioning(), "transition finished %s→%s (%.2fs)" % [from_room, to_room, waited])
	check(rm.get_active_room_id() == to_room, "arrived in %s (got %s)" % [to_room, rm.get_active_room_id()])
	_assert_controls_free(gate, hud, "%s→%s" % [from_room, to_room])
	## Klavye ekseni de serbest olmalı.
	var mim := root.get_node("MobileInputManager")
	mim.clear_held_inputs()
	Input.action_press(&"ui_right")
	await create_timer(0.25).timeout
	Input.action_release(&"ui_right")
	check(not gate.blocks_movement(), "%s→%s: movement still free after axis press" % [from_room, to_room])
	checked_rooms.append(String(to_room))


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("DOOR_CTRL SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var pm := root.get_node("PuzzleManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.35).timeout
	root.get_node("DialogueManager").clear()
	gate.set_story(false)
	var rm := root.get_node("RoomManager")
	var player: CharacterBody2D = current_scene.get_node("Player")
	var hud: Node = current_scene.get_node_or_null("UI")
	if hud == null:
		hud = get_first_node_in_group("hud")
	check(hud != null, "HUD present")

	## 1) Kritik kullanıcı yolu: balkon → ODA 03 mahzen
	pm.mark_solved(&"awakening_balcony_crossed")
	await _travel_and_assert(rm, gate, hud, player, &"awakening_balcony", &"awakening_crypt", &"from_awakening_balcony")

	## 2) Bölgeler arası birkaç kapı (gerçek hedef id'leri)
	var routes: Array = [
		[&"awakening", &"awakening_passage"],
		[&"awakening_passage", &"awakening_seal"],
		[&"awakening", &"awakening_balcony"],
		[&"decay_vines", &"decay_catacombs"],
		[&"decay_greenhouse", &"decay_shilda_wall"],
		[&"library_page", &"library_upper_stacks"],
		[&"experiment_authority", &"experiment_quarantine"],
		[&"mirrors_reverse", &"mirrors_labyrinth"],
		[&"core_threshold", &"core_memory_vault"],
	]
	for r in routes:
		var from_id: StringName = r[0]
		var to_id: StringName = r[1]
		var door := _door_in(rm, from_id, to_id)
		if door == null:
			check(false, "route door missing %s→%s" % [from_id, to_id])
			continue
		if door.is_locked():
			## Kilitliyse puzzle'ı aç (yalnız test).
			if door.required_puzzle != &"":
				pm.mark_solved(door.required_puzzle)
		await _travel_and_assert(rm, gate, hud, player, from_id, to_id)

	## 3) enter_room doğrudan (kapısız) sonrası da HUD sağlam
	rm.enter_room(&"awakening_crypt", &"default", false)
	await create_timer(0.2).timeout
	root.get_node("DialogueManager").clear()
	gate.set_story(false)
	load("res://scripts/world/room_transition.gd").reset_transition_lock()
	_assert_controls_free(gate, hud, "direct enter awakening_crypt")

	print("DOOR_CTRL rooms_checked=", ",".join(checked_rooms))
	print("DOOR_CTRL_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
