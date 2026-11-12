extends Node2D
## Karanlıkta görünmeyen sembol — yalnız bir Fener Cesedin (çiçekli ceset) ışığında belirir.
## Görüldüğünde memory_code öğretebilir.

@export var symbol_text: String = "◆"
@export var reveal_radius: float = 220.0
@export var memory_code_key: String = ""
@export var memory_code_value: String = ""
@export var reveal_line: String = ""
## Doluysa: aynı code_group'taki TÜM semboller görülünce kod öğrenilir (rakamlar yayılmış semboller).
@export var code_group: StringName = &""

var _label: Label
var _seen: bool = false


func _ready() -> void:
	add_to_group("hidden_symbol")
	_label = Label.new()
	_label.text = symbol_text
	_label.position = Vector2(-40, -16)
	_label.size = Vector2(80, 32)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_label(_label, 20, true)
	_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.6, 1))
	_label.modulate.a = 0.0
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var best := 9999.0
	for c in get_tree().get_nodes_in_group("lantern_corpse"):
		if c is Node2D and (c as Node2D).is_visible_in_tree():
			## Semboller duvarda yüksekte, beden yerde: dikey fark ~110 px'e kadar sayılmaz
			## (yoksa yerdeki fener asla yetişmezdi). Yatay mesafe belirleyici.
			var d: Vector2 = (c as Node2D).global_position - global_position
			best = minf(best, Vector2(d.x, maxf(0.0, absf(d.y) - 120.0)).length())
	var a := clampf(1.0 - (best - reveal_radius * 0.6) / (reveal_radius * 0.4), 0.0, 1.0)
	_label.modulate.a = lerpf(_label.modulate.a, a, 0.15)
	if a > 0.8 and not _seen:
		_seen = true
		if code_group != &"":
			_try_group_code()
			return
		if memory_code_key != "" and memory_code_value != "":
			GameState.learn_memory_code(memory_code_key, memory_code_value)
		if reveal_line != "":
			DialogueManager.whisper("Noroi", reveal_line)


func is_seen() -> bool:
	return _seen


func _try_group_code() -> void:
	var carrier: Node = null
	for n in get_tree().get_nodes_in_group("hidden_symbol"):
		if n == self or not ("code_group" in n) or n.code_group != code_group:
			continue
		if not n.is_seen():
			return
		if String(n.memory_code_value) != "":
			carrier = n
	if carrier == null and memory_code_value != "":
		carrier = self
	if carrier == null:
		return
	GameState.learn_memory_code(String(carrier.memory_code_key), String(carrier.memory_code_value))
	if String(carrier.reveal_line) != "":
		DialogueManager.whisper("Noroi", String(carrier.reveal_line))
