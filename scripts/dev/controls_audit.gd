extends SceneTree
## Runtime checks for modal physics, animation processing, and fair hazard damage.
var failures := 0

func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("CONTROLS ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _run() -> void:
	var state := root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	var dm := root.get_node("DialogueManager")
	dm.clear()
	var player := current_scene.get_node("Player")
	var gate := root.get_node("UiGate")
	player.global_position = Vector2(180, 110)
	player.velocity = Vector2(40, 250)
	dm.say("Shilda", "Test sırasında dünya durur; görsel animasyon devam eder.")
	var before: Vector2 = player.global_position
	await create_timer(0.25).timeout
	check(player.global_position.distance_to(before) < 0.1, "story freezes both horizontal and vertical physics")
	check(player.sprite.can_process() and player.sprite.is_playing(), "story keeps character animation active")
	check(gate.pauses_world_threats(), "story pauses threats")
	gate.set_journal(true)
	var page: String = dm.visible_page_text()
	root.get_node("MobileInputManager").press_interact()
	check(dm.visible_page_text() == page and dm.is_open, "journal cannot advance underlying story")
	gate.set_journal(false)
	dm.clear()
	player.global_position = Vector2(180, 288)
	player.velocity = Vector2.ZERO
	player._state = &"dash"
	var hearts: int = state.hearts
	check(not player.receive_hazard_hit(200.0) and state.hearts == hearts, "dash crosses hazard without damage")
	player._state = &"idle"
	check(player.receive_hazard_hit(200.0) and state.hearts == hearts - 1, "one contact costs only one heart")
	check(not player.receive_hazard_hit(200.0) and state.hearts == hearts - 1, "repeat contact cooldown prevents instant death")
	check(not root.get_node("DeathManager").is_dying, "first contact is survivable")
	print("CONTROLS_AUDIT failures=", failures)
	quit(1 if failures else 0)
