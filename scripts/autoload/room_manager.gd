extends Node
## Merkezi oda geçişi — tek aktif oda (görünür + işlem); kamera sınırı; ceset yenileme.

signal room_changed(from_room: StringName, to_room: StringName)

const InteractGlowScript := preload("res://scripts/world/interact_glow.gd")

## Sol-alt sanal joystick (x 14..114) arkasında doğmamak için sol sınırdan en az bu kadar içeride doğ.
const LEFT_SPAWN_MIN_X := 150.0

## Kalıcı oda sırası (01..N) ve Türkçe başlıklar — HUD oda başlığı bu tablodan okur.
const ROOM_ORDER: PackedStringArray = [
	"awakening", "awakening_balcony", "awakening_crypt", "awakening_passage", "awakening_seal", "awakening_vigil",
	"decay_vines", "decay_weight", "decay_greenhouse", "decay_shilda_wall", "decay_garden", "decay_catacombs", "decay_cistern",
	"library_hall", "library_witness", "library_clockroom", "library_page", "library_upper_stacks", "library_forbidden_wing", "library_reading_cell",
	"experiment_cells", "experiment_intake", "experiment_circuit", "experiment_authority", "experiment_quarantine", "experiment_core_conduit", "experiment_observation",
	"mirrors_reverse", "mirrors_dual", "mirrors_gallery", "mirrors_unbroken", "mirrors_labyrinth", "mirrors_shrine", "mirrors_1927",
	"core_threshold", "core_ascent", "core_seal_chamber", "core_memory_vault", "core_bloom_garden", "core",
]
const ROOM_TITLES_TR := {
	"awakening": "Uyanış", "awakening_balcony": "Gözlem Balkonu", "awakening_crypt": "İlk Bedenler Mahzeni",
	"awakening_passage": "Kırık Geçit", "awakening_seal": "Mühürlü Eşik", "awakening_vigil": "Nöbet Odası",
	"decay_vines": "Sarmaşık Yolu", "decay_weight": "Ağırlık Salonu", "decay_greenhouse": "Sera", "decay_garden": "Solmuş Bahçe",
	"decay_catacombs": "Kemik Mahzeni", "decay_shilda_wall": "Çatlak Duvar", "decay_cistern": "Sarnıç",
	"library_hall": "Hafıza Kütüphanesi", "library_witness": "Üç Tanık", "library_clockroom": "Saatler Odası", "library_page": "Unutulmuş Sayfa",
	"library_upper_stacks": "Üst Raflar", "library_forbidden_wing": "Yasak Kanat", "library_reading_cell": "Okuma Hücresi",
	"experiment_cells": "Gözlem Hücreleri", "experiment_intake": "Kabul Odası", "experiment_circuit": "Yankı Devresi", "experiment_authority": "Yetki Masası",
	"experiment_quarantine": "Kara Tecrit Mahzeni", "experiment_core_conduit": "Ruh Damarları Kanalı", "experiment_observation": "Gözlem Camı",
	"mirrors_reverse": "Ayna Geçidi", "mirrors_dual": "İki Yankı", "mirrors_gallery": "Bedenler Galerisi", "mirrors_unbroken": "Kırılmayan Ayna",
	"mirrors_labyrinth": "Yansıma Labirenti", "mirrors_shrine": "Ayna Tapınağı", "mirrors_1927": "Kırık Gece",
	"core_threshold": "Son Eşik", "core_ascent": "Son Merdiven", "core_seal_chamber": "Mühür Odası", "core_memory_vault": "Hafıza Kasası",
	"core_bloom_garden": "Çiçek Bahçesi", "core": "Çekirdek",
}

## Oda meta: bounds, isimli spawn, checkpoint (spawn yoksa), atmosfer klasörü, sahne kökü.
var _rooms: Dictionary = {} ## StringName -> { root, bounds, spawns, checkpoint, checkpoint_room, atmosphere_bg }

var _current: StringName = &""
var _extra_bootstrapped: bool = false

## Ek odalar — `main.tscn` dokunulmadan yüklenir (sahne kökü `World` altına eklenir).
const EXTRA_ROOM_SCENE_PATHS: PackedStringArray = [
	"res://scenes/rooms/library_hall.tscn",
	"res://scenes/rooms/library_witness.tscn",
	"res://scenes/rooms/library_page.tscn",
	"res://scenes/rooms/experiment_cells.tscn",
	"res://scenes/rooms/experiment_circuit.tscn",
	"res://scenes/rooms/experiment_authority.tscn",
	"res://scenes/rooms/mirrors_reverse.tscn",
	"res://scenes/rooms/mirrors_dual.tscn",
	"res://scenes/rooms/mirrors_unbroken.tscn",
	"res://scenes/rooms/core_threshold.tscn",
	"res://scenes/rooms/core_seal_chamber.tscn",
]


