extends Node2D
## Oda cilası (görsel): tamamen prosedürel (Polygon2D, Label, CanvasLayer), yeni asset yok, çarpışma yok,
## bulmaca/diyalog durumuna yazmaz. Oda gizliyken Godot _process'i durdurur. Parlama/solma/nabız animasyonları
## GameSettings.shake_enabled() kapalıyken (azaltılmış efekt) statik kalır. Düğüm odanın (0,0) noktasına konur.
## kind: garden_dots | greenhouse_trail | gallery_glass | clock_x | shrine_shadow | balcony_vignette | vault_glints

@export var kind: StringName = &""
## garden_dots: sequence_shrine yolu. balcony_vignette: dürbün (lore_point) yolu.
@export var source_path: NodePath = NodePath("")
## greenhouse_trail: saksı düğüm yolları.
@export var pot_paths: PackedStringArray = PackedStringArray()
## clock_x: bu bulmaca çözülünce (saat durunca) silüet kısa süre görünür.
@export var puzzle: StringName = &""
## Görsel merkez (garden_dots: nokta sırası; gallery_glass: cam; clock_x: silüet; vault_glints: sütun y'si).
@export var anchor: Vector2 = Vector2.ZERO
@export var xs: PackedFloat32Array = PackedFloat32Array()

var _src: Node = null
var _dots: Array = []
var _lit: int = -1
var _marked: Dictionary = {}
var _label: Label = null
var _t: float = 0.0
var _ghost: Node2D = null
var _dir: float = 1.0
var _fig: Node2D = null
var _layer: CanvasLayer = null
var _vig: TextureRect = null
var _vig_on: bool = false


func _ready() -> void:
	if source_path != NodePath(""):
		_src = get_node_or_null(source_path)
	match kind:
		&"garden_dots":
			_build_dots()
		&"gallery_glass":
			_build_glass()
		&"clock_x":
			_build_clock_x()
			PuzzleManager.puzzle_solved.connect(_on_solved)
		&"shrine_shadow":
			_ghost = _figure(Color(0.05, 0.04, 0.1, 0.28))
			_ghost.z_index = 2
			_ghost.visible = false
			add_child(_ghost)
		&"balcony_vignette":
			_build_vignette()
			visibility_changed.connect(_on_vis)
		&"vault_glints":
			_build_glints()


func _exit_tree() -> void:
	if PuzzleManager.puzzle_solved.is_connected(_on_solved):
		PuzzleManager.puzzle_solved.disconnect(_on_solved)


func _fx() -> bool:
	return GameSettings.shake_enabled()


func _circle(r: float, c: Color, at: Vector2 = Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	p.polygon = pts
	p.color = c
	p.position = at
	return p


func _figure(c: Color) -> Node2D:
	var f := Node2D.new()
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-7, -26), Vector2(7, -26), Vector2(10, 0), Vector2(-10, 0)])
	body.color = c
	f.add_child(body)
	f.add_child(_circle(6.0, c, Vector2(0, -31)))
	return f


# --- garden_dots -----------------------------------------------------------
func _build_dots() -> void:
	for i in 3:
		var d := Node2D.new()
		d.position = anchor + Vector2(float(i - 1) * 44.0, 0)
		d.add_child(_circle(7.0, Color(1.0, 0.85, 0.45, 0.22)))
		d.add_child(_circle(3.0, Color(1.0, 0.92, 0.6, 0.95)))
		d.visible = false
		d.z_index = 4
		add_child(d)
		_dots.append(d)


func _garden_progress() -> int:
	if _src != null and is_instance_valid(_src) and _src.has_method("get_progress"):
		var sid: StringName = _src.get("puzzle_id")
		if PuzzleManager.is_solved(sid):
			return _dots.size()
		return clampi(int(_src.get_progress()), 0, _dots.size())
	return 0


