extends SceneTree
func _initialize():
	OS.set_environment('TORIMON_SMOKE','')
	OS.set_environment('TORIMON_FRESH','1')
	var main = load('res://scenes/main/main.tscn').instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	var rm = root.get_node('RoomManager')
	print('ROOM_COUNT_PROBE rooms_has_passage=', rm.has_room(&'awakening_passage'), ' garden=', rm.has_room(&'decay_garden'), ' lib=', rm.has_room(&'library_hall'))
	print('DIALOGUE_OPEN=', root.get_node('DialogueManager').is_open)
	quit(0)
