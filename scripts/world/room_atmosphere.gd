extends Node2D
## Oda paleti + hafif parallax modülasyon (Awakening / Core).

@export var room_id: StringName = &"awakening"

const MOTE_MAX := 28 ## <= 40 particles per room
const ROOM_H := 360.0

var _motes: CPUParticles2D
var _built: bool = false


func _ready() -> void:
	_tint_layers()
	_align_backdrop()
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_build_atmosphere")


const BackdropScript := preload("res://scripts/world/room_backdrop.gd")
## Resmin arka duvarı y=228..253'te bitiyor. Oyuncuya doğru yaklaşan iki ayrı zemin düzlemi.
const MID_BASE := 270.0
const FRONT_BASE := 284.0
const FRONT_BOTTOM_ROW := {"awakening": 265.0, "core": 274.0, "decay": 265.0, "experiment": 295.0, "library": 295.0, "mirrors": 295.0}
## Uyanış yatağı/kapsülü resmi yalnız yataklı odalara (awakening, awakening_crypt) aittir;
## diğer Uyanış odaları soğuk taş tonlu gotik kemer duvarını kullanır.
const AWAKENING_CORRIDOR_ROOMS := [&"awakening_vigil", &"awakening_bellroom", &"awakening_s_room"]
## Komşu odaların aynı duvar kağıdını tekrarlamaması için bölgesel ikincil arka plan eşlemesi.
## RoomArchitecture kullanan özel odalar ile awakening_balcony aşağıda önceden döner ve değişmez.
const ALT_FAR_ROOMS := {
	&"awakening_seal": "res://assets/backgrounds/decay/far_alt.png",
	&"awakening_bellroom": "res://assets/backgrounds/decay/far_alt.png",
	&"awakening_s_room": "res://assets/backgrounds/decay/far_alt.png",
	&"decay_catacombs": "res://assets/backgrounds/decay/far_alt.png",
	&"decay_shilda_wall": "res://assets/backgrounds/decay/far_alt.png",
	&"library_witness": "res://assets/backgrounds/library/far_alt.png",
	&"library_upper_stacks": "res://assets/backgrounds/library/far_alt.png",
	&"library_archive_vault": "res://assets/backgrounds/library/far_alt.png",
	&"library_reading_cell": "res://assets/backgrounds/library/far_alt.png",
	&"experiment_cells": "res://assets/backgrounds/experiment/far_alt.png",
	&"experiment_twin_lab": "res://assets/backgrounds/experiment/far_alt.png",
	&"experiment_quarantine": "res://assets/backgrounds/experiment/far_alt.png",
	&"experiment_observation": "res://assets/backgrounds/experiment/far_alt.png",
	&"mirrors_dual": "res://assets/backgrounds/mirrors/far_alt.png",
	&"mirrors_unbroken": "res://assets/backgrounds/mirrors/far_alt.png",
	&"mirrors_inverse_hall": "res://assets/backgrounds/mirrors/far_alt.png",
	&"mirrors_shrine": "res://assets/backgrounds/mirrors/far_alt.png",
	&"mirrors_1927": "res://assets/backgrounds/mirrors/far_alt.png",
	&"core_seal_chamber": "res://assets/backgrounds/core/far_alt.png",
	&"core_memory_vault": "res://assets/backgrounds/core/far_alt.png",
	&"core_last_record": "res://assets/backgrounds/core/far_alt.png",
}


