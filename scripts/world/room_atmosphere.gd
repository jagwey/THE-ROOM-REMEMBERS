extends Node2D
## Oda paleti + hafif parallax modülasyon (Awakening / Core).

@export var room_id: StringName = &"awakening"

const MOTE_MAX := 28 ## <= 40 particles per room
const ROOM_H := 360.0
const BEAM_TEX := "res://assets/layers/light_beam.png"
## Isik huzmeleri y=288 zemin cizgisini asmaz (dondurulmus alt kose dahil): merkez 130, yukseklik 240.
const SHAFT_CY := 130.0
const SHAFT_H := 240.0

var _motes: CPUParticles2D
var _beams: Array[Sprite2D] = []
var _beam_base: Array[float] = []
var _beam_phase: Array[float] = []
var _built: bool = false
var _t: float = 0.0


func _ready() -> void:
	_tint_layers()
	_align_backdrop()
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_build_atmosphere")


## Zemin çizgisi (y=288) ile arka plan mobilya tabanlarını hizala: far/mid/front sprite'larını
## bölge başına aşağı kaydır, parallax dikey kaymasını kapat, tavan kemeri + zemin katmanlarını ekle.
const FLOOR_Y := 288.0
const BackdropScript := preload("res://scripts/world/room_backdrop.gd")
## Far katmanda zemin satırı (PNG içi), mid katmanda 234; front alt satırları bölgeye göre.
const FAR_FLOOR_ROW := {"awakening": 228.0, "core": 253.0, "decay": 243.0, "experiment": 243.0, "library": 240.0, "mirrors": 232.0}
const MID_FLOOR_ROW := 234.0
const FRONT_BOTTOM_ROW := {"awakening": 265.0, "core": 274.0, "decay": 265.0, "experiment": 288.0, "library": 288.0, "mirrors": 288.0}


func _region_key() -> String:
	var rid := String(room_id)
	for k in FAR_FLOOR_ROW:
		if rid.begins_with(k):
			return k
	return "awakening"


func _align_backdrop() -> void:
	if has_meta("backdrop_aligned"):
		return
	set_meta("backdrop_aligned", true)
	var key := _region_key()
	var shifts := {
		"ParallaxFar": FLOOR_Y - float(FAR_FLOOR_ROW[key]),
		"ParallaxMid": FLOOR_Y - MID_FLOOR_ROW,
		"ParallaxFront": FLOOR_Y - float(FRONT_BOTTOM_ROW[key]),
	}
	var last_idx := -1
	for nm in shifts:
		var px := get_node_or_null(nm)
		if px == null:
			continue
		last_idx = maxi(last_idx, px.get_index())
		if px is Parallax2D:
			## Dikey parallax yok: sprite'lar dünyada sabit y'de dursun (hizalama kamera y'sine bağlı kalmasın).
			var ss: Vector2 = (px as Parallax2D).scroll_scale
			(px as Parallax2D).scroll_scale = Vector2(ss.x, 1.0)
		var dy: float = shifts[nm]
		if dy > 0.0:
			for c in px.get_children():
				if c is Node2D:
					(c as Node2D).position.y += dy
	var back := Node2D.new()
	back.set_script(BackdropScript)
	back.name = "BackdropFill"
	add_child(back)
	move_child(back, last_idx + 1 if last_idx >= 0 else 0)
	var tint := _region_color().lerp(Color.WHITE, 0.55)
	back.call("setup", _backdrop_width(), tint, String(room_id) == "awakening_balcony", _motif())
	call_deferred("_refresh_backdrop_width", back)


func _backdrop_width() -> float:
	if "bounds" in self and (self.get("bounds") as Rect2).size.x > 64.0:
		return (self.get("bounds") as Rect2).size.x
	return _room_width()


func _refresh_backdrop_width(back: Node) -> void:
	if is_instance_valid(back):
		back.call("setup", _backdrop_width(), _region_color().lerp(Color.WHITE, 0.55), String(room_id) == "awakening_balcony", _motif())



func _process(delta: float) -> void:
	_t += delta
	for i in _beams.size():
		var s := _beams[i]
		var k := 0.5 + 0.5 * sin(_t * 0.45 + _beam_phase[i])
		s.modulate.a = _beam_base[i] * (0.45 + 0.55 * k)


func _on_visibility_changed() -> void:
	if not _built:
		return
	var vis := is_visible_in_tree()
	if vis and RoomManager.get_room_bounds(room_id).size.x > 64.0:
		var bw := _room_width()
		if not is_equal_approx(bw, _motes.emission_rect_extents.x * 2.0):
			_motes.emission_rect_extents = Vector2(bw * 0.5, ROOM_H * 0.5)
			_motes.position = Vector2(bw * 0.5, ROOM_H * 0.5)
	_motes.emitting = vis
	set_process(vis and not _beams.is_empty())


func _motif() -> String:
	var rid := String(room_id)
	if rid.begins_with("core"):
		return "core"
	if rid.begins_with("decay"):
		return "decay"
	if rid.begins_with("library"):
		return "library"
	if rid.begins_with("experiment"):
		return "experiment"
	if rid.begins_with("mirrors"):
		return "mirrors"
	return "awakening"


func _region_color() -> Color:
	var rid := String(room_id)
	if rid.begins_with("core"):
		return Palette.CRIMSON.lerp(Palette.IVORY, 0.25)
	if rid.begins_with("decay"):
		return Color(0.62, 0.72, 0.45)
	if rid.begins_with("library"):
		return Color(0.9, 0.74, 0.48)
	if rid.begins_with("experiment"):
		return Color(0.6, 0.82, 0.86)
	if rid.begins_with("mirrors"):
		return Palette.PALE_LILAC.lerp(Color(0.75, 0.82, 1.0), 0.5)
	return Palette.PALE_LILAC.lerp(Palette.IVORY, 0.4)


