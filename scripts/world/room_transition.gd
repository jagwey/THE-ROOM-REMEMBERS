extends Area2D
## Büyük gotik kemerli kapı (arka / karanlık açıklık + ışık / ön çerçeve / mühür katmanları).
## Geçiş: etkileşim → kilit kontrolü → içeri yürüme → kararma → hedef oda (hedef kapının önünde doğ)
## → kamera → açılma → kontrol geri. Kilit durumu PuzzleManager'da (dünya hafızası) — ölümde kilitlenmez.

@export var target_room_id: StringName = &"awakening_passage"
@export var target_spawn_id: StringName = &"default"
@export var required_puzzle: StringName = &""
@export var required_ability: StringName = &""
## > 0 ise kapı yalnız toplanan geri dönüş kaydı sayısı bu değere ulaşınca açılır ("Kayıtlar N/8").
@export var required_nooks: int = 0
@export var locked_message: String = "Önce bu odanın anısını tamamlamalıyım."
@export var door_title: String = ""
## Etiketi dikeyde kaydır (yakın iki kapının etiketi üst üste binmesin diye).
@export var label_dy: float = 0.0

## Oda adları tek kaynaktan: RoomManager.ROOM_TITLES_TR (HUD başlığı, hedef, harita, kapı etiketi).
const NookCount := preload("res://scripts/world/nook_record.gd")
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
const TOUCH_AVOID_PAD := 6.0 ## etiket ile dokunmatik düğme arası (ekran px)
var _label_base_y: float = 0.0
const _REGION_CARD := preload("res://scripts/ui/region_title_card.gd")

## Büyük bölge geçişi / salon girişi kapısı (daha yüksek sütunlu niş).
@export var grand: bool = false
## Odanın taş duvarına oturan kapı, normal yürüyüşte oyuncunun arkasında çizilir.
@export var wall_recessed: bool = false

## Aynı anda tek geçiş (çift dokunuş / iki kapı birden).
static var _transitioning: bool = false

var _seal: Sprite2D
var _leaves: Sprite2D
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
	_label.size.y = 36
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.z_index = 4
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Her zaman kapının tam ortasında; sabit sağ kenar kayması yok.
	_label.position = Vector2(-_label.size.x * 0.5, FOOT_Y - _door_h - 40.0 + label_dy)
	_label_base_y = _label.position.y
	add_child(_label)
	_refresh_door_state()
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
	_label.position.y = _label_base_y ## dokunmatik kaçınma kalıcı kaymasın: her karede tabandan hesapla
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
	_avoid_touch_buttons(view)


## Dokunmatik HUD açıkken etiket düğme/joystick altında kalmasın: ekran dikdörtgenlerine çarparsa
## en üstteki çakışan düğmenin üstüne çıkar; kadraj üstüne sığmazsa yana kayar.
func _avoid_touch_buttons(view: Rect2) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("get_touch_button_screen_rects"):
		return
	var rects: Array = hud.get_touch_button_screen_rects()
	if rects.is_empty():
		return
	var xf := _label.get_global_transform_with_canvas()
	var sc := xf.get_scale()
	if sc.x <= 0.0 or sc.y <= 0.0:
		return
	var start_y := _label.global_position.y
	var start_x := _label.global_position.x
	for _i in 4:
		var lr: Rect2 = _label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _label.size)
		var top := INF
		for r in rects:
			if lr.intersects(r as Rect2):
				top = minf(top, (r as Rect2).position.y)
		if top == INF:
			if lr.position.y >= 0.0:
				return
			break ## yukarı kadraj dışına çıktı: yana kay
		_label.global_position.y -=(lr.end.y - top + TOUCH_AVOID_PAD) / sc.y
	# Hâlâ çakışıyor (yukarı sığmadı): başlangıca dön, yana kay.
	_label.global_position = Vector2(start_x, start_y)
	for _i in 4:
		var lr2: Rect2 = _label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _label.size)
		var left := INF
		for r in rects:
			if lr2.intersects(r as Rect2):
				left = minf(left, (r as Rect2).position.x)
		if left == INF:
			return
		_label.global_position.x -= (lr2.end.x - left + TOUCH_AVOID_PAD) / sc.x


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


