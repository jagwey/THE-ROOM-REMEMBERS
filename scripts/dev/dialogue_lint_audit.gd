extends SceneTree
## Diyalog lint: JSON / tscn / gd içindeki oyuncuya görünen metinleri üslup kurallarına göre tarar.
## Çıktı: "LINT PASS <kural>" / "LINT FAIL <kural> <dosya>:<satır> <metin>". Çıkış kodu = FAIL yoksa 0.
## Çalıştır: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/dialogue_lint_audit.gd

const MAX_DIALOGUE := 90
const MAX_HINT := 70

const RULES := [
	"three_dots", "banned_word", "english_residue", "json_shilda_speaker",
	"line_length", "hint_length", "speaker_format", "unknown_placeholder",
]

## Yeni konuşmacı eklemek bu listeye eklemeyi gerektirir.
const KNOWN_SPEAKERS := ["Noroi", "Shilda", "@shilda", "???", "Ses", "X", "Arşivci", "Yansıma"]

## "<dosya>:<kural>" -> gerekçe. Gerekçesiz muafiyet yok.
const ALLOW := {
	"scripts/autoload/death_manager.gd:unknown_placeholder": "GLSL shader kaynağı; {} kod bloğu, oyuncu metni değil.",
}

const TURKISH_LETTERS := "çğıöşüÇĞİÖŞÜ"
const BANNED_ROOTS := ["hatıra", "bellek"]
const ENGLISH_RESIDUE := ["DOMAIN", "END OF PART", "PART I", "İz: "]

## tscn özellikleri: diyalog satırı sayılanlar (line_length).
const TSCN_DIALOGUE_PROPS := [
	"lines", "locked_lines", "repeat_line", "dialogue_sets", "intro_text", "solved_text",
	"refusal_line", "locked_line", "locked_message",
]
## tscn özellikleri: Konuşmacı|metin biçimi zorunlu olanlar.
const TSCN_SPEAKER_PROPS := ["lines", "locked_lines", "repeat_line", "dialogue_sets"]
## Uzunluk kuralından muaf ama diğer kurallar için taranan metin özellikleri.
const TSCN_OTHER_TEXT_PROPS := ["evidence_title", "evidence_body"]

var failures := 0
var fail_by_rule := {}
var allowed_used := {}


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	call_deferred("_run")


func _run() -> void:
	for r in RULES:
		fail_by_rule[r] = 0
	for path in _walk("res://data/dialogue", ".json"):
		_scan_json(path)
	for path in _walk("res://scenes", ".tscn"):
		_scan_tscn(path)
	for path in _walk("res://scripts", ".gd"):
		if path.begins_with("res://scripts/dev/"):
			continue
		_scan_gd(path)
	for key in ALLOW.keys():
		print("LINT ALLOW ", key, " used=", allowed_used.has(key), " | ", ALLOW[key])
	for r in RULES:
		if int(fail_by_rule[r]) == 0:
			print("LINT PASS ", r)
	print("LINT done failures=", failures, " ", fail_by_rule)
	quit(1 if failures > 0 else 0)


# --- raporlama -------------------------------------------------------------

func _fail(rule: String, path: String, line: int, text: String) -> void:
	var key := "%s:%s" % [path.trim_prefix("res://"), rule]
	if ALLOW.has(key):
		allowed_used[key] = true
		return
	failures += 1
	fail_by_rule[rule] = int(fail_by_rule[rule]) + 1
	print("LINT FAIL ", rule, " ", path.trim_prefix("res://"), ":", line, " ", text)


