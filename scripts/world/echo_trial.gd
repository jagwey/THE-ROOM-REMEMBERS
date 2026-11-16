extends Area2D
## Yankı Sınavı: çözülmüş derin odanın zamanlı varyantı. Sunak yalnız oda bulmacası çözülünce açılır.
## Sınav, odadaki sequence_shrine adımlarını KENDİ sırasıyla (order) okur; odanın çözülü durumuna dokunmaz.
## Süre dolunca ceza yok: adımlar çözülü haline (yanık) döner, istenince yeniden denenir.
## Başarıda defter sayfası + kalıcı "trial_<oda>" bayrağı. Ana ilerlemeye/hedeflere yazmaz (mark_solved yok).

const LorePointScript := preload("res://scripts/world/lore_point.gd")
const TOTAL := 6

## Oda kimliği; bayrak "trial_<trial_room>" olur.
@export var trial_room: StringName = &""
## Sınavın dayandığı sequence_shrine (bu node'a göre yol).
@export var shrine_path: NodePath = NodePath("")
## Sınav sırası (sequence_step step_id değerleri). Varyant burada: oda sırasından farklıdır.
@export var order: PackedStringArray = PackedStringArray()
@export var time_limit: float = 75.0
## Yanlış adımda süreden düşülen saniye (0 = yalnız zincir sıfırlanır).
@export var wrong_penalty: float = 0.0
## Her adımda canlı olması gereken plaka/bulmaca kimlikleri (boşsa yok).
@export var hold_live: PackedStringArray = PackedStringArray()
@export var hold_line: String = "Plaka boş; ağırlığı geri koymalıyım."
## Kadran bükümü: sınav sürerken bu kadran (dial_puzzle) belirli değerde durmalı (-1 = yok).
@export var dial_path: NodePath = NodePath("")
@export var dial_index: int = -1
@export var dial_value: int = 0
@export var dial_line: String = ""
## Dönüş bükümü: bu adım sırasından (order indeksi) önce oyuncu sunağa yeniden dokunmalı (-1 = yok).
@export var recall_at: int = -1
@export var recall_line: String = ""
## Yetenek bükümü: bu adım sırasından önce oyuncu yeteneği kullanmalı ("soul_slash" | "shadow_dash"; "" = yok).
@export var ability_kind: StringName = &""
@export var ability_at: int = -1
@export var ability_line: String = ""
## HUD'da gösterilen büküm etiketi ("Kadran: Mart", "Sunağa dön", "Ruh Kesimi").
@export var twist_label: String = ""
## Sınav başında söylenen oda satırı (ardından yeni sıra ve süre yazılır).
@export var intro_line: String = ""
@export var reward_title: String = ""
@export var reward_body: String = ""

var _active: bool = false
var _busy: bool = false
var _idx: int = 0
var _time_left: float = 0.0
var _shrine: Node = null
var _hud: CanvasLayer = null
var _timer_label: Label = null
var _seq_label: Label = null
var _label: Label = null
var _recalled: bool = false
var _ability_done: bool = false
var _note: String = ""
var _note_t: float = 0.0
## Test: son sınavın sonucu ("", "success", "timeout", "abort").
var last_result: String = ""


static func flags() -> Dictionary:
	var d: Variant = GameState.player_progress_knowledge.get("trials", {})
	return d if d is Dictionary else {}


static func count() -> int:
	var n := 0
	for k in flags():
		if bool(flags()[k]):
			n += 1
	return mini(n, TOTAL)


static func has_trial(room_id: String) -> bool:
	return bool(flags().get("trial_%s" % room_id, false))


func flag_key() -> String:
	return "trial_%s" % String(trial_room)


func is_active() -> bool:
	return _active


func get_progress() -> int:
	return _idx


func time_left() -> float:
	return _time_left


## Oda bulmacası çözüldü mü? Sınav yalnız o zaman açılır.
func is_available() -> bool:
	var sh := _get_shrine()
	return sh != null and PuzzleManager.is_solved(sh.get("puzzle_id"))