func _nooks_missing() -> bool:
	return required_nooks > 0 and NookCount.count() < required_nooks


func is_locked() -> bool:
	return _ability_blocked() or _nooks_missing() or (required_puzzle != &"" and not PuzzleManager.is_solved(required_puzzle))


func _build_visuals() -> void:
	var art: Dictionary = GothicDoorArt.get_textures(grand)
	var sz: Vector2 = art["size"]
	_door_h = sz.y
	var cy := FOOT_Y - sz.y * 0.5
	_add_art_layer("DoorBack", art["back"], cy, 1)
	_leaves = _add_art_layer("DoorLeaves", art["leaves"], cy, 1)
	_glow = _add_art_layer("DoorInnerLight", art["threshold"], cy, 1)
	_add_art_layer("DoorFrame", art["frame"], cy, 2)
	_seal = _add_art_layer("DoorSeal", art["seal"], FOOT_Y - float(art["seal_y"]), 2)
	if String(required_puzzle).begins_with("soul_seal"):
		_seal.modulate = Color(0.7, 0.56, 1.0)


func _add_art_layer(layer_name: String, texture: Texture2D, y: float, depth: int) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.name = layer_name
	layer.texture = texture
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.position.y = y
	layer.z_index = 0 if wall_recessed else depth
	add_child(layer)
	return layer


func _refresh_door_state() -> void:
	var locked := is_locked()
	_leaves.visible = locked
	_seal.visible = locked
	_glow.visible = not locked
	var hint := "Mühürlü"
	if not locked:
		hint = "El · Geç" if MobileInputManager.is_touch_ui() else "[E] Geç"
	var caption := "%s\n%s" % [get_display_name(), hint]
	if _label.text != caption:
		_label.text = caption
		_label.size.x = _label.get_minimum_size().x + 12.0


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
	_refresh_door_state()
	_phase += delta * 1.7
	if _label.visible:
		_clamp_door_label()
	if _glow.visible:
		_glow.modulate.a = 0.90 + 0.10 * sin(_phase)
	if _seal.visible:
		_seal.modulate.a = 0.85 + 0.15 * sin(_phase * 1.3)


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
			msg = "Bu geçidi Gölge Atılması'yla geç."
		elif _nooks_missing():
			msg = "Kayıtlar %d/%d. Geri dönüş köşelerinde eksik kayıtlar var." % [NookCount.count(), required_nooks]
		## Ruh mührü: yetenek yoksa "nerede bulunur", varsa "nasıl açılır" söylenir (genel varyantlar yanıltmasın).
		elif String(required_puzzle).begins_with("soul_seal"):
			var has_slash := bool(GameState.player_progress_knowledge.get("ability_soul_slash", false))
			if has_slash:
				msg = "Mor mühür. Q ile (mobilde yıldız düğmesi) Ruh Kesimi'ni kullan."
			elif idx % 2 == 0:
				msg = "Mor mühür kılıçla açılmıyor. Ruhumla kesmeyi henüz bilmiyorum."
			else:
				msg = "Bu mührü kıracak gücü eski kitaplarda ara."
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
			DialogueManager.say(GameState.keeper_speaker_name(), "Mühür parçaların eksik. Böyle girersen geri döneceksin.")
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


## Hızlı seyahat (defter haritası) kapı dışından aynı kilidi kurar.
static func begin_transition_lock() -> void:
	_transitioning = true


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


## Keşfedilmesi gereken kapıya soluk, nabız atan ek ışık (main.gd ve built_room paylaşır).
static func add_door_mark(door: Area2D) -> void:
	var mark := Sprite2D.new()
	mark.name = "DoorMark"
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.55, 1.0, 0.5))
	grad.set_color(1, Color(0.5, 0.35, 0.9, 0.0))
	gt.gradient = grad
	mark.texture = gt
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mark.material = mat
	mark.position = Vector2(0, -60)
	mark.scale = Vector2(2.4, 3.2)
	mark.z_index = 1
	door.add_child(mark)
	var tw := mark.create_tween().set_loops()
	tw.tween_property(mark, "modulate:a", 0.45, 1.4)
	tw.tween_property(mark, "modulate:a", 1.0, 1.4)
