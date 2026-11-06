extends Area2D
## Çekirdek seçim zemini — tek etkileşimde bir son.

@export var ending_kind: StringName = &"together"


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true


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
		DialogueManager.say("???", "Hazırlık eksik. Güven ve yollar tamamlanmalı.")
		await DialogueManager.dialogue_finished
		return
	DialogueManager.say("Şiren", "Buradayım.")
	DialogueManager.say("Şilda", "Birlikte mühürleyelim.")
	DialogueManager.say("Sen", "Birlikte mühürleme.")
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
	DialogueManager.say("Sen", "Bağı koparıyorum. Bellek serbest.")
	DialogueManager.say("Şilda", "Işıklar… başka bir düzene geçer.")
	var ok: bool = await DialogueManager.dialogue_finished
	if not ok:
		return
	GameState.set_world_flag(&"world_lights_changed", true)
	PuzzleManager.mark_solved(&"core_choice")
	await EndingManager.trigger(EndingManager.Ending.SEVER_BOND)
