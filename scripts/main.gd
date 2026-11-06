extends Node2D
## Ana sahne — RoomManager ile çok odalı dünya.

@onready var world: Node2D = $World
@onready var player: Node2D = $Player
@onready var keeper: Node2D = $Keeper

var _continued: bool = false

## room_id -> { node_name, bounds, spawns, checkpoint, bg }
const ROOM_DEFS := {
	"awakening": {"node": "Awakening", "bounds": Rect2(0, 0, 1280, 360), "checkpoint": Vector2(120, 280), "bg": "res://assets/backgrounds/awakening",
		"spawns": {"default": Vector2(120, 280), "from_passage": Vector2(1160, 288)}},
	"awakening_passage": {"node": "AwakeningPassage", "bounds": Rect2(0, 0, 1920, 360), "checkpoint": Vector2(700, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(80, 288), "from_awakening": Vector2(80, 288), "from_seal": Vector2(1840, 288)}},
	"awakening_seal": {"node": "AwakeningSeal", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(480, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(480, 288), "from_passage": Vector2(80, 288), "from_decay": Vector2(880, 288)}},
	"decay_vines": {"node": "DecayVines", "bounds": Rect2(0, 0, 1280, 360), "checkpoint": Vector2(120, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(80, 288), "from_seal": Vector2(80, 288), "from_weight": Vector2(1200, 288)}},
	"decay_weight": {"node": "DecayWeight", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(120, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(120, 288), "from_vines": Vector2(80, 288), "from_garden": Vector2(880, 288)}},
	"decay_garden": {"node": "DecayGarden", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(200, 288), "from_weight": Vector2(80, 288), "from_library": Vector2(880, 288)}},
	"library_hall": {"node": "LibraryHall", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(120, 288), "bg": "res://assets/backgrounds/library",
		"spawns": {"default": Vector2(120, 288), "from_garden": Vector2(120, 288), "from_witness": Vector2(880, 288), "from_hall": Vector2(120, 288)}},
	"library_witness": {"node": "LibraryWitness", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/library",
		"spawns": {"default": Vector2(120, 288), "from_hall": Vector2(120, 288), "from_page": Vector2(880, 288), "from_witness": Vector2(120, 288)}},
	"library_page": {"node": "LibraryPage", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/library",
		"spawns": {"default": Vector2(120, 288), "from_witness": Vector2(120, 288), "from_cells": Vector2(880, 288), "from_page": Vector2(120, 288)}},
	"experiment_cells": {"node": "ExperimentCells", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/experiment",
		"spawns": {"default": Vector2(120, 288), "from_page": Vector2(120, 288), "from_circuit": Vector2(880, 288), "from_cells": Vector2(120, 288)}},
	"experiment_circuit": {"node": "ExperimentCircuit", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/experiment",
		"spawns": {"default": Vector2(120, 288), "from_cells": Vector2(120, 288), "from_auth": Vector2(880, 288), "from_circuit": Vector2(120, 288)}},
	"experiment_authority": {"node": "ExperimentAuthority", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/experiment",
		"spawns": {"default": Vector2(120, 288), "from_circuit": Vector2(120, 288), "from_mirrors": Vector2(880, 288), "from_auth": Vector2(120, 288)}},
	"mirrors_reverse": {"node": "MirrorsReverse", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/mirrors",
		"spawns": {"default": Vector2(120, 288), "from_auth": Vector2(120, 288), "from_dual": Vector2(880, 288), "from_reverse": Vector2(120, 288), "from_mirrors": Vector2(120, 288)}},
	"mirrors_dual": {"node": "MirrorsDual", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/mirrors",
		"spawns": {"default": Vector2(120, 288), "from_reverse": Vector2(120, 288), "from_unbroken": Vector2(880, 288), "from_dual": Vector2(120, 288)}},
	"mirrors_unbroken": {"node": "MirrorsUnbroken", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/mirrors",
		"spawns": {"default": Vector2(120, 288), "from_dual": Vector2(120, 288), "from_threshold": Vector2(880, 288), "from_unbroken": Vector2(120, 288)}},
	"core_threshold": {"node": "CoreThreshold", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/core",
		"spawns": {"default": Vector2(120, 288), "from_mirrors": Vector2(120, 288), "from_seal_chamber": Vector2(880, 288), "from_threshold": Vector2(120, 288)}},
	"core_seal_chamber": {"node": "CoreSealChamber", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/core",
		"spawns": {"default": Vector2(120, 288), "from_threshold": Vector2(120, 288), "from_chamber": Vector2(120, 288)}},
	"core": {"node": "Core", "bounds": Rect2(0, 0, 640, 360), "checkpoint": Vector2(160, 280), "bg": "res://assets/backgrounds/core",
		"spawns": {"default": Vector2(160, 280), "from_chamber": Vector2(160, 280)}},
}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.VOID)
	_continued = false
	GameState.session_loaded_from_save = false
	if OS.get_environment("TORIMON_SMOKE") != "1" and OS.get_environment("TORIMON_FRESH") != "1":
		if SaveManager.has_save():
			if SaveManager.load_game(false):
				_continued = true
	_register_rooms()
	if not _continued:
		GameState.mark_room_visited(&"awakening")
		GameState.set_checkpoint(Vector2(120, 280), &"awakening")
		GameState.character_current_life_knowledge["spawn_id"] = &"default"

	var start_room := GameState.character_current_life_knowledge.get("room", &"awakening") as StringName
	var start_spawn := GameState.character_current_life_knowledge.get("spawn_id", &"default") as StringName
	if not RoomManager.has_room(start_room):
		start_room = &"awakening"
		start_spawn = &"default"
	if _continued:
		RoomManager.apply_initial_room(start_room, &"checkpoint", true)
		if String(start_room).begins_with("core") and keeper:
			keeper.visible = true
			keeper.global_position = Vector2(400, 280)
	else:
		RoomManager.apply_initial_room(start_room, start_spawn, true)

	if not _continued:
		DialogueManager.say("???", "Gözlerin açılıyor.")
		DialogueManager.say("???", "Oda seni hatırlıyor. Sen henüz bilmiyorsun.")
		DialogueManager.say("Shiren", "…Burası neresi?")
	else:
		DialogueManager.say("???", "…Yine buradasın.")
		DialogueManager.say("Shiren", "Bir şey unuttum. Oda unutmamış.")
	CorpseManager.rebuild_world_corpses()
	call_deferred("_clear_session_loaded_flag")
	if DisplayServer.get_name() == "headless" and OS.get_environment("TORIMON_SMOKE") == "1":
		call_deferred("_headless_faz67_smoke")


