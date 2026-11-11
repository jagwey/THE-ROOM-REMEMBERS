class_name FinalSequence
extends RefCounted
## BÖLÜM I SONU — tek final (spec §8, §31, §32): Ruh Kesiği ile ana mühür kırılır, Shilda insan formuna
## döner, X belirir, ekranlar DOMAIN 01-04'ü gösterir, X çekirdek parçasını alır ve geçide girer.
## Sonra THE ROOM REMEMBERS / END OF PART I, jenerik, game_completed, commit_save(&"final"), başlık.
##
## YER TUTUCU görseller (sprite yok): Shilda insan formu = soluk/doygunsuz ton + parıltı geçişi,
## X = FinalXActor siluet (uzun, koyu, soğuk beyaz ışık).
## Satırlar normal diyalogla ilerler. Bekleme/efekt anları, final daha önce tam izlendiyse
## (settings'te final_seen) ui_cancel ile hızlandırılabilir; ilk izleme atlanamaz.

## Son çalıştırmanın kaydı (denetim için): bayrak sırası ve görülen aşamalar.
static var last_run: Dictionary = {}

var fast: bool = false
var _tree: SceneTree
var _scene: Node
var _player: Node2D
var _keeper: Node2D
var _crystal: Node2D
var _x: Node2D
var _bonds: Node2D
var _overlay: CanvasLayer
var _flash: ColorRect
var _fade: ColorRect
var _skip_waits: bool = false
var _was_seen: bool = false
var _skip_pressed: bool = false ## ui_cancel olayı geldi (olay tabanlı; kare kaçırmaz)


static func _settings_path() -> String:
	return "user://qa/settings.cfg" if OS.get_environment("TORIMON_TEST") == "1" else "user://settings.cfg"


static func final_seen() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(_settings_path()) == OK and bool(cfg.get_value("progress", "final_seen", false))


static func mark_final_seen() -> void:
	var path := _settings_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("progress", "final_seen", true)
	cfg.save(path)


func play(tree: SceneTree, fast_mode: bool = false) -> void:
	_tree = tree
	fast = fast_mode
	_was_seen = final_seen()
	last_run = {"flag_order": [], "stages": [], "end_label": false, "part_label": false, "credits": false,
		"title_requested": false, "x_seen": false, "human": false, "domains": 0}
	_scene = tree.current_scene
	_player = tree.get_first_node_in_group("player") as Node2D
	_keeper = tree.get_first_node_in_group("keeper") as Node2D
	_crystal = tree.get_first_node_in_group("core_crystal") as Node2D
	UiGate.set_cutscene(true)
	DialogueManager.clear()
	MobileInputManager.clear_held_inputs()
	_build_overlay()
	_stage(&"setup")
	_place_actors()
	await _wait(0.6)
	await _seal_break()
	await _shilda_human()
	await _say([
		["Shilda", "Ellerim..."],
		["Noroi", "Shilda?"],
		["Shilda", "Sanırım... sonunda bitti."],
		["Noroi", "Gidelim."],
		["Shilda", "Kapıda ışık var. Bu sefer gerçek."],
	])
	await _exit_door_opens()
	await _wait(0.8)
	await _say([[DialogueManager.UNKNOWN_VOICE, "Demek sonunda başardınız."]])
	await _say([["Shilda", "Bu ses..."]])
	await _x_enters()
	await _say([
		["Shilda", "Kurucu...?"],
		["X", "Merhaba, Shilda."],
		["Shilda", "Yaşıyorsunuz..."],
		["X", "Elbette."],
		["Shilda", "Yıllarca sizi aradım. İnsanlar öldü. Ben de sayılırım."],
		["X", "Biliyorum."],
		["Shilda", "Ne?"],
		["X", "Her şeyi kaydettim."],
		["Noroi", "Bizi burada bıraktın."],
		["X", "Bırakmadım. İzledim. Kayıt böyle daha temiz."],
		["Shilda", "O gün bir kaza değil miydi?"],
		["X", "Hayır, Shilda."],
	])
	await _wait(0.8)
	await _say([
		["X", "Bu bir deneydi."],
		["X", "Sessizlik veriydi. Siz, sonuç."],
		["Shilda", "Bunca insan..."],
		["X", "Hepsi verinin parçasıydı."],
		["X", "Ama siz..."],
		["X", "Şimdiye kadarki en başarılı deneklerim sizsiniz."],
	])
	await _domain_screens()
	await _say([["X", "İlk boyuttan çıkmanız beklediğimden uzun sürdü."]])
	await _shard_pull()
	await _say([
		["Shilda", "Noroi!"],
		["Shilda", "Ona ne yaptınız?"],
		["X", "İhtiyacım olan şeyi aldım."],
		["Shilda", "Bizi neden kurtarmadınız?"],
		["X", "Çünkü henüz işiniz bitmemişti."],
		["Noroi", "İşimiz mi? Biz insanız."],
		["X", "Bölüm iki sizsiz açılmaz."],
	])
	await _portal_leave()
	await _say([
		["Shilda", "Noroi... beni duyuyor musun?"],
		["Noroi", "Duyuyorum. Bu sefer adın aklımda kalacak."],
		["Shilda", "O zaman yürü. Oda bizi bekleyemez."],
	])
	await _title_card()
	await _credits()
	_finish()


