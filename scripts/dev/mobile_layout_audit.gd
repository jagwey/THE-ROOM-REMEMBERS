extends SceneTree
## Telefon (yatay) dokunmatik HUD yerleşim denetimi: dokunmatik düğmeler birbirine / HUD metinlerine /
## diyalog kutusuna binmez, güvenli alan (çentik ~80 px) içinde kalır, fiziksel piksel olarak >= 44 px,
## diyalog/hedef metni kutu dışına taşmaz. Normal + büyük yazı, 8 çözünürlük.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/mobile_layout_audit.gd
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(2778, 1284), Vector2i(1600, 720),
	Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2048, 1536), Vector2i(1280, 800),
]
const MIN_TAP_PX := 44.0
const NOTCH_PX := 80.0
const LONG_OBJECTIVE := "Hedef: Kürsüdeki mührü bul, sonra üç kandili sırayla yak ve zincirin ucundaki kapıyı aç; acele etme, oda seni hatırlıyor."
const LONG_LINE := "Uzun bir konuşma satırı: duvarlar ağır ağır nefes alıyor, taşın altındaki isimleri tek tek okumaya çalışıyorsun ama harfler kayıyor, kayıyor, kayıyor; sonunda yalnız kendi sesinin yankısı kalıyor ve kapı hâlâ kapalı."
var failures := 0
var _checks := 0
var hud: CanvasLayer
var DM: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_TOUCH_UI", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		failures += 1
		print("ML FAIL ", label)


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("ML SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DM = root.get_node("DialogueManager")
	var gs := root.get_node("GameState")
	gs.player_progress_knowledge["ability_soul_slash"] = true # Skill düğmesi görünür (en kötü durum)
	gs.player_progress_knowledge["journal_unlocked"] = true
	hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	var sm_node: CanvasLayer = (load("res://scripts/ui/session_menu.gd") as GDScript).new()
	sm_node.name = "SessionMenu"
	root.add_child(sm_node)
	await process_frame
	await process_frame
	GameSettings.text_speed = 2
	var saved_scale_idx: int = GameSettings.button_scale_idx
	## Buton boyutu: 0.8 ve 1.2 (en kötü durum) her çözünürlükte; normal ölçekte büyük yazı da denenir.
	for scale_idx in [2, 0, 4]:
		GameSettings.button_scale_idx = scale_idx
		hud.apply_button_scale()
		for sz in RESOLUTIONS:
			for large in ([false, true] if scale_idx == 2 else [false]):
				GameSettings.font_large = large
				var tag := "%dx%d%s%s" % [sz.x, sz.y, " large" if large else "", "" if scale_idx == 2 else " btn%d%%" % GameSettings.BUTTON_SCALE_PCT[scale_idx]]
				var before := failures
				await _audit_one(sz, tag)
				print("ML ", "PASS " if failures == before else "FAIL ", tag)
	GameSettings.font_large = false
	GameSettings.button_scale_idx = saved_scale_idx
	hud.apply_button_scale()
	_ux_checks()


func _settle() -> void:
	for i in 3:
		await process_frame


## Pencere px / viewport birimi (canvas_items+expand: tek tip ölçek).
func _scale() -> float:
	var vp := root.get_visible_rect().size
	return minf(float(root.size.x) / vp.x, float(root.size.y) / vp.y)


func _apply_notch(sc: float) -> void:
	## DisplayServer güvenli alanı headless'ta taklit edilemez: aynı clamp ile inset'i elle uygula.
	var sa: Control = hud.safe_area
	var inset := minf(NOTCH_PX / sc, 64.0)
	sa.offset_left = inset
	sa.offset_right = -inset
	sa.offset_top = 0.0
	sa.offset_bottom = 0.0


func _audit_one(sz: Vector2i, tag: String) -> void:
	root.size = sz
	await _settle()
	var sc := _scale()
	_apply_notch(sc)
	hud.apply_text_size_setting(true)
	hud.refresh_touch_controls()
	root.get_node("GameState").room_changed.emit(&"awakening")
	hud._refresh_objective_now()
	hud._objective.text = LONG_OBJECTIVE
	hud._layout_objective_and_hint()
	await _settle()
	hud._context_hint.text = "El · Geçidi kullan"
	## Geri bildirim bildirimi (toast) + günlük rozeti de yerleşim denetimine girer.
	hud._toast_queue.clear()
	hud._toast_time_left = 0.0
	hud.queue_toast("Bu odadaki düzenek sıfırlandı. En eski bedenin toprağa karıştı.")
	hud._journal_dot.visible = true
	hud._process(0.0)
	await _settle()
	# --- Oyun hali: dokunmatik düğmeler + HUD metinleri
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var safe: Rect2 = hud.safe_area.get_global_rect()
	var buttons := _buttons()
	var texts := _hud_texts()
	_check_set(buttons, texts, safe, vp, sc, tag + " play")
	# Joystick: tabanı güvenli alan içinde ve düğmelere/metne binmez
	var joy := {"Joystick": (hud.joystick_base as Control).get_global_rect()}
	_check_set(joy, texts, safe, vp, sc, tag + " play joy")
	for bn in buttons:
		check(not (buttons[bn] as Rect2).intersects(joy["Joystick"] as Rect2), "%s play: %s overlaps joystick" % [tag, bn])
	check(hud._toast_label != null and hud._toast_label.is_visible_in_tree(), tag + " toast visible")
	var dot: Rect2 = (hud._journal_dot as Control).get_global_rect()
	check(safe.grow(0.5).encloses(dot) and (hud.btn_journal as Control).get_global_rect().grow(0.5).encloses(dot), tag + " journal badge inside button/safe area")
	# Hedef metni: sarılmış satırlar kutuya sığar
	var obj: Label = hud._objective
	check(obj.size.y >= float(obj.get_line_count() * obj.get_line_height()), "%s objective fits its box" % tag)
	check(obj.get_global_rect().end.x <= (hud.btn_journal as Control).get_global_rect().position.x + 0.5 \
		or obj.get_global_rect().end.y <= (hud.btn_journal as Control).get_global_rect().position.y, "%s objective clear of journal btn" % tag)
	# Menü düğmesi (SessionMenu): güvenli alan içinde, >= 44 px, Günlük düğmesine binmez
	var smenu := root.find_child("SessionMenu", true, false)
	if smenu != null:
		smenu._menu_safe_area.offset_left = hud.safe_area.offset_left
		smenu._menu_safe_area.offset_right = hud.safe_area.offset_right
		await _settle()
		var mb: Button = smenu._menu_button
		var mr := mb.get_global_rect()
		check(vp.grow(0.5).encloses(mr), "%s menu button outside screen %s" % [tag, mr])
		check(safe.grow(0.5).encloses(mr), "%s menu button outside safe area %s vs %s" % [tag, mr, safe])
		check(minf(mr.size.x, mr.size.y) * sc >= MIN_TAP_PX, "%s menu button tap %.0fpx" % [tag, minf(mr.size.x, mr.size.y) * sc])
		check(not mr.intersects((hud.btn_journal as Control).get_global_rect()), tag + " menu button overlaps journal")
		for bn in buttons:
			check(not mr.intersects(buttons[bn] as Rect2), "%s menu button overlaps %s" % [tag, bn])
	await _door_label_check(tag, vp)
	# Diyalog: tek satır + seçimler
	await _dialogue_state(tag, sc, safe, vp)


## Kapı etiketi sağ-alt düğmelerin (Zıpla vb.) altında kalmaz: çakışırsa yukarı/yana kayar.
func _door_label_check(tag: String, vp: Rect2) -> void:
	var rects: Array = hud.get_touch_button_screen_rects()
	check(not rects.is_empty(), tag + " door: touch rects exposed")
	if rects.is_empty():
		return
	var door := Area2D.new()
	door.set_script(load("res://scripts/world/room_transition.gd"))
	root.add_child(door)
	await process_frame
	var jr: Rect2 = hud.btn_jump.get_global_rect()
	# 1) Etiketi doğrudan Zıpla düğmesinin üstüne koy; kaçınma çalışmalı.
	door._label.global_position = Vector2(maxf(0.0, jr.end.x - door._label.size.x - 2.0), jr.position.y + 2.0)
	var pre: Rect2 = door._label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, door._label.size)
	check(pre.intersects(jr), tag + " door: test setup overlaps Jump")
	door._avoid_touch_buttons(Rect2())
	var lr: Rect2 = door._label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, door._label.size)
	for r in rects:
		check(not lr.intersects(r as Rect2), "%s door: label overlaps touch button %s vs %s" % [tag, lr, r])
	check(lr.position.y >= -0.5 and lr.position.x >= -0.5 and lr.end.x <= vp.end.x + 0.5, "%s door: label stays in view %s" % [tag, lr])
	# 2) Tam yol: kapı sağ-altta, _clamp_door_label üzerinden.
	door.global_position = Vector2(jr.get_center().x, jr.position.y + 4.0 - door._label_base_y)
	door._clamp_door_label()
	var lr2: Rect2 = door._label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, door._label.size)
	for r in rects:
		check(not lr2.intersects(r as Rect2), "%s door(full): label overlaps touch button %s vs %s" % [tag, lr2, r])
	door.queue_free()


