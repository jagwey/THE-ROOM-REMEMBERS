extends CanvasLayer
## Göz açma girişi: iki siyah göz kapağı (üst/alt, yumuşak kenarlı) yavaşça aralanır,
## yarıda bir kez kırpışır; nefes sesi. Beyaz flaş YOK — yalnız karanlıktan odaya.
## Süresince UiGate CUTSCENE: oynanış girdisi ve HUD kapalı. Devamda kısa sürer.

signal finished

const EDGE := 48.0

var _top: ColorRect
var _bot: ColorRect
var _veil: ColorRect
var _open: float = 0.0


func _init() -> void:
	layer = 90
	name = "EyeOpenIntro"


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	## Bulanık uyanış: koyu mor peçe, kapaklar açıldıkça çözülür.
	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.03, 0.08, 0.85)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_veil)
	_top = _make_lid(root, true)
	_bot = _make_lid(root, false)
	_apply(0.0)


func _exit_tree() -> void:
	## Sahne değişse bile girdi kilidi asla takılı kalmasın.
	UiGate.set_cutscene(false)


func _make_lid(parent: Control, top: bool) -> ColorRect:
	var lid := ColorRect.new()
	lid.color = Color.BLACK
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lid)
	## İç kenarda siyah → saydam geçiş (sert çizgi olmasın).
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
	gt.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
	gt.width = 4
	gt.height = 64
	var edge := TextureRect.new()
	edge.name = "Edge"
	edge.texture = gt
	edge.stretch_mode = TextureRect.STRETCH_SCALE
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lid.add_child(edge)
	return lid


func _apply(v: float) -> void:
	_open = v
	var sz := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640, 360)
	var half := sz.y * 0.5
	var travel := half + EDGE
	_top.size = Vector2(sz.x, half + 1.0)
	_top.position = Vector2(0, -v * travel)
	_bot.size = Vector2(sz.x, half + 1.0)
	_bot.position = Vector2(0, half + v * travel)
	var te := _top.get_node("Edge") as TextureRect
	te.position = Vector2(0, _top.size.y)
	te.size = Vector2(sz.x, EDGE)
	var be := _bot.get_node("Edge") as TextureRect
	be.position = Vector2(0, -EDGE)
	be.size = Vector2(sz.x, EDGE)
	if _veil:
		_veil.color.a = 0.85 * clampf(1.0 - v * 1.15, 0.0, 1.0)


## duration: toplam süre (ilk açılış ~2.2 sn, devam ~0.9 sn). Bitince kendini siler.
func play(duration: float = 2.2, blink: bool = true) -> void:
	UiGate.set_cutscene(true)
	AudioManager.play_sfx(&"breath", -4.0)
	var d := maxf(duration, 0.05)
	var tw := create_tween()
	if blink:
		tw.tween_interval(d * 0.12)
		tw.tween_method(_apply, 0.0, 0.28, d * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(_apply, 0.28, 0.06, d * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_method(_apply, 0.06, 1.0, d * 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_method(_apply, 0.0, 1.0, d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	UiGate.set_cutscene(false)
	finished.emit()
	queue_free()
