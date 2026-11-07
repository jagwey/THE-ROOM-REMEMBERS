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
	check(Portraits.key_for("Noroi") == &"noroi" and Portraits.key_for("Sen") == &"noroi", "noroi mapping")
	check(Portraits.key_for("Noroi", true) == &"noroi_sad", "noroi sad mapping")
	check(Portraits.key_for("Bekçi") == &"bekci" and Portraits.key_for("???") == &"bekci", "bekci mapping")
	check(Portraits.key_for("Shilda") == &"shilda", "shilda mapping")
	check(Portraits.key_for("Arşivci") == &"" and Portraits.key_for("Kayıt") == &"" and Portraits.key_for("Çekirdek") == &"", "unknown speakers no portrait")
	for k in Portraits.PATHS.keys():
		check(Portraits.texture_for(k) != null, "portrait texture loads: %s" % k)
	# Fısıltı konuşmacısı
	var dmc := root.get_node("DialogueManager")
	check(dmc.resolve_whisper_speaker("Noroi", true, false) == "Noroi", "whisper keeps Noroi")
	check(dmc.resolve_whisper_speaker("Shilda", true, false) == "???", "unnamed Shilda whisper masked")
	check(dmc.resolve_whisper_speaker("???", true, true) == "Shilda", "named ??? whisper -> Shilda")
	check(dmc.resolve_whisper_speaker("Bekçi", true, true) == "Bekçi", "Bekçi whisper kept")
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
	quit(1 if failures else 0)
