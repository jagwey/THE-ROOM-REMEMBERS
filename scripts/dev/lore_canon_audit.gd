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
	_check_text_regressions(texts)
	print("LORE failures=%d" % failures)
	quit(failures)


## Oyuncuya gorunen metin regresyonlari (qa/release-readiness BUG-003/004/005/015/018/022):
## yorum satirlari haric tum sahne/script/diyalog verisinde yasakli ifadeler bulunmaz.
const TEXT_REGRESSIONS: Array[Array] = [
	["kırk bir", "BUG-003/015: sabit '41' olum sayisi ({deaths} kullanilir)"],
	["Kırk bir", "BUG-003/015: sabit '41' olum sayisi ({deaths} kullanilir)"],
	["Kırk Bir", "BUG-003/015: sabit '41' olum sayisi ({deaths} kullanilir)"],
	["Güvenlik görevlisi: Shilda", "BUG-005: Shilda rol sizintisi (Arastirma Yardimcisi S.)"],
	["Kabul yılım", "BUG-004: 1995'i onceden bilme"],
	["kabul yılım", "BUG-004: 1995'i onceden bilme"],
	["1995'te ben girdim", "BUG-004: 1995'i onceden bilme"],
	["Benimki en sonda: 1995", "BUG-004: 1995'i onceden bilme"],
	["Finalden önce yüzü yok", "BUG-022: oyun-disi (meta) final anisi"],
	["Düzeni bozma. Kapı kapalı kalsın.", "BUG-005/X: X? konusma satiri degil iz olmali"],
	["X? fısıltısı", "BUG-005/X: X? konusma satiri degil iz olmali"],
	["Ruh Kesiği", "BUG-018: yetenek adi 'Ruh Kesimi'"],
	["Unutursam bir daha uyanamazmışım", "BUG-016: awakening_vigil kanit metni JSON ile uyumsuz"],
	["Kazı o yıl başladı", "BUG-019: X 1927'de boyutu kurdu (kazi degil)"],
	["Kazı başladı", "BUG-019: X 1927'de boyutu kurdu (kazi degil)"],
	["kazı başladı", "BUG-019: X 1927'de boyutu kurdu (kazi degil)"],
	["1927 kazı", "BUG-019: X 1927'de boyutu kurdu (kazi degil)"],
	["kazının yılı", "BUG-019: X 1927'de boyutu kurdu (kazi degil)"],
	["Kapı o yıl kapandı", "BUG-020: 1995 = Noroi'nin giris yili, kapi yili degil"],
	["Altmış sekiz yıl. Sayfalar", "BUG-021: 68 yil = 1927->1995 aritmetigi; gunluk 68 yil once yazildi"],
]


func _strip_comment_lines(t: String) -> String:
	var out: Array[String] = []
	for line in t.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


func _check_text_regressions(texts: Dictionary) -> void:
	var data: Array[String] = []
	_collect("res://data", "json", data)
	var all := {}
	for p in texts:
		all[p] = _strip_comment_lines(texts[p] as String) if (p as String).ends_with(".gd") else texts[p]
	for p in data:
		all[p] = FileAccess.get_file_as_string(p)
	for entry in TEXT_REGRESSIONS:
		var pat: String = entry[0]
		var hits: Array[String] = []
		for p in all:
			if (all[p] as String).contains(pat):
				hits.append(p)
		check(hits.is_empty(), "regression '%s' (%s) %s" % [pat, entry[1], str(hits)])
	## Kanon A: shilda_past_discovered Perde 1'de (awakening_crypt) kurulmaz; itiraf experiment_authority'de.
	check(not (texts.get("res://scenes/rooms/awakening_crypt.tscn", "") as String).contains("shilda_past_discovered"), "CANON-A: awakening_crypt.tscn shilda_past_discovered kurmaz")
	check(sb_has_flag_in_authority(texts), "CANON-A: story_beat experiment_authority shilda_past_discovered kurar")
	## Kanon B: 1995 okunakli olarak en erken library_*/experiment_* asamasinda; awakening_*/decay_* dosyalarinda gecmez.
	var early_hits: Array[String] = []
	var early_seen := 0
	for p in all:
		var base: String = (p as String).get_file()
		if base.begins_with("awakening") or base.begins_with("decay"):
			early_seen += 1
			if (all[p] as String).contains("1995"):
				early_hits.append(p)
	check(early_seen > 0, "CANON-B: awakening_*/decay_* dosyalari tarandi (%d)" % early_seen)
	check(early_hits.is_empty(), "CANON-B: awakening_*/decay_* dosyalarinda '1995' yok %s" % str(early_hits))
	## Kanon: Arastirma Yardimcisi S. imzasi artik experiment_authority kaydinda.
	var sb: String = texts.get("res://scripts/story/story_beat.gd", "")
	check(sb.contains("Araştırma Yardımcısı S."), "BUG-005: story_beat 'Araştırma Yardımcısı S.' kaydi")
	## {deaths} yer tutucusu gercek GameState sayacindan gelir (min 1).
	var lp = load("res://scripts/world/lore_point.gd")
	var gs: Node = root.get_node_or_null("GameState")
	check(lp != null and gs != null, "BUG-003: LorePoint + GameState yuklendi")
	if lp != null and gs != null:
		var prev = gs.player_progress_knowledge.get("deaths", null)
		gs.player_progress_knowledge["deaths"] = 7
		check(lp.format_text("Son sayı: {deaths}.") == "Son sayı: 7.", "BUG-003: {deaths} gercek sayac (7)")
		gs.player_progress_knowledge["deaths"] = 0
		check(lp.format_text("{deaths}. ölüm") == "1. ölüm", "BUG-003: {deaths} en az 1")
		check(lp.format_text("yer tutucu yok") == "yer tutucu yok", "BUG-003: yer tutucusuz metin degismez")
		if prev == null:
			gs.player_progress_knowledge.erase("deaths")
		else:
			gs.player_progress_knowledge["deaths"] = prev
	for scene_path in ["res://scenes/rooms/awakening_crypt.tscn", "res://scenes/rooms/decay_shilda_wall.tscn"]:
		check((texts.get(scene_path, "") as String).contains("{deaths}"), "BUG-003: %s {deaths} kullanir" % scene_path)


## story_beat.gd _experiment_authority() govdesinde shilda_past_discovered set edilir.
func sb_has_flag_in_authority(texts: Dictionary) -> bool:
	var sb: String = texts.get("res://scripts/story/story_beat.gd", "")
	var start := sb.find("func _experiment_authority")
	if start == -1:
		return false
	var end := sb.find("\nfunc ", start + 10)
	var body := sb.substr(start, (end if end != -1 else sb.length()) - start)
	return body.contains("shilda_past_discovered")


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
