extends Node2D
## Sera: üç gerçek saksı görünür olarak çizilir (plakalar kendi başına görünmez) ve
## Noroi'nin karanlık silueti girişten doğru saksıya (x620) durmadan yürür, orada diz çöker,
## saksı parlar; sonra söner ve gösteriyi tekrarlar (greenhouse_shade.gd).
## Gölge yalnız çözülmemişse (`decay_greenhouse_pot` ve eski `decay_greenhouse`) kurulur. Kayda geçmez.

const SHADE := preload("res://scripts/world/greenhouse_shade.gd")
const PLANTER := "res://assets/trr_refresh/decay/planter_bloom.png"
const POT_XS := [460.0, 620.0, 780.0]
const TARGET_X := 620.0
const GROUND_Y := 288.0
const PLANTER_SCALE := 0.62


func _ready() -> void:
	var tex: Texture2D = load(PLANTER)
	for x in POT_XS:
		var spr := Sprite2D.new()
		spr.name = "Planter%d" % int(x)
		spr.add_to_group("greenhouse_planter")
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(PLANTER_SCALE, PLANTER_SCALE)
		spr.position = Vector2(x, GROUND_Y - tex.get_height() * PLANTER_SCALE * 0.5 + 2.0)
		spr.z_index = 1
		add_child(spr)
	if PuzzleManager.is_solved(&"decay_greenhouse_pot") or PuzzleManager.is_solved(&"decay_greenhouse"):
		return
	var s := Node2D.new()
	s.set_script(SHADE)
	s.name = "PotShade"
	s.set("target_x", TARGET_X)
	add_child(s)
