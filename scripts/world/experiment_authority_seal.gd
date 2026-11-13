extends "res://scripts/world/code_seal_base.gd"
## Yetki masası mührü — kod 418 (hücre A/B kayıtları ve kabul kaydı hanelerini verir).

const LorePointScript := preload("res://scripts/world/lore_point.gd")


## Mühür, masadaki kayıt (AuthBeat) okunmadan açılmaz.
func _requirements_met() -> bool:
	var ev: Dictionary = GameState.player_progress_knowledge.get("evidence", {})
	return ev.has("ev_authority_desk")


func _on_solved() -> void:
	GameState.set_world_flag(&"mirrors_unlocked", true)
	LorePointScript.record_evidence("ev_authority", "Yetki masası", "Yetki masasındaki imza kazınmış; kayıtta silik bir fısıltı izi kaldı. Mühür üç hanelik bir kodla açıldı. Düzeni kimin kurduğu okunmuyor.", "gunluk")
