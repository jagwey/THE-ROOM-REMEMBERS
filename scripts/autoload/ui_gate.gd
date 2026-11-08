extends Node
## Modal öncelik: final > mühür paneli > günlük > hikâye > normal.
## Oynanış mantığı durur; görsel animasyonlar sürmeli (tree.paused KULLANMA).

enum Layer { NONE = 0, STORY = 1, JOURNAL = 2, SEAL = 3, ENDING = 4, DEATH = 5, CUTSCENE = 6, TITLE = 7, PAUSE_MENU = 8 }

signal gate_changed(layer: Layer)

var _story: bool = false
var _journal: bool = false
var _seal: bool = false
var _ending: bool = false
var _cutscene: bool = false
var _title: bool = false
var _pause_menu: bool = false
## Referans sayacı — iç içe kaynaklar birbirinin kilidini düşürmesin.
var _pause_refs: Dictionary = {} # StringName -> bool


func _ready() -> void:
	## Ölüm katmanı DeathManager.is_dying'den okunur; bayrak değişince de sinyal ver.
	## Yoksa HUD ölümde gizlediği dokunmatik düğmeleri dirilişte geri açmıyordu.
	_connect_death.call_deferred()


func _connect_death() -> void:
	if not DeathManager.phase_changed.is_connected(_on_death_phase):
		DeathManager.phase_changed.connect(_on_death_phase)


func _on_death_phase(_p: int) -> void:
	if DeathManager.is_dying:
		MobileInputManager.clear_held_inputs()
	_emit()


func current_layer() -> Layer:
	if DeathManager.is_dying:
		return Layer.DEATH
	if _title:
		return Layer.TITLE
	if _pause_menu:
		return Layer.PAUSE_MENU
	if _cutscene:
		return Layer.CUTSCENE
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


func set_title(active: bool) -> void:
	_set_flag(&"title", active, func(v): _title = v)


func set_pause_menu(active: bool) -> void:
	_set_flag(&"pause_menu", active, func(v): _pause_menu = v)


## Göz açma vb. kısa sinematik: girdi, HUD ve diyalog ilerletme kapalı.
func set_cutscene(active: bool) -> void:
	_set_flag(&"cutscene", active, func(v): _cutscene = v)


func is_cutscene() -> bool:
	return _cutscene


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
	return layer == Layer.JOURNAL or layer == Layer.SEAL or layer == Layer.ENDING or layer == Layer.CUTSCENE or layer == Layer.TITLE or layer == Layer.PAUSE_MENU


func pauses_world_threats() -> bool:
	## Hikâye dahil tüm modallarda tehlike/timer/düşman mantığı dursun.
	return current_layer() != Layer.NONE


func allows_story_continue() -> bool:
	return current_layer() == Layer.STORY


func _emit() -> void:
	gate_changed.emit(current_layer())
