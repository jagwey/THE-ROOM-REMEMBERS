extends Node
## Tek final: BÖLÜM I SONU. Mühür kırılır, Shilda insan formuna döner, X belirir (FinalSequence).
## Seçim/ölüm finali yok; Shilda öldürülemez. Dizi bitince giriş kilidi kalmaz.

signal ending_reached(ending_id: StringName)

enum Ending { NONE, PART_ONE }

var current: Ending = Ending.NONE
## Son tetiklenen final — dizi sonrası current sıfırlansa da smoke/UI doğrulayabilsin.
var last_ending: Ending = Ending.NONE
var _locked: bool = false


## Final için: çekirdek mührü çözülmüş, iki mühür parçası toplanmış, Ruh Kesimi açık.
func can_begin_final() -> bool:
	return PuzzleManager.is_solved(&"core_seal") and has_both_shards() and has_soul_slash()


## Ruh Kesimi (mührü kıran güç). Oyuncu henüz yoksa world flag'e bakılır.
func has_soul_slash() -> bool:
	return bool(GameState.player_progress_knowledge.get("ability_soul_slash", false))


## İki mühür parçası (Yasak Kanat + Ayna Tapınağı) çekirdek mührü için gerekir.
func has_both_shards() -> bool:
	return bool(GameState.get_world_flag(&"seal_shard_1", false)) and bool(GameState.get_world_flag(&"seal_shard_2", false))


func prep_status() -> Dictionary:
	return {
		"weight": PuzzleManager.is_solved(&"awakening_weight"),
		"code": PuzzleManager.is_solved(&"awakening_memory_code"),
		"echo": bool(GameState.player_progress_knowledge.get("echoes_seen", []).size() > 0),
		"trusted": bool(GameState.player_progress_knowledge.get("trusted_keeper", false)),
		"truth": bool(GameState.player_progress_knowledge.get("truth_seen", false)),
		"shards": has_both_shards(),
		"slash": has_soul_slash(),
	}


func reset_for_smoke() -> void:
	_locked = false
	current = Ending.NONE
	last_ending = Ending.NONE
	UiGate.set_ending(false)


## Tek final. FinalSequence sahneyi oynatır; bitince kilit açılır (return_to_title sahneyi zaten yeniler).
func trigger(ending: Ending, fast: bool = false) -> void:
	if _locked or ending == Ending.NONE:
		return
	_locked = true
	current = ending
	last_ending = ending
	var id: StringName = &"part_one"
	var seen: Array = GameState.player_progress_knowledge["endings_seen"]
	if not seen.has(String(id)):
		seen.append(String(id))
	ending_reached.emit(id)
	await FinalSequence.new().play(get_tree(), fast)
	_locked = false
	current = Ending.NONE
	UiGate.set_ending(false)