# --- Aşamalar ---------------------------------------------------------------------------

func _stage(id: StringName) -> void:
	(last_run["stages"] as Array).append(String(id))


func _flag(id: StringName) -> void:
	GameState.set_story_flag(id, true)
	(last_run["flag_order"] as Array).append(String(id))


func _place_actors() -> void:
	if _player == null or _keeper == null:
		return
	_keeper.visible = true
	if _keeper.has_method("set_mode"):
		_keeper.set_mode(_keeper.Mode.OBSERVE)
	_keeper.global_position = Vector2(_player.global_position.x + 70.0, _player.global_position.y)


func _seal_break() -> void:
	_stage(&"seal_break")
	var cpos := Vector2(480, 250)
	if _crystal != null:
		cpos = _crystal.global_position
	## Mühür bağları: kristali saran dört kırmızı çizgi
	_bonds = Node2D.new()
	_bonds.name = "FinalSealBonds"
	_bonds.z_index = 4
	_scene.add_child(_bonds)
	_bonds.global_position = cpos
	for a in [-2.4, -0.7, 0.7, 2.4]:
		var ln := Line2D.new()
		ln.width = 3.0
		ln.default_color = Color(0.85, 0.12, 0.2, 0.9)
		ln.points = PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 70.0])
		_bonds.add_child(ln)
	## Ruh Kesiği dalgası kristale doğru
	if _player != null:
		var dir := 1.0 if cpos.x >= _player.global_position.x else -1.0
		var wave := Area2D.new()
		wave.set_script(load("res://scripts/player/soul_slash_wave.gd"))
		wave.set("direction", dir)
		_scene.add_child(wave)
		wave.global_position = _player.global_position + Vector2(24.0 * dir, -24.0)
	_camera_trauma(0.5)
	await _wait(0.5)
	_flash_screen(Color(0.9, 0.8, 1.0, 0.9), 0.5)
	_camera_trauma(0.9)
	_flag(&"final_seal_broken")
	var d := 0.8 if not fast else 0.05
	var tw := _bonds.create_tween().set_parallel(true)
	tw.tween_property(_bonds, "modulate:a", 0.0, d)
	tw.tween_property(_bonds, "scale", Vector2(2.2, 2.2), d)
	await _wait(1.0)


func _exit_door_opens() -> void:
	_stage(&"exit_door_opens")
	var exit_light := _make_glow(Color(0.9, 0.95, 1.0, 0.95), 80.0)
	exit_light.name = "ExitDoorLight"
	exit_light.z_index = 3
	_scene.add_child(exit_light)
	exit_light.global_position = Vector2(880, 268)
	exit_light.scale = Vector2(0.2, 1.8)
	_camera_trauma(0.4)
	var tw := exit_light.create_tween().set_parallel(true)
	tw.tween_property(exit_light, "scale:x", 1.2, 0.8 if not fast else 0.05)
	tw.tween_property(exit_light, "modulate:a", 0.9, 0.8 if not fast else 0.05)
	await _wait(0.8)