func _ready() -> void:
	## main.tscn odaları zaten instance eder; çift yükleme yok.
	## Etkileşilebilir her nesneye (sonradan eklenenler dahil) parlayan hale tak.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Node2D and n.has_method("on_interact"):
		call_deferred("_attach_glow", n)


## Tipsiz parametre: ertelenmiş çağrıdan önce silinen düğümde motor hatası vermesin.
func _attach_glow(n) -> void:
	if is_instance_valid(n) and n is Node2D:
		InteractGlowScript.attach_to(n as Node2D)


func _bootstrap_extra_rooms() -> void:
	if _extra_bootstrapped:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var world := main.get_node_or_null("World") as Node
	if world == null:
		push_warning("RoomManager: Main içinde World yok; ek odalar yüklenemedi.")
		return
	for path in EXTRA_ROOM_SCENE_PATHS:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			push_warning("RoomManager: sahne yüklenemedi %s" % path)
			continue
		var inst := scene.instantiate() as Node2D
		if inst == null:
			continue
		## Sahne kökünün adı (ör. LibraryHall) main.gd ROOM_DEFS["node"] ile eşleşmeli — dosya adı değil.
		if world.has_node(NodePath(StringName(inst.name))):
			inst.queue_free()
			continue
		inst.visible = false
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(inst)
	_extra_bootstrapped = true


func register_room(
		room_id: StringName,
		root: Node2D,
		bounds: Rect2,
		spawns: Dictionary = {},
		checkpoint: Vector2 = Vector2.ZERO,
		checkpoint_room: StringName = &"",
		atmosphere_bg: String = ""
	) -> void:
	if root == null:
		push_warning("RoomManager.register_room: root null for %s" % String(room_id))
		return
	var cp_room := checkpoint_room if checkpoint_room != &"" else room_id
	var entry := {
		"root": root,
		"bounds": bounds,
		"spawns": spawns,
		"checkpoint": checkpoint,
		"checkpoint_room": cp_room,
		"atmosphere_bg": atmosphere_bg,
	}
	_rooms[room_id] = entry


func has_room(room_id: StringName) -> bool:
	return _rooms.has(room_id)


func get_active_room_id() -> StringName:
	return _current


func get_active_room_root() -> Node2D:
	var entry: Variant = _rooms.get(_current, null)
	if entry == null:
		return null
	return (entry as Dictionary).get("root") as Node2D


func get_active_room_bounds() -> Rect2:
	var b := get_room_bounds(_current)
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		return Rect2(0, 0, 640.0, 360.0)
	return b


## "ODA 01 · Uyanış" — sıra ROOM_ORDER'dan; bilinmeyen oda "ODA ?? · <id>".
func get_room_number_and_title(room_id: StringName) -> String:
	var idx := ROOM_ORDER.find(String(room_id))
	var num := "??" if idx < 0 else "%02d" % (idx + 1)
	var title := String(ROOM_TITLES_TR.get(String(room_id), String(room_id).replace("_", " ").capitalize()))
	return "ODA %s · %s" % [num, title]


## Sol joystick arkasında doğmayı önler (yalnız sol sınıra yakın doğuşlar sağa kayar).
func _clear_of_joystick(pos: Vector2, bounds: Rect2) -> Vector2:
	var min_x := bounds.position.x + LEFT_SPAWN_MIN_X
	if pos.x < min_x and bounds.size.x > LEFT_SPAWN_MIN_X * 2.0:
		pos.x = min_x
	return pos


func get_room_bounds(room_id: StringName) -> Rect2:
	var e: Variant = _rooms.get(room_id, null)
	if e == null:
		return Rect2()
	return e["bounds"] as Rect2


## Kapı geçişini autoload üzerinde yürüt — kaynak odanın PROCESS_MODE_DISABLED oluşu await'i dondurmasın.
func run_door_travel(door: Node, player: Node2D, fade: CanvasLayer, rect: ColorRect) -> void:
	await _run_door_travel(door, player, fade, rect)


