extends Node
## Pixeloid Sans — OFL piksel UI fontu; TR glifleri (ğüşıöç) doğrulandı.
## Hiyerarşi: hint 10 · body 12 · speaker/title 13–14 · ending title 16

const FONT_REG := "res://assets/fonts/PixeloidSans.ttf"
const FONT_BOLD := "res://assets/fonts/PixeloidSans-Bold.ttf"

var font_regular: Font
var font_bold: Font


func _ready() -> void:
	font_regular = _load_pixel_font(FONT_REG)
	font_bold = _load_pixel_font(FONT_BOLD)
	if font_regular == null:
		push_warning("UiTheme: PixeloidSans yüklenemedi")
		return
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		# Proje teması yoksa kök temayı oluştur.
		theme = Theme.new()
		theme.default_font = font_regular
		theme.default_font_size = 11
		call_deferred("_apply_root_theme", theme)
	else:
		theme.default_font = font_regular
		theme.default_font_size = 11
	_apply_type(theme, "Label", font_regular, 11)
	_apply_type(theme, "Button", font_regular, 10)
	if font_bold:
		theme.set_font("bold_font", "RichTextLabel", font_bold)
		theme.set_font("bold_italics_font", "RichTextLabel", font_bold)
	theme.set_font("normal_font", "RichTextLabel", font_regular)
	theme.set_font("italics_font", "RichTextLabel", font_regular)
	theme.set_font("mono_font", "RichTextLabel", font_regular)


func _apply_root_theme(theme: Theme) -> void:
	var tree := get_tree()
	if tree and tree.root:
		tree.root.theme = theme


func _load_pixel_font(path: String) -> Font:
	var f := load(path) as Font
	if f is FontFile:
		var ff := f as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


func _apply_type(theme: Theme, type_name: String, font: Font, size: int) -> void:
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)


func apply_label(label: Control, size: int, bold: bool = false) -> void:
	var f: Font = font_bold if bold and font_bold else font_regular
	if f == null or label == null:
		return
	if label is RichTextLabel:
		var rtl := label as RichTextLabel
		rtl.add_theme_font_override("normal_font", font_regular)
		if font_bold:
			rtl.add_theme_font_override("bold_font", font_bold)
		rtl.add_theme_font_size_override("normal_font_size", size)
		rtl.add_theme_font_size_override("bold_font_size", size)
	else:
		label.add_theme_font_override("font", f)
		label.add_theme_font_size_override("font_size", size)
