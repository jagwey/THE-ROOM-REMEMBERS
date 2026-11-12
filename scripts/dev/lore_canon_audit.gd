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
	_check_canon_decisions(texts)
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


## Phase 1 canon kararlari (spec §7). Etiketler `CANON <ad>`; sonraki gorevler bunlari kirmamali.
## X'in "adi": oyunda yalnizca "X" harfidir (kurucu imza). Final'e (mirrors_1927 sonrasi) kadar metinde gecmez.
const X_NAME_RE := r"\bX\b"
## Shilda'nin insan oldugunu acikca soyleyen ifadeler (experiment_observation oncesi yasak).
const SHILDA_HUMAN_PHRASES: Array[String] = [
	"insandı", "insan mıydın", "insan olarak", "bir zamanlar insan", "insan eli", "İnsan eli",
]
const WITNESS_WORDS := {"witness_clock": "saat", "witness_flower": "çiçek", "witness_seal": "mühür"}
const NUM_WORDS := {"bir": "1", "iki": "2", "üç": "3", "dört": "4", "beş": "5"}


## Oyuncuya gorunen metin: sahneler + dev-disi scriptler (yorumsuz) + data JSON.
func _game_text(texts: Dictionary) -> Dictionary:
	var out := {}
	for p in texts:
		if (p as String).begins_with("res://scripts/dev/"):
			continue
		out[p] = _strip_comment_lines(texts[p] as String) if (p as String).ends_with(".gd") else texts[p]
	var data: Array[String] = []
	_collect("res://data", "json", data)
	for p in data:
		out[p] = FileAccess.get_file_as_string(p)
	return out


## tscn/json/gd kaynaginda yalniz metin satirlari (node/ext_resource basliklari degil).
func _text_lines(src: String) -> Array[String]:
	var out: Array[String] = []
	for line in src.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("[node") or s.begins_with("[ext_resource") or s.begins_with("[sub_resource") or s.begins_with("[gd_scene"):
			continue
		out.append(line)
	return out


