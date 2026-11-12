extends Area2D
## Çekirdek kristal — hazırsa tek finali (BÖLÜM I SONU) başlatır; değilse eksikleri söyler.


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
	if GameState.has_story_flag(&"game_completed"):
		DialogueManager.say("Noroi", "Kristal sustu, artık söyleyeceği bir şey yok.")
		await DialogueManager.dialogue_finished
		return
	if EndingManager.can_begin_final():
		await EndingManager.trigger(EndingManager.Ending.PART_ONE)
		return
	CurseManager.add_curse(8.0, &"core_adjacent")
	var st: Dictionary = EndingManager.prep_status()
	DialogueManager.say("Noroi", "Çekirdek uğulduyor, mühür hâlâ sağlam.")
	if not PuzzleManager.is_solved(&"core_seal"):
		DialogueManager.say("", "Mühür odasındaki bağlar henüz çözülmedi.")
	if not st["shards"]:
		DialogueManager.say("", "İki mühür parçası da gerekiyor.")
	if not st["slash"]:
		DialogueManager.say("", "Bağları kesecek güç henüz uyanmadı: Ruh Kesimi.")
	await DialogueManager.dialogue_finished
