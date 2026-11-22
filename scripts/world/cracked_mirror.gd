extends Area2D
## Çatlak Ayna (Cracked Mirror) — Birleşik Hızlı Seyahat Çapası (Fast-Travel Anchor — F28)
## Keşfedilen bölgesel aynalar world_memory_state["unlocked_mirrors"] içine kaydedilir.
## İlk etkileşimde ayna keşfedilir; sonraki etkileşimlerde birleşik Günlük -> Harita & Mühürler
## sekmesini doğrudan açarak ziyaret edilmiş tüm odalara hızlı seyahat sağlar.

@export var mirror_id: StringName = &""
@export var display_name: String = ""

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
		display_name = RoomManager.ROOM_TITLES_TR.get(String(mirror_id), String(mirror_id))

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


func on_interact(_by: Node) -> void:
	if DialogueManager.is_open:
		DialogueManager.advance()
		return

	if not GameState.world_memory_state.has("unlocked_mirrors"):
		GameState.world_memory_state["unlocked_mirrors"] = []

	var unlocked: Array = GameState.world_memory_state["unlocked_mirrors"]
	var m_id := String(mirror_id)

	# İlk keşif: aynayı kaydet ve birleşik harita bağını fısılda.
	if not unlocked.has(m_id):
		unlocked.append(m_id)
		GameState.world_memory_state["unlocked_mirrors"] = unlocked
		SaveManager.save_game()
		var am := get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx(&"discovery")
		MobileInputManager.vibrate(20)
		DialogueManager.whisper("Noroi", "Çatlak yüzey titredi. Gördüğüm her odaya haritadan geçebilirim.")
		return

	_open_unified_map()


func _open_unified_map() -> void:
	var journal := get_tree().get_first_node_in_group("journal_ui")
	if journal == null:
		DialogueManager.whisper("Noroi", "Çatlak yüzeyde yalnız kendi yansımam duruyor.")
		return

	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"echo_playback", -6.0)
	MobileInputManager.vibrate(15)
	MobileInputManager.clear_held_inputs()

	if journal.has_method("open_journal"):
		journal.open_journal()
	if journal.visible and journal.has_method("_show_section"):
		journal._show_section("harita")


func _resolve_room_id() -> StringName:
	var p: Node = get_parent()
	while p:
		if "room_id" in p:
			return p.get("room_id")
		p = p.get_parent()
	return RoomManager.get_active_room_id()
