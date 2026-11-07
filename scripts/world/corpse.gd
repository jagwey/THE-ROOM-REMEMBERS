extends AnimatableBody2D
## Fiziksel ceset — Echo + iterek ağırlık bulmacası (mobil: Etkileş).

@export var corpse_id: String = ""
@export var echo_id: StringName = &""
@export var weight: int = 1
@export var usable_for_puzzle: bool = true
@export var push_step: float = 36.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var flower: Sprite2D = $Flower
@onready var interact: Area2D = $InteractArea

var _data: Dictionary = {}
var _echo_done: bool = false
var _pushing: bool = false


func _ready() -> void:
	add_to_group("corpse")
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	## Yürüyerek içinden geçilir; üstüne basılabilir (geçiş asla tıkanmaz).
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs:
		cs.one_way_collision = true
		cs.one_way_collision_margin = 8.0
	if interact:
		interact.collision_layer = 8
		interact.collision_mask = 0
		interact.monitoring = false
		interact.monitorable = true


func setup_from_data(data: Dictionary) -> void:
	_data = data
	corpse_id = String(data.get("id", ""))
	echo_id = StringName(String(data.get("echo_id", "echo_%s" % corpse_id)))
	weight = int(data.get("weight", 1))
	usable_for_puzzle = bool(data.get("usable_for_puzzle", true))
	var pos: Dictionary = data.get("position", {"x": 0, "y": 0})
	global_position = Vector2(float(pos.get("x", 0)), float(pos.get("y", 0)))
	var seen: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	_echo_done = seen.has(String(echo_id))
	if sprite:
		sprite.texture = load("res://assets/props/body_echo.png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.offset = Vector2(0, -20)
	if flower:
		flower.texture = load("res://assets/props/red_flower.png")
		flower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flower.visible = bool(data.get("has_flower", false))
		flower.position = Vector2(10, -8)
	_setup_lantern(bool(data.get("has_flower", false)))


func on_interact(by: Node) -> void:
	if DialogueManager.is_open:
		DialogueManager.advance()
		return
	## Oyunun ilk ceset karşılaşması: Shiren kendi bedenini tanır.
	if not bool(GameState.player_progress_knowledge.get("first_corpse_line_seen", false)):
		GameState.player_progress_knowledge["first_corpse_line_seen"] = true
		DialogueManager.say("Shiren", "Bu... benim kıyafetlerim mi?")
	# İlk etkileşim: Echo (oyuncu bilgisi).
	if not _echo_done:
		_echo_done = true
		var eid := _resolve_echo_id()
		_spawn_ghost()
		await EchoManager.play_echo(eid)
		DialogueManager.say("Sen", "…Ağır. İtebilirim.")
		return
	# Sonraki: cesedi oyuncunun baktığı yöne it (mobil dostu).
	var dir := 1.0
	if by and by.has_method("get_facing"):
		dir = float(by.get_facing())
	elif by:
		dir = signf(by.global_position.x - global_position.x) * -1.0
		if dir == 0.0:
			dir = 1.0
	_push(dir)


func _push(dir: float) -> void:
	if not usable_for_puzzle or _pushing:
		return
	var bounds := RoomManager.get_room_bounds(RoomManager.get_active_room_id())
	if bounds.size.x <= 0.0:
		bounds = Rect2(0, 0, 640, 360)
	var raw_target_x := clampf(global_position.x + dir * push_step, bounds.position.x + 40.0, bounds.end.x - 40.0)
	if absf(raw_target_x - global_position.x) < 0.5:
		DialogueManager.say("Sen", "…Daha ileri gitmiyor.")
		return

	var space := get_world_2d().direct_space_state
	var target_x: float = raw_target_x

	# 1. Yatay Engel Kontrolü (raycast: Duvarlar, Kapılar, Lanet Bariyerleri, Kırılabilir Duvarlar)
	if space != null:
		var ray_start := global_position + Vector2(0, -10.0)
		var ray_end := ray_start + Vector2(dir * (push_step + 14.0), 0.0)
		var q_wall := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1 | 16 | 32)
		q_wall.exclude = [get_rid()]
		var wall_hit: Dictionary = space.intersect_ray(q_wall)
		if not wall_hit.is_empty():
			var hit_pos: Vector2 = wall_hit["position"]
			var stop_x: float = hit_pos.x - dir * 14.0
			if (dir > 0.0 and stop_x <= global_position.x + 2.0) or (dir < 0.0 and stop_x >= global_position.x - 2.0):
				DialogueManager.say("Sen", "…Engelle karşılaştı.")
				return
			target_x = minf(target_x, stop_x) if dir > 0.0 else maxf(target_x, stop_x)

		# 2. Zemin / Çukur Kontrolü (Hedef noktanın altında zemin var mı?)
		var q_floor := PhysicsRayQueryParameters2D.create(
			Vector2(target_x, global_position.y - 4.0),
			Vector2(target_x, global_position.y + 24.0),
			1
		)
		q_floor.exclude = [get_rid()]
		var floor_hit: Dictionary = space.intersect_ray(q_floor)
		if floor_hit.is_empty():
			DialogueManager.say("Sen", "…Uçurumun kenarında durdu.")
			return

	if absf(target_x - global_position.x) < 0.5:
		DialogueManager.say("Sen", "…Daha ileri gitmiyor.")
		return

	_pushing = true
	_spawn_dust(dir)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"corpse_drag")
	var tw := create_tween()
	tw.tween_property(self, "global_position:x", target_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_pushing = false
	_persist_position()


## Ceset kendine özgü yankı oynatır: oda + ölüm nedeni + yaşam sayısı.
## İlk Uyanış cesedi (rift yankısı görülmemişse) 314 kodunu taşıyan yankıyı oynatır.
func _resolve_echo_id() -> StringName:
	var seen: Array = GameState.player_progress_knowledge.get("echoes_seen", [])
	var room := String(_data.get("room", "awakening"))
	if room.begins_with("awakening") and not seen.has("awakening_rift_echo"):
		return &"awakening_rift_echo"
	EchoManager.register_echo(String(echo_id), _build_echo_entry())
	return echo_id


func _build_echo_entry() -> Dictionary:
	var room := String(_data.get("room", "awakening"))
	var reason := String(_data.get("reason", "unknown"))
	var life := int(_data.get("life_index", 0)) + 1
	var place: String = ROOM_LINES.get(room.get_slice("_", 0), "Taş zemin soğuktu.")
	var cause: String = REASON_LINES.get(reason, "Sonra her şey sustu.")
	return {
		"evidence_id": "ev_%s" % corpse_id,
		"lines": [
			["Yankı", "%d. hayat. %s" % [life, place]],
			["Yankı", cause],
			["Yankı", LIFE_LINES[life % LIFE_LINES.size()]],
		],
		"journal": {
			"section": "izler",
			"title": "%d. hayatın sonu" % life,
			"body": "%s %s Bu beden hâlâ orada." % [place, cause],
			"kind": "evidence",
		},
		"memory_code": "",
	}


const ROOM_LINES := {
	"awakening": "Yatağın yanındaydım; saat hâlâ tıkırdıyordu.",
	"decay": "Sarmaşıklar bileklerime dolanmıştı.",
	"library": "Raflar fısıldıyordu; sayfalar adımı biliyordu.",
	"experiment": "Hücrelerin camı buğuluydu, içeride biri ağlıyordu.",
	"mirrors": "Aynadaki ben, benden önce düştü.",
	"core": "Çekirdeğin nabzı göğsümün içindeydi.",
}
const REASON_LINES := {
	"hearts": "Bir darbe daha… ve dizlerim çözüldü.",
	"hazard": "Zemin yalan söyledi. Düştüm.",
	"curse": "Lanet damarlarımdan yükseldi; ben değildim artık.",
	"keeper": "Shilda'nın pençesi… ama gözleri ağlıyordu.",
	"mercy": "Shilda fısıldadı: Uyu ve unut.",
	"cloud": "Kırmızı sis nefesimi aldı.",
	"thorn": "Kan dikeni avucumu deldi. Bilerek dokundum.",
}
const LIFE_LINES := [
	"Biri çiçek bıraktı. Kim olduğunu hatırlamıyorum.",
	"Bu beden benim. Ama ben bu bedende değilim.",
	"Yine unuttum. Oda unutmadı.",
	"Bir ses: Bir dahaki sefere sağa bakma.",
]


func _spawn_ghost() -> void:
	if sprite == null:
		return
	if _replay_trail(_data.get("trail", [])):
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.offset = sprite.offset
	ghost.modulate = Color(0.85, 0.75, 1.0, 0.0)
	ghost.z_index = 4
	add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.55, 0.35)
	tw.parallel().tween_property(ghost, "position:y", -28.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.8)
	tw.tween_callback(ghost.queue_free)


