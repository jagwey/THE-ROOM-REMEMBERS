extends Area2D
## Kırmızı çizgi (engelsiz) — yalnız Gölge Atılması ile içinden atılınca açılır. Açılınca puzzle_id çözülür.
## Yetenek yokken / yürürken çizgi geri iter (replik), yol kapanmaz.

@export var puzzle_id: StringName = &"dash_line"
@export var height: float = 110.0
@export var refusal_line: String = ""
@export var hint_line: String = "Çizgiyi yürüyerek geçemem; Gölge Atılması ile içinden atılmalıyım."

var _t: float = 0.0
var _warned: bool = false


func _ready() -> void:
	add_to_group("dash_line")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(36, height)
	cs.shape = r
	cs.position = Vector2(0, -height * 0.5)
	add_child(cs)
	z_index = 3
	body_entered.connect(_on_enter)
	body_exited.connect(func(b: Node): if b.is_in_group("player"): _warned = false)


func is_open() -> bool:
	return PuzzleManager.is_solved(puzzle_id)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if is_open():
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("player") and b.has_method("is_shadow_dashing") and b.is_shadow_dashing():
			receive_shadow_dash(b)
			return


func _draw() -> void:
	var open := is_open()
	for i in 7:
		var x := sin(_t * 2.0 + float(i)) * 6.0
		var a := 0.35 + 0.25 * sin(_t * 3.0 + float(i) * 0.7)
		if open:
			a *= 0.22
		draw_line(Vector2(x - 8.0 + float(i) * 2.6, 0), Vector2(-x + float(i) * 2.0 - 6.0, -height), Color(0.85, 0.1, 0.25, a), 2.0)


func _on_enter(b: Node) -> void:
	if _warned or is_open() or not b.is_in_group("player"):
		return
	if b.has_method("is_shadow_dashing") and b.is_shadow_dashing():
		return
	_warned = true
	if b.has_method("has_shadow_dash") and b.has_shadow_dash():
		DialogueManager.whisper("Noroi", hint_line)
	else:
		DialogueManager.whisper("Noroi", refusal_line if refusal_line != "" else "Kırmızı çizgi beni itiyor, gölge olsaydım geçebilirdim.")


## Gölge Atılması çizgiyi geçti: kalıcı olarak açılır.
func receive_shadow_dash(_by: Node) -> void:
	if is_open():
		return
	PuzzleManager.mark_solved(puzzle_id)
	MobileInputManager.vibrate(30)
	DialogueManager.whisper("Noroi", "Çizgiden gölge gibi geçtim; arkası açıldı.")
	SaveManager.save_game()
