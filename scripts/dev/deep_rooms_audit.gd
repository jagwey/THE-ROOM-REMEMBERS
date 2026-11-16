extends SceneTree
## Derin bulmaca odaları: yükleme, çift yönlü kapı, 3 kademe ipucu, çözüm yolu, yeniden giriş/ölüm sonrası çözülebilirlik, ödül.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/deep_rooms_audit.gd
## Not: yankı zamanlaması başsız çalışmaz; bu yüzden plaka kimlikleri doğrudan "canlı" yazılır,
## geri kalan (kayıt noktaları, kapı mandalı, sıralı sunak, ödül) gerçek düğümlerle sınanır.
var failures := 0

## id -> {host, live: canlı yazılacak plaka kimlikleri, steps: sunak sırası, puzzle, ev}
const ROOMS := {
	"awakening_bellroom": {
		"host": "awakening_vigil",
		"live": ["awakening_bellroom_corpse", "awakening_bellroom_echo", "awakening_bellroom_stand"],
		"steps": ["gun", "yas", "gece"],
		"puzzle": "awakening_bellroom",
		"ev": "ev_bellroom_first_watch",
	},
	"library_archive_vault": {
		"host": "library_upper_stacks",
		"live": ["library_archive_vault_corpse", "library_archive_vault_echo"],
		"dial": "library_archive_vault_dials",
		"dial_targets": [4, 11, 7],
		"steps": ["muhur", "son", "kayit"],
		"puzzle": "library_archive_vault",
		"ev": "ev_vault_shilda_1927",
	},
	"experiment_twin_lab": {
		"host": "experiment_circuit",
		"live": ["experiment_twin_lab_corpse", "experiment_twin_lab_echo", "experiment_twin_lab_seal"],
		"steps": ["tarti", "kesim", "dosya"],
		"puzzle": "experiment_twin_lab",
		"ev": "ev_twin_denek14_extra",
	},
	"mirrors_inverse_hall": {
		"host": "mirrors_labyrinth",
		"live": ["mirrors_inverse_hall_mimic", "mirrors_inverse_hall_cross"],
		"steps": ["ayna", "yansima", "golge"],
		"puzzle": "mirrors_inverse_hall",
		"ev": "ev_inverse_reflection",
	},
	"core_last_record": {
		"host": "core_memory_vault",
		"live": ["core_last_record_corpse", "core_last_record_echo", "core_last_record_seal", "core_last_record_cross"],
		"steps": ["gozlem", "kayit", "veda"],
		"puzzle": "core_last_record",
		"ev": "ev_last_record_x",
	},
	"awakening_s_room": {
		"host": "awakening",
		"live": ["awakening_s_room_corpse", "awakening_s_room_echo", "awakening_s_room_seal", "awakening_s_room_cross"],
		"steps": ["uyanis", "decay", "kutuphane", "deney", "aynalar"],
		"puzzle": "awakening_s_room",
		"ev": "ev_s_room_epilogue",
	},
	"decay_rootworks": {
		"host": "decay_garden",
		"live": ["decay_rootworks_corpse", "decay_rootworks_stone", "decay_rootworks_water"],
		"steps": ["su", "kok", "cicek"],
		"puzzle": "decay_rootworks",
		"ev": "ev_rootworks_gardener",
		"water": true,
	},
}


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("DR ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _find_all(n: Node, pred: Callable, out: Array) -> void:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_find_all(c, pred, out)


func _read_all_lore(room: Node) -> int:
	var pts: Array = []
	_find_all(room, func(x): return x.has_method("on_interact") and "lore_id" in x, pts)
	for p in pts:
		p.on_interact(null)
		await create_timer(0.5).timeout
	return pts.size()


func _shrine(room: Node) -> Node:
	var l: Array = []
	_find_all(room, func(x): return x.is_in_group("sequence_shrine"), l)
	return l[0] if l.size() > 0 else null


func _check_water(room: Node, rid: String) -> void:
	var ws: Array = []
	_find_all(room, func(x): return x.has_method("step") and "level_y" in x, ws)
	check(ws.size() == 1, "%s: water_level present" % rid)
	if ws.is_empty():
		return
	var w: Node = ws[0]
	var vs: Array = []
	_find_all(w, func(x): return x.is_in_group("valve") and int(x.delta) == 1, vs)
	check(vs.size() > 0, "%s: raise valve present" % rid)
	if vs.is_empty():
		return
	vs[0].on_interact(null)
	await create_timer(1.5).timeout
	var raft: Node2D = w.get_node("Raft")
	check(w.level == 2 and absf(raft.position.y - float(w.level_y[2])) < 2.0, "%s: valve lifts raft to level 2 (y=%.0f)" % [rid, raft.position.y])
	w.reset_to_start()


func _solve_dial(room: Node, spec: Dictionary, rid: String) -> void:
	var ds: Array = []
	_find_all(room, func(x): return x.has_method("turn") and "targets" in x, ds)
	check(ds.size() == 1, "%s: dial_puzzle present" % rid)
	if ds.is_empty():
		return
	var d: Node = ds[0]
	var want: Array = spec["dial_targets"]
	check(Array(d.targets) == want, "%s: dial targets match records" % rid)
	if root.get_node("PuzzleManager").is_solved(StringName(spec["dial"])):
		return
	## Yanlış değerde çözülmez.
	d.turn(0)
	check(not root.get_node("PuzzleManager").is_solved(StringName(spec["dial"])), "%s: wrong dial value does not solve" % rid)
	for i in want.size():
		for _k in 14:
			if d.values()[i] == int(want[i]):
				break
			d.turn(i)
	check(root.get_node("PuzzleManager").is_solved(StringName(spec["dial"])), "%s: dials solve at record months" % rid)


func _press_all(room: Node, steps: Array) -> void:
	var sh := _shrine(room)
	for s in steps:
		for c in sh.get_children():
			if "step_id" in c and String(c.step_id) == String(s):
				c.on_interact(null)
		await process_frame


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("DR SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)

	for rid in ROOMS.keys():
		var spec: Dictionary = ROOMS[rid]
		var id := StringName(rid)
		var host := StringName(String(spec["host"]))
		check(rm.has_room(id), "%s: loads" % rid)
		check(String(rid) in rm.ROOM_ORDER, "%s: in ROOM_ORDER" % rid)
		check(rm.ROOM_TITLES_TR.has(rid), "%s: has TR title" % rid)
		## Kapı: ana oda -> oda, oda -> ana oda.
		var hroot: Node = rm._rooms[host]["root"]
		var side: Node = hroot.find_child("Side_%s" % rid, true, false)
		check(side != null and side.get("target_room_id") == id, "%s: host door present" % rid)
		var rroot: Node = rm._rooms[id]["root"]
		var back: Array = []
		_find_all(rroot, func(x): return "target_room_id" in x and x.target_room_id == host, back)
		check(back.size() > 0, "%s: return door to host" % rid)
		## İpucu: üç kademe.
		var ids: Array = pm.ROOM_PUZZLES.get(rid, [])
		check(ids.size() > 0, "%s: ROOM_PUZZLES entry" % rid)
		for pid in ids:
			var h: Dictionary = pm.get_hints(StringName(pid))
			check(pm.HINTS.has(StringName(pid)) and String(h.get("goal", "")) != "" and String(h.get("orientation", "")) != "" and String(h.get("explicit", "")) != "", "%s: 3 hint tiers for %s" % [rid, pid])
		pm.solved.erase(String(spec["puzzle"]))
		## Oda girişi + yanlış sıra + yeniden giriş: hâlâ çözülebilir.
		rm.enter_room(id, StringName("from_%s" % host))
		await create_timer(0.4).timeout
		check(rm.get_active_room_id() == id, "%s: entered" % rid)
		var sh := _shrine(rroot)
		check(sh != null, "%s: shrine present" % rid)
		var n_lore := await _read_all_lore(rroot)
		check(n_lore >= 2, "%s: >=2 clue records (%d)" % [rid, n_lore])
		if spec.get("water", false):
			await _check_water(rroot, String(rid))
		if spec.has("dial"):
			await _solve_dial(rroot, spec, String(rid))
		var wrong: Array = (spec["steps"] as Array).duplicate()
		wrong.reverse()
		for lid in spec["live"]:
			pm.set_live(StringName(lid), true)
		await create_timer(0.3).timeout
		await _press_all(rroot, wrong)
		check(not pm.is_solved(StringName(spec["puzzle"])), "%s: wrong order does not solve" % rid)
		## Ölüm / yeniden giriş: canlı durum sıfırlanır, oda yeniden çözülebilir.
		for lid in spec["live"]:
			pm.set_live(StringName(lid), false)
		rm.enter_room(host, StringName("from_%s" % rid))
		await create_timer(0.4).timeout
		rm.enter_room(id, StringName("from_%s" % host))
		await create_timer(0.4).timeout
		check(not pm.is_solved(StringName(spec["puzzle"])), "%s: unsolved after re-entry" % rid)
		## Çözüm yolu.
		for lid in spec["live"]:
			pm.set_live(StringName(lid), true)
		await create_timer(0.3).timeout
		sh = _shrine(rroot)
		await _press_all(rroot, spec["steps"])
		check(pm.is_solved(StringName(spec["puzzle"])), "%s: solution solves (flag)" % rid)
		var ev: Dictionary = state.player_progress_knowledge.get("evidence", {})
		check(ev.has(String(spec["ev"])), "%s: reward evidence %s" % [rid, spec["ev"]])
		## Kalıcılık: çık, tekrar gir.
		for lid in spec["live"]:
			pm.set_live(StringName(lid), false)
		rm.enter_room(host, StringName("from_%s" % rid))
		await create_timer(0.4).timeout
		rm.enter_room(id, StringName("from_%s" % host))
		await create_timer(0.4).timeout
		check(pm.is_solved(StringName(spec["puzzle"])), "%s: solved persists re-entry" % rid)
		check(sh == null or _shrine(rroot).get_progress() == (spec["steps"] as Array).size(), "%s: shrine stays lit" % rid)

	print("DR done failures=", failures)
	quit(1 if failures > 0 else 0)
