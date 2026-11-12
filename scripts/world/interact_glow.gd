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
"flower_inspect.gd": &"cursed", "decay_flower_evidence.gd": &"cursed",
}
const LABEL_BY_SCRIPT := {
	"decay_flower_evidence.gd": "Kırmızı Çiçek", "flower_inspect.gd": "Kırmızı Çiçek",
	"pocket_watch_inspect.gd": "Cep Saati", "trace_marker.gd": "Anı İzi",
	"echo_point.gd": "Yankı", "echo_interactable.gd": "Yankı", "awakening_seal_echo_recall.gd": "Yankı Nişi",
	"echo_altar.gd": "Yankı Sunağı", "echo_switch.gd": "Yankı Anahtarı", "code_seal_base.gd": "Mühür",
	"blood_thorn.gd": "Kan Dikeni", "core_crystal.gd": "Çekirdek Kristali", 
	"mirror_relay.gd": "Ayna", "reset_lever.gd": "Kol",
	"vine_puzzle_lever.gd": "Kol", "vine_interact.gd": "Sarmaşık", "archive_door.gd": "Arşiv Kapısı",
	"story_beat.gd": "Anı", "keeper_controller.gd": "Shilda", "cracked_mirror.gd": "Çatlak Ayna",
	"shilda_garden_trust.gd": "Shilda", "evidence_card.gd": "Kayıt", "ability_pickup.gd": "Sunak",
}
const LORE_LABEL_BY_TEXTURE := {
	"photograph": "Eski Fotoğraf", "memory_echo": "Anı Yankısı", "red_flower": "Kırmızı Çiçek", "flowers": "Kırmızı Çiçek",
	"books": "Eski Günlük", "bookshelf": "Eski Günlük", "mirror": "Ayna", "mirror_shards": "Ayna Kırığı",
	"candles": "Mumlar", "candlestick": "Şamdan", "key": "Anahtar", "seal": "Mühür", "curse": "Lanet İzi",
	"body_echo": "Anı İzi", "core_crystal": "Çekirdek Kristali",
}

var _phase: float = 0.0
var _boost: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _color: Color = COLORS[&"normal"]
var _label: Label
var _label_local := Vector2(-60, -36)
var _tick: float = 0.0
var _is_target: bool = false
var _emph: float = 0.0
var _emph_sprite: CanvasItem = null
var _emph_base: Color = Color.WHITE
var _emph_mat: ShaderMaterial = null

const OUTLINE_COLOR := Color(1.0, 0.94, 0.82, 0.75)
const EMPH_MODULATE := Color(1.25, 1.22, 1.28, 1.0)
const OUTLINE_SHADER := "shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0, 0.94, 0.82, 0.75);
uniform vec2 px_scale = vec2(1.0, 1.0);
uniform float strength = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 o = TEXTURE_PIXEL_SIZE * px_scale;
	float a = texture(TEXTURE, UV + vec2(o.x, 0.0)).a;
	a = max(a, texture(TEXTURE, UV - vec2(o.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, o.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, o.y)).a);
	float edge = a * (1.0 - texture(TEXTURE, UV).a) * strength * outline_color.a;
	COLOR = vec4(mix(c.rgb, outline_color.rgb, edge), max(c.a, edge));
}
"


## Glow eklenmeli mi? Ceset, taş ve Shilda dahil tüm on_interact hedefleri; oyuncu/NPC/ikiz hariç.
static func wants_glow(n: Node) -> bool:
	if not (n is Node2D) or not n.has_method("on_interact"):
		return false
	if n is RigidBody2D or n.is_in_group("player"):
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


## Kısa isim etiketi ("Eski Günlük", "Kırmızı Çiçek", "Anı İzi", "Mühürlü Kapı"...).
static func label_for(n: Node) -> String:
	if n == null:
		return ""
	if n.has_method("get_interact_label"):
		var il := String(n.get_interact_label())
		return GameState.keeper_speaker_name() if il == "???" or il == "Shilda" else il
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
	## Nesnenin ARKASINDA ama arka planın ÖNÜNDE (z -1 ParallaxFar'ın arkasına düşüp görünmüyordu).
	show_behind_parent = true
	z_index = 0
	_phase = randf() * TAU
	## Görselin (varsa ilk Sprite2D) merkezine otur; yoksa nesnenin hafif üstüne.
	var anchor := Vector2(0, -16)
	var big := 1.0
	var top := -40.0
	var label_gap := 20.0
	var par := get_parent()
	var anim: AnimatedSprite2D = null
	for c in par.get_children():
		if c is AnimatedSprite2D and (c as AnimatedSprite2D).sprite_frames:
			anim = c
			break
	if anim != null:
		## Animasyonlu hedef (Shilda): görsel merkez/tepe geçerli karenin boyutundan hesaplanır.
		var ftex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
		if ftex == null:
			ftex = anim.sprite_frames.get_frame_texture(anim.sprite_frames.get_animation_names()[0], 0)
		if ftex != null:
			var fsz := ftex.get_size() * anim.scale.abs()
			var center_off := Vector2.ZERO if anim.centered else fsz * 0.5
			anchor = anim.position + anim.offset * anim.scale + center_off
			big = clampf(maxf(fsz.x, fsz.y) / 48.0, 0.7, 1.8)
			top = anchor.y - fsz.y * 0.5
			## Hale başın üstüne taşar; etiket halenin ve "..." ipucunun da üstünde dursun.
			label_gap = 32.0
	for c in par.get_children():
		if anim != null:
			break
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
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.clip_text = false
		_label.add_theme_font_size_override("font_size", 11)
		_label.add_theme_color_override("font_color", _color.lerp(Color.WHITE, 0.55))
		_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.z_index = 20
		_label.visible = false
		_label.modulate.a = 0.0
		_label_local = Vector2(0, top - label_gap)
		get_parent().add_child.call_deferred(_label)


