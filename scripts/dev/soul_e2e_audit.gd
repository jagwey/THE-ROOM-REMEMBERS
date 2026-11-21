extends SceneTree
## Parçalanmış Ruhlar uçtan uca oynanış denetimi (v1.20.0+): gerçek ana sahne, gerçek fizik çerçeveleri,
## oyuncunun gerçek saldırı yolu (`_on_attack` + attack_area), gerçek ölüm/diriliş, gerçek final dizisi.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/soul_e2e_audit.gd
var failures := 0
var state: Node
var sm: Node
var rm: Node
var soul: Node
var dm: Node
var gate: Node
var player: CharacterBody2D
var table: Array = [] ## denge tablosu satırları

const DT := 1.0 / 60.0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("E2E ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	sm = root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("E2E SKIP (run with TORIMON_TEST=1 so the player save is never touched)")
		quit(0)
		return
	state = root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	dm = root.get_node("DialogueManager")
	gate = root.get_node("UiGate")
	dm.clear()
	gate.set_story(false)
	rm = root.get_node("RoomManager")
	soul = root.get_node("SoulManager")
	player = current_scene.get_node("Player")
	await _idle_pressure()
	await _kill_balance()
	await _spark_flow()
	await _spark_timeout()
	await _death_and_save()
	await _ui_pause()
	await _other_rooms_and_blocking()
	await _final_twice()
	_print_table()
	print("E2E DONE failures=", failures)
	quit(1 if failures > 0 else 0)


# --- Yardımcılar ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Savaş/oda laneti bu denetimde dengeyi bozmasın (ele geçirilme yeniden yüklemesi testi yanıltır).
func _nocurse() -> void:
	var cm: Node = root.get_node("CurseManager")
	if not cm.possessing:
		cm.set_curse(0.0)


func _enter(rid: StringName) -> void:
	while root.get_node("CurseManager").possessing or root.get_node("DeathManager").is_dying:
		await process_frame
	rm.enter_room(rid, &"default")
	await create_timer(0.25).timeout
	dm.clear()
	gate.set_story(false)
	root.get_node("CurseManager").set_curse(0.0)
	state.hearts = state.max_hearts


func _enemies(rid: StringName) -> Array:
	var out: Array = []
	for n in rm._rooms[rid]["root"].get_children():
		if n.is_in_group("soul_enemy") and not bool(n.get("_dead")):
			out.append(n)
	return out


func _enemy(rid: StringName, kind: String) -> Node:
	for e in _enemies(rid):
		if String(e.get("kind")) == kind:
			return e
	return null


func _spark_in(rid: StringName, sid: String) -> Node:
	for n in rm._rooms[rid]["root"].get_children():
		if n.is_in_group("soul_spark") and String(n.get("soul_id")) == sid:
			return n
	return null


func _put_player(at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.set("_hurt_cooldown", 0.0)


func _room_rect(rid: StringName) -> Rect2:
	return rm._rooms[rid]["bounds"]


## Düşman gezinme sınırı (leash) + oda sınırı + düşmeme kontrolü. Bozulursa mesaj döner.
func _bounds_problem(e: Node, rid: StringName) -> String:
	var lo: float = float(e.home_x) - float(e.cfg["leash"]) - 4.0
	var hi: float = float(e.home_x) + float(e.cfg["leash"]) + 4.0
	var p: Vector2 = e.global_position
	var r := _room_rect(rid)
	if p.x < lo or p.x > hi:
		return "left leash x=%.0f" % p.x
	if p.x < r.position.x or p.x > r.end.x:
		return "left room x=%.0f" % p.x
	if p.y > 320.0 or p.y < 150.0:
		return "bad y=%.0f" % p.y
	return ""


# --- 1. Boşta oyuncu: düşmanlar gerçekten yaralar, sıkışmaz/kaçmaz ---------------------------

func _idle_pressure() -> void:
	for rid_s in soul.SOULS.keys():
		var rid := StringName(rid_s)
		await _enter(rid)
		var list := _enemies(rid)
		check(list.size() == (soul.SOULS[rid_s] as Array).size(), "%s: enemies present" % rid_s, list.size())
		## (a) Her düşman tek başına: boşta duran oyuncuyu gerçekten yaralamalı.
		for e in list:
			for o in list:
				o.set_physics_process(o == e)
			var dist := 150.0 if String(e.kind) == "whisper" else 48.0
			e.global_position = Vector2(e.home_x, 288.0)
			e.set("_cd", 0.0)
			_put_player(Vector2(float(e.home_x) - dist, 288.0))
			state.hearts = state.max_hearts
			var h0: int = state.hearts
			var first := -1.0
			var worst := ""
			for i in 540:
				await physics_frame
				_nocurse()
				if first < 0.0 and state.hearts < h0:
					first = float(i) * DT
				var pr := _bounds_problem(e, rid)
				if pr != "" and worst == "":
					worst = pr
				if state.hearts <= 1:
					state.hearts = state.max_hearts ## ölüm yarışını önle; kayıp sayımı h0'a göre kalır
					h0 = state.hearts
			check(first >= 0.0, "%s: idle player hurt by %s" % [rid_s, e.kind], "first hit @ %.2fs" % first)
			check(worst == "", "%s: %s stays in bounds while attacking" % [rid_s, e.kind], worst)
			## Çekirdek kural: ilk darbe adil uyarıdan önce gelmez (aggro'ya girdikten >= 0.5 sn).
			check(first >= 0.5 or first < 0.0, "%s: %s first hit not instant" % [rid_s, e.kind], first)
			## Tüm düşmanlar yeniden etkin.
			for o in list:
				o.set_physics_process(true)
			for n in get_nodes_in_group("soul_projectile"):
				n.queue_free()
			e.set("_state", 0)
			await _frames(70) ## i-frame bitsin
		## (b) Hepsi birlikte, oyuncu ortada boşta: oda dışına taşma/zemin kaybı yok, kalp düşer.
		var mean := 0.0
		for e in list:
			mean += float(e.home_x)
			e.global_position = Vector2(e.home_x, 288.0)
			e.velocity = Vector2.ZERO
			e.set("_state", 0)
			e.set("_cd", 0.0)
		mean /= float(list.size())
		_put_player(Vector2(mean, 288.0))
		state.hearts = state.max_hearts
		var lost := 0
		var prev: int = state.hearts
		var t_death := -1.0
		var bad := ""
		for i in 480:
			await physics_frame
			_nocurse()
			if state.hearts < prev:
				lost += prev - state.hearts
			prev = state.hearts
			for e in list:
				var pr := _bounds_problem(e, rid)
				if pr != "" and bad == "":
					bad = "%s: %s" % [e.name, pr]
			if state.hearts <= 1:
				state.hearts = state.max_hearts
				prev = state.hearts
				if t_death < 0.0:
					t_death = float(i) * DT
		check(bad == "", "%s: all enemies together stay in bounds" % rid_s, bad)
		check(lost > 0, "%s: group pressure drops hearts" % rid_s, "lost=%d" % lost)
		## 3 kalpten tam dolu: ilk 3 sn içinde oyuncu ölmemeli (2 sn i-frame).
		check(t_death < 0.0 or t_death >= 3.0, "%s: no kill-in-<3s from full hearts" % rid_s, t_death)
		for n in get_nodes_in_group("soul_projectile"):
			n.queue_free()


# --- 2. Gerçek kılıçla öldür + denge tablosu --------------------------------------------------

## Oyuncu botu: gerçek `_on_attack` yolu. Düşmana yeterince yakınsa vurur; değilse "dash" ile (ışınlanma, 0.5 sn aralık)
## uygun yana geçer. mode: "front" | "back".
func _kill(e: Node, mode: String) -> Dictionary:
	var rid := StringName(rm.get_active_room_id())
	var swings := 0
	var hits := 0
	var lost := 0
	var revived := 0
	var frames := 0
	var tp_cd := 0.0
	var prev_hp: int = e.health
	var prev_h: int = state.hearts
	var bounce := 0
	var modal_frames := 0
	while not bool(e._dead) and frames < 60 * 40:
		await physics_frame
		_nocurse()
		frames += 1
		tp_cd -= DT
		if gate.current_layer() != gate.Layer.NONE:
			modal_frames += 1 ## toplama fısıltısı vb. modal: kapat (oyuncu geçer)
			dm.clear()
			gate.set_story(false)
		if state.hearts < prev_h:
			lost += prev_h - state.hearts
		prev_h = state.hearts
		if state.hearts <= 1:
			state.hearts = state.max_hearts
			prev_h = state.hearts
			revived += 1
		if int(e.health) < prev_hp:
			hits += prev_hp - int(e.health)
		prev_hp = e.health
		if bool(e._dead):
			break
		var ex: float = e.global_position.x
		var px: float = player.global_position.x
		var want_side: float = -float(e._facing) if mode == "back" else (signf(px - ex) if px != ex else -1.0)
		var side_ok := signf(px - ex) == want_side
		var close := absf(px - ex) <= 36.0
		if not close and side_ok:
			## Gerçekçi yaklaşma: koşu hızıyla yürü (ışınlanma yok).
			player.global_position.x += signf(ex - px) * 130.0 * DT
		elif not side_ok and absf(px - ex) <= 70.0 and tp_cd <= 0.0:
			## Yanlış taraftaysa: dash ile arkaya geç (0.5 sn aralık).
			_put_player(Vector2(ex + want_side * 30.0, 288.0))
			tp_cd = 0.5
		elif not side_ok:
			player.global_position.x += signf(ex - px) * 130.0 * DT
		var dx: float = ex - player.global_position.x
		player.set("_facing", signf(dx) if dx != 0.0 else 1.0)
		if absf(dx) <= 40.0 and player._state != &"attack":
			player._on_attack()
			swings += 1
	if not bool(e._dead):
		print("E2E DEBUG stuck: layer=%d locked=%s state=%s pos=%s epos=%s hp=%d hearts=%d" % [gate.current_layer(), str(player._input_locked), str(player._state), str(player.global_position), str(e.global_position), e.health, state.hearts])
	return {"swings": swings, "hits": hits, "secs": float(frames) * DT, "lost": lost, "revived": revived,
		"dead": bool(e._dead), "modal": modal_frames}


func _kill_balance() -> void:
	var plan := [
		[&"library_hall", "crawler", "front"],
		[&"library_hall", "whisper", "front"],
		[&"library_upper_stacks", "crawler", "front"],
		[&"library_upper_stacks", "warden", "back"],
		[&"experiment_quarantine", "crawler", "front"],
		[&"experiment_quarantine", "warden", "back"],
		[&"experiment_quarantine", "whisper", "front"],
		[&"experiment_observation", "crawler", "front"],
		[&"experiment_observation", "whisper", "front"],
	]
	var by_kind := {}
	for p in plan:
		var rid: StringName = p[0]
		await _enter(rid)
		var e := _enemy(rid, p[1])
		check(e != null, "%s/%s present for kill test" % [rid, p[1]])
		if e == null:
			continue
		## Oyuncu girişten gelir: düşmanı yalnız hedefle (diğerleri duraksın) — tek tür dengesi.
		for o in _enemies(rid):
			o.set_physics_process(o == e)
		_put_player(Vector2(float(e.home_x) - 140.0, 288.0))
		var r := await _kill(e, p[2])
		for o in _enemies(rid):
			o.set_physics_process(true)
		check(bool(r["dead"]), "%s/%s killable with real attack (%s)" % [rid, p[1], p[2]], r)
		check(int(r["lost"]) <= 2, "%s/%s costs <= 2 hearts to kill" % [rid, p[1]], r["lost"])
		check(int(r["revived"]) == 0, "%s/%s never drops player to 1 heart-line" % [rid, p[1]], r["revived"])
		if not by_kind.has(p[1]):
			by_kind[p[1]] = r
		table.append([String(rid), p[1], p[2], int(r["swings"]), int(r["hits"]), float(r["secs"]), int(r["lost"])])
		var sp := _spark_in(rid, String(e.soul_id))
		check(sp != null, "%s/%s kill dropped spark" % [rid, p[1]])
		print("E2E NOTE %s/%s melee kill auto-claimed spark: %s" % [rid, p[1], str(soul.is_collected(String(e.soul_id)))])
		if sp:
			sp.queue_free()
		for n in get_nodes_in_group("soul_projectile"):
			n.queue_free()
		await process_frame
		soul.reset_ledger() ## melee ölümünde kıvılcım anında toplanır; sonraki turlar için sıfırla
		## Ledger'a dokunma: kıvılcım toplanmadı; odaya yeniden girmek düşmanı döndürür.
	## Kalkan: önden vuruş sektirir (gerçek saldırı yolu).
	soul.reset_ledger()
	await _enter(&"library_upper_stacks")
	var w := _enemy(&"library_upper_stacks", "warden")
	for o in _enemies(&"library_upper_stacks"):
		o.set_physics_process(o == w)
	w.set("_cd", 99.0)
	w.set("_state", 0)
	w.global_position = Vector2(w.home_x, 288.0)
	var f: float = w._facing
	_put_player(Vector2(w.global_position.x + f * 32.0, 288.0))
	player.set("_facing", -f)
	await _frames(3)
	var h0: int = w.health
	for k in 3:
		player._on_attack()
		await _frames(18)
	check(w.health == h0, "warden: 3 real frontal swings all bounce", [h0, w.health])
	## Toparlanma penceresinde (RECOVER) önden vuruş işler.
	w.set("_state", 3)
	w.set("_state_t", 5.0)
	await _frames(20)
	player._on_attack()
	await _frames(14)
	check(w.health < h0, "warden: frontal real swing works during recovery", [h0, w.health])
	for o in _enemies(&"library_upper_stacks"):
		o.set_physics_process(true)


# --- 3. Kıvılcım toplama: sayaç, HUD, günlük --------------------------------------------------

func _spark_flow() -> void:
	soul.reset_ledger()
	await _enter(&"library_hall")
	var e := _enemy(&"library_hall", "crawler")
	for o in _enemies(&"library_hall"):
		o.set_physics_process(o == e)
	_put_player(Vector2(float(e.home_x) - 60.0, 288.0))
	e.receive_soul_slash(null) ## menzilli öldürme (Ruh Kesimi): kıvılcım anında toplanmaz
	e.receive_soul_slash(null)
	await _frames(2)
	check(bool(e._dead), "spark flow: crawler killed (ranged)")
	var sp := _spark_in(&"library_hall", "library_hall/crawler")
	check(sp != null, "spark flow: spark exists")
	if sp == null:
		return
	var cm: Node = root.get_node("CurseManager")
	cm.set_curse(40.0)
	var c0: float = cm.curse
	check(not soul.is_collected("library_hall/crawler"), "spark flow: ranged kill does not auto-claim")
	## Oyuncu kıvılcımın bulunduğu yere yürür (fizik gövdesi girişi → body_entered ya da step yakalama).
	_put_player(Vector2(sp.global_position.x, 288.0))
	await _frames(20)
	check(soul.is_collected("library_hall/crawler"), "spark flow: walking onto spark collects soul")
	check(cm.curse <= c0 - 9.0, "spark flow: curse dropped ~10", [c0, cm.curse])
	check(soul.collected_count() == 1, "spark flow: counter 1/9", soul.collected_count())
	var hud: Node = get_first_node_in_group("hud")
	check(hud != null and hud._soul_label.visible and hud._soul_label.text == "Ruhlar 1/2 (1/9)", "spark flow: HUD updates live", hud._soul_label.text if hud else "")
	var jl := "\n".join(soul.journal_lines())
	check("Kütüphane" in jl and "1/2" in jl, "spark flow: journal lines report 1/2", jl)
	## Gerçek günlük sayfası.
	var jui: Node = get_first_node_in_group("journal_ui")
	if jui != null:
		var notes: Array = []
		jui._append_world_traces(notes)
		var found := false
		for n in notes:
			if String(n.get("title", "")).begins_with("Parçalanmış Ruhlar 1/9"):
				found = true
		check(found, "spark flow: journal page has Parçalanmış Ruhlar 1/9 entry")
	dm.clear()
	gate.set_story(false)
	## Odadan çık-gir: toplanan ruhun düşmanı yok, diğeri var.
	await _enter(&"awakening")
	await _enter(&"library_hall")
	check(_enemy(&"library_hall", "crawler") == null, "spark flow: collected crawler absent after re-entry")
	check(_enemy(&"library_hall", "whisper") != null, "spark flow: uncollected whisper present")
	for o in _enemies(&"library_hall"):
		o.set_physics_process(true)


func _spark_timeout() -> void:
	await _enter(&"library_hall")
	var e := _enemy(&"library_hall", "whisper")
	for o in _enemies(&"library_hall"):
		o.set_physics_process(o == e)
	_put_player(Vector2(60.0, 288.0))
	e.receive_soul_slash(null)
	await _frames(2)
	check(bool(e._dead), "timeout: whisper killed (ranged)")
	var sp := _spark_in(&"library_hall", "library_hall/whisper")
	check(sp != null, "timeout: spark exists")
	if sp == null:
		return
	var n0: int = soul.collected_count()
	check(not soul.is_collected("library_hall/whisper"), "timeout: spark not auto-claimed at kill time")
	await _frames(60 * 5 + 30)
	check(not is_instance_valid(sp) or sp.is_queued_for_deletion(), "timeout: spark vanishes after ~5s")
	var back := _enemy(&"library_hall", "whisper")
	check(back != null, "timeout: enemy respawned")
	if back:
		check(back.health == int(back.cfg["hp"]) and absf(back.global_position.x - float(back.home_x)) < 8.0, "timeout: respawned enemy fresh at home", [back.health, back.global_position])
	check(soul.collected_count() == n0, "timeout: ledger unchanged", soul.collected_count())
	for n in get_nodes_in_group("soul_projectile"):
		n.queue_free()


# --- 4. Savaşta ölüm + kayıt/yükleme --------------------------------------------------------

func _death_and_save() -> void:
	## Önceden 1 ruh toplanmış (library_hall/crawler). Savaşta öl.
	await _enter(&"library_hall")
	var cm: Node = root.get_node("CurseManager")
	var death: Node = root.get_node("DeathManager")
	var w := _enemy(&"library_hall", "whisper")
	w.set("_state", 1)
	w.set("_state_t", 0.4)
	cm.set_curse(55.0)
	_put_player(Vector2(float(w.home_x) - 140.0, 288.0))
	state.damage(99)
	var t := 0.0
	while death.is_dying and t < 30.0:
		await process_frame
		t += DT
	await create_timer(0.4).timeout
	dm.clear()
	gate.set_story(false)
	check(not death.is_dying, "death: rebirth completes")
	check(cm.curse <= 0.5, "death: curse reset to 0 after rebirth", cm.curse)
	check(soul.is_collected("library_hall/crawler") and soul.collected_count() == 1, "death: collected souls persist", soul.collected_count())
	var rid := StringName(rm.get_active_room_id())
	var bad := ""
	for r in [rid]:
		for e in _enemies(StringName(r)):
			if int(e.health) != int(e.cfg["hp"]): ## AI durumu zamana bağlı (yeniden doğunca yeniden saldırabilir)
				bad += "%s hp=%d st=%d; " % [e.name, e.health, e._state]
			if bool(e._dead):
				bad += e.name + " dead; "
	check(bad == "", "death: living enemies are reset/sane", bad)
	## Aktif odadaki düşman, oyuncu yeniden doğduktan sonra anında vurmaz (i-frame / uyarı).
	await _frames(30)
	check(state.hearts == state.max_hearts, "death: full hearts right after rebirth", state.hearts)
	## Kayıt → "yeni süreç" benzetimi → yükle.
	check(sm.save_game(), "save: save_game ok")
	soul.reset_ledger()
	check(soul.collected_count() == 0, "save: ledger wiped (simulated fresh process)")
	check(sm.load_game(false), "save: load_game ok")
	check(soul.is_collected("library_hall/crawler"), "save: collected soul persists across save/load", soul.collected_count())
	await _enter(&"library_hall")
	check(_enemy(&"library_hall", "crawler") == null, "save: collected enemy does not respawn after load")
	check(_enemy(&"library_hall", "whisper") != null, "save: uncollected enemy still spawns after load")


# --- 5. UI açıkken tehdit durur ---------------------------------------------------------------

func _ui_pause() -> void:
	await _enter(&"library_hall")
	var e := _enemy(&"library_hall", "whisper")
	for o in _enemies(&"library_hall"):
		o.set_physics_process(o == e)
	_put_player(Vector2(60.0, 288.0))
	var modes := {"story": [Callable(gate, "set_story")], "journal": [Callable(gate, "set_journal")], "pause": [Callable(gate, "set_pause_menu")]}
	for m in modes.keys():
		e.set("_state", 1)
		e.set("_state_t", 0.6)
		var cb: Callable = modes[m][0]
		cb.call(true)
		var hp0: int = state.hearts
		await _frames(30)
		check(is_equal_approx(float(e.get("_state_t")), 0.6), "ui pause (%s): enemy AI frozen" % m, e.get("_state_t"))
		check(state.hearts == hp0, "ui pause (%s): no damage" % m)
		cb.call(false)
		await _frames(2)
	## Kıvılcım ömrü UI açıkken akmaz.
	var sp: Node = (load("res://scripts/world/soul_spark.gd") as GDScript).spawn_at(rm._rooms[&"library_hall"]["root"], Vector2(700, 270), "library_hall/whisper")
	var ttl0: float = sp.time_left()
	gate.set_journal(true)
	await _frames(30)
	check(is_equal_approx(sp.time_left(), ttl0), "ui pause: spark lifetime frozen", [ttl0, sp.time_left()])
	gate.set_journal(false)
	sp.queue_free()
	for o in _enemies(&"library_hall"):
		o.set_physics_process(true)
	e.set("_state", 0)


# --- 6. Diğer odalar + engelleme -----------------------------------------------------------------

func _other_rooms_and_blocking() -> void:
	var stray := []
	for k in rm._rooms.keys():
		if soul.SOULS.has(String(k)):
			continue
		rm.enter_room(StringName(k), &"default")
		await create_timer(0.08).timeout
		dm.clear()
		gate.set_story(false)
		var root_node: Node = rm._rooms[k]["root"]
		for n in root_node.get_children():
			if n.is_in_group("soul_enemy") or n.is_in_group("soul_spark"):
				stray.append(String(k))
	check(stray.is_empty(), "no soul enemies outside the 4 rooms", stray)
	## 4 odada: gezinme bölgesi bulmaca plakası / mühür / kapıyla çakışmaz, fiziksel olarak engellemez.
	for rid_s in soul.SOULS.keys():
		var rid := StringName(rid_s)
		await _enter(rid)
		for e in _enemies(rid):
			check((int(e.collision_layer) & 1) == 0, "%s/%s does not occupy the world layer" % [rid_s, e.kind])
			var lo: float = float(e.home_x) - float(e.cfg["leash"]) - 20.0
			var hi: float = float(e.home_x) + float(e.cfg["leash"]) + 20.0
			for g in ["pressure_plate", "memory_seal_point"]:
				for n in get_nodes_in_group(g):
					if not (n as Node2D).is_visible_in_tree() or not rm._rooms[rid]["root"].is_ancestor_of(n):
						continue
					var nx: float = (n as Node2D).global_position.x
					check(nx < lo or nx > hi, "%s/%s patrol range clear of %s" % [rid_s, e.kind, g], [lo, hi, nx])
			for n in rm._rooms[rid]["root"].get_children():
				if n.is_in_group("puzzle_gate") or n.is_in_group("gate"):
					var gx: float = (n as Node2D).global_position.x
					check(gx < lo or gx > hi, "%s/%s patrol range clear of gate" % [rid_s, e.kind], [lo, hi, gx])


# --- 7. Final: hüküm satırı gerçekten gösterilir ----------------------------------------------

func _final_twice() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://qa/settings.cfg") == OK:
		cfg.set_value("progress", "final_seen", false)
		cfg.save("user://qa/settings.cfg")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "") ## final satırları otomatik ilerlesin
	var em := root.get_node("EndingManager")
	root.get_node("PuzzleManager").mark_solved(&"core_seal")
	state.set_world_flag(&"seal_shard_1", true)
	state.set_world_flag(&"seal_shard_2", true)
	state.player_progress_knowledge["ability_soul_slash"] = true
	state.set_shilda_named(true)
	var partial_line := "Hepsini getirmedin. Kalanlar bu odalarda sonsuza dek dolaşacak."
	var all_line := "Hepsini getirdin. Senden önce gelenler artık gidebilir."
	var shown: Array = []
	dm.line_shown.connect(func(sp: String, tx: String) -> void: shown.append([sp, tx]))
	for run in 2:
		var full := run == 1
		soul.reset_ledger()
		if full:
			for r in soul.SOULS.keys():
				for en in soul.SOULS[r]:
					soul.collect(String(en["id"]))
		else:
			soul.collect("library_hall/crawler")
			soul.collect("experiment_quarantine/warden")
		state.set_story_flag(&"game_completed", false)
		shown.clear()
		await _enter(&"core")
		check(em.can_begin_final(), "final run %d: prerequisites open" % run)
		await em.trigger(em.Ending.PART_ONE, true)
		var r: Dictionary = (load("res://scripts/story/final_sequence.gd") as GDScript).get("last_run")
		check(bool(r.get("souls_all", false)) == full, "final run %d: souls_all=%s" % [run, str(full)], r.get("souls_collected"))
		var texts: Array = []
		var speakers := {}
		for s in shown:
			texts.append(String(s[1]).replace("\n", " "))
			speakers[String(s[1]).replace("\n", " ")] = String(s[0])
		var want := all_line if full else partial_line
		var other := partial_line if full else all_line
		var got := false
		for tx in texts:
			if String(tx).begins_with(want.substr(0, 20)) or want.begins_with(String(tx)):
				got = true
		var wrong := false
		for tx in texts:
			if String(tx).begins_with(other.substr(0, 20)):
				wrong = true
		check(got, "final run %d: Shilda verdict line shown in real dialogue" % run, texts.filter(func(t): return "Hepsini" in String(t)))
		check(not wrong, "final run %d: opposite verdict NOT shown" % run)
		var spk := ""
		for tx in texts:
			if String(tx).begins_with(want.substr(0, 20)):
				spk = String(speakers[tx])
		check(spk == "Shilda", "final run %d: verdict spoken by Shilda" % run, spk)
		var count := 0
		for tx in texts:
			if "Hepsini" in String(tx):
				count += 1
		check(count >= 1 and count <= 2, "final run %d: verdict shown once (pages ok)" % run, count)
		check(gate.current_layer() != gate.Layer.CUTSCENE and not gate.blocks_movement(), "final run %d: input released" % run)
		await create_timer(0.3).timeout
		dm.clear()
		gate.set_story(false)


func _print_table() -> void:
	print("E2E BALANCE enemy_type | room | approach | swings | hits | seconds | hearts_lost")
	for r in table:
		print("E2E BALANCE %s | %s | %s | %d | %d | %.2f | %d" % [r[1], r[0], r[2], r[3], r[4], r[5], r[6]])
