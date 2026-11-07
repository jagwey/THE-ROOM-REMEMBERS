extends Area2D
## Çekirdek seçim zemini — tek etkileşimde bir son.

@export var ending_kind: StringName = &"together"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	queue_redraw()


func _draw() -> void:
	var rune_col := Color(0.4, 0.9, 1.0, 0.85) if ending_kind == &"together" else Color(1.0, 0.35, 0.35, 0.85)
	draw_rect(Rect2(-24, -4, 48, 8), rune_col * 0.4, true)
	draw_arc(Vector2.ZERO, 16.0, 0, TAU, 16, rune_col, 2.0)
	if ending_kind == &"together":
		draw_line(Vector2(-8, 6), Vector2(0, -10), rune_col, 2.0)
		draw_line(Vector2(0, -10), Vector2(8, 6), rune_col, 2.0)
		draw_line(Vector2(-6, -2), Vector2(6, -2), rune_col, 2.0)
	else:
		draw_line(Vector2(-8, -8), Vector2(8, 8), rune_col, 2.0)
		draw_line(Vector2(8, -8), Vector2(-8, 8), rune_col, 2.0)


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
			DialogueManager.say("???", "Hazırlık eksik. Güven ve yollar tamamlanmalı.")
		await DialogueManager.dialogue_finished
		return
	DialogueManager.say("Shiren", "İki parça. İki ad. Bir mühür.")
	DialogueManager.say("Shilda", "Birlikte mühürleyelim.")
	DialogueManager.say("Shiren", "Birlikte.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	PuzzleManager.mark_solved(&"core_choice")
	await EndingManager.trigger(EndingManager.Ending.GOOD_TRUST_SEAL)


func _do_sever() -> void:
	if not EndingManager.can_attempt_sever():
		DialogueManager.say("???", "Gerçeği henüz görmedin.")
		await DialogueManager.dialogue_finished
		return
	DialogueManager.say("Shiren", "Bağı koparıyorum. Bellek serbest.")
	DialogueManager.say("Shilda", "Işıklar… başka bir düzene geçer.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	GameState.set_world_flag(&"world_lights_changed", true)
	PuzzleManager.mark_solved(&"core_choice")
	await EndingManager.trigger(EndingManager.Ending.SEVER_BOND)