func _ready() -> void:
	add_to_group("echo_trial")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	set_process(false)
	if get_node_or_null("CollisionShape2D") == null:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 96)
		cs.shape = rect
		add_child(cs)
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite2D"
		add_child(spr)
	spr.texture = load("res://assets/props/halo.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.modulate = Color(0.95, 0.78, 0.45, 1.0)
	_label = Label.new()
	_label.position = Vector2(-90, -78)
	_label.size = Vector2(180, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UiTheme.has_method("apply_outlined"):
		UiTheme.call("apply_outlined", _label, 14)
	else:
		UiTheme.apply_label(_label, 14)
	add_child(_label)
	RoomManager.room_changed.connect(_on_room_changed)
	PuzzleManager.puzzle_solved.connect(_on_puzzle_solved)
	SaveManager.game_loaded.connect(_on_game_loaded)
	_refresh_label()


func _exit_tree() -> void:
	if _active:
		_end(&"abort")
	if RoomManager.room_changed.is_connected(_on_room_changed):
		RoomManager.room_changed.disconnect(_on_room_changed)
	if SaveManager.game_loaded.is_connected(_on_game_loaded):
		SaveManager.game_loaded.disconnect(_on_game_loaded)
	if PuzzleManager.puzzle_solved.is_connected(_on_puzzle_solved):
		PuzzleManager.puzzle_solved.disconnect(_on_puzzle_solved)


func get_interact_label() -> String:
	return "Yankı Sınavı"


func get_glow_kind() -> StringName:
	return &"memory"


func _on_puzzle_solved(_id: StringName) -> void:
	_refresh_label()


## Kayıt yüklenince sınav bırakılır (bellek içi durum kayda girmez; oda çözülü haline döner).
func _on_game_loaded() -> void:
	if _active:
		_end(&"abort")


func _on_room_changed(_from_room: StringName, _to_room: StringName) -> void:
	if _active:
		_end(&"abort")


func _refresh_label() -> void:
	if _label == null:
		return
	if has_trial(String(trial_room)):
		_label.text = "Yankı Sınavı · tamamlandı"
	elif is_available():
		_label.text = "Yankı Sınavı · %s: başla" % MobileInputManager.control_name(&"interact")
	else:
		_label.text = "Yankı Sınavı · kilitli"


func _get_shrine() -> Node:
	if _shrine != null and is_instance_valid(_shrine):
		return _shrine
	if shrine_path != NodePath(""):
		_shrine = get_node_or_null(shrine_path)
	return _shrine


## "Gün Çanı › Yas Çanı › Gece Çanı" biçiminde sınav sırası (adım etiketlerinden).
func order_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var sh := _get_shrine()
	for sid in order:
		var name_tr := String(sid)
		if sh:
			for c in sh.get_children():
				if "step_id" in c and String(c.step_id) == String(sid):
					name_tr = String(c.label)
		parts.append(name_tr)
	return " › ".join(parts)


func on_interact(_by: Node) -> void:
	if _active:
		## Dönüş bükümü: sırası gelince sunağa yeniden dokunmak kaydı onaylar.
		if recall_at >= 0 and _idx == recall_at and not _recalled:
			_recalled = true
			_flash("Sunak kaydı onayladı.")
		return
	if _busy:
		return
	if not is_available():
		_busy = true
		DialogueManager.say("Noroi", "Yankı bu odayı henüz tanımıyor. Önce odanın sırrını çözmeliyim.")
		await DialogueManager.dialogue_finished
		_busy = false
		return
	if has_trial(String(trial_room)):
		DialogueManager.say("Noroi", "Bu sınavı geçtim; kayıt defterde duruyor.")
		return
	_busy = true
	if intro_line != "":
		DialogueManager.say("Noroi", intro_line)
	DialogueManager.say("Noroi", "Yeni kayıt: %s. Süre %d saniye." % [order_text(), int(time_limit)])
	var ok: bool = await DialogueManager.dialogue_finished
	_busy = false
	if not ok or _active:
		return
	begin()


## Sınavı başlatır (testler diyaloğu atlayıp doğrudan çağırır).
func begin() -> bool:
	if _active or not is_available() or order.is_empty():
		return false
	var sh := _get_shrine()
	_active = true
	_idx = 0
	_time_left = time_limit
	last_result = ""
	_recalled = false
	_ability_done = false
	_note = ""
	_note_t = 0.0
	var dl := _get_dial()
	if dl and dl.has_method("begin_trial") and dial_index >= 0:
		dl.begin_trial(dial_index)
	if sh and sh.has_method("_set_all_lit"):
		sh._set_all_lit(false)
	_build_hud()
	_update_hud("")
	set_process(true)
	_refresh_label()
	return true


func _process(delta: float) -> void:
	if DialogueManager.is_open:
		return
	tick(delta)


## Süre ilerletir; dolunca cezasız biter. Testler doğrudan çağırır.
func tick(delta: float) -> void:
	if not _active:
		return
	_time_left -= delta
	_note_t = maxf(0.0, _note_t - delta)
	if _time_left <= 0.0:
		_time_left = 0.0
		_end(&"timeout")
		return
	_update_hud(_note if _note_t > 0.0 else "")


## sequence_shrine.press() sınav sırasında adımı buraya yönlendirir. Doğruysa true (shrine kendi mantığını atlar).
func handle_step(shrine: Node, step_id: String, source: Node) -> bool:
	if not _active or shrine != _get_shrine():
		return false
	for rid in hold_live:
		if not PuzzleManager.is_live(StringName(rid)):
			_flash(hold_line)
			return true
	var gate := twist_gate()
	if gate != "":
		_flash(gate)
		return true
	var want := String(order[_idx])
	if step_id == want:
		_idx += 1
		if source and source.has_method("set_lit"):
			source.set_lit(true)
		if shrine.has_method("_tick"):
			shrine._tick(source)
		if _idx >= order.size():
			_end(&"success")
		else:
			_update_hud("")
		return true
	_idx = 0
	_recalled = false
	_ability_done = false
	if shrine.has_method("_set_all_lit"):
		shrine._set_all_lit(false)
	if shrine.has_method("_trauma"):
		shrine._trauma(0.18)
	if step_id == String(order[0]):
		_idx = 1
		if source and source.has_method("set_lit"):
			source.set_lit(true)
	if wrong_penalty > 0.0:
		_time_left = maxf(0.5, _time_left - wrong_penalty)
	_flash("Yanlış sıra.")
	return true


## Büküm engeli: boşsa adım geçebilir; doluysa söylenecek satır (zincir bozulmaz, ceza yok).
func twist_gate() -> String:
	var dl := _get_dial()
	if dial_index >= 0 and dl != null and dl.has_method("values"):
		var vals: PackedInt32Array = dl.values()
		if dial_index < vals.size() and vals[dial_index] != dial_value:
			return dial_line if dial_line != "" else "Kadran yanlış değerde."
	if recall_at >= 0 and _idx == recall_at and not _recalled:
		return recall_line if recall_line != "" else "Önce sunağa dönmeliyim."
	if ability_kind != &"" and _idx == ability_at and not _ability_done:
		return ability_line if ability_line != "" else "Önce yeteneği kullanmalıyım."
	return ""


## Yetenek bükümü: mühür/çizgi yeteneği kullanıldığında bildirir (soul_seal, curse_barrier).
func note_ability(kind: StringName, _src: Node = null) -> void:
	if not _active or ability_kind == &"" or kind != ability_kind:
		return
	if not _ability_done:
		_ability_done = true
		_flash("%s tamam." % (twist_label if twist_label != "" else "Yetenek"))


func _get_dial() -> Node:
	if dial_path == NodePath(""):
		return null
	return get_node_or_null(dial_path)


func _flash(note: String) -> void:
	_note = note
	_note_t = 3.0
	_update_hud(note)


func twist_status() -> String:
	if twist_label == "":
		return ""
	var ok := true
	var dl := _get_dial()
	if dial_index >= 0 and dl != null and dl.has_method("values"):
		var vals: PackedInt32Array = dl.values()
		ok = dial_index < vals.size() and vals[dial_index] == dial_value
	if recall_at >= 0:
		ok = ok and (_recalled or _idx > recall_at)
	if ability_kind != &"":
		ok = ok and (_ability_done or _idx > ability_at)
	return "%s: %s" % [twist_label, "tamam" if ok else "bekliyor"]


func _end(result: StringName) -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	last_result = String(result)
	var dl := _get_dial()
	if dl and is_instance_valid(dl) and dl.has_method("end_trial"):
		dl.end_trial()
	var sh := _get_shrine()
	## Odanın çözülü hali: tüm adımlar yanık.
	if sh and is_instance_valid(sh) and sh.has_method("_set_all_lit") and sh.is_inside_tree():
		sh._set_all_lit(PuzzleManager.is_solved(sh.get("puzzle_id")))
	_free_hud()
	if result == &"success":
		_reward()
	elif result == &"timeout" and is_inside_tree():
		DialogueManager.say("Noroi", "Süre doldu. Yankı sustu; istediğimde yeniden deneyebilirim.")
	_refresh_label()


func _reward() -> void:
	var d := flags()
	d[flag_key()] = true
	GameState.player_progress_knowledge["trials"] = d
	LorePointScript.record_evidence("ev_%s" % flag_key(), reward_title, reward_body, "izler", "evidence")
	if is_inside_tree():
		EchoManager.journal_updated.emit()
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(&"seal_open", -8.0)
		DialogueManager.say("Noroi", "Yankı sınavı geçildi. Defterime yeni bir sayfa yazıldı.")
	SaveManager.save_game()


func _build_hud() -> void:
	_free_hud()
	_hud = CanvasLayer.new()
	_hud.layer = 40
	_timer_label = Label.new()
	_timer_label.anchor_left = 0.0
	_timer_label.anchor_right = 1.0
	_timer_label.offset_top = 56.0
	_timer_label.offset_bottom = 84.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seq_label = Label.new()
	_seq_label.anchor_left = 0.0
	_seq_label.anchor_right = 1.0
	_seq_label.offset_top = 84.0
	_seq_label.offset_bottom = 108.0
	_seq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UiTheme.has_method("apply_outlined"):
		UiTheme.call("apply_outlined", _timer_label, 22, true)
		UiTheme.call("apply_outlined", _seq_label, 14)
	_hud.add_child(_timer_label)
	_hud.add_child(_seq_label)
	add_child(_hud)


func _free_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	_timer_label = null
	_seq_label = null


func _update_hud(note: String) -> void:
	if _timer_label == null:
		return
	var secs := int(ceil(_time_left))
	_timer_label.text = "Yankı Sınavı  %d:%02d" % [secs / 60, secs % 60]
	var s := "%s  (%d/%d)" % [order_text(), _idx, order.size()]
	var ts := twist_status()
	if ts != "":
		s = "%s  ·  %s" % [s, ts]
	if note != "":
		s = "%s  ·  %s" % [note, s]
	_seq_label.text = s
