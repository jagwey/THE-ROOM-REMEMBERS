extends "res://scripts/world/sequence_shrine.gd"
## Kırık Anı: Shilda'nın insan hayatından 3 kırık parça. Önce üçü de okunur (her dokunuş
## parçayı gösterir); sonra parçalar tarih ve neden-sonuç sırasına göre dokunulur.
## Yanlış sıra cezasızdır, zinciri sıfırlar. Çözüm: kalıcı bayrak + günlük kaydı + Shilda satırı.
## İsteğe bağlıdır; hiçbir kapıyı kilitlemez.

const TOTAL := 5

## Kronolojik sıra (S.'nin Odası duvarı bu sırayı kullanır).
const CHRONO: Array = ["uyanis", "decay", "kutuphane", "deney", "aynalar"]

const DATA := {
	"uyanis": {
		"title": "Kırık Anı: İlk Gün",
		"year": "Ekim 1921",
		"frags": {
			"a": "Ekim 1921. Kapıdaki görevli adımı deftere yazdı: S., yardımcı.",
			"b": "Aynı akşam bana bir anahtar ve boş bir defter verdiler.",
			"c": "Ertesi sabah ilk sayfaya yazdım: bugün çalışmaya başladım.",
		},
		"order": ["a", "b", "c"],
		"body": "Ekim 1921. Araştırma Yardımcısı S. göreve başladı: kayıt, anahtar, boş defter.",
		"line": "İlk günümü hatırlıyorum. Anahtarı kaybettim; defteri değil.",
	},
	"decay": {
		"title": "Kırık Anı: Sera",
		"year": "Mart 1923",
		"frags": {
			"a": "Mart 1923. Serada ilk fide öldü; kimse nedenini bulamadı.",
			"b": "Nisan 1923. Toprağa baktım: kökler suyu çekmiyor, çürüyordu.",
			"c": "Mayıs 1923. Müdür serayı kapattı. Notlarımı bana bıraktı.",
		},
		"order": ["a", "b", "c"],
		"body": "1923 baharı. Seradaki çürüme S.'nin notlarında başladı; sera kapatıldı.",
		"line": "Seranın kokusu hâlâ burada. Çürümeyi o zaman da durduramadım.",
	},
	"kutuphane": {
		"title": "Kırık Anı: Yasak Raf",
		"year": "Eylül 1924",
		"frags": {
			"a": "Eylül 1924. Yasak rafın anahtarı bende kaldı.",
			"b": "Şubat 1925. Rafta bir deney kaydı buldum; sayfaları eksikti.",
			"c": "Haziran 1925. Eksik sayfalar saat odasında, duvarın ardındaydı.",
		},
		"order": ["a", "b", "c"],
		"body": "1924-1925. S. yasak rafın anahtarını aldı; eksik deney sayfalarını saat odasında buldu.",
		"line": "O raf kilitliydi. Anahtar bende kalmıştı; şimdi hatırlıyorum.",
	},
	"deney": {
		"title": "Kırık Anı: Yanlış Sayı",
		"year": "Ocak 1926",
		"frags": {
			"a": "Ocak 1926. Gözlem odasında defter tutmakla görevlendirildim.",
			"b": "Ağustos 1926. Verileri geçirirken bir sayının yanlış olduğunu gördüm.",
			"c": "Aralık 1926. Sayıyı müdüre gösterdim; susturdu, odayı kilitledi.",
		},
		"order": ["a", "b", "c"],
		"body": "1926. S. gözlem kayıtlarında yanlış bir sayı buldu; müdür bunu kilit altına aldı.",
		"line": "Sayının yanlış olduğunu biliyordum. Susmayı o odada öğrendim.",
	},
	"aynalar": {
		"title": "Kırık Anı: Geç Yansıma",
		"year": "Mart 1927",
		"frags": {
			"a": "Mart 1927. Aynalı galeriye çağırdılar; kendimi iki kez gördüm.",
			"b": "Mayıs 1927. Yansımam benden bir adım geç hareket etti.",
			"c": "Haziran 1927. Son kayda tarihi yazamadım; ellerim titriyordu.",
		},
		"order": ["a", "b", "c"],
		"body": "1927. Galerideki yansıma S.'den geç kaldı; son kayıt tarihsiz kaldı.",
		"line": "Aynada geç kalan bendim. Sen düzgün yürü, Noroi.",
	},
}

@export var memory_id: String = "uyanis"

var _read: Dictionary = {}


static func flags() -> Dictionary:
	var d: Variant = GameState.player_progress_knowledge.get("memories", {})
	return d if d is Dictionary else {}


static func count() -> int:
	var n := 0
	for k in flags():
		if bool(flags()[k]):
			n += 1
	return mini(n, TOTAL)


static func has_memory(id: String) -> bool:
	return bool(flags().get(id, false))


func _ready() -> void:
	var d: Dictionary = DATA.get(memory_id, {})
	puzzle_id = StringName("memory_" + memory_id)
	var ord := PackedStringArray()
	for s in d.get("order", []):
		ord.append(String(s))
	order = ord
	fail_line = "Sıra tutmadı. Tarihlere ve olayların sırasına bak."
	penalize_wrong = false
	if has_memory(memory_id) and not PuzzleManager.is_solved(puzzle_id):
		PuzzleManager.mark_solved(puzzle_id)
	super._ready()
	if PuzzleManager.is_solved(puzzle_id):
		for k in d.get("frags", {}):
			_read[k] = true


func read_count() -> int:
	return _read.size()


func press(step_id: String, source: Node = null) -> void:
	var d: Dictionary = DATA.get(memory_id, {})
	var frags: Dictionary = d.get("frags", {})
	if not frags.has(step_id):
		return
	if PuzzleManager.is_solved(puzzle_id):
		if not DialogueManager.is_open:
			DialogueManager.say("Kayıt", String(frags[step_id]))
		return
	if _read.size() < frags.size():
		var first := not _read.has(step_id)
		_read[step_id] = true
		DialogueManager.say("Kayıt", String(frags[step_id]))
		if first and _read.size() >= frags.size():
			DialogueManager.say("Noroi", "Üç parça da okundu. Şimdi doğru sırayla dokunmalıyım.")
		return
	if not DialogueManager.is_open:
		DialogueManager.say("Kayıt", String(frags[step_id]))
	super.press(step_id, source)


func _repeat_clue() -> void:
	pass


func _add_evidence() -> void:
	var d: Dictionary = DATA.get(memory_id, {})
	if d.is_empty():
		return
	var first := not has_memory(memory_id)
	var mem: Dictionary = flags().duplicate()
	mem[memory_id] = true
	GameState.player_progress_knowledge["memories"] = mem
	evidence_id = "memory_" + memory_id
	evidence_title = String(d["title"])
	evidence_body = String(d["body"])
	super._add_evidence()
	if first:
		DialogueManager.say(GameState.keeper_speaker_name(), String(d["line"]))
		DialogueManager.say("Kayıt", "Anılar %d/%d." % [count(), TOTAL])
