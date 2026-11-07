extends SceneTree
## Zıplama testi: değişken yükseklik, coyote, tampon, hava fazları, çift zıplama yok,
## dash ikinci zıplama vermez, iniş sesi tek, zıplama düğmesi diğerleriyle çakışmaz.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/jump_audit.gd
var failures := 0
var player: CharacterBody2D
var mim: Node
var dm: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("JUMP ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _reset(at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player._state = &"idle"
	player._dash_cd = 0.0
	player._jump_buffer = 0.0
	mim.release_jump()
	await create_timer(0.35).timeout
	dm.clear()


## Zıplama yap, `hold` sn basılı tut, inene dek en yüksek noktayı ve fazları kaydet.
func _jump_peak(hold: float) -> Dictionary:
	var y0 := player.global_position.y
	var min_y := y0
	var phases: Array[StringName] = []
	mim.press_jump()
	var t := 0.0
	var released := false
	while t < 1.6:
		await physics_frame
		t += 1.0 / 60.0
		if not released and t >= hold:
			mim.release_jump()
			released = true
		min_y = minf(min_y, player.global_position.y)
		if phases.is_empty() or phases[-1] != player.air_phase:
			phases.append(player.air_phase)
		if t > 0.2 and player.is_on_floor() and player.air_phase == &"ground":
			break
	if not released:
		mim.release_jump()
	return {"height": y0 - min_y, "phases": phases, "time": t}


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("JUMP SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	dm = root.get_node("DialogueManager")
	mim = root.get_node("MobileInputManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	root.get_node("RoomManager").enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	player = current_scene.get_node("Player")
	var start := Vector2(200, 288)
	await _reset(start)
	check(player.is_on_floor(), "player settles on floor")
	var floor_y := player.global_position.y

	## 1) Değişken yükseklik + fazlar.
	var full: Dictionary = await _jump_peak(0.6)
	await _reset(start)
	var tap: Dictionary = await _jump_peak(0.05)
	check(full.height > 40.0, "full jump height %.0f px" % full.height)
	check(tap.height < full.height * 0.7, "tap jump lower (%.0f < %.0f)" % [tap.height, full.height])
	var ph: Array = full.phases
	var order_ok := true
	var want := [&"jump_start", &"rising", &"apex", &"falling", &"landing", &"ground"]
	var idx := -1
	for w in want:
		var j := ph.find(w, idx + 1)
		if j <= idx:
			order_ok = false
		idx = j
	check(order_ok, "air phases in order %s" % str(ph))
	check(player._last_land_ms > 0, "land sfx stamp set")

	## 2) Çift zıplama yok.
	await _reset(start)
	mim.press_jump()
	await create_timer(0.22).timeout
	mim.release_jump()
	var vy_before := player.velocity.y
	mim.press_jump()
	await physics_frame
	await physics_frame
	check(player.velocity.y > vy_before - 1.0 and player.velocity.y > player.JUMP_VELOCITY + 60.0, "no double jump in air (vy %.0f)" % player.velocity.y)
	mim.release_jump()
	await create_timer(0.8).timeout

	## 3) Dash ikinci zıplama vermez.
	await _reset(start)
	mim.press_jump()
	await create_timer(0.18).timeout
	mim.release_jump()
	player._on_dash()
	await create_timer(0.3).timeout
	var y_after_dash := player.global_position.y
	mim.press_jump()
	await create_timer(0.12).timeout
	mim.release_jump()
	check(player.global_position.y >= y_after_dash - 1.0 or player.velocity.y > 0.0, "dash gives no extra jump")
	await create_timer(0.8).timeout

	## 4) Coyote: zemini terk ettikten 0.05 sn sonra zıplanır; 0.2 sn sonra zıplanmaz.
	await _reset(start)
	player.global_position.y = floor_y - 40.0
	await create_timer(0.04).timeout
	mim.press_jump()
	await physics_frame
	await physics_frame
	check(player.velocity.y < -200.0, "coyote jump within window (vy %.0f)" % player.velocity.y)
	mim.release_jump()
	await create_timer(1.0).timeout
	await _reset(start)
	player.global_position.y = floor_y - 60.0
	await create_timer(0.2).timeout
	mim.press_jump()
	await physics_frame
	await physics_frame
	check(player.velocity.y > -100.0, "no jump after coyote window (vy %.0f)" % player.velocity.y)
	mim.release_jump()
	await create_timer(0.8).timeout

	## 5) Tampon: inişten hemen önce basılan zıplama yere değince çalışır; erken basış çalışmaz.
	await _reset(start)
	player.global_position.y = floor_y - 6.0
	player.velocity.y = 200.0
	player._coyote = 0.0
	mim.press_jump()
	await create_timer(0.03).timeout
	mim.release_jump()
	var min_y := player.global_position.y
	for i in 20:
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
	check(min_y < floor_y - 10.0, "buffered jump fires on landing (rose %.0f px)" % (floor_y - min_y))
	await create_timer(0.8).timeout
	await _reset(start)
	player.global_position.y = floor_y - 70.0
	await create_timer(0.15).timeout ## coyote doğal olarak biter; düşüş ~0.39 sn sürer
	mim.press_jump()
	await create_timer(0.05).timeout
	mim.release_jump()
	await create_timer(0.35).timeout
	min_y = player.global_position.y
	for i in 20:
		await physics_frame
		min_y = minf(min_y, player.global_position.y)
	check(min_y > floor_y - 6.0, "early press (>buffer) does not jump on landing")

	## 6) İniş sesi tek sefer.
	await _reset(start)
	player.global_position.y = floor_y - 50.0
	await create_timer(0.6).timeout
	var stamp: int = player._last_land_ms
	await create_timer(0.3).timeout
	check(stamp > 0 and player._last_land_ms == stamp, "land sound once per landing")

	## 7) Zıplama düğmesi diğer düğmelerle çakışmaz.
	var hud := current_scene.find_child("HUD", true, false)
	if hud == null:
		for n in current_scene.find_children("*", "", true, false):
			if "_buttons_by_name" in n:
				hud = n
				break
	if hud and "_buttons_by_name" in hud:
		var btns: Dictionary = hud._buttons_by_name
		var jb: Control = btns.get(&"jump")
		var overlap := []
		for k in btns:
			var b: Control = btns[k]
			if k == &"jump" or b == null or jb == null:
				continue
			if jb.get_global_rect().grow(-1).intersects(b.get_global_rect().grow(-1)):
				overlap.append(k)
		check(jb != null and overlap.is_empty(), "jump button overlaps none %s" % str(overlap))
	else:
		check(false, "HUD buttons found")
	print("JUMP_AUDIT failures=", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.SAVE_PATH))
	quit(1 if failures else 0)