# --- gallery_glass ---------------------------------------------------------
func _build_glass() -> void:
	var panel := Polygon2D.new()
	panel.polygon = PackedVector2Array([Vector2(-80, -58), Vector2(80, -58), Vector2(80, 58), Vector2(-80, 58)])
	panel.color = Color(0.6, 0.72, 0.9, 0.09)
	panel.position = anchor
	panel.z_index = -1
	add_child(panel)
	for i in 3:
		var face := Node2D.new()
		face.position = anchor + Vector2(float(i - 1) * 46.0, 8.0 + float(i % 2) * 6.0)
		face.add_child(_circle(11.0, Color(0.85, 0.9, 1.0, 1.0)))
		face.add_child(_circle(1.6, Color(0.05, 0.05, 0.1, 1.0), Vector2(-4, -2)))
		face.add_child(_circle(1.6, Color(0.05, 0.05, 0.1, 1.0), Vector2(4, -2)))
		face.scale = Vector2(0.8, 1.15)
		face.z_index = 0
		add_child(face)
		if _fx():
			face.modulate.a = 0.0
			var tw := create_tween().set_loops()
			tw.tween_interval(1.4 * float(i) + 0.5)
			tw.tween_property(face, "modulate:a", 0.16, 2.4)
			tw.tween_interval(1.2)
			tw.tween_property(face, "modulate:a", 0.0, 2.4)
			tw.tween_interval(3.0)
		else:
			face.modulate.a = 0.1
	_label = Label.new()
	_label.position = anchor + Vector2(-48, -86)
	_label.add_theme_font_size_override("font_size", UiTheme.HINT)
	_label.modulate = Color(0.85, 0.9, 1.0, 0.7)
	_label.z_index = 4
	add_child(_label)
	_refresh_count()


func _refresh_count() -> void:
	if _label == null:
		return
	var n := 0
	var wm: Dictionary = GameState.world_memory_state
	if wm.has("corpses"):
		n = (wm["corpses"] as Array).size()
	_label.text = "Beden: %d" % n


# --- greenhouse_trail ------------------------------------------------------
func _soil_mark(pot: Node2D) -> void:
	var m := Node2D.new()
	m.position = Vector2(pot.global_position.x, 294.0)
	var e := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 4.0))
	e.polygon = pts
	e.color = Color(0.2, 0.13, 0.08, 0.75)
	m.add_child(e)
	for k in [-12.0, -4.0, 6.0, 13.0]:
		m.add_child(_circle(1.4, Color(0.3, 0.2, 0.11, 0.9), Vector2(k, -2.0 + absf(k) * 0.05)))
	m.z_index = 1
	add_child(m)
	if _fx():
		m.modulate.a = 0.0
		create_tween().tween_property(m, "modulate:a", 1.0, 1.2)


# --- clock_x ---------------------------------------------------------------
func _build_clock_x() -> void:
	_fig = _figure(Color(0.03, 0.03, 0.06, 1.0))
	_fig.position = anchor
	_fig.scale = Vector2(1.5, 1.5)
	## Yüzde silik bir X izi.
	for a in [45.0, -45.0]:
		var bar := Polygon2D.new()
		bar.polygon = PackedVector2Array([Vector2(-5, -1), Vector2(5, -1), Vector2(5, 1), Vector2(-5, 1)])
		bar.rotation_degrees = a
		bar.color = Color(0.7, 0.2, 0.2, 0.9)
		bar.position = Vector2(0, -31)
		_fig.add_child(bar)
	_fig.modulate.a = 0.0
	_fig.z_index = -1
	add_child(_fig)


func _on_solved(id: StringName) -> void:
	if id != puzzle or _fig == null or not is_visible_in_tree():
		return
	if _fx():
		var tw := create_tween()
		tw.tween_property(_fig, "modulate:a", 0.5, 0.5)
		tw.tween_interval(1.6)
		tw.tween_property(_fig, "modulate:a", 0.0, 0.9)
	else:
		_fig.modulate.a = 0.35
		get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(_fig): _fig.modulate.a = 0.0)


