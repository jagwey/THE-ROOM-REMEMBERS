extends Area2D
## Büyük gotik kemerli kapı (arka / karanlık açıklık + ışık / ön çerçeve / mühür katmanları).
## Geçiş: etkileşim → kilit kontrolü → içeri yürüme → kararma → hedef oda (hedef kapının önünde doğ)
## → kamera → açılma → kontrol geri. Kilit durumu PuzzleManager'da (dünya hafızası) — ölümde kilitlenmez.

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

const LOCKED_VARIANTS := [
	"Kapı mühürlenmiş.",
	"Bu sembolü daha önce gördüm mü?",
	"Bir şey bu kapıyı içeriden tutuyor.",
]
## Kapının zemine oturduğu yerel y (kapılar y≈268, zemin 288).
const FOOT_Y := 20.0
const WALK_TIME := 0.22
const FADE_OUT := 0.26
const FADE_IN := 0.3

## Aynı anda tek geçiş (çift dokunuş / iki kapı birden).
static var _transitioning: bool = false

var _seal: Sprite2D
var _glow: Sprite2D
var _locked_tries: int = 0
var _last_locked_ms: int = -10000
var _phase: float = 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("room_door")
	_transitioning = false
	_build_visuals()
	var label := Label.new()
	label.name = "DoorLabel"
	## Mobilde sağ alt buton kümesinin üstünde kalsın; sağ kenardaki kapılarda etiket içeri kayar.
	var touch := MobileInputManager.is_touch_ui()
	var right_edge := position.x > 700
	label.position = Vector2((-240.0 if touch else -140.0) if right_edge else -75.0, FOOT_Y - 160.0 - 38.0)
	label.size = Vector2(150, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if (right_edge and touch) else HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var hint := "El: Geç" if touch else "[E] Geç"
	label.text = "%s\n%s" % [get_display_name(), hint]
	label.z_index = 4
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	## Etkileşim alanını da genişlet (paylaşılan şekli kopyalayarak).
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is RectangleShape2D:
		var rect := (cs.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rect.size = Vector2(maxf(rect.size.x, 52.0), maxf(rect.size.y, 72.0))
		cs.shape = rect
	call_deferred("_hide_legacy_door_sprites")


func get_display_name() -> String:
	return door_title if not door_title.is_empty() else String(ROOM_TITLES.get(String(target_room_id), "Geçit"))


## Etkileşim ışığı rengi: kilitli = lanet kırmızısı, açık = normal krem.
func get_glow_kind() -> StringName:
	return &"cursed" if is_locked() else &"normal"


func get_interact_label() -> String:
	return "Mühürlü Kapı" if is_locked() else get_display_name()


func is_locked() -> bool:
	return required_puzzle != &"" and not PuzzleManager.is_solved(required_puzzle)


func _build_visuals() -> void:
	var base_y := FOOT_Y - 80.0 ## 160 px kapının merkezi
	var back := Sprite2D.new()
	back.name = "DoorBack"
	back.texture = load("res://assets/props/gothic_door_back.png")
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.position = Vector2(0, base_y)
	back.z_index = -3
	add_child(back)
	## Karanlığın içinden yükselen soluk kırmızı/mor ışık (ucuz: tek additive sprite).
	_glow = Sprite2D.new()
	_glow.name = "DoorInnerLight"
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.2, 0.32, 0.55))
	grad.set_color(1, Color(0.3, 0.18, 0.4, 0.0))
	gt.gradient = grad
	_glow.texture = gt
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.position = Vector2(0, FOOT_Y - 26.0)
	_glow.scale = Vector2(0.8, 1.2)
	_glow.z_index = -3
	add_child(_glow)
	var frame := Sprite2D.new()
	frame.name = "DoorFrame"
	frame.texture = load("res://assets/props/gothic_door_frame.png")
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.position = Vector2(0, base_y)
	frame.z_index = -2
	add_child(frame)
	_seal = Sprite2D.new()
	_seal.name = "DoorSeal"
	_seal.texture = load("res://assets/props/gothic_door_seal.png")
	_seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seal.position = Vector2(0, base_y + 10.0)
	_seal.z_index = -2
	add_child(_seal)
	_refresh_seal()