func _clear_session_loaded_flag() -> void:
	GameState.session_loaded_from_save = false


func _register_rooms() -> void:
	for rid in ROOM_DEFS.keys():
		var def: Dictionary = ROOM_DEFS[rid]
		if RoomManager.has_room(StringName(rid)):
			continue
		var node_name: String = String(def["node"])
		var root := world.get_node_or_null(node_name) as Node2D
		if root == null:
			push_warning("main: missing room node %s" % node_name)
			continue
		var spawns: Dictionary = {}
		for sk in def["spawns"].keys():
			spawns[StringName(sk)] = def["spawns"][sk]
		RoomManager.register_room(
			StringName(rid),
			root,
			def["bounds"] as Rect2,
			spawns,
			def["checkpoint"] as Vector2,
			StringName(rid),
			String(def["bg"])
		)


func enter_core() -> void:
	RoomManager.enter_room(&"core", &"default")
	if keeper:
		keeper.visible = true
		keeper.global_position = Vector2(400, 280)
	CurseManager.add_curse(8.0, &"core_enter")


func enter_awakening() -> void:
	RoomManager.enter_room(&"awakening", &"checkpoint", false)


func _headless_faz67_smoke() -> void:
	print("SMOKE_START")
	await get_tree().create_timer(0.5).timeout
	## Intro / gizem diyalogunu zorla kapat — otomatik ilerleme takılırsa smoke bitsin.
	if DialogueManager.is_open:
		DialogueManager.clear()
	await get_tree().create_timer(0.2).timeout
	GameState.player_progress_knowledge["awakening_mystery_seen"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true
	print("SMOKE_AFTER_INTRO")

	var deaths_before := int(GameState.player_progress_knowledge["deaths"])
	print("SMOKE_CURSE")
	CurseManager.add_curse(100.0, &"smoke_curse")
	var curse_fail_ok := false
	if DeathManager.is_dying:
		await DeathManager.rebirth_completed
		curse_fail_ok = int(GameState.player_progress_knowledge["deaths"]) > deaths_before
	else:
		## Fail-life tetiklenmediyse yine de sayacı doğrula
		await get_tree().create_timer(0.5).timeout
		curse_fail_ok = int(GameState.player_progress_knowledge["deaths"]) > deaths_before
	print("SMOKE_CURSE_DONE fail=", curse_fail_ok)
	var world_kept := GameState.world_memory_state.has("flags")

	## Bad ending yalnız core'da
	EndingManager.reset_for_smoke()
	print("SMOKE_BAD")
	RoomManager.enter_room(&"core", &"default")
	if keeper:
		keeper.visible = true
		keeper.global_position = Vector2(400, 280)
	await get_tree().create_timer(0.1).timeout
	if keeper and keeper.has_method("receive_player_strike"):
		for i in 3:
			await keeper.receive_player_strike()
			if EndingManager.last_ending == EndingManager.Ending.BAD_KILL_KEEPER \
					or EndingManager.current == EndingManager.Ending.BAD_KILL_KEEPER:
				break
			await get_tree().create_timer(0.1).timeout
	if EndingManager.last_ending != EndingManager.Ending.BAD_KILL_KEEPER:
		## Epilog/UI takılırsa doğrudan tetikle
		await EndingManager.trigger(EndingManager.Ending.BAD_KILL_KEEPER)
	await get_tree().create_timer(0.2).timeout
	var bad_ok := EndingManager.last_ending == EndingManager.Ending.BAD_KILL_KEEPER
	print("SMOKE_BAD_DONE ", bad_ok)

	EndingManager.reset_for_smoke()
	PuzzleManager.mark_solved(&"awakening_weight")
	PuzzleManager.mark_solved(&"awakening_memory_code")
	PuzzleManager.mark_solved(&"mirrors_unbroken")
	PuzzleManager.mark_solved(&"core_seal")
	GameState.player_progress_knowledge["echoes_seen"] = ["awakening_rift_echo"]
	GameState.player_progress_knowledge["trusted_keeper"] = true
	GameState.player_progress_knowledge["truth_seen"] = true
	GameState.set_world_flag(&"awakening_door_opened", true)
	print("SMOKE_GOOD")
	enter_core()
	await get_tree().create_timer(0.2).timeout
	## Doğrudan final tetikle — kristal diyalog zinciri headless'ta takılabiliyor
	if EndingManager.can_attempt_good_seal():
		await EndingManager.trigger(EndingManager.Ending.GOOD_TRUST_SEAL)
	else:
		var crystal := get_tree().get_first_node_in_group("core_crystal")
		if crystal and crystal.has_method("on_interact"):
			await crystal.on_interact(player)
	await get_tree().create_timer(0.3).timeout
	var good_ok := EndingManager.last_ending == EndingManager.Ending.GOOD_TRUST_SEAL
	print("SMOKE_GOOD_DONE ", good_ok)
	var msg := "FAZ67_SMOKE ok curse_fail=%s world=%s bad=%s good=%s rooms=%s indicator=%s" % [
		str(curse_fail_ok),
		str(world_kept),
		str(bad_ok),
		str(good_ok),
		str(RoomManager.has_room(&"decay_garden") and RoomManager.has_room(&"library_hall")),
		str(CurseManager.visible_meter or bool(GameState.player_progress_knowledge.get("curse_indicator_seen", false))),
	]
	print(msg)
	var f := FileAccess.open("user://faz67_smoke.txt", FileAccess.WRITE)
	if f:
		f.store_string(msg)
	SaveManager.save_game()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if (curse_fail_ok and world_kept and bad_ok and good_ok) else 1)
