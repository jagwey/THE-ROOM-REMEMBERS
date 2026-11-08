extends SceneTree
## "Devam Et" yolu (apply_initial_room) m3 mekaniklerini (çatlak ayna, gölgeler) kurar mı?
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/resume_m3_audit.gd
var failures := 0


func _initialize() -> void:
	OS.set_environment("TORIMON_TEST", "1")
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("RESUME ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _count(room_root: Node, scene_path: String) -> int:
	var n := 0
	for c in room_root.get_children():
		if c.scene_file_path == scene_path:
			n += 1
	return n


func _run() -> void:
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	var rm := root.get_node("RoomManager")
	var rid := &"decay_garden"
	var room_root: Node2D = rm._rooms[rid].root
	const MIRROR := "res://scenes/props/cracked_mirror.tscn"
	const SHADE := "res://scenes/world/memory_shade_walking.tscn"
	## Temiz başlangıç: kurulumu sıfırla.
	for c in room_root.get_children():
		if c.scene_file_path == MIRROR or c.scene_file_path == SHADE:
			room_root.remove_child(c)
			c.free()
	room_root.remove_meta("m3_mechanics_ready") if room_root.has_meta("m3_mechanics_ready") else null
	check(_count(room_root, MIRROR) == 0 and _count(room_root, SHADE) == 0, "precondition: no mirror/shade")
	rm.apply_initial_room(rid, &"checkpoint", false)
	check(_count(room_root, MIRROR) == 1, "resume path spawns cracked mirror")
	check(_count(room_root, SHADE) >= 1, "resume path spawns walking shade")
	rm.apply_initial_room(rid, &"checkpoint", false)
	check(_count(room_root, MIRROR) == 1, "no duplicate mirror on repeated apply")
	print("RESUME failures=", failures)
	quit(1 if failures > 0 else 0)
