extends SceneTree
## Ipucu cozulebilirlik denetimi: her kod/sira bulmacasinin cevabi, oyuncunun gordugu metinlerden
## (yanki satirlari, gunluk govdeleri, diyalog JSON, yazitlar, etiketler, sahne metin ozellikleri)
## turetilebilir mi? Cevaplar sabit; ipucu metinleri gercek kaynaklardan (sahne/JSON/kaynak) okunur.
## Calistir: TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/clue_solvability_audit.gd
var failures := 0
var passes := 0

const NUM_WORDS := {"bir": 1, "iki": 2, "üç": 3, "dört": 4, "beş": 5, "altı": 6, "yedi": 7, "sekiz": 8, "dokuz": 9}
## Oyuncuya gorunen metin ozellikleri (id/anahtar alanlari bilerek disarida).
const TEXT_PROPS := [
	"label", "text", "lines", "labels", "title", "body", "evidence_title", "evidence_body", "symbol_text",
	"reveal_line", "intro_line", "locked_line", "locked_lines", "repeat_line", "success_line", "fail_line",
	"require_line", "solved_line", "wrong_line", "dialogue_sets", "body_line", "untrusted_lines",
]
var _num_re: RegEx
var _dialogue_cache: Dictionary = {}


func _initialize() -> void:
	OS.set_environment("TORIMON_FRESH", "1")
	OS.set_environment("TORIMON_NO_AUTO_DIALOGUE", "1")
	OS.set_environment("TORIMON_SMOKE", "")
	call_deferred("_run")


func check(ok: bool, label: String, detail: Variant = "") -> void:
	print("CLUE ", "PASS " if ok else "FAIL ", label, " ", detail)
	if ok:
		passes += 1
	else:
		failures += 1


func note(msg: String) -> void:
	print("CLUE NOTE ", msg)


func _run() -> void:
	var sm := root.get_node("SaveManager")
	if not ("qa/" in String(sm.SAVE_PATH)):
		print("CLUE SKIP (run with TORIMON_TEST=1)")
		quit(0)
		return
	_num_re = RegEx.new()
	var words := "|".join(NUM_WORDS.keys())
	_num_re.compile("(?<![\\p{L}\\p{N}])(\\d+|" + words + ")(?:[dt][ae]n?|y[ıiuü]|[ıiuüae])?(?![\\p{L}\\p{N}])")
	root.get_node("GameState").player_progress_knowledge["awakening_mystery_seen"] = true
	change_scene_to_file("res://scenes/main/main.tscn")
	await process_frame
	await create_timer(0.3).timeout
	root.get_node("DialogueManager").clear()
	_awakening()
	_witness()
	_clockroom()
	_catacombs()
	_garden()
	_authority()
	_bloom_garden()
	_vault()
	_orders()
	print("CLUE SUMMARY pass=", passes, " fail=", failures)
	quit(failures)


# ---------------------------------------------------------------- yardimcilar

func _room_root(rid: String) -> Node:
	var rooms: Dictionary = root.get_node("RoomManager")._rooms
	var e: Variant = rooms.get(StringName(rid), null)
	if e == null:
		return null
	return (e as Dictionary)["root"]


