extends Node
## Hikâye diyaloğu — sayfalama, tip yazıcı, iptal ≠ tamamlanma.
## Ortam fısıltıları (CurseVFX) bu yöneticiden geçmez.

signal line_shown(speaker: String, text: String)
signal page_shown(speaker: String, page_text: String, page_index: int, page_count: int)
signal dialogue_closed ## yalnızca başarılı tamamlanma
signal dialogue_cancelled
signal dialogue_finished(completed: bool)
signal typing_finished

var _queue: Array[Dictionary] = []
var is_open: bool = false
var last_was_whisper: bool = false
var generation: int = 0

## Aktif satırın sayfaları
var _pages: PackedStringArray = []
var _page_index: int = 0
var _speaker: String = ""
var _full_line: String = ""
var _typing: bool = false
var _typed_len: int = 0
var _type_accum: float = 0.0
const TYPE_CPS := 48.0

## Sayfa ölçümü — HUD Content alanına göre ayarlanır
var page_max_width: float = 300.0
var page_max_lines: int = 3
var page_font_size: int = 12
var page_font: Font = null


func say(speaker: String, text: String) -> void:
	_enqueue(speaker, text, false)


func whisper(speaker: String, text: String) -> void:
	## Hikâye fısıltısı: modal paneli kullanır (ortam VFX fısıltısından ayrı).
	_enqueue(speaker, text, true)


func _enqueue(speaker: String, text: String, is_whisper: bool) -> void:
	_queue.append({"speaker": speaker, "text": text, "whisper": is_whisper})
	if not is_open:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_finish(true)
		return
	if not is_open:
		is_open = true
		generation += 1
		UiGate.set_story(true)
	var line: Dictionary = _queue.pop_front()
	last_was_whisper = bool(line.get("whisper", false))
	_speaker = String(line["speaker"])
	_full_line = String(line["text"])
	if last_was_whisper and _speaker != "Bekçi":
		_speaker = "???"
	_pages = _paginate(_full_line, page_max_width, page_max_lines, page_font_size, page_font)
	if _pages.is_empty():
		_pages = PackedStringArray([""])
	_page_index = 0
	_begin_page()
	_schedule_headless_auto()


func _begin_page() -> void:
	var page := _pages[_page_index]
	_typing = true
	_typed_len = 0
	_type_accum = 0.0
	line_shown.emit(_speaker, page)
	page_shown.emit(_speaker, page, _page_index, _pages.size())
	if page.is_empty():
		_typing = false
		typing_finished.emit()


