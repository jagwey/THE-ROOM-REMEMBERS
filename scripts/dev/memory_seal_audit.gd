extends SceneTree
## Hafiza Muhru denetimi: 12 ana odada muhur, tehlike/kapi ortusmesi yok, lanetliyken commit eder,
## lanetsiz red, guvenlik kapisi, commit -> oda degis -> load_committed -> muhur konumu.
## Calistir: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/memory_seal_audit.gd
const ROOMS: Array[StringName] = [
	&"awakening", &"decay_garden", &"library_hall", &"experiment_cells", &"mirrors_reverse", &"core_threshold",
	&"awakening_crypt", &"decay_catacombs", &"library_forbidden_wing", &"experiment_core_conduit",
	&"mirrors_shrine", &"core_seal_chamber",
]
const SEAL_SCRIPT := "memory_seal_point.gd"
var failures := 0
var main: Node
var rm: Node
var sm: Node
var gs: Node
var dm: Node
var player: Node2D
var curse: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("SEAL ", "PASS " if ok else "FAIL ", label, " ", detail)
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
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("SEAL SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(sm.SAVE_PATH).get_base_dir()))
	sm.delete_all_save_files()
	change_scene_to_file("res://scenes/main/main.tscn")
	await _wait(0.3)
	main = current_scene
	rm = root.get_node("RoomManager")
	player = main.get_node("Player")
	curse = root.get_node("CurseManager")
	dm.clear()
	var path := String(sm.SAVE_PATH)

	## Eksik alan -> yalniz Uyanis muhru acik.
	check(sm._deserialize_seals(null) == [&"awakening"], "missing discovered_seals defaults to awakening")

	## 1) Her odada muhur + spawn isaretcisi + ortusme yok.
	for rid in ROOMS:
		rm.enter_room(rid, &"default")
		await _wait(0.1)
		dm.clear()
		var seal := _find_seal(rid)
		check(seal != null, "seal exists in %s" % rid)
		if seal == null:
			continue
		var sp: Dictionary = rm._rooms[rid].spawns
		var marker := StringName("seal_%s" % rid)
		check(sp.has(marker) and (sp[marker] as Vector2).distance_to(seal.global_position) < 2.0, "spawn %s matches seal" % marker, sp.get(marker, null))
		var seal_rect := Rect2(seal.global_position + Vector2(-24, -60), Vector2(48, 60))
		var bad: Array = []
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
				bad.append(str(n.name))
		check(bad.is_empty(), "seal clear of hazards/doors in %s" % rid, bad)
		check(seal.global_position.y >= 270.0 and seal.global_position.x > 150.0, "seal on floor in %s" % rid, seal.global_position)
		var crowd: Array = []
		var foes: Array = []
		for n in rt.find_children("*", "Node2D", true, false):
			if n == seal:
				continue
			var d := (n as Node2D).global_position.distance_to(seal.global_position)
			if n.has_method("on_interact") and d < 80.0:
				crowd.append("%s@%d" % [n.name, int(d)])
			if n.is_in_group("enemy") and d < 160.0:
				foes.append("%s@%d" % [n.name, int(d)])
		check(crowd.is_empty(), "no other interactable within 80px in %s" % rid, crowd)
		check(foes.is_empty(), "no enemy spawn within 160px in %s" % rid, foes)

	## 2) Lanetsiz etkilesim kayit yazmaz; lanetliyken clear_curse + commit (Uyanis).
	rm.enter_room(&"awakening", &"default")
	await _wait(0.15)
	dm.clear()
	var a_seal := _find_seal(&"awakening")
	sm.delete_all_save_files()
	curse.set_curse(0.0)
	var s0 := _serial(path)
	a_seal.on_interact(player)
	await _wait(0.15)
	check(_serial(path) <= s0, "zero curse does not commit", [s0, _serial(path)])
	check(dm.is_open or _serial(path) <= s0, "zero curse rejects save (dialogue or no commit)")
	dm.clear()
	check(curse.curse <= 0.0, "curse unchanged when rejected")
	curse.add_curse(40.0)
	var s1c := _serial(path)
	a_seal.on_interact(player)
	await _wait(0.1)
	dm.clear()
	var c: Variant = sm._read_save(path)
	check(c is Dictionary and _serial(path) > s1c, "cursed interact commits (serial up)", [s1c, _serial(path)])
	check(curse.curse <= 0.0, "seal clears curse to zero", curse.curse)
	if c is Dictionary:
		var life: Dictionary = c["character_current_life_knowledge"]
		check(str(life.get("room", "")) == "awakening" and str(life.get("checkpoint_room", "")) == "awakening", "committed records room")
		check((c["discovered_seals"] as Array).has("awakening"), "committed file lists awakening seal")
	check(get_nodes_in_group("seal_banner").size() >= 1, "banner shown")
	check(not FileAccess.file_exists(sm.resume_path()), "seal does not write resume file")

	## 4) Tehlike kapisi: yakin dusman ve diyalog.
	check(not a_seal._is_danger(), "no danger baseline in awakening")
	var s2 := _serial(path)
	var foe := Node2D.new()
	foe.add_to_group("enemy")
	current_scene.add_child(foe)
	foe.global_position = player.global_position + Vector2(60, 0)
	a_seal.on_interact(player)
	await _wait(0.05)
	check(_serial(path) == s2, "enemy within 120px blocks seal")
	check(dm.is_open, "blocked seal shows danger line")
	dm.clear()
	foe.global_position = player.global_position + Vector2(400, 0)
	check(not a_seal._is_danger(), "far enemy does not block")
	foe.queue_free()
	await _wait(0.05)
	dm.clear()
	dm.say("Noroi", "test")
	check(a_seal._is_danger(), "dialogue blocks seal")
	dm.clear()
	await _wait(0.05)
	var ksrc := GDScript.new()
	ksrc.source_code = "extends Node2D
var mode := 5
"
	ksrc.reload()
	var keeper_fake := Node2D.new()
	keeper_fake.set_script(ksrc)
	keeper_fake.add_to_group("keeper")
	current_scene.add_child(keeper_fake)
	keeper_fake.global_position = player.global_position + Vector2(200, 0)
	check(a_seal._is_danger(), "keeper in COMBAT blocks seal")
	keeper_fake.set("mode", 2)
	check(a_seal._is_danger(), "keeper in INTERVENE blocks seal")
	keeper_fake.set("mode", 0)
	check(not a_seal._is_danger(), "keeper in OBSERVE does not block seal")
	keeper_fake.queue_free()
	await _wait(0.05)

	## Banner / bolge karti cakismaz (ikisi ayni anda tetiklenir).
	var card_cls = load("res://scripts/ui/region_title_card.gd")
	card_cls.show_region_title("library")
	await _wait(0.1)
	curse.add_curse(30.0)
	a_seal.on_interact(player)
	await _wait(0.7)
	dm.clear()
	var card_ok: bool = card_cls.is_showing()
	var card_rect := Rect2()
	var banner_rect := Rect2()
	if card_cls.instance != null:
		card_rect = (card_cls.instance.get("_container") as Control).get_node("Backing").get_global_rect()
	var banners := get_nodes_in_group("seal_banner")
	if banners.size() == 1:
		banner_rect = (banners[0].get_node("BannerBox/Backing") as Control).get_global_rect()
	check(card_ok and banner_rect.size.x > 0.0 and not card_rect.intersects(banner_rect), "seal banner does not overlap region card", [card_rect, banner_rect])
	dm.clear()

	## 3) Yeni muhur: lanetliyken kesif listesi + commit; resume dosyasi.
	rm.enter_room(&"decay_garden", &"default")
	await _wait(0.15)
	dm.clear()
	var g_seal := _find_seal(&"decay_garden")
	curse.add_curse(35.0)
	var s1 := _serial(path)
	g_seal.on_interact(player)
	await _wait(0.1)
	dm.clear()
	check(_serial(path) > s1 and gs.discovered_seals.has(&"decay_garden"), "second seal commits and is discovered")
	check(curse.curse <= 0.0, "garden seal cleared curse")
	sm.save_game()
	var rs: Variant = sm._read_save(sm.resume_path())
	check(rs is Dictionary and (rs["discovered_seals"] as Array).has("decay_garden") and (rs["discovered_seals"] as Array).has("awakening"), "resume file persists discovered_seals")

	## 5) Bilinen muhuru lanetliyken yeniden etkinlestir -> yine commit; seyahat menusu yok (v1.7).
	var s3 := _serial(path)
	curse.add_curse(22.0)
	g_seal.on_interact(player)
	await _wait(0.1)
	dm.clear()
	check(_serial(path) > s3, "re-activation still commits when cursed")
	check(get_first_node_in_group("seal_travel_modal") == null, "no seal travel modal")
	check(curse.curse <= 0.0, "re-activation clears curse")

	## 6) commit -> oda degistir -> load_committed -> muhur konumu.
	rm.enter_room(&"library_hall", &"default")
	await _wait(0.15)
	dm.clear()
	var l_seal := _find_seal(&"library_hall")
	curse.add_curse(28.0)
	l_seal.on_interact(player)
	await _wait(0.1)
	dm.clear()
	rm.enter_room(&"awakening", &"default")
	await _wait(0.1)
	check(sm.load_committed(false), "load_committed ok")
	rm.enter_room(&"library_hall", &"checkpoint")
	await _wait(0.15)
	check(rm.get_active_room_id() == &"library_hall" and player.global_position.distance_to(l_seal.global_position) < 8.0, "committed save restores at seal", player.global_position)
	check(gs.discovered_seals.has(&"library_hall") and gs.discovered_seals.has(&"awakening"), "discovered_seals survive load_committed")

	sm.delete_all_save_files()
	print("SEAL RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
