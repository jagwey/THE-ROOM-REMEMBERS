extends Node
## Üç hafıza katmanı — karakter ölünce sıfırlanır; dünya/oyuncu kalır.

const CampaignObjectives := preload("res://scripts/story/campaign_objectives.gd")

signal knowledge_changed(layer: StringName)
signal room_changed(room_id: StringName)
signal hearts_changed(current: int, maximum: int)
signal world_flag_changed(flag: StringName, value: Variant)
signal story_flag_changed(id: StringName, value: bool)

const MAX_HEARTS := 3
const DEFAULT_CHECKPOINT := Vector2(120, 280)

## Oyuncu meta bilgisi (ölümler arası kalır).
var player_progress_knowledge: Dictionary = {
	"deaths": 0,
	"seen_keeper": false,
	"awakening_mystery_seen": false,
	"pocket_watch_seen": false,
	"shilda_named": false,
	"first_death_seen": false,
	"rooms_visited": [],
	"journal_unlocked": false,
	"journal_notes": [],
	"echoes_seen": [],
	"memory_codes": {},
	"endings_seen": [],
}

## Bu hayatın karakter bilgisi (ölümde sıfırlanır).
var character_current_life_knowledge: Dictionary = {
	"room": &"awakening",
	"checkpoint": DEFAULT_CHECKPOINT,
	"checkpoint_room": &"awakening",
	"spawn_id": &"default",
	"interacted": [],
	"dialogue_flags": {},
	"warned_hazard": false,
}

## Dünya hafızası (kalıcı).
var world_memory_state: Dictionary = {
	"corpses": [], ## fiziksel, max 3
	"traces": [], ## çiçek / leke / silüet (fazla ceset dönüşümü)
	"echo_sites": [],
	"keeper_mood": &"observe",
	"flowers_left": 0,
	"forbidden_touched": [],
	## kırık / açık dünya bayrakları
	"flags": {
		"awakening_door_opened": false,
		"awakening_trap_sprung": false,
		"awakening_crystal_cracked": false,
		"hazard_rift_seen": false,
	},
	## Bulmaca çözümleri — string id -> bool (kalıcı).
	"puzzles": {},
}

## Hikâye durumu bayrakları (v3, kalıcı): StringName -> bool. Kayıtta String anahtarlı yazılır.
const STORY_FLAGS := [
	&"intro_completed", &"first_shadow_seen", &"first_warning_heard", &"first_death_completed",
	&"first_corpse_discovered", &"shilda_name_known", &"first_archive_record_read",
	&"dimension_origin_discovered", &"shilda_past_discovered", &"core_access_granted",
	&"final_seal_broken", &"x_revealed", &"game_completed",
]
var story_flags: Dictionary = {}
## Etkinleştirilmiş Hafıza Mühürleri (oda id). Uyanış mührü her zaman açıktır.
var discovered_seals: Array[StringName] = [&"awakening"]
## Lanet ele geçirilme sayısı (kalıcı; ilk sekans uzun, tekrarlar kısa). Kayıt yüklemesi onu düşürmez (bkz. SaveManager._apply_data).
var possession_count: int = 0

var hearts: int = MAX_HEARTS
var max_hearts: int = MAX_HEARTS

## Bu oturumda kayıt yüklendiyse Player._ready varsayılan checkpoint yazmasın.
var session_loaded_from_save: bool = false


func _ready() -> void:
	hearts_changed.emit(hearts, max_hearts)


## Yeni yaşam: Noroi'nin bu hayata ait bilgisi tamamen silinir. Normal ölüm her zaman
## Uyanış yatağında doğurur; önceki hayatın uzak checkpoint'i yeni hayata taşınmaz.
## (Dünya hafızası ve oyuncu ilerlemesi burada DEĞİŞMEZ.)
func reset_character_life() -> void:
	character_current_life_knowledge = {
		"room": &"awakening",
		"checkpoint": DEFAULT_CHECKPOINT,
		"checkpoint_room": &"awakening",
		"spawn_id": &"rebirth_bed",
		"interacted": [],
		"dialogue_flags": {},
		"warned_hazard": false,
	}
	hearts = max_hearts
	hearts_changed.emit(hearts, max_hearts)
	knowledge_changed.emit(&"character")


