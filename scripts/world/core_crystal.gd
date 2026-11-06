extends Area2D
## Çekirdek — iyi son için hazırlık + güven gerekir.


func _ready() -> void:
	add_to_group("core_crystal")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if has_node("Sprite2D"):
		$Sprite2D.texture = load("res://assets/layers/core_crystal.png")
		$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func on_interact(_by: Node) -> void:
	if EndingManager.current != EndingManager.Ending.NONE:
		return
	CurseManager.add_curse(12.0, &"core_adjacent")
	if EndingManager.can_attempt_good_seal():
		DialogueManager.say("Sen", "Mühürleri… birleştiriyorum.")
		DialogueManager.say("Bekçi", "…Teşekkür ederim.")
		await DialogueManager.dialogue_closed
		await EndingManager.trigger(EndingManager.Ending.GOOD_TRUST_SEAL)
		return
	var st: Dictionary = EndingManager.prep_status()
	DialogueManager.say("Sen", "Çekirdek uğultulu… eksikler var.")
	if not st["weight"]:
		DialogueManager.say("???", "Ağırlık yolu kapalı.")
	if not st["code"]:
		DialogueManager.say("???", "Sayı henüz senin değil.")
	if not st["echo"]:
		DialogueManager.say("???", "Yankı yok.")
	if not st["trusted"]:
		DialogueManager.say("???", "Bekçi'ye… güvenmedin.")
	DialogueManager.say("Sen", "Sadece konuşmak yetmez.")