func _room_files(room_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for r in room_ids:
		for p in ["res://scenes/rooms/%s.tscn" % r, "res://data/dialogue/%s.json" % r]:
			if FileAccess.file_exists(p):
				out.append(p)
	return out


func _check_canon_decisions(texts: Dictionary) -> void:
	var game := _game_text(texts)
	var order: PackedStringArray = load("res://scripts/autoload/room_manager.gd").ROOM_ORDER
	var i1927 := order.find("mirrors_1927")
	var iobs := order.find("experiment_observation")
	var ivigil := order.find("awakening_vigil")
	check(i1927 > 0 and iobs > 0 and ivigil > 0, "CANON room order anchors found (%d/%d/%d)" % [ivigil, iobs, i1927])
	var before_1927: Array[String] = []
	var before_obs: Array[String] = []
	var before_vigil: Array[String] = []
	for i in order.size():
		if i < i1927:
			before_1927.append(order[i])
		if i < iobs:
			before_obs.append(order[i])
		if i < ivigil:
			before_vigil.append(order[i])
	var sys_scripts: Array[String] = [
		"res://scripts/story/story_beat.gd", "res://scripts/keeper/keeper_controller.gd",
		"res://scripts/world/corpse.gd", "res://scripts/story/campaign_objectives.gd",
	]

	## X'in adi mirrors_1927 oncesinde gecmez.
	var xre := RegEx.create_from_string(X_NAME_RE)
	var x_hits: Array[String] = []
	var x_files := _room_files(before_1927)
	x_files.append_array(sys_scripts)
	for p in x_files:
		for line in _text_lines(str(game.get(p, ""))):
			if xre.search(line) != null:
				x_hits.append("%s: %s" % [p.get_file(), line.strip_edges().left(80)])
	check(x_hits.is_empty(), "CANON x_name_late %s" % str(x_hits))

	## Shilda'nin insan oldugu experiment_observation oncesi acik soylenmez.
	var h_hits: Array[String] = []
	var h_files := _room_files(before_obs)
	h_files.append("res://scripts/story/campaign_objectives.gd")
	for p in h_files:
		var t: String = str(game.get(p, ""))
		for ph in SHILDA_HUMAN_PHRASES:
			if t.contains(ph):
				h_hits.append("%s '%s'" % [p.get_file(), ph])
	check(h_hits.is_empty(), "CANON shilda_human_late %s" % str(h_hits))

	## "yuzlerce" ve "1927 yazi" hicbir oyun metninde gecmez.
	var hundreds: Array[String] = []
	var summer: Array[String] = []
	var summer_re := RegEx.create_from_string("1927 yaz(?:ı|ın|ına|ında|ının|ından)(?![a-zA-ZçğıöşüÇĞİÖŞÜ])")
	for p in game:
		var t: String = game[p]
		if t.to_lower().contains("yüzlerce"):
			hundreds.append(p)
		if summer_re.search(t) != null:
			summer.append(p)
	check(hundreds.is_empty(), "CANON no_hundreds %s" % str(hundreds))
	check(summer.is_empty(), "CANON night_1927 %s" % str(summer))

	## Kasa: X'in tesisi kendi secimiyle iceriden kilitledigi (ironi) soylenir.
	var vault_src := str(game.get("res://scenes/rooms/core_memory_vault.tscn", ""))
	var irony := false
	for seg in vault_src.replace(";;", "\"").split("\""):
		if seg.contains("kilit") and seg.contains("kendi"):
			irony = true
	check(irony, "CANON vault_irony")

	## Kabul: cicegin sahibi Shilda.
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/experiment_intake.json"))
	var flower_ok := false
	var flower_bad := false
	if parsed is Dictionary:
		for set_name in (parsed.get("sets", {}) as Dictionary):
			for e in (parsed["sets"][set_name] as Array):
				var tt := str(e.get("t", ""))
				if tt.contains("çiçek") or tt.contains("Çiçek"):
					if str(e.get("s", "")) == "@shilda" and tt.contains("benim"):
						flower_ok = true
					if tt.contains("ben koymadım") or tt.contains("Sen getirdin"):
						flower_bad = true
	check(flower_ok and not flower_bad, "CANON intake_flower_owner (shilda_claims=%s, contradicts=%s)" % [str(flower_ok), str(flower_bad)])

	## Hall kaydi sirasi = Tanik yankilarinin sirasi (sahnede soldan saga, kayit sirasi).
	var sb := str(game.get("res://scripts/story/story_beat.gd", ""))
	var scene_order := _witness_scene_order(str(texts.get("res://scenes/rooms/library_witness.tscn", "")))
	var reg_order: Array[String] = []
	for m in RegEx.create_from_string(r'register_echo\("(witness_\w+)"').search_all(str(texts.get("res://scripts/story/library_witness_room.gd", ""))):
		reg_order.append(WITNESS_WORDS.get(m.get_string(1), "?"))
	var text_orders: Array = []
	for line in sb.split("\n"):
		var low := line.to_lower()
		if low.contains("saat") and low.contains("çiçek") and low.contains("mühür"):
			var w: Array = []
			for word in ["saat", "çiçek", "mühür"]:
				w.append([low.find(word), word])
			w.sort_custom(func(a, b): return a[0] < b[0])
			text_orders.append(w.map(func(x): return x[1]))
	var witness_ok := scene_order.size() == 3 and str(scene_order) == str(reg_order) and not text_orders.is_empty()
	for o in text_orders:
		if str(o) != str(scene_order):
			witness_ok = false
	check(witness_ok, "CANON witness_order scene=%s register=%s texts=%s" % [str(scene_order), str(reg_order), str(text_orders)])

	## Bahce ipucu ("dort, bir, iki") = bulmaca cozumu.
	var garden := str(texts.get("res://scenes/rooms/core_bloom_garden.tscn", ""))
	var sol: Array[String] = []
	var om := RegEx.create_from_string(r'puzzle_id = &"core_bloom_order"\s*\norder = PackedStringArray\(([^)]*)\)').search(garden)
	if om != null:
		for q in om.get_string(1).split(","):
			sol.append(q.strip_edges().trim_prefix("\"").trim_suffix("\""))
	var hint_src: Array[String] = [garden, str(game.get("res://scripts/story/campaign_objectives.gd", ""))]
	var hint_re := RegEx.create_from_string(r"((?:dört|bir|iki|üç|beş)(?:, (?:dört|bir|iki|üç|beş))+)")
	var hints: Array = []
	for src in hint_src:
		for m in hint_re.search_all(src):
			var nums: Array[String] = []
			for wd in m.get_string(1).split(", "):
				nums.append(NUM_WORDS[wd])
			hints.append(nums)
	var garden_ok := sol.size() == 3 and hints.size() >= 2
	for hnt in hints:
		if str(hnt) != str(sol):
			garden_ok = false
	check(garden_ok, "CANON garden_hint solution=%s hints=%s" % [str(sol), str(hints)])

	## Nobet Odasi tanismasindan once "Shilda" adi govde metninde gecmez (sabit "Shilda|" konusmaci oneki calisma aninda cozulur).
	var s_hits: Array[String] = []
	var s_files := _room_files(before_vigil)
	for p in ["res://scripts/world/awakening_seal_echo_recall.gd", "res://scripts/world/awakening_room.gd", "res://scripts/story/awakening_room.gd"]:
		s_files.append(p)
	for p in s_files:
		for line in _text_lines(str(game.get(p, "")) if game.has(p) else str(texts.get(p, ""))):
			var body := line.replace("Shilda|", "").replace("\"Shilda\"", "")
			if body.contains("Shilda") and (body.contains("\"") or p.ends_with(".json")):
				s_hits.append("%s: %s" % [p.get_file(), line.strip_edges().left(80)])
	check(s_hits.is_empty(), "CANON pre_name_shilda %s" % str(s_hits))


## library_witness.tscn: echo dugumlerini x konumuna gore sirala, kelimeye cevir.
func _witness_scene_order(src: String) -> Array[String]:
	var found: Array = []
	var x := 0.0
	var posre := RegEx.create_from_string(r"position = Vector2\(\s*([\d\.\-]+)\s*,")
	var idre := RegEx.create_from_string(r'echo_id = &"(witness_\w+)"')
	for line in src.split("\n"):
		var pm := posre.search(line)
		if pm != null:
			x = pm.get_string(1).to_float()
		var im := idre.search(line)
		if im != null:
			found.append([x, WITNESS_WORDS.get(im.get_string(1), "?")])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[String] = []
	for f in found:
		out.append(f[1])
	return out


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