func _walk(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	var files: PackedStringArray = d.get_files()
	files.sort()
	for f in files:
		if String(f).ends_with(ext):
			out.append(dir_path.path_join(f))
	var dirs: PackedStringArray = d.get_directories()
	dirs.sort()
	for sub in dirs:
		out.append_array(_walk(dir_path.path_join(sub), ext))
	return out


# --- metin kuralları -------------------------------------------------------

func _has_turkish_letter(s: String) -> bool:
	for i in s.length():
		if TURKISH_LETTERS.contains(s[i]):
			return true
	return false


## Oyuncuya görünen metin gibi mi? (kimlik/yol benzeri literal'leri eler)
func _is_identifier_like(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[a-z0-9_\\-./:@%]+$")
	return rx.search(s) != null


## Tek kelimelik büyük harfle başlayan literal ("Ellerim...") metin sayılır.
func _is_capitalized_word(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("^[A-ZÇĞİÖŞÜ][a-zçğıöşüA-Z.…?!]*")
	return rx.search(s) != null


func _check_style(path: String, line: int, text: String, check_banned: bool = true) -> void:
	if text.contains("..."):
		_fail("three_dots", path, line, text)
	if check_banned:
		var low := text.to_lower()
		for root_word in BANNED_ROOTS:
			if low.contains(root_word):
				_fail("banned_word", path, line, text)
				break
	for residue in ENGLISH_RESIDUE:
		if text.contains(residue):
			_fail("english_residue", path, line, text)
			break
	var rx := RegEx.new()
	rx.compile("\\{[^}]*\\}")
	for m in rx.search_all(text):
		if m.get_string() != "{deaths}":
			_fail("unknown_placeholder", path, line, text)
			break


## Diyalog satırı: ';;' parçası başına, konuşmacı öneksiz uzunluk.
func _check_dialogue_length(path: String, line: int, text: String, with_speaker: bool) -> void:
	for part in text.split(";;"):
		var body := String(part)
		if with_speaker:
			var idx := body.find("|")
			if idx >= 0:
				body = body.substr(idx + 1)
		if body.length() > MAX_DIALOGUE:
			_fail("line_length", path, line, "(%d) %s" % [body.length(), body])


func _check_speaker_format(path: String, line: int, text: String) -> void:
	for part in text.split(";;"):
		var p := String(part)
		var idx := p.find("|")
		if idx <= 0 or idx == p.length() - 1:
			_fail("speaker_format", path, line, p)
			continue
		var speaker := p.substr(0, idx)
		if not KNOWN_SPEAKERS.has(speaker):
			_fail("speaker_format", path, line, "bilinmeyen konuşmacı '%s' | %s" % [speaker, p])


func _check_hint(path: String, line: int, text: String) -> void:
	if text.length() > MAX_HINT:
		_fail("hint_length", path, line, "(%d) %s" % [text.length(), text])


# --- literal ayrıştırma ----------------------------------------------------

## Satırdaki çift tırnaklı literal'leri çözülmüş haliyle döndürür; tırnak dışı '#' yorumu keser.
## Her eleman: {"s": metin, "start": literal başlangıç indeksi, "end": bitiş indeksi (kapanış tırnağı)}.
func _literals(src: String, stop_at_hash: bool) -> Array:
	var out: Array = []
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "#" and stop_at_hash:
			break
		if c == "\"":
			var start := i
			var buf := ""
			i += 1
			while i < n and src[i] != "\"":
				if src[i] == "\\" and i + 1 < n:
					i += 1
					var e := src[i]
					if e == "n":
						buf += "\n"
					elif e == "t":
						buf += "\t"
					else:
						buf += e
				else:
					buf += src[i]
				i += 1
			out.append({"s": buf, "start": start, "end": i})
		i += 1
	return out


func _line_of(text: String, needle: String) -> int:
	var idx := text.find(needle)
	if idx < 0:
		return 0
	return text.substr(0, idx).count("\n") + 1


# --- JSON ------------------------------------------------------------------

func _scan_json(path: String) -> void:
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var sets: Variant = (parsed as Dictionary).get("sets", {})
	if typeof(sets) != TYPE_DICTIONARY:
		return
	for set_id in (sets as Dictionary).keys():
		for entry in (sets as Dictionary)[set_id]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if (entry as Dictionary).has("variants"):
				for variant in (entry as Dictionary)["variants"]:
					_scan_json_entry(path, raw, variant)
			else:
				_scan_json_entry(path, raw, entry)


func _scan_json_entry(path: String, raw: String, entry: Variant) -> void:
	if typeof(entry) != TYPE_DICTIONARY:
		return
	var text := String((entry as Dictionary).get("t", ""))
	var line := _line_of(raw, "\"t\": \"%s" % text.substr(0, 24))
	if String((entry as Dictionary).get("s", "")) == "Shilda":
		_fail("json_shilda_speaker", path, line, text)
	_check_style(path, line, text)
	_check_dialogue_length(path, line, text, false)


# --- tscn ------------------------------------------------------------------

func _scan_tscn(path: String) -> void:
	var rx := RegEx.new()
	rx.compile("^([a-z_]+) = (.*)$")
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for ln in lines.size():
		var m := rx.search(String(lines[ln]))
		if m == null:
			continue
		var prop := m.get_string(1)
		var value := m.get_string(2)
		var lineno := ln + 1
		if prop == "doors":
			var lits := _literals(value, false)
			for k in range(lits.size() - 1):
				if String(lits[k]["s"]) == "msg":
					var msg := String(lits[k + 1]["s"])
					_check_style(path, lineno, msg)
					_check_dialogue_length(path, lineno, msg, false)
					_check_hint(path, lineno, msg)
			continue
		var is_dialogue: bool = TSCN_DIALOGUE_PROPS.has(prop) or prop.ends_with("_refusal_line")
		var is_other: bool = TSCN_OTHER_TEXT_PROPS.has(prop)
		if not (is_dialogue or is_other):
			continue
		for lit in _literals(value, false):
			var s := String(lit["s"])
			if s.is_empty():
				continue
			var has_speaker := TSCN_SPEAKER_PROPS.has(prop)
			_check_style(path, lineno, s)
			if is_dialogue:
				_check_dialogue_length(path, lineno, s, has_speaker)
			if has_speaker:
				_check_speaker_format(path, lineno, s)


# --- gd --------------------------------------------------------------------

func _scan_gd(path: String) -> void:
	var is_hint_file := path == "res://scripts/story/campaign_objectives.gd"
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var call_rx := RegEx.new()
	call_rx.compile("DialogueManager\\.(say|whisper|say_with)\\(")
	for ln in lines.size():
		var src := String(lines[ln])
		if src.strip_edges().begins_with("#"):
			continue
		var lineno := ln + 1
		for lit in _literals(src, true):
			var s := String(lit["s"])
			if s.is_empty() or _is_identifier_like(s):
				continue
			var texty := _has_turkish_letter(s) or s.contains(" ") or _is_capitalized_word(s)
			# İngilizce kalıntı yalnız metin gibi görünen literal'lerde aranır.
			if texty or ENGLISH_RESIDUE.any(func(r): return s.contains(r)):
				_check_style(path, lineno, s)
			if is_hint_file and texty:
				_check_hint(path, lineno, s)
		var cm := call_rx.search(src)
		if cm != null:
			var arg_text := _call_text_literal(src.substr(cm.get_end()))
			if arg_text != "":
				_check_dialogue_length(path, lineno, arg_text, false)


## say(speaker, "metin") çağrısının ikinci argümanı bir literal ile başlıyorsa onu döndürür.
func _call_text_literal(rest: String) -> String:
	var depth := 0
	var in_str := false
	var args: Array = []
	var cur := ""
	var i := 0
	while i < rest.length():
		var c := rest[i]
		if in_str:
			cur += c
			if c == "\\" and i + 1 < rest.length():
				i += 1
				cur += rest[i]
			elif c == "\"":
				in_str = false
		else:
			if c == "\"":
				in_str = true
				cur += c
			elif c == "(" or c == "[" or c == "{":
				depth += 1
				cur += c
			elif c == ")" or c == "]" or c == "}":
				if depth == 0:
					args.append(cur)
					cur = ""
					break
				depth -= 1
				cur += c
			elif c == "," and depth == 0:
				args.append(cur)
				cur = ""
			else:
				cur += c
		i += 1
	if cur != "":
		args.append(cur)
	if args.size() < 2:
		return ""
	var second := String(args[1]).strip_edges()
	if not second.begins_with("\""):
		return ""
	var lits := _literals(second, false)
	if lits.is_empty():
		return ""
	return String(lits[0]["s"])
