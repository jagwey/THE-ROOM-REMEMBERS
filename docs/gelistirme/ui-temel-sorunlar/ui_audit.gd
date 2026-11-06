extends SceneTree

var results: Array = []
func _initialize() -> void:
	call_deferred("run")
func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
func check(id: String, passed: bool, evidence: Dictionary) -> void:
	results.append({"id": id, "passed": passed, "evidence": evidence})
	print("UI_AUDIT ", JSON.stringify(results.back()))
func box(node: Control) -> Dictionary:
	var r := node.get_global_rect()
	return {"x":r.position.x,"y":r.position.y,"w":r.size.x,"h":r.size.y,"minimum":str(node.get_combined_minimum_size()),"clip":node.clip_contents}
func run() -> void:
	create_timer(25.0).timeout.connect(func(): quit(90))
	var scene: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await wait(3.5)
	var hud: Node = scene.get_node("UI")
	var journal: Node = scene.get_node("Journal")
	var player: Node = scene.get_node("Player")
	var dm: Node = root.get_node("DialogueManager")
	var mobile: Node = root.get_node("MobileInputManager")
	var snapshots := {"viewport":str(root.get_visible_rect()),"safe_area":box(hud.safe_area),"dialogue":box(hud.dialogue_panel),"speaker":box(hud.dialogue_speaker),"text":box(hud.dialogue_text),"journal_panel":box(journal.panel),"journal_title":box(journal.title),"journal_body":box(journal.body),"journal_close":box(journal.btn_close)}
	# Visual bounds from measured PNG opaque main components, mapped through KEEP_ASPECT_CENTERED.
	var panel_rect: Rect2 = journal.panel.get_global_rect()
	var scale_factor: float = minf(panel_rect.size.x / 320.0, panel_rect.size.y / 180.0)
	var draw_origin: Vector2 = panel_rect.position + (panel_rect.size - Vector2(320,180) * scale_factor) * 0.5
	var book_rect := Rect2(draw_origin + Vector2(64,3)*scale_factor,Vector2(191,126)*scale_factor)
	check("journal_widgets_within_book_art",book_rect.encloses(journal.title.get_global_rect()) and book_rect.encloses(journal.body.get_global_rect()) and book_rect.encloses(journal.btn_close.get_global_rect()),{"book_rect":str(book_rect),"title":box(journal.title),"body":box(journal.body),"close":box(journal.btn_close)})
	check("journal_body_close_no_overlap",not journal.body.get_global_rect().intersects(journal.btn_close.get_global_rect()),{"intersection":str(journal.body.get_global_rect().intersection(journal.btn_close.get_global_rect()))})
	hud._on_dialogue_line("Bekçi","Oraya gitme.")
	await process_frame
	check("dialogue_avoids_controls",not hud.dialogue_panel.get_global_rect().intersects(hud.joystick_base.get_global_rect()) and not hud.dialogue_panel.get_global_rect().intersects(hud.btn_dash.get_global_rect()) and not hud.dialogue_panel.get_global_rect().intersects(hud.btn_interact.get_global_rect()),{"dialogue":box(hud.dialogue_panel),"joystick":box(hud.joystick_base),"dash":box(hud.btn_dash),"interact":box(hud.btn_interact)})
	var long_text := "İğne, çiçek, gölge, şüphe: Oda her şeyi hatırlıyor. ".repeat(24)
	hud._on_dialogue_line("Hafızasını kaybetmiş uzun isimli bir tanık",long_text)
	await process_frame
	await process_frame
	check("long_dialogue_stays_in_panel",hud.dialogue_panel.get_global_rect().encloses(hud.dialogue_text.get_global_rect()),{"text":box(hud.dialogue_text),"panel":box(hud.dialogue_panel),"line_count":hud.dialogue_text.get_line_count(),"characters":long_text.length(),"max_lines_visible":hud.dialogue_text.max_lines_visible})
	check("speaker_stays_in_panel",hud.dialogue_panel.get_global_rect().encloses(hud.dialogue_speaker.get_global_rect()),{"speaker":box(hud.dialogue_speaker),"panel":box(hud.dialogue_panel)})
	hud._on_dialogue_closed()
	journal.open_journal()
	var start_x: float = player.position.x
	mobile.set_move_vector(Vector2.RIGHT)
	await wait(0.2)
	mobile.set_move_vector(Vector2.ZERO)
	check("journal_blocks_movement",absf(player.position.x-start_x)<1.0,{"delta_x":player.position.x-start_x,"journal_visible":journal.visible})
	mobile.press_attack()
	mobile.release_attack()
	check("journal_blocks_attack",player._state != &"attack",{"state":String(player._state),"attack_monitoring":player.attack_area.monitoring})
	var touch := InputEventScreenTouch.new()
	touch.index=7
	touch.pressed=true
	touch.position=hud.joystick_base.get_global_rect().get_center()+Vector2(20,0)
	Input.parse_input_event(touch)
	await process_frame
	check("journal_blocks_global_joystick_input",not hud._joy_active and mobile.move_vector == Vector2.ZERO,{"joy_active":hud._joy_active,"move_vector":str(mobile.move_vector),"touch_id":hud._joy_touch_index})
	# Direct handler fixture distinguishes callback behavior from headless event dispatch.
	hud._input(touch)
	check("joystick_callback_respects_modal",not hud._joy_active and mobile.move_vector == Vector2.ZERO,{"joy_active":hud._joy_active,"move_vector":str(mobile.move_vector),"fixture":"HUD._input called directly while journal visible"})
	touch=InputEventScreenTouch.new()
	touch.index=7
	touch.pressed=false
	touch.position=hud.joystick_base.get_global_rect().get_center()+Vector2(20,0)
	Input.parse_input_event(touch)
	hud._input(touch)
	await process_frame
	dm.say("Bekçi","İlk satır")
	dm.say("Bekçi","İkinci satır")
	var queued_before: int = dm._queue.size()
	mobile.press_interact()
	mobile.release_interact()
	check("journal_prevents_background_dialogue_advance",dm._queue.size()==queued_before,{"queued_before":queued_before,"queued_after":dm._queue.size(),"journal_visible":journal.visible})
	dm.clear()
	journal.close_journal()
	await wait(0.4)
	# clear() should leave UI in a coherent closed state.
	dm.say("Bekçi","Kısa satır")
	dm.clear()
	check("dialogue_clear_hides_panel",not hud.dialogue_panel.visible,{"manager_is_open":dm.is_open,"panel_visible":hud.dialogue_panel.visible})
	# Body size must not push Close outside its intended region under a long journal entry.
	journal.open_journal()
	journal.body.text="[b]Türkçe uzun günlük[/b]\n"+long_text.repeat(4)
	await process_frame
	check("journal_scroll_enabled",journal.body.scroll_active and not journal.body.fit_content,{"scroll_active":journal.body.scroll_active,"fit_content":journal.body.fit_content,"body":box(journal.body)})
	var whisper: Control=scene.get_node("CurseVFX/Whisper")
	check("curse_whisper_has_separate_text_region",not whisper.get_global_rect().intersects(hud.dialogue_text.get_global_rect()),{"whisper":box(whisper),"dialogue_text":box(hud.dialogue_text),"note":"geometry only; concurrence depends on gameplay events"})
	# Synthetic viewport insets validate layout behavior, not an Android notch API.
	hud.safe_area.offset_left=16.0
	hud.safe_area.offset_top=8.0
	hud.safe_area.offset_right=-48.0
	hud.safe_area.offset_bottom=-12.0
	await process_frame
	check("buttons_follow_safe_area_insets",hud.safe_area.get_global_rect().encloses(hud.btn_interact.get_global_rect()) and hud.safe_area.get_global_rect().encloses(hud.btn_journal.get_global_rect()),{"safe_area":box(hud.safe_area),"interact":box(hud.btn_interact),"journal_button":box(hud.btn_journal),"fixture":"synthetic insets L16 T8 R48 B12"})
	var output := {"engine":Engine.get_version_info()["string"],"headless":true,"snapshots":snapshots,"results":results}
	var f:=FileAccess.open("res://ui_audit.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(output,"\t"))
	f.close()
	quit(0)
