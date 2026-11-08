extends Node
## Procedural audio (no files): SFX pool, region ambience/music beds, curse hiss, stingers.
## Synthesis runs on one low-priority worker thread (scripts/audio/synth_job.gd), so boot never
## stalls; sounds requested before they are ready are rendered synchronously. No-op in headless/test.

const SynthJob := preload("res://scripts/audio/synth_job.gd")
const SoundBank := preload("res://scripts/audio/sound_bank.gd")

const VOICES := 8
const XFADE_SEC := 1.5
const MUSIC_DB := -9.0
const AMB_DB := -7.0
const FOOT_INTERVAL := 0.28
const TYPE_INTERVAL := 0.045

var _enabled: bool = false
var _streams: Dictionary = {}
var _queue: Array = [] ## of [key: String, kind: StringName, id: StringName]; guarded by _mutex
var _done: Array = [] ## of [key, stream, usec]; guarded by _mutex
var _mutex: Mutex = Mutex.new()
var _sem: Semaphore = Semaphore.new()
var _thread: Thread
var _exit: bool = false
var _busy_key: String = ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _last_play_ms: Dictionary = {}
var _stinger_player: AudioStreamPlayer
var _region: StringName = &""
var _chan: Dictionary = {} ## "music"/"amb" -> {players, cur, tween}
var _curse_player: AudioStreamPlayer
var _curse_db: float = -80.0
var _curse_target_db: float = -80.0
var _curse_value: float = 0.0
var _master_linear: float = 1.0
var _music_on: bool = true
var _boot_delay: int = 3
var _player_node: CharacterBody2D
var _player_poll: float = 0.0
var _foot_t: float = 0.0
var _foot_alt: bool = false
var _anim_step_ms: int = -10000 ## Son animasyon-senkron adım; varken zamanlayıcı susar (çift ses yok).
var _typing: bool = false
var _type_t: float = 0.0
var _type_age: float = 0.0
var _type_speaker: String = ""
var _blips: Dictionary = {} ## speaker key -> AudioStreamWAV (prosedürel diyalog blip'i)
var _gen_log: Dictionary = {} ## key -> usec (debug)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = not _is_headless_or_test()
	if not _enabled:
		set_process(false)
		return
	_setup_buses()
	_setup_players()
	_connect_hooks()
	_enqueue_boot()
	_thread = Thread.new()
	_thread.start(_worker, Thread.PRIORITY_LOW)


func _exit_tree() -> void:
	if _enabled:
		for c in get_children():
			if c is AudioStreamPlayer:
				(c as AudioStreamPlayer).stop()
				(c as AudioStreamPlayer).stream = null
		_streams.clear()
		for bname in ["Music", "SFX", "Ambience"]:
			var bi := AudioServer.get_bus_index(bname)
			while bi >= 0 and AudioServer.get_bus_effect_count(bi) > 0:
				AudioServer.remove_bus_effect(bi, 0)
	if _thread != null and _thread.is_started():
		_mutex.lock()
		_exit = true
		_mutex.unlock()
		_sem.post()
		_thread.wait_to_finish()


func _is_headless_or_test() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if OS.get_environment("TORIMON_SMOKE") == "1" or OS.get_environment("TORIMON_TEST") == "1":
		return true
	return false


# --- public API ----------------------------------------------------------

func play_sfx(id: StringName, volume_db: float = 0.0, pitch: float = -1.0) -> void:
	if not _enabled:
		return
	var s := _get_sound(id)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(id, -1000)) < 25:
		return
	_last_play_ms[id] = now
	var p := _free_sfx_player()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch if pitch > 0.0 else randf_range(0.95, 1.05)
	p.play()


func set_region(region: StringName) -> void:
	if not _enabled or region == _region or not SoundBank.is_region(region):
		return
	_region = region
	for kind in [&"music", &"amb"]:
		var key := "%s:%s" % [kind, region]
		if _streams.has(key):
			_crossfade(kind, _streams[key])
		else:
			_prioritize(key, kind, region)


func play_region_ambient(region: StringName) -> void:
	set_region(region)


func play_ambient(region: StringName) -> void:
	play_region_ambient(region)


func start_ambient(region: StringName = &"awakening") -> void:
	play_region_ambient(region)


func play_title_ambience() -> void:
	start_ambient(&"awakening")


func set_master_volume(linear: float) -> void:
	_master_linear = clampf(linear, 0.0, 1.0)
	if not _enabled:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_master_linear, 0.0001)))
	AudioServer.set_bus_mute(0, _master_linear <= 0.0001)


func set_music_enabled(enabled: bool) -> void:
	_music_on = enabled
	if not _enabled:
		return
	var i := AudioServer.get_bus_index("Music")
	if i >= 0:
		AudioServer.set_bus_mute(i, not enabled)


