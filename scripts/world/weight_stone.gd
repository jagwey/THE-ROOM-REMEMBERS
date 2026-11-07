extends CharacterBody2D
## İtilebilir taş — ceset yerine plaka bulmacası (world layer).

@export var min_x: float = 40.0
@export var max_x: float = 900.0

const GRAVITY := 900.0
const PUSH_SPEED := 180.0
const FRICTION := 420.0

var _start_global: Vector2 = Vector2.ZERO


func _init() -> void:
	collision_layer = 1 | 8
	collision_mask = 1


func _ready() -> void:
	add_to_group("weight_stone")
	collision_layer = 1 | 8  ## Layer 1 (World) + Layer 4 (Interact bit 3)
	collision_mask = 1
	_start_global = global_position


func reset_to_start() -> void:
	global_position = _start_global
	velocity = Vector2.ZERO


func apply_push(dir: float) -> void:
	velocity.x = signf(dir) * PUSH_SPEED


func on_interact(by: Node = null) -> void:
	apply_push(by.get_facing() if by and by.has_method("get_facing") else 1.0)


func _physics_process(delta: float) -> void:
	if UiGate.pauses_world_threats():
		velocity = Vector2.ZERO
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, min_x, max_x)


func get_weight() -> int:
	return 1