func _schedule_headless_auto() -> void:
	# Headless: varsayılan otomatik ilerleme (smoke). Görüntülü testte
	# TORIMON_NO_AUTO_DIALOGUE=1 ile kapat. Tek zincir — çift timer yok.
	if DisplayServer.get_name() != "headless":
		return
	if OS.get_environment("TORIMON_NO_AUTO_DIALOGUE") == "1":
		return
	var gen := generation
	get_tree().create_timer(0.04).timeout.connect(func():
		if generation != gen or not is_open:
			return
		if is_typing():
			_typing = false
			_typed_len = _pages[_page_index].length() if not _pages.is_empty() else 0
			page_shown.emit(_speaker, _pages[_page_index], _page_index, _pages.size())
			typing_finished.emit()
		else:
			advance()
		if is_open and generation == gen:
			_schedule_headless_auto()
	, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if not is_open or not _typing:
		return
	var page := _pages[_page_index]
	_type_accum += delta * TYPE_CPS
	var add := int(_type_accum)
	if add <= 0:
		return
	_type_accum -= float(add)
	_typed_len = mini(_typed_len + add, page.length())
	page_shown.emit(_speaker, page.substr(0, _typed_len), _page_index, _pages.size())
	if _typed_len >= page.length():
		_typing = false
		typing_finished.emit()


func visible_page_text() -> String:
	if _pages.is_empty():
		return ""
	var page := _pages[_page_index]
	if _typing:
		return page.substr(0, _typed_len)
	return page


func is_typing() -> bool:
	return _typing


func has_queued_lines() -> bool:
	return not _queue.is_empty()


func advance() -> void:
	if not is_open:
		return
	if UiGate.blocks_dialogue_advance():
		return
	# İlk basış: sayfayı tamamla.
	if _typing:
		_typing = false
		_typed_len = _pages[_page_index].length()
		page_shown.emit(_speaker, _pages[_page_index], _page_index, _pages.size())
		typing_finished.emit()
		return
	# Sonraki sayfa veya sonraki satır.
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_begin_page()
		return
	_show_next()


func clear() -> void:
	## İptal — tamamlanma sinyali YOK.
	_queue.clear()
	_pages = PackedStringArray()
	_page_index = 0
	_typing = false
	if is_open:
		_finish(false)
	else:
		is_open = false
		last_was_whisper = false
		UiGate.set_story(false)


func _finish(completed: bool) -> void:
	is_open = false
	last_was_whisper = false
	_typing = false
	_pages = PackedStringArray()
	UiGate.set_story(false)
	if completed:
		dialogue_closed.emit()
	else:
		dialogue_cancelled.emit()
	dialogue_finished.emit(completed)


func rebuild_pages_for_metrics(width: float, max_lines: int, font_size: int, font: Font = null) -> void:
	page_max_width = maxf(40.0, width)
	page_max_lines = maxi(1, max_lines)
	page_font_size = maxi(8, font_size)
	if font != null:
		page_font = font
	if is_open and not _full_line.is_empty():
		_pages = _paginate(_full_line, page_max_width, page_max_lines, page_font_size, page_font)
		if _pages.is_empty():
			_pages = PackedStringArray([""])
		_page_index = mini(_page_index, _pages.size() - 1)
		_begin_page()


static func _paginate(text: String, max_width: float, max_lines: int, font_size: int, font_override: Font = null) -> PackedStringArray:
	var font: Font = font_override if font_override != null else ThemeDB.fallback_font
	var pages: PackedStringArray = []
	var paragraphs := text.split("\n", true)
	var cur_lines: PackedStringArray = []

	for para in paragraphs:
		var words: PackedStringArray = _split_words(para)
		var line := ""
		for w in words:
			var candidate := w if line.is_empty() else "%s %s" % [line, w]
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
				line = candidate
			else:
				if line != "":
					cur_lines.append(line)
					if cur_lines.size() >= max_lines:
						pages.append("\n".join(cur_lines))
						cur_lines = PackedStringArray()
				if font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
					for chunk in _break_long_word(w, max_width, font, font_size):
						cur_lines.append(chunk)
						if cur_lines.size() >= max_lines:
							pages.append("\n".join(cur_lines))
							cur_lines = PackedStringArray()
					line = ""
				else:
					line = w
		if line != "":
			cur_lines.append(line)
			if cur_lines.size() >= max_lines:
				pages.append("\n".join(cur_lines))
				cur_lines = PackedStringArray()
		if para.is_empty() and not cur_lines.is_empty():
			cur_lines.append("")
			if cur_lines.size() >= max_lines:
				pages.append("\n".join(cur_lines))
				cur_lines = PackedStringArray()

	if not cur_lines.is_empty():
		pages.append("\n".join(cur_lines))
	if pages.is_empty() and text.is_empty():
		pages.append("")
	return pages


static func _split_words(s: String) -> PackedStringArray:
	if s.is_empty():
		return PackedStringArray([""])
	return s.split(" ", false)


static func _break_long_word(word: String, max_width: float, font: Font, font_size: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var buf := ""
	for i in word.length():
		var ch := word.substr(i, 1)
		var cand := buf + ch
		if font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			buf = cand
		else:
			if buf != "":
				out.append(buf)
			buf = ch
	if buf != "":
		out.append(buf)
	return out


func pages_rejoin_equals_source(source: String, width: float, max_lines: int, font_size: int) -> bool:
	## Test yardımcısı: sayfalardan birleşen metin kaynakla eşit mi (satır sonu normalizasyonu).
	var pages := _paginate(source, width, max_lines, font_size, page_font)
	var rebuilt := "\n".join(pages)
	var norm_src := source.strip_edges()
	var norm_out := rebuilt.strip_edges()
	# Boşluk birleşimi sözcük kırılımında değişebilir; harf içeriğini karşılaştır.
	return _letters_only(norm_src) == _letters_only(norm_out)


static func _letters_only(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch := s.substr(i, 1)
		if ch != " " and ch != "\n" and ch != "\t":
			out += ch
	return out
