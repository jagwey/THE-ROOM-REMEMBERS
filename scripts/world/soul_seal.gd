extends StaticBody2D
## Mor ruh mührü / mühürlü sarmaşık — yalnız Ruh Kesimi (Soul Slash) açar. Açılınca puzzle_id çözülür.

@export var puzzle_id: StringName = &"soul_seal"
@export var height: float = 110.0
## Mührün "arka" yüzü: 1 = sağ, -1 = sol, 0 = yok. Oyuncu arka taraftan gelirse
## (ör. başka yoldan mahzene girip geri dönerse) mühür kendiliğinden çözülür;
## yoksa Ruh Kesimi olmadan odada kapana kısılırdı.
@export var back_side: int = 0
## Yetenek yokken söylenen ret repliği (boşsa varsayılan satır). Yeteneğin alındığı odanın adını içermeli.
@export var refusal_line: String = ""
## Doluysa bu puzzle çözülmeden kesim reddedilir (yanlış kesim hiçbir şeyi bozmaz).
@export var requires: StringName = &""
## false: çarpışma gövdesi yok (duvardaki damar); yine de kesimle açılır.
@export var blocking: bool = true
@export var wrong_line: String = ""

var _vis: Node2D
var _shape: CollisionShape2D
var _hint_done: bool = false


func _ready() -> void:
	add_to_group("soul_seal")
	collision_layer = 1 | 32
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, height)
	_shape.shape = rect
	_shape.disabled = not blocking
	_shape.position = Vector2(0, -height * 0.5)
	add_child(_shape)
	_vis = Node2D.new()
	add_child(_vis)
	var vines := Sprite2D.new()
	vines.texture = load("res://assets/layers/vines.png")
	vines.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vines.position = Vector2(0, -height * 0.5)
	vines.scale = Vector2(0.5, height / 128.0)
	vines.modulate = Color(0.7, 0.45, 1.0, 1.0)
	_vis.add_child(vines)
	var sigil := Sprite2D.new()
	sigil.texture = load("res://assets/props/seal.png")
	sigil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sigil.position = Vector2(0, -height * 0.55)
	sigil.scale = Vector2(0.5, 0.5)
	sigil.modulate = Color(0.85, 0.6, 1.0, 1.0)
	_vis.add_child(sigil)
	var tw := sigil.create_tween().set_loops()
	tw.tween_property(sigil, "modulate:a", 0.5, 0.9)
	tw.tween_property(sigil, "modulate:a", 1.0, 0.9)
	PuzzleManager.puzzle_solved.connect(func(id: StringName): if id == puzzle_id and _shape.disabled == false: _open(false))
	if PuzzleManager.is_solved(puzzle_id):
		_open(false)
	elif back_side != 0:
		_add_back_sensor()


func _add_back_sensor() -> void:
	var sensor := Area2D.new()
	sensor.name = "BackSensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 0xFFFF
	sensor.monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(56, height)
	cs.shape = r
	cs.position = Vector2(float(signi(back_side)) * 44.0, -height * 0.5)
	sensor.add_child(cs)
	add_child(sensor)
	sensor.body_entered.connect(_on_back_body)


func _on_back_body(body: Node) -> void:
	if not body.is_in_group("player") or PuzzleManager.is_solved(puzzle_id):
		return
	if signf(body.global_position.x - global_position.x) != float(signi(back_side)):
		return
	_solve("Mühür bu yandan sadece bir sürgü… çektim, çözüldü.")


func receive_soul_slash(_from: Node) -> void:
	if PuzzleManager.is_solved(puzzle_id):
		return
	if requires != &"" and not PuzzleManager.is_solved(requires):
		if wrong_line != "":
			DialogueManager.whisper("Noroi", wrong_line)
		return
	_solve("Mühür ruhumu tanıdı… ve çözüldü.")


func _solve(line: String) -> void:
	PuzzleManager.mark_solved(puzzle_id)
	MobileInputManager.vibrate(35)
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(&"seal_open")
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.3)
	DialogueManager.whisper("Noroi", line)
	SaveManager.save_game()
	_open(true)


func receive_sword_hit(_from: Node, _dir: float, _combo: int) -> void:
	if PuzzleManager.is_solved(puzzle_id) or _hint_done:
		return
	_hint_done = true
	if bool(GameState.player_progress_knowledge.get("ability_soul_slash", false)):
		DialogueManager.whisper("Noroi", "Kılıç taşı keser ama bu mühür ruh istiyor: Yıldız ya da Q.")
	elif refusal_line != "":
		DialogueManager.whisper("Noroi", refusal_line)
	else:
		DialogueManager.whisper("Noroi", "Kılıç geçmiyor, mühür bir ruh bekliyor ve o gücü henüz tanımıyorum.")


func _open(animate: bool) -> void:
	_shape.set_deferred("disabled", true)
	if animate:
		var tw := create_tween()
		tw.tween_property(_vis, "modulate:a", 0.0, 0.6)
		tw.tween_callback(func(): _vis.visible = false)
	else:
		_vis.visible = false