func is_current_target() -> bool:
	return _is_target


## Vurgulanacak ana görsel: ilk AnimatedSprite2D, yoksa dokulu ilk Sprite2D (ceset/taş/eşya).
func _find_main_sprite() -> CanvasItem:
	var par := get_parent()
	for c in par.get_children():
		if c != self and c is AnimatedSprite2D:
			return c
	for c in par.get_children():
		if c != self and c is Sprite2D and (c as Sprite2D).texture and (c as Sprite2D).visible and c.name != "Flower":
			return c
	return null


func _update_emphasis(delta: float, want: bool) -> void:
	## Kapılar kendi büyük etiket/ışığını kullanır; kontrast vurgusu yalnız diğer nesnelere.
	if get_parent().get_node_or_null("DoorLabel") != null:
		return
	_emph = move_toward(_emph, 1.0 if want else 0.0, delta * 4.0)
	if _emph > 0.01 and not is_instance_valid(_emph_sprite):
		_emph_sprite = _find_main_sprite()
		if _emph_sprite == null:
			_emph = 0.0
			return
		_emph_base = _emph_sprite.self_modulate
		if _emph_sprite.material == null:
			if _emph_mat == null:
				var sh := Shader.new()
				sh.code = OUTLINE_SHADER
				_emph_mat = ShaderMaterial.new()
				_emph_mat.shader = sh
				_emph_mat.set_shader_parameter("outline_color", OUTLINE_COLOR)
			_emph_sprite.material = _emph_mat
	if not is_instance_valid(_emph_sprite):
		return
	if _emph_mat != null and _emph_sprite.material == _emph_mat:
		var gs: Vector2 = (_emph_sprite as Node2D).global_scale.abs()
		_emph_mat.set_shader_parameter("px_scale", Vector2(1.0 / maxf(gs.x, 0.05), 1.0 / maxf(gs.y, 0.05)))
		_emph_mat.set_shader_parameter("strength", _emph)
	var pulse := 0.5 + 0.5 * sin(_phase * 0.8)
	var tint := Color.WHITE.lerp(EMPH_MODULATE, _emph * (0.55 + 0.45 * pulse))
	_emph_sprite.self_modulate = Color(_emph_base.r * tint.r, _emph_base.g * tint.g, _emph_base.b * tint.b, _emph_base.a)
	if _emph <= 0.01:
		_emph_sprite.self_modulate = _emph_base
		if _emph_sprite.material == _emph_mat:
			_emph_sprite.material = null
		_emph_sprite = null


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
		## Sırttaki beden: alt HUD "E · Bırak" yeter, bedenin üstünde ikinci etiket olmasın.
		if p.has_method("is_carried") and bool(p.call("is_carried")):
			_is_target = false
		## Tür değişebilir (kilitli kapı açılınca kırmızı → krem).
		var c: Color = COLORS.get(kind_for(p), COLORS[&"normal"])
		if c != _color:
			_color = c
			if _label:
				_label.add_theme_color_override("font_color", _color.lerp(Color.WHITE, 0.55))
		if _label and _is_target:
			_label.text = label_for(p)
	_boost = move_toward(_boost, 1.0 if _is_target else 0.0, delta * 5.0)
	_update_emphasis(delta, _is_target and not spent)
	var pulse := 0.5 + 0.5 * sin(_phase)
	var a := (0.26 + 0.18 * pulse) * (0.35 if spent else 1.0)
	a += _boost * 0.4
	self_modulate = Color(_color, clampf(a, 0.0, 0.9))
	scale = _base_scale * (1.0 + 0.06 * pulse + 0.18 * _boost)
	if _label:
		_label.visible = _boost > 0.01
		_label.modulate.a = _boost
		if _label.visible:
			_fit_name_label()


func _fit_name_label() -> void:
	if not _label.is_inside_tree():
		return
	var font: Font = _label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var tw := ceilf(font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 12.0
	var w := clampf(tw, 36.0, 260.0)
	_label.size = Vector2(w, 20.0)
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var desired := parent.to_global(Vector2(_label_local.x - w * 0.5, _label_local.y))
	var view := _camera_view()
	if view.size.x > 8.0:
		var margin := 6.0
		desired.x = clampf(desired.x, view.position.x + margin, maxf(view.position.x + margin, view.end.x - margin - w))
		desired.y = clampf(desired.y, view.position.y + margin, maxf(view.position.y + margin, view.end.y - margin - _label.size.y))
	_label.global_position = desired


func _camera_view() -> Rect2:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return Rect2()
	var vp := get_viewport().get_visible_rect().size
	var zoom := cam.zoom
	var size := Vector2(vp.x / maxf(zoom.x, 0.01), vp.y / maxf(zoom.y, 0.01))
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)
