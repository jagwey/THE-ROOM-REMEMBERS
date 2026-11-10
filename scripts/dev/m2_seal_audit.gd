extends SceneTree
## Milestone 2 Verification Audit: Memory Seal Points & Curse Mechanics (R2)
## Tests:
## 1. get_interact_label: "Sessiz Mühür" when curse <= 0, "Laneti Mühürle (%d%%)" when curse > 0
## 2. on_interact with curse <= 0: Rejected with Noroi dialogue, no commit save
## 3. Danger checks: enemy, keeper, dialogue block seal interaction
## 4. on_interact with curse > 0: Absorbs curse, clears curse to 0, sets checkpoint, commits save, glow=1.0, banner
## 5. Rollback on commit save failure: curse restored, seal discovery rolled back, error banner
## 6. Fast travel removal: _open_travel, _close_travel, _travel_to, _other_seals, _travel_layer, modal removed
## 7. 12 Primary room seals placement, spawn alignment, hazard clearance

const ROOMS: Array[StringName] = [
	&"awakening", &"decay_garden", &"library_hall", &"experiment_cells", &"mirrors_reverse", &"core_threshold",
	&"awakening_crypt", &"decay_catacombs", &"library_forbidden_wing", &"experiment_core_conduit",
	&"mirrors_shrine", &"core_seal_chamber",
]
const SEAL_SCRIPT := "memory_seal_point.gd"

var failures := 0
var total_checks := 0

var sm: Node
var gs: Node
var dm: Node
var rm: Node
var curse: Node
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
		print("M2_SEAL_AUDIT ", msg, label, " [", detail, "]")
	else:
		print("M2_SEAL_AUDIT ", msg, label)
	if not ok:
		failures += 1


func _is_seal(n: Node) -> bool:
	var sc: Script = n.get_script()
	return sc != null and String(sc.resource_path).ends_with(SEAL_SCRIPT)


func _find_seal(room_id: StringName) -> Node2D:
	var rt: Node = rm._rooms[room_id].root
	for n in rt.find_children("*", "Area2D", true, false):
		if _is_seal(n):
			return n as Node2D
	return null


func _serial(path: String) -> int:
	var d: Variant = sm._read_save(path)
	return int((d as Dictionary).get("save_serial", -1)) if d is Dictionary else -1


func _rect_of(cs: CollisionShape2D) -> Rect2:
	var r := cs.shape as RectangleShape2D
	if r == null:
		return Rect2()
	var c := cs.global_position
	return Rect2(c - r.size * 0.5, r.size)


func _is_hazard(n: Node) -> bool:
	if n.is_in_group("curse_cloud") or n.is_in_group("blood_thorn"):
		return true
	if String(n.name).begins_with("Pit"):
		return true
	var p := n.get_parent()
	return p != null and String(p.name) == "Hazards"