# --- balcony_vignette ------------------------------------------------------
func _build_vignette() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 24
	_layer.visible = false
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.45, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	_vig = TextureRect.new()
	_vig.texture = gt
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.modulate.a = 0.0
	_layer.add_child(_vig)
	add_child(_layer)


func _on_vis() -> void:
	if not is_visible_in_tree() and _layer != null:
		_vig_on = false
		_vig.modulate.a = 0.0
		_layer.visible = false


func _set_vignette(on: bool) -> void:
	if on == _vig_on or _vig == null:
		return
	_vig_on = on
	if on:
		_layer.visible = true
	var target := 0.75 if on else 0.0
	if _fx():
		var tw := create_tween()
		tw.tween_property(_vig, "modulate:a", target, 0.6)
		if not on:
			tw.tween_callback(func(): if not _vig_on: _layer.visible = false)
	else:
		_vig.modulate.a = target * 0.6
		if not on:
			_layer.visible = false


# --- vault_glints ----------------------------------------------------------
func _build_glints() -> void:
	var i := 0
	for x in xs:
		for row in 2:
			var s := Polygon2D.new()
			s.polygon = PackedVector2Array([Vector2(0, -4), Vector2(1.2, -1.2), Vector2(4, 0), Vector2(1.2, 1.2), Vector2(0, 4), Vector2(-1.2, 1.2), Vector2(-4, 0), Vector2(-1.2, -1.2)])
			s.color = Color(1.0, 0.9, 0.55, 1.0)
			s.position = Vector2(x + (10.0 if row == 0 else -12.0), anchor.y - 26.0 * float(row) - 6.0)
			s.z_index = 4
			add_child(s)
			if _fx():
				s.modulate.a = 0.0
				var tw := create_tween().set_loops()
				tw.tween_interval(0.7 * float(i) + 0.3)
				tw.tween_property(s, "modulate:a", 0.85, 0.5)
				tw.tween_property(s, "modulate:a", 0.0, 0.9)
				tw.tween_interval(2.4)
			else:
				s.modulate.a = 0.3
			i += 1


# --- per frame -------------------------------------------------------------
func _process(delta: float) -> void:
	match kind:
		&"garden_dots":
			var p := _garden_progress()
			if p != _lit:
				var prev := _lit
				_lit = p
				for i in _dots.size():
					var d: Node2D = _dots[i]
					d.visible = i < p
					if _fx() and i < p and i >= prev and prev >= 0:
						d.scale = Vector2(1.9, 1.9)
						create_tween().tween_property(d, "scale", Vector2.ONE, 0.45)
		&"gallery_glass":
			_t += delta
			if _t >= 1.0:
				_t = 0.0
				_refresh_count()
		&"greenhouse_trail":
			var shade := get_tree().get_first_node_in_group("greenhouse_shade")
			if shade == null or not (shade is Node2D):
				return
			## Yalnız gölgenin diz çöktüğü saksı işaretlenir; üstünden yürüyüp geçtiği yanlış saksı değil.
			if not bool(shade.get_meta("kneeling", true)):
				return
			var sx: float = (shade as Node2D).global_position.x
			for sp in pot_paths:
				var pot := get_node_or_null(NodePath(sp)) as Node2D
				if pot == null or _marked.has(sp):
					continue
				if absf(sx - pot.global_position.x) < 22.0:
					_marked[sp] = true
					_soil_mark(pot)
		&"shrine_shadow":
			var pl := get_tree().get_first_node_in_group("player") as Node2D
			if pl == null or _ghost == null:
				return
			var vx := 0.0
			if pl is CharacterBody2D:
				vx = (pl as CharacterBody2D).velocity.x
			if absf(vx) > 8.0:
				_dir = signf(vx)
			var target := pl.global_position + Vector2(_dir * 38.0, 0.0)
			if not _ghost.visible:
				_ghost.global_position = target
				_ghost.visible = true
			_ghost.global_position = _ghost.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
		&"balcony_vignette":
			if _src != null and is_instance_valid(_src):
				_set_vignette(bool(_src.get("_busy")))
