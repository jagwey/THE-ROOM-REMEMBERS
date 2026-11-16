extends SceneTree
## Geri dönüş köşeleri: 8 kayıt (4 Ruh Kesimi, 4 Gölge Atılması). Yetenek yokken kapalı, varken açık,
## kayıt alınır, bayrak kayıt/yüklemede kalır, sayaç 8/8, ana yol kapanmaz.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/backtrack_nooks_audit.gd
var failures := 0

## Yakınlık tabanı (px, x ekseni). Varsayılan 72; yalnız çok kalabalık 4 odada o odanın ulaşılabilir en iyi değeri.
const NEAR_MIN := {"awakening_crypt": 40.0, "library_hall": 44.0, "experiment_cells": 54.0, "awakening_balcony": 49.0}

const NOOKS := [
	{"room": "awakening_crypt", "k": "crypt", "ab": "soul"},
	{"room": "decay_catacombs", "k": "catacombs", "ab": "soul"},
	{"room": "library_hall", "k": "hall", "ab": "soul"},
	{"room": "experiment_cells", "k": "cells", "ab": "soul"},
	{"room": "decay_cistern", "k": "cistern", "ab": "dash"},
	{"room": "experiment_observation", "k": "observation", "ab": "dash"},
	{"room": "awakening_balcony", "k": "balcony", "ab": "dash"},
	{"room": "library_forbidden_wing", "k": "forbidden", "ab": "dash"},
]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("NOOK ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _find_all(n: Node, pred: Callable, out: Array) -> void:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_find_all(c, pred, out)


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("NOOK SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var NR = load("res://scripts/world/nook_record.gd")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	check(NR.TOTAL == 8, "TOTAL is 8")
	check(NR.count() == 0, "counter starts at 0/8")

	for spec in NOOKS:
		var rid := String(spec["room"])
		var k := String(spec["k"])
		var soul: bool = spec["ab"] == "soul"
		var akey := "ability_soul_slash" if soul else "ability_shadow_dash"
		check(rm.has_room(StringName(rid)), "%s: room loads" % rid)
		rm.enter_room(StringName(rid), &"default")
		await create_timer(0.4).timeout
		dm.clear()
		gate.set_story(false)
		var rroot: Node = rm._rooms[StringName(rid)]["root"]
		var frag: Node = rroot.find_child("NookFrag", true, false)
		var rec: Node = rroot.find_child("NookRecord", true, false)
		var g: Node = rroot.find_child("NookVein" if soul else "NookLine", true, false)
		check(frag != null and rec != null and g != null, "%s: fragment, gate, record present" % rid)
		if frag == null or rec == null or g == null:
			continue
		state.player_progress_knowledge.erase(akey)
		check(not NR.has_nook(k), "%s: record not yet taken" % k)

		## Ana yol: kapı çevresinde >=96 px; kapı engellenmez.
		var doors: Array = []
		_find_all(rroot, func(x): return "target_room_id" in x and x is Node2D, doors)
		var near_ok := true
		for d in doors:
			for n in [frag, g, rec]:
				if absf((n as Node2D).global_position.x - (d as Node2D).global_position.x) < 96.0:
					near_ok = false
		check(near_ok, "%s: nook nodes >=96px from every door" % rid)
		## Yakınlık: her köşe nesnesi diğer her etkileşimli nesneden/kapıdan >=72 px (x ekseni) uzakta.
		var others: Array = []
		_find_all(rroot, func(x): return x is Node2D and (x.has_method("on_interact") or x.has_method("apply_push") or x.is_in_group("pressure_plate") or "target_room_id" in x), others)
		var crowd := ""
		for n in [frag, g, rec]:
			for o in others:
				if o == frag or o == g or o == rec:
					continue
				var dx := absf((n as Node2D).global_position.x - (o as Node2D).global_position.x)
				if dx < float(NEAR_MIN.get(rid, 72.0)):
					crowd += " %s~%s(%d)" % [n.name, o.name, int(dx)]
		check(crowd == "", "%s: nook nodes >=%dpx from other interactables/doors%s" % [rid, int(NEAR_MIN.get(rid, 72.0)), crowd])
		if soul:
			check(g.blocking == false, "%s: vein does not block the path" % rid)
		else:
			check(g is Area2D and not (g is PhysicsBody2D), "%s: red line is non-solid" % rid)

		## Yetenek yok: kapalı.
		rec.on_interact(null)
		await create_timer(1.5).timeout
		dm.clear()
		gate.set_story(false)
		check(not NR.has_nook(k) and not pm.is_solved(StringName("nook_%s_gate" % k)), "%s: closed without ability" % k)
		## Parça okunur, yetenek yine yok: hâlâ kapalı.
		frag.on_interact(null)
		await create_timer(2.5).timeout
		var seen: Array = state.player_progress_knowledge.get("lore_seen", [])
		check(seen.has("nook_%s_a" % k), "%s: fragment readable without ability" % k)
		rec.on_interact(null)
		await create_timer(1.5).timeout
		dm.clear()
		gate.set_story(false)
		check(not NR.has_nook(k), "%s: still closed without ability after fragment" % k)
		## Yetenek var, kapı kesilmedi: hâlâ kapalı.
		state.player_progress_knowledge[akey] = true
		rec.on_interact(null)
		await create_timer(1.5).timeout
		dm.clear()
		gate.set_story(false)
		check(not NR.has_nook(k), "%s: closed with ability but gate unused" % k)
		## Kapıyı aç.
		if soul:
			g.receive_soul_slash(null)
		else:
			g.receive_shadow_dash(null)
		await create_timer(0.3).timeout
		check(pm.is_solved(StringName("nook_%s_gate" % k)), "%s: gate opens with the ability" % k)
		## Kayıt alınır.
		rec.on_interact(null)
		await create_timer(3.5).timeout
		dm.clear()
		gate.set_story(false)
		seen = state.player_progress_knowledge.get("lore_seen", [])
		check(NR.has_nook(k) and seen.has("nook_%s_b" % k), "%s: record taken, flag set" % k)

	check(NR.count() == 8, "counter reaches 8/8 (got %d)" % NR.count())

	## Kayıt/yükleme: bayraklar ve kapı çözümleri kalır.
	sm.save_game()
	state.player_progress_knowledge["nooks"] = {}
	check(NR.count() == 0, "flags wiped before load")
	var loaded: bool = sm.load_game(false)
	check(loaded, "save loads")
	await create_timer(0.3).timeout
	for spec in NOOKS:
		check(NR.has_nook(String(spec["k"])), "%s: flag persists across save/load" % spec["k"])
		check(pm.is_solved(StringName("nook_%s_gate" % spec["k"])), "%s: gate stays open after load" % spec["k"])
	check(NR.count() == 8, "counter 8/8 after load")

	print("NOOK failures=%d" % failures)
	quit(failures)
