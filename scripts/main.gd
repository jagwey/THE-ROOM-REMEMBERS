extends Node2D

const EyeOpenIntro := preload("res://scripts/ui/eye_open_intro.gd")
## Ana sahne — RoomManager ile çok odalı dünya.

@onready var world: Node2D = $World
@onready var player: Node2D = $Player
@onready var keeper: Node2D = $Keeper

var _continued: bool = false

## room_id -> { node_name, bounds, spawns, checkpoint, bg }
const ROOM_DEFS := {
	"awakening": {"node": "Awakening", "bounds": Rect2(0, 0, 1280, 360), "checkpoint": Vector2(120, 280), "bg": "res://assets/backgrounds/awakening",
		"spawns": {"default": Vector2(120, 280), "rebirth_bed": Vector2(120, 280), "from_passage": Vector2(1160, 288), "seal_awakening": Vector2(380, 288)}},
	"awakening_passage": {"node": "AwakeningPassage", "bounds": Rect2(0, 0, 1500, 360), "checkpoint": Vector2(600, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(80, 288), "from_awakening": Vector2(80, 288), "from_seal": Vector2(1410, 288)}},
	"awakening_seal": {"node": "AwakeningSeal", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(480, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(480, 288), "from_passage": Vector2(80, 288), "from_decay": Vector2(880, 288)}},
	"decay_vines": {"node": "DecayVines", "bounds": Rect2(0, 0, 1280, 360), "checkpoint": Vector2(120, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(80, 288), "from_seal": Vector2(80, 288), "from_weight": Vector2(1200, 288)}},
	"decay_weight": {"node": "DecayWeight", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(120, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(120, 288), "from_vines": Vector2(80, 288), "from_garden": Vector2(880, 288)}},
	"decay_garden": {"node": "DecayGarden", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(130, 288), "bg": "res://assets/backgrounds/decay",
		"spawns": {"default": Vector2(130, 288), "from_weight": Vector2(80, 288), "from_library": Vector2(880, 288)}},
	"library_hall": {"node": "LibraryHall", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(120, 288), "bg": "res://assets/backgrounds/library",
		"spawns": {"default": Vector2(120, 288), "from_garden": Vector2(120, 288), "from_witness": Vector2(880, 288), "from_hall": Vector2(120, 288)}},
	"library_witness": {"node": "LibraryWitness", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/library",
		"spawns": {"default": Vector2(120, 288), "from_hall": Vector2(120, 288), "from_page": Vector2(880, 288), "from_witness": Vector2(120, 288)}},
	"library_page": {"node": "LibraryPage", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/library",
		"spawns": {"default": Vector2(120, 288), "from_witness": Vector2(120, 288), "from_cells": Vector2(880, 288), "from_stacks": Vector2(880, 288), "from_page": Vector2(120, 288)}},
	"experiment_cells": {"node": "ExperimentCells", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/experiment",
		"spawns": {"default": Vector2(120, 288), "from_page": Vector2(120, 288), "from_circuit": Vector2(880, 288), "from_reading": Vector2(120, 288), "from_cells": Vector2(120, 288)}},
	"experiment_circuit": {"node": "ExperimentCircuit", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/experiment",
		"spawns": {"default": Vector2(120, 288), "from_cells": Vector2(120, 288), "from_auth": Vector2(880, 288), "from_circuit": Vector2(120, 288)}},
	"experiment_authority": {"node": "ExperimentAuthority", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/experiment",
		"spawns": {"default": Vector2(120, 288), "from_circuit": Vector2(120, 288), "from_mirrors": Vector2(880, 288), "from_quarantine": Vector2(880, 288), "from_auth": Vector2(120, 288)}},
	"mirrors_reverse": {"node": "MirrorsReverse", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/mirrors",
		"spawns": {"default": Vector2(120, 288), "from_auth": Vector2(120, 288), "from_dual": Vector2(880, 288), "from_observation": Vector2(120, 288), "from_reverse": Vector2(120, 288), "from_mirrors": Vector2(120, 288), "from_mirrors_dual": Vector2(880, 288)}},
	"mirrors_dual": {"node": "MirrorsDual", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/mirrors",
		"spawns": {"default": Vector2(120, 288), "from_reverse": Vector2(120, 288), "from_unbroken": Vector2(880, 288), "from_dual": Vector2(120, 288), "from_mirrors_reverse": Vector2(120, 288), "from_mirrors_gallery": Vector2(880, 288)}},
	"mirrors_unbroken": {"node": "MirrorsUnbroken", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/mirrors",
		"spawns": {"default": Vector2(120, 288), "from_dual": Vector2(120, 288), "from_threshold": Vector2(880, 288), "from_unbroken": Vector2(120, 288), "from_mirrors_gallery": Vector2(120, 288), "from_mirrors_labyrinth": Vector2(880, 288)}},
	"core_threshold": {"node": "CoreThreshold", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/core",
		"spawns": {"default": Vector2(120, 288), "from_mirrors": Vector2(120, 288), "from_seal_chamber": Vector2(880, 288), "from_threshold": Vector2(120, 288), "from_mirrors_1927": Vector2(120, 288), "from_core_ascent": Vector2(880, 288)}},
	"core_seal_chamber": {"node": "CoreSealChamber", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(200, 288), "bg": "res://assets/backgrounds/core",
		"spawns": {"default": Vector2(120, 288), "from_threshold": Vector2(120, 288), "from_chamber": Vector2(880, 288), "from_core_ascent": Vector2(120, 288), "from_core_memory_vault": Vector2(880, 288)}},
	"core": {"node": "Core", "bounds": Rect2(0, 0, 960, 360), "checkpoint": Vector2(160, 280), "bg": "res://assets/backgrounds/core",
		"spawns": {"default": Vector2(160, 280), "from_chamber": Vector2(160, 280), "from_core_bloom_garden": Vector2(160, 280)}},
}