func _dialogue_state(tag: String, sc: float, safe: Rect2, vp: Rect2) -> void:
	DM.clear()
	await _settle()
	DM.ask("Araştırma Yardımcısı S. (çok uzun bir konuşmacı adı)", LONG_LINE, PackedStringArray([
		"Evet, hatırlıyorum ve bunu uzun uzun anlatabilirim.", "Hayır, hiçbir şey hatırlamıyorum.", "Sana güvenmiyorum, bu oda beni oynuyor."]))
	for i in 4:
		await process_frame
	var guard := 0
	while not DM._choices_live and DM.is_open and guard < 12: # seçimler son sayfada
		DM.advance()
		for i in 3:
			await process_frame
		guard += 1
	await _settle()
	check(hud.dialogue_panel.visible, tag + " dialogue: panel visible")
	var panel: Rect2 = hud.dialogue_panel.get_global_rect()
	var rects: Dictionary = {}
	rects["DialoguePanel"] = panel
	check(safe.grow(0.5).encloses(panel), "%s dialogue: panel inside safe area %s vs %s" % [tag, panel, safe])
	check(vp.grow(0.5).encloses(panel), tag + " dialogue: panel inside screen")
	# metin kutusu
	var t: Label = hud.dialogue_text
	var lines := t.get_line_count()
	check(float(lines) * t.get_line_height() <= t.size.y + 1.0, "%s dialogue: text %d lines fit %.0fpx" % [tag, lines, t.size.y])
	check(hud.dialogue_speaker.get_global_rect().end.x <= panel.end.x + 0.5, tag + " dialogue: speaker inside panel")
	# görünür dokunmatik düğmeler (yalnız interact) panele binmez
	var btns := _buttons()
	for bn in btns:
		check(not (btns[bn] as Rect2).intersects(panel), "%s dialogue: %s overlaps panel" % [tag, bn])
	_check_set(btns, {}, safe, vp, sc, tag + " dialogue")
	# seçim kutusu
	if DM._choices_live:
		var cb: Control = hud._choice_box
		check(cb != null and is_instance_valid(cb), tag + " dialogue: choice box exists")
		if cb != null and is_instance_valid(cb):
			var cr := cb.get_global_rect()
			check(vp.grow(0.5).encloses(cr), "%s choices: inside screen %s" % [tag, cr])
			check(safe.grow(0.5).encloses(cr), "%s choices: inside safe area %s" % [tag, cr])
			check(not cr.intersects(panel), "%s choices: overlap dialogue panel" % tag)
			for bn in btns:
				check(not (btns[bn] as Rect2).intersects(cr), "%s choices: overlap %s" % [tag, bn])
			for ch in cb.get_children():
				var b := ch as Button
				check(b.size.y * sc >= MIN_TAP_PX, "%s choice button tap %.0fpx" % [tag, b.size.y * sc])
				var f := b.get_theme_font("font")
				var fs := b.get_theme_font_size("font_size")
				check(f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0 <= b.size.x, "%s choice text fits: %s" % [tag, b.text])
	DM.clear()
	await _settle()


