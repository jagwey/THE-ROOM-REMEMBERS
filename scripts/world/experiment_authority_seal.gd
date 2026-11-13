extends "res://scripts/world/code_seal_base.gd"
## Yetki masası mührü — kod 418 (hücre A/B kayıtları ve kabul kaydı hanelerini verir).

const LorePointScript := preload("res://scripts/world/lore_point.gd")


func _on_solved() -> void:
	GameState.set_story_flag(&"shilda_past_discovered")
	GameState.set_world_flag(&"mirrors_unlocked", true)
	LorePointScript.record_evidence("ev_authority", "Yetki masası", "Yetki masasındaki imza kazınmış; kayıtta silik bir fısıltı izi kaldı. Mühür üç hanelik bir kodla açıldı. Düzeni kimin kurduğu okunmuyor.", "gunluk")