func _is_door(n: Node) -> bool:
	var sc: Script = n.get_script()
	return sc != null and String(sc.resource_path).ends_with("room_transition.gd")


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	sm = root.get_node("SaveManager")
	gs = root.get_node("GameState")
	dm = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")
	curse = root.get_node("CurseManager")

	if not ("qa/" in String(sm.SAVE_PATH)):
		print("M2_SEAL_AUDIT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(sm.SAVE_PATH).get_base_dir()))
	sm.delete_all_save_files()

	change_scene_to_file("res://scenes/main/main.tscn")
	await _wait(0.3)
	main = current_scene
	player = main.get_node("Player")
	dm.clear()

	var save_path := String(sm.SAVE_PATH)

	print("\n==================================================")
	print("TEST SECTION 1: INTERACTION LABEL INVARIANTS")
	print("==================================================")
	rm.enter_room(&"awakening", &"default")
	await _wait(0.15)
	dm.clear()
	var a_seal := _find_seal(&"awakening")
	check(a_seal != null, "Awakening seal instance exists")

	# Curse = 0 -> Sessiz Mühür
	curse.curse = 0.0
	check(a_seal.get_interact_label() == "Sessiz Mühür", "Curse 0.0 label is 'Sessiz Mühür'", a_seal.get_interact_label())

	# Curse negative -> Sessiz Mühür
	curse.curse = -5.0
	check(a_seal.get_interact_label() == "Sessiz Mühür", "Curse -5.0 label is 'Sessiz Mühür'", a_seal.get_interact_label())

	# Curse > 0 -> Laneti Mühürle (%d%%)
	curse.curse = 25.0
	check(a_seal.get_interact_label() == "Laneti Mühürle (25%)", "Curse 25.0 label is 'Laneti Mühürle (25%)'", a_seal.get_interact_label())

	curse.curse = 50.0
	check(a_seal.get_interact_label() == "Laneti Mühürle (50%)", "Curse 50.0 label is 'Laneti Mühürle (50%)'", a_seal.get_interact_label())

	curse.curse = 73.4
	check(a_seal.get_interact_label() == "Laneti Mühürle (73%)", "Curse 73.4 label is 'Laneti Mühürle (73%)'", a_seal.get_interact_label())

	curse.curse = 73.6
	check(a_seal.get_interact_label() == "Laneti Mühürle (74%)", "Curse 73.6 label is 'Laneti Mühürle (74%)'", a_seal.get_interact_label())

	curse.curse = 99.0
	check(a_seal.get_interact_label() == "Laneti Mühürle (99%)", "Curse 99.0 label is 'Laneti Mühürle (99%)'", a_seal.get_interact_label())

	print("\n==================================================")
	print("TEST SECTION 2: ZERO CURSE INTERACTION REJECTION")
	print("==================================================")
	sm.delete_all_save_files()
	curse.curse = 0.0
	dm.clear()
	var s_before := _serial(save_path)
	var cp_before: Vector2 = gs.get_checkpoint()

	a_seal.on_interact(player)
	await _wait(0.1)

	var s_after := _serial(save_path)
	check(s_after == s_before, "Zero curse does NOT write save file", [s_before, s_after])
	check(gs.get_checkpoint() == cp_before, "Zero curse does NOT change checkpoint")
	check(dm.is_open, "Zero curse opens dialogue")
	check(dm._speaker == "Noroi", "Dialogue speaker is Noroi", dm._speaker)
	check(dm._full_line == "Kanımda aktif bir lanet yok. Bu mühür sadece lanet altındayken uyanır.", "Dialogue text matches exact canon", dm._full_line)
	check(get_nodes_in_group("seal_banner").is_empty(), "Zero curse does NOT show seal banner")
	dm.clear()

	print("\n==================================================")
	print("TEST SECTION 3: DANGER CHECKS")
	print("==================================================")
	check(not a_seal._is_danger(), "Awakening baseline: no danger")

	# 1. Nearby enemy (within 120px)
	var foe := Node2D.new()
	foe.add_to_group("enemy")
	current_scene.add_child(foe)
	foe.global_position = player.global_position + Vector2(60, 0)
	check(a_seal._is_danger(), "Enemy within 120px triggers danger")

	curse.curse = 40.0
	var s_danger := _serial(save_path)
	a_seal.on_interact(player)
	await _wait(0.05)
	check(_serial(save_path) == s_danger, "Danger blocks interaction save commit")
	check(curse.curse == 40.0, "Danger leaves curse untouched")
	check(dm.is_open and dm._full_line == "Tehlike varken mühür tepki vermiyor.", "Danger dialogue shown")
	dm.clear()

	# Far enemy does not trigger danger
	foe.global_position = player.global_position + Vector2(300, 0)
	check(not a_seal._is_danger(), "Enemy at 300px does not trigger danger")
	foe.queue_free()
	await _wait(0.05)

	# 2. Keeper in danger mode (INTERVENE=2, COMBAT=5) within 320px
	var ksrc := GDScript.new()
	ksrc.source_code = "extends Node2D\nvar mode := 5\n"
	ksrc.reload()
	var keeper_fake := Node2D.new()
	keeper_fake.set_script(ksrc)
	keeper_fake.add_to_group("keeper")
	current_scene.add_child(keeper_fake)
	keeper_fake.global_position = player.global_position + Vector2(200, 0)
	check(a_seal._is_danger(), "Keeper in COMBAT (5) triggers danger")
	keeper_fake.set("mode", 2)
	check(a_seal._is_danger(), "Keeper in INTERVENE (2) triggers danger")
	keeper_fake.set("mode", 0)
	check(not a_seal._is_danger(), "Keeper in OBSERVE (0) does not trigger danger")
	keeper_fake.queue_free()
	await _wait(0.05)

	# 3. Open dialogue triggers danger
	dm.say("Noroi", "test")
	check(a_seal._is_danger(), "Active dialogue triggers danger")
	dm.clear()
	await _wait(0.05)
	check(not a_seal._is_danger(), "Cleared dialogue clears danger")

	print("\n==================================================")
	print("TEST SECTION 4: CURSE ABSORPTION & CHECKPOINT SAVING")
	print("==================================================")
	sm.delete_all_save_files()
	curse.curse = 65.0
	dm.clear()
	var s_pre := _serial(save_path)
	var seal_pos := a_seal.global_position

	a_seal.on_interact(player)
	var glow_on_absorb: float = a_seal._glow
	await _wait(0.15)

	check(curse.curse == 0.0, "Curse absorbed and cleared to 0.0", curse.curse)
	check(_serial(save_path) > s_pre, "Commit save succeeded, serial increased", [s_pre, _serial(save_path)])
	check(gs.discovered_seals.has(&"awakening"), "Seal registered in GameState.discovered_seals")
	check(gs.get_checkpoint().distance_to(seal_pos) < 1.0, "GameState checkpoint set to seal position", gs.get_checkpoint())
	check(gs.character_current_life_knowledge.get("checkpoint_room") == &"awakening", "Checkpoint room set to awakening")

	var committed_data: Variant = sm._read_save(save_path)
	check(committed_data is Dictionary, "Committed save file successfully read")
	if committed_data is Dictionary:
		check(float(committed_data.get("curse", -1.0)) == 0.0, "Committed save persists curse as 0.0", committed_data.get("curse"))
		var c_life: Dictionary = committed_data.get("character_current_life_knowledge", {})
		check(str(c_life.get("checkpoint_room", "")) == "awakening", "Committed save records checkpoint_room")
		check(str(c_life.get("room", "")) == "awakening", "Committed save records room")
		var cp_dict: Dictionary = c_life.get("checkpoint", {})
		var file_cp := Vector2(float(cp_dict.get("x", 0)), float(cp_dict.get("y", 0)))
		check(file_cp.distance_to(seal_pos) < 1.0, "Committed save records seal checkpoint coords", file_cp)

	check(glow_on_absorb == 1.0, "Seal glow set to 1.0 on absorption", glow_on_absorb)
	var banners := get_nodes_in_group("seal_banner")
	check(banners.size() == 1, "SealBanner spawned")
	if banners.size() > 0:
		var labels := banners[0].find_children("*", "Label", true, false)
		var title_node: Label = labels[0] if labels.size() > 0 else null
		var sub_node: Label = labels[1] if labels.size() > 1 else null
		check(title_node != null and title_node.text == "LANET MÜHÜRLENDİ", "Banner title is 'LANET MÜHÜRLENDİ'", title_node.text if title_node else "")
		check(sub_node != null and sub_node.text == "Lanet etkisi temizlendi (65%) ve mühre kazındı.", "Banner subtitle has absorbed 65%", sub_node.text if sub_node else "")
	for b in banners:
		b.queue_free()

	print("\n==================================================")
	print("TEST SECTION 5: ROLLBACK ON SAVE FAILURE")
	print("==================================================")
	rm.enter_room(&"decay_garden", &"default")
	await _wait(0.15)
	dm.clear()
	var g_seal := _find_seal(&"decay_garden")
	check(g_seal != null, "Decay garden seal exists")

	# Ensure decay_garden is not known yet
	gs.discovered_seals.erase(&"decay_garden")
	curse.curse = 38.0
	sm.force_fail_for_test = true

	var s_fail_before := _serial(save_path)
	g_seal.on_interact(player)
	await _wait(0.1)

	sm.force_fail_for_test = false
	var s_fail_after := _serial(save_path)

	check(s_fail_after == s_fail_before, "Failed save did not increment serial")
	check(curse.curse == 38.0, "Curse rolled back to 38.0 after failed save", curse.curse)
	check(not gs.discovered_seals.has(&"decay_garden"), "Decay garden discovery rolled back")

	var fail_banners := get_nodes_in_group("seal_banner")
	if fail_banners.size() > 0:
		var f_labels := fail_banners[0].find_children("*", "Label", true, false)
		var f_title: Label = f_labels[0] if f_labels.size() > 0 else null
		check(f_title != null and f_title.text == "MÜHÜR YAZILAMADI", "Failure banner shown", f_title.text if f_title else "")
	for b in fail_banners:
		b.queue_free()

	print("\n==================================================")
	print("TEST SECTION 6: FAST TRAVEL METHODS AND MODAL REMOVAL")
	print("==================================================")
	# Fast travel functions removed from memory_seal_point.gd
	check(not a_seal.has_method("_open_travel"), "_open_travel() completely removed from memory_seal_point")
	check(not a_seal.has_method("_close_travel"), "_close_travel() completely removed from memory_seal_point")
	check(not a_seal.has_method("_travel_to"), "_travel_to() completely removed from memory_seal_point")
	check(not a_seal.has_method("_other_seals"), "_other_seals() completely removed from memory_seal_point")
	check(a_seal.get("_travel_layer") == null, "_travel_layer variable removed")
	check(a_seal.get("TRAVEL_LAYER") == null, "TRAVEL_LAYER constant removed")
	check(a_seal.get("TRAVEL_GROUP") == null, "TRAVEL_GROUP constant removed")

	# Interacting with an already known seal with curse does NOT open any modal
	curse.curse = 30.0
	a_seal.on_interact(player)
	await _wait(0.1)
	check(get_nodes_in_group("seal_travel_modal").is_empty(), "No seal_travel_modal created on known seal interaction")
	check(root.get_node("UiGate").current_layer() == 0, "UiGate not locked in story mode")

	print("\n==================================================")
	print("TEST SECTION 7: PRIMARY ROOMS SEAL PLACEMENT")
	print("==================================================")
	for rid in ROOMS:
		rm.enter_room(rid, &"default")
		await _wait(0.1)
		dm.clear()
		var seal := _find_seal(rid)
		check(seal != null, "Seal exists in %s" % rid)
		if seal == null:
			continue
		var sp: Dictionary = rm._rooms[rid].spawns
		var marker := StringName("seal_%s" % rid)
		check(sp.has(marker) and (sp[marker] as Vector2).distance_to(seal.global_position) < 2.0, "Spawn %s matches seal pos" % marker)
		var seal_rect := Rect2(seal.global_position + Vector2(-24, -60), Vector2(48, 60))
		var bad_nodes: Array = []
		var rt: Node = rm._rooms[rid].root
		for n in rt.find_children("*", "Node2D", true, false):
			if n == seal or not (_is_hazard(n) or _is_door(n)):
				continue
			var hit := false
			for cs in n.find_children("*", "CollisionShape2D", true, false):
				if _rect_of(cs).grow(8.0).intersects(seal_rect):
					hit = true
			if _is_door(n) and absf((n as Node2D).global_position.x - seal.global_position.x) < 56.0:
				hit = true
			if hit:
				bad_nodes.append(str(n.name))
		check(bad_nodes.is_empty(), "Seal clear of hazards/doors in %s" % rid, bad_nodes)
		check(seal.global_position.y >= 270.0 and seal.global_position.x > 150.0, "Seal on floor in %s" % rid, seal.global_position)

	sm.delete_all_save_files()
	print("\n==================================================")
	print("M2 SEAL AUDIT SUMMARY: Total checks = ", total_checks, " | Failures = ", failures)
	print("==================================================")
	quit(1 if failures > 0 else 0)
