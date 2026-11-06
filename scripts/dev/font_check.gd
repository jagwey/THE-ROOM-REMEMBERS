extends SceneTree
func _initialize():
	OS.set_environment("TORIMON_FRESH","1")
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	var hud = root.find_child("HUD", true, false)
	print("FONT_CHECK hud=", hud)
	if hud == null:
		print("FONT_CHECK groups=", root.get_tree().get_nodes_in_group("hud"))
		hud = root.get_tree().get_first_node_in_group("hud")
	print("FONT_CHECK hud2=", hud)
	if hud:
		print("FONT_CHECK children=", hud.get_child_count())
		var text = hud.find_child("Text", true, false)
		var speaker = hud.find_child("Speaker", true, false)
		var hint = hud.find_child("Hint", true, false)
		print("FONT_CHECK nodes text=", text, " speaker=", speaker, " hint=", hint)
		for n in [text, speaker, hint]:
			if n:
				var f = n.get_theme_font("font")
				print("FONT_CHECK ", n.name, " font=", f, " path=", f.resource_path if f else "null", " sz=", n.get_theme_font_size("font_size"))
	quit(0)