func stinger(id: StringName) -> void:
	if not _enabled or not SoundBank.STINGER_IDS.has(id):
		return
	var s := _get_sound(id)
	if s == null:
		return
	_stinger_player.stream = s
	_stinger_player.volume_db = -2.0
	_stinger_player.pitch_scale = 1.0
	_stinger_player.play()


## Debug: synchronously render every SFX/stinger/bed; returns {key: usec}.
func debug_generate_all() -> Dictionary:
	var out := {}
	var ids: Array = []
	ids.append_array(SoundBank.SFX_IDS)
	ids.append_array(SoundBank.STINGER_IDS)
	for id in ids:
		var t0 := Time.get_ticks_usec()
		var j := SynthJob.new()
		j.setup(id, SoundBank.recipe(id))
		j.step(1 << 40)
		out[String(id)] = Time.get_ticks_usec() - t0
	for r in SoundBank.REGIONS:
		for kind in [&"music", &"amb"]:
			var t1 := Time.get_ticks_usec()
			var j2 := SynthJob.new()
			j2.setup(r, SoundBank.bed_recipe(r, kind))
			j2.step(1 << 40)
			out["%s:%s" % [kind, r]] = Time.get_ticks_usec() - t1
	var t2 := Time.get_ticks_usec()
	var j3 := SynthJob.new()
	j3.setup(&"curse", SoundBank.curse_bed_recipe())
	j3.step(1 << 40)
	out["curse_bed"] = Time.get_ticks_usec() - t2
	return out


# --- setup ---------------------------------------------------------------

func _setup_buses() -> void:
	for bname in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bname) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, "Master")
			# Consolidate reverb: attach reverb only to Ambience bus to reduce processing overhead
			if bname == "Ambience":
				var rv := AudioEffectReverb.new()
				rv.room_size = 0.75
				rv.damping = 0.6
				rv.wet = 0.25
				rv.dry = 1.0
				AudioServer.add_bus_effect(idx, rv)
	set_music_enabled(_music_on)
	set_master_volume(_master_linear)


func _setup_players() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = "Music"
	add_child(_stinger_player)
	for kind in [&"music", &"amb"]:
		var ps: Array[AudioStreamPlayer] = []
		for i in 2:
			var p2 := AudioStreamPlayer.new()
			p2.bus = "Music" if kind == &"music" else "Ambience"
			p2.volume_db = -80.0
			add_child(p2)
			ps.append(p2)
		_chan[kind] = {"players": ps, "cur": -1, "tween": null}
	_curse_player = AudioStreamPlayer.new()
	_curse_player.bus = "Ambience"
	_curse_player.volume_db = -80.0
	add_child(_curse_player)


func _connect_hooks() -> void:
	GameState.room_changed.connect(_on_room_changed)
	DialogueManager.page_shown.connect(_on_page_shown)
	DialogueManager.typing_finished.connect(_on_typing_finished)
	DeathManager.death_started.connect(func(_r: StringName) -> void: play_sfx(&"death_chord"))
	DeathManager.rebirth_completed.connect(func() -> void: play_sfx(&"rebirth_chord"))
	CurseManager.curse_whisper.connect(func(_t: String) -> void: play_sfx(&"curse_whisper", -4.0))
	CurseManager.curse_changed.connect(_on_curse_changed)
	EndingManager.ending_reached.connect(_on_ending)
	PuzzleManager.puzzle_solved.connect(func(_p: StringName) -> void: stinger(&"discovery"))


func _enqueue_boot() -> void:
	# Hot SFX first, then the rest, stingers, then idle pre-warm of other region beds.
	var hot: Array[StringName] = [&"footstep", &"ui_click", &"jump", &"land", &"sword_swing", &"sword_hit", &"typewriter"]
	for id in hot:
		_queue.append([String(id), &"sfx", id])
	for r in [&"awakening"]:
		_queue.push_front(["amb:%s" % r, &"amb", r])
		_queue.push_front(["music:%s" % r, &"music", r])
	for id in SoundBank.SFX_IDS:
		if not hot.has(id):
			_queue.append([String(id), &"sfx", id])
	for id in SoundBank.STINGER_IDS:
		_queue.append([String(id), &"sfx", id])
	for r in SoundBank.REGIONS:
		if r != &"awakening":
			_queue.append(["music:%s" % r, &"music", r])
			_queue.append(["amb:%s" % r, &"amb", r])
	_sem.post()


# --- synthesis scheduling ------------------------------------------------

