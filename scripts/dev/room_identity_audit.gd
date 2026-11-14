extends SceneTree
## v1.9 oda kimliği: sıralı sunaklar, yalan ayna, balkon boşluğu, karantina rafı, günlük ipucu.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/room_identity_audit.gd

var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("ROOMID ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _room(id: StringName) -> Node:
	return root.get_node("RoomManager")._rooms[id].root


func _enter(id: StringName) -> void:
	root.get_node("RoomManager").enter_room(id, &"default")
	await process_frame
	await create_timer(0.12).timeout
	root.get_node("DialogueManager").clear()


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("ROOMID SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.35).timeout
	var pm: Node = root.get_node("PuzzleManager")
	var gs: Node = root.get_node("GameState")
	var h1 := String(pm.get_current_hint(&"core_bloom_order", 1))
	var h3 := String(pm.get_current_hint(&"core_bloom_order", 3))
	check(h1 != "" and h3 != "" and h1 != h3, "bloom hints escalate by tier")
	check(String(pm.get_current_hint(&"mirrors_labyrinth_crossed", 2)).contains("kırmızı"), "labyrinth hint names the lie")

	await _enter(&"core_bloom_garden")
	var bloom: Node = _room(&"core_bloom_garden").find_child("BloomShrine", true, false)
	var reconcile: Node = _room(&"core_bloom_garden").find_child("Reconcile", true, false)
	check(bloom != null and reconcile != null, "bloom shrine and flower exist")
	if bloom:
		bloom.press("1")
		check(bloom.get_progress() == 0 and not pm.is_solved(&"core_bloom_order"), "wrong bloom stone resets")
		bloom.press("4")
		bloom.press("2")
		check(bloom.get_progress() == 0 and not pm.is_solved(&"core_bloom_order"), "broken bloom chain resets")
		pm.set_live(&"core_bloom_weight", true)  # v1.18: taşlar plakada beden ister
		bloom.press("4")
		bloom.press("1")
		bloom.press("2")
		check(pm.is_solved(&"core_bloom_order"), "4-1-2 wakes the garden")
	check(String(reconcile.get("requires_puzzle")) == "core_bloom_order", "reconcile waits for the stones")

	await _enter(&"core_memory_vault")
	var vault: Node = _room(&"core_memory_vault").find_child("Vault", true, false)
	var vshrine: Node = _room(&"core_memory_vault").find_child("VaultShrine", true, false)
	check(not bool(gs.player_progress_knowledge.get("truth_seen", false)), "truth hidden before the years")
	if vshrine:
		vshrine.press("1995")
		check(not pm.is_solved(&"core_vault_order"), "1995 first does not open the vault")
		vshrine.press("1927")
		vshrine.press("1995")
		vshrine.press("son")
		check(pm.is_solved(&"core_vault_order"), "1927-1995-son opens the vault")
	check(String(vault.get("requires_puzzle")) == "core_vault_order", "vault lore is gated")

	await _enter(&"library_upper_stacks")
	var shelf: Node = _room(&"library_upper_stacks").find_child("ShelfShrine", true, false)
	check(shelf != null and shelf.get_node_or_null("ShelfBridge") == null, "shelf bridge is down until the books")
	if shelf:
		shelf.press("ses")
		shelf.press("muhur")
		shelf.press("cicek")
		check(pm.is_solved(&"library_shelf_order") and shelf.get_node_or_null("ShelfBridge") != null, "ses-mühür-çiçek drops the plank")

	await _enter(&"mirrors_labyrinth")
	var lab: Node = _room(&"mirrors_labyrinth")
	var lies: PackedVector3Array = lab.get("false_reflections")
	var plats: PackedVector3Array = lab.get("invisible_platforms")
	check(lies.size() >= 1, "labyrinth has a false reflection", lies.size())
	var raised := false
	for p in plats:
		if p.y <= 230.0:
			raised = true
	check(raised, "labyrinth path climbs above a hop")
	check(lab.get_node_or_null("Interactive/Crossed") != null, "crossing the labyrinth is a reward")

	await _enter(&"awakening_balcony")
	var gaps: PackedVector2Array = _room(&"awakening_balcony").get("floor_gaps")
	check(gaps.size() >= 1 and gaps[0].y - gaps[0].x >= 48.0 and gaps[0].x > 600.0, "balcony floor is broken before the seal", gaps)

	await _enter(&"experiment_quarantine")
	var q: Node = _room(&"experiment_quarantine")
	var cassette: Node2D = q.find_child("Cassette", true, false)
	var qgaps: PackedVector2Array = q.get("floor_gaps")
	check(cassette != null and cassette.position.y <= 250.0, "quarantine report sits on the ledge", cassette.position if cassette else "")
	check(qgaps.size() >= 1 and qgaps[0].x > 900.0, "quarantine gap is past the curse cloud", qgaps)
	var cloud: Node2D = q.find_child("Cloud", true, false)
	check(cloud != null and cloud.position.x > 500.0 and cloud.position.x < 800.0, "curse cloud stays on the walkable center")

	var hint: Dictionary = pm.journal_hint_for_active_room()
	check(String(hint.get("title", "")) == "Bu oda" and String(hint.get("body", "")) != "", "journal hint for the active room", hint)
	print("ROOMID failures=", failures)
	quit(1 if failures else 0)
