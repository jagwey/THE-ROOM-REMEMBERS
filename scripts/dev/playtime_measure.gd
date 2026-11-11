extends SceneTree
## İçerik saati: sahnedeki ve JSON'daki gerçek satırlardan okuma süresi + oda yürüyüşü.
## Çalıştır: godot --headless --path . -s res://scripts/dev/playtime_measure.gd

const READ_CPS := 16.0
const BOX_SEC := 0.8
const ROOM_WALK_SEC := 18.0
const PUZZLE_SEC := 35.0
const DEATH_SEC := 45.0
const DEATHS := 4
const MAIN_ROOMS := 25
const SIDE_ROOMS := 15
const MAIN_PUZZLES := 18

var _lines := 0
var _chars := 0
var _json_lines := 0
var _json_words := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var files: Array[String] = []
	_collect("res://scenes", "tscn", files)
	_collect("res://scripts", "gd", files)
	var tagged := RegEx.create_from_string("\"([^\"|\\n]{1,24})\\|([^\"\\n]*)\"")
	var called := RegEx.create_from_string("(?:say|whisper|say_with)\\(\\s*(?:\"[^\"]*\"|[\\w\\.\\(\\)]+)\\s*,\\s*\"([^\"\\n]+)\"")
	for path in files:
		if path.begins_with("res://scripts/dev/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for m in tagged.search_all(text):
			for seg in (m.get_string(2) as String).split(";;"):
				var body := seg.get_slice("|", 1) if seg.contains("|") else seg
				_lines += 1
				_chars += body.length()
		for m in called.search_all(text):
			_lines += 1
			_chars += (m.get_string(1) as String).length()
	var dir := DirAccess.open("res://data/dialogue")
	if dir:
		for file_name in dir.get_files():
			if not String(file_name).ends_with(".json"):
				continue
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s" % file_name))
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var sets: Variant = (parsed as Dictionary).get("sets", {})
			if typeof(sets) != TYPE_DICTIONARY:
				continue
			for set_id in (sets as Dictionary).keys():
				for entry in (sets as Dictionary)[set_id]:
					_json_line(entry)
	var read_sec := float(_chars) / READ_CPS + float(_lines) * BOX_SEC
	var main_sec := read_sec + MAIN_ROOMS * ROOM_WALK_SEC + MAIN_PUZZLES * PUZZLE_SEC + DEATHS * DEATH_SEC
	var full_sec := main_sec + SIDE_ROOMS * (ROOM_WALK_SEC + 20.0)
	print("PLAYTIME lines=%d chars=%d json_lines=%d json_words=%d" % [_lines, _chars, _json_lines, _json_words])
	print("PLAYTIME read_min=%.1f main_min=%.1f with_sides_min=%.1f" % [read_sec / 60.0, main_sec / 60.0, full_sec / 60.0])
	print("PLAYTIME target_min=165-195 measured_with_sides_min=%.1f" % (full_sec / 60.0))
	quit(0)


func _json_line(entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		return
	if (entry as Dictionary).has("variants"):
		for variant in (entry as Dictionary)["variants"]:
			_json_line(variant)
		return
	var body := String((entry as Dictionary).get("t", ""))
	if body.is_empty():
		return
	_json_lines += 1
	_lines += 1
	_chars += body.length()
	for part in body.split(" ", false):
		if not part.is_empty():
			_json_words += 1


func _collect(root: String, ext: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path := "%s/%s" % [root, name]
		if dir.current_is_dir():
			_collect(path, ext, out)
		elif name.ends_with("." + ext):
			out.append(path)
		name = dir.get_next()