func _run_door_travel(door: Node, player: Node2D, fade: CanvasLayer, rect: ColorRect) -> void:
	var DoorScript = load("res://scripts/world/room_transition.gd")
	var tree := get_tree()
	if tree == null or not is_instance_valid(door):
		if DoorScript:
			DoorScript.reset_transition_lock()
		return
	var walk_time: float = float(DoorScript.WALK_TIME)
	var fade_out: float = float(DoorScript.FADE_OUT)
	var fade_in: float = float(DoorScript.FADE_IN)
	var target_room: StringName = door.target_room_id
	var target_spawn: StringName = door.target_spawn_id
	var door_x: float = (door as Node2D).global_position.x if door is Node2D else 0.0
	var tw := tree.create_tween()
	if player:
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
		var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		var walk := absf(door_x - player.global_position.x) > 2.0
		if sprite and walk:
			sprite.flip_h = door_x < player.global_position.x
		if walk and "scripted_walk" in player:
			player.set("scripted_walk", true)
		tw.tween_property(player, "global_position:x", door_x, walk_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(DoorScript._end_walk.bind(player))
		tw.tween_property(player, "modulate", Color(0.35, 0.28, 0.42, 1.0), fade_out)
		if is_instance_valid(rect):
			tw.parallel().tween_property(rect, "color:a", 1.0, fade_out)
	elif is_instance_valid(rect):
		tw.tween_property(rect, "color:a", 1.0, fade_out)
	await tw.finished
	if not is_instance_valid(tree):
		if is_instance_valid(fade):
			fade.queue_free()
		DoorScript.reset_transition_lock()
		return
	enter_room(target_room, target_spawn)
	if is_instance_valid(player):
		player.modulate = Color.WHITE
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO
	await tree.process_frame
	if not is_instance_valid(tree):
		if is_instance_valid(fade):
			fade.queue_free()
		DoorScript.reset_transition_lock()
		return
	if not is_instance_valid(rect):
		if is_instance_valid(fade):
			fade.queue_free()
		if is_instance_valid(door) and door.has_method("finish_travel_flags"):
			door.finish_travel_flags()
		DoorScript.reset_transition_lock()
		return
	var tw2 := tree.create_tween()
	tw2.tween_property(rect, "color:a", 0.0, fade_in)
	await tw2.finished
	if is_instance_valid(fade):
		fade.queue_free()
	if is_instance_valid(door) and door.has_method("finish_travel_flags"):
		door.finish_travel_flags()
	DoorScript.reset_transition_lock()


func enter_room(room_id: StringName, spawn_id: StringName = &"default", apply_room_checkpoint: bool = true) -> void:
	if not _rooms.has(room_id):
		push_warning("RoomManager.enter_room: unknown room %s" % String(room_id))
		return
	var from_id := _current
	## Oda değişti: eski "Kaydet ve Çık" konumu artık geçersiz.
	GameState.character_current_life_knowledge.erase("resume")
	_deactivate_all_rooms()
	_current = room_id
	var entry: Dictionary = _rooms[room_id]
	var root: Node2D = entry["root"]
	if root:
		root.visible = true
		root.process_mode = Node.PROCESS_MODE_INHERIT
		_set_room_physics(root, true)
		_set_room_canvas_layers(root, true)
		_setup_m3_mechanics(room_id, root, entry["spawns"])

	var bounds: Rect2 = entry["bounds"]
	var spawns: Dictionary = entry["spawns"]
	var spawn_pos: Vector2
	if spawn_id == &"checkpoint":
		spawn_pos = GameState.get_checkpoint()
	else:
		spawn_pos = spawns.get(spawn_id, Vector2.ZERO) as Vector2
		if spawn_pos == Vector2.ZERO:
			spawn_pos = entry["checkpoint"] as Vector2
		if spawn_pos == Vector2.ZERO:
			spawn_pos = Vector2(bounds.position.x + bounds.size.x * 0.5, 288.0)
	spawn_pos = _clear_of_joystick(spawn_pos, bounds)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		player.global_position = spawn_pos
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO

	GameState.character_current_life_knowledge["spawn_id"] = spawn_id
	GameState.mark_room_visited(room_id)
	if room_id == &"core_threshold":
		GameState.set_story_flag(&"core_access_granted")

	# F27: Gothic Region Title Cards & regions_visited
	var region := String(room_id).get_slice("_", 0)
	var visited_regions: Array = GameState.world_memory_state.get("regions_visited", [])
	if not visited_regions.has(region):
		visited_regions.append(region)
		GameState.world_memory_state["regions_visited"] = visited_regions
		var disc_reg: Array = GameState.player_progress_knowledge.get("discovered_regions", [])
		if not disc_reg.has(region):
			disc_reg.append(region)
			GameState.player_progress_knowledge["discovered_regions"] = disc_reg
		var card = get_tree().get_first_node_in_group("region_title_card")
		if card and card.has_method("show_region_title"):
			card.show_region_title(region)
		elif ResourceLoader.exists("res://scripts/ui/region_title_card.gd"):
			var card_cls = load("res://scripts/ui/region_title_card.gd")
			if card_cls and card_cls.has_method("show_region_title"):
				card_cls.show_region_title(region)

	if apply_room_checkpoint:
		var cp: Vector2 = entry["checkpoint"] as Vector2
		var cp_room: StringName = entry["checkpoint_room"] as StringName
		if cp != Vector2.ZERO:
			GameState.set_checkpoint(cp, cp_room)

	_apply_camera(bounds)

	CorpseManager.rebuild_world_corpses()
	if from_id != &"" and from_id != room_id:
		room_changed.emit(from_id, room_id)
	SaveManager.call_deferred("save_game")


func _deactivate_all_rooms() -> void:
	for k in _rooms.keys():
		var entry: Dictionary = _rooms[k]
		var root: Node2D = entry["root"] as Node2D
		if root == null:
			continue
		root.visible = false
		root.process_mode = Node.PROCESS_MODE_DISABLED
		_set_room_physics(root, false)
		_set_room_canvas_layers(root, false)


func apply_initial_room(room_id: StringName, spawn_id: StringName = &"default", teleport_to_spawn: bool = true) -> void:
	## İlk yüklemede sinyal dökme — sadece durum kur. Kayıt yüklendiyse teleport false (konum zaten cp).
	if not _rooms.has(room_id):
		push_warning("RoomManager.apply_initial_room: unknown %s" % String(room_id))
		return
	_deactivate_all_rooms()
	_current = room_id
	GameState.character_current_life_knowledge["room"] = room_id
	GameState.mark_room_visited(room_id)
	var entry: Dictionary = _rooms[room_id]
	var root: Node2D = entry["root"]
	if root:
		root.visible = true
		root.process_mode = Node.PROCESS_MODE_INHERIT
		_set_room_physics(root, true)
		_set_room_canvas_layers(root, true)
		_setup_m3_mechanics(room_id, root, entry["spawns"])

	var bounds: Rect2 = entry["bounds"]
	if teleport_to_spawn:
		var spawns: Dictionary = entry["spawns"]
		var spawn_pos: Vector2
		var resume: Variant = SaveManager.take_resume_point(room_id) if spawn_id == &"checkpoint" else null
		if resume is Vector2 and bounds.grow(8.0).has_point(resume):
			spawn_pos = resume ## Kaydet ve Çık → Devam et: tam kaldığı yer.
		else:
			if spawn_id == &"checkpoint":
				spawn_pos = GameState.get_checkpoint()
			else:
				spawn_pos = spawns.get(spawn_id, Vector2.ZERO) as Vector2
				if spawn_pos == Vector2.ZERO:
					spawn_pos = entry["checkpoint"] as Vector2
				if spawn_pos == Vector2.ZERO:
					spawn_pos = Vector2(bounds.position.x + bounds.size.x * 0.5, 288.0)
			spawn_pos = _clear_of_joystick(spawn_pos, bounds)
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			player.global_position = spawn_pos
			if player is CharacterBody2D:
				(player as CharacterBody2D).velocity = Vector2.ZERO

	_apply_camera(bounds)

	CorpseManager.rebuild_world_corpses()


func _apply_camera(bounds: Rect2) -> void:
	var cam := get_tree().get_first_node_in_group("follow_camera") as Camera2D
	if cam == null:
		return
	if cam.has_method("set_room_bounds"):
		cam.set_room_bounds(bounds)
	if cam.has_method("snap_to_target"):
		cam.snap_to_target()
	refit_parallax()


## Geniş ekran / zoom-out sonrası parallax katmanlarının tekrar sayısını görünür genişliğe göre ayarla.
func refit_parallax() -> void:
	if not _rooms.has(_current):
		return
	var root: Node2D = _rooms[_current]["root"]
	if root == null:
		return
	var cam := get_tree().get_first_node_in_group("follow_camera") as Camera2D
	var vis := root.get_viewport_rect().size
	if cam:
		vis /= maxf(cam.zoom.x, 0.5)
	var room_w: float = (_rooms[_current]["bounds"] as Rect2).size.x
	for child in root.get_children():
		if child is Parallax2D:
			var px := child as Parallax2D
			var rx := px.repeat_size.x
			if rx <= 0.0:
				continue
			var need := int(ceil((maxf(vis.x, room_w) + vis.x) / rx)) + 1
			px.repeat_times = maxi(px.repeat_times, need)


func _set_room_physics(node: Node, active: bool) -> void:
	# Process mode does not remove static bodies from the physics world.
	# Every room shares coordinates; explicitly isolate inactive geometry/areas.
	if node is CollisionObject2D:
		var object := node as CollisionObject2D
		if not active:
			if not object.has_meta("room_physics_suspended"):
				object.set_meta("room_saved_layer", object.collision_layer)
				object.set_meta("room_saved_mask", object.collision_mask)
				object.set_meta("room_physics_suspended", true)
			object.collision_layer = 0
			object.collision_mask = 0
		elif object.has_meta("room_physics_suspended"):
			var saved_layer: int = int(object.get_meta("room_saved_layer"))
			var saved_mask: int = int(object.get_meta("room_saved_mask"))
			# Açılmış engellerin katman 1 olarak yeniden canlanmasını engelle
			if object.has_method("_is_open") and bool(object.call("_is_open")):
				saved_layer = 0
			elif object.has_method("is_broken") and bool(object.call("is_broken")):
				saved_layer = 0
			elif "puzzle_id" in object and PuzzleManager.is_solved(object.get("puzzle_id")):
				saved_layer = 0
			elif "open_flag" in object and object.get("open_flag") != &"" and bool(GameState.get_world_flag(object.get("open_flag"), false)):
				saved_layer = 0
			object.collision_layer = saved_layer
			object.collision_mask = saved_mask
			object.remove_meta("room_physics_suspended")
	for child in node.get_children():
		_set_room_physics(child, active)


func _set_room_canvas_layers(node: Node, active: bool) -> void:
	# CanvasLayer is independent of its Node2D parent's visibility/process mode.
	if node is CanvasLayer:
		var canvas := node as CanvasLayer
		if not active:
			if not canvas.has_meta("room_canvas_suspended"):
				canvas.set_meta("room_saved_visible", canvas.visible)
				canvas.set_meta("room_canvas_suspended", true)
			canvas.visible = false
		elif canvas.has_meta("room_canvas_suspended"):
			canvas.visible = bool(canvas.get_meta("room_saved_visible"))
			canvas.remove_meta("room_canvas_suspended")
	for child in node.get_children():
		_set_room_canvas_layers(child, active)


func reset_registry() -> void:
	_rooms.clear()
	_current = &""
	_extra_bootstrapped = false


func _setup_m3_mechanics(room_id: StringName, root: Node2D, spawns: Dictionary) -> void:
	if root == null or root.has_meta("m3_mechanics_ready"):
		return
	root.set_meta("m3_mechanics_ready", true)

	var rid := String(room_id)

	# 1. Cracked Mirror setup (F28)
	const MIRROR_POSITIONS := {
		"awakening_balcony": Vector2(190, 288),
		"decay_garden": Vector2(465, 288),
		"library_hall": Vector2(190, 288),
		"experiment_cells": Vector2(280, 288),
		"mirrors_reverse": Vector2(280, 288),
	}
	if MIRROR_POSITIONS.has(rid):
		var pos: Vector2 = MIRROR_POSITIONS[rid]
		spawns["from_mirror"] = pos + Vector2(24, 0)
		var mirror_scene := load("res://scenes/props/cracked_mirror.tscn") as PackedScene
		if mirror_scene:
			var mirror := mirror_scene.instantiate() as Area2D
			mirror.mirror_id = room_id
			mirror.position = pos
			root.add_child(mirror)

	# 2. Walking Shades setup (F22)
	const WALKING_SHADES := {
		"decay_garden": [Vector2(420, 288)],
		"decay_catacombs": [Vector2(260, 288), Vector2(750, 288)],
		"experiment_cells": [Vector2(350, 288)],
	}
	if WALKING_SHADES.has(rid):
		var walk_scene := load("res://scenes/world/memory_shade_walking.tscn") as PackedScene
		if walk_scene:
			for p in WALKING_SHADES[rid]:
				var shade := walk_scene.instantiate() as CharacterBody2D
				shade.position = p
				root.add_child(shade)

	# 3. Shielded Shades setup (F23)
	const SHIELDED_SHADES := {
		"experiment_cells": [Vector2(650, 288)],
		"experiment_circuit": [Vector2(480, 288)],
		"mirrors_reverse": [Vector2(480, 288)],
		"mirrors_labyrinth": [Vector2(1060, 288)],
	}
	if SHIELDED_SHADES.has(rid):
		var shield_scene := load("res://scenes/world/memory_shade_shielded.tscn") as PackedScene
		if shield_scene:
			for p in SHIELDED_SHADES[rid]:
				var shade := shield_scene.instantiate() as CharacterBody2D
				shade.position = p
				root.add_child(shade)
