extends Node
## Geçmiş Yankısı — ceset/iz üzerinde. FAZ 5'e kadar stub.

signal echo_started(echo_id: StringName)
signal echo_finished(echo_id: StringName)

var active_echo: StringName = &""


func play_echo(echo_id: StringName) -> void:
	if active_echo != &"":
		return
	active_echo = echo_id
	echo_started.emit(echo_id)
	var sites: Array = GameState.world_memory_state["echo_sites"]
	var key := String(echo_id)
	if not sites.has(key):
		sites.append(key)
	await get_tree().create_timer(0.5).timeout
	active_echo = &""
	echo_finished.emit(echo_id)
