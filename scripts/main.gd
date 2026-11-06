extends Node2D
## Ana sahne — World / Player / Keeper / Camera / UI / Audio / Core.

@onready var room_awakening: Node2D = $World/Awakening
@onready var room_core: Node2D = $World/Core
@onready var player: Node2D = $Player
@onready var keeper: Node2D = $Keeper


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.VOID)
	GameState.mark_room_visited(&"awakening")
	GameState.set_checkpoint(Vector2(120, 280), &"awakening")
	if room_core:
		room_core.visible = false
		room_core.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := $Camera2D
	if cam and cam.has_method("set_room_bounds"):
		cam.set_room_bounds(Rect2(0, 0, 640, 360))
	DialogueManager.say("???", "Gözlerin açılıyor.")
	DialogueManager.say("???", "Oda seni hatırlıyor.")
	# Smoke sadece TORIMON_SMOKE=1 ve headless
	if DisplayServer.get_name() == "headless" and OS.get_environment("TORIMON_SMOKE") == "1":
		call_deferred("_headless_faz67_smoke")


func enter_core() -> void:
	if room_awakening:
		room_awakening.visible = false
		room_awakening.process_mode = Node.PROCESS_MODE_DISABLED
	if room_core:
		room_core.visible = true
		room_core.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.mark_room_visited(&"core")
	GameState.set_checkpoint(Vector2(160, 280), &"core")
	if player:
		player.global_position = Vector2(160, 280)
	if keeper:
		keeper.visible = true
		keeper.global_position = Vector2(400, 280)
	var cam := $Camera2D
	if cam and cam.has_method("set_room_bounds"):
		cam.set_room_bounds(Rect2(0, 0, 640, 360))
	CurseManager.add_curse(8.0, &"core_enter")
	CorpseManager.rebuild_world_corpses()


func enter_awakening() -> void:
	if room_core:
		room_core.visible = false
		room_core.process_mode = Node.PROCESS_MODE_DISABLED
	if room_awakening:
		room_awakening.visible = true
		room_awakening.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.mark_room_visited(&"awakening")
	var cam := $Camera2D
	if cam and cam.has_method("set_room_bounds"):
		cam.set_room_bounds(Rect2(0, 0, 640, 360))
	if player:
		player.global_position = GameState.get_checkpoint()


func _headless_faz67_smoke() -> void:
	await get_tree().create_timer(0.8).timeout
	if DialogueManager.is_open:
		await DialogueManager.dialogue_closed
	GameState.player_progress_knowledge["awakening_mystery_seen"] = true
	GameState.player_progress_knowledge["seen_keeper"] = true

	# --- FAZ 6: lanet 100% → fail life, dünya kalır ---
	var deaths_before := int(GameState.player_progress_knowledge["deaths"])
	CurseManager.add_curse(100.0, &"smoke_curse")
	await DeathManager.rebirth_completed
	var curse_fail_ok := int(GameState.player_progress_knowledge["deaths"]) > deaths_before
	var world_kept := GameState.world_memory_state.has("flags")

	# --- FAZ 7 bad ---
	EndingManager.reset_for_smoke()
	if keeper and keeper.has_method("receive_player_strike"):
		for i in 3:
			await keeper.receive_player_strike()
			if EndingManager.current == EndingManager.Ending.BAD_KILL_KEEPER:
				break
			await get_tree().create_timer(0.1).timeout
	if EndingManager.current != EndingManager.Ending.BAD_KILL_KEEPER:
		await EndingManager.epilogue_finished
	else:
		await get_tree().create_timer(0.3).timeout
	var bad_ok := EndingManager.current == EndingManager.Ending.BAD_KILL_KEEPER

	# --- FAZ 7 good ---
	EndingManager.reset_for_smoke()
	PuzzleManager.mark_solved(&"awakening_weight")
	PuzzleManager.mark_solved(&"awakening_memory_code")
	GameState.player_progress_knowledge["echoes_seen"] = ["awakening_rift_echo"]
	GameState.player_progress_knowledge["trusted_keeper"] = true
	GameState.set_world_flag(&"awakening_door_opened", true)
	enter_core()
	await get_tree().create_timer(0.2).timeout
	var crystal := get_tree().get_first_node_in_group("core_crystal")
	if crystal and crystal.has_method("on_interact"):
		await crystal.on_interact(player)
	if EndingManager.current != EndingManager.Ending.GOOD_TRUST_SEAL:
		await EndingManager.epilogue_finished
	else:
		await get_tree().create_timer(0.3).timeout
	var good_ok := EndingManager.current == EndingManager.Ending.GOOD_TRUST_SEAL

	var msg := "FAZ67_SMOKE ok curse_fail=%s world=%s bad=%s good=%s indicator=%s" % [
		str(curse_fail_ok),
		str(world_kept),
		str(bad_ok),
		str(good_ok),
		str(CurseManager.visible_meter or bool(GameState.player_progress_knowledge.get("curse_indicator_seen", false))),
	]
	print(msg)
	var f := FileAccess.open("user://faz67_smoke.txt", FileAccess.WRITE)
	if f:
		f.store_string(msg)
	SaveManager.save_game()
