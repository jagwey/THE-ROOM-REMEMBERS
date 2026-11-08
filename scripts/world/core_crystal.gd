extends Area2D
## Çekirdek kristal — bilgi. Seçim yan zeminde.


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
	CurseManager.add_curse(8.0, &"core_adjacent")
	var st: Dictionary = EndingManager.prep_status()
	var cg := EndingManager.can_attempt_good_seal()
	var cs := EndingManager.can_attempt_sever()
	if not cg and not cs:
		DialogueManager.say("Noroi", "Çekirdek uğulduyor… bir şeyler eksik.")
		if not st["weight"]:
			DialogueManager.say("", "Ağırlık yolu kapalı.")
		if not st["code"]:
			DialogueManager.say("", "Sayıyı henüz bilmiyorsun.")
		if not st["echo"]:
			DialogueManager.say("", "Yankı yok.")
		if not st["trusted"]:
			DialogueManager.say("", "Shilda'ya henüz güvenmedin.")
		if not st["truth"]:
			DialogueManager.say("", "Gerçeği henüz görmedin.")
		DialogueManager.say("Noroi", "Sadece konuşmak yetmez.")
		await DialogueManager.dialogue_finished
		return
	DialogueManager.say("Shilda", "Sağda mührü birlikte kırmak, solda bağı koparmak var.")
	DialogueManager.say("Noroi", "Yanlış zemine dokunursam geri dönemem.")
	await DialogueManager.dialogue_finished
