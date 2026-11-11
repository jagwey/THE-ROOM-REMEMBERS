extends Area2D
## Büyük gotik kemerli kapı (arka / karanlık açıklık + ışık / ön çerçeve / mühür katmanları).
## Geçiş: etkileşim → kilit kontrolü → içeri yürüme → kararma → hedef oda (hedef kapının önünde doğ)
## → kamera → açılma → kontrol geri. Kilit durumu PuzzleManager'da (dünya hafızası) — ölümde kilitlenmez.

@export var target_room_id: StringName = &"awakening_passage"
@export var target_spawn_id: StringName = &"default"
@export var required_puzzle: StringName = &""
@export var required_ability: StringName = &""
@export var locked_message: String = "Önce bu odanın hatırasını tamamlamalıyım."
@export var door_title: String = ""

## Oda adları tek kaynaktan: RoomManager.ROOM_TITLES_TR (HUD başlığı, hedef, harita, kapı etiketi).
const ROOM_TITLES: Dictionary = preload("res://scripts/autoload/room_manager.gd").ROOM_TITLES_TR

const LOCKED_VARIANTS := [
	"Kapı mühürlenmiş.",
	"Bu sembolü daha önce gördüm mü?",
	"Bir şey bu kapıyı içeriden tutuyor.",
]
## Kapı tabanı zemin çizgisi (y=288); kapı düğümü bu yüksekliğe oturtulur.
const FLOOR_Y := 288.0
const FOOT_Y := 0.0
const GothicDoorArt := preload("res://scripts/world/gothic_door_art.gd")
const WALK_TIME := 0.22
const FADE_OUT := 0.26
const FADE_IN := 0.3
const LABEL_MARGIN := 16.0
const _REGION_CARD := preload("res://scripts/ui/region_title_card.gd")

## Büyük bölge geçişi / salon girişi kapısı (daha yüksek sütunlu niş).
@export var grand: bool = false

## Aynı anda tek geçiş (çift dokunuş / iki kapı birden).
static var _transitioning: bool = false

var _seal: Sprite2D
var _glow: Sprite2D
var _label: Label
var _door_h: float = 116.0
var _locked_tries: int = 0
var _last_locked_ms: int = -10000
var _phase: float = 0.0
var _in_travel: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("room_door")
	reset_transition_lock()
	if not RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.connect(_on_room_changed)
	## Eski kapılar y≈268'e konmuştu; zemin 288 — kapı tabanı tam zeminde olsun.
	if position.y > 250.0 and position.y < 300.0:
		position.y = FLOOR_Y
	if not grand:
		grand = _is_grand_target()
	_build_visuals()
	_label = Label.new()
	_label.name = "DoorLabel"
	_label.size = Vector2(220, 36)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	var touch := MobileInputManager.is_touch_ui()
	var hint := "El · Geç" if touch else "[E] Geç"
	_label.text = "%s\n%s" % [get_display_name(), hint]
	_label.z_index = 4
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Her zaman kapının tam ortasında; sabit sağ kenar kayması yok.
	_label.position = Vector2(-_label.size.x * 0.5, FOOT_Y - _door_h - 40.0)
	add_child(_label)
	call_deferred("_clamp_door_label")
	if not UiGate.gate_changed.is_connected(_on_gate_changed):
		UiGate.gate_changed.connect(_on_gate_changed)
	_on_gate_changed(UiGate.current_layer())
	## Etkileşim alanı: kapı açıklığı + biraz pay (programatik kapıda şekil adı farklı olabilir).
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		for c in get_children():
			if c is CollisionShape2D:
				cs = c
				break
	if cs == null:
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	## Gotik kapı görseline hizalı etkileşim kutusu (açıklık genişliği + yüksekliğin %90'ı).
	var art_sizes: Dictionary = GothicDoorArt.get_textures(grand)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(64.0, float(art_sizes["opening_w"]) + 12.0), _door_h * 0.9)
	cs.shape = rect
	cs.position = Vector2(0.0, FOOT_Y - rect.size.y * 0.5)
	call_deferred("_hide_legacy_door_sprites")


