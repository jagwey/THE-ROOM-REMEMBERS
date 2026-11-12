extends SceneTree
## İtme denetimi: taş omuzla (giriş yönü) ve Etkileş adımıyla itilir, plaka her adımda algılar,
## itiş sırasında etkileşim hedefi taşa yapışık kalır, ceset çiçeği küçük.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/push_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("PUSH ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _make_counter(parent: Node, pos: Vector2) -> Area2D:
	var gd := GDScript.new()
	gd.source_code = "extends Area2D\nvar hits := 0\nfunc on_interact(_by):\n\thits += 1\n"
	gd.reload()
	var a := Area2D.new()
	a.set_script(gd)
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 40)
	cs.shape = r
	a.add_child(cs)
	a.position = pos
	parent.add_child(a)
	return a


func _run() -> void:
	var state := root.get_node("GameState")
	var dm := root.get_node("DialogueManager")
	var gate := root.get_node("UiGate")
	var mim := root.get_node("MobileInputManager")
	var pm := root.get_node("PuzzleManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	var rm := root.get_node("RoomManager")
	rm.enter_room(&"decay_weight", &"default")
	await create_timer(0.3).timeout
	dm.clear()
	var player: CharacterBody2D = current_scene.get_node("Player")
	var room_root: Node = rm._rooms[&"decay_weight"].root
	var stone: CharacterBody2D = room_root.get_node_or_null("WeightStone")
	var plate: Area2D = room_root.get_node_or_null("Interactive/PressurePlate")
	check(stone != null and plate != null, "stone and plate exist")
	if stone == null or plate == null:
		quit(1)
		return
	check(stone.collision_layer == 9 and stone.collision_mask == 1, "stone layer 1|8, mask 1")
	var cs := stone.get_node("CollisionShape2D") as CollisionShape2D
	check(cs.one_way_collision, "stone shape one-way (player not blocked horizontally)")
	check(stone.has_method("on_interact") and stone.has_method("get_weight") and stone.get_weight() == 1, "stone interactable + weight 1")

	## 1) Omuz itişi (giriş yönü): oyuncu taşa doğru yürür.
	stone.reset_to_start()
	player.global_position = Vector2(stone.global_position.x - 24.0, 288.0)
	player.velocity = Vector2.ZERO
	mim.clear_held_inputs()
	await create_timer(0.1).timeout
	var x0 := stone.global_position.x
	mim.set_move_vector(Vector2(1.0, 0.0))
	for i in range(40):
		await physics_frame
	mim.clear_held_inputs()
	check(stone.global_position.x > x0 + 20.0, "walking into stone pushes it (dx=%.1f)" % (stone.global_position.x - x0))
	check(player.global_position.x < stone.global_position.x, "player stays behind stone while pushing")
	## Arkasını dönmüş oyuncu itmez.
	await create_timer(0.5).timeout ## kayma bitsin
	var x1 := stone.global_position.x
	player.global_position = Vector2(stone.global_position.x + 24.0, 288.0)
	mim.set_move_vector(Vector2(1.0, 0.0))
	for i in range(20):
		await physics_frame
	mim.clear_held_inputs()
	check(absf(stone.global_position.x - x1) < 1.0, "walking away from stone does not push")

	## 2) Etkileş adımı.
	stone.reset_to_start()
	player.global_position = Vector2(stone.global_position.x - 22.0, 288.0)
	player.set("_facing", 1.0)
	mim.clear_held_inputs()
	await create_timer(0.2).timeout
	var xs := stone.global_position.x
	check(player.get_interaction_target() == stone, "stone is the interact target")
	player._on_interact()
	await create_timer(0.4).timeout
	check(stone.global_position.x > xs + 30.0, "interact step pushes ~36 px (dx=%.1f)" % (stone.global_position.x - xs))

	## 3) Duvar/uçurum: sınır dışına itilmez.
	stone.reset_to_start()
	stone.global_position.x = stone.max_x - 0.5
	await create_timer(0.1).timeout
	var xe := stone.global_position.x
	var moved: bool = await stone.step_push(1.0)
	check(not moved and absf(stone.global_position.x - xe) < 1.0, "no push beyond bound / ledge")

	## 4) Plaka: adım adım itilince basılır, geri çekilince kalkmaz değil — basılı anda algılanır.
	var pz: Dictionary = state.world_memory_state.get("puzzles", {})
	pz.erase("decay_weight_latch")
	state.world_memory_state["puzzles"] = pz
	state.set_world_flag(&"decay_weight_latched", false)
	pm.sync_from_world()
	stone.reset_to_start()
	await create_timer(0.1).timeout
	var steps := 0
	while not plate._pressed and steps < 20:
		steps += 1
		player.global_position = Vector2(stone.global_position.x - 22.0, 288.0)
		player.set("_facing", 1.0)
		await stone.step_push(1.0, player)
		await physics_frame
	check(plate._pressed, "plate pressed by stone after %d interact steps (stone x=%.1f)" % [steps, stone.global_position.x])
	check(pm.is_live(&"decay_weight_latch"), "plate puzzle live while stone weight rests (latch happens on pass)")

	## 5) Yapışık hedef: itişten sonra daha yakın bir Etkileş nesnesi hedefi çalmaz.
	stone.reset_to_start()
	player.global_position = Vector2(stone.global_position.x - 22.0, 288.0)
	player.set("_facing", 1.0)
	await create_timer(1.4).timeout ## önceki itiş yapışkanlığı bitsin
	var near := _make_counter(room_root, Vector2(player.global_position.x + 4.0, 270.0))
	await create_timer(0.2).timeout
	check(player.get_interaction_target() == near, "without push, nearer object is the target")
	player.note_push(stone)
	check(player.get_interaction_target() == stone, "after push, stone stays the target (sticky)")
	await create_timer(1.4).timeout
	check(player.get_interaction_target() == near, "sticky expires after 1.2 s")
	near.queue_free()

	## 6) Ceset çiçeği küçük, vurgu glow'u arka planın önünde.
	var cres := load("res://scenes/world/corpse.tscn") as PackedScene
	var c := cres.instantiate()
	var fl := c.get_node("Flower") as Sprite2D
	check(fl.scale.x <= 0.4 and fl.position.y < -8.0, "death flower scaled small near chest edge")
	c.free()
	var g: Sprite2D = stone.get_node_or_null("InteractGlow")
	check(g != null and g.z_index >= 0 and g.show_behind_parent, "stone has glow in front of background (z>=0, behind parent)")

	print("PUSH AUDIT: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
