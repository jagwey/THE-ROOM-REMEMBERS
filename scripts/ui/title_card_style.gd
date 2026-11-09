extends RefCounted
## Ortak başlık kartı görünümü (bölge kartı + Hafıza Mührü bildirimi): koyu zemin, iki ince çizgi, başlık + alt yazı.

## `container` içine zemin, çizgiler ve iki etiket kurar. `width`: içerik genişliği, `line_h`: üst-alt çizgi aralığı.
## Dönen sözlük: backing, top_line, bottom_line, title, sub.
static func build(container: Control, width: float, line_h: float, line_color: Color) -> Dictionary:
	var backing := ColorRect.new()
	backing.name = "Backing"
	backing.color = Color(0.07, 0.05, 0.09, 0.94)
	backing.position = Vector2(-20, -6)
	backing.size = Vector2(width + 40.0, line_h + 14.0)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(backing)

	var top := _line(container, Vector2(20, 0), width - 40.0, line_color)
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(0, 4)
	vbox.size = Vector2(width, line_h - 8.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(title, UiTheme.TITLE, true, Palette.IVORY)
	vbox.add_child(title)

	var sub := Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_outlined(sub, UiTheme.HINT, false, Palette.PALE_LILAC)
	vbox.add_child(sub)

	var bottom := _line(container, Vector2(20, line_h), width - 40.0, line_color)
	return {"backing": backing, "top_line": top, "bottom_line": bottom, "title": title, "sub": sub}


static func _line(container: Control, pos: Vector2, w: float, col: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = col
	line.position = pos
	line.size = Vector2(w, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(line)
	return line
