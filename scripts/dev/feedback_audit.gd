extends SceneTree
## UX geri bildirim denetimi: ceset sınırı bildirimi, oyun süresi kaydı, bulmaca sıfırlama notu,
## günlük "yeni" rozeti, devam kartı satırları (640x360 taban genişliğinde taşma yok).
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/feedback_audit.gd
var failures := 0
var _lost_events := 0
var gs: Node
var sm: Node
var cm: Node
var pm: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("FEEDBACK ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _corpse(i: int) -> Dictionary:
	return {"id": "fb_%d" % i, "position": {"x": 100 + i, "y": 280}, "room": "awakening", "anchored": false, "anchoring": false, "has_flower": false}


func _run() -> void:
	sm = root.get_node("SaveManager")
	gs = root.get_node("GameState")
	cm = root.get_node("CorpseManager")
	pm = root.get_node("PuzzleManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("FEEDBACK SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	await process_frame
	await process_frame
	_corpse_limit()
	await _toast_queue()
	await _ambient_and_hint()
	_play_time()
	_puzzle_reset()
	_journal_badge()
	await _continue_card()
	print("FEEDBACK DONE failures=%d" % failures)
	quit(1 if failures > 0 else 0)


## 1) Sınır aşılınca sinyal bir kez; yeniden kurulumda yok.
func _corpse_limit() -> void:
	var corpses: Array = gs.world_memory_state["corpses"]
	corpses.clear()
	gs.world_memory_state["traces"].clear()
	cm.corpse_lost_to_limit.connect(func(_t): _lost_events += 1)
	for i in 3:
		corpses.append(_corpse(i))
	cm._trim_excess()
	check(_lost_events == 0, "no toast event at exactly MAX_CORPSES")
	corpses.append(_corpse(3))
	cm._trim_excess()
	check(_lost_events == 1 and corpses.size() == cm.MAX_CORPSES, "one event when oldest corpse trimmed (events=%d)" % _lost_events)
	cm.rebuild_world_corpses()
	check(_lost_events == 1, "rebuild does not emit (load path silent)")


## HUD: ölüm sinematiği sürerken bildirim bekler, rebirth sonrası gösterilir.
func _toast_queue() -> void:
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	var dm := root.get_node("DeathManager")
	dm.is_dying = true
	hud.queue_toast(hud.TOAST_CORPSE_LOST)
	check(hud._toast_shown_log.is_empty() and hud._toast_queue.size() == 1, "toast held while dying")
	dm.is_dying = false
	dm.rebirth_completed.emit()
	check(hud._toast_shown_log == [hud.TOAST_CORPSE_LOST], "toast shown after rebirth_completed")
	check(hud._toast_queue.is_empty(), "toast shown only once")
	hud.queue_toast(hud.TOAST_CORPSE_LOST)
	check(hud._toast_shown_log.size() == 1, "second toast waits while first is showing")
	hud.queue_free()
	await process_frame


## Yürüyüş odası ortam anı ziyaret başına bir kez; hızlı seyahat ipucu yalnız bir kez (kalıcı bayrak).
func _ambient_and_hint() -> void:
	var hud: CanvasLayer = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	var amb: Node = hud.get_node_or_null("RoomAmbient")
	check(amb != null, "HUD owns RoomAmbient")
	if amb == null:
		hud.queue_free()
		return
	var line := String(amb.LINES[&"experiment_quarantine"][0])
	gs.last_visit_was_new = true
	amb.on_room_changed(&"experiment_quarantine")
	check(not amb.tick_at(0.0, 100.0), "ambient: first sample only records side")
	check(not amb.tick_at(60.0, 100.0), "ambient: no fire before crossing middle")
	check(amb.tick_at(160.0, 100.0), "ambient: fires when middle crossed")
	check(hud._toast_shown_log.has(line), "ambient: line shown via toast")
	check(not amb.tick_at(0.0, 100.0), "ambient: only once per visit")
	amb.on_room_changed(&"experiment_quarantine")
	amb.tick_at(0.0, 100.0)
	check(amb.tick_at(160.0, 100.0), "ambient: fires again on next visit")
	amb.on_room_changed(&"awakening")
	amb.tick_at(0.0, 100.0)
	check(not amb.tick_at(160.0, 100.0), "ambient: rooms without a line stay silent")
	for rid in amb.LINES:
		check(String(amb.LINES[rid][0]).length() <= 40 and not String(amb.LINES[rid][0]).contains("Denek"), "ambient line short/no spoiler: %s" % rid)
	## Hızlı seyahat ipucu: art arda 3 görülmüş oda -> bir kez.
	var orig_flag: bool = GameSettings.fast_travel_hint_shown
	GameSettings.fast_travel_hint_shown = false
	gs.last_visit_was_new = false
	amb.on_room_changed(&"awakening")
	amb.on_room_changed(&"awakening_balcony")
	check(not GameSettings.fast_travel_hint_shown, "ft hint: not after 2 revisits")
	amb.on_room_changed(&"awakening")
	check(GameSettings.fast_travel_hint_shown, "ft hint: flag set after 3 revisits in a row")
	amb.on_room_changed(&"awakening_balcony")
	amb.on_room_changed(&"awakening")
	var hints := 0
	for t in hud._toast_shown_log + hud._toast_queue:
		if String(t).begins_with("İpucu:"):
			hints += 1
	check(hints == 1, "ft hint: shown exactly once (count=%d)" % hints)
	## Yeni oda seriyi sıfırlar.
	GameSettings.fast_travel_hint_shown = false
	gs.last_visit_was_new = true
	amb.on_room_changed(&"awakening")
	gs.last_visit_was_new = false
	amb.on_room_changed(&"awakening_balcony")
	amb.on_room_changed(&"awakening")
	check(not GameSettings.fast_travel_hint_shown, "ft hint: new room resets the streak")
	GameSettings.fast_travel_hint_shown = orig_flag
	GameSettings.save_settings()
	gs.last_visit_was_new = true
	hud.queue_free()
	await process_frame


func _play_time() -> void:
	gs.player_progress_knowledge["play_time_sec"] = 0.0
	gs.add_play_time(3725.0)
	check(is_equal_approx(gs.get_play_time_sec(), 3725.0), "add_play_time accumulates")
	check(gs.format_play_time(3725.0) == "1s 2dk" and gs.format_play_time(300.0) == "5dk", "format_play_time (%s / %s)" % [gs.format_play_time(3725.0), gs.format_play_time(300.0)])
	check(sm.commit_save(&"test", Vector2(120, 280), &"awakening"), "commit_save ok")
	gs.player_progress_knowledge["play_time_sec"] = 0.0
	check(sm.load_committed(false), "load_committed ok")
	check(absf(gs.get_play_time_sec() - 3725.0) < 1.0, "play time persisted across save/load (%s)" % str(gs.get_play_time_sec()))
	## Eski kayıt: anahtar yok -> 0; bozuk tür -> 0.
	var d: Dictionary = sm._deserialize_progress({"deaths": 2})
	check(float(d.get("play_time_sec", -1.0)) == 0.0, "migration default play_time_sec = 0")
	d = sm._deserialize_progress({"play_time_sec": "abc"})
	check(float(d.get("play_time_sec", -1.0)) == 0.0, "corrupt play_time_sec -> 0")


## 3) Kısmi canlı ilerleme + yükleme -> not bir kez.
func _puzzle_reset() -> void:
	pm.solved.erase("fb_plate")
	pm.set_live(&"fb_plate", true)
	check(gs.player_progress_knowledge["partial_puzzles"].has("fb_plate"), "partial flag set when live (unsolved)")
	gs.player_progress_knowledge["partial_puzzles"]["fb_plate"] = "fb_room"
	pm.reset_live_for_load() ## yükleme: canlı durum silinir
	check(not pm.is_live(&"fb_plate"), "live state reset by load")
	check(not pm.take_reset_notice(&"other_room"), "no notice in a different room")
	check(pm.take_reset_notice(&"fb_room"), "reset notice in the puzzle room")
	check(not pm.take_reset_notice(&"fb_room"), "notice only once (flag cleared)")
	## Çözülünce ya da canlı kapanınca işaret silinir.
	pm.set_live(&"fb_plate", true)
	gs.player_progress_knowledge["partial_puzzles"]["fb_plate"] = "fb_room"
	pm.set_live(&"fb_plate", false)
	check(not gs.player_progress_knowledge["partial_puzzles"].has("fb_plate"), "flag cleared when live ends normally")
	gs.player_progress_knowledge["partial_puzzles"]["fb_plate"] = "fb_room"
	pm.mark_solved(&"fb_plate")
	check(not pm.take_reset_notice(&"fb_room"), "no notice for solved puzzle")
	pm.solved.erase("fb_plate")
	gs.world_memory_state["puzzles"].erase("fb_plate")


## 4) Rozet: yeni kayıt -> sekme + genel rozet; sekme açılınca söner; kayıtla kalır.
func _journal_badge() -> void:
	gs.player_progress_knowledge["journal_notes"] = []
	gs.world_memory_state["traces"].clear()
	gs.journal_seen_init(true)
	check(not gs.journal_any_unseen(), "no badge on empty journal")
	gs.player_progress_knowledge["journal_notes"].append({"section": "notlar", "title": "Deneme Notu", "body": "x"})
	check(gs.journal_unseen("notlar") == 1 and gs.journal_unseen("gunluk") == 0 and gs.journal_any_unseen(), "new note -> notlar badge only")
	check(gs.last_journal_note_title() == "Deneme Notu", "last note title")
	check(sm.commit_save(&"test", Vector2(120, 280), &"awakening"), "commit with badge")
	gs.journal_seen_init(true) ## bellekte "hepsi görüldü" yap
	check(not gs.journal_any_unseen(), "badge cleared in memory (precondition)")
	check(sm.load_committed(false), "reload")
	check(gs.journal_unseen("notlar") == 1, "unseen count survives reload")
	## Günlük sekmesi: açınca söner, diğer sekmelerde "•" görünür.
	var journal: Node = (load("res://scenes/ui/journal.tscn") as PackedScene).instantiate()
	root.add_child(journal)
	await process_frame
	journal._show_section("gunluk")
	check(journal.tab_notlar.text.ends_with("•"), "notlar tab shows dot while unseen (%s)" % journal.tab_notlar.text)
	check(not journal.tab_gunluk.text.ends_with("•"), "gunluk tab has no dot")
	journal._show_section("notlar")
	check(gs.journal_unseen("notlar") == 0 and not gs.journal_any_unseen(), "opening tab clears badge")
	journal._show_section("gunluk")
	check(not journal.tab_notlar.text.ends_with("•"), "dot gone after tab seen")
	journal.queue_free()
	## Eski kayıt (anahtar yok) sahte rozet üretmez.
	gs.player_progress_knowledge.erase("journal_seen")
	check(not gs.journal_any_unseen(), "legacy save without journal_seen -> no false badge")
	await process_frame


## 2) Devam kartı: süre + son not satırı, 196 px'i aşmaz; 640x360 tabanında taşmaz.
func _continue_card() -> void:
	gs.player_progress_knowledge["journal_notes"] = [{"section": "notlar", "title": "Çok uzun bir not başlığı: bu başlık kartın genişliğini aşmamalı", "body": "x"}]
	gs.player_progress_knowledge["rooms_visited"] = ["awakening", "awakening_balcony", "awakening_crypt"]
	gs.player_progress_knowledge["deaths"] = 3
	gs.player_progress_knowledge["play_time_sec"] = 5400.0
	sm.commit_save(&"test", Vector2(120, 280), &"awakening")
	var ts: Control = load("res://scripts/ui/title_screen.gd").new()
	root.add_child(ts)
	for sz in [Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = sz
		ts.open(true)
		await process_frame
		await process_frame
		await process_frame
		var texts: Array = []
		var tag := "%dx%d" % [sz.x, sz.y]
		var view := Rect2(Vector2.ZERO, Vector2(sz))
		var ok_w := true
		var ok_in := true
		for l in ts._card_box.get_children():
			if l is Label:
				texts.append((l as Label).text)
				var r := (l as Label).get_global_rect()
				if r.size.x > 196.5:
					ok_w = false
				if not view.grow(1.0).encloses(r):
					ok_in = false
		var all := "\n".join(texts)
		check(all.contains("Süre: 1s 30dk"), tag + " card shows play time")
		check(all.contains("Son not: Çok uzun"), tag + " card shows last note")
		check(ok_w, tag + " card labels within 196 px")
		check(ok_in, tag + " card lines inside viewport")
	ts.queue_free()
