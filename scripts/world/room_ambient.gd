extends Node
## Yürüyüş ağırlıklı odalarda ziyaret başına bir kez, oyuncu oda ortasını geçince kısa bir ortam anı
## (uzak ses + tek satır fısıltı; HUD toast kuyruğu). Veri tek yerde: LINES.
## Ayrıca hızlı seyahat ipucu: oyuncu art arda 3 görülmüş odadan geçince bir kez (GameSettings'te kalıcı).
## HUD (hud_controller.gd) çocuk olarak ekler; toast için üst düğümün queue_toast()'unu kullanır.

const MID_DEADZONE := 24.0
const REVISIT_STREAK_FOR_HINT := 3

## room_id -> [satır, sfx, dB]. Spoiler yok; kısa (toast dar).
const LINES := {
	&"experiment_quarantine": ["Duvarın ardında bir nefes var.", &"breath", -14.0],
	&"experiment_authority": ["Masalardan biri hâlâ sıcak.", &"clock_tick", -12.0],
	&"experiment_circuit": ["Uzakta bir şey tıkırdadı.", &"clock_tick", -14.0],
	&"library_page": ["Bir sayfa kendiliğinden çevrildi.", &"typewriter", -16.0],
	&"awakening_vigil": ["Nöbet bitmedi. Biri sayıyor.", &"clock_tick", -12.0],
	&"decay_shilda_wall": ["Çatlaktan bir fısıltı sızıyor.", &"curse_whisper", -16.0],
}

var _room: StringName = &""
var _fired: bool = false
var _side: int = 0
var _revisit_streak: int = 0
var fired_log: Array[StringName] = [] ## test/audit: ateşlenen odalar


func _ready() -> void:
	GameState.room_changed.connect(on_room_changed)


func on_room_changed(room_id: StringName) -> void:
	_room = room_id
	_fired = false
	_side = 0
	if GameState.last_visit_was_new:
		_revisit_streak = 0
	else:
		_revisit_streak += 1
		_maybe_fast_travel_hint()


func _process(_delta: float) -> void:
	if _fired or not LINES.has(_room):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not RoomManager.has_room(_room):
		return
	var b: Rect2 = RoomManager.get_active_room_bounds()
	if b.size.x <= 0.0:
		return
	tick_at(player.global_position.x, b.position.x + b.size.x * 0.5)


## Oyuncu x'i oda ortasının karşı yanına geçtiyse bir kez ateşler. Ateşlendiyse true.
func tick_at(px: float, cx: float) -> bool:
	if _fired or not LINES.has(_room):
		return false
	var dx := px - cx
	if _side == 0:
		if absf(dx) > MID_DEADZONE:
			_side = 1 if dx > 0.0 else -1
		return false
	if float(_side) * dx >= 0.0:
		return false
	if UiGate.current_layer() != UiGate.Layer.NONE or DeathManager.is_dying or DialogueManager.is_open:
		return false ## uygun an gelene kadar bekle
	_fired = true
	var d: Array = LINES[_room]
	AudioManager.play_sfx(StringName(d[1]), float(d[2]))
	_toast(String(d[0]))
	fired_log.append(_room)
	return true


func _maybe_fast_travel_hint() -> void:
	GameSettings.ensure_loaded()
	if GameSettings.fast_travel_hint_shown or _revisit_streak < REVISIT_STREAK_FOR_HINT:
		return
	GameSettings.fast_travel_hint_shown = true
	GameSettings.save_settings()
	if MobileInputManager.is_touch_ui():
		_toast("İpucu: Günlükteki haritada bir odaya iki kez dokun, hızlıca dön.")
	else:
		_toast("İpucu: Günlüğü aç (%s), haritada bir odaya çift tıkla, hızlıca dön." % MobileInputManager.control_name(&"journal"))


func _toast(text: String) -> void:
	var p := get_parent()
	if p != null and p.has_method("queue_toast"):
		p.queue_toast(text)
