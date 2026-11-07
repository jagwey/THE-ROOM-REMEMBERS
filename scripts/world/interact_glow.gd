extends Sprite2D
## Etkileşilebilir nesnelerin arkasında nabız gibi atan hale. Renk türe göre:
## normal = krem, hafıza = lila/mavi, lanetli = kırmızı. Yalnız oyuncunun GERÇEK etkileşim hedefi
## (en yakın, menzil içi) parlar ve üstünde kısa isim etiketi çıkar. Bulmacası çözülmüş nesne söner.
## RoomManager tüm `on_interact` düğümlerine otomatik ekler. Tek ortak sistem: nesneler isterse
## `get_glow_kind()` / `get_interact_label()` / `can_interact()` sağlar; yoksa betik adından çıkarılır.

const NODE_NAME := "InteractGlow"
const LABEL_NAME := "InteractNameLabel"
const COLORS := {
	&"normal": Color(1.0, 0.82, 0.5),
	&"memory": Color(0.66, 0.62, 1.0),
	&"cursed": Color(1.0, 0.24, 0.3),
}
const KIND_BY_SCRIPT := {
	"echo_altar.gd": &"memory", "echo_interactable.gd": &"memory", "echo_point.gd": &"memory",
	"echo_switch.gd": &"memory", "trace_marker.gd": &"memory", "awakening_seal_echo_recall.gd": &"memory",
	"mirror_relay.gd": &"memory", "lore_point.gd": &"memory", "evidence_card.gd": &"memory",
	"story_beat.gd": &"memory", "pocket_watch_inspect.gd": &"memory",
	"blood_thorn.gd": &"cursed", "code_seal_base.gd": &"cursed", "core_crystal.gd": &"cursed",
	"core_portal.gd": &"cursed", "flower_inspect.gd": &"cursed", "decay_flower_evidence.gd": &"cursed",
}
const LABEL_BY_SCRIPT := {
	"decay_flower_evidence.gd": "Kırmızı Çiçek", "flower_inspect.gd": "Kırmızı Çiçek",
	"pocket_watch_inspect.gd": "Cep Saati", "trace_marker.gd": "Hatıra İzi",
	"echo_point.gd": "Yankı", "echo_interactable.gd": "Yankı", "awakening_seal_echo_recall.gd": "Yankı Nişi",
	"echo_altar.gd": "Yankı Sunağı", "echo_switch.gd": "Yankı Anahtarı", "code_seal_base.gd": "Mühür",
	"blood_thorn.gd": "Kan Dikeni", "core_crystal.gd": "Çekirdek Kristali", "core_portal.gd": "Geçit",
	"core_choice_pad.gd": "Seçim Zemini", "mirror_relay.gd": "Ayna", "reset_lever.gd": "Kol",
	"vine_puzzle_lever.gd": "Kol", "vine_interact.gd": "Sarmaşık", "archive_door.gd": "Arşiv Kapısı",
	"story_beat.gd": "Hatıra", "keeper_controller.gd": "Shilda", "shilda_name_beat.gd": "Shilda",
	"shilda_garden_trust.gd": "Shilda", "evidence_card.gd": "Kayıt", "ability_pickup.gd": "Sunak",
}
const LORE_LABEL_BY_TEXTURE := {
	"photograph": "Eski Fotoğraf", "cassette": "Kaset", "red_flower": "Kırmızı Çiçek", "flowers": "Kırmızı Çiçek",
	"books": "Eski Günlük", "bookshelf": "Eski Günlük", "mirror": "Ayna", "mirror_shards": "Ayna Kırığı",
	"candles": "Mumlar", "candlestick": "Şamdan", "key": "Anahtar", "seal": "Mühür", "curse": "Lanet İzi",
	"body_echo": "Hatıra İzi", "core_crystal": "Çekirdek Kristali",
}

var _phase: float = 0.0
var _boost: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _color: Color = COLORS[&"normal"]
var _label: Label
var _tick: float = 0.0
var _is_target: bool = false


## Glow eklenmeli mi? Bedenler (gardiyan, ceset, itilebilir taş) ve NPC'ler hariç.
static func wants_glow(n: Node) -> bool:
	if not (n is Node2D) or not n.has_method("on_interact"):
		return false
	if n is CharacterBody2D or n is AnimatableBody2D or n is RigidBody2D:
		return false
	if n.is_in_group("corpse") or n.is_in_group("player"):
		return false
	var scr: Script = n.get_script()
	if scr and String(scr.resource_path).get_file() in ["npc_actor.gd", "echo_twin.gd"]:
		return false
	return not n.has_node(NODE_NAME)


