extends Area2D
## Visible, explicitly activated doorway; puzzle state is checked before travel.

@export var target_room_id: StringName = &"awakening_passage"
@export var target_spawn_id: StringName = &"default"
@export var required_puzzle: StringName = &""
@export var locked_message: String = "Önce bu odanın hatırasını tamamlamalıyım."
@export var door_title: String = ""

const ROOM_TITLES := {
	"awakening": "Uyanış", "awakening_passage": "Kırık Geçit",
	"awakening_seal": "Mühür Eşiği", "decay_vines": "Sarmaşık Yolu",
	"decay_weight": "Ağırlık Salonu", "decay_garden": "Solmuş Bahçe",
	"library_hall": "Hafıza Kütüphanesi", "library_witness": "Üç Tanık",
	"library_page": "Unutulmuş Sayfa", "experiment_cells": "Gözlem Hücreleri",
	"experiment_circuit": "Yankı Devresi", "experiment_authority": "Yetki Masası",
	"mirrors_reverse": "Ayna Geçidi", "mirrors_dual": "İki Yankı",
	"mirrors_unbroken": "Kırılmayan Ayna", "core_threshold": "Son Eşik",
	"core_seal_chamber": "Mühür Odası", "core": "Çekirdek",
	"awakening_balcony": "Gözlem Balkonu", "awakening_crypt": "İlk Bedenler Mahzeni",
	"decay_catacombs": "Kemik Mahzeni", "decay_shilda_wall": "Çatlak Duvar",
	"library_upper_stacks": "Üst Raflar", "library_forbidden_wing": "Yasak Kanat",
	"experiment_quarantine": "Karantina", "experiment_core_conduit": "Enerji Kanalı",
	"mirrors_labyrinth": "Yansıma Labirenti", "mirrors_shrine": "Ayna Tapınağı",
	"core_memory_vault": "Hafıza Kasası", "core_bloom_garden": "Çiçek Bahçesi",
}

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("room_door")
	var icon := Sprite2D.new()
	icon.texture = load("res://assets/props/door_open.png")
	## Geçitler uzaktan seçilsin: büyük ikon, ayağa oturur.
	icon.position = Vector2(0, -34)
	icon.scale = Vector2(1.1, 1.1)
	icon.z_index = 3
	icon.modulate = Color(0.85, 0.8, 0.9, 0.9)
	add_child(icon)
	var label := Label.new()
	## Mobilde sağ alt buton kümesinin üstünde kalsın; sağ kenardaki kapılarda etiket içeri kayar.
	var touch := MobileInputManager.is_touch_ui()
	var right_edge := position.x > 700
	label.position = Vector2((-240.0 if touch else -140.0) if right_edge else -10.0, -140.0 if touch else -108.0)
	label.size = Vector2(150, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if (right_edge and touch) else HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var hint := "El: Geç" if touch else "[E] Geç"
	label.text = "%s\n%s" % [(door_title if not door_title.is_empty() else ROOM_TITLES.get(String(target_room_id), "Geçit")), hint]
	label.z_index = 4
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	## Etkileşim alanını da genişlet (paylaşılan şekli kopyalayarak).
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		var rect := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rect.size = Vector2(maxf(rect.size.x, 52.0), maxf(rect.size.y, 72.0))
		cs.shape = rect

func on_interact(_by: Node) -> void:
	if not is_visible_in_tree():
		return
	if required_puzzle != &"" and not PuzzleManager.is_solved(required_puzzle):
		DialogueManager.say("Shiren", locked_message)
		return
	if not RoomManager.has_room(target_room_id):
		push_warning("room_transition: unknown room %s" % String(target_room_id))
		return
	# Leave physics query callbacks before changing the entire room's collision state.
	RoomManager.call_deferred("enter_room", target_room_id, target_spawn_id)