func _exit_tree() -> void:
	reset_transition_lock()
	if UiGate.gate_changed.is_connected(_on_gate_changed):
		UiGate.gate_changed.disconnect(_on_gate_changed)
	if RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.disconnect(_on_room_changed)


func _on_room_changed(_from: StringName, to: StringName) -> void:
	## Aktif geçiş varken diğer kapılar kilidi düşürmesin (fade yarım kalır / HUD yarışır).
	## Geçiş RoomManager üzerinde yürür; oda PROCESS_MODE_DISABLED olsa bile await sürer.
	if is_transitioning():
		return
	_in_travel = false
	reset_transition_lock()


## Ana bölge (ilk "_" öncesi) hedefle farklıysa büyük kapı.
func _is_grand_target() -> bool:
	var room := _find_room()
	if room == null or not ("room_id" in room):
		return false
	var here := String(room.room_id).split("_")[0]
	var there := String(target_room_id).split("_")[0]
	return here != there


func _find_room() -> Node:
	var room: Node = get_parent()
	while room and not ("room_id" in room):
		room = room.get_parent()
	return room


func _on_gate_changed(layer) -> void:
	if _label:
		_label.visible = int(layer) == int(UiGate.Layer.NONE)


## Etiketi kapı ortasında tut; oda sınırı VE aktif Camera2D görüş alanı içinde 16 px payla sıkıştır.
func _clamp_door_label() -> void:
	if not is_inside_tree() or _label == null:
		return
	var room := _find_room()
	var bounds := Rect2(0.0, 0.0, 960.0, 360.0)
	if room != null:
		var b := RoomManager.get_room_bounds(StringName(room.room_id))
		if b.size.x > 0.0:
			bounds = b
	var w := _label.size.x
	# Önce kapı ortasına geri al, sonra sınırlara sıkıştır (kamera kayarken yeniden hesaplanır).
	var gx := global_position.x - w * 0.5
	var lo := bounds.position.x + LABEL_MARGIN
	var hi := bounds.end.x - LABEL_MARGIN - w
	var view := _camera_view_rect()
	# Kapının kendisi kadrajda değilse etiketi gizle: ekran dışı kapıların etiketleri kenara yığılıp üst üste binmesin.
	if view.size.x > 0.0:
		var on_screen := global_position.x >= view.position.x - 8.0 and global_position.x <= view.end.x + 8.0
		var card_up: bool = _REGION_CARD.is_showing()
		_label.modulate.a = 1.0 if (on_screen and not card_up) else 0.0
	if view.size.x > 0.0:
		lo = maxf(lo, view.position.x + LABEL_MARGIN)
		hi = minf(hi, view.end.x - LABEL_MARGIN - w)
	if hi >= lo:
		gx = clampf(gx, lo, hi)
	else:
		gx = clampf(gx, lo, lo) if view.size.x > 0.0 and w > view.size.x - 2.0 * LABEL_MARGIN else gx
	_label.global_position.x = gx
	if view.size.x > 0.0:
		var gy := _label.global_position.y
		_label.global_position.y = clampf(gy, view.position.y + LABEL_MARGIN, maxf(view.position.y + LABEL_MARGIN, view.end.y - LABEL_MARGIN - _label.size.y))


## Aktif Camera2D'nin dünya koordinatındaki görüş dikdörtgeni; kamera yoksa boş Rect2.
func _camera_view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var cam := vp.get_camera_2d()
	if cam == null:
		return Rect2()
	var size := vp.get_visible_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)


func get_display_name() -> String:
	return door_title if not door_title.is_empty() else String(ROOM_TITLES.get(String(target_room_id), "Geçit"))


## Etkileşim ışığı rengi: kilitli = lanet kırmızısı, açık = normal krem.
func get_glow_kind() -> StringName:
	return &"cursed" if is_locked() else &"normal"


