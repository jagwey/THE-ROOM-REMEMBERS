extends Node
## Lanet — bantlar: 0–49 kontrol, 50–69 ilk belirtiler, 70–89 tehlike, 90–99 kritik.
## 100 → ölüm DEĞİL: ele geçirilme sekansı, ardından son committed kayıt yüklenir (ceset/ruh/yatak yok, final değil).

signal curse_changed(value: float)
signal band_changed(band: int)
signal curse_whisper(text: String)
signal possession_started
signal possession_finished
signal curse_possession_started
signal curse_possession_finished
signal curse_failed_life

enum Band { CONTROL, FIRST_SIGNS, DANGER, CRITICAL }

const CURSE_MAX := 100.0
const BAND_FIRST_SIGNS := 50.0
const BAND_DANGER := 70.0
const BAND_CRITICAL := 90.0
## Ele geçirilmeden sonra lanet bu değere çekilir (Bant 1 - İlk İşaretler).
const POSSESSION_SAFE_CURSE := 50.0
const PossessionOverlay := preload("res://scripts/ui/possession_overlay.gd")

var curse: float = 0.0
var visible_meter: bool = false ## 50+ görüldüyse küçük mühür açık kalır
var band: int = Band.CONTROL
var possessing: bool = false
var is_possessing: bool:
	get: return possessing
	set(v): possessing = v


static func band_for(value: float) -> int:
	if value >= BAND_CRITICAL:
		return Band.CRITICAL
	if value >= BAND_DANGER:
		return Band.DANGER
	if value >= BAND_FIRST_SIGNS:
		return Band.FIRST_SIGNS
	return Band.CONTROL


func get_band() -> int:
	return band


func add_curse(amount: float, reason: StringName = &"") -> void:
	if amount <= 0.0 or possessing or DeathManager.is_dying:
		return
	if reason != &"":
		var touched: Array = GameState.world_memory_state["forbidden_touched"]
		var key := String(reason)
		if not touched.has(key):
			touched.append(key)
	set_curse(curse + amount)


func clear_curse(amount: float) -> void:
	if amount <= 0.0 or possessing:
		return
	set_curse(curse - amount)


## Lanet değerini ayarla (0–100). 100'e ulaşırsa ele geçirilme başlar.
func set_curse(value: float) -> void:
	if possessing or DeathManager.is_dying:
		return
	var prev := curse
	curse = clampf(value, 0.0, CURSE_MAX)
	curse_changed.emit(curse)
	_update_band(prev)
	if curse >= BAND_FIRST_SIGNS:
		visible_meter = true
	if curse >= CURSE_MAX:
		_begin_possession()


## Kayıt yüklemesi: değer ele geçirilmeyi tetiklemez (en çok 99), bant sessizce eşitlenir.
func restore_curse(value: float) -> void:
	curse = clampf(value, 0.0, CURSE_MAX - 1.0)
	curse_changed.emit(curse)
	var new_band := band_for(curse)
	if new_band != band:
		band = new_band
		band_changed.emit(band)


func _update_band(prev: float) -> void:
	var new_band := band_for(curse)
	if new_band != band:
		var old := band
		band = new_band
		band_changed.emit(band)
		if band > old:
			match band:
				Band.FIRST_SIGNS:
					curse_whisper.emit("…kulaklarında uğultu.")
				Band.DANGER:
					curse_whisper.emit("Kırmızı… her yerde.")
				Band.CRITICAL:
					curse_whisper.emit("Dayanamıyorum—")
	if prev < 40.0 and curse >= 40.0:
		curse_whisper.emit("Bir şey… içimde büyüyor.")


func _begin_possession() -> void:
	## Ölüm/final sırasında ele geçirme başlamaz.
	if DeathManager.is_dying or EndingManager.current != EndingManager.Ending.NONE:
		return
	possessing = true
	release_motion_locks()
	possession_started.emit()
	curse_possession_started.emit()
	curse_failed_life.emit()
	DialogueManager.clear()
	var repeat: bool = GameState.possession_count > 0
	GameState.possession_count += 1
	UiGate.set_cutscene(true)
	var scene := get_tree().current_scene
	var overlay: CanvasLayer = PossessionOverlay.new()
	scene.add_child(overlay)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var tint: Tween = null
	if player:
		tint = player.create_tween()
		tint.tween_property(player, "modulate", Color(1.6, 0.2, 0.3, 1.0), 0.6)
	await overlay.play(repeat)
	if tint and tint.is_valid():
		tint.kill() ## atlamada tint, yeniden doğan oyuncuyu kırmızı bırakmasın
	_reload_committed()
	await overlay.finish(repeat)
	UiGate.set_cutscene(false)
	possessing = false
	release_motion_locks()
	possession_finished.emit()
	curse_possession_finished.emit()


## Contract entrypoint (Interface Contract 1 / PROJECT.md)
func fail_curse_possession() -> void:
	if DeathManager.is_dying:
		return
	_begin_possession()


## Legacy alias for compatibility with R4/dispatch requirements
func _fail_life() -> void:
	_begin_possession()


## Son committed kayda dön: oda + güvenli konum; kalıcı dünya ilerlemesi (world_memory_state, PuzzleManager, player_progress_knowledge) KORUNUR.
func _reload_committed() -> void:
	var committed_data: Variant = SaveManager._read_with_fallback(SaveManager.SAVE_PATH)
	var room := &"awakening"
	var pos := GameState.DEFAULT_CHECKPOINT
	if committed_data is Dictionary:
		var life: Dictionary = (committed_data as Dictionary).get("character_current_life_knowledge", {})
		room = StringName(str(life.get("checkpoint_room", life.get("room", &"awakening"))))
		var cp_val: Variant = life.get("checkpoint", null)
		if cp_val is Dictionary:
			pos = Vector2(float((cp_val as Dictionary).get("x", 120.0)), float((cp_val as Dictionary).get("y", 280.0)))
		elif cp_val is Vector2:
			pos = cp_val as Vector2
	else:
		var life: Dictionary = GameState.character_current_life_knowledge
		room = StringName(str(life.get("checkpoint_room", life.get("room", &"awakening"))))
		pos = GameState.get_checkpoint()

	GameState.character_current_life_knowledge["checkpoint"] = pos
	GameState.character_current_life_knowledge["checkpoint_room"] = room
	GameState.character_current_life_knowledge["room"] = room
	GameState.character_current_life_knowledge["spawn_id"] = &"checkpoint"

	if RoomManager.has_room(room):
		RoomManager.enter_room(room, &"checkpoint", false)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("respawn_at"):
		player.respawn_at(pos)
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("snap_to_target"):
		cam.snap_to_target()

	restore_curse(POSSESSION_SAFE_CURSE)
	CorpseManager.rebuild_world_corpses()
	SaveManager.save_game()


## Lanet / ele geçirme hareket etkisi bırakmaz: zaman ölçeği 1.0, hız çarpanı yok.
func release_motion_locks() -> void:
	DeathManager.release_time_scale()


func reset_for_new_life() -> void:
	possessing = false
	release_motion_locks()
	curse = 0.0
	if band != Band.CONTROL:
		band = Band.CONTROL
		band_changed.emit(band)
	# Gösterge: meta olarak en az bir kez 50+ gördüyse açık kalabilir
	if not bool(GameState.player_progress_knowledge.get("curse_indicator_seen", false)):
		visible_meter = false
	curse_changed.emit(curse)


func unlock_indicator() -> void:
	visible_meter = true
	GameState.player_progress_knowledge["curse_indicator_seen"] = true
