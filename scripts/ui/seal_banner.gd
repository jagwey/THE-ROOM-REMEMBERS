extends CanvasLayer
## Hafıza Mührü bildirimi: başlık + alt yazı, kısa süre görünüp söner. Tek örnek, static ile çağrılır.
## Bölge kartı (y 112..188) ile çakışmaması için kendi yuvasında durur (y 200).

const TitleCardStyle := preload("res://scripts/ui/title_card_style.gd")
const GROUP := "seal_banner"
const BANNER_Y := 200.0
const BANNER_W := 440.0
const BANNER_H := 66.0
const HOLD := 2.2


static func show_banner(title: String, sub: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	for old in tree.get_nodes_in_group(GROUP):
		old.queue_free()
	var banner := new()
	tree.current_scene.add_child(banner)
	banner._present(title, sub)


func _present(title: String, sub: String) -> void:
	add_to_group(GROUP)
	layer = 28
	var box := Control.new()
	box.name = "BannerBox"
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = BANNER_Y
	box.offset_left = -BANNER_W * 0.5
	box.offset_right = BANNER_W * 0.5
	box.offset_bottom = BANNER_Y + BANNER_H + 4.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	add_child(box)
	var parts := TitleCardStyle.build(box, BANNER_W, BANNER_H, Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 0.8))
	(parts["title"] as Label).text = title
	(parts["sub"] as Label).text = sub
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.tween_interval(HOLD)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