func _shilda_human() -> void:
	_stage(&"shilda_human")
	if _keeper == null:
		last_run["human"] = true
		return
	var spr := _keeper.get_node_or_null("AnimatedSprite2D") as Node2D
	var glow := _make_glow(Color(1.0, 0.95, 0.85, 1.0), 54.0)
	glow.modulate.a = 0.0
	_scene.add_child(glow)
	glow.global_position = _keeper.global_position + Vector2(0, -34)
	glow.z_index = 7
	var d := 1.4 if not fast else 0.05
	## Parıltı yükselir, Shilda soluk/insani tona geçer (halka sönmüş gibi, boy normale iner).
	var t := _keeper.create_tween().set_parallel(true)
	t.tween_property(glow, "modulate:a", 0.9, d * 0.5)
	t.tween_property(_keeper, "modulate", Color(1.35, 1.3, 1.25, 1.0), d)
	if spr != null:
		t.tween_property(spr, "scale", spr.scale * 0.94, d)
	await _wait(d)
	var t2 := glow.create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, d * 0.6)
	await _wait(d * 0.6 + 0.2)
	glow.queue_free()
	last_run["human"] = true


func _x_enters() -> void:
	_stage(&"x_enters")
	var fx := FinalXActor.new()
	_x = fx
	var base := _keeper.global_position if _keeper != null else Vector2(560, 280)
	var px := _player.global_position.x if _player != null else 480.0
	fx.modulate.a = 0.0
	_scene.add_child(fx)
	fx.global_position = Vector2(clampf(maxf(px, base.x) + 190.0, 120.0, 900.0), base.y)
	_flag(&"x_revealed")
	last_run["x_seen"] = true
	var d := 1.6 if not fast else 0.05
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(fx, "modulate:a", 1.0, d)
	tw.tween_property(fx, "glow", 1.0, d)
	await _wait(d + 0.4)


