extends SceneTree
## Gezinme botu: gerçek Player ile (manuel _physics_process adımları) her odada her doğuş noktasından
## kapılara / etkileşimlere ulaşılabilirlik araması (BFS: yürü, koş-zıpla, atıl, zıpla+atıl).
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/traversal_bot_audit.gd -- [oda1,oda2,...] [shadow]
## Rapor satırları: TRAV ... (UNREACH / SPAWN_BAD / VOID / NOFLOOR / OK)
## Yalnız jeometri/fizik; bulmaca kapıları oyundaki hâliyle bırakılır (kilitli kapı hedef sayılır, ayrıca not edilir).

const DT := 1.0 / 60.0
const MAX_NODES := 150
const QX := 24.0
const QY := 10.0

var player: CharacterBody2D
var rm: Node
var cur_bounds: Rect2
var pits: Array = []
var void_hits := 0
var failures := 0
var mim: Node
var dbg_walk := OS.get_environment("TRAV_DBG") != ""
var closed_mode := false
var dbg_void := 0
var curse: Node


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func _q(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x / QX)), int(round(p.y / QY)))


func _reset_player(p: Vector2) -> void:
	player.global_position = p
	player.velocity = Vector2.ZERO
	player._state = &"idle"
	player._dash_cd = 0.0
	player._dash_timer = 0.0
	player._jump_held = false
	player._jump_buffer = 0.0
	player._coyote = 0.1
	player._stagger_timer = 0.0
	player._attack_timer = 0.0
	player.collision_mask = 1 | 16
	curse.curse = 0.0  # atılma laneti besler; bota ele geçirilme/sendeleme karışmasın
	curse.possessing = false
	player._input_locked = false
	mim.move_vector = Vector2.ZERO


func _step(n: int = 1) -> void:
	for i in n:
		player._physics_process(DT)


func _in_pit(p: Vector2) -> bool:
	for pit in pits:
		var r: Rect2 = pit
		if p.x >= r.position.x - 4.0 and p.x <= r.end.x + 4.0:
			return true
	return false


## actions: [dir, run_frames, jump(bool), hold_frames, dash_frame(-1), total_frames]
func _sim(start: Vector2, dir: int, run: int, jump: bool, hold: int, dash_at: int, total: int) -> Dictionary:
	_reset_player(start)
	_step(2)
	var grounded: Array = []
	var fell := false
	var void_fall := false
	var was_air := false
	var jump_released := false
	var air_frames := 0
	mim.move_vector = Vector2(dir, 0)
	for f in total:
		if jump and f == run:
			mim.jump_pressed.emit()
		if jump and f == run + hold and not jump_released:
			mim.jump_released.emit()
			jump_released = true
		if dash_at >= 0 and f == dash_at:
			mim.dash_pressed.emit()
		_step(1)
		var p: Vector2 = player.global_position
		if player.is_on_floor():
			if f % 6 == 0 or was_air:
				grounded.append(p)
			was_air = false
			air_frames = 0
		else:
			was_air = true
			air_frames += 1
		if p.y > 400.0:
			if _in_pit(p):
				fell = true
			else:
				void_fall = true
				if dbg_void < 4:
					dbg_void += 1
					print("TRAV dbg void y p=", p, " start=", start, " act=", [dir, run, jump, hold, dash_at])
			break
		if p.x < cur_bounds.position.x - 80.0 or p.x > cur_bounds.end.x + 80.0:
			void_fall = true
			if dbg_void < 4:
				dbg_void += 1
				print("TRAV dbg void x p=", p, " start=", start, " act=", [dir, run, jump, hold, dash_at])
			break
	if dbg_walk and not jump and dash_at < 0:
		var c := player.get_last_slide_collision()
		if c != null and absf(c.get_normal().x) > 0.5:
			print("TRAV dbg walkend dir=", dir, " pos=", player.global_position, " collider=", (c.get_collider() as Node).get_path() if c.get_collider() is Node else "?", " layer=", (c.get_collider() as CollisionObject2D).collision_layer)
	if jump and not jump_released:
		mim.jump_released.emit()
	mim.move_vector = Vector2.ZERO
	# Son duruş: yerdeyse kaydet
	if player.is_on_floor():
		grounded.append(player.global_position)
	return {"grounded": grounded, "fell": fell, "void": void_fall}


