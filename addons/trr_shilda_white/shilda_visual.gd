extends Node2D
## Shilda White Guardian (Godot 4) — Remastered HD Visual Controller.
## Karakterin AI, hitbox ve collision scriptlerine dokunmadan görsel olarak kullanabilirsiniz.
@export var noroi_visible_height: float = 64.0
@export_range(1.1, 2.0, 0.05) var target_ratio: float = 1.6
@export var source_character_height: float = 183.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    sprite.sprite_frames = load("res://addons/trr_shilda_white/shilda_sprite_frames.tres")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    adjust_scale()
    sprite.play(&"idle")

func adjust_scale() -> void:
    var s: float = noroi_visible_height * target_ratio / maxf(source_character_height, 1.0)
    sprite.scale = Vector2.ONE * s
    # 224x224 tuval: Karakter yatayda tam ortada (x=112), ayak tabanı y=196'da sabitlenmiştir.
    # centered=true iken merkez (112, 112)'dir; ayak tabanı merkezden 84 piksel aşağıdadır.
    # Bu nedenle node kök noktası (0, 0) doğrudan zemin/ayak hizası olur:
    sprite.position = Vector2(0.0, -84.0 * s)

func play_shilda(anim: StringName, facing_left: bool = false) -> void:
    if sprite.sprite_frames.has_animation(anim):
        sprite.flip_h = facing_left
        sprite.play(anim)
