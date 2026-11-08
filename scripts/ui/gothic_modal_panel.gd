class_name GothicModalPanel
extends Control
## Yeniden kullanılabilir gotik modal: karartma + NinePatch çerçeve + başlık + içerik kutusu.
## Anchors ile ortalanır (640x360 taban, geniş ekranda genişler). Çerçeve PNG'si 9-dilimlenir,
## iç zemin palet renkli StyleBoxFlat ile okunaklı tutulur (PNG'deki hazır plaka yuvaları örtülür).

const FRAME_MENU := "res://assets/panels/menu.png"
const FRAME_INVENTORY := "res://assets/panels/inventory.png"
## Atlas bölgeleri (320x180 kaynak içindeki çerçeve) ve 9-dilim kenar payları.
const MENU_REGION := Rect2(86, 2, 148, 174)
const INVENTORY_REGION := Rect2(70, 2, 180, 176)

var dim: ColorRect
var frame: NinePatchRect
var title_label: Label
## İçerik bu kutuya eklenir (title sonrası).
var body: VBoxContainer

## Esc / geri ile kapanınca çağrılır (UiGate kilidini bırakmak için).
var on_close: Callable = Callable()

var _inner: PanelContainer


## variant: &"menu" | &"inventory"
func setup(title: String, panel_size: Vector2, variant: StringName = &"menu", dim_alpha: float = 0.78) -> GothicModalPanel:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(Palette.VOID, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	frame = NinePatchRect.new()
	frame.name = "Frame"
	var atlas := AtlasTexture.new()
	var inv := variant == &"inventory"
	atlas.atlas = load(FRAME_INVENTORY if inv else FRAME_MENU)
	atlas.region = INVENTORY_REGION if inv else MENU_REGION
	frame.texture = atlas
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.patch_margin_left = 22
	frame.patch_margin_right = 22
	frame.patch_margin_top = 24
	frame.patch_margin_bottom = 22
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -panel_size.x * 0.5
	frame.offset_right = panel_size.x * 0.5
	frame.offset_top = -panel_size.y * 0.5
	frame.offset_bottom = panel_size.y * 0.5
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(frame)

	_inner = PanelContainer.new()
	_inner.name = "Inner"
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.offset_left = 15
	_inner.offset_right = -15
	_inner.offset_top = 15
	_inner.offset_bottom = -15
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.DEEP_STONE
	sb.border_color = Palette.CRIMSON
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_inner.add_theme_stylebox_override("panel", sb)
	frame.add_child(_inner)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_inner.add_child(col)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.apply_outlined(title_label, UiTheme.SPEAKER, true)
	col.add_child(title_label)
	body = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	col.add_child(body)
	return self


func set_title(text: String) -> void:
	if title_label:
		title_label.text = text


func add_label(text: String, size: int = UiTheme.HINT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.apply_outlined(l, size, false, Palette.PALE_LILAC)
	body.add_child(l)
	return l


func add_button(text: String, on_pressed: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b)
	b.pressed.connect(on_pressed)
	(parent if parent != null else body).add_child(b)
	return b


static func style_button(b: Button, font_size: int = UiTheme.BODY) -> void:
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 30.0)
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.apply_label(b, font_size, false)
	b.add_theme_color_override("font_color", Palette.IVORY)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Palette.IVORY)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Palette.PALE_LILAC)
	b.add_theme_stylebox_override("normal", _box(Palette.VOID, Palette.STONE))
	b.add_theme_stylebox_override("hover", _box(Palette.STONE, Palette.CRIMSON))
	b.add_theme_stylebox_override("pressed", _box(Palette.DARK_RED, Palette.CRIMSON))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Palette.IVORY))
	b.add_theme_stylebox_override("disabled", _box(Palette.DEEP_STONE, Palette.DEEP_STONE))


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_BACK):
		if has_method("dismiss"):
			call("dismiss")
		elif has_method("close"):
			call("close")
		else:
			visible = false
		if on_close.is_valid():
			on_close.call()
		get_viewport().set_input_as_handled()

