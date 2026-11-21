extends SceneTree
## Parçalanmış Ruhlar (v1.20.0) denetimi: düşman davranışı, kıvılcım, kalıcı defter, HUD, yerleşim.
## AI mantığı `_ai(delta)` doğrudan sürülür (fizik overlap'ine bağlı değil), böylece deterministiktir.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/soul_combat_audit.gd
var failures := 0
var state: Node
var sm: Node
var rm: Node
var player: CharacterBody2D
var soul: Node

const DT := 1.0 / 60.0


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("SOUL ", "PASS " if ok else "FAIL ", label, " ", detail)
	if not ok:
		failures += 1


func _run() -> void:
	sm = root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("SOUL SKIP (run with TORIMON_TEST=1 so the player save is never touched)")
		quit(0)
		return
	state = root.get_node("GameState")
	state.player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	root.get_node("DialogueManager").clear()
	root.get_node("UiGate").set_story(false)
	rm = root.get_node("RoomManager")
	soul = root.get_node("SoulManager")
	player = current_scene.get_node("Player")
	_ledger_and_migration()
	await _placement()
	await _crawler()
	await _whisper()
	await _warden()
	await _spark_and_persistence()
	await _death_persistence()
	_hud_journal_ending()
	quit(1 if failures > 0 else 0)


func _enemies(rid: StringName) -> Array:
	var root_node: Node = rm._rooms[rid]["root"]
	var out: Array = []
	for n in root_node.get_children():
		if n.is_in_group("soul_enemy") and not bool(n.get("_dead")):
			out.append(n)
	return out


func _enemy(rid: StringName, kind: String) -> Node:
	for e in _enemies(rid):
		if String(e.get("kind")) == kind:
			return e
	return null


