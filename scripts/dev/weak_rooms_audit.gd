extends SceneTree
## Zayıf oda cilası: ipuçları/delil/bulmaca öğeleri sahnede var mı, kilitler çözülebilir mi.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/weak_rooms_audit.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("WR ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _scene(room: String) -> Node:
	var ps := load("res://scenes/rooms/%s.tscn" % room) as PackedScene
	return ps.instantiate() if ps else null


func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _lore(room: Node, lore_id: String) -> Node:
	for n in room.find_children("*", "Area2D", true, false):
		if "lore_id" in n and String(n.get("lore_id")) == lore_id:
			return n
	return null


func _run() -> void:
	var pm := root.get_node("PuzzleManager")

	# core: yankı-kapı üçlüsü aynı bulmaca kimliğini paylaşır, kapı kalıcı kilit açar.
	var core := _scene("core")
	check(core != null, "core scene loads")
	if core:
		var altar := core.find_child("EchoAltar", true, false)
		var plate := core.find_child("EchoPlate", true, false)
		var gate := core.find_child("EchoGate", true, false)
		check(altar != null and plate != null and gate != null, "core: altar+plate+gate exist")
		if altar and plate and gate:
			check(String(altar.puzzle_id) == "core_entry_echo" and String(plate.puzzle_id) == "core_entry_echo", "core: altar/plate share puzzle id")
			check(String(gate.puzzle_listen) == "core_entry_echo" and bool(gate.latch_on_live), "core: gate listens + latches on live")
			var crystal := core.find_child("CoreCrystal", true, false)
			check(altar.position.x < plate.position.x and plate.position.x < gate.position.x and gate.position.x < crystal.position.x, "core: altar<plate<gate<crystal (no softlock side)")
		core.free()
	check(pm.get_hints(&"core_entry_echo").has("explicit"), "core: hint entry has explicit text")
	check(pm.ROOM_PUZZLES["core"][0] == &"core_entry_echo", "core: ROOM_PUZZLES lists echo first")

	# decay_vines / decay_cistern / passage: giriş tabelası hedefi söyler.
	for pair in [["decay_vines", "decay_vines_sign"], ["decay_cistern", "decay_cistern_goal"], ["awakening_passage", "passage_ring_sign"],
			["experiment_cells", "cells_wall_notches"], ["library_reading_cell", "reading_cell_initial_s"], ["library_reading_cell", "reading_cell_dried_flower"]]:
		var r := _scene(pair[0])
		var lp := _lore(r, pair[1]) if r else null
		check(lp != null and lp.lines.size() >= 1, "%s: lore %s present" % [pair[0], pair[1]])
		if lp:
			for l in lp.lines:
				check(String(l).length() <= 120, "%s: line <=120 chars (%d)" % [pair[1], String(l).length()])
		if r:
			r.free()

	# reading cell: kanıt + Shilda satırı, hücre notları.
	var rc := _scene("library_reading_cell")
	if rc:
		var s_notch := _lore(rc, "reading_cell_initial_s")
		check(s_notch != null and String(s_notch.evidence_title) != "", "reading cell: S. notch gives evidence")
		var fl := _lore(rc, "reading_cell_dried_flower")
		var has_shilda := false
		if fl:
			for l in fl.lines:
				if String(l).begins_with("Shilda|"):
					has_shilda = true
		check(fl != null and String(fl.evidence_title) != "" and has_shilda and bool(fl.trust_gate), "reading cell: dried flower evidence + trust-gated Shilda line")
		rc.free()

	# cells: Denek 14 izi.
	var cells := _scene("experiment_cells")
	if cells:
		var wn := _lore(cells, "cells_wall_notches")
		check(wn != null and String(wn.evidence_body).contains("Denek 14"), "cells: wall notches carry the Denek 14 trace")
		cells.free()

	# library_page: kartlar başlık + olay cümlesi taşır; Kayıt B raf/kart sırasıyla uyumlu.
	var po := _src("res://scripts/story/page_order_puzzle.gd")
	check(po.contains("Kayıt I —") and po.contains("Kayıt II —") and po.contains("Kayıt III —"), "page order: cards have titles")
	check(po.contains("Önce deney, sonra kapı, sonda mühür"), "page order: audited orientation phrase kept")
	var hall := _src("res://scenes/rooms/library_hall.tscn")
	check(hall.contains("Raflar Kayıt A'da. Kartlar: önce deney, sonra kapı, en son mühür."), "library_hall Kayıt B matches page/shelf order")
	check(not hall.contains('body = "Önce deney, sonra kapı."'), "library_hall: old Kayıt B line gone")
	var q := _src("res://scenes/rooms/experiment_quarantine.tscn")
	check(not q.contains("Sis canlıyı sever.") and q.contains("kalkan"), "quarantine: line matches corpse-shield logic")

	# mirrors_reverse tepkileri + unbroken konuşma uzunluğu.
	var rev := _scene("mirrors_reverse")
	if rev:
		var z := rev.find_child("InvertZone", true, false)
		check(z != null and String(z.enter_line) != "" and String(z.exit_line) != "", "mirrors_reverse: enter+exit reaction lines")
		rev.free()
	var sb := _src("res://scripts/story/story_beat.gd")
	var a := sb.find("func _mirrors_unbroken()")
	var b := sb.find("var ok: bool = await DialogueManager.dialogue_finished", a)
	var seg := sb.substr(a, b - a)
	var n := seg.count("DialogueManager.say(") - 2 # ilk iki koruma satırı hariç
	check(n >= 4 and n <= 24, "mirrors_unbroken: confrontation has 4-24 lines (got %d)" % n)

	print("WR DONE failures=", failures)
	quit(1 if failures > 0 else 0)