func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _nodes_with(rid: String, prop: String) -> Array:
	var all: Array = []
	var r := _room_root(rid)
	if r == null:
		return all
	_walk(r, all)
	var res: Array = []
	for n in all:
		for p in (n as Node).get_property_list():
			if String(p["name"]) == prop and (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				res.append(n)
				break
	return res


func _flatten(v: Variant, out: Array) -> void:
	if v is String or v is StringName:
		if String(v) != "":
			out.append(String(v))
	elif v is PackedStringArray or v is Array:
		for x in v:
			_flatten(x, out)
	elif v is Dictionary:
		for k in (v as Dictionary).keys():
			_flatten((v as Dictionary)[k], out)


## Sahne metin ozellikleri + Label/Button metni + (echo_id varsa) yanki satirlari ve gunluk metni.
func _scene_parts(rid: String) -> Array:
	var parts: Array = []
	var r := _room_root(rid)
	if r == null:
		return parts
	var all: Array = []
	_walk(r, all)
	var catalog: Dictionary = root.get_node("EchoManager")._catalog
	for n in all:
		var node := n as Node
		if node is Label or node is Button:
			_flatten(node.get("text"), parts)
		for p in node.get_property_list():
			var pn := String(p["name"])
			if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			if pn in TEXT_PROPS:
				_flatten(node.get(pn), parts)
			elif pn == "echo_id":
				_echo_parts(String(node.get(pn)), catalog, parts)
	return parts


func _echo_parts(eid: String, catalog: Dictionary, parts: Array) -> void:
	var e: Variant = catalog.get(eid, null)
	if not (e is Dictionary):
		return
	for ln in (e as Dictionary).get("lines", []):
		if ln is Array and (ln as Array).size() >= 2:
			parts.append(String(ln[1]))
	var j: Variant = (e as Dictionary).get("journal", {})
	if j is Dictionary:
		parts.append(String(j.get("title", "")))
		parts.append(String(j.get("body", "")))


func _dialogue_parts(rid: String) -> Array:
	var parts: Array = []
	var path := "res://data/dialogue/%s.json" % rid
	if not FileAccess.file_exists(path):
		return parts
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		var sets: Dictionary = (d as Dictionary).get("sets", {})
		for k in sets.keys():
			for ln in sets[k]:
				parts.append(String(ln.get("t", "")))
	return parts


func _parts(rid: String) -> Array:
	return _scene_parts(rid) + _dialogue_parts(rid)


func _parts_of(rids: Array) -> Array:
	var out: Array = []
	for r in rids:
		out += _parts(String(r))
	return out


func _tokens(text: String) -> Array:
	var out: Array = []
	for m in _num_re.search_all(text.to_lower()):
		var tok := m.get_string(1)
		if tok.is_valid_int():
			if tok.length() <= 3:
				for ch in tok:
					out.append(int(ch))
		else:
			out.append(int(NUM_WORDS[tok]))
	return out


func _has_digit(text: String, d: int) -> bool:
	return d in _tokens(text)


func _has_seq(text: String, digits: Array) -> bool:
	var t := _tokens(text)
	if t.size() < digits.size():
		return false
	for i in range(t.size() - digits.size() + 1):
		var ok := true
		for j in digits.size():
			if t[i + j] != digits[j]:
				ok = false
				break
		if ok:
			return true
	return false


func _any_seq(parts: Array, digits: Array) -> String:
	for p in parts:
		if _has_seq(String(p), digits):
			return String(p)
	return ""


func _any_digit(parts: Array, d: int) -> String:
	for p in parts:
		if _has_digit(String(p), d):
			return String(p)
	return ""


func _any_match(parts: Array, pattern: String) -> String:
	var re := RegEx.new()
	re.compile("(?i)" + pattern)
	for p in parts:
		if re.search(String(p).to_lower()) != null:
			return String(p)
	return ""


func _idx(text: String, word: String) -> int:
	return text.to_lower().find(word.to_lower())


func _before(a: String, b: String) -> bool:
	var order: PackedStringArray = root.get_node("RoomManager").ROOM_ORDER
	var ia := order.find(a)
	var ib := order.find(b)
	return ia >= 0 and ib >= 0 and ia < ib


## Bulmaca kimligi ROOM_PUZZLES uzerinden erisilebilir mi? HINTS girdisi yoksa yedek metne dusulur (NOT).
func _hint_reach(room: String, ids: Array) -> void:
	var pm := root.get_node("PuzzleManager")
	var list: Array = pm.ROOM_PUZZLES.get(room, [])
	var on_list := false
	for id in ids:
		if list.has(StringName(String(id))):
			on_list = true
	check(on_list, "hint reach: %s ROOM_PUZZLES has code puzzle" % room, str(ids) + " in " + str(list))
	for id in list:
		if not pm.HINTS.has(id):
			note("FALLBACK hint (no HINTS entry): %s / %s" % [room, String(id)])


func _hint_text(pid: String) -> String:
	var h: Dictionary = root.get_node("PuzzleManager").HINTS.get(StringName(pid), {})
	return " ".join([String(h.get("goal", "")), String(h.get("orientation", "")), String(h.get("explicit", ""))])


func _source_literals(path: String) -> String:
	return FileAccess.get_file_as_string(path)


# ---------------------------------------------------------------- bulmacalar

func _awakening() -> void:
	# --- gecit halkalari 3-1-4 ---
	var shrines := _nodes_with("awakening_passage", "order")
	check(shrines.size() >= 1, "passage: ring shrine found")
	if shrines.size() >= 1:
		var order: PackedStringArray = shrines[0].get("order")
		check(",".join(order) == "3,1,4", "passage: ring order is 3,1,4", ",".join(order))
		var labels: Array = []
		for c in shrines[0].get_children():
			if "step_id" in c:
				labels.append([String(c.get("step_id")), String(c.get("label"))])
		for d in [3, 1, 4]:
			var ok := false
			for l in labels:
				if l[0] == str(d) and _has_digit(l[1], d):
					ok = true
			check(ok, "passage: ring step %d labelled with its notch count" % d, str(labels))
	var passage := _parts("awakening_passage")
	var rift := _any_seq(passage, [3, 1, 4])
	check(rift != "", "passage: rift echo shows 3,1,4 in order (echo lines/journal)", rift)
	var rift_echo_nodes := _nodes_with("awakening_passage", "echo_id")
	var has_rift := false
	for n in rift_echo_nodes:
		if String(n.get("echo_id")) == "awakening_rift_echo":
			has_rift = true
	check(has_rift, "passage: RiftEchoStone (awakening_rift_echo) is in the passage room")
	# Halka haneleri: balkon (3), mezarlik sayfalari (1), yatak anisi (4)
	var feed := _parts_of(["awakening_balcony", "awakening_crypt"])
	check(_any_digit(_parts("awakening_balcony"), 3) != "", "passage feed: balcony gives first digit 3")
	check(_any_seq(feed, [3, 1]) != "" or _any_digit(_parts("awakening_crypt"), 1) != "", "passage feed: crypt tablet gives digit 1")
	check(_any_digit(_parts("awakening_crypt"), 4) != "", "passage feed: crypt bed memory gives digit 4")
	check(_before("awakening_balcony", "awakening_passage") and _before("awakening_crypt", "awakening_passage"), "passage feed: balcony+crypt precede passage in ROOM_ORDER")
	_hint_reach("awakening_passage", ["awakening_passage_rings"])
	# --- uyanis muhru 314 ---
	for rid in ["awakening_seal"]:
		var seals := _nodes_with(rid, "story_code")
		check(seals.size() >= 1, "%s: code seal present" % rid)
		for s in seals:
			check(String(s.get("story_code")) == "314", "%s: seal code is 314" % rid, String(s.get("story_code")))
	check(_any_seq(passage, [3, 1, 4]) != "", "seal 314: derivable from passage echo/journal text")
	check(_before("awakening_passage", "awakening_seal"), "seal 314: passage precedes seal room")
	_hint_reach("awakening_seal", ["awakening_memory_code"])
	var recall := _source_literals("res://scripts/world/awakening_seal_echo_recall.gd")
	check(_any_seq([recall], [3, 1, 4]) != "", "seal 314: seal room alcove also restates 3-1-4 (script text)")


func _witness() -> void:
	var seals := _nodes_with("library_witness", "story_code")
	check(seals.size() == 1 and String(seals[0].get("story_code")) == "251", "witness: seal code is 251")
	var intro_full := String(seals[0].get("intro_line")) if seals.size() == 1 else ""
	var intro := intro_full.substr(maxi(intro_full.find(":"), 0))
	var i_clock := _idx(intro, "saat")
	var i_flower := _idx(intro, "çiçek")
	var i_seal := _idx(intro, "mühür")
	check(i_clock >= 0 and i_clock < i_flower and i_flower < i_seal, "witness: seal intro names slots in order saat, çiçek, mühür", intro)
	var catalog: Dictionary = root.get_node("EchoManager")._catalog
	var digit_by_kind := {}
	for n in _nodes_with("library_witness", "echo_id"):
		var eid := String(n.get("echo_id"))
		var parts: Array = []
		_echo_parts(eid, catalog, parts)
		for kind in ["clock", "flower", "seal"]:
			if kind in eid:
				for d in range(1, 10):
					if _any_digit(parts, d) != "":
						digit_by_kind[kind] = d
	var code := ""
	for kind in ["clock", "flower", "seal"]:
		code += str(digit_by_kind.get(kind, "?"))
	check(code == "251", "witness: echo digits in slot order give 251", code)
	_hint_reach("library_witness", ["library_witnesses"])


func _clockroom() -> void:
	var dials := _nodes_with("library_clockroom", "targets")
	check(dials.size() == 1, "clockroom: dial puzzle found")
	if dials.size() != 1:
		return
	var targets: PackedInt32Array = dials[0].get("targets")
	var labels: PackedStringArray = dials[0].get("labels")
	check(Array(targets) == [3, 9, 6], "clockroom: dial targets 3,9,6", str(targets))
	check(Array(labels) == ["1927", "1995", "BUGÜN"], "clockroom: dial order labels 1927,1995,BUGÜN", str(labels))
	var parts := _parts("library_clockroom")
	var rule := _any_seq(parts, [3, 9, 6])
	check(rule != "", "clockroom: a clue states dial sequence 3,9,6 in order", rule)
	check(_any_match(parts, "kadran sırası: 1927, 1995, bugün") != "", "clockroom: clue states dial order 1927, 1995, bugün")
	check(_any_match(parts, "1927[^.\\n]*üç|üç[^.\\n]*1927") != "", "clockroom: 1927 clock text gives 3")
	check(_any_match(parts, "1995[^.\\n]*dokuz|dokuz[^.\\n]*1995") != "", "clockroom: 1995 clock text gives 9")
	check(_any_match(parts, "altı[^.\\n]*bugün|bugün[^.\\n]*altı") != "", "clockroom: today's pocket watch gives 6")
	_hint_reach("library_clockroom", ["library_clock_dials", "library_clockroom"])


func _catacombs() -> void:
	var syms: Array = []
	for n in _nodes_with("decay_catacombs", "symbol_text"):
		if String(n.get("code_group")) == "catacomb":
			syms.append(n)
	syms.sort_custom(func(a, b): return (a as Node2D).position.x < (b as Node2D).position.x)
	var code := ""
	for s in syms:
		code += String(s.get("symbol_text"))
	check(code == "586", "catacombs: symbols read left to right give 586", code)
	var seals := _nodes_with("decay_catacombs", "story_code")
	check(seals.size() == 1 and String(seals[0].get("story_code")) == "586", "catacombs: seal code is 586")
	var parts := _parts("decay_catacombs")
	check(_any_seq(parts, [5, 8, 6]) != "", "catacombs: reveal line spells 5,8,6 in order")
	check(_any_match(parts, "çiçekli bir beden fener gibi yanar") != "", "catacombs: warning says flower corpse burns like a lantern")
	check(_any_match(parts, "ölülerin ışığı") != "", "catacombs: warning says the dead's light shows the way")
	var flower_src := false
	for n in _nodes_with("decay_catacombs", "memory_code_key"):
		flower_src = true
	check(_room_root("decay_catacombs").find_child("FlowerSource", true, false) != null, "catacombs: FlowerSource present so flower corpse is attainable")
	for pid in ["decay_catacomb_seal"]:
		var t := _hint_text(pid).to_lower()
		check(("çiçekli ceset" in t or "ölülerin ışığ" in t) and ("ışığ" in t or "yanar" in t or "ceset" in t), "catacombs: HINTS[%s] mentions flower-corpse light" % pid, t)
	_hint_reach("decay_catacombs", ["decay_catacomb_seal"])


func _garden() -> void:
	var shrines := _nodes_with("decay_garden", "order")
	check(shrines.size() >= 1, "garden: bloom shrine found")
	if shrines.size() < 1:
		return
	var order: PackedStringArray = shrines[0].get("order")
	check(",".join(order) == "7,2,9", "garden: bloom order is 7,2,9", ",".join(order))
	var petals := {}
	for n in _nodes_with("decay_garden", "symbol_text"):
		petals[String(n.get("symbol_text"))] = true
	for d in ["7", "2", "9"]:
		check(petals.has(d), "garden: petal count symbol %s exists (read by corpse light)" % d)
	var gh := _parts("decay_greenhouse")
	var line := _any_seq(gh, [7, 2, 9])
	check(line != "", "garden: greenhouse inscription states 7,2,9 in order", line)
	check(_any_match(gh, "yedi yaprak") != "" and _any_match(gh, "dokuz damla") != "", "garden: inscription ties 7 to petals and 9 to drops")
	check(_before("decay_greenhouse", "decay_garden"), "garden: greenhouse precedes garden")
	var t := _hint_text("decay_garden_bloom").to_lower()
	check("yaprak" in t and "sera" in t, "garden: hint sends player to greenhouse glass and petal counts", t)
	_hint_reach("decay_garden", ["decay_garden_bloom"])
	# Ceset isigi gerektirir: hidden_symbol varsayilan lantern_required=true
	check(_any_match(_parts("decay_garden") + _dialogue_parts("decay_garden"), "yaprak|çiçek") != "" or true, "garden: (informational) petals exist")


func _authority() -> void:
	var seals := _nodes_with("experiment_authority", "story_code")
	check(seals.size() == 1 and String(seals[0].get("story_code")) == "418", "authority: seal code is 418")
	# Hucre A / B kayitlari story_beat.gd icinde (_cell_record -> _evidence).
	var sb := _source_literals("res://scripts/story/story_beat.gd")
	var re_a := RegEx.new()
	re_a.compile("\"ev_cell_a\",\\s*\"[^\"]*\",\\s*\"([^\"]*)\"")
	var re_b := RegEx.new()
	re_b.compile("\"ev_cell_b\",\\s*\"[^\"]*\",\\s*\"([^\"]*)\"")
	var ma := re_a.search(sb)
	var mb := re_b.search(sb)
	var body_a := ma.get_string(1) if ma else ""
	var body_b := mb.get_string(1) if mb else ""
	check(_has_digit(body_a, 4) and _any_match([body_a], "ilk hane\\W+dört") != "", "authority: cell A record gives first digit 4", body_a)
	check(_has_digit(body_b, 1) and _any_match([body_b], "ikinci hane\\W+bir") != "", "authority: cell B record gives second digit 1", body_b)
	var intake := _parts("experiment_intake")
	check(_any_match(intake, "son hane\\W+sekiz") != "", "authority: intake record gives last digit 8")
	var cells: Array = []
	for n in _nodes_with("experiment_cells", "beat_id"):
		cells.append(String(n.get("beat_id")))
	check(cells.has("experiment_cell_a") and cells.has("experiment_cell_b"), "authority: cell A and B record beats exist in experiment_cells", str(cells))
	check(_before("experiment_cells", "experiment_authority") and _before("experiment_intake", "experiment_authority"), "authority: cells + intake precede authority room")
	check(_any_match([sb], "mühür kodu üç hane\\. haneler kayıtlara dağıtılmış") != "", "authority: desk record tells player the 3 digits are spread over records")
	_hint_reach("experiment_authority", ["experiment_authority"])


func _bloom_garden() -> void:
	var shrines := _nodes_with("core_bloom_garden", "order")
	check(shrines.size() >= 1, "bloom: shrine found")
	if shrines.size() < 1:
		return
	var order: PackedStringArray = shrines[0].get("order")
	check(",".join(order) == "4,1,2", "bloom: order is 4,1,2", ",".join(order))
	var labels := {}
	for c in shrines[0].get_children():
		if "step_id" in c:
			labels[String(c.get("step_id"))] = String(c.get("label"))
	for d in [4, 1, 2]:
		var l := String(labels.get(str(d), ""))
		check(l != "" and (_has_digit(l, d) or (d == 1 and l.to_lower().begins_with("tek"))), "bloom: stone %d is labelled with its crown count" % d, l)
	var parts := _parts("core_bloom_garden")
	var rule := _any_match(parts, "önce en çok, sonra en az, sonra kalan")
	check(rule != "", "bloom: Shilda states rule most -> least -> remaining", rule)
	check(_any_match(parts, "taçlardaki çiçek sayısına") != "", "bloom: journal says stones wake by crown count")
	# kural: en cok=4, en az=1, kalan=2
	var vals := []
	for k in labels.keys():
		vals.append(int(k))
	check(vals.max() == 4 and vals.min() == 1 and 2 in vals, "bloom: most=4, least=1, remaining=2 matches rule")
	_hint_reach("core_bloom_garden", ["core_bloom_order"])


func _vault() -> void:
	var shrines := _nodes_with("core_memory_vault", "order")
	check(shrines.size() >= 1, "vault: shrine found")
	if shrines.size() < 1:
		return
	var order: PackedStringArray = shrines[0].get("order")
	check(",".join(order) == "1927,1995,son", "vault: order is 1927,1995,son", ",".join(order))
	var labels := {}
	for c in shrines[0].get_children():
		if "step_id" in c:
			labels[String(c.get("step_id"))] = String(c.get("label"))
	for s in order:
		check(String(labels.get(s, "")).to_lower().contains(s), "vault: step %s is labelled" % s, String(labels.get(s, "")))
	check(_any_match(_parts("awakening_crypt"), "1927") != "" or _any_match(_parts("mirrors_1927"), "1927") != "", "vault: 1927 is seen in earlier rooms (crypt ledger / mirrors_1927 brick)")
	check(_any_match(_parts("experiment_intake"), "1995") != "", "vault: 1995 is seen in intake record")
	check(_any_match(_parts("core_memory_vault"), "tarihleri sen topladın") != "", "vault: echo says dates were collected by player")
	var t := _hint_text("core_vault_order").to_lower()
	check(t.find("1927") >= 0 and t.find("1927") < t.find("1995"), "vault: hint states 1927 before 1995", t)
	_hint_reach("core_memory_vault", ["core_vault_order"])


func _orders() -> void:
	# --- kutuphane salonu: saat, cicek, muhur ---
	var hall := _parts("library_hall")
	var rec := _any_match(hall, "önce saat konuştu, sonra çiçek, en son mühür")
	check(rec != "", "hall: Kayit A states saat, çiçek, mühür order", rec)
	var hs := _nodes_with("library_hall", "order")
	check(hs.size() >= 1 and ",".join(hs[0].get("order")) == "saat,cicek,muhur", "hall: shelf order is saat,cicek,muhur")
	_hint_reach("library_hall", ["library_hall_shelves"])
	# --- ust raflar: ses, muhur, cicek ---
	var us := _parts("library_upper_stacks")
	var ev := _any_match(us, "rafların sırası: ses, mühür, çiçek")
	check(ev != "", "stacks: fallen-book evidence states ses, mühür, çiçek", ev)
	var ss := _nodes_with("library_upper_stacks", "order")
	check(ss.size() >= 1 and ",".join(ss[0].get("order")) == "ses,muhur,cicek", "stacks: shelf order is ses,muhur,cicek")
	_hint_reach("library_upper_stacks", ["library_shelf_order"])
	# --- unutulmus sayfa: deney, kapi, muhur ---
	var po := _source_literals("res://scripts/story/page_order_puzzle.gd")
	check(po.contains("const ORDER: Array[String] = [\"experiment_started\", \"door_closed\", \"seal_engaged\"]"), "page: order is experiment_started, door_closed, seal_engaged")
	check(po.contains("Önce deney, sonra kapı, sonda mühür"), "page: panel text states deney, kapı, mühür")
	check(_any_match(hall, "önce deney, sonra kapı") != "", "page: Kayit B states deney then kapı (earlier room)")
	_hint_reach("library_page", ["library_page_order"])
	# --- mezarlik sayfalari: tarih sirasi ---
	var cs := _nodes_with("awakening_crypt", "order")
	check(cs.size() >= 1, "crypt pages: shrine found")
	if cs.size() >= 1:
		var months := {"mart": 3, "haziran": 6, "aralık": 12}
		var dated: Array = []
		for c in cs[0].get_children():
			if "step_id" in c:
				var l := String(c.get("label")).to_lower()
				for m in months.keys():
					if m in l:
						dated.append([int(months[m]), String(c.get("step_id"))])
		dated.sort_custom(func(a, b): return a[0] < b[0])
		var want := []
		for d in dated:
			want.append(d[1])
		check(dated.size() == 3 and want == Array(cs[0].get("order")), "crypt pages: labelled dates sorted chronologically equal the puzzle order", str(want))
		var cp := _parts("awakening_crypt")
		check(_any_match(cp, "tarih") != "", "crypt pages: text tells player to order by date")
	_hint_reach("awakening_crypt", ["awakening_crypt_pages"])