func get_interact_label() -> String:
	return "Mühürlü Kapı" if is_locked() else get_display_name()


func _ability_blocked() -> bool:
	return required_ability != &"" and not bool(GameState.player_progress_knowledge.get(String(required_ability), false))


func is_locked() -> bool:
	return _ability_blocked() or (required_puzzle != &"" and not PuzzleManager.is_solved(required_puzzle))


func _build_visuals() -> void:
	var art: Dictionary = GothicDoorArt.get_textures(grand)
	var sz: Vector2 = art["size"]
	_door_h = sz.y
	var cy := FOOT_Y - sz.y * 0.5 ## Sprite merkezi: taban tam zeminde (y=0).
	var back := Sprite2D.new()
	back.name = "DoorBack"
	back.texture = art["back"]
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.position = Vector2(0, cy)
	back.z_index = 1
	add_child(back)
	## Karanlığın içinden yükselen soluk kırmızı/mor ışık (ucuz: tek additive sprite).
	_glow = Sprite2D.new()
	_glow.name = "DoorInnerLight"
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.18, 0.3, 0.32))
	grad.set_color(1, Color(0.3, 0.18, 0.4, 0.0))
	gt.gradient = grad
	_glow.texture = gt
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.position = Vector2(0, FOOT_Y - 12.0)
	_glow.scale = Vector2(float(art["opening_w"]) / 64.0 * 0.9, 0.9)
	_glow.z_index = 1
	add_child(_glow)
	var frame := Sprite2D.new()
	frame.name = "DoorFrame"
	frame.texture = art["frame"]
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.position = Vector2(0, cy)
	frame.z_index = 2
	add_child(frame)
	_seal = Sprite2D.new()
	_seal.name = "DoorSeal"
	_seal.texture = art["seal"]
	_seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seal.position = Vector2(0, FOOT_Y - float(art["seal_y"]))
	_seal.z_index = 2
	add_child(_seal)
	_refresh_seal()


func _refresh_seal() -> void:
	if _seal:
		_seal.visible = is_locked()


## Sahnelerde elle konmuş eski küçük kapı görsellerini gizle (çift kapı görünmesin).
func _hide_legacy_door_sprites() -> void:
	var p := get_parent()
	if p == null:
		return
	for c in p.get_children():
		if c is Sprite2D and (c as Sprite2D).texture:
			var path := String((c as Sprite2D).texture.resource_path)
			if (path.ends_with("door_open.png") or path.ends_with("door_closed.png")) \
					and absf((c as Sprite2D).position.x - position.x) < 48.0:
				(c as Sprite2D).visible = false


func _process(delta: float) -> void:
	_phase += delta * 1.7
	if _label and _label.visible:
		_clamp_door_label()
	if _glow:
		_glow.modulate.a = 0.75 + 0.25 * sin(_phase)
	if _seal:
		var locked := is_locked()
		if _seal.visible != locked:
			_seal.visible = locked
		if locked:
			_seal.modulate = Color(1, 1, 1, 0.8 + 0.2 * sin(_phase * 1.3))