func _room_width() -> float:
	var b := RoomManager.get_room_bounds(room_id)
	if b.size.x > 64.0:
		return b.size.x
	return 960.0


static func _dot_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length() / 4.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _build_atmosphere() -> void:
	if _built or not is_inside_tree():
		return
	_built = true
	var w := _room_width()
	var col := _region_color()
	var rid := String(room_id)
	# Floating motes
	_motes = CPUParticles2D.new()
	_motes.name = "AtmosphereMotes"
	_motes.z_index = 3
	_motes.texture = _dot_texture()
	_motes.amount = clampi(int(w / 40.0), 12, MOTE_MAX)
	_motes.lifetime = 16.0
	_motes.preprocess = 16.0
	_motes.local_coords = true
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = Vector2(w * 0.5, ROOM_H * 0.5)
	_motes.position = Vector2(w * 0.5, ROOM_H * 0.5)
	_motes.direction = Vector2(1.0, -0.15)
	_motes.spread = 40.0
	_motes.initial_velocity_min = 3.0
	_motes.initial_velocity_max = 11.0
	_motes.gravity = Vector2(0.0, -0.8) if (rid.begins_with("core") or rid.begins_with("decay")) else Vector2(0.0, 0.4)
	_motes.scale_amount_min = 0.35
	_motes.scale_amount_max = 0.9
	_motes.color = Color(col.r, col.g, col.b, 0.6)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_motes.color_ramp = g
	_motes.emitting = is_visible_in_tree()
	add_child(_motes)
	# Light shafts
	var tex := load(BEAM_TEX) as Texture2D
	if tex:
		var count := clampi(int(w / 600.0), 1, 3)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(rid)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for i in count:
			var s := Sprite2D.new()
			s.name = "LightShaft%d" % i
			s.texture = tex
			s.material = mat
			s.z_index = 2
			s.centered = true
			var cx := (float(i) + 0.5) / float(count) * w + rng.randf_range(-60.0, 60.0)
			s.position = Vector2(cx, SHAFT_CY)
			s.rotation = rng.randf_range(-0.2, 0.1)
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			s.scale = Vector2(rng.randf_range(0.9, 1.6) * 90.0 / tw * 1.5, SHAFT_H / th)
			var base := rng.randf_range(0.10, 0.2)
			s.modulate = Color(col.r, col.g, col.b, base)
			add_child(s)
			_beams.append(s)
			_beam_base.append(base)
			_beam_phase.append(rng.randf_range(0.0, TAU))
	_on_visibility_changed()


func _tint_layers() -> void:
	var far := get_node_or_null("ParallaxFar") as CanvasItem
	var mid := get_node_or_null("ParallaxMid") as CanvasItem
	var front := get_node_or_null("ParallaxFront") as CanvasItem
	var rid := String(room_id)
	if rid == "core":
		if far:
			far.modulate = Color(Palette.CRIMSON.r, Palette.CRIMSON.g, Palette.CRIMSON.b, 1.0).lerp(Color.WHITE, 0.7)
		if mid:
			mid.modulate = Color(1.0, 0.92, 0.94, 1.0)
		if front:
			front.modulate = Color.WHITE
	elif rid.begins_with("awakening"):
		if far:
			far.modulate = Color(Palette.DEEP_STONE.r, Palette.DEEP_STONE.g, Palette.DEEP_STONE.b, 1.0).lerp(Color.WHITE, 0.5)
		if mid:
			mid.modulate = Color(0.92, 0.88, 0.9, 1.0)
		if front:
			front.modulate = Color(0.96, 0.93, 0.95, 1.0)
	elif rid.begins_with("decay"):
		if far:
			far.modulate = Color(0.42, 0.5, 0.38, 1.0).lerp(Color.WHITE, 0.45)
		if mid:
			mid.modulate = Color(0.88, 0.82, 0.78, 1.0)
		if front:
			front.modulate = Color(0.94, 0.9, 0.86, 1.0)
	elif rid.begins_with("library"):
		if far:
			far.modulate = Color(0.5, 0.48, 0.62, 1.0).lerp(Color.WHITE, 0.5)
		if mid:
			mid.modulate = Color(0.9, 0.88, 0.94, 1.0)
		if front:
			front.modulate = Color.WHITE
	elif rid.begins_with("experiment"):
		if far:
			far.modulate = Color(Palette.PALE_LILAC.r, Palette.PALE_LILAC.g, Palette.PALE_LILAC.b, 1.0).lerp(Color.WHITE, 0.55)
		if mid:
			mid.modulate = Color(0.9, 0.86, 0.92, 1.0)
		if front:
			front.modulate = Color.WHITE
	elif rid.begins_with("mirrors"):
		if far:
			far.modulate = Color(0.62, 0.58, 0.72, 1.0).lerp(Color.WHITE, 0.55)
		if mid:
			mid.modulate = Color(0.88, 0.84, 0.92, 1.0)
		if front:
			front.modulate = Color.WHITE
	else:
		if far:
			far.modulate = Color(Palette.PALE_LILAC.r, Palette.PALE_LILAC.g, Palette.PALE_LILAC.b, 1.0).lerp(Color.WHITE, 0.55)
		if mid:
			mid.modulate = Color(1.0, 0.96, 0.98, 1.0)
		if front:
			front.modulate = Color.WHITE
