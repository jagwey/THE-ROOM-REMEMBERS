extends SceneTree
## Dokunmatik kontrol yerleşimi: 2712x1220 / 2400x1080 / 1280x720 / 1024x768, tüm buton boyutları (%80-%120).
## Düğmeler + joystick güvenli alan içinde, birbirine ve hedef/kalp/ipucu/günlük metinlerine binmez,
## dokunma boyutu >= ~9 mm eşdeğeri (telefon yüksekliği ~70 mm, tablet 4:3 ~120 mm varsayımı).
## v1.20.6: yalnız Kılıç (basılı = Ruh Kesimi) + Zıpla; diyalogda düğme yok, dokunuş ilerletir.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/touch_controls_layout_audit.gd
const SIZES: Array[Vector2i] = [Vector2i(2712, 1220), Vector2i(2400, 1080), Vector2i(1280, 720), Vector2i(1024, 768)]
const MIN_MM := 9.0
const NOTCH_PX := 80.0
var failures := 0
var _checks := 0
var hud: CanvasLayer


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_TOUCH_UI", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		failures += 1
		print("TC FAIL ", label)


func _run() -> void:
	if not ("qa/" in String(root.get_node("SaveManager").SAVE_PATH)):
		print("TC SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var gs := root.get_node("GameState")
	gs.player_progress_knowledge["ability_soul_slash"] = true
	gs.player_progress_knowledge["journal_unlocked"] = true
	hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	var saved_idx: int = GameSettings.button_scale_idx
	var saved_layout: int = GameSettings.touch_layout
	for layout in GameSettings.TOUCH_LAYOUT_NAMES.size():
		GameSettings.touch_layout = layout
		for idx in GameSettings.BUTTON_SCALE_PCT.size():
			GameSettings.button_scale_idx = idx
			for sz in SIZES:
				await _audit_one(sz, "%dx%d btn%d%% %s" % [sz.x, sz.y, GameSettings.BUTTON_SCALE_PCT[idx], GameSettings.TOUCH_LAYOUT_NAMES[layout]])
	GameSettings.button_scale_idx = saved_idx
	GameSettings.touch_layout = saved_layout
	print("TC DONE failures=", failures, " checks=", _checks)
	quit(1 if failures > 0 else 0)


func _settle() -> void:
	for i in 3:
		await process_frame


func _audit_one(sz: Vector2i, tag: String) -> void:
	root.size = sz
	await _settle()
	var vpr := root.get_visible_rect().size
	var sc := minf(float(root.size.x) / vpr.x, float(root.size.y) / vpr.y)
	var vp := Rect2(Vector2.ZERO, vpr)
	var inset := minf(NOTCH_PX / sc, 64.0)
	hud.safe_area.offset_left = inset
	hud.safe_area.offset_right = -inset
	hud.safe_area.offset_top = 0.0
	hud.safe_area.offset_bottom = 0.0
	hud.apply_button_scale()
	hud.refresh_touch_controls()
	root.get_node("GameState").room_changed.emit(&"awakening")
	hud._context_hint.text = "Geçidi kullan"
	await _settle()
	var safe: Rect2 = hud.safe_area.get_global_rect()
	var phys_h_mm := 120.0 if float(sz.x) / float(sz.y) < 1.5 else 70.0
	var min_px := MIN_MM / phys_h_mm * float(sz.y)
	var items := {}
	for pair in [["Attack", hud.btn_attack], ["Dash", hud.btn_dash], ["Jump", hud.btn_jump], ["Skill", hud.btn_skill], ["Interact", hud.btn_interact]]:
		if (pair[1] as Control).is_visible_in_tree():
			items[pair[0]] = (pair[1] as Control).get_global_rect()
	## El/Kılıç tek düğme (Interact), Atıl kaydırma: Attack/Dash düğmesi görünmez.
	check(items.size() == 2 and items.has("Jump") and items.has("Interact"), tag + " only Jump+Sword visible (got %s)" % [items.keys()])
	if GameSettings.touch_layout == GameSettings.TouchLayout.ARROWS:
		check(not hud.joystick_base.is_visible_in_tree() and hud._arrows[0].is_visible_in_tree() and hud._arrows[1].is_visible_in_tree(), tag + " both arrows visible")
		items["Left"] = hud._arrows[0].get_global_rect()
		items["Right"] = hud._arrows[1].get_global_rect()
	else:
		items["Joystick"] = (hud.joystick_base as Control).get_global_rect()
	var texts := {"Hearts": hud.hearts_row.get_global_rect(), "Journal": (hud.btn_journal as Control).get_global_rect()}
	## Ruh sayacı (Parçalanmış Ruhlar) ruhlu odada görünür: kontrollere binmemeli.
	hud._soul_label.text = "Ruhlar 1/3 (9/9)"
	hud._soul_label.visible = true
	await _settle()
	texts["Souls"] = hud._soul_label.get_global_rect()
	if hud._context_hint.is_visible_in_tree():
		var f: Font = hud._context_hint.get_theme_font("font")
		var fs: int = hud._context_hint.get_theme_font_size("font_size")
		var w := minf(f.get_string_size(hud._context_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0, hud._context_hint.size.x)
		var r: Rect2 = hud._context_hint.get_global_rect()
		texts["ContextHint"] = Rect2(r.get_center().x - w * 0.5, r.position.y, w, r.size.y)
	## Dokunulabilir hedef çipi (el simgesi + çerçeve): en uzun ad ile, düğmelere binmemeli, >= 9 mm.
	var stub := Node2D.new()
	stub.name = "KeeperStub"
	root.add_child(stub)
	hud._hint_tick = 999.0
	hud._set_hint_chip(stub)
	await _settle()
	check(hud._hint_chip.is_visible_in_tree(), tag + " target chip visible")
	var chip: Rect2 = hud.hint_chip_hit_rect()
	texts["TargetChip"] = chip
	check(safe.grow(0.5).encloses(hud._hint_chip.get_global_rect()), "%s TargetChip outside safe area %s" % [tag, chip])
	check(minf(chip.size.x, chip.size.y) * sc >= min_px, "%s TargetChip tap %.0fpx < %.0fpx (9mm)" % [tag, minf(chip.size.x, chip.size.y) * sc, min_px])
	var names := items.keys()
	for i in names.size():
		var r: Rect2 = items[names[i]]
		check(safe.grow(0.5).encloses(r) and vp.grow(0.5).encloses(r), "%s %s outside safe area %s vs %s" % [tag, names[i], r, safe])
		check(minf(r.size.x, r.size.y) * sc >= min_px, "%s %s tap %.0fpx < %.0fpx (9mm)" % [tag, names[i], minf(r.size.x, r.size.y) * sc, min_px])
		for j in range(i + 1, names.size()):
			check(not r.intersects(items[names[j]]), "%s %s overlaps %s" % [tag, names[i], names[j]])
		for tn in texts:
			check(not r.intersects(texts[tn]), "%s %s overlaps %s" % [tag, names[i], tn])
	hud._set_hint_chip(null)
	stub.free()
	hud._hint_tick = 0.0
	# Diyalog: yalnız Etkileş, köşede (Zıpla yuvası), panele binmez
	var DM := root.get_node("DialogueManager")
	DM.ask("S.", "Kısa satır.", PackedStringArray(["Evet", "Hayır"]))
	await _settle()
	await _settle()
	## v1.20.6: diyalogda düğme yok; ekrana dokunmak ilerletir.
	check(not hud.btn_interact.is_visible_in_tree() and not hud.btn_jump.is_visible_in_tree(), tag + " dialogue: no action buttons")
	DM.clear()
	await _settle()
	print("TC ", tag)
