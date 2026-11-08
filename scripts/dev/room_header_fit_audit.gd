extends SceneTree
## Tüm oda başlıkları RoomHeader içinde kesilmeden (HEADER_MAX_W) sığmalı.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/room_header_fit_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("RHFIT ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("RHFIT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	var HUD = load("res://scripts/ui/hud_controller.gd")
	var rm := root.get_node("RoomManager")
	var theme := root.get_node("UiTheme")
	var font: Font = theme.font_bold if theme.font_bold else ThemeDB.fallback_font
	var fsize := 12 # hud.tscn RoomHeaderLabel font_size
	var ids: Array = rm.ROOM_TITLES_TR.keys()
	check(ids.size() == 30, "30 room titles (%d)" % ids.size())
	var widest := 0.0
	var widest_id := ""
	for rid in ids:
		var t: String = rm.get_room_number_and_title(StringName(rid))
		var w: float = HUD.header_needed_width(t, font, fsize)
		if w > widest:
			widest = w
			widest_id = String(rid)
		check(w <= HUD.get_script_constant_map()["HEADER_MAX_W"], "%s fits (%.0f <= %.0f)" % [t, w, HUD.get_script_constant_map()["HEADER_MAX_W"]])
	print("RHFIT widest ", widest_id, " ", widest)
	print("RHFIT done failures=", failures)
	quit(1 if failures > 0 else 0)
