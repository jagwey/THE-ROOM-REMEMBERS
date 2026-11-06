extends Node
## Üç hafıza katmanı — karakter ölünce sıfırlanır; dünya/oyuncu kalır.

signal knowledge_changed(layer: StringName)
signal room_changed(room_id: StringName)
signal hearts_changed(current: int, maximum: int)

const MAX_HEARTS := 3

## Oyuncu meta bilgisi (ölümler arası kalır).
var player_progress_knowledge: Dictionary = {
	"deaths": 0,
	"seen_keeper": false,
	"rooms_visited": [],
	"journal_unlocked": false,
	"endings_seen": [],
}

## Bu hayatın karakter bilgisi (ölümde sıfırlanır).
var character_current_life_knowledge: Dictionary = {
	"room": &"awakening",
	"checkpoint": Vector2(120, 280),
	"interacted": [],
	"dialogue_flags": {},
}

## Dünya hafızası (kalıcı — cesetler, izler, Bekçi tepkisi).
var world_memory_state: Dictionary = {
	"corpses": [],
	"echo_sites": [],
	"keeper_mood": &"observe",
	"flowers_left": 0,
	"forbidden_touched": [],
}

var hearts: int = MAX_HEARTS
var max_hearts: int = MAX_HEARTS


func _ready() -> void:
	hearts_changed.emit(hearts, max_hearts)


func reset_character_life() -> void:
	character_current_life_knowledge = {
		"room": character_current_life_knowledge.get("checkpoint_room", &"awakening"),
		"checkpoint": character_current_life_knowledge.get("checkpoint", Vector2(120, 280)),
		"interacted": [],
		"dialogue_flags": {},
	}
	hearts = max_hearts
	hearts_changed.emit(hearts, max_hearts)
	knowledge_changed.emit(&"character")


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


func damage(amount: int = 1) -> void:
	hearts = maxi(0, hearts - amount)
	hearts_changed.emit(hearts, max_hearts)
	if hearts <= 0:
		DeathManager.request_death(&"hearts")
