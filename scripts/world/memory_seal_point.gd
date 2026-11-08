extends Area2D
## Hafıza Mührü: kayıt noktası + mühürler arası geçiş. Prosedürel çizim (kaide, kırık halka, kristal).
## Etkileşim: SaveManager.commit_save(&"memory_seal", spawn, oda). Tehlikede (ölüm/diyalog/yakın düşman) tepki vermez.

const ENEMY_RANGE := 120.0
const SEAL_GROUP := &"memory_seal_point"
const TRAVEL_LAYER := 30

@export var room_id: StringName = &""

var _t: float = 0.0
var _glow: float = 0.0
var _travel_layer: CanvasLayer = null


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(SEAL_GROUP)
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 56)
		cs.shape = rect
		cs.position = Vector2(0, -26)
		add_child(cs)
	if room_id == &"":
		room_id = RoomManager.get_active_room_id()


func get_interact_label() -> String:
	return "Hafıza Mührü"


func get_glow_kind() -> StringName:
	return &"cursed"


func _process(delta: float) -> void:
	_t += delta
	_glow = maxf(0.0, _glow - delta * 0.8)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	var stone := Color(0.16, 0.13, 0.18)
	var edge := Color(0.34, 0.28, 0.36)
	# Kaide.
	draw_rect(Rect2(-18, -8, 36, 8), stone)
	draw_rect(Rect2(-18, -8, 36, 2), edge)
	draw_rect(Rect2(-12, -20, 24, 12), stone)
	draw_rect(Rect2(-12, -20, 24, 2), edge)
	# Kırık halka (üstte açık yay).
	var c := Vector2(0, -38)
	var ring := Color(0.78, 0.7, 0.76, 0.55 + 0.25 * pulse + _glow * 0.2)
	draw_arc(c, 12.0, deg_to_rad(-60), deg_to_rad(235), 20, ring, 2.0)
	draw_arc(c, 12.0, deg_to_rad(255), deg_to_rad(300), 6, ring, 2.0)
	# Kırmızı-beyaz kristal.
	var k := 0.55 + 0.45 * pulse + _glow
	var red := Color(0.85, 0.16, 0.24, minf(1.0, 0.7 + 0.3 * k))
	var white := Color(1.0, 0.9, 0.92, minf(1.0, 0.6 + 0.4 * k))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 0), c + Vector2(0, 9), c + Vector2(-6, 0)]), red)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 0), c + Vector2(0, 0)]), white)
	# Hale.
	var halo := Color(1.0, 0.3, 0.38, 0.10 + 0.10 * k)
	draw_circle(c, 16.0 + 6.0 * k, halo)


func _is_danger() -> bool:
	if DeathManager.is_dying or DialogueManager.is_open:
		return true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		var en := e as Node2D
		if en and is_instance_valid(en) and en.is_visible_in_tree() \
				and en.global_position.distance_to(player.global_position) <= ENEMY_RANGE:
			return true
	return false


func _spawn_position() -> Vector2:
	## Kayıt konumu = mührün zemindeki konumu (seal_<oda> işaretçisiyle aynı nokta).
	return global_position


func on_interact(_by: Node = null) -> void:
	if is_instance_valid(_travel_layer):
		return
	if _is_danger():
		DialogueManager.say("Noroi", "Tehlike varken mühür tepki vermiyor.")
		return
	var was_known := GameState.discovered_seals.has(room_id)
	GameState.discover_seal(room_id)
	var ok := SaveManager.commit_save(&"memory_seal", _spawn_position(), room_id)
	_glow = 1.0
	AudioManager.play_sfx(&"seal_open")
	if not ok:
		return
	var SealBanner := load("res://scripts/ui/seal_banner.gd")
	SealBanner.show_banner("HAFIZA MÜHÜRLENDİ", "Kayıt noktası etkinleştirildi.")
	if was_known and _other_seals().size() > 0:
		_open_travel()


func _other_seals() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in GameState.discovered_seals:
		if id != room_id:
			out.append(id)
	return out


func _open_travel() -> void:
	_travel_layer = CanvasLayer.new()
	_travel_layer.layer = TRAVEL_LAYER
	get_tree().current_scene.add_child(_travel_layer)
	var rows := _other_seals()
	var modal := GothicModalPanel.new()
	modal.setup("Mühürler arası geçiş", Vector2(460, 150.0 + 46.0 * rows.size()))
	_travel_layer.add_child(modal)
	modal.on_close = _close_travel
	modal.add_label("Etkinleştirdiğin bir mühre geç.", UiTheme.BODY)
	for id in rows:
		var title := RoomManager.get_room_number_and_title(id)
		var b := modal.add_button(title, _travel_to.bind(id))
		b.custom_minimum_size = Vector2(0, 38)
	modal.add_button("Kapat", _close_travel)
	UiGate.set_story(true)


func _close_travel() -> void:
	if is_instance_valid(_travel_layer):
		_travel_layer.queue_free()
	_travel_layer = null
	UiGate.set_story(false)


func _travel_to(target: StringName) -> void:
	_close_travel()
	RoomManager.enter_room(target, StringName("seal_%s" % String(target)))
