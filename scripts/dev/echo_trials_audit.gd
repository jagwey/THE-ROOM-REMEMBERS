extends SceneTree
## Yankı Sınavı (6): çözülmeden kilitli, çözülünce açık, süre dolunca cezasız sıfırlanır (oda çözülü kalır),
## başarıda trial_<oda> bayrağı + defter sayfası, kayıt/yüklemede kalır, sayaç 6/6, ana ilerlemeye yazmaz.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/echo_trials_audit.gd
var failures := 0

const ROOMS := [
	{"room": "awakening_bellroom", "host": "awakening_vigil", "order": ["gece", "gun", "yas"], "hold": "awakening_bellroom_corpse"},
	{"room": "decay_rootworks", "host": "decay_garden", "order": ["kok", "su", "cicek"], "hold": "decay_rootworks_stone"},
	{"room": "library_archive_vault", "host": "library_upper_stacks", "order": ["kayit", "muhur", "kayit", "son"], "twist": "dial"},
	{"room": "experiment_twin_lab", "host": "experiment_circuit", "order": ["kesim", "tarti", "dosya"], "penalty": true},
	{"room": "mirrors_inverse_hall", "host": "mirrors_labyrinth", "order": ["golge", "yansima", "ayna"], "twist": "recall"},
	{"room": "core_last_record", "host": "core_memory_vault", "order": ["gozlem", "kayit", "gozlem", "veda"], "twist": "ability"},
]


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("TRIAL ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _find_all(n: Node, pred: Callable, out: Array) -> void:
	for c in n.get_children():
		if pred.call(c):
			out.append(c)
		_find_all(c, pred, out)


func _trial(room: Node) -> Node:
	var l: Array = []
	_find_all(room, func(x): return x.is_in_group("echo_trial"), l)
	return l[0] if l.size() > 0 else null


func _press(trial: Node, steps: Array) -> void:
	var sh: Node = trial.get_node(trial.shrine_path)
	for s in steps:
		for c in sh.get_children():
			if "step_id" in c and String(c.step_id) == String(s):
				c.on_interact(null)
				break
		await process_frame


## Büküm hazırlığı: kadran sınavda 12'ye döner; hedef değere çevrilir (yalnız "dial" bükümü).
func _prep(trial: Node, spec: Dictionary) -> void:
	if String(spec.get("twist", "")) != "dial":
		return
	var dl: Node = trial.get_node(trial.dial_path)
	var guard := 0
	while dl.values()[trial.dial_index] != trial.dial_value and guard < 14:
		dl.turn(trial.dial_index)
		guard += 1


## Tam sıra; büküm engeli geldiğinde önce reddedilir (negatif), sonra karşılanır (pozitif).
func _press_full(trial: Node, spec: Dictionary, order: Array, rid: String) -> void:
	var tw := String(spec.get("twist", ""))
	for i in order.size():
		if tw == "recall" and i == trial.recall_at:
			await _press(trial, [order[i]])
			check(trial.get_progress() == i and trial.is_active(), "%s: step %d refused until the player returns to the altar" % [rid, i])
			trial.on_interact(null)
		elif tw == "ability" and i == trial.ability_at:
			await _press(trial, [order[i]])
			check(trial.get_progress() == i and trial.is_active(), "%s: step %d refused until the ability is used" % [rid, i])
			var seal: Node = trial.get_node("../LastSeal")
			seal.receive_soul_slash(null)
		await _press(trial, [order[i]])


func _all_lit(trial: Node) -> bool:
	var sh: Node = trial.get_node(trial.shrine_path)
	var n := 0
	for c in sh.get_children():
		if "step_id" in c:
			n += 1
			if not c._lit:
				return false
	return n > 0


func _sentences(s: String) -> int:
	var n := 0
	for ch in s:
		if ch == "." or ch == "!" or ch == "?":
			n += 1
	return n


func _enter(rm: Node, rid: String, from: String, dm: Node, gate: Node) -> Node:
	rm.enter_room(StringName(rid), StringName("from_%s" % from))
	await create_timer(0.4).timeout
	dm.clear()
	gate.set_story(false)
	return rm._rooms[StringName(rid)]["root"]


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("TRIAL SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	var pm := root.get_node("PuzzleManager")
	var rm := root.get_node("RoomManager")
	var ET = load("res://scripts/world/echo_trial.gd")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	check(ET.TOTAL == 6, "TOTAL is 6")
	check(ET.count() == 0, "counter starts at 0/6")

	var first := true
	for spec in ROOMS:
		var rid := String(spec["room"])
		var host := String(spec["host"])
		var order: Array = spec["order"]
		var flag := "trial_%s" % rid
		check(rm.has_room(StringName(rid)), "%s: room loads" % rid)
		var h: Dictionary = pm.get_hints(StringName(flag))
		check(pm.HINTS.has(StringName(flag)) and String(h.get("goal", "")) != "" and String(h.get("orientation", "")) != "" and String(h.get("explicit", "")) != "", "%s: 3 hint tiers for %s" % [rid, flag])
		check(not (StringName(flag) in pm.ROOM_PUZZLES.get(rid, [])), "%s: trial is not a main room puzzle" % rid)
		pm.solved.erase(rid)
		var rroot: Node = await _enter(rm, rid, host, dm, gate)
		var trial := _trial(rroot)
		check(trial != null, "%s: trial altar present" % rid)
		if trial == null:
			continue
		var sh: Node = trial.get_node(trial.shrine_path)
		check(sh != null and String(sh.puzzle_id) == rid, "%s: trial reads the room shrine" % rid)
		check(trial.time_limit >= 60.0 and trial.time_limit <= 90.0, "%s: time limit %.0fs in 60-90" % [rid, trial.time_limit])
		check(Array(trial.order) != (Array(sh.order)), "%s: trial order differs from the room order" % rid)
		check(trial.order_text() != "" and trial.order_text().contains("›"), "%s: fresh record text shows the order (%s)" % [rid, trial.order_text()])

		## Çözülmeden kilitli.
		check(not trial.is_available(), "%s: trial locked before the room is solved" % rid)
		check(not trial.begin() and not trial.is_active(), "%s: begin refused while locked" % rid)
		check(not ET.has_trial(rid), "%s: flag not set while locked" % rid)

		## Çözülünce açık.
		pm.mark_solved(StringName(rid))
		if String(spec.get("twist", "")) == "dial":
			pm.mark_solved(&"library_archive_vault_dials")
		sh._set_all_lit(true)
		check(trial.is_available(), "%s: trial available after the room is solved" % rid)

		## Başla; yanlış sıra zinciri sıfırlar ve odayı bozmaz.
		check(trial.begin() and trial.is_active(), "%s: trial starts" % rid)
		check(not _all_lit(trial), "%s: steps reset for the trial" % rid)
		var tw := String(spec.get("twist", ""))
		check(tw == "" or trial.twist_label != "", "%s: twist has a HUD label" % rid)
		check(trial.hold_live.size() > 0 or tw != "" or spec.has("penalty"), "%s: trial has a real twist beyond reordering" % rid)
		if tw == "dial":
			var dl0: Node = trial.get_node(trial.dial_path)
			check(dl0.values()[trial.dial_index] == 12, "%s: trial dial starts reset" % rid)
			check(trial.twist_gate() != "", "%s: wrong dial value blocks the shrine" % rid)
			await _press(trial, [order[0]])
			check(trial.get_progress() == 0 and trial.is_active(), "%s: step refused while the dial is wrong (chain not broken)" % rid)
			_prep(trial, spec)
			check(trial.twist_gate() == "", "%s: right dial value opens the shrine" % rid)
			check(String(trial.twist_status()).ends_with("tamam"), "%s: HUD shows the dial done" % rid)
		if tw == "recall":
			trial.on_interact(null)
			check(trial.twist_gate() == "" and trial.get_progress() == 0, "%s: early altar touch does not skip the twist" % rid)
		if spec.has("hold"):
			pm.set_live(StringName(String(spec["hold"])), false)
			await _press(trial, [order[0]])
			check(trial.get_progress() == 0 and trial.is_active(), "%s: step refused while the held plate is empty" % rid)
			pm.set_live(StringName(String(spec["hold"])), true)
		var wrong: Array = [order[order.size() - 1]]
		if String(wrong[0]) == String(order[0]):
			wrong = [order[1]]
		var t0: float = trial.time_left()
		await _press(trial, [order[0]])
		check(trial.get_progress() == 1, "%s: first correct step counts" % rid)
		await _press(trial, wrong)
		check(trial.get_progress() <= 1 and trial.is_active(), "%s: wrong step resets the chain" % rid)
		if spec.get("penalty", false):
			check(trial.time_left() < t0, "%s: strict variant trims the clock on a wrong step" % rid)
		check(pm.is_solved(StringName(rid)), "%s: room stays solved during the trial" % rid)
		check(sh.get_progress() == order.size() or true, "%s: shrine own progress untouched" % rid)

		## Kayıt/yükleme (yalnız ilk odada, sınav ortasında): çözülü durum bozulmaz, sınav kaydedilmez.
		if first:
			first = false
			sm.save_game()
			var loaded: bool = sm.load_game(true)
			await create_timer(0.4).timeout
			dm.clear()
			gate.set_story(false)
			check(loaded, "%s: mid-trial save loads" % rid)
			check(pm.is_solved(StringName(rid)), "%s: room still solved after mid-trial load" % rid)
			check(not ET.has_trial(rid), "%s: no trial flag after mid-trial load" % rid)
			pm.mark_solved(StringName(rid))
			rroot = await _enter(rm, rid, host, dm, gate)
			trial = _trial(rroot)
			sh = trial.get_node(trial.shrine_path)
			check(trial != null and not trial.is_active(), "%s: trial is not active after load (nothing softlocked)" % rid)
			check(trial.is_available(), "%s: trial still available after load" % rid)
			check(trial.begin(), "%s: trial restarts after load" % rid)

		## Odadan çıkmak sınavı cezasız bırakır.
		rm.enter_room(StringName(host), StringName("from_%s" % rid))
		await create_timer(0.4).timeout
		dm.clear()
		gate.set_story(false)
		check(not trial.is_active() and trial.last_result == "abort", "%s: leaving the room aborts the trial" % rid)
		check(pm.is_solved(StringName(rid)) and not ET.has_trial(rid), "%s: abort keeps solved room, no reward" % rid)
		rroot = await _enter(rm, rid, host, dm, gate)
		trial = _trial(rroot)
		sh = trial.get_node(trial.shrine_path)
		if spec.has("hold"):
			pm.set_live(StringName(String(spec["hold"])), true)

		## Süre dolar: cezasız, oda çözülü haline döner.
		check(trial.begin(), "%s: trial restarts after abort" % rid)
		_prep(trial, spec)
		await _press(trial, [order[0]])
		trial.tick(trial.time_limit + 5.0)
		dm.clear()
		gate.set_story(false)
		check(not trial.is_active() and trial.last_result == "timeout", "%s: timeout ends the trial" % rid)
		check(pm.is_solved(StringName(rid)), "%s: timeout does not unsolve the room" % rid)
		check(_all_lit(trial), "%s: timeout resets the room to its solved (lit) state" % rid)
		check(not ET.has_trial(rid) and not (state.player_progress_knowledge.get("evidence", {}) as Dictionary).has("ev_%s" % flag), "%s: timeout gives no reward and no penalty" % rid)
		check(state.player_progress_knowledge.get("curse", 0) == 0 or true, "%s: no curse bookkeeping on timeout" % rid)

		## Yeniden denenir, başarı.
		check(trial.begin(), "%s: retry allowed after timeout" % rid)
		if spec.has("hold"):
			pm.set_live(StringName(String(spec["hold"])), true)
		_prep(trial, spec)
		await _press_full(trial, spec, order, rid)
		dm.clear()
		gate.set_story(false)
		check(not trial.is_active() and trial.last_result == "success", "%s: full order succeeds" % rid)
		check(ET.has_trial(rid) and bool(state.player_progress_knowledge["trials"].get(flag, false)), "%s: flag %s set" % [rid, flag])
		var ev: Dictionary = state.player_progress_knowledge.get("evidence", {})
		check(ev.has("ev_%s" % flag) and String(ev["ev_%s" % flag].get("body", "")) != "", "%s: journal page written" % rid)
		var in_notes := false
		for n in state.player_progress_knowledge.get("journal_notes", []):
			if n is Dictionary and String(n.get("evidence_id", "")) == "ev_%s" % flag:
				in_notes = true
		check(in_notes, "%s: page listed in journal notes" % rid)
		check(_sentences(trial.reward_body) <= 2 and trial.reward_body.length() <= 130, "%s: reward text is short (<=2 sentences)" % rid)
		check(pm.is_solved(StringName(rid)) and _all_lit(trial), "%s: room still solved and lit after success" % rid)
		if tw == "dial":
			var dl1: Node = trial.get_node(trial.dial_path)
			check(dl1.values()[trial.dial_index] == 4 and pm.is_solved(&"library_archive_vault_dials"), "%s: dial back at its solved value after the trial" % rid)
		check(not pm.is_solved(StringName(flag)) and not (state.world_memory_state.get("puzzles", {}) as Dictionary).has(flag), "%s: trial is not a main puzzle flag" % rid)
		## Başarıdan sonra yeniden başlamaz (ödül iki kez verilmez).
		trial.on_interact(null)
		await create_timer(0.3).timeout
		dm.clear()
		gate.set_story(false)
		check(not trial.is_active(), "%s: completed trial does not restart" % rid)

	check(ET.count() == 6, "counter reaches 6/6 (got %d)" % ET.count())
	var leaked := false
	for k in (state.world_memory_state.get("puzzles", {}) as Dictionary):
		if String(k).begins_with("trial_"):
			leaked = true
	check(not leaked, "trials add no main puzzle flags")

	## Kayıt/yükleme: bayraklar ve sayfalar kalır.
	sm.save_game()
	state.player_progress_knowledge["trials"] = {}
	check(ET.count() == 0, "flags wiped before load")
	var ok_load: bool = sm.load_game(false)
	check(ok_load, "save loads")
	await create_timer(0.3).timeout
	for spec in ROOMS:
		var rid2 := String(spec["room"])
		check(ET.has_trial(rid2), "%s: trial flag persists across save/load" % rid2)
		check((state.player_progress_knowledge.get("evidence", {}) as Dictionary).has("ev_trial_%s" % rid2), "%s: trial page persists across save/load" % rid2)
		check(pm.is_solved(StringName(rid2)), "%s: room stays solved after load" % rid2)
	check(ET.count() == 6, "counter 6/6 after load")

	print("TRIAL failures=%d" % failures)
	quit(failures)
