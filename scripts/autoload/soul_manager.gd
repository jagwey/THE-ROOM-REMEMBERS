extends Node
## SoulManager — Parçalanmış Ruhlar: kalıcı ruh defteri, düşman yerleşimi, sayaçlar.
## Defter GameState.world_memory_state["souls"]["collected"] içinde (ölümle/yeniden yüklemeyle silinmez).
## Toplanmış ruhun düşmanı bir daha doğmaz; toplanmamış düşman odaya girince geri gelir.

signal souls_changed

## Not: preload yok — bu autoload derlenirken düşman/kıvılcım betikleri (SoulManager'a atıf yapar) döngü yaratır.
const ENEMY_PATH := "res://scripts/world/soul_enemy.gd"
const SPARK_PATH := "res://scripts/world/soul_spark.gd"

## Oda -> ruh listesi. id benzersiz; x yatay ev konumu (zemin y=288).
## Hafıza mühürlerinden (>=160 px) ve bulmaca nesnelerinden uzak durulmuştur.
const SOULS := {
	"library_hall": [
		{"id": "library_hall/crawler", "kind": "crawler", "x": 330.0},
		{"id": "library_hall/whisper", "kind": "whisper", "x": 800.0},
	],
	"library_upper_stacks": [
		{"id": "library_upper_stacks/crawler", "kind": "crawler", "x": 620.0},
		{"id": "library_upper_stacks/warden", "kind": "warden", "x": 940.0},
	],
	"experiment_quarantine": [
		{"id": "experiment_quarantine/crawler", "kind": "crawler", "x": 430.0},
		{"id": "experiment_quarantine/warden", "kind": "warden", "x": 780.0},
		{"id": "experiment_quarantine/whisper", "kind": "whisper", "x": 900.0},
	],
	"experiment_observation": [
		{"id": "experiment_observation/crawler", "kind": "crawler", "x": 560.0},
		{"id": "experiment_observation/whisper", "kind": "whisper", "x": 850.0},
	],
}

func _ledger() -> Array:
	var s: Variant = GameState.world_memory_state.get("souls", null)
	if not s is Dictionary:
		s = {"collected": []}
		GameState.world_memory_state["souls"] = s
	var d: Dictionary = s
	if not d.get("collected", null) is Array:
		d["collected"] = []
	return d["collected"]


func is_collected(soul_id: String) -> bool:
	return soul_id in _ledger()


func collect(soul_id: String) -> void:
	var l := _ledger()
	if soul_id != "" and not (soul_id in l):
		l.append(soul_id)
	souls_changed.emit()


func reset_ledger() -> void:
	GameState.world_memory_state["souls"] = {"collected": []}
	souls_changed.emit()


func room_total(room_id: String) -> int:
	return (SOULS.get(room_id, []) as Array).size()


func room_collected(room_id: String) -> int:
	var n := 0
	for e in SOULS.get(room_id, []):
		if is_collected(String(e["id"])):
			n += 1
	return n


func total_count() -> int:
	var n := 0
	for r in SOULS.keys():
		n += room_total(String(r))
	return n


func collected_count() -> int:
	var n := 0
	for r in SOULS.keys():
		n += room_collected(String(r))
	return n


func all_collected() -> bool:
	return total_count() > 0 and collected_count() >= total_count()


func has_souls(room_id: String) -> bool:
	return SOULS.has(room_id)


## HUD: "Ruhlar 1/2 (3/9)" — oda ve toplam. Ruhsuz odada boş.
func hud_text(room_id: String) -> String:
	if not has_souls(room_id):
		return ""
	return "Ruhlar %d/%d (%d/%d)" % [room_collected(room_id), room_total(room_id), collected_count(), total_count()]


## Günlük satırları: oda başına durum.
func journal_lines() -> Array[String]:
	var out: Array[String] = []
	for r in SOULS.keys():
		var rid := String(r)
		var c := room_collected(rid)
		var t := room_total(rid)
		var state := "hepsi özgür" if c >= t else ("%d/%d ruh özgür" % [c, t])
		out.append("%s: %s" % [String(RoomManager.ROOM_TITLES_TR.get(rid, rid)), state])
	return out


## Oda her etkinleştirildiğinde çağrılır: toplanmamış ruhların düşmanını (yoksa) doğurur.
func ensure_room(room_id: StringName, root: Node) -> void:
	var rid := String(room_id)
	if root == null or not SOULS.has(rid):
		return
	for e in SOULS[rid]:
		var sid := String(e["id"])
		if is_collected(sid):
			var old := _find_enemy(root, sid)
			if old:
				old.queue_free()
			continue
		if _find_enemy(root, sid) != null or _find_spark(root, sid) != null:
			continue
		spawn_enemy(root, e)


func spawn_enemy(root: Node, entry: Dictionary) -> Node:
	var en: Node = (load(ENEMY_PATH) as GDScript).create(String(entry["kind"]), String(entry["id"]), Vector2(float(entry["x"]), 284.0))
	en.name = "Soul_" + String(entry["id"]).replace("/", "_")
	root.add_child(en)
	return en


func _find_enemy(root: Node, sid: String) -> Node:
	for n in root.get_children():
		if n.is_in_group("soul_enemy") and String(n.get("soul_id")) == sid and not bool(n.get("_dead")):
			return n
	return null


func _find_spark(root: Node, sid: String) -> Node:
	for n in root.get_children():
		if n.is_in_group("soul_spark") and String(n.get("soul_id")) == sid:
			return n
	return null


func _entry_for(sid: String) -> Dictionary:
	for r in SOULS.keys():
		for e in SOULS[r]:
			if String(e["id"]) == sid:
				return e
	return {}


## Düşman öldü: kıvılcım düşür (toplanırsa ruh serbest, aksi halde düşman döner).
func on_enemy_killed(enemy: Node) -> void:
	var par := enemy.get_parent()
	if par == null:
		return
	var at: Vector2 = (enemy as Node2D).global_position + Vector2(0, -22)
	(load(SPARK_PATH) as GDScript).spawn_at(par, at, String(enemy.get("soul_id")))


## Kıvılcım 5 sn içinde alınmadı: ruh geri döner, düşman evinde yeniden belirir.
func on_spark_expired(sid: String, root: Node, _at: Vector2) -> void:
	if root == null or not is_instance_valid(root) or is_collected(sid):
		return
	var entry := _entry_for(sid)
	if entry.is_empty() or _find_enemy(root, sid) != null:
		return
	spawn_enemy(root, entry)
