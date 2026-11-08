extends SceneTree
## Ortak etkileşim sistemi testi: renk türü, en yakın hedef, menzil dışı tetiklenmez,
## yalnız hedef parlar + isim etiketi, tekrar tetiklenme koruması, Shilda yalnız sakinken.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/interact_audit.gd
var failures := 0
## Otomatik yüklemeler hazır olduktan sonra yüklenir (preload derleme anında PuzzleManager bulamaz).
var Glow: GDScript


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("INTERACT ", "PASS " if ok else "FAIL ", label)
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
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("INTERACT SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	Glow = load("res://scripts/world/interact_glow.gd")
	var state := root.get_node("GameState")
	var gate := root.get_node("UiGate")
	var dm := root.get_node("DialogueManager")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm.clear()
	gate.set_story(false)
	var rm := root.get_node("RoomManager")
	rm.enter_room(&"awakening", &"default")
	await create_timer(0.3).timeout
	var player: CharacterBody2D = current_scene.get_node("Player")
	var room: Node = (rm._rooms[&"awakening"] as Dictionary)["root"]
	var watch: Node2D = room.find_child("PocketWatchInspect", true, false)
	var shilda_beat: Node2D = room.find_child("ShildaNameBeat", true, false)
	var exit: Node2D = room.find_child("ExitPassage", true, false)
	check(watch != null and exit != null, "awakening interactables found")

	## 1) Tür / renk / etiket.
	check(Glow.kind_for(watch) == &"memory", "pocket watch = memory (lila)")
	check(Glow.kind_for(exit) == &"normal", "open door = normal (krem)")
	check(Glow.label_for(watch) == "Cep Saati", "watch label 'Cep Saati'")
	var g: Sprite2D = watch.get_node_or_null("InteractGlow")
	check(g != null, "glow attached to watch")
	check(g and g.self_modulate.r < 0.8 and g.self_modulate.b > 0.9, "memory glow is lilac/blue %s" % (g.self_modulate if g else ""))
	var lp: Node = load("res://scripts/world/lore_point.gd").new()
	lp.set("texture_path", "res://assets/props/red_flower.png")
	check(Glow.label_for(lp) == "Kırmızı Çiçek", "lore red flower label")
	lp.free()
	var ldoor_scene := (rm._rooms[&"awakening_seal"] as Dictionary)["root"] as Node
	var ldoor: Node = null
	for n in ldoor_scene.find_children("*", "Area2D", true, false):
		if n.has_method("is_locked") and n.is_locked():
			ldoor = n
			break
	check(ldoor != null and Glow.kind_for(ldoor) == &"cursed" and Glow.label_for(ldoor) == "Mühürlü Kapı", "locked door = cursed + 'Mühürlü Kapı'")

	## 2) Menzil + en yakın hedef + yalnız hedef parlar.
	player.global_position = Vector2(watch.global_position.x - 150, 288)
	await create_timer(0.25).timeout
	check(player.get_interaction_target() != watch, "far away → watch not target")
	var far_hits := 0
	player.global_position = Vector2(watch.global_position.x, 288)
	await create_timer(0.3).timeout
	check(player.get_interaction_target() == watch, "close → watch is target")
	check(g.is_current_target(), "watch glow marked as current target")
	var lbl: Label = watch.get_node_or_null("InteractNameLabel")
	check(lbl != null and lbl.visible and lbl.text == "Cep Saati", "name label shown on approach")
	var sg: Sprite2D = shilda_beat.get_node_or_null("InteractGlow") if shilda_beat != null else null
	check(sg == null or not sg.is_current_target(), "other object not highlighted")
	player.global_position = Vector2(watch.global_position.x - 150, 288)
	await create_timer(0.5).timeout
	check(not g.is_current_target() and (lbl == null or not lbl.visible), "label hides when leaving")
	## İki sayaç: oyuncu birine daha yakın → yalnız o tetiklenir.
	var a := _make_counter(room, Vector2(700, 270))
	var b := _make_counter(room, Vector2(724, 270))
	player.global_position = Vector2(698, 288)
	player.set("_facing", 1.0)
	await create_timer(0.25).timeout
	check(player.get_interaction_target() == a, "nearest of two picked")
	player._on_interact()
	player._on_interact() ## aynı karede ikinci basış → korumalı
	check(a.hits == 1 and b.hits == 0, "single trigger, nearest only (a=%d b=%d)" % [a.hits, b.hits])
	await create_timer(0.3).timeout
	player._on_interact()
	check(a.hits == 2, "after debounce window interact works again")
	player.global_position = Vector2(900, 288)
	await create_timer(0.25).timeout
	player._on_interact()
	check(a.hits == 2 and b.hits == 0 + far_hits, "out of range → nothing triggers")
	a.queue_free()
	b.queue_free()

	## 3) Shilda yalnız sakinken.
	var keeper := current_scene.get_tree().get_first_node_in_group("keeper")
	if keeper == null:
		keeper = current_scene.find_child("Keeper", true, false)
	if keeper and keeper.has_method("can_interact"):
		var old_mode = keeper.mode
		keeper.mode = keeper.Mode.COMBAT
		check(not keeper.can_interact(), "Shilda in combat → cannot talk")
		dm.clear()
		keeper.on_interact(player)
		check(not dm.is_open, "combat Shilda opens no dialogue")
		keeper.mode = keeper.Mode.OBSERVE
		check(keeper.can_interact(), "calm Shilda → can talk")
		keeper.mode = old_mode
	else:
		check(false, "keeper node with can_interact found")
	print("INTERACT_AUDIT failures=", failures)
	sm.delete_all_save_files()
	quit(1 if failures else 0)
