extends CanvasLayer
## Gotik Bölge Başlık Kartı HUD (Gothic Region Title Card HUD — F27)
## Oyuncu ilk kez bir ana bölgeye girdiğinde ekranın üstünde zarif bir gotik kart gösterilir ve discovery stinger çalar.

## Bölge adları tek kaynak: kart başlığı (büyük harf), günlük haritası ve hedefler "name" alanını kullanır.
const REGION_CARDS := {
	"awakening": {"name": "Uyanış Mahmuzu", "title": "UYANIŞ MAHMUZU", "sub": "İlk Anı"},
	"decay": {"name": "Çürüme Bahçesi", "title": "ÇÜRÜME BAHÇESİ", "sub": "Zamanın Çürüttüğü Kökler"},
	"library": {"name": "Hafıza Kütüphanesi", "title": "HAFIZA KÜTÜPHANESİ", "sub": "Yazılı Günahlar"},
	"experiment": {"name": "Kara Deney Mahzeni", "title": "KARA DENEY MAHZENİ", "sub": "Ruhun Parçalandığı Yer"},
	"mirrors": {"name": "Aynalar Salonu", "title": "AYNALAR SALONU", "sub": "Ters Yansımalar"},
	"core": {"name": "Hafıza Çekirdeği", "title": "HAFIZA ÇEKİRDEĞİ", "sub": "Son Karar"},
}


## Bölge kimliği -> görünen ad (günlük haritası vb.).
static func region_name(region_id: String) -> String:
	return String((REGION_CARDS.get(region_id, {}) as Dictionary).get("name", region_id.capitalize()))

static var instance: Node = null

var _container: Control
var _title_label: Label
var _sub_label: Label
var _top_line: ColorRect
var _bottom_line: ColorRect
var _tween: Tween
## Diyalog/kapı açıkken gelen kartlar sıraya girer, kapı boşalınca gösterilir.
var _queue: Array[String] = []
## Ekrandaki kartın bölgesi; kart sürerken diyalog açılırsa kart gizlenip sıraya geri alınır.
var _current := ""
## Kart, üst-orta oda başlığının (y 6..38) ve sol üst hedef/ipucunun (y 40..96) altında durur.
const CARD_Y := 112.0
const TitleCardStyle := preload("res://scripts/ui/title_card_style.gd")


func _ready() -> void:
	instance = self
	add_to_group("region_title_card")
	layer = 28
	_build_ui()
	## Bölge değişince önceki bölgenin kartı hiçbir odada çıkmasın.
	if not RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.connect(_on_room_changed)


func _build_ui() -> void:
	if _container:
		return
	_container = Control.new()
	_container.name = "TitleCardContainer"
	_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_container.offset_top = CARD_Y
	_container.offset_left = -200.0
	_container.offset_right = 200.0
	_container.offset_bottom = CARD_Y + 64.0
	_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.modulate.a = 0.0
	add_child(_container)

	# Koyu zemin: arkadaki dünya etiketleri ([E] Geç, prop adları) kartla çakışmasın.
	var parts := TitleCardStyle.build(_container, 400.0, 60.0, Color(Palette.PALE_LILAC.r, Palette.PALE_LILAC.g, Palette.PALE_LILAC.b, 0.45))
	_top_line = parts["top_line"]
	_bottom_line = parts["bottom_line"]
	_title_label = parts["title"]
	_sub_label = parts["sub"]


static func show_region_title(region_name: String) -> void:
	if instance and is_instance_valid(instance):
		instance.call("display_card", region_name)
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var scene := load("res://scenes/ui/region_title_card.tscn") as PackedScene
			var inst: Node = null
			if scene:
				inst = scene.instantiate()
			else:
				var script_cls = load("res://scripts/ui/region_title_card.gd")
				inst = script_cls.new()
			if inst:
				tree.root.call_deferred("add_child", inst)
				inst.call_deferred("display_card", region_name)


## Kart ekrandayken true: dünya etiketleri (kapı adları) bu sürede gizlenir, kartın arkasından sızmaz.
static func is_showing() -> bool:
	if instance == null or not is_instance_valid(instance):
		return false
	var c: Control = instance.get("_container")
	return c != null and c.modulate.a > 0.02


## Oda/bölge değişti: eski sıra ve ekrandaki kart temizlenir (yeni bölge kartı hemen ardından gelir).
func _on_room_changed(_from_room: StringName, to_room: StringName) -> void:
	var to_region := String(to_room).get_slice("_", 0)
	var keep: Array[String] = []
	for q in _queue:
		if q == to_region:
			keep.append(q)
	_queue = keep
	if _current != "" and _current != to_region:
		if _tween and _tween.is_valid():
			_tween.kill()
		if _container:
			_container.modulate.a = 0.0
		_current = ""


func _is_gated() -> bool:
	return DialogueManager.is_open or UiGate.blocks_gameplay_input()


func _process(_delta: float) -> void:
	if _is_gated():
		# Kart ekrandayken diyalog/kapı açıldı: üst üste binmesin, kartı sakla ve sonra yeniden göster.
		if _container and _container.modulate.a > 0.02:
			if _tween and _tween.is_valid():
				_tween.kill()
			_container.modulate.a = 0.0
			if _current != "" and not _queue.has(_current):
				_queue.push_front(_current)
		return
	if _queue.is_empty():
		return
	_show_now(_queue.pop_front())


func display_card(region_name: String) -> void:
	if not REGION_CARDS.has(region_name):
		return
	if _is_gated():
		if not _queue.has(region_name):
			_queue.append(region_name)
		return
	_show_now(region_name)


func _show_now(region_name: String) -> void:
	var info: Dictionary = REGION_CARDS.get(region_name, {})
	if info.is_empty():
		return
	_build_ui()
	_current = region_name
	_title_label.text = String(info.get("title", ""))
	_sub_label.text = String(info.get("sub", ""))

	var am := get_node_or_null("/root/AudioManager")
	if am:
		if am.has_method("play_stinger"):
			am.play_stinger(&"discovery")
		elif am.has_method("play_sfx"):
			am.play_sfx(&"discovery")

	if _tween and _tween.is_valid():
		_tween.kill()

	_container.position.y = CARD_Y + 8.0
	_container.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_container, "position:y", CARD_Y, 2.2).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_container, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _current = "")
