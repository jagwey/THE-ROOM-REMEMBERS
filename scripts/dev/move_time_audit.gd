extends SceneTree
## Headless: sol/sağ hız eşit; hitstop + ölüm ağır çekimi + lanet sonrası time_scale 1.0;
## lanetliyken girdi yoksa yatay hız yok.
## Kasıtlı lanet etkisi: %80+ seyrek stagger (yönsüz takılma). Kendiliğinden yürüme yok.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/move_time_audit.gd

var failures := 0
var player: CharacterBody2D
var mim: Node
var dm: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("MOVE_TIME ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _silence_stagger() -> void:
	player._curse_jitter = 1000.0
	player._stagger_timer = 0.0
	var vfx := root.get_node_or_null("/root/CurseVfx")
	if vfx == null:
		var nodes := get_nodes_in_group("curse_vfx")
		vfx = nodes[0] if nodes.size() > 0 else null
	if vfx and vfx.has_signal("stagger_pulse") and vfx.stagger_pulse.is_connected(player._on_curse_stagger):
		vfx.stagger_pulse.disconnect(player._on_curse_stagger)


func _unlock_and_neutral() -> void:
	var gate: Node = root.get_node("UiGate")
	player._input_locked = false
	player._state = &"idle"
	mim.clear_held_inputs()
	mim.set_move_vector(Vector2.ZERO)
	for _i in 8:
		dm.clear()
		gate.set_cutscene(false)
		gate.set_story(false)
		await physics_frame
		if not gate.blocks_movement():
			await physics_frame
			return


func _sample(dir_x: float) -> Vector2:
	_silence_stagger()
	await _unlock_and_neutral()
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(640, 288)
	var x0 := player.global_position.x
	mim.set_move_vector(Vector2(dir_x, 0.0))
	for _i in 24:
		await physics_frame
		_silence_stagger()
	var out := Vector2(player.velocity.x, player.global_position.x - x0)
	mim.set_move_vector(Vector2.ZERO)
	player.velocity = Vector2.ZERO
	return out


func _speeds_match(tag: String) -> void:
	var left: Vector2 = await _sample(-1.0)
	var right: Vector2 = await _sample(1.0)
	var speed_gap := absf(absf(left.x) - absf(right.x))
	var step_gap := absf(absf(left.y) - absf(right.y))
	check(speed_gap < 1.0 and step_gap < 1.5, "%s left/right speed equal v=%s step=%s" % [tag, left, right])
	check(absf(left.x) > 100.0 and absf(right.x) > 100.0, "%s both directions reach run speed" % tag)
	var half_l: Vector2 = await _sample(-0.55)
	var half_r: Vector2 = await _sample(0.55)
	var half_gap := absf(absf(half_l.x) - absf(half_r.x))
	check(half_gap < 1.0, "%s half-deflection symmetric vL=%s vR=%s" % [tag, half_l.x, half_r.x])


func _no_drift(tag: String) -> void:
	_silence_stagger()
	dm.clear()
	player._input_locked = false
	player._state = &"idle"
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(640, 288)
	mim.clear_held_inputs()
	mim.set_move_vector(Vector2.ZERO)
	await physics_frame
	var x0 := player.global_position.x
	for _i in 30:
		await physics_frame
		_silence_stagger()
	check(absf(player.velocity.x) < 1.0 and absf(player.global_position.x - x0) < 1.5, "%s no velocity without input vx=%.2f dx=%.2f" % [tag, player.velocity.x, player.global_position.x - x0])
	var biased: float = player._apply_curse_drift(0.0, 0.0)
	var neg: float = player._apply_curse_drift(-0.8, 0.0)
	var pos: float = player._apply_curse_drift(0.8, 0.0)
	check(is_zero_approx(biased) and is_equal_approx(absf(neg), absf(pos)), "%s drift axis symmetric zero=%.3f L=%.3f R=%.3f" % [tag, biased, neg, pos])


func _run() -> void:
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.4).timeout
	dm = root.get_node("DialogueManager")
	dm.clear()
	var gate: Node = root.get_node("UiGate")
	gate.set_cutscene(false)
	gate.set_story(false)
	player = current_scene.get_node("Player")
	mim = root.get_node("MobileInputManager")
	root.get_node("DeathManager").release_time_scale()
	check(is_equal_approx(Engine.time_scale, 1.0), "time_scale starts at 1")

	root.get_node("CurseManager").restore_curse(0.0)
	await _speeds_match("curse0")
	await _no_drift("curse0")

	root.get_node("CurseManager").restore_curse(50.0)
	await _speeds_match("curse50")
	await _no_drift("curse50")

	root.get_node("CurseManager").restore_curse(95.0)
	await _speeds_match("curse95")
	await _no_drift("curse95")

	OS.set_environment("TORIMON_TIME_HOLDS", "1")
	var death: Node = root.get_node("DeathManager")
	death.begin_time_hold(0.35, 0.30)
	await player._hitstop(0.06)
	check(is_equal_approx(Engine.time_scale, 0.35), "hitstop end leaves death slowmo (%.3f)" % Engine.time_scale)
	await create_timer(0.32).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "after hitstop+death slowmo time_scale is 1")

	death.begin_time_hold(0.30, 0.50)
	await physics_frame
	check(Engine.time_scale < 0.95, "hold before pause is below 1")
	root.get_node("UiGate").set_pause_menu(true)
	check(is_equal_approx(Engine.time_scale, 1.0), "pause resets time_scale")
	root.get_node("UiGate").set_pause_menu(false)
	await create_timer(0.55).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "expired pause-hold stays at 1")

	death.begin_time_hold(0.25, 0.50)
	await physics_frame
	death._on_root_child_exiting(current_scene)
	check(is_equal_approx(Engine.time_scale, 1.0), "scene exit resets time_scale")
	await create_timer(0.55).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "scene-exit hold completion stays at 1")

	death.begin_time_hold(0.20, 0.50)
	await physics_frame
	root.get_node("CurseManager").release_motion_locks()
	check(is_equal_approx(Engine.time_scale, 1.0), "curse end resets time_scale")
	await create_timer(0.55).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "curse-end hold completion stays at 1")

	death.release_time_scale()
	root.get_node("CurseManager").restore_curse(95.0)
	await _no_drift("after time sequence curse95")
	check(is_equal_approx(Engine.time_scale, 1.0), "time_scale still 1 after cursed idle")

	print("MOVE_TIME failures=", failures)
	quit(1 if failures else 0)