func _align_backdrop() -> void:
	if has_meta("backdrop_aligned"):
		return
	set_meta("backdrop_aligned", true)
	# Özel, tam boy oda çizimi hem tavanı hem zemini içeriyor.
	if has_node("RoomArchitecture"):
		for layer_name in ["ParallaxFar", "ParallaxMid", "ParallaxFront"]:
			var layer := get_node_or_null(layer_name) as CanvasItem
			if layer:
				layer.hide()
		return
	var far := get_node_or_null("ParallaxFar") as Parallax2D
	var mid := get_node_or_null("ParallaxMid") as Parallax2D
	var front := get_node_or_null("ParallaxFront") as Parallax2D
	# Balkon: kendi kemerli boşluk manzarası var; tekrar eden yatak duvarı ve korkuluk önü enkaz gizlenir.
	if room_id == &"awakening_balcony":
		for layer in [far, mid, front]:
			if layer:
				layer.hide()
		var balcony_back := Node2D.new()
		balcony_back.set_script(BackdropScript)
		balcony_back.name = "BackdropFill"
		balcony_back.z_index = -6
		add_child(balcony_back)
		_refresh_backdrop_width(balcony_back)
		call_deferred("_refresh_backdrop_width", balcony_back)
		return
	# İkincil bölgesel duvarlar + yataksız Uyanış koridorları (Nöbet, Çanlar, S.'nin Odası).
	if far:
		var far_override := String(ALT_FAR_ROOMS.get(room_id, ""))
		if far_override == "" and AWAKENING_CORRIDOR_ROOMS.has(room_id):
			far_override = "res://assets/backgrounds/decay/far.png"
		if far_override != "":
			var far_tex := load(far_override) as Texture2D
			if far_tex:
				for child in far.get_children():
					if child is Sprite2D:
						(child as Sprite2D).texture = far_tex
	# Bölgeler arasında kullanılan resim, odanın adından farklı olabilir (örneğin Uyanış Geçidi).
	var region := ""
	if front and front.get_child_count() > 0:
		var first := front.get_child(0) as Sprite2D
		if first and first.texture:
			region = first.texture.resource_path.get_base_dir().get_file()
	_place_plane(far, -7, 0.0)
	_place_plane(mid, -5, MID_BASE - 234.0)
	_curate_middle_plane(mid)
	_place_plane(front, -4, FRONT_BASE - float(FRONT_BOTTOM_ROW.get(region, FRONT_BASE)))
	var back := Node2D.new()
	back.set_script(BackdropScript)
	back.name = "BackdropFill"
	back.z_index = -6
	add_child(back)
	_refresh_backdrop_width(back)
	call_deferred("_refresh_backdrop_width", back)


func _place_plane(plane: Parallax2D, depth: int, offset_y: float) -> void:
	if plane == null:
		return
	plane.z_index = depth
	plane.scroll_scale.y = 1.0
	# Yalnız yatay tekrar: üstte/alta başka bir kopya girmez.
	plane.repeat_size.y = 0.0
	for child in plane.get_children():
		if child is Sprite2D:
			(child as Sprite2D).position.y += offset_y


## Bazı bölge PNG'leri tavan/pencere öğelerini taşır; gerçek piksel konumlarına göre hizala.
func _curate_middle_plane(plane: Parallax2D) -> void:
	if plane == null:
		return
	for child in plane.get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		match sprite.texture.resource_path:
			"res://assets/backgrounds/awakening/mid.png":
				# Gotik tavan kemer kaburgaları, zincirler ve üst boşluk sisi; tavana sabitle.
				sprite.position.y = 0.0
				sprite.modulate.a = 0.78
			"res://assets/backgrounds/decay/mid.png":
				# Sarmaşık tavandan sarkar (piksel alanı x=486..593, y=113..235).
				sprite.region_enabled = true
				sprite.region_rect = Rect2(480, 113, 128, 128)
				sprite.position.x += 480
				sprite.position.y = -2
			"res://assets/backgrounds/library/mid.png":
				# Penceresiz raf koridorlarında (far_alt) pencere huzmesi gizlenir; gül pencereli odalarda soğuk gece sisi olur.
				if ALT_FAR_ROOMS.has(room_id):
					sprite.visible = false
				else:
					sprite.modulate = Color(0.46, 0.44, 0.72, 0.22)
			"res://assets/backgrounds/mirrors/mid.png":
				# Havada asılı cam kırıkları sağ yarıda (x=493..587, y=113..235).
				sprite.modulate.a = 0.72
			"res://assets/backgrounds/experiment/mid.png":
				# Tavandan sarkan zincirler sol yarıda (x=30..146, y=51..233); tavana sabitle.
				sprite.position.y = -50.0
				sprite.modulate.a = 0.75


func _backdrop_width() -> float:
	if "bounds" in self and (self.get("bounds") as Rect2).size.x > 64.0:
		return (self.get("bounds") as Rect2).size.x
	return _room_width()


func _refresh_backdrop_width(back: Node) -> void:
	if is_instance_valid(back):
		var balcony := room_id == &"awakening_balcony"
		var shards := String(room_id).begins_with("mirrors") and room_id != &"mirrors_labyrinth"
		back.call("setup", _backdrop_width(), _region_color().lerp(Color.WHITE, 0.55), balcony, shards)



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
	set_process(vis)


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
	# Boyalı pencerenin ışığı aynı düzlemde kalır. Oda merkezinde ikinci bir ışık deseni oluşmaz.
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
