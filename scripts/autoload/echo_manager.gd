extends Node
## Geçmiş Yankısı — rüya gibi kısa sahne. İptal = ödül yok; oturum kimliğiyle bağlanır.

signal echo_started(echo_id: StringName)
signal echo_finished(echo_id: StringName)
signal journal_updated

var active_echo: StringName = &""
var _play_gen: int = 0

## echo_id → rüya satırları (TR) + günlük kaydı (evidence_id)
var _catalog: Dictionary = {
	"default": {
		"evidence_id": "ev_default_fall",
		"lines": [
			["Yankı", "Karanlık… ayak sesleri."],
			["Yankı", "Biri fısıldadı: Oraya gitme."],
			["Yankı", "Sonra — düşüş."],
		],
		"journal": {
			"section": "notlar",
			"title": "İlk düşüş",
			"body": "Bir fısıltı: Oraya gitme. Sonra boşluk. Beden orada kaldı; ben değil.",
			"kind": "evidence",
		},
		"memory_code": "",
	},
	"awakening_rift_echo": {
		"evidence_id": "ev_rift_314",
		"lines": [
			["Yankı", "Kırmızı halka… zemin yalan söylüyor."],
			["Yankı", "Üç çatlak. Bir nefes. Dört kalp atışı."],
			["Yankı", "Sayı… üç… bir… dört."],
		],
		"journal": {
			"section": "izler",
			"title": "Yarığın sayısı",
			"body": "Rüyada gördüm: 3 — 1 — 4. Karakter bilmiyor. Ben biliyorum.",
			"kind": "evidence",
		},
		"memory_code": "314",
	},
	"crypt_first_bodies": {
		"evidence_id": "ev_crypt_rebirth",
		"lines": [
			["Yankı", "Yatağın başında Shilda. Elinde şırınga yok; sadece bir çiçek."],
			["Yankı", "Sen: Sil onu. Hepsini. Bir daha hatırlamak istemiyorum."],
			["Yankı", "Shilda: Sen unutursan… ben hatırlarım. Söz."],
		],
		"journal": {
			"section": "izler",
			"title": "Silme Emri",
			"body": "Hafızamın silinmesini ben istedim. Shilda söz verdi: ben unutursam o hatırlayacak.",
			"kind": "evidence",
		},
		"memory_code": "",
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
	if not GameState.player_progress_knowledge.has("evidence"):
		GameState.player_progress_knowledge["evidence"] = {}


func play_echo(echo_id: StringName) -> void:
	if active_echo != &"":
		return
	_ensure_player_journal()
	_play_gen += 1
	var gen := _play_gen
	active_echo = echo_id
	echo_started.emit(echo_id)

	var key := String(echo_id)
	var entry: Dictionary = _catalog.get(key, {})
	if entry.is_empty():
		if key.contains("corpse") and bool(GameState.player_progress_knowledge.get("first_death_seen", false)):
			entry = _catalog["awakening_rift_echo"]
		else:
			entry = _catalog["default"]

	var sites: Array = GameState.world_memory_state["echo_sites"]
	if not sites.has(key):
		sites.append(key)

	var seen: Array = GameState.player_progress_knowledge["echoes_seen"]
	var first_time := not seen.has(key)

	DialogueManager.say("…", "(gözlerin buğulanıyor)")
	for pair in entry.get("lines", []):
		if pair is Array and pair.size() >= 2:
			DialogueManager.say(String(pair[0]), String(pair[1]))
	var completed: bool = await DialogueManager.dialogue_finished

	if gen != _play_gen:
		active_echo = &""
		return

	## İptal softlock: uyanış yarığı yankısı kodunu ve günlüğü iptal sonrası da verir.
	var grant_rewards: bool = first_time and (completed or echo_id == &"awakening_rift_echo")
	if grant_rewards:
		seen.append(key)
		_write_journal(entry.get("journal", {}), String(entry.get("evidence_id", key)))
		var code := String(entry.get("memory_code", ""))
		if code != "":
			GameState.learn_memory_code("awakening", code)
		GameState.player_progress_knowledge["journal_unlocked"] = true
		journal_updated.emit()
		SaveManager.save_game()

	active_echo = &""
	echo_finished.emit(echo_id)


func _write_journal(note: Dictionary, evidence_id: String) -> void:
	if note.is_empty():
		return
	var evidence: Dictionary = GameState.player_progress_knowledge["evidence"]
	if evidence.has(evidence_id):
		return
	evidence[evidence_id] = {
		"id": evidence_id,
		"discovered": true,
		"kind": String(note.get("kind", "evidence")),
		"title": String(note.get("title", "Kayıt")),
		"body": String(note.get("body", "")),
		"section": String(note.get("section", "notlar")),
	}
	var notes: Array = GameState.player_progress_knowledge["journal_notes"]
	notes.append({
		"evidence_id": evidence_id,
		"section": String(note.get("section", "notlar")),
		"title": String(note.get("title", "Kayıt")),
		"body": String(note.get("body", "")),
		"kind": String(note.get("kind", "evidence")),
		"at_death": int(GameState.player_progress_knowledge.get("deaths", 0)),
	})
	if String(note.get("section", "")) != "gunluk":
		notes.append({
			"evidence_id": evidence_id + "_log",
			"section": "gunluk",
			"title": "Yankı notu",
			"body": String(note.get("title", "")) + " — hatırladım; o unuttu.",
			"kind": "inference",
			"at_death": int(GameState.player_progress_knowledge.get("deaths", 0)),
		})


func get_notes_for_section(section: String) -> Array:
	_ensure_player_journal()
	var out: Array = []
	for n in GameState.player_progress_knowledge["journal_notes"]:
		if n is Dictionary and String(n.get("section", "")) == section:
			out.append(n)
	return out


func register_echo(echo_id: String, data: Dictionary) -> void:
	_catalog[echo_id] = data