func get_checkpoint() -> Vector2:
	var cp: Variant = character_current_life_knowledge.get("checkpoint", DEFAULT_CHECKPOINT)
	if cp is Vector2:
		return cp
	if cp is Dictionary:
		return Vector2(float(cp.get("x", DEFAULT_CHECKPOINT.x)), float(cp.get("y", DEFAULT_CHECKPOINT.y)))
	return DEFAULT_CHECKPOINT


func mark_room_visited(room_id: StringName) -> void:
	character_current_life_knowledge["room"] = room_id
	var visited: Array = player_progress_knowledge["rooms_visited"]
	if not visited.has(String(room_id)):
		visited.append(String(room_id))
	room_changed.emit(room_id)
	knowledge_changed.emit(&"player")


func set_checkpoint(pos: Vector2, room_id: StringName = &"") -> void:
	character_current_life_knowledge["checkpoint"] = pos
	if room_id != &"":
		character_current_life_knowledge["checkpoint_room"] = room_id
	knowledge_changed.emit(&"character")


func set_world_flag(flag: StringName, value: Variant = true) -> void:
	var flags: Dictionary = world_memory_state["flags"]
	flags[String(flag)] = value
	world_flag_changed.emit(flag, value)
	knowledge_changed.emit(&"world")


## Hikâye bayrağı yaz. Bilinmeyen id uyarı verir ama yine saklanır.
func set_story_flag(id: StringName, value: bool = true) -> void:
	if not STORY_FLAGS.has(id):
		push_warning("Bilinmeyen hikâye bayrağı: %s" % String(id))
	var changed := bool(story_flags.get(id, false)) != value or not story_flags.has(id)
	story_flags[id] = value
	if changed:
		story_flag_changed.emit(id, value)


func has_story_flag(id: StringName) -> bool:
	return bool(story_flags.get(id, false))


func reset_discovered_seals() -> void:
	discovered_seals = [&"awakening"]


func discover_seal(room_id: StringName) -> void:
	if not discovered_seals.has(room_id):
		discovered_seals.append(room_id)


func clear_story_flags() -> void:
	var cleared: Array = []
	for k in story_flags.keys():
		if bool(story_flags[k]):
			cleared.append(StringName(String(k)))
	story_flags.clear()
	for id in cleared:
		story_flag_changed.emit(id, false)
	knowledge_changed.emit(&"player")


func get_world_flag(flag: StringName, default: Variant = false) -> Variant:
	var flags: Dictionary = world_memory_state.get("flags", {})
	return flags.get(String(flag), default)


func damage(amount: int = 1) -> void:
	## Ölüm akışında (ruh/yas/doğuş) hasar yok: yenilenen can geri düşmesin.
	if DeathManager.is_dying or CurseManager.possessing:
		return
	hearts = maxi(0, hearts - amount)
	hearts_changed.emit(hearts, max_hearts)
	if hearts <= 0:
		DeathManager.request_death(&"hearts")


## Bellek kodu öğren: hangi yaşamda (ölüm sayısı) öğrenildiğini de kaydeder.
func learn_memory_code(key: String, code: String) -> void:
	var codes: Dictionary = player_progress_knowledge.get("memory_codes", {})
	var had := codes.has(key)
	codes[key] = code
	player_progress_knowledge["memory_codes"] = codes
	var lives: Dictionary = player_progress_knowledge.get("memory_code_life", {})
	if not had or not lives.has(key):
		lives[key] = int(player_progress_knowledge.get("deaths", 0))
	player_progress_knowledge["memory_code_life"] = lives
	knowledge_changed.emit(&"player")


