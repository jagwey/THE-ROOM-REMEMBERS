extends Node
## Son yolları stub — kötü: Bekçi'yi öldür; iyi: güven + Çekirdek mühür.

signal ending_reached(ending_id: StringName)

enum Ending { NONE, BAD_KILL_KEEPER, GOOD_TRUST_SEAL }

var current: Ending = Ending.NONE


func trigger(ending: Ending) -> void:
	current = ending
	var id: StringName
	match ending:
		Ending.BAD_KILL_KEEPER:
			id = &"bad_kill_keeper"
		Ending.GOOD_TRUST_SEAL:
			id = &"good_trust_seal"
		Ending.NONE:
			return
		_:
			id = &"unknown"
	var seen: Array = GameState.player_progress_knowledge["endings_seen"]
	if not seen.has(String(id)):
		seen.append(String(id))
	ending_reached.emit(id)
