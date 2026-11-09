extends SceneTree
## Lore canon denetimi (v3): Noroi deneyin yetkilisi/baslaticisi degildir; 1927/1995 zaman cizelgesi.
## Calistir: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/lore_canon_audit.gd
var failures := 0

const SELF_PATH := "res://scripts/dev/lore_canon_audit.gd"
## Teknik anahtarlarda gecen izin verilen "shiren" kimlikleri (su an yok).
const SHIREN_ALLOWLIST: Array[String] = []
const FORBIDDEN: Array[String] = [
	"Protokol Yetkilisi: Noroi", "Yetkili Noroi", "Ben başlattım",
	"bir zamanlar benimdi", "ben istedim", "Bana kendisi emretti",
	"İmza benim", "Yazarı benim", "Yazar: Noroi", "Sil onu", "hafızayı yaktın",
	"düzene katkıda", "burayı kurdum", "sesi saklamak istedin",
]
const REQUIRED: Array[String] = ["1927", "1995", "Araştırma Yardımcısı S."]
## Diyalog satiri uzunlugu (konusmaci etiketi haric): > WARN uyari listesi, > FAIL hata.
const LINE_WARN := 90
const LINE_FAIL := 120


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print("LORE ", "PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1


func _collect(dir: String, ext: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		_collect(dir.path_join(d), ext, out)


func _run() -> void:
	var files: Array[String] = []
	_collect("res://scenes", "tscn", files)
	_collect("res://scripts", "gd", files)
	var texts := {}
	for p in files:
		if p == SELF_PATH:
			continue
		texts[p] = FileAccess.get_file_as_string(p)
	check(texts.size() > 50, "scanned %d files" % texts.size())

	for p in texts:
		var t: String = texts[p]
		var low := t.to_lower()
		var idx := low.find("shiren")
		while idx != -1:
			var ctx := low.substr(maxi(idx - 24, 0), 56)
			var allowed := false
			for a in SHIREN_ALLOWLIST:
				if ctx.contains(a.to_lower()):
					allowed = true
			check(allowed, "no 'Shiren' in %s (%s)" % [p, ctx.replace("\n", " ")])
			idx = low.find("shiren", idx + 6)
		for pat in FORBIDDEN:
			if t.contains(pat):
				check(false, "forbidden '%s' in %s" % [pat, p])
	check(failures == 0, "no forbidden patterns")

	for req in REQUIRED:
		var found := false
		for p in texts:
			if (texts[p] as String).contains(req):
				found = true
				break
		check(found, "present: %s" % req)

	_check_line_lengths(texts)
	print("LORE failures=%d" % failures)
	quit(failures)


## "Konusmaci|metin" sabitleri (;; ile bolunmus setler dahil) ve say/whisper cagrilari.
func _check_line_lengths(texts: Dictionary) -> void:
	var tagged := RegEx.create_from_string(r'"([^"|\n]{1,24})\|([^"\n]*)"')
	var called := RegEx.create_from_string(r'(?:say|whisper|say_with)\(\s*(?:"[^"]*"|[\w\.\(\)]+)\s*,\s*"([^"\n]+)"')
	var total := 0
	var longest := 0
	var warns: Array[String] = []
	var fails := 0
	for p in texts:
		if (p as String).begins_with("res://scripts/dev/"):
			continue
		var t: String = texts[p]
		var found: Array[String] = []
		for m in tagged.search_all(t):
			for seg in (m.get_string(2) as String).split(";;"):
				found.append(seg.get_slice("|", 1) if seg.contains("|") else seg)
		for m in called.search_all(t):
			found.append(m.get_string(1))
		for line in found:
			total += 1
			longest = maxi(longest, line.length())
			if line.length() > LINE_FAIL:
				fails += 1
				print("LORE FAIL line>%d (%d) %s: %s" % [LINE_FAIL, line.length(), p, line])
			elif line.length() > LINE_WARN:
				warns.append("%d %s: %s" % [line.length(), p, line])
	for w in warns:
		print("LORE WARN line>%d %s" % [LINE_WARN, w])
	print("LORE lines=%d longest=%d warn=%d fail=%d" % [total, longest, warns.size(), fails])
	check(total > 100, "dialogue lines scanned (%d)" % total)
	check(fails == 0, "no dialogue line > %d chars" % LINE_FAIL)
