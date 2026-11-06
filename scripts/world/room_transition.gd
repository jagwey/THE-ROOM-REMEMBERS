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
}

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("room_door")
	var icon := Sprite2D.new()
	icon.texture = load("res://assets/props/door_open.png")
	icon.position = Vector2(0, -20)
	icon.scale = Vector2(0.7, 0.7)
	icon.z_index = 3
	icon.modulate = Color(0.85, 0.8, 0.9, 0.9)
	add_child(icon)
	var label := Label.new()
	label.position = Vector2(-140 if position.x > 700 else -10, -86)
	label.size = Vector2(150, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var hint := "El: Geç" if OS.has_feature("mobile") else "[E] Geç"
	label.text = "%s\n%s" % [(door_title if not door_title.is_empty() else ROOM_TITLES.get(String(target_room_id), "Geçit")), hint]
	label.z_index = 4
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

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
