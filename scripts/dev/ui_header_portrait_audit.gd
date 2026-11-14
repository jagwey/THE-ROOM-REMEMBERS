extends SceneTree
## Oda başlığı, portre eşlemesi, fısıltı konuşmacısı, menü/günlük kapıları, hedef metni.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/ui_header_portrait_audit.gd
var failures := 0
var Portraits = load("res://scripts/ui/dialogue_portraits.gd")


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("UIHP ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("UIHP SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var rm := root.get_node("RoomManager")
	var gs := root.get_node("GameState")
	# Oda numaraları/başlıkları
	check(rm.get_room_number_and_title(&"awakening") == "ODA 01 · Uyanış", "awakening title")
	check(rm.get_room_number_and_title(&"awakening_balcony") == "ODA 02 · Gözlem Balkonu", "balcony title")
	check(rm.get_room_number_and_title(&"awakening_crypt") == "ODA 03 · İlk Bedenler Mahzeni", "crypt title")
	check(rm.get_room_number_and_title(&"awakening_passage") == "ODA 04 · Kırık Geçit", "passage title")
	check(rm.get_room_number_and_title(&"awakening_seal") == "ODA 05 · Mühürlü Eşik", "seal title")
	var missing: PackedStringArray = []
	var seen := {}
	var defs: Dictionary = load("res://scripts/main.gd").get_script_constant_map()["ROOM_DEFS"]
	for rid in defs.keys():
		var t: String = rm.get_room_number_and_title(rid)
		if t.begins_with("ODA ??") or not t.begins_with("ODA "):
			missing.append(String(rid))
		if seen.has(t):
			missing.append("dup:" + String(rid))
		seen[t] = true
	check(missing.is_empty(), "every ROOM_DEFS room has unique number/title %s" % str(missing))
	# Portre eşlemesi
	check(Portraits.key_for("Noroi") == &"noroi" and Portraits.key_for("Sen") == &"", "noroi mapping; legacy Sen has no portrait")
	check(Portraits.key_for("Noroi", true) == &"noroi_sad", "noroi sad mapping")
	check(Portraits.key_for("???") == &"shilda_unknown" and Portraits.key_for("Bekçi") == &"", "??? -> silhouette portrait (shilda_unknown); Bekçi is no longer a speaker")
	check(Portraits.key_for("") == &"" and Portraits.key_for("Sistem") == &"" and Portraits.key_for("Kayıt") == &"", "narrator/system speakers: no portrait")
	check(Portraits.key_for("Shilda") == &"shilda", "shilda mapping")
	check(Portraits.key_for("Arşivci") == &"" and Portraits.key_for("Kayıt") == &"" and Portraits.key_for("Çekirdek") == &"", "unknown speakers no portrait")
	for k in Portraits.PATHS.keys():
		check(Portraits.texture_for(k) != null, "portrait texture loads: %s" % k)
	# Fısıltı konuşmacısı
	var dmc := root.get_node("DialogueManager")
	check(dmc.resolve_whisper_speaker("Noroi", true, false) == "Noroi", "whisper keeps Noroi")
	check(dmc.resolve_whisper_speaker("Shilda", true, false) == "???" and dmc.resolve_whisper_speaker("Shilda", false, false) == "???", "unnamed: Shilda lines show ???")
	check(dmc.resolve_whisper_speaker("???", true, true) == "Shilda" and dmc.resolve_whisper_speaker("Shilda", false, true) == "Shilda", "named: ??? and Shilda lines show Shilda")
	check(dmc.resolve_whisper_speaker("???", false, false) == "???", "unnamed: ??? stays ???")
	check(dmc.resolve_whisper_speaker("Noroi", true, true) == "Noroi", "named: Noroi whisper kept")
	# Shilda adı: tek kaynak + göç + keeper_speaker_name
	gs.set_shilda_named(false)
	check(not gs.is_shilda_named() and not gs.has_story_flag(&"shilda_name_known"), "unnamed flag false before start")
	gs.player_progress_knowledge["shilda_named_partial"] = true
	check(gs.is_shilda_named() and gs.has_story_flag(&"shilda_name_known") and not gs.player_progress_knowledge.has("shilda_named_partial") and not bool(gs.player_progress_knowledge.get("shilda_named", false)), "legacy partial key migrates to the shilda_name_known flag")
	gs.set_shilda_named(false)
	gs.set_world_flag(&"shilda_named", true)
	check(gs.is_shilda_named() and gs.has_story_flag(&"shilda_name_known") and not bool(gs.get_world_flag(&"shilda_named", false)), "legacy world flag migrates")
	gs.set_shilda_named(false)
	gs.character_current_life_knowledge["room"] = &"awakening"
	gs.player_progress_knowledge["pocket_watch_seen"] = false
	gs.clear_story_flags()
	check(not ("Gölgeyle" in gs.get_current_objective()), "room 1 objective: no 'Gölgeyle konuş' before the first death (Shilda absent)")
	gs.set_story_flag(&"first_death_completed")
	check(("Gölgeyle konuş" in gs.get_current_objective()) and not ("Shilda" in gs.get_current_objective()), "after first death, unnamed: objective 'Gölgeyle konuş' without the name")
	gs.set_shilda_named(true)
	check(gs.keeper_speaker_name() == "Shilda" and not ("Gölgeyle" in gs.get_current_objective()), "named -> Shilda, objective step dropped")
	gs.set_shilda_named(false)
	# say_with: ad açıklama satırında geri çağrı, konuşmacı anında Shilda
	var dm2 := root.get_node("DialogueManager")
	var seen_speakers: Array = []
	dm2.line_shown.connect(func(sp: String, _t: String): seen_speakers.append(sp))
	dm2.say("???", "Noroi… yine mi?")
	dm2.say("Noroi", "Sen kimsin?")
	dm2.say_with("Shilda", "Ben Shilda.", func(): gs.set_shilda_named(true))
	await create_timer(0.1).timeout
	for _i in range(6):
		dm2.advance()
		await create_timer(0.05).timeout
	check(gs.is_shilda_named() and seen_speakers.size() >= 3 and seen_speakers[0] == "???" and seen_speakers[1] == "Noroi" and seen_speakers[2] == "Shilda", "card shows ??? until the naming line, then Shilda %s" % str(seen_speakers))
	check(gs.keeper_speaker_name() == "Shilda", "after naming keeper_speaker_name is Shilda")
	check(gs.is_shilda_named() == gs.has_story_flag(&"shilda_name_known"), "is_shilda_named and shilda_name_known are one truth")
	var keeper_src := FileAccess.get_file_as_string("res://scripts/keeper/keeper_controller.gd")
	var main_src2 := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(not ("set_shilda_named" in main_src2), "main.gd no longer forces the Shilda name")
	var naming_funcs := _funcs_calling(keeper_src, "set_shilda_named(true)")
	var funcs_ok := not naming_funcs.is_empty()
	for fn in naming_funcs:
		if not (fn in ["place_for_room", "_queue_naming_lines", "_run_naming_scene"]):
			funcs_ok = false
	check(funcs_ok and not ("Ben Shilda." in keeper_src), "keeper names only in the naming scene / hidden-late-room fallback %s" % str(naming_funcs))
	check(not ("set_shilda_named" in FileAccess.get_file_as_string("res://scripts/story/story_beat.gd")), "story_beat.gd no longer names Shilda unconditionally")
	check("return GameState.keeper_speaker_name()" in keeper_src, "keeper interact label follows the speaker name")
	dm2.clear()
	gs.set_shilda_named(false)
	# Konuşmacı sözleşmesi: tüm say/whisper ve oda lore satırları izinli kümeden
	_speaker_contract_scan()
	# Intro satırları portresiz
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	var intro := main_src.substr(main_src.find("func _play_intro"), 1800)
	var rx := RegEx.new()
	rx.compile('say\\("([^"]*)", "(Gözlerin|Bu oda seni|Yine bu yatak)')
	var intro_hits := rx.search_all(intro)
	var intro_ok := intro_hits.size() == 3
	for m in intro_hits:
		if m.get_string(1) != "" or Portraits.has_portrait(m.get_string(1)):
			intro_ok = false
	check(intro_ok, "intro opening lines: narrator '' with no portrait (%d lines)" % intro_hits.size())
	# Hedef metni
	gs.character_current_life_knowledge["room"] = &"awakening"
	var obj: String = gs.get_current_objective()
	check(not ("Saata" in obj) and not (" · Saat" in obj and obj.begins_with("Uyanış")), "objective has no typo/room prefix: " + obj)
	check(not obj.begins_with("Uyanış"), "objective without room prefix")
	# Menü/günlük kapıları
	var JournalScript = load("res://scripts/ui/journal_ui.gd")
	check(JournalScript.call("can_open_in_layer", 0) and JournalScript.call("can_open_in_layer", 2), "journal opens in NONE/JOURNAL")
	for layer in [1, 3, 5, 4, 6, 7, 8]:
		check(not JournalScript.call("can_open_in_layer", layer), "journal blocked in layer %d" % layer)
	await _keeper_spawn_checks()
	await _medallion_checks()
	quit(1 if failures else 0)


## Lowest opaque pixel row (texture space) of the keeper's first idle frame.
func _keeper_feet_row(spr: AnimatedSprite2D) -> int:
	var anim: StringName = &"idle"
	if not spr.sprite_frames.has_animation(anim):
		anim = spr.sprite_frames.get_animation_names()[0]
	var tex := spr.sprite_frames.get_frame_texture(anim, 0)
	var img := tex.get_image()
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.1:
				return y
	return 0


## Floor top y under world x (Floor* StaticBody2D rectangles built by BuiltRoom / the scene).
func _floor_top_at(room: Node, x: float) -> float:
	for c in room.get_children():
		if c is StaticBody2D and String(c.name).begins_with("Floor"):
			var cs: CollisionShape2D = null
			for k in c.get_children():
				if k is CollisionShape2D:
					cs = k
			if cs and cs.shape is RectangleShape2D:
				var half: Vector2 = (cs.shape as RectangleShape2D).size * 0.5
				if absf(x - c.global_position.x) <= half.x:
					return c.global_position.y - half.y
	return NAN


func _keeper_spawn_checks() -> void:
	var keeper := (load("res://scenes/keeper/keeper.tscn") as PackedScene).instantiate()
	root.add_child(keeper)
	var spr := keeper.get_node("AnimatedSprite2D") as AnimatedSprite2D
	await process_frame
	var feet_row := _keeper_feet_row(spr)
	var tex_h: int = spr.sprite_frames.get_frame_texture(spr.animation, 0).get_height()
	## centered sprite: bottom opaque pixel (row+1) in node space
	var feet_local: float = spr.position.y + spr.offset.y + (feet_row + 1) - tex_h * 0.5
	keeper.queue_free()
	var bad: Array = []
	var bad_feet: Array = []
	var n := 0
	for f in DirAccess.get_files_at("res://scenes/rooms"):
		if not f.ends_with(".tscn"):
			continue
		var room := (load("res://scenes/rooms/" + f) as PackedScene).instantiate()
		root.add_child(room)
		await process_frame
		var spawns := room.get_node_or_null("Spawns")
		for m in (spawns.get_children() if spawns else []):
			if not String(m.name).begins_with("keeper_"):
				continue
			n += 1
			var fl := _floor_top_at(room, m.global_position.x)
			if is_nan(fl):
				bad.append("%s/%s: no floor under x" % [f, m.name])
				continue
			if m.global_position.y > fl + 0.01:
				bad.append("%s/%s y=%s floor=%s" % [f, m.name, m.global_position.y, fl])
			var feet_world: float = m.global_position.y + feet_local
			if absf(feet_world - fl) > 2.0:
				bad_feet.append("%s/%s feet=%s floor=%s" % [f, m.name, feet_world, fl])
		room.queue_free()
		await process_frame
	check(n > 0 and bad.is_empty(), "keeper_spawns_on_floor: %d keeper_* spawns not below floor %s" % [n, str(bad)])
	check(bad_feet.is_empty(), "keeper sprite feet sit on floor within 2px (feet_local=%s) %s" % [feet_local, str(bad_feet)])


func _medallion_checks() -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	var panel := hud.get_node("SafeArea/Dialogue") as Control
	for sz in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(2400, 1080)]:
		root.content_scale_size = Vector2i(640, 360)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.size = sz
		await process_frame
		await process_frame
		var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		panel.visible = true
		hud.call("_update_portrait", "Shilda")
		await process_frame
		var med := hud.get("_medallion") as Control
		var ok_ref := med != null
		var mr: Rect2 = med.get_global_rect() if ok_ref else Rect2()
		var pr: Rect2 = panel.get_global_rect()
		var inside_panel := ok_ref and pr.grow(0.5).encloses(mr)
		var inside_vp := ok_ref and vp.grow(0.5).encloses(mr)
		check(inside_panel and inside_vp, "medallion_inside_panel %s: med=%s panel=%s vp=%s" % [str(sz), str(mr), str(pr), str(vp)])
	hud.queue_free()


