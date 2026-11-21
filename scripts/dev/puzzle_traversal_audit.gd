extends "res://scripts/dev/traversal_bot_audit.gd"
## Bulmaca AÇIKKEN gezinme: traversal_bot_audit botu (gerçek Player fiziği) ile, çukurla bölünmüş odalarda
## oyunun kendi mekanikleri kurulmuş halde (ceset basamağı/köprü, Raf Tahtası, sal seviyesi, Gölge Atılması)
## uçtan uca ulaşılabilirlik ve DÖNÜŞ yolunu doğrular. Çalıştır:
## TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/puzzle_traversal_audit.gd
## Satırlar: PTRAV PASS/FAIL ...  Sonunda "PTRAV done failures=N".

var _gs: Node
var _cm: Node
var _pm: Node
var _dm: Node
var _gate: Node
var _room: Node2D


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("PTRAV SKIP (TORIMON_TEST=1 ile çalıştır)")
		quit(0)
		return
	_gs = root.get_node("GameState")
	_gs.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.45).timeout
	mim = root.get_node("MobileInputManager")
	curse = root.get_node("CurseManager")
	_cm = root.get_node("CorpseManager")
	_pm = root.get_node("PuzzleManager")
	_dm = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")
	_gate = root.get_node("UiGate")
	_dm.clear()
	_gate.set_story(false)
	player = current_scene.get_node("Player")

	# 1) Balkon: iki ceset basamağı (sütun dibi 618, dönüş için 770).
	await _scenario("awakening_balcony", &"default", Vector2.ZERO, "steps", false,
		["Door_awakening_crypt", "StepThornFar", "BalconyRail"], "balkon: yakın taraftan kapıya (basamak cesedi)")
	await _scenario("awakening_balcony", &"from_awakening_crypt", Vector2.ZERO, "steps", false,
		["Telescope", "Door_awakening", "NookFrag"], "balkon: kapıdan dönüş (iki basamak)")
	await _scenario("awakening_balcony", &"default", Vector2.ZERO, "near_only", false,
		["Door_awakening_crypt"], "balkon: yalnız yakın basamakla ileri geçiş")

	# 2) Katakomb: köprü cesedi (Thorn hold_corpse, anchor 898).
	await _scenario("decay_catacombs", &"default", Vector2.ZERO, "hold:Thorn", false,
		["CatacombSeal", "NookRecord"], "katakomb: köprüyle karşı yakaya")
	await _scenario("decay_catacombs", &"default", Vector2(1130, 288), "hold:Thorn", false,
		["Door_decay_vines", "Thorn", "FlowerSource"], "katakomb: karşı yakadan dönüş (köprü durur)")
	await _scenario("decay_catacombs", &"default", Vector2(1130, 288), "none", true,
		["Thorn"], "katakomb: köprü yokken karşı yakadan Thorn'a ulaşılamaz (beklenen) -> çukur ölümü yolu")

	# 3) Ayna Labirenti: BridgeThorn hold köprüsü.
	await _scenario("mirrors_labyrinth", &"default", Vector2.ZERO, "hold:BridgeThorn", false,
		["Crossed", "Shard", "Door_mirrors_shrine"], "labirent: köprüyle karşı yakaya")
	await _scenario("mirrors_labyrinth", &"from_mirrors_shrine", Vector2.ZERO, "hold:BridgeThorn", false,
		["Hint", "Door_mirrors_unbroken", "BridgeThorn"], "labirent: tapınaktan dönüş (köprü durur)")

	# 4) Kütüphane Üst Raflar: sıra çözülünce tahta iner, yüksek kapı.
	await _scenario("library_upper_stacks", &"default", Vector2.ZERO, "solve:library_shelf_order", false,
		["Door_library_forbidden_wing"], "raflar: tahta inince yüksek kapı")
	await _scenario("library_upper_stacks", &"from_library_forbidden_wing", Vector2.ZERO, "solve:library_shelf_order", false,
		["Door_library_page", "Librarian"], "raflar: yasak kanattan dönüş")

	# 5) Karantina: kaset platformu çukuru kapatır.
	await _scenario("experiment_quarantine", &"default", Vector2.ZERO, "solve:experiment_quarantine_done", false,
		["Door_experiment_core_conduit", "Cassette"], "karantina: çukur platformla, çekirdek kapısı")
	await _scenario("experiment_quarantine", &"from_experiment_core_conduit", Vector2.ZERO, "solve:experiment_quarantine_done", false,
		["Door_experiment_authority", "Sign"], "karantina: çekirdekten dönüş")

	# 6) Ayna Tapınağı: Gölge Atılması ile bariyerler + çukur.
	_gs.player_progress_knowledge["ability_shadow_dash"] = true
	await _scenario("mirrors_shrine", &"default", Vector2.ZERO, "none", false,
		["Door_mirrors_1927", "Trial", "Shard2"], "tapınak: atılmayla bariyer+çukur, kapıya")
	await _scenario("mirrors_shrine", &"default", Vector2(800, 288), "none", false,
		["Door_mirrors_labyrinth", "ShadowDash"], "tapınak: karşı yakadan dönüş")
	_gs.player_progress_knowledge["ability_shadow_dash"] = false

	# 7) Sarnıç: sal seviyeleri (oyuncu salda başlar; vanalarla yükselir).
	await _scenario("decay_cistern", &"default", Vector2.ZERO, "raft:2", false,
		["Page2", "NookFrag"], "sarnıç: sal 2. seviye -> Sayfa2 ve sağ taraf")
	await _scenario("decay_cistern", &"default", Vector2.ZERO, "raft:3", false,
		["Page3", "DrainThorn"], "sarnıç: sal 3. seviye -> Sayfa3 ve sol taraf")
	await _scenario("decay_cistern", &"default", Vector2(900, 288), "raft:1", false,
		["Door_decay_weight", "DrainThorn"], "sarnıç: sağ yakadan 1. seviye salla dönüş")

	print("PTRAV done failures=", failures)
	quit(1 if failures > 0 else 0)


