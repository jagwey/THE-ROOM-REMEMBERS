extends Control
## Diyalog portre madalyonu: yumuşak (lineer+mipmap) illüstrasyon, dairesel maske + koyu vinyet,
## ince gotik çift halka (soluk lila + altın). Piksel filtresi YOK — yalnız bu düğümde.

const SHADER_CODE := "shader_type canvas_item;
uniform float vignette = 0.5;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float r = length(UV - vec2(0.5)) * 2.0;
	c.rgb *= tint;
	c.rgb *= 1.0 - smoothstep(0.5, 1.0, r) * vignette;
	c.a *= 1.0 - smoothstep(0.95, 1.0, r);
	COLOR = c;
}"

var rect: TextureRect
var key: StringName = &""
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(68, 68)
	size = Vector2(68, 68)
	rect = TextureRect.new()
	rect.name = "Portrait"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 4.0
	rect.offset_top = 4.0
	rect.offset_right = -4.0
	rect.offset_bottom = -4.0
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	add_child(rect)
	visible = false


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r - 1.0, Color(Palette.VOID, 0.92))
	draw_arc(c, r - 1.0, 0.0, TAU, 48, Color(Palette.PALE_LILAC, 0.9), 1.5, true)
	draw_arc(c, r - 4.0, 0.0, TAU, 48, Color(0.78, 0.62, 0.3, 0.75), 1.0, true)


## Anahtar boşsa gizlenir. animate: konuşmacı değişti -> kısa fade + soldan kayma.
func show_key(new_key: StringName, animate: bool) -> void:
	key = new_key
	if _tween and _tween.is_valid():
		_tween.kill()
	if new_key == &"":
		visible = false
		return
	rect.texture = load("res://scripts/ui/dialogue_portraits.gd").texture_for(new_key)
	(rect.material as ShaderMaterial).set_shader_parameter(&"tint", Vector3(0.05, 0.04, 0.09) if new_key == &"shilda_unknown" else Vector3.ONE)
	visible = true
	if not animate:
		modulate.a = 1.0
		rect.position.x = 4.0
		return
	modulate.a = 0.0
	rect.position.x = -6.0
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.22)
	_tween.tween_property(rect, "position:x", 4.0, 0.22)
