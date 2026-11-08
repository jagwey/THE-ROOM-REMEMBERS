extends Area2D
## Çekirdek seçim zemini — tek etkileşimde bir son.

@export var ending_kind: StringName = &"together"
## Etiket ekran kenarına taşarsa yatayda içeri kaydırılır (kamera oda sınırındayken kesilmesin).
var _label_shift := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	z_index = 3 ## zemin dokusu runeleri ikiye bolmesin
	queue_redraw()


func _touch() -> bool:
	return MobileInputManager.is_touch_ui()


func _label_text() -> String:
	var act := "Mührü Birlikte Kır" if ending_kind == &"together" else "Bağı Kopar"
	## Dokunmatikte [E] tuşu yok: HUD/kapı etiketleriyle aynı "El ·" öneki.
	return ("El · " + act) if _touch() else (act + " [E]")


func _process(_delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var inv := vp.get_canvas_transform().affine_inverse()
	var vis := Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
	var w := ThemeDB.fallback_font.get_string_size(_label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var sx := absf(global_scale.x) if global_scale.x != 0.0 else 1.0
	var half := w * 0.5 * sx
	var cx := global_position.x
	var shift := 0.0
	if cx + half > vis.end.x - 4.0:
		shift = (vis.end.x - 4.0) - (cx + half)
	elif cx - half < vis.position.x + 4.0:
		shift = (vis.position.x + 4.0) - (cx - half)
	shift = roundf(shift / sx)
	if shift != _label_shift:
		_label_shift = shift
		queue_redraw()


func _draw() -> void:
	## Gotik rün/sigil: zemin çizgisi, çift halka ve noktalı uçlar. Düz daire/X-A ikonu yok
	## (X dash tuşuyla karışıyordu). Eylem adı + [E] altta.
	var col := Color(0.55, 0.85, 0.95, 0.9) if ending_kind == &"together" else Color(0.95, 0.3, 0.38, 0.9)
	var dim := Color(col, 0.35)
	draw_line(Vector2(-26, 8), Vector2(26, 8), dim, 1.0)
	draw_arc(Vector2.ZERO, 15.0, 0, TAU, 24, dim, 1.0)
	draw_arc(Vector2.ZERO, 11.0, 0, TAU, 24, col, 1.0)
	if ending_kind == &"together":
		## Birbirine geçmiş iki yay + mühür ucu (bağ/birlik).
		draw_arc(Vector2(-4, 0), 7.0, -PI * 0.5, PI * 0.5, 10, col, 1.0)
		draw_arc(Vector2(4, 0), 7.0, PI * 0.5, PI * 1.5, 10, col, 1.0)
		draw_line(Vector2(0, -15), Vector2(0, -19), col, 1.0)
		draw_line(Vector2(0, 15), Vector2(0, 19), col, 1.0)
	else:
		## Koparılmış halka: iki yay arasında kırık, zikzak çatlak ve uçlarda diken.
		draw_line(Vector2(0, -11), Vector2(-3, -4), col, 1.0)
		draw_line(Vector2(-3, -4), Vector2(3, 1), col, 1.0)
		draw_line(Vector2(3, 1), Vector2(0, 11), col, 1.0)
		draw_line(Vector2(-11, 0), Vector2(-18, -3), col, 1.0)
		draw_line(Vector2(11, 0), Vector2(18, 3), col, 1.0)
	for k in 4:
		var ang := PI * 0.25 + k * PI * 0.5
		draw_circle(Vector2.from_angle(ang) * 15.0, 1.0, col)
	var f := ThemeDB.fallback_font
	var txt := _label_text()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var lx := -w * 0.5 + _label_shift
	## Dokunmatikte alt köşe düğmeleri (Atıl/Saldır) etiketi örtmesin: etiket rünün üstünde.
	var ly := -24.0 if _touch() else 24.0
	draw_string(f, Vector2(lx + 1, ly + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.85))
	draw_string(f, Vector2(lx, ly), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col.lerp(Color.WHITE, 0.5), 1.0))


func on_interact(_by: Node) -> void:
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	match ending_kind:
		&"together":
			await _do_together()
		&"sever":
			await _do_sever()
		_:
			push_error("core_choice_pad: unknown ending_kind " + String(ending_kind))


func _do_together() -> void:
	if not EndingManager.can_attempt_good_seal():
		if not EndingManager.has_both_shards():
			DialogueManager.say("Shilda", "Mühür kırık. Bir yarısı Yasak Kanat'ta, öteki Ayna Tapınağı'nda.")
		else:
			DialogueManager.say("", "Hazırlık eksik. Güven ve yollar tamamlanmalı.")
		await DialogueManager.dialogue_finished
		return
	DialogueManager.say("Noroi", "İki parça. İki ad. Tek bir anahtar.")
	DialogueManager.say("Shilda", "X'in mührünü birlikte kıralım.")
	DialogueManager.say("Noroi", "Birlikte.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"core_choice")
	await EndingManager.trigger(EndingManager.Ending.GOOD_TRUST_SEAL)


func _do_sever() -> void:
	if not EndingManager.can_attempt_sever():
		DialogueManager.say("", "Gerçeği henüz görmedin.")
		await DialogueManager.dialogue_finished
		return
	DialogueManager.say("Noroi", "Bağı koparıyorum. Anılarım bana dönsün.")
	DialogueManager.say("Shilda", "Dikkat et, Noroi… Hatırladıkların seni değiştirebilir.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	GameState.set_world_flag(&"world_lights_changed", true)
	PuzzleManager.mark_solved(&"core_choice")
	await EndingManager.trigger(EndingManager.Ending.SEVER_BOND)