## v1.0 genişleme: mevcut odalardan yan bölgelere açılan kapılar (geri dönüş / metroidvania-lite).
## room_id -> [{x, to, req, msg}] — hedef odada "from_<room_id>" spawn'ı built_room tarafından üretilir.
const SIDE_DOORS := {
	"awakening": [{"x": 672.0, "to": "awakening_balcony"}],
	"decay_vines": [{"x": 896.0, "to": "decay_catacombs"}],
	"decay_weight": [{"x": 720.0, "to": "decay_cistern"}],
}


## Keşfedilmesi gereken yan kapıya soluk, nabız atan ek ışık (başlık etiketi kapının kendisinde).
func _add_door_mark(door: Area2D) -> void:
	load("res://scripts/world/room_transition.gd").add_door_mark(door)


func _add_side_doors() -> void:
	var door_script: Script = load("res://scripts/world/room_transition.gd")
	for rid in SIDE_DOORS.keys():
		if not RoomManager.has_room(StringName(rid)):
			continue
		var entry: Dictionary = RoomManager._rooms[StringName(rid)]
		var bounds: Rect2 = entry.get("bounds", Rect2(0, 0, 960, 360))
		var root: Node2D = entry["root"]
		var parent: Node = root.get_node_or_null("Interactive")
		if parent == null:
			parent = root
		for d in SIDE_DOORS[rid]:
			var target := String(d["to"])
			if not RoomManager.has_room(StringName(target)):
				continue
			if parent.has_node("Side_%s" % target):
				continue
			var door := Area2D.new()
			door.name = "Side_%s" % target
			door.set_script(door_script)
			door.position = Vector2(float(d["x"]), 268.0)
			door.set("target_room_id", StringName(target))
			door.set("target_spawn_id", StringName("from_%s" % rid))
			if d.has("req"):
				door.set("required_puzzle", StringName(String(d["req"])))
			if d.has("ability"):
				door.set("required_ability", StringName(String(d["ability"])))
			if d.has("msg"):
				door.set("locked_message", String(d["msg"]))
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(44, 96)
			cs.shape = rect
			door.add_child(cs)
			if d.has("label_dy"):
				door.set("label_dy", float(d["label_dy"]))
			if d.has("title"):
				door.set("door_title", String(d["title"]))
			parent.add_child(door)
			if d.get("mark", false):
				_add_door_mark(door)
			var spawns: Dictionary = entry["spawns"]
			var inward := 48.0 if float(d["x"]) < bounds.size.x * 0.5 else -48.0
			spawns[StringName("from_%s" % target)] = Vector2(float(d["x"]) + inward, 288.0)


func _ready() -> void:
	DeathManager.release_time_scale()
	RenderingServer.set_default_clear_color(Palette.VOID)
	_continued = false
	GameState.session_loaded_from_save = false
	var fresh_pending := SaveManager.consume_fresh_start()
	if not fresh_pending and OS.get_environment("TORIMON_SMOKE") != "1" and OS.get_environment("TORIMON_FRESH") != "1":
		if SaveManager.has_save():
			if SaveManager.load_game(false):
				_continued = true
	_register_rooms()
	_add_side_doors()
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
		var s := String(start_room)
		var cut := s.find("_")
		var reg := StringName(s if cut < 0 else s.substr(0, cut))
		AudioManager.play_region_ambient(reg)
		if keeper:
			keeper.place_for_room(start_room)
	else:
		RoomManager.apply_initial_room(start_room, start_spawn, true)

	# Başlık ekranı açıksa açılış repliği oyuncu "Başla/Devam et" deyince gelir.
	var menu := get_node_or_null("SessionMenu")
	if menu and menu.has_method("is_title_open") and menu.is_title_open():
		AudioManager.play_title_ambience()
		menu.title_closed.connect(_play_intro, CONNECT_ONE_SHOT)
	else:
		_play_intro()
	CorpseManager.rebuild_world_corpses()
	call_deferred("_clear_session_loaded_flag")
	if DisplayServer.get_name() == "headless" and OS.get_environment("TORIMON_SMOKE") == "1":
		call_deferred("_headless_faz67_smoke")