func on_interact(by: Node) -> void:
	if not is_visible_in_tree() or _transitioning or DeathManager.is_dying:
		return
	if is_locked():
		var now := Time.get_ticks_msec()
		if now - _last_locked_ms < 700:
			return ## Tekrar tetiklenme koruması.
		_last_locked_ms = now
		var idx := _locked_tries % 4
		_locked_tries += 1
		var msg: String = locked_message if idx == 0 else String(LOCKED_VARIANTS[idx - 1])
		## Yetenek kilidi sabit cümle kullanır; mühür kapılarındaki LOCKED_VARIANTS döngüsü aynı kalır.
		if _ability_blocked():
			msg = "Bu geçit için Gölge Atılması gerek."
		## Ruh mührü: yetenek yoksa "nerede bulunur", varsa "nasıl açılır" söylenir (genel varyantlar yanıltmasın).
		elif String(required_puzzle).begins_with("soul_seal"):
			var has_slash := bool(GameState.player_progress_knowledge.get("ability_soul_slash", false))
			if has_slash:
				msg = "Mor mühür. Ruh Kesimi'ni savur (Q / yıldız düğmesi)."
			elif idx % 2 == 0:
				msg = "Mor bir mühür. Kılıç işlemez… ruhumla kesmeyi henüz bilmiyorum."
			else:
				msg = "Mor bir mühür. Bunu kıracak güç… belki eski kitapların arasında saklı."
		AudioManager.play_sfx(&"seal_key", -8.0, 0.55)
		_shake_seal()
		DialogueManager.say("Noroi", msg)
		return
	if not RoomManager.has_room(target_room_id):
		push_warning("room_transition: unknown room %s" % String(target_room_id))
		return
	if target_room_id == &"core" and not EndingManager.has_both_shards():
		if not bool(GameState.character_current_life_knowledge.get("warned_core_shards", false)):
			GameState.character_current_life_knowledge["warned_core_shards"] = true
			DialogueManager.say(GameState.keeper_speaker_name(), "Çekirdek açılacak… ama mühür parçaların eksik. Eksik girersen geri dönersin.")
			return
	_travel(by)


func _shake_seal() -> void:
	if _seal == null:
		return
	var x0 := 0.0
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_seal, "position:x", x0 + (2.0 if i % 2 == 0 else -2.0), 0.04)
	tw.tween_property(_seal, "position:x", x0, 0.04)


func _travel(by: Node) -> void:
	## Kapı düğümü eski odada PROCESS_MODE_DISABLED olur; await burada kalırsa UiGate CUTSCENE
	## ve DoorFade asılı kalır → joystick/hareket kaybolur. Geçişi her zaman aktif RoomManager yürütür.
	_transitioning = true
	_in_travel = true
	var tree := get_tree()
	if tree == null:
		reset_transition_lock()
		return
	UiGate.set_cutscene(true)
	MobileInputManager.clear_held_inputs()
	AudioManager.play_sfx(&"door_open", -4.0)
	var cam := tree.get_first_node_in_group("follow_camera")
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.12)
	var player := by as Node2D
	if player == null or not player.is_in_group("player"):
		player = tree.get_first_node_in_group("player") as Node2D
	var fade := _make_fade(tree)
	var rect := fade.get_child(0) as ColorRect if fade and fade.get_child_count() > 0 else null
	if rect == null:
		if is_instance_valid(fade):
			fade.queue_free()
		reset_transition_lock()
		return
	RoomManager.run_door_travel(self, player, fade, rect)


## RoomManager tarafından çağrılır (autoload: oda disable'dan etkilenmez).
func finish_travel_flags() -> void:
	_in_travel = false


static func _end_walk(player: Node) -> void:
	if is_instance_valid(player) and "scripted_walk" in player:
		player.set("scripted_walk", false)


static func is_transitioning() -> bool:
	return _transitioning


static func reset_transition_lock() -> void:
	_transitioning = false
	UiGate.set_cutscene(false)
	## clear_held_inputs burada çağrılmaz: her oda değişiminde (geçiş yokken de)
	## nötr-joystick kilidi yeniden kuruluyor ve bir sonraki adım yutuluyordu.
	## Kilit, geçişin başında _travel içinde kurulur; parmak hâlâ basılıysa orada kalır.
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		for c in tree.root.get_children():
			if is_instance_valid(c) and c is CanvasLayer and (c.name == "DoorFade" or c.name.begins_with("DoorFade")):
				c.queue_free()
	## Ölümdeki gate_changed kaçırma hatasının kapı eşi: HUD'u her kilit çözülüşünde yenile.
	if tree:
		var hud := tree.get_first_node_in_group("hud")
		if hud and hud.has_method("refresh_touch_controls"):
			hud.call("refresh_touch_controls")


func _make_fade(tree: SceneTree) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "DoorFade"
	layer.layer = 90
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.04, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(r)
	tree.root.add_child(layer)
	return layer
