extends CharacterBody2D
## İtilebilir taş — plaka bulmacası. Oyuncuyu yatayda engellemez (tek yönlü çarpışma, ceset gibi):
## (a) omuz itişi: oyuncunun GİRİŞ yönü (input_x) taşa doğruysa taş ilerler,
## (b) Etkileş: push_step kadar tween ile adım adım it (duvar/uçurum ışın kontrolü).
## Üstüne çıkılabilir; layer 1 (zemin/plaka algısı) + layer 8 (etkileşim).

@export var min_x: float = 40.0
@export var max_x: float = 900.0
@export var push_step: float = 36.0
@export var half_width: float = 11.0

const GRAVITY := 900.0
const PUSH_SPEED := 180.0 ## apply_push (anlık hız)
const FRICTION := 420.0
const WALK_PUSH_FACTOR := 0.6 ## oyuncu hızının çarpanı (iterken yavaşlar)
const CONTACT_DX := 30.0 ## oyuncu-taş merkez mesafesi üst sınırı (omuz teması)

var _start_global: Vector2 = Vector2.ZERO
var _stepping: bool = false


func _init() -> void:
	collision_layer = 1 | 8
	collision_mask = 1


func _ready() -> void:
	add_to_group("weight_stone")
	collision_layer = 1 | 8  ## Layer 1 (World) + Layer 8 (Interact)
	collision_mask = 1
	_start_global = global_position
	## Oyuncu yatayda içinden geçer, üstüne basabilir (itme girdiden gelir).
	for c in get_children():
		if c is CollisionShape2D:
			var cs := c as CollisionShape2D
			cs.one_way_collision = true
			cs.one_way_collision_margin = 8.0
			if cs.shape is RectangleShape2D:
				half_width = (cs.shape as RectangleShape2D).size.x * 0.5
			break


func reset_to_start() -> void:
	global_position = _start_global
	velocity = Vector2.ZERO
	_stepping = false


func apply_push(dir: float) -> void:
	velocity.x = signf(dir) * PUSH_SPEED


func get_weight() -> int:
	return 1


func get_interact_label() -> String:
	return "Taş"


## Etkileş: taşı baktığın yöne bir adım it.
func on_interact(by: Node = null) -> void:
	var dir := 1.0
	if by and by.has_method("get_facing"):
		dir = float(by.get_facing())
	step_push(dir, by)


func step_push(dir: float, by: Node = null) -> bool:
	if _stepping or UiGate.pauses_world_threats():
		return false
	dir = signf(dir) if dir != 0.0 else 1.0
	var dist := _clear_distance(dir, push_step)
	dist = minf(dist, (max_x - global_position.x) if dir > 0.0 else (global_position.x - min_x))
	if dist < 1.0:
		return false
	if by and by.has_method("note_push"):
		by.note_push(self)
	_stepping = true
	velocity.x = 0.0
	var target_x := global_position.x + dir * dist
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(&"corpse_drag")
	var tw := create_tween()
	tw.tween_property(self, "global_position:x", target_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_stepping = false
	_refresh_plates()
	return true


## Verilen yönde en fazla `want` piksel gidilebilir mi (duvar + uçurum). 0 = engelli.
func _clear_distance(dir: float, want: float) -> float:
	var space := get_world_2d().direct_space_state
	if space == null:
		return want
	var allowed := want
	var ray_start := global_position + Vector2(0, -10.0)
	var ray_end := ray_start + Vector2(dir * (half_width + want + 2.0), 0.0)
	var q := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1 | 16 | 32)
	q.exclude = _body_rids()
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var hx: float = (hit["position"] as Vector2).x
		allowed = minf(allowed, maxf(0.0, absf(hx - global_position.x) - half_width - 1.0))
	if allowed < 1.0:
		return 0.0
	## Zemin: hedef ayak ucunun altında zemin olmalı (taşın ön kenarı boşlukta kalmasın).
	var foot_x := global_position.x + dir * (allowed + half_width * 0.5)
	var qf := PhysicsRayQueryParameters2D.create(Vector2(foot_x, global_position.y - 4.0), Vector2(foot_x, global_position.y + 24.0), 1)
	qf.exclude = [get_rid()]
	if space.intersect_ray(qf).is_empty():
		return 0.0
	return allowed


func _body_rids() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	for g in [&"corpse", &"weight_stone", &"pushable_stone"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is CollisionObject2D and not out.has((n as CollisionObject2D).get_rid()):
				out.append((n as CollisionObject2D).get_rid())
	return out


func _refresh_plates() -> void:
	for p in get_tree().get_nodes_in_group("pressure_plate"):
		if p.has_method("_recompute"):
			p._recompute()


## Omuz itişi: oyuncunun giriş yönü taşa doğru ve yan yana ise taş oyuncuyla aynı hızda ilerler.
func _walk_push_dir() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not ("input_x" in player):
		return 0.0
	var ix := float(player.get("input_x"))
	if absf(ix) < 0.3:
		return 0.0
	var dx := global_position.x - player.global_position.x
	var dy := player.global_position.y - global_position.y
	if absf(dx) > CONTACT_DX or absf(dx) < 2.0 or signf(dx) != signf(ix):
		return 0.0
	if dy < -10.0 or dy > 28.0: ## üstünde duruyorsa itme
		return 0.0
	return signf(ix)


func _physics_process(delta: float) -> void:
	if UiGate.pauses_world_threats():
		velocity = Vector2.ZERO
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	if _stepping:
		velocity.x = 0.0
		move_and_slide()
		return
	var wd := _walk_push_dir()
	if wd != 0.0:
		var player := get_tree().get_first_node_in_group("player")
		var spd := 175.0 * WALK_PUSH_FACTOR
		if "SPEED" in player:
			spd = float(player.SPEED) * WALK_PUSH_FACTOR
		if _clear_distance(wd, 4.0) > 0.5:
			velocity.x = wd * spd
			if player.has_method("note_push"):
				player.note_push(self)
		else:
			velocity.x = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, min_x, max_x)
	if absf(velocity.x) > 0.5:
		_refresh_plates()
