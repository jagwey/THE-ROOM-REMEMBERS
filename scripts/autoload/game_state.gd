extends Node
## Üç hafıza katmanı — karakter ölünce sıfırlanır; dünya/oyuncu kalır.

const CampaignObjectives := preload("res://scripts/story/campaign_objectives.gd")

signal knowledge_changed(layer: StringName)
signal room_changed(room_id: StringName)
signal hearts_changed(current: int, maximum: int)
signal world_flag_changed(flag: StringName, value: Variant)

const MAX_HEARTS := 3
const DEFAULT_CHECKPOINT := Vector2(120, 280)

## Oyuncu meta bilgisi (ölümler arası kalır).
var player_progress_knowledge: Dictionary = {
	"deaths": 0,
	"seen_keeper": false,
	"awakening_mystery_seen": false,
	"pocket_watch_seen": false,
	"shilda_named_partial": false,
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

var hearts: int = MAX_HEARTS
var max_hearts: int = MAX_HEARTS

## Bu oturumda kayıt yüklendiyse Player._ready varsayılan checkpoint yazmasın.
var session_loaded_from_save: bool = false


func _ready() -> void:
	hearts_changed.emit(hearts, max_hearts)


func reset_character_life() -> void:
	var cp: Vector2 = get_checkpoint()
	var room: StringName = character_current_life_knowledge.get("checkpoint_room", &"awakening")
	character_current_life_knowledge = {
		"room": room,
		"checkpoint": cp,
		"checkpoint_room": room,
		"spawn_id": &"checkpoint",
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


func get_world_flag(flag: StringName, default: Variant = false) -> Variant:
	var flags: Dictionary = world_memory_state.get("flags", {})
	return flags.get(String(flag), default)


func damage(amount: int = 1) -> void:
	hearts = maxi(0, hearts - amount)
	hearts_changed.emit(hearts, max_hearts)
	if hearts <= 0:
		DeathManager.request_death(&"hearts")


func get_current_objective() -> String:
	var rid: String = String(character_current_life_knowledge.get("room", &""))
	## Uyanış: kısa adım adım; diğer odalar: CampaignObjectives (HUD tek kaynak).
	if rid == "awakening":
		if not bool(player_progress_knowledge.get("pocket_watch_seen", false)):
			return "Saata bak · plakaya bas · sağdaki geçide git"
		if not PuzzleManager.is_solved(&"awakening_weight"):
			return "Plakaya bas · kapı açılsın · Kırık Geçit'e git"
		return "Kırık Geçit'ten ilerle; yarıklara dikkat et."
	return CampaignObjectives.get_objective(rid)
