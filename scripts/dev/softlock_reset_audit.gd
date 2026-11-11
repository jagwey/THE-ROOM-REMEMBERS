extends SceneTree
## Kilitlenme / durum sıfırlama denetimi (BUG-001, BUG-002, BUG-010):
##  - ölüm sırasında ruh serbest kalırsa veya sahne yenilenirse is_dying/faz/ruh temiz kalmalı, eski coroutine yeni oyunu bozmamalı
##  - ele geçirilme sırasında sahne yenilenirse possessing + UiGate cutscene temiz kalmalı
##  - start_new_game / return_to_title sonrası ölüm, possession ve cutscene durumları sıfır
##  - _begin_possession yeniden girişi çift overlay / çift sayaç üretmemeli
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/softlock_reset_audit.gd
var failures := 0
var sm: Node
var gs: Node
var death: Node
var curse: Node
var gate: Node
var dm: Node
var rm: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("SOFTLOCK ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _until(cond: Callable, timeout_sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if float(Time.get_ticks_msec() - t0) / 1000.0 > timeout_sec:
			return false
		await process_frame
	return true


## Sonraki senaryodan önce otoload durumunu elle temizle (başarısız senaryo diğerlerini kirletmesin).
func _hard_reset() -> void:
	death.is_dying = false
	death.phase = death.Phase.ALIVE
	death.release_time_scale()
	curse.possessing = false
	gate.set_cutscene(false)
	curse.reset_for_new_life()
	gs.possession_count = 0
	gs.clear_story_flags()
	dm.clear()


func _boot() -> void:
	_hard_reset()
	rm.reset_registry()
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await _wait(0.4)
	dm.clear()
	gs.player_progress_knowledge["awakening_mystery_seen"] = true
	rm.enter_room(&"awakening", &"rebirth_bed", false)
	await _wait(0.2)
	dm.clear()


func _clean_state(tag: String) -> void:
	check(not death.is_dying, tag + ": is_dying false", death.is_dying)
	check(death.phase == death.Phase.ALIVE, tag + ": phase ALIVE", death.phase_name())
	check(not is_instance_valid(death._soul), tag + ": no leftover soul")
	check(not curse.possessing, tag + ": possessing false", curse.possessing)
	check(not gate.is_cutscene(), tag + ": UiGate cutscene false", gate.is_cutscene())
	check(is_equal_approx(Engine.time_scale, 1.0), tag + ": time_scale 1.0", Engine.time_scale)


func _overlay_count() -> int:
	var n := 0
	var ov_script: Script = load("res://scripts/ui/possession_overlay.gd")
	if current_scene == null:
		return 0
	for c in current_scene.get_children():
		if c.get_script() == ov_script:
			n += 1
	return n


func _run() -> void:
	sm = root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("SOFTLOCK SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(sm.SAVE_PATH).get_base_dir()))
	sm.delete_all_save_files()
	gs = root.get_node("GameState")
	death = root.get_node("DeathManager")
	curse = root.get_node("CurseManager")
	gate = root.get_node("UiGate")
	dm = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")

	## S1) Ruh ölüm geçişinde serbest kalır (tween ruha bağlı) -> ölüm akışı yine de bitmeli.
	await _boot()
	var hook1 := func(p: int) -> void:
		if p == death.Phase.SOUL_TRANSITION and is_instance_valid(death._soul):
			death._soul.free()
	death.phase_changed.connect(hook1)
	gs.damage(99)
	var done1: bool = await _until(func() -> bool: return not death.is_dying, 5.0)
	death.phase_changed.disconnect(hook1)
	check(done1, "S1 soul freed mid-transition: death flow still completes (is_dying false)", death.is_dying)
	await _wait(0.3)
	_clean_state("S1")

	## S2) Ölüm sırasında Yeni Oyun (sahne yenilenir).
	await _boot()
	var fired2 := [false]
	var hook2 := func(p: int) -> void:
		if p == death.Phase.SOUL_RELEASE and not fired2[0]:
			fired2[0] = true
			sm.start_new_game()
	death.phase_changed.connect(hook2)
	gs.damage(99)
	await _until(func() -> bool: return fired2[0], 3.0)
	await _wait(1.5)
	death.phase_changed.disconnect(hook2)
	_clean_state("S2 death+new_game")
	await _wait(3.0) ## eski coroutine dirilirse yeni oyunu bozar
	_clean_state("S2 later")
	check(not gs.has_story_flag(&"first_death_completed"), "S2: stale death coroutine did not touch the new game", gs.has_story_flag(&"first_death_completed"))
	check(curse.curse < 50.0, "S2: stale respawn did not add curse", curse.curse)
	check(int(gs.player_progress_knowledge.get("deaths", 0)) == 0, "S2: death counter reset", gs.player_progress_knowledge.get("deaths", 0))

	## S3) Ölüm sırasında Ana Menüye Dön (return_to_title).
	await _boot()
	var fired3 := [false]
	var hook3 := func(p: int) -> void:
		if p == death.Phase.SOUL_RELEASE and not fired3[0]:
			fired3[0] = true
			var menu := current_scene.get_node_or_null("SessionMenu")
			if menu:
				menu.return_to_title()
	death.phase_changed.connect(hook3)
	gs.damage(99)
	await _until(func() -> bool: return fired3[0], 3.0)
	await _wait(1.5)
	death.phase_changed.disconnect(hook3)
	_clean_state("S3 death+return_to_title")
	await _wait(2.0)
	_clean_state("S3 later")

	## S4) Ele geçirilme sırasında Yeni Oyun.
	await _boot()
	curse.set_curse(100.0)
	await _wait(0.3)
	check(curse.possessing and gate.is_cutscene(), "S4 precondition: possession running + cutscene")
	sm.start_new_game()
	await _wait(1.2)
	_clean_state("S4 possession+new_game")
	check(gs.possession_count == 0, "S4: possession_count reset", gs.possession_count)
	await _wait(6.0) ## ilk sekans ~4.5 sn; eski coroutine dirilirse committed yükler / sayaç artar
	_clean_state("S4 later")
	check(gs.possession_count == 0 and curse.curse < 50.0, "S4: stale possession did not touch new game", [gs.possession_count, curse.curse])

	## S5) Ele geçirilme sırasında Ana Menüye Dön.
	await _boot()
	curse.set_curse(100.0)
	await _wait(0.3)
	check(curse.possessing and gate.is_cutscene(), "S5 precondition: possession running + cutscene")
	var menu5 := current_scene.get_node_or_null("SessionMenu")
	check(menu5 != null, "S5: SessionMenu present")
	if menu5:
		menu5.return_to_title()
	await _wait(1.2)
	_clean_state("S5 possession+return_to_title")
	await _wait(6.0)
	_clean_state("S5 later")

	## S6) Yeniden giriş: üç kez çağrı -> tek sekans, tek overlay, tek sayaç artışı.
	await _boot()
	var pc0: int = gs.possession_count
	curse.fail_curse_possession()
	curse.fail_curse_possession()
	curse._begin_possession()
	await process_frame
	check(gs.possession_count == pc0 + 1, "S6: re-entry guarded, possession_count +1 only", gs.possession_count - pc0)
	check(_overlay_count() == 1, "S6: exactly one PossessionOverlay", _overlay_count())
	var done6: bool = await _until(func() -> bool: return not curse.possessing, 20.0)
	check(done6, "S6: possession finishes", curse.possessing)
	await _wait(0.3)
	check(_overlay_count() == 0, "S6: overlay freed after finish", _overlay_count())
	check(not gate.is_cutscene(), "S6: cutscene released after finish")

	sm.delete_all_save_files()
	print("SOFTLOCK_AUDIT failures=", failures)
	quit(1 if failures else 0)
