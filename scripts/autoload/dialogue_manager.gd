extends Node
## Diyalog stub — Türkçe satırlar.

signal line_shown(speaker: String, text: String)
signal dialogue_closed

var _queue: Array[Dictionary] = []
var is_open: bool = false


func say(speaker: String, text: String) -> void:
	_queue.append({"speaker": speaker, "text": text})
	if not is_open:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		is_open = false
		dialogue_closed.emit()
		return
	is_open = true
	var line: Dictionary = _queue.pop_front()
	line_shown.emit(String(line["speaker"]), String(line["text"]))


func advance() -> void:
	if not is_open:
		return
	_show_next()
