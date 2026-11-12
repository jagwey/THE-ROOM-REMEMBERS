extends Area2D
## Sarnıç günlük sayfası. Her sayfa kalıcı dünya bayrağı (cistern_page_<id>) olarak saklanır.
## Üç sayfa toplanınca `decay_cistern` çözülür ve günlük diyaloğu oynar.

const LorePointScript := preload("res://scripts/world/lore_point.gd")
const PAGE_COUNT := 3
const SOLVE_ID := &"decay_cistern"
const DIARY_EVIDENCE := "Sarnıçtaki sayfalar altmış sekiz yıl önce yazılmış. Bir el yazmış, su silememiş."

@export var page_id: int = 1
## Doluysa sayfa yalnız bu su seviyesindeyken alınabilir (çukur dibi: 0).
@export var water: NodePath
@export var need_level: int = -1
@export var need_line: String = "Sayfa suyun altında kalmış, oraya inemiyorum."

var _busy: bool = false
var _sprite: Sprite2D


func _flag() -> StringName:
	return StringName("cistern_page_%d" % page_id)


func _ready() -> void:
	add_to_group("cistern_page")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 28)
		cs.shape = rect
		add_child(cs)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/props/memory_echo.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(0.35, 0.35)
	_sprite.modulate = Color(0.85, 0.9, 1.0, 0.9)
	add_child(_sprite)
	_refresh()


func is_taken() -> bool:
	return bool(GameState.get_world_flag(_flag(), false)) or PuzzleManager.is_solved(SOLVE_ID)


func _refresh() -> void:
	visible = not is_taken()


func get_interact_label() -> String:
	return "Sayfa"


func _water_ok() -> bool:
	if need_level < 0:
		return true
	var w := get_node_or_null(water)
	return w != null and int(w.get("level")) == need_level


func _taken_count() -> int:
	var n := 0
	for i in range(1, PAGE_COUNT + 1):
		if bool(GameState.get_world_flag(StringName("cistern_page_%d" % i), false)):
			n += 1
	return n


func on_interact(_by: Node) -> void:
	if _busy or is_taken():
		return
	if not _water_ok():
		DialogueManager.say("Noroi", need_line)
		return
	_busy = true
	GameState.set_world_flag(_flag(), true)
	_refresh()
	var n := _taken_count()
	if n >= PAGE_COUNT:
		PuzzleManager.mark_solved(SOLVE_ID)
		for line in DialogueData.get_set(&"decay_cistern", &"diary"):
			DialogueManager.say(String(line[0]), String(line[1]))
		var ok: bool = await DialogueManager.dialogue_finished
		if ok:
			LorePointScript.record_evidence("ev_cistern_diary", "Islak Günlük", DIARY_EVIDENCE, "izler")
	else:
		DialogueManager.say("Noroi", "Islak bir sayfa topladım. (%d/%d)" % [n, PAGE_COUNT])
	SaveManager.save_game()
	_busy = false