const TRAIL_STEP := 0.1


## Yankı tekrarı: bu bedenin son ~3 saniyesi soluk mor bir Shiren olarak yeniden oynar,
## cesedin üstünde biter ve söner. İz yoksa (eski kayıt) klasik yükselen hayalet.
func _replay_trail(trail: Variant) -> bool:
	if not (trail is Array) or (trail as Array).size() < 4:
		return false
	var frames := load("res://assets/characters/shiren.tres") as SpriteFrames
	if frames == null:
		return false
	var g := AnimatedSprite2D.new()
	g.name = "EchoReplay"
	g.sprite_frames = frames
	g.top_level = true
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.offset = Vector2(0, -44)
	g.z_index = 4
	g.modulate = Color(0.72, 0.6, 1.0, 0.0)
	add_child(g)
	var first: Array = trail[0]
	g.global_position = Vector2(float(first[0]), float(first[1]))
	_apply_trail_sample(g, first)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"echo_playback", -6.0)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.5, 0.25)
	for s in trail:
		if not (s is Array) or (s as Array).size() < 4:
			continue
		tw.tween_callback(_apply_trail_sample.bind(g, s))
		tw.tween_property(g, "global_position", Vector2(float(s[0]), float(s[1])), TRAIL_STEP)
	tw.tween_interval(0.35)
	tw.tween_property(g, "modulate:a", 0.0, 0.6)
	tw.tween_callback(g.queue_free)
	return true