const ALLOWED_SPEAKERS := ["", "???", "X?", "X", "Sistem", "Kayıt", "Shilda", "Noroi", "Arşivci", "Yansıma", "Ses", "Çekirdek", "GameState.keeper_speaker_name()"]


## Verilen alt dizgeyi içeren fonksiyon adları (üst düzey func satırına göre).
func _funcs_calling(src: String, needle: String) -> Array:
	var out: Array = []
	var cur := ""
	for line in src.replace("\r", "").split("\n"):
		if line.begins_with("func ") or line.begins_with("static func "):
			cur = line.substr(line.find("func ") + 5).split("(")[0].strip_edges()
		elif needle in line and not line.strip_edges().begins_with("#") and cur != "" and not out.has(cur):
			out.append(cur)
	return out


func _scan_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan_files(dir.path_join(d), out)


func _speaker_contract_scan() -> void:
	var files: Array = []
	_scan_files("res://scripts", files)
	_scan_files("res://scenes", files)
	var rx_say := RegEx.new()
	rx_say.compile('(?:say|whisper|say_with)\\((GameState\\.keeper_speaker_name\\(\\)|"[^"]*"),')
	var rx_lore := RegEx.new()
	rx_lore.compile('"([^"|\\n]{1,20})\\|')
	var bad: Array = []
	for f in files:
		if String(f).begins_with("res://scripts/dev/"):
			continue
		var src := FileAccess.get_file_as_string(f)
		for m in rx_say.search_all(src):
			var sp := m.get_string(1)
			if sp.begins_with('"'):
				sp = sp.substr(1, sp.length() - 2)
			if not ALLOWED_SPEAKERS.has(sp):
				bad.append("%s: %s" % [f, sp])
		if String(f).ends_with(".tscn"):
			for m in rx_lore.search_all(src):
				if not ALLOWED_SPEAKERS.has(m.get_string(1)):
					bad.append("%s: lore %s" % [f, m.get_string(1)])
	check(bad.is_empty(), "speaker contract: only allowed speakers %s" % str(bad))
