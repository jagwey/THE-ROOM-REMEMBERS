extends "res://scripts/world/room_root.gd"
## Veri-güdümlü oda kurucu (v1.0 genişleme odaları). Sahnede yalnız içerik düğümleri bulunur;
## zemin, duvarlar, parallax, platformlar, kapılar, spawnlar ve karanlık mod burada üretilir.
## Spawn noktaları: kapılardan "from_<hedef>" adıyla otomatik + default.

const TILE := preload("res://assets/tiles/tile_00.png")
const DOOR_SCRIPT := preload("res://scripts/world/room_transition.gd")
const DRESS := preload("res://scripts/world/platform_dress.gd")

@export var room_width: float = 960.0
@export var bg_region: String = "awakening"
## Her öğe: Vector3(x, y_top, width) — tek yönlü platform.
@export var platforms: PackedVector3Array = PackedVector3Array()
## Zemindeki boşluklar: Vector2(x_start, x_end) — düşen ölür (hazard).
@export var floor_gaps: PackedVector2Array = PackedVector2Array()
## Her öğe: {"x": float, "y": float(ops.), "to": String, "spawn": String, "req": String, "msg": String, "title"?, "mark"?, "label_dy"?}
@export var doors: Array = []
@export var dark: bool = false
@export var dark_color: Color = Color(0.16, 0.13, 0.2, 1.0)
@export var default_spawn: Vector2 = Vector2(80, 288)
## Görünmez platformlar: yalnız tavandaki aynada (mirror_line etrafında simetrik) yansımaları görünür.
@export var invisible_platforms: PackedVector3Array = PackedVector3Array()
## Aynada görünen ama basılmayan yalan basamaklar (Vector3 x, y_top, width).
@export var false_reflections: PackedVector3Array = PackedVector3Array()
@export var mirror_line: float = 160.0

var _glow: PointLight2D


func _ready() -> void:
	bounds = Rect2(0, 0, room_width, 360)
	if atmosphere_bg == "":
		atmosphere_bg = "res://assets/backgrounds/%s" % bg_region
	_build_parallax()
	_build_floor()
	_build_platforms()
	_build_invisible_platforms()
	_build_walls()
	_build_spawns_and_doors()
	if get_node_or_null("Corpse") == null:
		var corpse_root := Node2D.new()
		corpse_root.name = "Corpse"
		corpse_root.add_to_group("corpses_root")
		add_child(corpse_root)
	if dark:
		add_to_group("dark_room")
		var cm := CanvasModulate.new()
		cm.color = dark_color
		add_child(cm)
		_glow = PointLight2D.new()
		_glow.texture = load("res://scripts/world/corpse.gd").make_light_texture()
		_glow.texture_scale = 0.7
		_glow.energy = 0.9
		_glow.color = Color(0.85, 0.8, 1.0, 1.0)
		add_child(_glow)
	super._ready()


func _process(_delta: float) -> void:
	if _glow and visible:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			_glow.global_position = p.global_position + Vector2(0, -24)


func _build_parallax() -> void:
	var layers := [["ParallaxFar", "far", 0.15], ["ParallaxMid", "mid", 0.45], ["ParallaxFront", "front", 1.0]]
	for l in layers:
		if get_node_or_null(String(l[0])):
			continue
		var px := Parallax2D.new()
		px.name = String(l[0])
		px.repeat_size = Vector2(640, 0)
		px.repeat_times = int(ceil(room_width / 640.0)) + 2
		px.scroll_scale = Vector2(float(l[2]), float(l[2]))
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/backgrounds/%s/%s.png" % [bg_region, String(l[1])])
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		px.add_child(spr)
		add_child(px)
		move_child(px, 0)


func _floor_segments() -> Array:
	var segs: Array = [Vector2(0, room_width)]
	for g in floor_gaps:
		var next: Array = []
		for s in segs:
			if g.y <= s.x or g.x >= s.y:
				next.append(s)
				continue
			if g.x > s.x:
				next.append(Vector2(s.x, g.x))
			if g.y < s.y:
				next.append(Vector2(g.y, s.y))
		segs = next
	return segs