func _apply_trail_sample(g: AnimatedSprite2D, s: Array) -> void:
	if not is_instance_valid(g):
		return
	var anim := StringName(String(s[2]))
	if g.sprite_frames.has_animation(anim) and (g.animation != anim or not g.is_playing()):
		g.play(anim)
	g.flip_h = bool(s[3])


func _spawn_dust(dir: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 0.85
	p.direction = Vector2(-dir, -0.4)
	p.spread = 35.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.62, 0.55, 0.58, 0.7)
	p.position = Vector2(-dir * 10.0, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


## Fener Ceset: çiçekli beden karanlık odalarda etrafı aydınlatır ve gizli sembolleri gösterir.
func _setup_lantern(on: bool) -> void:
	var old := get_node_or_null("LanternLight")
	if old:
		old.queue_free()
	if not on:
		remove_from_group("lantern_corpse")
		return
	add_to_group("lantern_corpse")
	var light := PointLight2D.new()
	light.name = "LanternLight"
	light.texture = make_light_texture()
	light.texture_scale = 1.6
	light.color = Color(1.0, 0.55, 0.6, 1.0)
	light.energy = 1.4
	light.position = Vector2(10, -14)
	add_child(light)
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "energy", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "energy", 1.5, 1.1).set_trans(Tween.TRANS_SINE)


static var _light_tex: Texture2D


static func make_light_texture() -> Texture2D:
	if _light_tex:
		return _light_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_light_tex = t
	return t


func set_anchoring(value: bool, plate_id: StringName) -> void:
	for c in GameState.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == corpse_id:
			if value:
				c["anchoring"] = true
				c["anchor_plate"] = String(plate_id)
			elif String(c.get("anchor_plate", "")) == String(plate_id):
				c["anchoring"] = false
			break


func _persist_position() -> void:
	for c in GameState.world_memory_state["corpses"]:
		if c is Dictionary and String(c.get("id", "")) == corpse_id:
			c["position"] = {"x": global_position.x, "y": global_position.y}
			break
	# Plakayı yenile
	for p in get_tree().get_nodes_in_group("pressure_plate"):
		if p.has_method("_recompute"):
			p._recompute()
	SaveManager.save_game()


func get_weight() -> int:
	return weight if usable_for_puzzle else 0
