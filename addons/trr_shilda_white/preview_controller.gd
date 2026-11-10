extends Node2D
@onready var visual: Variant = $ShildaVisual
var sequence: Array[StringName] = [&"idle", &"walk", &"talk", &"warning", &"cast", &"flower", &"vanish"]
var selected: int = 0

func _ready() -> void:
    visual.noroi_visible_height = 220.0
    visual.target_ratio = 1.0
    visual.adjust_scale()
    visual.position = Vector2(560, 425)
    visual.play_shilda(sequence[selected])
    $Help.text = "SHILDA / Left - Right: animation change | idle"

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_RIGHT:
            selected = (selected + 1) % sequence.size()
        elif event.keycode == KEY_LEFT:
            selected = (selected - 1 + sequence.size()) % sequence.size()
        else:
            return
        visual.play_shilda(sequence[selected])
        $Help.text = "SHILDA / Left - Right: animation change | " + str(sequence[selected])