func _buttons() -> Dictionary:
	var d := {}
	for pair in [["Attack", hud.btn_attack], ["Dash", hud.btn_dash], ["Jump", hud.btn_jump], ["Skill", hud.btn_skill], ["Interact", hud.btn_interact], ["Journal", hud.btn_journal]]:
		var c := pair[1] as Control
		if c.is_visible_in_tree():
			d[pair[0]] = c.get_global_rect()
	return d


func _hud_texts() -> Dictionary:
	var d := {}
	var hearts: Control = hud.hearts_row
	d["Hearts"] = hearts.get_global_rect()
	var hdr := hud.get_node_or_null("SafeArea/RoomHeader") as Control
	if hdr != null and hdr.is_visible_in_tree():
		d["RoomHeader"] = hdr.get_global_rect()
	if hud._objective.is_visible_in_tree():
		d["Objective"] = hud._objective.get_global_rect()
	if hud._context_hint.is_visible_in_tree() and hud._context_hint.text != "":
		# yalnız yazının gerçek genişliği (kutu 440 geniş, ortalı)
		var f: Font = hud._context_hint.get_theme_font("font")
		var fs: int = hud._context_hint.get_theme_font_size("font_size")
		var w := minf(f.get_string_size(hud._context_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0, hud._context_hint.size.x)
		var r: Rect2 = hud._context_hint.get_global_rect()
		d["ContextHint"] = Rect2(r.get_center().x - w * 0.5, r.position.y, w, r.size.y)
	if hud.hint_label.is_visible_in_tree():
		d["KeyHint"] = hud.hint_label.get_global_rect()
	if hud._toast_label != null and hud._toast_label.is_visible_in_tree():
		d["Toast"] = hud._toast_label.get_global_rect()
	return d


func _check_set(buttons: Dictionary, texts: Dictionary, safe: Rect2, vp: Rect2, sc: float, tag: String) -> void:
	var names := buttons.keys()
	for i in names.size():
		var r: Rect2 = buttons[names[i]]
		check(vp.grow(0.5).encloses(r), "%s: %s outside screen %s" % [tag, names[i], r])
		check(safe.grow(0.5).encloses(r), "%s: %s outside safe area %s vs %s" % [tag, names[i], r, safe])
		var px := minf(r.size.x, r.size.y) * sc
		check(px >= MIN_TAP_PX, "%s: %s tap %.0fpx < %.0f" % [tag, names[i], px, MIN_TAP_PX])
		for j in range(i + 1, names.size()):
			check(not r.intersects(buttons[names[j]]), "%s: %s overlaps %s" % [tag, names[i], names[j]])
		for tn in texts:
			check(not r.intersects(texts[tn]), "%s: %s overlaps text %s (%s vs %s)" % [tag, names[i], tn, r, texts[tn]])
	for tn in texts:
		var tr: Rect2 = texts[tn]
		check(vp.grow(0.5).encloses(tr), "%s: text %s outside screen %s" % [tag, tn, tr])
		check(safe.grow(0.5).encloses(tr), "%s: text %s outside safe area %s vs %s" % [tag, tn, tr, safe])
	var tkeys := texts.keys()
	for i in tkeys.size():
		for j in range(i + 1, tkeys.size()):
			check(not (texts[tkeys[i]] as Rect2).intersects(texts[tkeys[j]]), "%s: text %s overlaps text %s" % [tag, tkeys[i], tkeys[j]])


## Hedef nabzı, ölüm döngüsü sayacı, ayar kalıcılığı, geri ipucu sayacı.
func _ux_checks() -> void:
	hud.pulse_objective()
	check(hud._obj_tween != null and hud._obj_tween.is_valid(), "pulse: tween running")
	var first_tween: Tween = hud._obj_tween
	hud.pulse_objective()
	check(not first_tween.is_valid() or first_tween != hud._obj_tween, "pulse: previous tween replaced")
	check(hud._objective.modulate.r > 1.0, "pulse: objective highlighted")
	var dm := root.get_node("DeathManager")
	dm.reset_death_loop()
	for i in 3:
		dm._note_loop_death()
	check(dm.loop_deaths >= dm.LOOP_HELPER_DEATHS, "death loop: counter reaches threshold")
	dm.reset_death_loop()
	check(dm.loop_deaths == 0, "death loop: reset clears counter")
	var saved_hint: int = GameSettings.hint_level
	GameSettings.hint_level = 0
	var pm := root.get_node("PuzzleManager")
	check(String(pm.helper_hint_for_room(&"awakening_balcony")) != "" or String(pm.helper_hint_for_room(&"awakening")) != "", "death loop: helper hint ignores low hint_level")
	GameSettings.hint_level = saved_hint
	var tmp := "user://qa_settings_roundtrip.cfg"
	var s_idx: int = GameSettings.button_scale_idx
	var s_on: bool = GameSettings.touch_onboarding_done
	var s_bh: int = GameSettings.back_hint_count
	GameSettings.button_scale_idx = 4
	GameSettings.touch_onboarding_done = true
	GameSettings.back_hint_count = 2
	GameSettings.save_settings(tmp)
	GameSettings.reset_defaults()
	GameSettings.load_settings(tmp)
	check(GameSettings.button_scale_idx == 4 and is_equal_approx(GameSettings.button_scale(), 1.2), "settings: button scale persists")
	check(GameSettings.touch_onboarding_done and GameSettings.back_hint_count == 2, "settings: onboarding/back-hint flags persist")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	GameSettings.button_scale_idx = s_idx
	GameSettings.touch_onboarding_done = s_on
	GameSettings.back_hint_count = s_bh
	print("ML UX DONE failures=", failures)
	print("ML DONE failures=", failures, " checks=", _checks)
	quit(1 if failures > 0 else 0)