func _domain_screens() -> void:
	_stage(&"domain_screens")
	## Eski ekranlar: 01 ile başlar, 02-04 eklenerek ızgara dolar.
	var screens := Control.new()
	screens.name = "DomainScreens"
	screens.set_anchors_preset(Control.PRESET_FULL_RECT)
	screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(screens)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screens.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screens.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	center.add_child(grid)
	var labels := ["EXPERIMENTAL DOMAIN — 01", "DOMAIN — 02", "DOMAIN — 03", "DOMAIN — 04"]
	for i in labels.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(200, 54)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.07, 0.1, 0.95)
		sb.border_color = Color(0.55, 0.85, 1.0, 0.9)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.name = "Domain%d" % (i + 1)
		l.text = labels[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UiTheme.apply_outlined(l, 9, true, Color(0.7, 0.92, 1.0))
		panel.add_child(l)
		panel.modulate.a = 0.0
		grid.add_child(panel)
		await _wait(0.5)
		panel.modulate.a = 1.0
		last_run["domains"] = int(last_run["domains"]) + 1
		_flash_screen(Color(0.6, 0.85, 1.0, 0.3), 0.2)
		await _wait(0.8)
	await _wait(1.0)
	screens.queue_free()


func _shard_pull() -> void:
	_stage(&"shard_pull")
	var chest := (_player.global_position if _player != null else Vector2(480, 280)) + Vector2(0, -28)
	var red := _make_glow(Color(1.0, 0.1, 0.12, 1.0), 26.0)
	red.modulate.a = 0.0
	_scene.add_child(red)
	red.global_position = chest
	red.z_index = 8
	var d := 0.7 if not fast else 0.05
	var tw := red.create_tween()
	tw.tween_property(red, "modulate:a", 1.0, d)
	_camera_trauma(0.5)
	await _wait(d + 0.2)
	## Parça X'in avucuna uçar
	var target := (_x.global_position if _x != null else chest + Vector2(180, 0)) + Vector2(-14, -36)
	var fly := _make_glow(Color(1.0, 0.25, 0.25, 1.0), 10.0)
	_scene.add_child(fly)
	fly.global_position = chest
	fly.z_index = 9
	var tw2 := fly.create_tween()
	tw2.tween_property(fly, "global_position", target, 0.9 if not fast else 0.05)
	await _wait(1.0)
	fly.queue_free()
	var tw3 := red.create_tween()
	tw3.tween_property(red, "modulate:a", 0.0, 0.4 if not fast else 0.05)
	## Noroi diz çöker (yer tutucu: sprite çöker)
	if _player != null:
		var spr := _player.get_node_or_null("AnimatedSprite2D") as Node2D
		if spr != null:
			var tw4 := spr.create_tween()
			tw4.tween_property(spr, "scale:y", spr.scale.y * 0.78, 0.5 if not fast else 0.05)
	await _wait(0.8)
	red.queue_free()


func _portal_leave() -> void:
	_stage(&"portal")
	if _x == null:
		return
	var portal := _make_glow(Color(0.12, 0.0, 0.2, 1.0), 44.0)
	portal.name = "FinalPortal"
	portal.modulate.a = 0.0
	_scene.add_child(portal)
	portal.global_position = _x.global_position + Vector2(52, -40)
	portal.scale = Vector2(0.4, 1.0)
	portal.z_index = 4
	var d := 0.9 if not fast else 0.05
	var tw := portal.create_tween()
	tw.tween_property(portal, "modulate:a", 1.0, d)
	await _wait(d)
	await _say([["X", "İkiniz de beklentilerimi aştınız."]])
	var tw2 := _x.create_tween().set_parallel(true)
	tw2.tween_property(_x, "global_position:x", portal.global_position.x, 1.2 if not fast else 0.05)
	tw2.tween_property(_x, "modulate:a", 0.0, 1.2 if not fast else 0.05)
	await _wait(1.4)
	var tw3 := portal.create_tween()
	tw3.tween_property(portal, "modulate:a", 0.0, 0.7 if not fast else 0.05)
	await _wait(0.9)
	portal.queue_free()
	_x.queue_free()
	_x = null


func _title_card() -> void:
	_stage(&"title_card")
	var d := 2.0 if not fast else 0.05
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", 1.0, d)
	await _wait(d + 0.2)
	var box := VBoxContainer.new()
	box.name = "PartOneCard"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	_overlay.add_child(box)
	var t1 := Label.new()
	t1.name = "TitleLabel"
	t1.text = "THE ROOM REMEMBERS"
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(t1, 30, true, Palette.IVORY)
	box.add_child(t1)
	var t2 := Label.new()
	t2.name = "PartLabel"
	t2.text = "END OF PART I"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(t2, 20, true, Palette.CRIMSON.lightened(0.35))
	box.add_child(t2)
	last_run["end_label"] = true
	last_run["part_label"] = true
	box.modulate.a = 0.0
	var tw2 := box.create_tween()
	tw2.tween_property(box, "modulate:a", 1.0, 1.2 if not fast else 0.05)
	await _wait(3.5)
	var tw3 := box.create_tween()
	tw3.tween_property(box, "modulate:a", 0.0, 1.0 if not fast else 0.05)
	await _wait(1.2)
	box.queue_free()
	await _part_two_teaser()


## Jenerik öncesi Bölüm II kancası (post-credits hook değil; END OF PART I kartından hemen sonra).
func _part_two_teaser() -> void:
	_stage(&"part_two_teaser")
	var box := VBoxContainer.new()
	box.name = "PartTwoTeaser"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	_overlay.add_child(box)
	var hook := Label.new()
	hook.name = "TeaserHook"
	hook.text = "Ama oda hâlâ uyanık."
	hook.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(hook, 16, false, Palette.PALE_LILAC)
	box.add_child(hook)
	var t2 := Label.new()
	t2.name = "TeaserTitle"
	t2.text = "BÖLÜM II — yakında"
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_outlined(t2, 18, true, Palette.IVORY)
	box.add_child(t2)
	last_run["part_two_teaser"] = true
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.8 if not fast else 0.05)
	await _wait(2.4 if not fast else 0.1)
	var tw2 := box.create_tween()
	tw2.tween_property(box, "modulate:a", 0.0, 0.7 if not fast else 0.05)
	await _wait(0.9 if not fast else 0.05)
	box.queue_free()


