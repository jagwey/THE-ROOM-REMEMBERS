extends SceneTree
## Kayıt sağlamlığı: yedek (.prev) oluşur, ana kayıt bozulursa yedek yüklenir,
## ikisi de yoksa/bozuksa load_game false döner (çökme yok).
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/save_robust_audit.gd
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("SAVE ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _run() -> void:
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	var path := String(sm.SAVE_PATH)
	if not ("qa/" in path):
		print("SAVE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	gs.player_progress_knowledge["deaths"] = 7
	sm.save_game()
	check(sm._read_save(path) != null, "save written and parseable")
	gs.player_progress_knowledge["deaths"] = 8
	sm.save_game()
	check(sm._read_save(path + ".prev") != null, "previous save kept as .prev")
	check(not FileAccess.file_exists(path + ".tmp"), "no leftover .tmp")
	## Yarıda kalmış yazma: ana dosya bozuk.
	_write(path, "{\"player_progress_kno")
	gs.player_progress_knowledge["deaths"] = 0
	check(sm.load_game(false), "corrupt save falls back to .prev")
	check(int(gs.player_progress_knowledge.get("deaths", -1)) == 7, "fallback restores last good state (deaths=%s)" % str(gs.player_progress_knowledge.get("deaths")))
	## Bozuk ana kayıt, yedeği ezmemeli.
	sm.save_game()
	check(sm._read_save(path + ".prev") != null, ".prev not overwritten by corrupt main")
	## Hiç geçerli kayıt yok.
	_write(path, "not json")
	_write(path + ".prev", "[]")
	check(not sm.load_game(false), "no valid save -> load_game false, no crash")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".prev"))
	print("SAVE_AUDIT failures=", failures)
	quit(1 if failures else 0)
