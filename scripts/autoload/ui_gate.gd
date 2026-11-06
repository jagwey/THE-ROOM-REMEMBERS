extends Node
## Modal öncelik: final > mühür paneli > günlük > hikâye > normal.
## Oynanış mantığı durur; görsel animasyonlar sürmeli (tree.paused KULLANMA).

enum Layer { NONE = 0, STORY = 1, JOURNAL = 2, SEAL = 3, ENDING = 4, DEATH = 5 }

signal gate_changed(layer: Layer)

var _story: bool = false
var _journal: bool = false
var _seal: bool = false
var _ending: bool = false
## Referans sayacı — iç içe kaynaklar birbirinin kilidini düşürmesin.
var _pause_refs: Dictionary = {} # StringName -> bool


func current_layer() -> Layer:
	if DeathManager.is_dying:
		return Layer.DEATH
	if _ending:
		return Layer.ENDING
	if _seal:
		return Layer.SEAL
	if _journal:
		return Layer.JOURNAL
	if _story:
		return Layer.STORY
	return Layer.NONE


func set_story(active: bool) -> void:
	_set_flag(&"story", active, func(v): _story = v)


func set_journal(active: bool) -> void:
	_set_flag(&"journal", active, func(v): _journal = v)


func set_seal(active: bool) -> void:
	_set_flag(&"seal", active, func(v): _seal = v)


func set_ending(active: bool) -> void:
	_set_flag(&"ending", active, func(v): _ending = v)


func _set_flag(key: StringName, active: bool, apply: Callable) -> void:
	var was := bool(_pause_refs.get(key, false))
	if was == active:
		return
	_pause_refs[key] = active
	apply.call(active)
	if active:
		MobileInputManager.clear_held_inputs()
	_emit()


func blocks_gameplay_input() -> bool:
	return current_layer() != Layer.NONE


func blocks_movement() -> bool:
	return blocks_gameplay_input()


func blocks_combat() -> bool:
	return blocks_gameplay_input()


func blocks_dialogue_advance() -> bool:
	## Günlük / mühür / final açıkken alttaki hikâye diyaloğu ilerletilmez.
	var layer := current_layer()
	return layer == Layer.JOURNAL or layer == Layer.SEAL or layer == Layer.ENDING


func pauses_world_threats() -> bool:
	## Hikâye dahil tüm modallarda tehlike/timer/düşman mantığı dursun.
	return current_layer() != Layer.NONE


func allows_story_continue() -> bool:
	return current_layer() == Layer.STORY


func _emit() -> void:
	gate_changed.emit(current_layer())
