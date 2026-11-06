extends SceneTree
## Görüntülü UI kanıtı — headless DEĞİL.
## godot --path PROJECT -s res://scripts/dev/polish_capture.gd

const OUT_REL := "docs/gelistirme/ui-temel-sorunlar/screens"

var _shot_i := 0
var _out_abs := ""
var _dm: Node
var _echo: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	print("POLISH_CAPTURE start display=", DisplayServer.get_name())
	_out_abs = ProjectSettings.globalize_path("res://").path_join(OUT_REL)
	DirAccess.make_dir_recursive_absolute(_out_abs)
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	_dm = root.get_node_or_null("/root/DialogueManager")
	_echo = root.get_node_or_null("/root/EchoManager")
	await create_timer(0.7).timeout

	await _wait_dialogue_or(1.5)
	await _shot("08_font_dialogue_short")

	var long_tr := "Gözlerim yanıyor. Oda nefes alıyor gibi; taşların arasında eski bir şarkı sızıyor. "
	long_tr += "Bekçi uzaklarda duruyor, kırmızı ışık tavanı yalıyor, ayaklarım ağırlaşıyor. "
	long_tr += "Unutmak kolay, hatırlamak ise bir lanet; yine de sayfalar birbirine tutunuyor. "
	long_tr += "Üç, bir, dört — yankı sayılarını fısıldıyor. Kapı ağır, plaka soğuk, mühür suskun. "
	long_tr += "Bu cümle bilerek uzatıldı çünkü taşma testi sayfalama ister, küçültme veya kesme değil. "
	long_tr += long_tr
	long_tr += long_tr
	if _dm:
		_dm.call("clear")
	await process_frame
	await process_frame
	var hud := root.find_child("HUD", true, false)
	if hud and hud.has_method("_sync_dialogue_metrics"):
		hud.call("_sync_dialogue_metrics")
	if _dm:
		_dm.call("say", "BekçiAvcısıUzunKonuşmacıAdıTestiXXXXXXXX", long_tr)
	# Tip yazıcı bitsin
	var guard := 3.0
	while guard > 0.0 and _dm and bool(_dm.call("is_typing")):
		await create_timer(0.05).timeout
		guard -= 0.05
	await create_timer(0.15).timeout
	await _shot("09_font_dialogue_long")
	if _dm:
		_dm.call("advance")
	await create_timer(0.05).timeout
	if _dm:
		_dm.call("advance")
	guard = 3.0
	while guard > 0.0 and _dm and bool(_dm.call("is_typing")):
		await create_timer(0.05).timeout
		guard -= 0.05
	await create_timer(0.15).timeout
	await _shot("10_font_dialogue_page2")
	if _dm:
		_dm.call("clear")

	await create_timer(0.25).timeout
	await _shot("11_font_normal_play")

	var journal := root.find_child("Journal", true, false)
	if journal and journal.has_method("open_journal"):
		journal.call("open_journal")
		await create_timer(0.3).timeout
		await _shot("12_font_journal_empty")
		if _echo and _echo.has_method("_write_journal"):
			for i in 8:
				_echo.call("_write_journal", {
					"section": "notlar",
					"title": "Not %d — uzun başlık" % (i + 1),
					"body": "Bu satır kasıtlı olarak uzundur. Kitap sayfası içinde kaydırılmalı; Kapat düğmesinin üstüne binmemeli. Türkçe karakterler: ığüşöç İĞÜŞÖÇ.",
				})
		if journal.has_method("_show_section"):
			journal.call("_show_section", "notlar")
		await create_timer(0.3).timeout
		await _shot("13_font_journal_full")
		if journal.has_method("close_journal"):
			journal.call("close_journal")

	await create_timer(0.2).timeout
	await _shot("14_font_after_journal")

	var ok_page := true
	if _dm and _dm.has_method("pages_rejoin_equals_source"):
		ok_page = bool(_dm.call("pages_rejoin_equals_source", long_tr, 360.0, 4, 12))
	print("POLISH_CAPTURE page_rejoin_ok=", ok_page)
	print("POLISH_CAPTURE shots=", _shot_i, " dir=", _out_abs)
	quit(0 if ok_page else 1)


func _wait_dialogue_or(t: float) -> void:
	var left := t
	while left > 0.0:
		var open := false
		if _dm:
			open = bool(_dm.get("is_open"))
		if open:
			break
		await create_timer(0.05).timeout
		left -= 0.05
	await create_timer(0.2).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("POLISH_CAPTURE fail shot ", name)
		return
	var path := _out_abs.path_join("%s.png" % name)
	var err := img.save_png(path)
	_shot_i += 1
	print("POLISH_CAPTURE shot ", name, " err=", err, " size=", img.get_width(), "x", img.get_height())