func _refresh_seal() -> void:
	if _seal:
		_seal.visible = is_locked()


## Sahnelerde elle konmuş eski küçük kapı görsellerini gizle (çift kapı görünmesin).
func _hide_legacy_door_sprites() -> void:
	var p := get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c is Sprite2D and (c as Sprite2D).texture:
			var path := String((c as Sprite2D).texture.resource_path)
			if (path.ends_with("door_open.png") or path.ends_with("door_closed.png")) \
					and absf((c as Sprite2D).position.x - position.x) < 48.0:
				(c as Sprite2D).visible = false


func _process(delta: float) -> void:
	_phase += delta * 1.7
	if _glow:
		_glow.modulate.a = 0.75 + 0.25 * sin(_phase)
	if _seal:
		var locked := is_locked()
		if _seal.visible != locked:
			_seal.visible = locked
		if locked:
			_seal.modulate = Color(1, 1, 1, 0.8 + 0.2 * sin(_phase * 1.3))


func on_interact(by: Node) -> void:
	if not is_visible_in_tree() or _transitioning or DeathManager.is_dying:
		return
	if is_locked():
		var now := Time.get_ticks_msec()
		if now - _last_locked_ms < 700:
			return ## Tekrar tetiklenme koruması.
		_last_locked_ms = now
		var idx := _locked_tries % 4
		_locked_tries += 1
		var msg: String = locked_message if idx == 0 else String(LOCKED_VARIANTS[idx - 1])
		AudioManager.play_sfx(&"seal_key", -8.0, 0.55)
		_shake_seal()
		DialogueManager.say("Shiren", msg)
		return
	if not RoomManager.has_room(target_room_id):
		push_warning("room_transition: unknown room %s" % String(target_room_id))
		return
	_travel(by)


func _shake_seal() -> void:
	if _seal == null:
		return
	var x0 := 0.0
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_seal, "position:x", x0 + (2.0 if i % 2 == 0 else -2.0), 0.04)
	tw.tween_property(_seal, "position:x", x0, 0.04)


func _travel(by: Node) -> void:
	_transitioning = true
	var tree := get_tree()
	UiGate.set_cutscene(true)
	MobileInputManager.clear_held_inputs()
	AudioManager.play_sfx(&"door_open", -4.0)
	var player := by as Node2D
	if player == null or not player.is_in_group("player"):
		player = tree.get_first_node_in_group("player") as Node2D
	var fade := _make_fade(tree)
	var rect := fade.get_child(0) as ColorRect
	## Ağaç tween'i: oda değişince bu kapı devre dışı kalsa da animasyon sürer.
	var tw := tree.create_tween()
	if player:
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		var walk := absf(global_position.x - player.global_position.x) > 2.0
		if sprite and walk:
			sprite.flip_h = global_position.x < player.global_position.x
		if walk and "scripted_walk" in player:
			player.set("scripted_walk", true)
		tw.tween_property(player, "global_position:x", global_position.x, WALK_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_end_walk.bind(player))
		tw.tween_property(player, "modulate", Color(0.35, 0.28, 0.42, 1.0), FADE_OUT)
		tw.parallel().tween_property(rect, "color:a", 1.0, FADE_OUT)
	else:
		tw.tween_property(rect, "color:a", 1.0, FADE_OUT)
	await tw.finished
	RoomManager.enter_room(target_room_id, target_spawn_id)
	if is_instance_valid(player):
		player.modulate = Color.WHITE
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
	await tree.process_frame
	var tw2 := tree.create_tween()
	tw2.tween_property(rect, "color:a", 0.0, FADE_IN)
	await tw2.finished
	fade.queue_free()
	UiGate.set_cutscene(false)
	MobileInputManager.clear_held_inputs()
	_transitioning = false


static func _end_walk(player: Node) -> void:
	if is_instance_valid(player) and "scripted_walk" in player:
		player.set("scripted_walk", false)


static func is_transitioning() -> bool:
	return _transitioning


func _make_fade(tree: SceneTree) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "DoorFade"
	layer.layer = 90
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.04, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(r)
	tree.root.add_child(layer)
	return layer
