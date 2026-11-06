extends SceneTree
var checks: Array = []
var notes: Dictionary = {}
func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("run")
func wait(t: float) -> void:
	await create_timer(t).timeout
func check(id: String, passed: bool, evidence: Variant) -> void:
	checks.append({"id":id,"passed":passed,"evidence":evidence})
	print("NEXT_AUDIT ", JSON.stringify(checks.back()))
func finish_dialogue(dm: Node) -> void:
	for i in 200:
		if not dm.is_open: return
		dm.advance()
		await process_frame
func run() -> void:
	create_timer(45).timeout.connect(func(): quit(91))
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await wait(0.3)
	var dm: Node = root.get_node("DialogueManager")
	var gate: Node = root.get_node("UiGate")
	var mobile: Node = root.get_node("MobileInputManager")
	var gs: Node = root.get_node("GameState")
	var puzzles: Node = root.get_node("PuzzleManager")
	var saves: Node = root.get_node("SaveManager")
	var corpses: Node = root.get_node("CorpseManager")
	var player: Node = main.get_node("Player")
	var hud: Node = main.get_node("UI")
	var journal: Node = main.get_node("Journal")
	var cam: Node = main.get_node("Camera2D")
	check("startup_scene_loaded",is_instance_valid(player),{"engine":Engine.get_version_info().string,"viewport":str(root.get_visible_rect())})
	await finish_dialogue(dm)
	dm.say("Shilda","Bu satır yalnızca oyuncunun basışıyla ilerlemeli.")
	await wait(0.5)
	check("manual_dialogue_stays_open",dm.is_open,{"auto_disabled":true})
	check("story_blocks_input",gate.blocks_movement() and gate.blocks_combat(),{"layer":gate.current_layer()})
	check("story_pauses_threats",gate.pauses_world_threats(),{"pauses_world_threats":gate.pauses_world_threats()})
	var start: Vector2 = player.global_position
	mobile.set_move_vector(Vector2.RIGHT)
	mobile.press_attack()
	await wait(0.2)
	check("story_player_locked",player.global_position.distance_to(start)<1.0 and player._state != &"attack",{"delta":str(player.global_position-start),"state":String(player._state)})
	check("story_sprite_processes",player.sprite.can_process(),{"is_playing":player.sprite.is_playing(),"can_process":player.sprite.can_process()})
	dm.clear()
	await process_frame
	check("cancel_closes_hud",not hud.dialogue_panel.visible and not dm.is_open,{"visible":hud.dialogue_panel.visible})
	var text := "İğne çiçek gölge şüphe. Oda her şeyi hatırlıyor. ".repeat(50)
	dm.say("Shilda",text)
	dm.advance()
	await process_frame
	check("long_page_fits_panel",hud.dialogue_panel.get_global_rect().encloses(hud.dialogue_text.get_global_rect()),{"chars":text.length(),"pages":dm._pages.size(),"panel":str(hud.dialogue_panel.get_global_rect()),"text":str(hud.dialogue_text.get_global_rect())})
	check("pagination_retains_nonwhitespace",dm.pages_rejoin_equals_source(text,dm.page_max_width,dm.page_max_lines,dm.page_font_size),{"note":"existing helper ignores whitespace; not exact source equality"})
	journal.open_journal()
	await wait(0.1)
	check("journal_blocks_gameplay",gate.blocks_movement() and gate.blocks_dialogue_advance(),{"tree_paused":paused})
	check("journal_visual_animation_processes",player.sprite.can_process(),{"can_process":player.sprite.can_process(),"tree_paused":paused})
	check("journal_body_close_separate",not journal.scroll.get_global_rect().intersects(journal.btn_close.get_global_rect()),{"scroll":str(journal.scroll.get_global_rect()),"close":str(journal.btn_close.get_global_rect())})
	journal.close_journal()
	await process_frame
	check("nested_journal_preserves_story_lock",gate.blocks_movement() and dm.is_open,{"layer":gate.current_layer()})
	dm.clear()
	var before_cam: Vector2 = cam.global_position
	player.set_physics_process(false)
	player.global_position.x=540
	await wait(0.3)
	notes["same_size_room_camera"]={"before":str(before_cam),"after":str(cam.global_position),"bounds":str(cam.room_rect),"explanation":"room equals viewport; clamped center stays fixed"}
	cam.set_room_bounds(Rect2(0,0,1920,360))
	player.global_position.x=1000
	await wait(0.4)
	check("camera_follows_in_wide_fixture",cam.global_position.x>before_cam.x+100,{"camera":str(cam.global_position),"fixture_bounds":"1920x360; player teleported; not natural room"})
	cam.set_room_bounds(Rect2(0,0,640,360))
	player.global_position=Vector2(120,280)
	player.set_physics_process(true)
	var flag: StringName = &"review_saved_flag"
	gs.set_world_flag(flag,true)
	gs.set_world_flag(&"awakening_crystal_cracked",true)
	saves.save_game()
	gs.set_world_flag(flag,false)
	puzzles.solved.clear()
	var loaded: bool = saves.load_game()
	check("save_roundtrip_and_puzzle_sync",loaded and gs.get_world_flag(flag,false) and puzzles.is_solved(&"awakening_memory_code"),{"loaded":loaded,"note":"same-process roundtrip in isolated user data; not startup continuation"})
	gs.set_world_flag(&"awakening_crystal_cracked",false)
	puzzles.solved.clear()
	var plate: Node2D = get_first_node_in_group("pressure_plate")
	corpses.record_corpse_at(Vector2(plate.global_position.x,280))
	await wait(0.6)
	check("plate_accepts_nearby_corpse_fixture",puzzles.is_solved(&"awakening_weight"),{"fixture":"corpse spawned near plate; proximity detection fixture; natural pushing not tested"})
	dm.clear()
	main.enter_core()
	corpses.record_corpse_at(Vector2(210,280))
	await wait(0.2)
	var actual_parent := ""
	for c in corpses._spawned:
		if is_instance_valid(c): actual_parent=str(c.get_parent().get_path())
	check("corpse_in_active_core",actual_parent.contains("Core"),{"parent":actual_parent})
	main.enter_awakening()
	dm.clear()
	gs.player_progress_knowledge["memory_codes"]={"awakening":"314"}
	var seal: Node = get_first_node_in_group("memory_seal")
	seal.on_interact(player)
	await process_frame
	dm.clear()
	await process_frame
	check("cancel_intro_does_not_open_seal_pad",not hud.seal_root.visible,{"pad_visible":hud.seal_root.visible,"note":"intro dialogue cancelled through manager"})
	if hud._seal_waiting:
		hud._seal_result=""
		hud._seal_waiting=false
	await wait(0.1)
	dm.clear()
	await wait(0.1)
	seal._busy=false
	seal.on_interact(player)
	await finish_dialogue(dm)
	await wait(0.1)
	if hud._seal_waiting:
		hud._seal_press("3")
		hud._seal_press("1")
		hud._seal_press("4")
		hud._seal_press("OK")
	await wait(0.1)
	dm.clear()
	await process_frame
	check("cancel_success_line_does_not_solve",not puzzles.is_solved(&"awakening_memory_code"),{"solved_after_cancel":puzzles.is_solved(&"awakening_memory_code")})
	var ending: Node = main.get_node("EndingUI")
	ending.play_epilogue("Test",["Birinci","İkinci"])
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.pressed=true
	touch.index=0
	ending._on_dim_gui(touch)
	check("ending_touch_callback_advances",ending._index==1,{"index":ending._index,"fixture":"direct callback, not OS touch dispatch"})
	ending._playing=false
	await process_frame
	notes["implemented_rooms"]=["awakening","core"]
	var failed := 0
	for c in checks:
		if not c.passed: failed+=1
	var report := {"engine":Engine.get_version_info().string,"headless":true,"checks":checks.size(),"passed":checks.size()-failed,"failed":failed,"results":checks,"notes":notes}
	var f := FileAccess.open("res://next_audit.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	f.close()
	print("NEXT_SUMMARY ",checks.size()," checks, ",failed," failed")
	quit(0)
