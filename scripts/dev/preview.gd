extends Node2D
# Asset viewer only: touch buttons cycle themes and animation clips.
var themes = ["awakening", "decay", "library", "experiment", "mirrors", "core"]
var clips = ["idle", "run", "attack", "dash", "hurt", "death"]
var theme_index := 0
var clip_index := 0
var backdrops: Array[Sprite2D] = []
var hero: AnimatedSprite2D
var keeper: AnimatedSprite2D
var status: Label
var clock := 0.0

func sprite(path: String, pos: Vector2, parent: Node = self) -> Sprite2D:
    var s := Sprite2D.new()
    s.texture = load(path)
    s.position = pos
    parent.add_child(s)
    return s

func _ready() -> void:
    for layer in ["far", "mid", "front"]:
        var s := sprite("res://assets/backgrounds/awakening/" + layer + ".png", Vector2(320,180))
        backdrops.append(s)
    backdrops[2].z_index = 3
    # A TileSetAtlasSource is created from the exact 32x32 atlas, without auto-terrain rules.
    var tile_set := TileSet.new()
    tile_set.tile_size = Vector2i(32,32)
    var source := TileSetAtlasSource.new()
    source.texture = load("res://assets/tiles/terrain_atlas.png")
    source.texture_region_size = Vector2i(32,32)
    for y in range(4):
        for x in range(4):
            source.create_tile(Vector2i(x,y))
    tile_set.add_source(source,0)
    var ground := TileMapLayer.new()
    ground.tile_set = tile_set
    ground.position = Vector2(0,256)
    add_child(ground)
    for x in range(20):
        ground.set_cell(Vector2i(x,0),0,Vector2i(x % 3,0))
        ground.set_cell(Vector2i(x,1),0,Vector2i(x % 4,1))
        ground.set_cell(Vector2i(x,2),0,Vector2i(x % 4,1))
    hero = AnimatedSprite2D.new()
    hero.sprite_frames = load("res://assets/characters/noroi.tres")
    hero.position = Vector2(280,212)
    add_child(hero)
    hero.play("idle")
    keeper = AnimatedSprite2D.new()
    keeper.sprite_frames = load("res://assets/characters/keeper.tres")
    keeper.position = Vector2(410,196)
    add_child(keeper)
    keeper.play("observe")
    var npc := AnimatedSprite2D.new()
    npc.sprite_frames = load("res://assets/characters/npc.tres")
    npc.position = Vector2(190,220)
    add_child(npc)
    npc.play("librarian_idle")
    var hud := CanvasLayer.new()
    add_child(hud)
    for x in range(3):
        sprite("res://assets/hud/heart_full.png",Vector2(24+x*25,20),hud)
    sprite("res://assets/hud/joystick_base.png",Vector2(52,306),hud)
    sprite("res://assets/hud/joystick_thumb.png",Vector2(52,306),hud).scale=Vector2(.5,.5)
    for i in range(3):
        var button := TextureButton.new()
        button.texture_normal = load("res://assets/hud/" + ["attack","dash","interact"][i] + ".png")
        button.position = Vector2(440+i*64,284)
        button.pressed.connect(_next_clip)
        hud.add_child(button)
    var next := Button.new()
    next.text="Tema >"
    next.position=Vector2(536,8)
    next.pressed.connect(_next_theme)
    hud.add_child(next)
    var anim := Button.new()
    anim.text="Animasyon >"
    anim.position=Vector2(422,8)
    anim.pressed.connect(_next_clip)
    hud.add_child(anim)
    status=Label.new()
    status.position=Vector2(130,10)
    status.add_theme_font_size_override("font_size",12)
    hud.add_child(status)
    _update_status()

func _next_theme() -> void:
    theme_index=(theme_index+1)%themes.size()
    for i in range(3):
        backdrops[i].texture=load("res://assets/backgrounds/"+themes[theme_index]+"/"+["far","mid","front"][i]+".png")
    _update_status()

func _next_clip() -> void:
    clip_index=(clip_index+1)%clips.size()
    hero.play(clips[clip_index])
    keeper.play(["observe","walk","attack","grieve"][clip_index%4])
    _update_status()

func _update_status() -> void:
    status.text=themes[theme_index]+" / "+clips[clip_index]

func _process(delta: float) -> void:
    clock+=delta
    # Bounded motion intentionally avoids implying seamless panoramic backgrounds.
    backdrops[0].position.x=320+round(sin(clock*.3)*2)
    backdrops[1].position.x=320+round(sin(clock*.3)*5)
    backdrops[2].position.x=320+round(sin(clock*.3)*10)
    if Input.is_action_just_pressed("ui_right"):
        _next_theme()
    if Input.is_action_just_pressed("ui_accept"):
        _next_clip()
