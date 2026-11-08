extends CanvasLayer
## Hafıza Mührü bildirimi: başlık + alt yazı, kısa süre görünüp söner. Tek örnek, static ile çağrılır.

const GROUP := "seal_banner"
const BANNER_Y := 112.0
const HOLD := 2.2

static func show_banner(title: String, sub: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	for old in tree.get_nodes_in_group(GROUP):
		old.queue_free()
	var banner := load("res://scripts/ui/seal_banner.gd").new() as CanvasLayer
	tree.current_scene.add_child(banner)
	banner.call("_present", title, sub)

var title_text: String = ""
var sub_text: String = ""


func _present(title: String, sub: String) -> void:
	title_text = title
	sub_text = sub
	add_to_group(GROUP)
	layer = 28
	var box := Control.new()
	box.name = "BannerBox"
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = BANNER_Y
	box.offset_left = -220.0
	box.offset_right = 220.0
	box.offset_bottom = BANNER_Y + 70.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)
	var back := ColorRect.new()
	back.color = Color(0.07, 0.05, 0.09, 0.94)
	back.position = Vector2(-20, -6)
	back.size = Vector2(480, 80)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(back)
	for y in [0.0, 66.0]:
		var line := ColorRect.new()
		line.color = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.8)
		line.position = Vector2(20, y)
		line.size = Vector2(400, 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(line)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(0, 8)
	vbox.size = Vector2(440, 54)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(t, UiTheme.TITLE, true, Palette.IVORY)
	vbox.add_child(t)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(s, UiTheme.HINT, false, Palette.PALE_LILAC)
	vbox.add_child(s)
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.tween_interval(HOLD)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
