extends SceneTree
## Android export guard: `@export var x: PackedStringArray = []` gibi Array-literal varsayılanlar
## export sırasında (tscn -> binary scn) sahnedeki değerin DÜŞMESİNE yol açıyor (v1.20.5 10A kapısı).
## Packed*Array export'ları `= PackedXArray()` ile başlatılmalı.
## Çalıştır: godot --headless --path . -s res://scripts/dev/export_default_audit.gd

var _failures := 0


func _init() -> void:
	var re := RegEx.new()
	re.compile("^@export[^\\n]*var\\s+(\\w+)\\s*:\\s*(Packed\\w+Array)\\s*=\\s*\\[")
	_scan("res://scripts", re)
	print("EXPORT_DEFAULT_AUDIT failures=%d" % _failures)
	quit(1 if _failures > 0 else 0)


func _scan(dir_path: String, re: RegEx) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub), re)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var path := dir_path.path_join(file)
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var m := re.search(lines[i].strip_edges())
			if m:
				_failures += 1
				print("EXPORT_DEFAULT FAIL %s:%d %s: %s = [] -> use %s()" % [path, i + 1, m.get_string(1), m.get_string(2), m.get_string(2)])