func _build_floor() -> void:
	var terrain := Node2D.new()
	terrain.name = "WalkableTerrain"
	terrain.z_index = 2
	add_child(terrain)
	var i := 0
	for seg in _floor_segments():
		var w: float = seg.y - seg.x
		if w <= 1.0:
			continue
		var body := StaticBody2D.new()
		body.name = "Floor%d" % i
		body.collision_layer = 1
		body.position = Vector2(seg.x + w * 0.5, 312)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w + (40.0 if i == 0 else 0.0), 48)
		cs.shape = rect
		body.add_child(cs)
		add_child(body)
		terrain.add_child(_tile_strip(Vector2(seg.x, 288), w))
		var found := Polygon2D.new()
		found.polygon = PackedVector2Array([Vector2(seg.x, 320), Vector2(seg.y, 320), Vector2(seg.y, 360), Vector2(seg.x, 360)])
		found.color = Color(0.08, 0.06, 0.1, 1)
		terrain.add_child(found)
		i += 1
	## Boşluklar: dibe düşen ölür.
	for g in floor_gaps:
		var pit := Area2D.new()
		pit.name = "Pit%d" % int(g.x)
		pit.add_to_group("pit")
		pit.collision_layer = 0
		pit.collision_mask = 2
		pit.position = Vector2((g.x + g.y) * 0.5, 352)
		var cs2 := CollisionShape2D.new()
		var r2 := RectangleShape2D.new()
		r2.size = Vector2(g.y - g.x, 24)
		cs2.shape = r2
		pit.add_child(cs2)
		pit.body_entered.connect(func(b): if b.is_in_group("player") and not DeathManager.is_dying: DeathManager.request_death(&"hazard"))
		add_child(pit)
		var abyss := Polygon2D.new()
		abyss.polygon = PackedVector2Array([Vector2(g.x, 300), Vector2(g.y, 300), Vector2(g.y, 360), Vector2(g.x, 360)])
		abyss.color = Color(0.05, 0.03, 0.07, 1)
		abyss.z_index = 1
		add_child(abyss)


func _tile_strip(at: Vector2, w: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TILE
	s.centered = false
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, w, 32)
	return s


func _build_platforms() -> void:
	var i := 0
	for p in platforms:
		var body := StaticBody2D.new()
		body.name = "Platform%d" % i
		body.collision_layer = 1
		body.position = Vector2(p.x + p.z * 0.5, p.y + 6)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.z, 12)
		cs.shape = rect
		cs.one_way_collision = true
		body.add_child(cs)
		var strip := _tile_strip(Vector2(-p.z * 0.5, -6), p.z)
		strip.region_rect = Rect2(0, 0, p.z, 14)
		strip.z_index = 2
		body.add_child(strip)
		add_child(body)
		_add_dress("PlatformDress%d" % i, p.x, p.y, p.z, false, false)
		i += 1