func _recipe_for(entry: Array) -> Dictionary:
	var kind: StringName = entry[1]
	if kind == &"sfx":
		return SoundBank.recipe(entry[2])
	if kind == &"curse":
		return SoundBank.curse_bed_recipe()
	return SoundBank.bed_recipe(entry[2], kind)


func _worker() -> void:
	while true:
		_sem.wait()
		while true:
			_mutex.lock()
			if _exit:
				_mutex.unlock()
				return
			if _queue.is_empty():
				_busy_key = ""
				_mutex.unlock()
				break
			var e: Array = _queue.pop_front()
			_busy_key = e[0]
			_mutex.unlock()
			var recipe := _recipe_for(e)
			if recipe.is_empty():
				continue
			var j := SynthJob.new()
			j.setup(StringName(e[0]), recipe)
			j.step(1 << 40)
			_mutex.lock()
			_done.append([e[0], j.stream, j.total_usec()])
			_mutex.unlock()


func _prioritize(key: String, kind: StringName, id: StringName) -> void:
	_mutex.lock()
	var found := false
	for i in _queue.size():
		if _queue[i][0] == key:
			var e: Array = _queue[i]
			_queue.remove_at(i)
			_queue.push_front(e)
			found = true
			break
	if not found and _busy_key != key and not _streams.has(key):
		_queue.push_front([key, kind, id])
	_mutex.unlock()
	_sem.post()


func _get_sound(id: StringName) -> AudioStream:
	var key := String(id)
	if _streams.has(key):
		return _streams[key]
	if not SoundBank.has_sound(id):
		return null
	# Synchronous fallback (requested before the worker got to it).
	_mutex.lock()
	for i in _queue.size():
		if _queue[i][0] == key:
			_queue.remove_at(i)
			break
	_mutex.unlock()
	var j := SynthJob.new()
	j.setup(id, SoundBank.recipe(id))
	j.step(1 << 40)
	_streams[key] = j.stream
	_gen_log[key] = j.total_usec()
	return j.stream


func _collect_done() -> void:
	_mutex.lock()
	var batch := _done
	_done = []
	_mutex.unlock()
	for r in batch:
		var key: String = r[0]
		if _streams.has(key):
			continue
		_streams[key] = r[1]
		_gen_log[key] = r[2]
		if key.begins_with("music:") or key.begins_with("amb:"):
			var kind: StringName = &"music" if key.begins_with("music:") else &"amb"
			if key == "%s:%s" % [kind, _region]:
				_crossfade(kind, _streams[key])


# --- playback helpers ----------------------------------------------------

func _free_sfx_player() -> AudioStreamPlayer:
	for i in VOICES:
		var p := _sfx_players[(_sfx_next + i) % VOICES]
		if not p.playing:
			_sfx_next = (_sfx_next + i + 1) % VOICES
			return p
	var q := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % VOICES
	return q


func _crossfade(kind: StringName, stream: AudioStream) -> void:
	var ch: Dictionary = _chan[kind]
	var ps: Array = ch["players"]
	var cur: int = ch["cur"]
	var nxt := 0 if cur != 0 else 1
	var tw: Tween = ch["tween"]
	if tw != null and tw.is_valid():
		tw.kill()
	var newp: AudioStreamPlayer = ps[nxt]
	newp.stop()
	newp.stream = stream
	newp.volume_db = -60.0
	newp.play()
	var target := MUSIC_DB if kind == &"music" else AMB_DB
	tw = create_tween().set_parallel(true)
	tw.tween_property(newp, "volume_db", target, XFADE_SEC)
	if cur >= 0:
		var oldp: AudioStreamPlayer = ps[cur]
		tw.tween_property(oldp, "volume_db", -60.0, XFADE_SEC)
		tw.chain().tween_callback(oldp.stop)
	ch["cur"] = nxt
	ch["tween"] = tw


# --- signal hooks --------------------------------------------------------

func _on_room_changed(room_id: StringName) -> void:
	var s := String(room_id)
	var cut := s.find("_")
	set_region(StringName(s if cut < 0 else s.substr(0, cut)))


func _on_page_shown(speaker: String, _text: String, _i: int, _n: int) -> void:
	_type_speaker = speaker
	if not _typing:
		_typing = true
		_type_t = 0.0
		_type_age = 0.0


func _on_typing_finished() -> void:
	_typing = false


func _on_curse_changed(value: float) -> void:
	_curse_value = value
	if value < 40.0:
		_curse_target_db = -80.0
	else:
		_curse_target_db = lerpf(-30.0, -11.0, clampf((value - 40.0) / 60.0, 0.0, 1.0))
	if value >= 30.0 and not _streams.has("curse"):
		_prioritize("curse", &"curse", &"curse")


