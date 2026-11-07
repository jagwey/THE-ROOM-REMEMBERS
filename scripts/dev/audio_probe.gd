extends SceneTree
## Non-headless probe: times procedural audio generation. Run windowed:
## godot --path . --audio-driver Dummy -s res://scripts/dev/audio_probe.gd

func _initialize() -> void:
	await process_frame
	await process_frame
	var am: Node = root.get_node_or_null("AudioManager")
	if am == null:
		print("AUDIO_PROBE no AudioManager")
		quit(1)
		return
	var t0 := Time.get_ticks_usec()
	var res: Dictionary = am.debug_generate_all()
	var total := Time.get_ticks_usec() - t0
	var sfx_total := 0
	var beds_total := 0
	for k in res:
		if String(k).contains(":"):
			beds_total += int(res[k])
		else:
			sfx_total += int(res[k])
		print("AUDIO_PROBE %s %.1f ms" % [k, float(res[k]) / 1000.0])
	print("AUDIO_PROBE sfx_total=%.0f ms beds_total=%.0f ms all=%.0f ms" % [sfx_total / 1000.0, beds_total / 1000.0, total / 1000.0])
	# exercise runtime API
	am.set_region(&"decay")
	am.play_sfx(&"seal_open")
	am.stinger(&"discovery")
	am.play_sfx(&"nope_unknown")
	am.set_master_volume(0.8)
	am.set_music_enabled(true)
	for i in 400:
		await process_frame
	print("AUDIO_PROBE runtime ok buses=%d streams_ready=%d" % [AudioServer.bus_count, (am.get("_streams") as Dictionary).size()])
	quit(0)
