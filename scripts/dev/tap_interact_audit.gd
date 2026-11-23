extends SceneTree
## v1.20.6 dokunmatik kontrol: nesneye dokunarak etkileşim, menzil dışı "Yaklaşmalıyım",
## boşluğa dokunuş hiçbir şey seçmez, kılıç kısa bas = vuruş, basılı ~0.35 sn = Ruh Kesimi,
## iptal edilen basış Ruh Kesimi ateşlemez.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/tap_interact_audit.gd
var failures := 0
var _skills := 0
var _attacks := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_TOUCH_UI", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("TAP ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _make_counter(parent: Node, pos: Vector2) -> Area2D:
	var gd := GDScript.new()
	gd.source_code = "extends Area2D\nvar hits := 0\nfunc on_interact(_by):\n\thits += 1\n"
	gd.reload()
	var a := Area2D.new()
	a.set_script(gd)
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 40)
	cs.shape = r
	a.add_child(cs)
	a.position = pos
	parent.add_child(a)
	return a


func _screen(hud: Node, world: Vector2) -> Vector2:
	return hud.get_viewport().get_canvas_transform() * world


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("TAP SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	var mim := root.get_node("MobileInputManager")
	mim.skill_pressed.connect(func(): _skills += 1)
	mim.attack_pressed.connect(func(): _attacks += 1)
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	var rm := root.get_node("RoomManager")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	var player: CharacterBody2D = current_scene.get_node("Player")
	var hud: Node = get_first_node_in_group("hud")
	var room: Node = (rm._rooms[&"awakening"] as Dictionary)["root"]
	var watch: Node2D = room.find_child("PocketWatchInspect", true, false)
	check(hud != null and watch != null, "hud + watch found")

	## 1) Menzil dışındaki nesneye dokunuş: nesne seçilir ama kullanılmaz, "Yaklaşmalıyım".
	player.global_position = Vector2(watch.global_position.x - 150, 288)
	await create_timer(0.3).timeout
	var t: Node2D = hud._world_tap_target(_screen(hud, watch.global_position + Vector2(0, -6)))
	check(t == watch, "tap on far watch resolves to watch (got %s)" % [t])
	hud._resolve_world_tap(watch)
	check(not dm.is_open, "far tap does not interact")
	check(hud._far_hint_until > Time.get_ticks_msec(), "far tap sets 'Yaklaşmalıyım' hint")
	await process_frame
	await process_frame
	check(hud._context_hint.text == hud.FAR_HINT_TEXT, "context hint shows %s (got '%s')" % [hud.FAR_HINT_TEXT, hud._context_hint.text])
	hud._far_hint_until = 0

	## 2) Boş alana dokunuş hiçbir şey seçmez.
	var empty: Node2D = hud._world_tap_target(_screen(hud, Vector2(watch.global_position.x - 400, 120)))
	check(empty == null, "tap on empty space → no target (got %s)" % [empty])

	## 3) Menzildeki nesneye dokunuş tam bir kez etkileşir; oyuncu ona döner.
	## Üst üste binme: kapının (Side_awakening_balcony) üstündeki sayaç, merkeze dokununca seçilir.
	var a := _make_counter(room, Vector2(700, 270))
	player.global_position = Vector2(680, 288)
	player.set("_facing", -1.0)
	await create_timer(0.3).timeout
	var ta: Node2D = hud._world_tap_target(_screen(hud, a.global_position + Vector2(0, -10)))
	check(ta == a, "tap on near counter resolves to it (got %s)" % [ta])
	hud._resolve_world_tap(a)
	check(a.hits == 1, "near tap interacts once (hits=%d)" % a.hits)
	check(float(player.get("_facing")) > 0.0, "player turns toward tapped object")
	a.queue_free()
	## Dokunma payı: boş alandaki nesnenin ~6 px yanına dokunmak da tutar (9 mm hedef).
	var cx := watch.global_position.x - 150.0
	var c := _make_counter(room, room.to_local(Vector2(cx, 270)))
	player.global_position = Vector2(cx - 20, 288)
	await create_timer(0.3).timeout
	var tb: Node2D = hud._world_tap_target(_screen(hud, c.global_position + Vector2(18, -10)))
	check(tb == c, "tap slightly beside counter still hits (pad) (got %s)" % [tb])
	c.queue_free()
	await create_timer(0.3).timeout

	## 3b) Dokunulabilir hedef çipi: yakındaki hedefin adı el simgeli çipte; çipe dokunmak onu kullanır.
	var d := _make_counter(room, room.to_local(Vector2(cx, 270)))
	player.global_position = Vector2(cx - 20, 288)
	await create_timer(0.5).timeout
	var tgt = player.get_interaction_target()
	check(tgt == d, "near counter is the interaction target (got %s)" % [tgt])
	check(hud._hint_chip.is_visible_in_tree() and hud._hint_chip_target == tgt, "target chip shows near target")
	check(hud._context_hint.text == "", "plain hint text hidden while chip shows (got '%s')" % hud._context_hint.text)
	var chip_c: Vector2 = hud._hint_chip.get_global_rect().get_center()
	check(hud._hint_chip_hit(chip_c), "chip tap is consumed")
	check(d.hits == 1, "chip tap interacts with target (hits=%d)" % d.hits)
	check(not hud._hint_chip_hit(chip_c + Vector2(0, -90)), "tap far above chip is not a chip tap")
	d.queue_free()
	await create_timer(0.3).timeout
	check(not hud._hint_chip.is_visible_in_tree() or hud._hint_chip_target != d, "chip clears when target gone")

	## 3c) Düğme arkasında nesne → düğme saydamlaşır ama basılabilir; nesne gidince geri gelir.
	var jb: Control = hud.btn_jump
	await create_timer(0.6).timeout
	check(jb.modulate.a > 0.9, "jump button opaque with nothing behind (a=%.2f)" % jb.modulate.a)
	var jr: Rect2 = jb.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, jb.size)
	var wpos: Vector2 = hud.get_viewport().get_canvas_transform().affine_inverse() * jr.get_center()
	var e := _make_counter(room, room.to_local(wpos + Vector2(0, 14)))
	var glow := Node2D.new()
	glow.add_to_group(&"interact_glow")
	e.add_child(glow)
	await create_timer(0.6).timeout
	check(jb.modulate.a < 0.6, "object behind jump button → button fades (a=%.2f)" % jb.modulate.a)
	check(hud._button_at(jr.get_center()) == jb, "faded jump button still takes touches")
	e.queue_free()
	await create_timer(0.6).timeout
	check(jb.modulate.a > 0.9, "object gone → button opaque again (a=%.2f)" % jb.modulate.a)

	## 3d) Nesnenin üstündeki isim etiketi de dokunma alanı (nesne düğme arkasındayken isme dokunulur).
	player.global_position = Vector2(watch.global_position.x - 20, 288)
	await create_timer(0.8).timeout
	var nl := watch.get_node_or_null("InteractNameLabel") as Control
	check(nl != null and nl.visible, "watch name label visible when targeted (target=%s)" % [player.get_interaction_target()])
	if nl != null and nl.visible:
		var lr: Rect2 = nl.get_global_rect()
		check(hud._tap_rect(watch).encloses(lr), "watch tap rect includes its name label")
		var top: Vector2 = _screen(hud, Vector2(lr.get_center().x, lr.position.y + 1.0))
		check(hud._world_tap_target(top) == watch, "tap on name label top resolves to watch")

	## 4) Kılıç: kısa bas = vuruş, Ruh Kesimi yok.
	state.player_progress_knowledge["ability_soul_slash"] = true
	var btn = hud.btn_interact
	check(btn.is_visible_in_tree(), "sword button visible on touch UI")
	_attacks = 0
	_skills = 0
	hud._press_button(btn, 41)
	hud._release_touch_index(41)
	check(_attacks == 1 and _skills == 0, "short tap → slash only (atk=%d skill=%d)" % [_attacks, _skills])
	await create_timer(0.4).timeout

	## 5) Basılı tut ~0.35 sn → dolar, bırakınca Ruh Kesimi.
	_skills = 0
	hud._press_button(btn, 42)
	hud._sword_press_ms = Time.get_ticks_msec() - 400
	hud._tick_sword_charge()
	check(hud._sword_charged, "hold ≥350 ms charges sword")
	check(btn.modulate != Color.WHITE, "charged sword button glows")
	hud._release_touch_index(42)
	check(_skills == 1, "release after hold → Ruh Kesimi (skill=%d)" % _skills)
	check(not hud._sword_charged and Color(btn.modulate, 1.0) == Color.WHITE, "charge resets after release")
	await create_timer(0.4).timeout

	## 6) Dolmuş basış iptal edilirse (arayüz açıldı vb.) Ruh Kesimi ateşlenmez.
	_skills = 0
	hud._press_button(btn, 43)
	hud._sword_press_ms = Time.get_ticks_msec() - 400
	hud._tick_sword_charge()
	hud._release_all_buttons()
	check(_skills == 0, "canceled charged hold → no Ruh Kesimi")

	## 7) Yetenek yokken basılı tutmak dolmaz.
	state.player_progress_knowledge["ability_soul_slash"] = false
	_skills = 0
	hud._press_button(btn, 44)
	hud._sword_press_ms = Time.get_ticks_msec() - 400
	hud._tick_sword_charge()
	hud._release_touch_index(44)
	check(_skills == 0 and not hud._sword_charged, "no ability → hold does nothing extra")

	## 8) Beden taşınırken düğme "Bırak" olur (el dokusu, etkileşim gönderir).
	hud._set_action_drop(true)
	check(btn.texture_normal == hud._interact_tex, "carrying → sword button shows hand (Bırak)")
	hud._set_action_drop(false)
	check(btn.texture_normal == hud._attack_tex, "not carrying → sword texture back")

	print("TAP_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