func _credits() -> void:
	_stage(&"credits")
	var holder := MarginContainer.new()
	holder.name = "FinalCredits"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", 120)
	holder.add_theme_constant_override("margin_right", 120)
	holder.add_theme_constant_override("margin_top", 30)
	holder.add_theme_constant_override("margin_bottom", 30)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	var scroll := CreditsScroll.new()
	holder.add_child(scroll)
	await _tree.process_frame
	last_run["credits"] = true
	var done := [false]
	scroll.finished.connect(func() -> void: done[0] = true)
	scroll.play(0.2 if fast else 26.0, 0.05 if fast else 1.0)
	while not done[0]:
		if _skip_requested():
			break
		await _tree.process_frame
	scroll.stop()
	await _wait(0.5)
	holder.queue_free()


func _finish() -> void:
	_stage(&"finish")
	_flag(&"game_completed")
	SaveManager.commit_save(&"final")
	mark_final_seen()
	UiGate.set_cutscene(false)
	if fast:
		last_run["title_requested"] = true
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.queue_free()
		return
	var menu := _tree.get_first_node_in_group("session_menu")
	if menu != null and menu.has_method("return_to_title"):
		last_run["title_requested"] = true
		menu.return_to_title()
		return
	## Başlık yolu yoksa siyah örtü tek başına kalmasın: örtüyü kaldır, sahneyi baştan yükle.
	last_run["title_requested"] = true
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_tree.reload_current_scene()


# --- Yardımcılar -------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 95
	_overlay.name = "FinalOverlay"
	_scene.add_child(_overlay)
	var listener := SkipListener.new()
	listener.on_skip = func() -> void: _skip_pressed = true
	_overlay.add_child(listener)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_flash)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)


func _flash_screen(c: Color, d: float) -> void:
	_flash.color = c
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, d if not fast else 0.02)


func _camera_trauma(v: float) -> void:
	var cam := _tree.get_first_node_in_group("follow_camera")
	if cam != null and cam.has_method("add_trauma"):
		cam.add_trauma(v)


func _make_glow(c: Color, radius: float) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 1.0))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var s := Sprite2D.new()
	s.texture = gt
	s.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	return s


func _skip_allowed() -> bool:
	return _was_seen and not fast


## Atlama isteği (olay tabanlı). Yalnız izin varsa tüketilir.
func _skip_requested() -> bool:
	return _skip_allowed() and _skip_pressed


## ui_cancel basışını olay olarak yakalar; polling'in kare arasında kaçırdığı basışları da görür.
class SkipListener extends Node:
	var on_skip: Callable

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") and on_skip.is_valid():
			on_skip.call()
			get_viewport().set_input_as_handled() ## Esc duraklatma menüsünü de açmasın


## Zaman beklemesi; final daha önce tam izlendiyse ui_cancel ile hızlanır, ilk izleme atlanamaz.
func _wait(sec: float) -> void:
	var left := sec if not fast else minf(sec, 0.05)
	while left > 0.0 and not _skip_waits:
		if _skip_requested():
			_skip_waits = true
			break
		var step := minf(left, 0.05)
		await _tree.create_timer(step).timeout
		left -= step


## Diyalog satırları. Gate'i diyalog süresince açar (CUTSCENE ilerlemeyi engeller), sonra kilitler.
func _say(lines: Array) -> void:
	UiGate.set_cutscene(false)
	for l in lines:
		DialogueManager.say(String(l[0]), String(l[1]))
	await DialogueManager.dialogue_finished
	UiGate.set_cutscene(true)