func _build_invisible_platforms() -> void:
	if invisible_platforms.is_empty() and false_reflections.is_empty():
		return
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(0, 20), Vector2(room_width, 20), Vector2(room_width, mirror_line - 6), Vector2(0, mirror_line - 6)])
	band.color = Color(0.55, 0.7, 0.85, 0.16)
	band.z_index = 1
	add_child(band)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(0, mirror_line - 6), Vector2(room_width, mirror_line - 6)])
	edge.width = 2.0
	edge.default_color = Color(0.8, 0.9, 1.0, 0.5)
	edge.z_index = 1
	add_child(edge)
	var i := 0
	for p in invisible_platforms:
		var body := StaticBody2D.new()
		body.name = "Hidden%d" % i
		body.collision_layer = 1
		body.position = Vector2(p.x + p.z * 0.5, p.y + 6)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(p.z, 12)
		cs.shape = rect
		cs.one_way_collision = true
		body.add_child(cs)
		add_child(body)
		## Yansıma: aynanın içinde, ters yönde.
		var refl := _tile_strip(Vector2(p.x, 2.0 * mirror_line - p.y - 14.0), p.z)
		refl.region_rect = Rect2(0, 0, p.z, 14)
		refl.flip_v = true
		refl.modulate = Color(0.75, 0.9, 1.0, 0.85)
		refl.z_index = 2
		add_child(refl)
		_add_dress("MirrorDress%d" % i, p.x, 2.0 * mirror_line - p.y - 14.0, p.z, true, false)
		i += 1
	var f := 0
	for p in false_reflections:
		var lie := _tile_strip(Vector2(p.x, 2.0 * mirror_line - p.y - 14.0), p.z)
		lie.name = "FalseReflection%d" % f
		lie.region_rect = Rect2(0, 0, p.z, 14)
		lie.flip_v = true
		## Soluk kırmızı: telefondan mavi gerçek taşlardan ayrılır.
		lie.modulate = Color(1.0, 0.45, 0.42, 0.42)
		lie.z_index = 2
		add_child(lie)
		_add_dress("LieDress%d" % f, p.x, 2.0 * mirror_line - p.y - 14.0, p.z, true, true)
		f += 1


func _add_dress(node_name: String, x: float, y: float, w: float, as_reflection: bool, is_lie: bool) -> void:
	var dress := Node2D.new()
	dress.name = node_name
	dress.set_script(DRESS)
	dress.z_index = 1
	add_child(dress)
	dress.call("configure", x, y, w, room_width, floor_gaps, as_reflection, is_lie, mirror_line)


func _build_walls() -> void:
	for side in [[-16.0, "LeftWall"], [room_width + 16.0, "RightWall"]]:
		if get_node_or_null(String(side[1])):
			continue
		var body := StaticBody2D.new()
		body.name = String(side[1])
		body.collision_layer = 1
		body.position = Vector2(float(side[0]), 180)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 400)
		cs.shape = rect
		body.add_child(cs)
		add_child(body)


func _build_spawns_and_doors() -> void:
	var spawns := get_node_or_null("Spawns") as Node2D
	if spawns == null:
		spawns = Node2D.new()
		spawns.name = "Spawns"
		add_child(spawns)
	if spawns.get_node_or_null("default") == null:
		var d := Marker2D.new()
		d.name = "default"
		d.position = default_spawn
		spawns.add_child(d)
	var interactive := get_node_or_null("Interactive") as Node2D
	if interactive == null:
		interactive = Node2D.new()
		interactive.name = "Interactive"
		add_child(interactive)
	for d in doors:
		if not (d is Dictionary):
			continue
		var x := float(d.get("x", 40.0))
		var y := float(d.get("y", 268.0))
		var target := String(d.get("to", ""))
		var door := Area2D.new()
		door.name = "Door_%s" % target
		door.set_script(DOOR_SCRIPT)
		door.position = Vector2(x, y)
		door.set("target_room_id", StringName(target))
		door.set("target_spawn_id", StringName(String(d.get("spawn", "from_%s" % String(room_id)))))
		if String(d.get("req", "")) != "":
			door.set("required_puzzle", StringName(String(d.get("req"))))
		if String(d.get("msg", "")) != "":
			door.set("locked_message", String(d.get("msg")))
		if String(d.get("title", "")) != "":
			door.set("door_title", String(d.get("title")))
		if d.has("label_dy"):
			door.set("label_dy", float(d.get("label_dy")))
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 96)
		cs.shape = rect
		door.add_child(cs)
		interactive.add_child(door)
		if bool(d.get("mark", false)):
			DOOR_SCRIPT.add_door_mark(door)
		## Bu kapıdan gelene spawn: kapının biraz içi.
		var sname := "from_%s" % target
		if spawns.get_node_or_null(sname) == null:
			var m := Marker2D.new()
			m.name = sname
			var inward := 48.0 if x < room_width * 0.5 else -48.0
			m.position = Vector2(clampf(x + inward, 48.0, room_width - 48.0), 288.0)
			spawns.add_child(m)
