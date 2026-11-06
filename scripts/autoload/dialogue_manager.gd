extends Node
## Diyalog — Türkçe satırlar; fısıltı (whisper) erken gizem için.

signal line_shown(speaker: String, text: String)
signal dialogue_closed

var _queue: Array[Dictionary] = []
var is_open: bool = false
var last_was_whisper: bool = false


func say(speaker: String, text: String) -> void:
	_enqueue(speaker, text, false)


func whisper(speaker: String, text: String) -> void:
	## Fısıltı: aynı UI; konuşmacı ??? / Bekçi kalır, metin yumuşak.
	_enqueue(speaker, text, true)


func _enqueue(speaker: String, text: String, is_whisper: bool) -> void:
	_queue.append({"speaker": speaker, "text": text, "whisper": is_whisper})
	if not is_open:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		is_open = false
		last_was_whisper = false
		dialogue_closed.emit()
		return
	is_open = true
	var line: Dictionary = _queue.pop_front()
	last_was_whisper = bool(line.get("whisper", false))
	var speaker := String(line["speaker"])
	var text := String(line["text"])
	if last_was_whisper and speaker != "Bekçi":
		speaker = "???"
	line_shown.emit(speaker, text)
	# Headless smoke: satırları otomatik geç.
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(0.12).timeout.connect(advance, CONNECT_ONE_SHOT)


func advance() -> void:
	if not is_open:
		return
	_show_next()


func clear() -> void:
	_queue.clear()
	is_open = false
	last_was_whisper = false
