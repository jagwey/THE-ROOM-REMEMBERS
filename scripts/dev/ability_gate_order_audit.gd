extends SceneTree
## Yetenek sırası tutarlılığı (v1.20.6): bir yetenek kilidi, o yetenek verilmeden ÖNCE gelen odada bulunmaz.
## - Gölge Atılması (dash_line / curse_barrier): yalnız Ayna Tapınağı ve sonrası.
## - Ruh Kesimi (soul_seal): yalnız Yasak Kanat ve sonrası.
## Yan odalar kendi PROGRESS_ORDER sırasıyla değerlendirilir; erken bir merkezden açılan yan odaya giden kapı
## o yeteneği istemeli (SIDE_DOORS "ability"). Oda metinleri, yeteneksiz yerlerde "Gölge Atılması için ... gitmeliyim"
## gibi ret repliği taşımaz.
## Çalıştır: godot --headless --path . -s res://scripts/dev/ability_gate_order_audit.gd

const DASH_SCRIPTS := ["res://scripts/world/dash_line.gd", "res://scripts/world/curse_barrier.gd"]
const SOUL_SCRIPTS := ["res://scripts/world/soul_seal.gd"]
const DASH_ROOM := "mirrors_shrine"
const SOUL_ROOM := "library_forbidden_wing"

var _failures := 0


func _fail(msg: String) -> void:
	_failures += 1
	print("ABILITY_ORDER FAIL ", msg)


## Anahtarın içinde geçen en uzun oda id'si (ör. "trial_mirrors_inverse_hall" -> mirrors_inverse_hall).
func _room_of(key: String, order: PackedStringArray) -> String:
	var best := ""
	for rid in order:
		if key.contains(rid) and rid.length() > best.length():
			best = rid
	return best


func _check_text(tag: String, rid: String, body: String, order: PackedStringArray, dash_idx: int, soul_idx: int, door_ability: Dictionary) -> void:
	var i := order.find(rid)
	if i < 0:
		return
	var door_dash := String(door_ability.get(rid, "")) == "ability_shadow_dash"
	if i < dash_idx and not door_dash and body.contains("Gölge Atılması"):
		_fail("%s (#%d) mentions Gölge Atılması before %s" % [tag, i, DASH_ROOM])
	if i < soul_idx and not door_dash and body.contains("Ruh Kesimi"):
		_fail("%s (#%d) mentions Ruh Kesimi before %s" % [tag, i, SOUL_ROOM])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var order: PackedStringArray = root.get_node("RoomManager").PROGRESS_ORDER
	var side_doors: Dictionary = load("res://scripts/main.gd").SIDE_DOORS
	var dash_idx := order.find(DASH_ROOM)
	var soul_idx := order.find(SOUL_ROOM)
	## Yan oda -> kapısındaki yetenek şartı.
	var door_ability := {}
	for hub in side_doors:
		for d in side_doors[hub]:
			door_ability[String(d["to"])] = String(d.get("ability", ""))
	var checked := 0
	for i in order.size():
		var rid := order[i]
		var path := "res://scenes/rooms/%s.tscn" % rid
		if not FileAccess.file_exists(path):
			continue
		checked += 1
		var text := FileAccess.get_file_as_string(path)
		var door_dash := String(door_ability.get(rid, "")) == "ability_shadow_dash"
		for sp in DASH_SCRIPTS:
			if text.contains('path="%s"' % sp) and i < dash_idx and not door_dash:
				_fail("%s (#%d) has %s before %s (#%d)" % [rid, i, sp.get_file(), DASH_ROOM, dash_idx])
		for sp in SOUL_SCRIPTS:
			if text.contains('path="%s"' % sp) and i < soul_idx:
				_fail("%s (#%d) has %s before %s (#%d)" % [rid, i, sp.get_file(), SOUL_ROOM, soul_idx])
		if i < dash_idx and not door_dash and text.contains("Gölge Atılması için"):
			_fail("%s (#%d) still has a 'Gölge Atılması için ...' refusal line" % [rid, i])
		if i < soul_idx and text.contains("Ruh Kesimi için"):
			_fail("%s (#%d) still has a 'Ruh Kesimi için ...' refusal line" % [rid, i])
	## Erken merkezden açılan, içinde Gölge Atılması kilidi olan yan oda kapısı yeteneği istemeli.
	for hub in side_doors:
		for d in side_doors[hub]:
			var to := String(d["to"])
			var p := "res://scenes/rooms/%s.tscn" % to
			if not FileAccess.file_exists(p):
				continue
			var t := FileAccess.get_file_as_string(p)
			var has_dash := false
			for sp in DASH_SCRIPTS:
				has_dash = has_dash or t.contains('path="%s"' % sp)
			if has_dash and order.find(String(hub)) < dash_idx and String(d.get("ability", "")) != "ability_shadow_dash":
				_fail("side door %s -> %s leads to a dash gate before %s without an ability lock" % [hub, to, DASH_ROOM])
	## İpucu (PuzzleManager.HINTS) ve hedef (CampaignObjectives) metinleri: erken odada yetenek adı geçmez.
	var hints: Dictionary = root.get_node("PuzzleManager").HINTS
	for key in hints:
		var rid := _room_of(String(key), order)
		var body := ""
		for k in hints[key]:
			body += String(hints[key][k]) + " "
		_check_text("hint %s" % key, rid, body, order, dash_idx, soul_idx, door_ability)
	var objs: Dictionary = load("res://scripts/story/campaign_objectives.gd")._BY_ROOM
	for rid in objs:
		_check_text("objective %s" % rid, String(rid), String(objs[rid]), order, dash_idx, soul_idx, door_ability)
	print("ABILITY_ORDER rooms=%d failures=%d" % [checked, _failures])
	quit(1 if _failures > 0 else 0)
