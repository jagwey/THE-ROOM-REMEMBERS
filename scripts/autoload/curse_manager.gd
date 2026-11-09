extends Node
## Lanet — bantlar: 0–49 kontrol, 50–69 ilk belirtiler, 70–89 tehlike, 90–99 kritik.
## 100 → ölüm DEĞİL: ele geçirilme sekansı, ardından son committed kayıt yüklenir (ceset/ruh/yatak yok, final değil).

signal curse_changed(value: float)
signal band_changed(band: int)
signal curse_whisper(text: String)
signal possession_started
signal possession_finished

enum Band { CONTROL, FIRST_SIGNS, DANGER, CRITICAL }

const CURSE_MAX := 100.0
const BAND_FIRST_SIGNS := 50.0
const BAND_DANGER := 70.0
const BAND_CRITICAL := 90.0
## Ele geçirilmeden sonra lanet bu değeri aşamaz (asla kritik banda dönmez).
const POSSESSION_SAFE_CURSE := 25.0
const PossessionOverlay := preload("res://scripts/ui/possession_overlay.gd")

var curse: float = 0.0
var visible_meter: bool = false ## 50+ görüldüyse küçük mühür açık kalır
var band: int = Band.CONTROL
var possessing: bool = false


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
	if amount <= 0.0 or possessing:
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
	if possessing:
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
	## Ölüm/final sırasında ele geçirme başlamaz; lanet 99'da tutulur.
	if DeathManager.is_dying or EndingManager.current != EndingManager.Ending.NONE:
		curse = CURSE_MAX - 1.0
		curse_changed.emit(curse)
		return
	possessing = true
	possession_started.emit()
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
	possession_finished.emit()


## Son committed kayda dön: oda + güvenli konum; dünya ve hikâye durumu committed hale gelir.
func _reload_committed() -> void:
	SaveManager.load_committed()
	var life: Dictionary = GameState.character_current_life_knowledge
	var room := StringName(str(life.get("checkpoint_room", life.get("room", &"awakening"))))
	## Committed kayıt yoksa da mevcut checkpoint konumu kullanılır (oda varsayılanı değil).
	if RoomManager.has_room(room):
		RoomManager.enter_room(room, &"checkpoint", false)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_method("respawn_at"):
		var pos: Vector2 = player.global_position if RoomManager.has_room(room) else GameState.get_checkpoint()
		player.respawn_at(pos)
	var cam := get_tree().get_first_node_in_group("follow_camera")
	if cam and cam.has_method("snap_to_target"):
		cam.snap_to_target()
	restore_curse(minf(curse, POSSESSION_SAFE_CURSE))
	CorpseManager.rebuild_world_corpses()
	## Sayaç ve yeni durum diske yazılsın (resume dosyası, committed'a dokunmaz).
	SaveManager.save_game()


func reset_for_new_life() -> void:
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