func _on_ending(ending_id: StringName) -> void:
	var s := String(ending_id).to_lower()
	if s.contains("sever"):
		stinger(&"ending_sever")
	elif s.contains("good") or s.contains("true") or s.contains("free") or s.contains("release"):
		stinger(&"ending_good")
	else:
		stinger(&"ending_bad")


# --- per-frame -----------------------------------------------------------

func _process(delta: float) -> void:
	if _boot_delay > 0:
		_boot_delay -= 1
		return
	_collect_done()
	_update_curse_layer(delta)
	_update_typing(delta)
	_update_footsteps(delta)


func _update_curse_layer(delta: float) -> void:
	_curse_db = move_toward(_curse_db, _curse_target_db, 40.0 * delta)
	if _curse_db > -70.0 and _streams.has("curse"):
		if not _curse_player.playing:
			_curse_player.stream = _streams["curse"]
			_curse_player.play()
		_curse_player.volume_db = _curse_db
	elif _curse_player.playing:
		_curse_player.stop()


func _update_typing(delta: float) -> void:
	if not _typing:
		return
	_type_age += delta
	if _type_age > 8.0 or not DialogueManager.is_open:
		_typing = false
		return
	_type_t -= delta
	if _type_t <= 0.0:
		_type_t = TYPE_INTERVAL
		_play_blip(_type_speaker)


## Konuşmacıya göre kısa, yumuşak, düşük sesli harf blip'i (prosedürel; dosya yok).
func _blip_profile(speaker: String) -> Array:
	## [taban Hz, harmonik oranı, süre sn, glide]
	match speaker.strip_edges().to_lower():
		"noroi":
			return [520.0, 0.25, 0.045, 0.0]
		"shilda":
			return [340.0, 0.5, 0.06, -0.08]
		"arşivci", "arsivci":
			return [230.0, 0.15, 0.07, 0.0]
		"???":
			return [180.0, 0.7, 0.07, 0.12]
		_:
			return [400.0, 0.0, 0.035, 0.0] ## sistem / anlatıcı


func _make_blip(speaker: String) -> AudioStreamWAV:
	var prof := _blip_profile(speaker)
	var rate := 22050
	var n := int(float(prof[2]) * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var k := float(i) / float(n)
		var f: float = float(prof[0]) * (1.0 + float(prof[3]) * k)
		var env := minf(k * 12.0, 1.0) * pow(1.0 - k, 1.6)
		var v := sin(TAU * f * t) + float(prof[1]) * sin(TAU * f * 2.0 * t)
		data.encode_s16(i * 2, int(clampf(v * env * 0.45, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _play_blip(speaker: String) -> void:
	if not _enabled:
		return
	var key := speaker.strip_edges().to_lower()
	if not _blips.has(key):
		_blips[key] = _make_blip(speaker)
	var p := _free_sfx_player()
	p.stream = _blips[key]
	p.volume_db = -19.0
	p.pitch_scale = randf_range(0.94, 1.08)
	p.play()


## Koşu animasyonunun ayak-yere-değme karesinden çağrılır (görüntüyle senkron adım sesi).
func footstep_from_anim() -> void:
	if UiGate.blocks_movement() or DeathManager.is_dying:
		return
	_anim_step_ms = Time.get_ticks_msec()
	_foot_alt = not _foot_alt
	var base := 0.9 if _foot_alt else 0.97
	play_sfx(&"footstep", randf_range(-9.0, -6.5), base * randf_range(0.93, 1.07))


func _update_footsteps(delta: float) -> void:
	_player_poll -= delta
	if _player_poll <= 0.0 or not is_instance_valid(_player_node):
		_player_poll = 0.5
		_player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D
	var p := _player_node
	if p == null or not is_instance_valid(p) or not p.is_inside_tree() or not p.is_visible_in_tree():
		return
	## Kitap/diyalog/ölüm sırasında adım sesi yok.
	if UiGate.blocks_movement() or DeathManager.is_dying:
		_foot_t = minf(_foot_t, 0.06)
		return
	if Time.get_ticks_msec() - _anim_step_ms < 600:
		return ## Koşu animasyonu adımları kendisi tetikliyor.
	if absf(p.velocity.x) > 40.0 and p.is_on_floor():
		_foot_t -= delta
		if _foot_t <= 0.0:
			## Yumuşak taş: her adımda farklı perde/şiddet, sağ-sol adım hafif farklı.
			_foot_t = FOOT_INTERVAL * randf_range(0.92, 1.08)
			_foot_alt = not _foot_alt
			var base := 0.9 if _foot_alt else 0.97
			play_sfx(&"footstep", randf_range(-9.0, -6.5), base * randf_range(0.93, 1.07))
	else:
		_foot_t = minf(_foot_t, 0.06)
