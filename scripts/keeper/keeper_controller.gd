extends CharacterBody2D
## Bekçi — erken oyun: yalnızca gözlem. Öldürmez.

enum Mode { OBSERVE, WARN, INTERVENE, MOURNING, INTIMACY }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hint: Label = $HintLabel

@export var mode: Mode = Mode.OBSERVE

var _player: Node2D


func _ready() -> void:
	add_to_group("keeper")
	sprite.sprite_frames = load("res://assets/characters/keeper.tres")
	sprite.offset = Vector2(0, -60)
	sprite.play("observe")
	hint.text = ""
	hint.visible = false
	GameState.world_memory_state["keeper_mood"] = &"observe"


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return
	# Yüzünü oyuncuya çevir; yaklaşma yok.
	sprite.flip_h = _player.global_position.x < global_position.x
	var dist := global_position.distance_to(_player.global_position)
	match mode:
		Mode.OBSERVE:
			if sprite.animation != "observe":
				sprite.play("observe")
			if dist < 90.0:
				_show_hint("…")
			else:
				hint.visible = false
		Mode.WARN:
			_show_hint("Uzak dur.")
		Mode.INTERVENE, Mode.MOURNING, Mode.INTIMACY:
			# FAZ 3+ — şimdilik observe animasyonu.
			if sprite.animation != "observe":
				sprite.play("observe")
		_:
			pass


func _show_hint(text: String) -> void:
	hint.text = text
	hint.visible = true


func on_interact(_by: Node) -> void:
	# Erken oyun: sessiz gözlem / kısa Türkçe ipucu. Öldürme yok.
	DialogueManager.say("Bekçi", "…Seni izliyorum.")
	DialogueManager.say("Bekçi", "Henüz hatırlama.")
