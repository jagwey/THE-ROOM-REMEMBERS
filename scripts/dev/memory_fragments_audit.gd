extends SceneTree
## Kırık Anı (5) + S.'nin Odası kapısı: okuma kapısı, cezasız yanlış sıra, doğru sıra, sayaç, kayıt/yükleme, kilit.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/memory_fragments_audit.gd
var failures := 0
const HOSTS := {
	"uyanis": "awakening_vigil",
	"decay": "decay_vines",
	"kutuphane": "library_clockroom",
	"deney": "experiment_circuit",
	"aynalar": "mirrors_dual",
}


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("MF ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _find_all(n: Node, pred: Callable, out: Array) -> void:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_find_all(c, pred, out)


func _touch(sh: Node, sid: String) -> void:
	for c in sh.get_children():
		if "step_id" in c and String(c.step_id) == sid:
			c.on_interact(null)
	await process_frame
	root.get_node("DialogueManager").clear()


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("MF SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var MS = load("res://scripts/world/memory_shrine.gd")
	var NK = load("res://scripts/world/nook_record.gd")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)

	check(MS.count() == 0, "starts at 0/5")
	var prev_room: StringName = &"awakening"
	for mid in HOSTS.keys():
		var rid := StringName(HOSTS[mid])
		check(rm.has_room(rid), "%s: host room loads" % mid)
		var puzzle := StringName("memory_" + mid)
		check(pm.HINTS.has(puzzle), "%s: hint entry" % mid)
		var ids: Array = pm.ROOM_PUZZLES.get(String(rid), [])
		check(ids.size() > 0 and String(ids[ids.size() - 1]) == String(puzzle), "%s: optional puzzle listed last (main hint first)" % mid)
		rm.enter_room(rid, &"default")
		await create_timer(0.4).timeout
		dm.clear()
		var rroot: Node = rm._rooms[rid]["root"]
		var l: Array = []
		_find_all(rroot, func(x): return x.is_in_group("sequence_shrine") and "memory_id" in x, l)
		check(l.size() == 1, "%s: one memory shrine" % mid)
		if l.is_empty():
			continue
		var sh: Node = l[0]
		var order: Array = Array(sh.order)
		check(order.size() == 3, "%s: 3 fragments in order" % mid)
		var curse_before: float = root.get_node("CurseManager").curse
		## Okuma kapısı: üçü okunmadan sıra sayılmaz.
		await _touch(sh, String(order[2]))
		await _touch(sh, String(order[1]))
		check(not pm.is_solved(puzzle) and sh.read_count() == 2, "%s: order presses ignored before all read" % mid)
		await _touch(sh, String(order[0]))
		check(sh.read_count() == 3, "%s: all three read" % mid)
		## Yanlış sıra: cezasız, çözmez.
		for s in [order[2], order[1], order[0]]:
			await _touch(sh, String(s))
		check(not pm.is_solved(puzzle), "%s: wrong order does not solve" % mid)
		check(is_equal_approx(root.get_node("CurseManager").curse, curse_before), "%s: wrong order has no curse penalty" % mid)
		check(not MS.has_memory(mid), "%s: no flag after wrong order" % mid)
		## Doğru sıra.
		for s in order:
			await _touch(sh, String(s))
		check(pm.is_solved(puzzle), "%s: right order solves" % mid)
		check(MS.has_memory(mid), "%s: persistent flag set" % mid)
		check(state.player_progress_knowledge.get("memories", {}).get(mid, false) == true, "%s: flag stored in progress" % mid)
		prev_room = rid
	check(MS.count() == 5, "counter reaches 5/5 (got %d)" % MS.count())

	## Kayıt / yükleme kalıcılığı.
	check(sm.save_game(), "save_game ok")
	state.player_progress_knowledge["memories"] = {}
	check(MS.count() == 0, "flags cleared before load")
	check(sm.load_game(false), "load_game ok")
	check(MS.count() == 5, "memories survive save/load (got %d)" % MS.count())

	## Ana yol açık: Kırık Anı çözülmeden de geçiş mümkün (kapılar anı bayrağına bağlı değil).
	var blockers: Array = []
	for rid2 in HOSTS.values():
		var rr: Node = rm._rooms[StringName(rid2)]["root"]
		_find_all(rr, func(x): return "required_puzzle" in x and String(x.required_puzzle).begins_with("memory_"), blockers)
	check(blockers.is_empty(), "no door requires a memory puzzle")

	## S.'nin Odası kapısı: <8 kilitli, mesaj eksik sayıyı söyler, 8/8 açık.
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.4).timeout
	dm.clear()
	var aroot: Node = rm._rooms[&"awakening"]["root"]
	var side: Node = aroot.find_child("Side_awakening_s_room", true, false)
	check(side != null, "S-room door exists in awakening")
	if side != null:
		var all_ids := ["a", "b", "c", "d", "e", "f", "g", "h"]
		state.player_progress_knowledge["nooks"] = {}
		check(side.is_locked(), "S-room door locked at 0/8")
		var half := {}
		for i in range(5):
			half[all_ids[i]] = true
		state.player_progress_knowledge["nooks"] = half
		check(NK.count() == 5 and side.is_locked(), "S-room door locked at 5/8 (count %d)" % NK.count())
		side.on_interact(null)
		await process_frame
		var shown := String(dm.get("current_text")) if "current_text" in dm else ""
		print("MF INFO refusal text: ", shown)
		var full := {}
		for i in range(8):
			full[all_ids[i]] = true
		state.player_progress_knowledge["nooks"] = full
		check(NK.count() == 8 and not side.is_locked(), "S-room door open at 8/8 (count %d)" % NK.count())
	print("MF done failures=", failures)
	quit(1 if failures > 0 else 0)
