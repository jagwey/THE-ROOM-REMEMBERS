extends Area2D
## Çatlak Ayna (Cracked Mirror) — Hızlı Seyahat (Fast-Travel Anchor — F28)
## Keşfedilen bölgesel aynalar world_memory_state["unlocked_mirrors"] içine kaydedilir.
## Oyuncu etkileşime geçtiğinde açık aynalar arasında hızlı geçiş (RoomManager.enter_room) yapılmasını sağlar.

const MIRROR_NAMES := {
	"awakening_balcony": "Uyanış Balkonu",
	"awakening": "Uyanış Odası",
	"decay_garden": "Çürüme Bahçesi",
	"library_hall": "Hafıza Kütüphanesi",
	"experiment_cells": "Deney Hücreleri",
	"mirrors_reverse": "Aynalar Salonu",
}

@export var mirror_id: StringName = &""
@export var display_name: String = ""

var _panel: GothicModalPanel
var _sprite: Sprite2D
var _shimmer: Sprite2D


func _ready() -> void:
	add_to_group("cracked_mirror")
	collision_layer = 8 ## LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true

	if mirror_id == &"":
		mirror_id = _resolve_room_id()

	if display_name == "":
		display_name = MIRROR_NAMES.get(String(mirror_id), String(mirror_id))

	_setup_visuals()


func _setup_visuals() -> void:
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 48)
		shape.shape = rect
		shape.position = Vector2(0, -24)
		add_child(shape)

	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.texture = load("res://assets/props/crystal.png")
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.position = Vector2(0, -24)
		_sprite.scale = Vector2(1.2, 1.4)
		_sprite.modulate = Color(0.85, 0.8, 1.0, 0.9)
		add_child(_sprite)

	_shimmer = get_node_or_null("Shimmer") as Sprite2D
	if _shimmer == null:
		_shimmer = Sprite2D.new()
		_shimmer.name = "Shimmer"
		_shimmer.texture = load("res://assets/props/halo.png")
		_shimmer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shimmer.position = Vector2(0, -24)
		_shimmer.scale = Vector2(0.6, 0.8)
		_shimmer.modulate = Color(0.7, 0.5, 1.0, 0.4)
		add_child(_shimmer)

	if _shimmer:
		var tw := _shimmer.create_tween().set_loops()
		tw.tween_property(_shimmer, "modulate:a", 0.2, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_shimmer, "modulate:a", 0.6, 1.2).set_trans(Tween.TRANS_SINE)


func on_interact(by: Node) -> void:
	if DialogueManager.is_open:
		DialogueManager.advance()
		return

	if not GameState.world_memory_state.has("unlocked_mirrors"):
		GameState.world_memory_state["unlocked_mirrors"] = []

	var unlocked: Array = GameState.world_memory_state["unlocked_mirrors"]
	var m_id := String(mirror_id)

	# İlk keşif: aynayı aç ve fısılda
	if not unlocked.has(m_id):
		unlocked.append(m_id)
		GameState.world_memory_state["unlocked_mirrors"] = unlocked
		SaveManager.save_game()
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx(&"discovery")
		DialogueManager.whisper("Noroi", "Ayna çatlağı derinleşti… Yansıma diğer odalara bağlandı.")
		return

	# Diğer açık aynaları topla
	var destinations: Array = []
	for m in unlocked:
		if String(m) != m_id:
			destinations.append(String(m))

	if destinations.is_empty():
		DialogueManager.whisper("Noroi", "Ayna çatlak ve sessiz. Başka bir odadaki aynayı henüz uyandırmadım.")
		return

	_open_travel_modal(destinations)


func _open_travel_modal(destinations: Array) -> void:
	if _panel == null:
		_panel = GothicModalPanel.new()
		_panel.setup("Çatlak Ayna — Hızlı Seyahat", Vector2(360, 220))
		add_child(_panel)
		# UiGate kilidi görünürlüğe bağlı: düğme, Esc veya başka yoldan kapanınca bırakılır.
		_panel.visibility_changed.connect(func(): UiGate.set_story(_panel.visible))

	# Eski düğmeleri temizle
	for child in _panel.body.get_children():
		child.queue_free()

	var desc := _panel.add_label("Hangi yansımanın içine adım atacaksın?", UiTheme.HINT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for dest in destinations:
		var dest_str := String(dest)
		var dest_name: String = MIRROR_NAMES.get(dest_str, dest_str)
		_panel.add_button(dest_name, func():
			_panel.hide()
			_travel_to(dest_str)
		)

	_panel.add_button("Vazgeç", func():
		_panel.hide()
	)

	_panel.show()
	MobileInputManager.clear_held_inputs()


func _travel_to(target_room: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"echo_playback")
	MobileInputManager.vibrate(25)

	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.2)

	# Oyuncuyu hedef odaya taşı
	RoomManager.enter_room(StringName(target_room), &"from_mirror")
	SaveManager.save_game()


func _resolve_room_id() -> StringName:
	var p: Node = get_parent()
	while p:
		if "room_id" in p:
			return p.get("room_id")
		p = p.get_parent()
	return RoomManager.get_active_room_id()