func _actions() -> Array:
	var a: Array = []
	for d in [-1, 1]:
		a.append([d, 0, false, 0, -1, 80])  # yürü (kenara/duvara kadar)
		a.append([d, 20, false, 0, 20, 60])  # koş + yer atılması
	for hold in [40, 10]:
		for dash_at in [-1, 16]:
			a.append([0, 0, true, hold, dash_at, 90])
			for d in [-1, 1]:
				a.append([d, 0, true, hold, dash_at, 90])
				a.append([d, 18, true, hold, dash_at + 18 if dash_at >= 0 else -1, 108])
	return a


func _explore(start: Vector2, targets: Array = []) -> Dictionary:
	var seen := {}
	var nodes: Array = []
	var queue: Array = []
	var voids := 0
	var pit_falls := 0
	seen[_q(start)] = true
	nodes.append(start)
	queue.append(start)
	var acts := _actions()
	if dbg_walk:
		var rr := _sim(Vector2(477, 288), 1, 0, false, 0, -1, 80)
		print("TRAV dbg walk477 -> ", rr, " pos=", player.global_position, " vel=", player.velocity, " state=", player._state, " mask=", player.collision_mask, " ax=", mim.get_move_axis(), " block=", root.get_node("UiGate").blocks_movement())
	while not queue.is_empty() and nodes.size() < MAX_NODES:
		var cur: Vector2 = queue.pop_front()
		if not targets.is_empty() and _all_reached(targets, nodes):
			break
		if dbg_walk:
			print("TRAV dbg pop ", cur, " q=", queue.size(), " n=", nodes.size())
		for a in acts:
			var r := _sim(cur, a[0], a[1], a[2], a[3], a[4], a[5])
			if dbg_walk and queue.is_empty() and a[0] == 1 and a[1] == 0 and not a[2] and a[4] < 0:
				print("TRAV dbg lastnode walk ", cur, " -> ", r.grounded.size(), " last=", r.grounded.back() if r.grounded.size() > 0 else "-", " end=", player.global_position)
			if r.void:
				voids += 1
			if r.fell:
				pit_falls += 1
			for g in r.grounded:
				var gp: Vector2 = g
				var k := _q(gp)
				if not seen.has(k):
					seen[k] = true
					nodes.append(gp)
					queue.append(gp)
					if nodes.size() >= MAX_NODES:
						break
			if nodes.size() >= MAX_NODES:
				break
	return {"nodes": nodes, "voids": voids, "pit_falls": pit_falls, "capped": nodes.size() >= MAX_NODES}