func _play_intro() -> void:
	## Göz kapakları aralanır (beyaz flaş yok); replikler gözler açıldıktan sonra.
	var fast := DisplayServer.get_name() == "headless" or OS.get_environment("TORIMON_SMOKE") == "1" or OS.get_environment("TORIMON_TEST") == "1"
	var eyes := EyeOpenIntro.new()
	add_child(eyes)
	await eyes.play(0.05 if fast else (0.9 if _continued else 2.2), not _continued)
	if not is_inside_tree():
		return
	if not _continued:
		DialogueManager.say("", "Gözlerin açılıyor. Saat durmuş. Biri nefesini tutmuş.")
		DialogueManager.say("", "Bu oda seni tanıyor. Sen onu tanımıyorsun.")
		DialogueManager.say("Noroi", "Burası neresi, neden uyanamıyorum?")
		await DialogueManager.dialogue_finished
		if not is_inside_tree():
			return
		GameState.set_story_flag(&"intro_completed")
		GameState.player_progress_knowledge["awakening_mystery_seen"] = true
		return
	else:
		DialogueManager.say("", "Yine bu yatak. Oda saydı. Sen unuttun.")
		DialogueManager.say("Noroi", "Bir şey eksik, duvarlar hatırlıyor.")


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
		keeper.global_position = Vector2(560, 280)
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
	GameState.set_world_flag(&"smoke_possession_world_persist", true)
	PuzzleManager.mark_solved(&"smoke_possession_persist")
	print("SMOKE_CURSE")
	CurseManager.add_curse(100.0, &"smoke_curse")
	## v3: lanet dolunca ölüm değil ele geçirme; committed kayda döner, ölüm sayılmaz.
	var possession_started := CurseManager.possessing
	var waited := 0.0
	while CurseManager.possessing and waited < 20.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	var curse_fail_ok: bool = possession_started and not CurseManager.possessing 			and not DeathManager.is_dying 			and int(GameState.player_progress_knowledge["deaths"]) == deaths_before
	var curse_safe_ok: bool = absf(CurseManager.curse - CurseManager.POSSESSION_SAFE_CURSE) < 1.0
	print("SMOKE_CURSE_DONE possession=", curse_fail_ok, " curse50=", curse_safe_ok)
	var world_kept: bool = GameState.world_memory_state.has("flags") and GameState.get_world_flag(&"smoke_possession_world_persist", false) and PuzzleManager.is_solved(&"smoke_possession_persist")

	## Tek final: Shilda öldürülemez, sonra BÖLÜM I SONU dizisi (hızlı)
	EndingManager.reset_for_smoke()
	print("SMOKE_FINAL")
	RoomManager.enter_room(&"core", &"default")
	if keeper:
		keeper.visible = true
		keeper.global_position = Vector2(560, 280)
	await get_tree().create_timer(0.1).timeout
	if keeper and keeper.has_method("receive_player_strike"):
		for i in 3:
			await keeper.receive_player_strike()
	var bad_ok: bool = (not keeper.is_defeated()) if keeper else true
	PuzzleManager.mark_solved(&"core_seal")
	GameState.set_world_flag(&"seal_shard_1", true)
	GameState.set_world_flag(&"seal_shard_2", true)
	GameState.player_progress_knowledge["ability_soul_slash"] = true
	await EndingManager.trigger(EndingManager.Ending.PART_ONE, true)
	var good_ok := EndingManager.last_ending == EndingManager.Ending.PART_ONE and GameState.has_story_flag(&"final_seal_broken") and GameState.has_story_flag(&"x_revealed") and GameState.has_story_flag(&"game_completed")
	print("SMOKE_FINAL_DONE ", good_ok)
	var variant_ok: bool = String(FinalSequence.last_run.get("variant", "")) in ["together", "apart"]
	var msg := "FAZ67_SMOKE ok variant=%s curse_possession=%s curse50=%s world=%s bad=%s good=%s rooms=%s indicator=%s" % [
		str(variant_ok),
		str(curse_fail_ok),
		str(curse_safe_ok),
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
	get_tree().quit(0 if (curse_fail_ok and curse_safe_ok and world_kept and bad_ok and good_ok and variant_ok) else 1)