## spawn/start: başlangıç; setup: ceset/bulmaca kurulumu; expect_unreach: true ise hedeflerin ULAŞILAMAMASI beklenir.
func _scenario(rid: StringName, spawn: StringName, start_at: Vector2, setup: String, expect_unreach: bool, names: Array, label: String) -> void:
	var entry: Dictionary = rm._rooms[rid]
	_room = entry.root
	cur_bounds = entry.bounds
	_gs.world_memory_state["corpses"].clear()
	rm.enter_room(rid, spawn)
	await create_timer(0.1).timeout
	_dm.clear()
	_gate.set_story(false)
	curse.reset_for_new_life()
	pits.clear()
	for pit in get_nodes_in_group("pit"):
		if pit is Area2D and _room.is_ancestor_of(pit):
			for c in pit.get_children():
				if c is CollisionShape2D and c.shape is RectangleShape2D:
					var sz: Vector2 = (c.shape as RectangleShape2D).size
					pits.append(Rect2(pit.global_position - sz * 0.5, sz))
	_open_blockers(_room)
	await _apply_setup(setup)
	await physics_frame
	await physics_frame
	var sp: Vector2 = start_at if start_at != Vector2.ZERO else player.global_position
	if setup.begins_with("raft:"):
		var w := _room.find_child("Water", true, false)
		var raft := w.get_node("Raft") as Node2D
		if start_at == Vector2.ZERO:
			sp = Vector2(raft.global_position.x - 40.0, raft.global_position.y - 24.0)
	_reset_player(sp)
	_step(30)
	var begin: Vector2 = player.global_position
	var targets: Array = []
	for nm in names:
		var t := _room.find_child(String(nm), true, false)
		if t is Node2D:
			targets.append(t)
		else:
			failures += 1
			print("PTRAV FAIL %s: hedef yok '%s'" % [label, nm])
	var res := _explore(begin, [] if expect_unreach else targets)
	var nodes: Array = res.nodes
	var missing: Array = []
	for t in targets:
		if _reach_pos(t, nodes) == null:
			missing.append(String(t.name))
	var ok: bool
	if expect_unreach:
		ok = missing.size() == targets.size()
	else:
		ok = missing.is_empty()
	if not ok:
		failures += 1
	print("PTRAV %s %s | room=%s spawn=%s start=%s nodes=%d missing=%s" % ["PASS" if ok else "FAIL", label, rid, spawn, begin, nodes.size(), missing])


func _apply_setup(setup: String) -> void:
	if setup == "none":
		return
	if setup == "steps" or setup == "near_only":
		var xs: Array = [618.0] if setup == "near_only" else [618.0, 770.0]
		for x in xs:
			_cm.record_corpse_at(Vector2(x, 288.0), &"thorn")
		await physics_frame
		return
	if setup.begins_with("hold:"):
		var thorn := _room.find_child(setup.substr(5), true, false)
		var before: Array = thorn._corpse_ids()
		_cm.record_corpse_at(Vector2(thorn.anchor_x, thorn.anchor_y), &"thorn")
		var held: bool = thorn._hold_new_corpse(before)
		if not held:
			failures += 1
			print("PTRAV FAIL hold corpse not registered for ", setup)
		await physics_frame
		thorn._update_plank()
		return
	if setup.begins_with("solve:"):
		var pid := StringName(setup.substr(6))
		if not _pm.is_solved(pid):
			_pm.mark_solved(pid)
		## Oyundaki çözümle aynı: sıra mabedi tahta köprüyü indirir (oda zaten yüklü olduğu için elle).
		for n in _room.find_children("*", "", true, false):
			if n.get("puzzle_id") == pid and n.has_method("_spawn_bridge"):
				n._spawn_bridge()
		await create_timer(0.2).timeout
		return
	if setup.begins_with("raft:"):
		var lvl := int(setup.substr(5))
		var w := _room.find_child("Water", true, false)
		w.level = lvl
		(w.get_node("Raft") as Node2D).position.y = w.level_y[lvl]
		await physics_frame
		return
