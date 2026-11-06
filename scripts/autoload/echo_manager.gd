extends Node
## Geçmiş Yankısı — rüya gibi kısa sahne. Bilgi oyuncuya/günlüğe gider; karaktere otomatik yazılmaz.

signal echo_started(echo_id: StringName)
signal echo_finished(echo_id: StringName)
signal journal_updated

var active_echo: StringName = &""

## echo_id → rüya satırları (TR) + günlük kaydı
var _catalog: Dictionary = {
	"default": {
		"lines": [
			["Yankı", "Karanlık… ayak sesleri."],
			["Yankı", "Biri fısıldadı: Oraya gitme."],
			["Yankı", "Sonra — düşüş."],
		],
		"journal": {
			"section": "notlar",
			"title": "İlk düşüş",
			"body": "Bir fısıltı: Oraya gitme. Sonra boşluk. Beden orada kaldı; ben değil.",
		},
		"memory_code": "",
	},
	"awakening_rift_echo": {
		"lines": [
			["Yankı", "Kırmızı halka… zemin yalan söylüyor."],
			["Yankı", "Üç çatlak. Bir nefes. Dört kalp atışı."],
			["Yankı", "Sayı… üç… bir… dört."],
		],
		"journal": {
			"section": "izler",
			"title": "Yarığın sayısı",
			"body": "Rüyada gördüm: 3 — 1 — 4. Karakter bilmiyor. Ben biliyorum.",
		},
		"memory_code": "314",
	},
}


func _ready() -> void:
	_ensure_player_journal()


func _ensure_player_journal() -> void:
	if not GameState.player_progress_knowledge.has("journal_notes"):
		GameState.player_progress_knowledge["journal_notes"] = []
	if not GameState.player_progress_knowledge.has("echoes_seen"):
		GameState.player_progress_knowledge["echoes_seen"] = []
	if not GameState.player_progress_knowledge.has("memory_codes"):
		GameState.player_progress_knowledge["memory_codes"] = {}


func play_echo(echo_id: StringName) -> void:
	if active_echo != &"":
		return
	_ensure_player_journal()
	active_echo = echo_id
	echo_started.emit(echo_id)

	var key := String(echo_id)
	var entry: Dictionary = _catalog.get(key, {})
	if entry.is_empty():
		# Ceset id'lerine özel: rift ölümüyle ilişkilendir
		if key.contains("corpse") and bool(GameState.player_progress_knowledge.get("first_death_seen", false)):
			entry = _catalog["awakening_rift_echo"]
		else:
			entry = _catalog["default"]

	var sites: Array = GameState.world_memory_state["echo_sites"]
	if not sites.has(key):
		sites.append(key)

	var seen: Array = GameState.player_progress_knowledge["echoes_seen"]
	var first_time := not seen.has(key)
	if first_time:
		seen.append(key)

	# Karakter otomatik bilmez — sadece oyuncu/günlük.
	DialogueManager.say("…", "(gözlerin buğulanıyor)")
	for pair in entry.get("lines", []):
		if pair is Array and pair.size() >= 2:
			DialogueManager.say(String(pair[0]), String(pair[1]))
	await DialogueManager.dialogue_closed

	if first_time:
		_write_journal(entry.get("journal", {}))
		var code := String(entry.get("memory_code", ""))
		if code != "":
			GameState.player_progress_knowledge["memory_codes"]["awakening"] = code
		GameState.player_progress_knowledge["journal_unlocked"] = true
		journal_updated.emit()
		SaveManager.save_game()

	active_echo = &""
	echo_finished.emit(echo_id)


func _write_journal(note: Dictionary) -> void:
	if note.is_empty():
		return
	var notes: Array = GameState.player_progress_knowledge["journal_notes"]
	var title := String(note.get("title", "Kayıt"))
	for n in notes:
		if n is Dictionary and String(n.get("title", "")) == title:
			return
	notes.append({
		"section": String(note.get("section", "notlar")),
		"title": title,
		"body": String(note.get("body", "")),
		"at_death": int(GameState.player_progress_knowledge.get("deaths", 0)),
	})
	# Günlük bölümüne kısa özet satırı
	if String(note.get("section", "")) != "gunluk":
		notes.append({
			"section": "gunluk",
			"title": "Yankı notu",
			"body": title + " — hatırladım; o unuttu.",
			"at_death": int(GameState.player_progress_knowledge.get("deaths", 0)),
		})


func get_notes_for_section(section: String) -> Array:
	_ensure_player_journal()
	var out: Array = []
	for n in GameState.player_progress_knowledge["journal_notes"]:
		if n is Dictionary and String(n.get("section", "")) == section:
			out.append(n)
	return out