static func attach_to(n: Node2D) -> void:
	if not is_instance_valid(n) or not wants_glow(n):
		return
	var g := Sprite2D.new()
	g.set_script(load("res://scripts/world/interact_glow.gd"))
	g.name = NODE_NAME
	n.add_child(g)


static func _script_file(n: Node) -> String:
	var scr: Script = n.get_script() if n else null
	return String(scr.resource_path).get_file() if scr else ""


## Etkileşim türü: &"normal" | &"memory" | &"cursed".
static func kind_for(n: Node) -> StringName:
	if n == null:
		return &"normal"
	if n.has_method("get_glow_kind"):
		return n.get_glow_kind()
	return KIND_BY_SCRIPT.get(_script_file(n), &"normal")


## Kısa isim etiketi ("Eski Günlük", "Kırmızı Çiçek", "Hatıra İzi", "Mühürlü Kapı"...).
static func label_for(n: Node) -> String:
	if n == null:
		return ""
	if n.has_method("get_interact_label"):
		return String(n.get_interact_label())
	var f := _script_file(n)
	if f == "lore_point.gd":
		var tp := String(n.get("texture_path")).get_file().get_basename()
		if LORE_LABEL_BY_TEXTURE.has(tp):
			return LORE_LABEL_BY_TEXTURE[tp]
		var et := String(n.get("evidence_title"))
		return et if not et.is_empty() and et.length() <= 18 else "Eski Kayıt"
	if f in ["evidence_card.gd", "ability_pickup.gd"]:
		var t := String(n.get("title"))
		if not t.is_empty():
			return t
	return LABEL_BY_SCRIPT.get(f, "İncele")


func _ready() -> void:
	texture = load("res://assets/props/halo.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	show_behind_parent = true
	z_index = -1
	_phase = randf() * TAU
	## Görselin (varsa ilk Sprite2D) merkezine otur; yoksa nesnenin hafif üstüne.
	var anchor := Vector2(0, -16)
	var big := 1.0
	var top := -40.0
	for c in get_parent().get_children():
		if c != self and c is Sprite2D and (c as Sprite2D).texture:
			var sp := c as Sprite2D
			anchor = sp.position + sp.offset * sp.scale
			var sz := sp.texture.get_size() * sp.scale.abs()
			big = clampf(maxf(sz.x, sz.y) / 48.0, 0.7, 1.8)
			top = anchor.y - sz.y * 0.5
			break
	position = anchor
	_base_scale = Vector2.ONE * 1.1 * big
	scale = _base_scale
	_color = COLORS.get(kind_for(get_parent()), COLORS[&"normal"])
	self_modulate = Color(_color, 0.0)
	## Kapıların kendi büyük etiketi var; diğerlerine küçük isim etiketi (yalnız hedefken).
	if get_parent().get_node_or_null("DoorLabel") == null:
		_label = Label.new()
		_label.name = LABEL_NAME
		_label.text = label_for(get_parent())
		_label.size = Vector2(120, 16)
		_label.position = Vector2(-60, top - 20.0)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 11)
		_label.add_theme_color_override("font_color", _color.lerp(Color.WHITE, 0.55))
		_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.z_index = 6
		_label.visible = false
		_label.modulate.a = 0.0
		get_parent().add_child.call_deferred(_label)


func is_current_target() -> bool:
	return _is_target


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase += delta * 2.6
	var p := get_parent() as Node2D
	var spent := false
	if "puzzle_id" in p:
		var pid = p.get("puzzle_id")
		if pid is StringName and pid != &"" and PuzzleManager.is_solved(pid):
			spent = true
	## Hedef sorgusu her karede değil (mobil): 0.1 sn'de bir.
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.1
		_is_target = false
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("get_interaction_target") and not UiGate.blocks_movement():
			_is_target = player.get_interaction_target() == p
		## Tür değişebilir (kilitli kapı açılınca kırmızı → krem).
		var c: Color = COLORS.get(kind_for(p), COLORS[&"normal"])
		if c != _color:
			_color = c
			if _label:
				_label.add_theme_color_override("font_color", _color.lerp(Color.WHITE, 0.55))
		if _label and _is_target:
			_label.text = label_for(p)
	_boost = move_toward(_boost, 1.0 if _is_target else 0.0, delta * 5.0)
	var pulse := 0.5 + 0.5 * sin(_phase)
	var a := (0.26 + 0.18 * pulse) * (0.35 if spent else 1.0)
	a += _boost * 0.4
	self_modulate = Color(_color, clampf(a, 0.0, 0.9))
	scale = _base_scale * (1.0 + 0.06 * pulse + 0.18 * _boost)
	if _label:
		_label.visible = _boost > 0.01
		_label.modulate.a = _boost