## &"same_life" | &"past_life" | &"unknown"
func memory_code_reaction(key: String) -> StringName:
	var codes: Dictionary = player_progress_knowledge.get("memory_codes", {})
	if String(codes.get(key, "")) == "":
		return &"unknown"
	var lives: Dictionary = player_progress_knowledge.get("memory_code_life", {})
	var learned := int(lives.get(key, int(player_progress_knowledge.get("deaths", 0))))
	return &"same_life" if learned >= int(player_progress_knowledge.get("deaths", 0)) else &"past_life"


func get_current_objective() -> String:
	var rid: String = String(character_current_life_knowledge.get("room", &""))
	return CampaignObjectives.objective_for_room(rid)


## Beceri düğmesi: Ruh Kesimi veya Gölge Atılması açıldı mı.
func has_any_ability() -> bool:
	return bool(player_progress_knowledge.get("ability_soul_slash", false)) 		or bool(player_progress_knowledge.get("ability_shadow_dash", false))


## Shilda adını söyledi mi (söylemeden önce konuşmacı kartı "???").
## TEK kaynak: story flag `shilda_name_known`. Eski kayıtlardaki
## player_progress_knowledge["shilda_named"] / "shilda_named_partial" / world flag
## "shilda_named" true ise burada bayrağa göç ettirilir.
func is_shilda_named() -> bool:
	if has_story_flag(&"shilda_name_known"):
		return true
	var legacy: bool = bool(player_progress_knowledge.get("shilda_named", false)) 		or bool(player_progress_knowledge.get("shilda_named_partial", false))
	var flags: Dictionary = world_memory_state.get("flags", {})
	if legacy or bool(flags.get(&"shilda_named", flags.get("shilda_named", false))):
		_clear_legacy_shilda_named()
		set_story_flag(&"shilda_name_known", true)
		return true
	return false


func set_shilda_named(value: bool = true) -> void:
	_clear_legacy_shilda_named()
	set_story_flag(&"shilda_name_known", value)
	knowledge_changed.emit(&"player")


func _clear_legacy_shilda_named() -> void:
	player_progress_knowledge["shilda_named"] = false
	player_progress_knowledge.erase("shilda_named_partial")
	var flags: Dictionary = world_memory_state.get("flags", {})
	flags.erase(&"shilda_named")
	flags.erase("shilda_named")


## Shilda'nın konuşmacı adı: isim öncesi "???", sonrası "Shilda".
func keeper_speaker_name() -> String:
	return "Shilda" if is_shilda_named() else "???"


func get_shilda_trust_state() -> Dictionary:
	if not player_progress_knowledge.has("shilda_trust"):
		player_progress_knowledge["shilda_trust"] = {
			"warnings_heeded": 0,
			"warnings_breached": 0,
			"echoes_completed": 0,
			"echoes_skipped": 0,
			"flowers_respected": true,
			"sanctuary_peace": true,
			"strikes_dealt": 0,
			"reconciled": false,
		}
	return player_progress_knowledge["shilda_trust"]


func is_shilda_trusted() -> bool:
	if bool(player_progress_knowledge.get("keeper_hurt", false)):
		return false
	if bool(player_progress_knowledge.get("keeper_withdrew", false)):
		return false
	if bool(player_progress_knowledge.get("trusted_keeper", false)):
		return true
	var t: Dictionary = get_shilda_trust_state()
	var score: int = 0
	if int(t.get("warnings_heeded", 0)) >= int(t.get("warnings_breached", 0)):
		score += 1
	if int(t.get("echoes_completed", 0)) >= 1:
		score += 1
	if bool(t.get("flowers_respected", true)):
		score += 1
	if bool(t.get("sanctuary_peace", true)) and int(t.get("strikes_dealt", 0)) == 0:
		score += 1
	if bool(t.get("reconciled", false)):
		score += 1
	return score >= 3