func _reach_pos(t: Node2D, nodes: Array) -> Variant:
	var best: Variant = null
	var bd := 1e9
	for n in nodes:
		var p: Vector2 = n
		var dx := absf(p.x - t.global_position.x)
		var dy := t.global_position.y - p.y
		if dx <= 56.0 and dy > -90.0 and dy < 70.0:
			if dx < bd:
				bd = dx
				best = p
	return best


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("TRAV SKIP (TORIMON_TEST=1 ile çalıştır)")
		quit(0)
		return
	var args := OS.get_cmdline_user_args()
	var only: PackedStringArray = []
	var shadow := false
	for a in args:
		if a == "shadow":
			shadow = true
		elif a == "closed":
			closed_mode = true
		else:
			only = String(a).split(",", false)
	var gs := root.get_node("GameState")
	gs.player_progress_knowledge["awakening_mystery_seen"] = true
	gs.player_progress_knowledge["ability_shadow_dash"] = shadow
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.45).timeout
	mim = root.get_node("MobileInputManager")
	curse = root.get_node("CurseManager")
	var dm: Node = root.get_node("DialogueManager")
	rm = root.get_node("RoomManager")
	var gate: Node = root.get_node("UiGate")
	dm.clear()
	gate.set_story(false)
	player = current_scene.get_node("Player")
	var ids: Array = rm.ROOM_ORDER.duplicate()
	print("TRAV start shadow=", shadow, " rooms=", ids.size())
	for rid in ids:
		if not only.is_empty() and not only.has(String(rid)):
			continue
		var t0 := Time.get_ticks_msec()
		var entry: Dictionary = rm._rooms[rid]
		var room: Node2D = entry.root
		cur_bounds = entry.bounds
		var spawn_ids: Array = (entry.spawns as Dictionary).keys()
		if not spawn_ids.has(&"default"):
			spawn_ids.append(&"default")
		# hedefler
		var targets: Array = []
		for n in room.find_children("*", "Node2D", true, false):
			if n.is_in_group("room_door") or (n.has_method("on_interact") and not n.is_in_group("room_door")):
				targets.append(n)
		for spawn_id in spawn_ids:
			rm.enter_room(rid, spawn_id)
			await create_timer(0.08).timeout
			dm.clear()
			gate.set_story(false)
			curse.reset_for_new_life()
			# çukurlar
			pits.clear()
			for pit in get_nodes_in_group("pit"):
				if pit is Area2D and room.is_ancestor_of(pit):
					for c in pit.get_children():
						if c is CollisionShape2D and c.shape is RectangleShape2D:
							var sz: Vector2 = (c.shape as RectangleShape2D).size
							pits.append(Rect2(pit.global_position - sz * 0.5, sz))
			if not closed_mode:
				_open_blockers(room)
			# move_and_slide sabit fizik delta'sı için fizik çerçevesinin içinde çalış
			await physics_frame
			var sp: Vector2 = player.global_position
			# doğuş sağlığı
			var overlap: bool = player.test_move(player.global_transform, Vector2.ZERO)
			_reset_player(sp)
			_step(40)
			var settled: bool = player.is_on_floor()
			var fell_y: float = player.global_position.y
			if overlap or not settled or fell_y > 330.0:
				failures += 1
				print("TRAV SPAWN_BAD room=%s spawn=%s pos=%s overlap=%s grounded=%s y_after=%.0f" % [rid, spawn_id, sp, overlap, settled, fell_y])
			var start: Vector2 = player.global_position
			var res := _explore(start, targets)
			var nodes: Array = res.nodes
			var unreach: Array = []
			for t in targets:
				if not (t is Node2D) or not is_instance_valid(t):
					continue
				if _reach_pos(t, nodes) == null:
					var info := "%s@%s" % [t.name, (t as Node2D).global_position]
					if t.has_method("is_locked") and t.is_locked():
						info += "(kilitli)"
					unreach.append(info)
			if dbg_walk:
				var xs: Array = nodes.map(func(v): return int(v.x))
				xs.sort()
				print("TRAV dbg nodes_x=", xs)
			print("TRAV room=%s spawn=%s start=%s nodes=%d%s voidfalls=%d pitfalls=%d unreach=%d %s" % [rid, spawn_id, start, nodes.size(), "+" if res.capped else "", res.voids, res.pit_falls, unreach.size(), unreach])
			if res.voids > 0:
				print("TRAV VOID room=%s spawn=%s sims_falling_out_of_world_without_pit=%d" % [rid, spawn_id, res.voids])
		print("TRAV roomtime %s %.1fs targets=%d" % [rid, (Time.get_ticks_msec() - t0) / 1000.0, targets.size()])
	print("TRAV done failures=", failures)
	quit(0)



const OPENABLE := ["gate_blocker.gd", "curse_barrier.gd", "soul_seal.gd", "vine_gate.gd", "cracked_wall.gd", "weight_stone.gd"]


## Bulmaca engellerini (kapı, bariyer, mühür, itilen taş) kapat: geriye kalan engel = gerçek jeometri.
func _open_blockers(room: Node) -> void:
	for n in room.find_children("*", "CollisionObject2D", true, false):
		if n is Area2D:
			continue
		var sc: Script = n.get_script()
		if sc != null and OPENABLE.has(sc.resource_path.get_file()):
			(n as CollisionObject2D).collision_layer = 0


func _all_reached(targets: Array, nodes: Array) -> bool:
	for t in targets:
		if t is Node2D and is_instance_valid(t) and _reach_pos(t, nodes) == null:
			return false
	return true
