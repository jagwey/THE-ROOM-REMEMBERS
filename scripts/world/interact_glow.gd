extends Sprite2D
## Etkileşilebilir nesnelerin arkasında nabız gibi atan hale. Oyuncu yaklaşınca parlar;
## bulmacası çözülmüş nesnede söner. RoomManager tüm `on_interact` düğümlerine otomatik ekler.

const NODE_NAME := "InteractGlow"
const NEAR_DIST := 72.0
const BASE_COLOR := Color(1.0, 0.82, 0.5)

var _phase: float = 0.0
var _boost: float = 0.0
var _base_scale: Vector2 = Vector2.ONE


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
	for c in get_parent().get_children():
		if c != self and c is Sprite2D and (c as Sprite2D).texture:
			var sp := c as Sprite2D
			anchor = sp.position + sp.offset * sp.scale
			var sz := sp.texture.get_size() * sp.scale.abs()
			big = clampf(maxf(sz.x, sz.y) / 48.0, 0.7, 1.8)
			break
	position = anchor
	_base_scale = Vector2.ONE * 1.1 * big
	scale = _base_scale
	modulate = Color(BASE_COLOR, 0.0)


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
	var near := false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.global_position.distance_to(global_position) < NEAR_DIST:
		near = true
	_boost = move_toward(_boost, 1.0 if near else 0.0, delta * 4.0)
	var pulse := 0.5 + 0.5 * sin(_phase)
	var a := (0.32 + 0.22 * pulse) * (0.35 if spent else 1.0)
	a += _boost * 0.35
	modulate = Color(BASE_COLOR, clampf(a, 0.0, 0.9))
	scale = _base_scale * (1.0 + 0.06 * pulse + 0.15 * _boost)