func _prep_player(at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.set("_hurt_cooldown", 0.0)
	state.hearts = state.max_hearts


# --- 1. Defter + eski kayıt göçü -------------------------------------------------------------

func _ledger_and_migration() -> void:
	check(soul.total_count() == 9, "9 souls registered", soul.total_count())
	check(soul.collected_count() == 0, "fresh game has no souls collected")
	var souls: Variant = state.world_memory_state.get("souls", null)
	check(souls is Dictionary and (souls as Dictionary).get("collected", null) is Array, "default world_memory_state has souls ledger")
	## Eski kayıt (souls anahtarı yok / bozuk): migration varsayılana döner.
	var old_save := {"corpses": [], "traces": [], "flags": {}, "puzzles": {}}
	var migrated: Dictionary = sm._deserialize_world(old_save)
	check(migrated.get("souls", null) is Dictionary and (migrated["souls"]["collected"] as Array).is_empty(), "old save migrates with empty ledger")
	var bad_save := {"souls": "garbage"}
	check((sm._deserialize_world(bad_save)["souls"] as Dictionary).get("collected", null) is Array, "corrupt souls value coerced")
	var dup_save := {"souls": {"collected": ["a/b", "a/b", 5]}}
	check((sm._deserialize_world(dup_save)["souls"]["collected"] as Array) == ["a/b"], "duplicate/non-string ledger entries cleaned")
	## Kaydet/yükle gidiş-dönüş.
	soul.collect("library_hall/crawler")
	var ser: Dictionary = sm._serialize_world(state.world_memory_state)
	var round_trip: Dictionary = sm._deserialize_world(JSON.parse_string(JSON.stringify(ser)))
	check("library_hall/crawler" in (round_trip["souls"]["collected"] as Array), "ledger survives save/load round trip")
	soul.reset_ledger()
	check(soul.collected_count() == 0, "reset_ledger clears")


# --- 2. Yerleşim ------------------------------------------------------------------------------

func _placement() -> void:
	var rooms_with := 0
	for rid in soul.SOULS.keys():
		rm.enter_room(StringName(rid), &"default")
		await create_timer(0.1).timeout
		rooms_with += 1
		var list: Array = soul.SOULS[rid]
		var found := _enemies(StringName(rid))
		check(found.size() == list.size(), "%s: all %d enemies spawned" % [rid, list.size()], found.size())
		for e in found:
			check(e.is_in_group("enemy") and e.is_in_group("soul_enemy"), "%s: %s in enemy+soul_enemy groups" % [rid, e.name])
		## Zemine oturma: boşluğa düşmemiş olmalı.
		for i in 40:
			await physics_frame
		for e in found:
			check(e.is_on_floor() and absf(e.global_position.y - 288.0) < 6.0, "%s: %s stands on floor" % [rid, e.name], e.global_position)
		## Hafıza mührü 160 px kuralı + plaka/kapı çakışması yok.
		for seal in get_nodes_in_group(&"memory_seal_point"):
			if not (seal as Node2D).is_visible_in_tree():
				continue
			for e in found:
				check(absf((seal as Node2D).global_position.x - e.global_position.x) >= 160.0 or absf((seal as Node2D).global_position.y - e.global_position.y) >= 160.0,
					"%s: %s >=160px from memory seal" % [rid, e.name])
		for plate in get_nodes_in_group("pressure_plate"):
			if not (plate as Node2D).is_visible_in_tree():
				continue
			for e in found:
				check(absf((plate as Node2D).global_position.x - float(e.get("home_x"))) > 40.0, "%s: %s not on pressure plate" % [rid, e.name])
	check(rooms_with >= 3 and rooms_with <= 5, "enemies placed in 3-5 rooms", rooms_with)


# --- 3. Sürünen ------------------------------------------------------------------------------

func _crawler() -> void:
	rm.enter_room(&"library_hall", &"default")
	await create_timer(0.1).timeout
	var e := _enemy(&"library_hall", "crawler")
	check(e != null, "crawler present")
	if e == null:
		return
	e.set("_cd", 0.0)
	e.global_position = Vector2(e.home_x, 288.0)
	_prep_player(Vector2(e.global_position.x - 70.0, 288.0))
	var tele_t := -1.0
	var hit_t := -1.0
	var t := 0.0
	var hp0: int = state.hearts
	while t < 4.0 and hit_t < 0.0:
		e._ai(DT)
		t += DT
		if int(e.get("_state")) == 1 and tele_t < 0.0:
			tele_t = t
		if state.hearts < hp0:
			hit_t = t
		## Oyuncu yaklaşırken düşman hareketini elle uygula (fizik çerçevesi yok).
		e.global_position.x += e.velocity.x * DT
		player.global_position.x = minf(player.global_position.x + 20.0 * DT, e.global_position.x - 12.0)
	check(tele_t >= 0.0, "crawler enters telegraph", tele_t)
	check(hit_t > 0.0 and state.hearts == hp0 - 1, "crawler deals exactly 1 heart", [hp0, state.hearts])
	check(hit_t - tele_t >= 0.45, "crawler telegraph >= 0.45s before hit", hit_t - tele_t)
	## Dokunulmazlık: 2 sn i-frame içinde ikinci darbe yok.
	var hp1: int = state.hearts
	e.set("_state", 0)
	e.set("_cd", 0.0)
	for i in 240:
		e._ai(DT)
		if i < 100:
			player.set("_hurt_cooldown", maxf(float(player.get("_hurt_cooldown")), 0.5))
	check(state.hearts == hp1, "no damage during i-frames", [hp1, state.hearts])
	## Kılıç: 2 can, ilk vuruş yaralar, ikinci öldürür.
	e.set("_hurt_timer", 0.0)
	e.receive_sword_hit(player, 1.0, 0)
	check(int(e.health) == 1 and float(e._hurt_timer) > 0.0, "crawler hurt + hurt flash window", e.health)
	check(absf(e.velocity.x) > 50.0, "crawler knocked back")
	e.receive_sword_hit(player, 1.0, 0)
	check(bool(e._dead), "crawler dies on second hit")
	var spark := _spark_in(&"library_hall", "library_hall/crawler")
	check(spark != null, "death drops soul spark")
	if spark:
		spark.queue_free()
	# Defteri değiştirmeden düşmanı geri çağır (kıvılcım toplanmadı varsayımı).
	await process_frame
	rm.enter_room(&"library_hall", &"default")
	await create_timer(0.1).timeout
	check(_enemy(&"library_hall", "crawler") != null, "uncollected crawler returns on room re-entry")
	## UI kapısı: tehdit duraklar (fizik adımında _ai çalışmaz).
	var c2 := _enemy(&"library_hall", "crawler")
	c2.set("_state", 1)
	c2.set("_state_t", 0.5)
	root.get_node("UiGate").set_story(true)
	for i in 6:
		await physics_frame
	check(is_equal_approx(float(c2.get("_state_t")), 0.5), "enemy paused while UI gate open")
	root.get_node("UiGate").set_story(false)
	c2.set("_state", 0)


func _spark_in(rid: StringName, sid: String) -> Node:
	var root_node: Node = rm._rooms[rid]["root"]
	for n in root_node.get_children():
		if n.is_in_group("soul_spark") and String(n.get("soul_id")) == sid:
			return n
	return null


# --- 4. Fısıltı ------------------------------------------------------------------------------

func _whisper() -> void:
	rm.enter_room(&"library_hall", &"default")
	await create_timer(0.1).timeout
	var e := _enemy(&"library_hall", "whisper")
	check(e != null, "whisper present")
	if e == null:
		return
	e.set("_cd", 0.0)
	e.set("_state", 0)
	e.global_position = Vector2(e.home_x, 288.0)
	_prep_player(Vector2(e.global_position.x - 180.0, 288.0))
	var t := 0.0
	var tele_t := -1.0
	var fire_t := -1.0
	var hp0: int = state.hearts
	var proj: Node = null
	while t < 4.0 and proj == null:
		e._ai(DT)
		t += DT
		if int(e.get("_state")) == 1 and tele_t < 0.0:
			tele_t = t
		for n in get_nodes_in_group("soul_projectile"):
			proj = n
			fire_t = t
		_prep_keep_distance(e)
	check(tele_t >= 0.0 and proj != null, "whisper telegraphs then fires", [tele_t, fire_t])
	check(fire_t - tele_t >= 0.7, "whisper telegraph >= 0.7s", fire_t - tele_t)
	check(state.hearts == hp0, "firing alone deals no damage")
	if proj == null:
		return
	## Yavaş ve kaçılabilir: zıplayan oyuncuya isabet etmez.
	check(proj.SPEED <= 100.0, "projectile is slow", proj.SPEED)
	var pj: Node2D = proj
	player.global_position = Vector2(pj.global_position.x + float(proj.dir) * 60.0, 288.0 - 60.0)
	for i in 240:
		proj.step(DT)
		if not is_instance_valid(proj) or proj.is_queued_for_deletion():
			break
		player.global_position.y = 228.0
	check(state.hearts == hp0, "projectile misses a jumping player")
	## İsabet: yerdeki oyuncu 1 kalp kaybeder.
	var pr2 := (load("res://scripts/world/soul_projectile.gd") as GDScript).new() as Node2D
	pr2.set("dir", 1.0)
	rm._rooms[&"library_hall"]["root"].add_child(pr2)
	pr2.global_position = Vector2(500.0, 276.0)
	player.global_position = Vector2(540.0, 288.0)
	player.set("_hurt_cooldown", 0.0)
	for i in 600:
		if not is_instance_valid(pr2) or pr2.is_queued_for_deletion():
			break
		pr2.step(DT)
	check(state.hearts == hp0 - 1, "projectile hits grounded player for 1 heart", [hp0, state.hearts])
	## Kılıç tek vuruşta öldürür.
	e.set("_hurt_timer", 0.0)
	e.receive_sword_hit(player, 1.0, 0)
	check(bool(e._dead), "whisper dies to one sword hit")
	var sp := _spark_in(&"library_hall", "library_hall/whisper")
	check(sp != null, "whisper drops spark")
	if sp:
		sp.queue_free()
	for n in get_nodes_in_group("soul_projectile"):
		n.queue_free()


func _prep_keep_distance(e: Node) -> void:
	e.global_position.x += e.velocity.x * DT


# --- 5. Kopuk Bekçi --------------------------------------------------------------------------

func _warden() -> void:
	rm.enter_room(&"library_upper_stacks", &"default")
	await create_timer(0.1).timeout
	var e := _enemy(&"library_upper_stacks", "warden")
	check(e != null, "warden present")
	if e == null:
		return
	e.set("_state", 0)
	e.set("_hurt_timer", 0.0)
	var facing: float = e._facing
	var front_attacker := Node2D.new()
	var back_attacker := Node2D.new()
	current_scene.add_child(front_attacker)
	current_scene.add_child(back_attacker)
	front_attacker.global_position = e.global_position + Vector2(facing * 40.0, 0)
	back_attacker.global_position = e.global_position + Vector2(-facing * 40.0, 0)
	var h0: int = e.health
	e.receive_sword_hit(front_attacker, -facing, 0)
	check(e.health == h0, "warden shield blocks frontal sword hit", e.health)
	e.set("_hurt_timer", 0.0)
	e.receive_sword_hit(back_attacker, facing, 0)
	check(e.health == h0 - 1, "warden takes damage from behind", e.health)
	## Saldırı sonrası toparlanma penceresinde ön darbe işler.
	e.set("_hurt_timer", 0.0)
	e.set("_state", 3) ## RECOVER
	e.set("_state_t", 1.0)
	var h1: int = e.health
	e.receive_sword_hit(front_attacker, -facing, 0)
	check(e.health == h1 - 1, "warden vulnerable from front during recovery", e.health)
	## Ağır saldırı: uyarı + 1 kalp.
	e.health = 3
	e.set("_state", 0)
	e.set("_hurt_timer", 0.0)
	e.set("_cd", 0.0)
	e.global_position = Vector2(e.home_x, 288.0)
	_prep_player(Vector2(e.global_position.x + e._facing * 40.0, 288.0))
	var hp0: int = state.hearts
	var t := 0.0
	var tele_t := -1.0
	var hit_t := -1.0
	while t < 4.0 and hit_t < 0.0:
		e._ai(DT)
		t += DT
		if int(e.get("_state")) == 1 and tele_t < 0.0:
			tele_t = t
		if state.hearts < hp0:
			hit_t = t
		player.global_position = Vector2(e.global_position.x + e._facing * 40.0, 288.0)
	check(hit_t > 0.0 and state.hearts == hp0 - 1, "warden deals exactly 1 heart", [hp0, state.hearts])
	check(hit_t - tele_t >= 0.7, "warden telegraph >= 0.7s", hit_t - tele_t)
	front_attacker.queue_free()
	back_attacker.queue_free()


# --- 6. Kıvılcım + kalıcılık -----------------------------------------------------------------

func _spark_and_persistence() -> void:
	rm.enter_room(&"library_upper_stacks", &"default")
	await create_timer(0.1).timeout
	var sid := "library_upper_stacks/crawler"
	var e := _enemy(&"library_upper_stacks", "crawler")
	check(e != null, "upper stacks crawler present")
	if e == null:
		return
	## (a) Toplanırsa: ruh serbest, lanet -10, düşman bir daha doğmaz.
	root.get_node("CurseManager").set_curse(40.0)
	e.receive_sword_hit(player, 1.0, 2)
	check(bool(e._dead), "combo hit kills crawler (2 dmg)")
	var spark := _spark_in(&"library_upper_stacks", sid)
	check(spark != null, "spark dropped")
	if spark == null:
		return
	check(spark.time_left() > 4.5 and spark.time_left() <= 5.0, "spark lasts ~5s", spark.time_left())
	player.global_position = spark.global_position + Vector2(0, 14)
	spark.step(DT)
	await process_frame
	check(soul.is_collected(sid), "touching spark collects soul")
	check(is_equal_approx(root.get_node("CurseManager").curse, 30.0), "collecting clears 10 curse", root.get_node("CurseManager").curse)
	check(soul.collected_count() == 1, "counter = 1", soul.collected_count())
	## Toplama fısıltısı modal panel açar (ClaritySpark ile aynı); sonraki adımlar için kapat.
	root.get_node("DialogueManager").clear()
	root.get_node("UiGate").set_story(false)
	rm.enter_room(&"library_hall", &"default")
	await create_timer(0.1).timeout
	rm.enter_room(&"library_upper_stacks", &"default")
	await create_timer(0.1).timeout
	check(_enemy(&"library_upper_stacks", "crawler") == null, "collected soul does not respawn on re-entry")
	check(_enemy(&"library_upper_stacks", "warden") != null, "other uncollected enemy still there")
	## (b) Toplanmazsa: 5 sn sonra düşman geri gelir, defter değişmez.
	var w := _enemy(&"library_upper_stacks", "warden")
	w.set("_hurt_timer", 0.0)
	w.set("_facing", 1.0)
	var back := Node2D.new()
	current_scene.add_child(back)
	back.global_position = w.global_position + Vector2(-40, 0)
	w.health = 1
	w.receive_sword_hit(back, 1.0, 0)
	back.queue_free()
	check(bool(w._dead), "warden killed from behind")
	var wsid := "library_upper_stacks/warden"
	var sp2 := _spark_in(&"library_upper_stacks", wsid)
	check(sp2 != null, "warden spark dropped")
	if sp2 == null:
		return
	player.global_position = Vector2(80.0, 288.0)
	for i in 400:
		if not is_instance_valid(sp2) or sp2.is_queued_for_deletion():
			break
		sp2.step(DT)
	await process_frame
	check(not soul.is_collected(wsid), "expired spark leaves ledger unchanged")
	var back_e := _enemy(&"library_upper_stacks", "warden")
	check(back_e != null, "enemy respawns after spark expires")
	check(soul.collected_count() == 1, "counter still 1 after expiry", soul.collected_count())
	## Kayıt/yükleme gidiş-dönüş: toplanan ruh yeniden yüklemede de toplanmış kalır.
	var ser: Dictionary = sm._serialize_world(state.world_memory_state)
	state.world_memory_state = sm._deserialize_world(JSON.parse_string(JSON.stringify(ser)))
	check(soul.is_collected(sid), "collected soul persists across save/load")


func _death_persistence() -> void:
	var sid := "library_upper_stacks/crawler"
	check(soul.is_collected(sid), "precondition: soul collected")
	var death := root.get_node("DeathManager")
	_prep_player(Vector2(200.0, 288.0))
	state.damage(99)
	var t := 0.0
	while death.is_dying and t < 25.0:
		await process_frame
		t += DT
	await create_timer(0.3).timeout
	check(soul.is_collected(sid), "collected soul survives death")
	check(soul.collected_count() == 1, "counter survives death", soul.collected_count())
	var active := StringName(rm.get_active_room_id())
	rm.enter_room(&"library_upper_stacks", &"default")
	await create_timer(0.1).timeout
	check(_enemy(&"library_upper_stacks", "crawler") == null, "collected enemy still absent after death")
	check(active != &"", "active room after death", active)


# --- 7. HUD / günlük / final ------------------------------------------------------------------

func _hud_journal_ending() -> void:
	rm.enter_room(&"library_upper_stacks", &"default")
	state.room_changed.emit(&"library_upper_stacks")
	var hud: Node = get_first_node_in_group("hud")
	check(hud != null and hud._soul_label != null, "HUD has soul counter")
	if hud and hud._soul_label:
		check(hud._soul_label.visible and "Ruhlar 1/2 (1/9)" == hud._soul_label.text, "HUD shows room + total", hud._soul_label.text)
		state.room_changed.emit(&"awakening")
		rm._current = &"awakening"
		hud._refresh_souls()
		check(not hud._soul_label.visible, "HUD counter hidden in soulless room")
		rm._current = &"library_upper_stacks"
	var lines: Array = soul.journal_lines()
	check(lines.size() == 4, "journal has one line per soul room", lines.size())
	var joined := "\n".join(lines)
	check("Üst Raflar" in joined and "1/2" in joined, "journal reports per-room status", joined)
	var fs := FileAccess.get_file_as_string("res://scripts/story/final_sequence.gd")
	check("Hepsini getirdin. Senden önce gelenler artık gidebilir." in fs, "ending: all-collected verdict line")
	check("Hepsini getirmedin. Kalanlar bu odalarda sonsuza dek dolaşacak." in fs, "ending: partial verdict line")
	check(not soul.all_collected(), "all_collected false with partial ledger")
	for r in soul.SOULS.keys():
		for en in soul.SOULS[r]:
			soul.collect(String(en["id"]))
	check(soul.all_collected() and soul.collected_count() == 9, "all_collected true when every soul collected")
	soul.reset_ledger()
