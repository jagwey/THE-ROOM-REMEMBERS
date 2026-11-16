extends SceneTree
## Oda cilası (room_polish.gd): bahçe ışık noktaları, sera toprak izi, galeri sayaç/yüzler, 1927 X silüeti,
## tapınak gölgesi, balkon vinyeti, kasa parıltıları. Görsel; bulmaca durumunu değiştirmez.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/room_polish_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("POLISH ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _enter(rm: Node, rid: String) -> Node:
	rm.enter_room(StringName(rid), &"default")
	await create_timer(0.4).timeout
	var rroot: Node = rm._rooms[StringName(rid)]["root"]
	return rroot.find_child("RoomPolish", true, false)


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("POLISH SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var rm := root.get_node("RoomManager")
	var pm := root.get_node("PuzzleManager")
	var dm := root.get_node("DialogueManager")
	var gate := root.get_node("UiGate")
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)

	## Bahçe: ışık noktası sayısı = basılan çiçek sayısı; bulmaca durumu değişmez.
	var p = await _enter(rm, "decay_garden")
	check(p != null, "garden: polish node present")
	var shrine: Node = p.get_node(p.source_path)
	await create_timer(0.2).timeout
	var vis := func() -> int:
		var n := 0
		for d in p._dots:
			if d.visible:
				n += 1
		return n
	check(vis.call() == 0, "garden: no dots before any flower")
	shrine.press("7")
	await create_timer(0.2).timeout
	check(vis.call() == 1, "garden: 1 dot after first flower")
	shrine.press("2")
	await create_timer(0.2).timeout
	check(vis.call() == 2, "garden: 2 dots after second flower")
	check(not pm.is_solved(&"decay_garden_bloom"), "garden: dots do not solve the puzzle")

	## Sera: gölge saksıdan geçince toprak izi.
	p = await _enter(rm, "decay_greenhouse")
	check(p != null, "greenhouse: polish node present")
	for old in get_nodes_in_group("greenhouse_shade"):
		old.remove_from_group("greenhouse_shade")
	var shade := Node2D.new()
	shade.add_to_group("greenhouse_shade")
	p.get_parent().add_child(shade)
	shade.global_position = Vector2(460, 252)
	await create_timer(0.2).timeout
	check(p._marked.size() == 1, "greenhouse: soil mark on the pot the shade passed")
	shade.global_position = Vector2(300, 252)
	await create_timer(0.2).timeout
	check(p._marked.size() == 1, "greenhouse: no mark where the shade has not passed")
	shade.global_position = Vector2(620, 252)
	await create_timer(0.2).timeout
	check(p._marked.size() == 2, "greenhouse: second pot marked")
	shade.queue_free()

	## Galeri: sayaç + yüzler.
	p = await _enter(rm, "mirrors_gallery")
	check(p != null and p._label != null, "gallery: counter label present")
	check(p._label.text.begins_with("Beden: "), "gallery: counter text (%s)" % p._label.text)

	## 1927: saat durunca X silüeti kısa süre görünür, sonra söner; diyalog yok.
	p = await _enter(rm, "mirrors_1927")
	check(p != null and p._fig != null, "1927: silhouette present and hidden")
	check(is_equal_approx(p._fig.modulate.a, 0.0), "1927: silhouette starts invisible")
	p._on_solved(&"mirrors_1927_walk")
	await create_timer(0.8).timeout
	check(p._fig.modulate.a > 0.2, "1927: silhouette shows when the clock stops")
	await create_timer(3.5).timeout
	check(p._fig.modulate.a < 0.05, "1927: silhouette fades away")

	## Tapınak: gölge oyuncunun bir adım önünde, çarpışmasız.
	p = await _enter(rm, "mirrors_shrine")
	check(p != null and p._ghost != null, "shrine: shadow present")
	await create_timer(0.5).timeout
	check(p._ghost.visible, "shrine: shadow visible while the player is in the room")
	check(p._ghost.get_child_count() > 0 and not (p._ghost is CollisionObject2D), "shrine: shadow has no collision")

	## Balkon: dürbün konuşmasında vinyet.
	p = await _enter(rm, "awakening_balcony")
	check(p != null and p._vig != null, "balcony: vignette present")
	check(not p._vig_on, "balcony: vignette off by default")
	var tele: Node = p.get_node(p.source_path)
	tele.set("_busy", true)
	await create_timer(1.0).timeout
	check(p._vig_on and p._layer.visible, "balcony: vignette on during the telescope interaction")
	tele.set("_busy", false)
	await create_timer(1.0).timeout
	check(not p._vig_on and not p._layer.visible, "balcony: vignette off after")

	## Kasa: yıl parıltıları.
	p = await _enter(rm, "core_memory_vault")
	check(p != null and p.get_child_count() == 6, "vault: 6 glints (2 per year column)")

	print("POLISH failures=%d" % failures)
	quit(failures)
