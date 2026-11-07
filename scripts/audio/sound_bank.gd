extends RefCounted
## Procedural recipes (no audio files). Consumed by synth_job.gd.
## SFX/stingers: 22.05 kHz mono. Region beds: 11.025 kHz mono loops (LOOP_T seconds).

const SFX_RATE := 22050
const BED_RATE := 8000
const LOOP_T := 12.0

const SFX_IDS: Array[StringName] = [
	&"footstep", &"ui_click", &"jump", &"land", &"sword_swing", &"sword_hit", &"hurt", &"dash",
	&"typewriter", &"seal_key", &"seal_open", &"curse_whisper", &"plate_press", &"door_open",
	&"corpse_drag", &"soul_slash", &"wall_crack", &"wall_break", &"keeper_claw", &"keeper_charge",
	&"echo_record", &"echo_playback", &"ui_open", &"ui_close", &"death_chord", &"rebirth_chord",
]
const STINGER_IDS: Array[StringName] = [&"discovery", &"ending_bad", &"ending_good", &"ending_sever"]
const REGIONS: Array[StringName] = [&"awakening", &"decay", &"library", &"experiment", &"mirrors", &"core"]


static func has_sound(id: StringName) -> bool:
	return SFX_IDS.has(id) or STINGER_IDS.has(id)


static func is_region(region: StringName) -> bool:
	return REGIONS.has(region)


# --- op helpers ----------------------------------------------------------

static func _t(at: float, dur: float, f: float, a: float, k: String = "sine", f2: float = -1.0, extra: Dictionary = {}) -> Dictionary:
	var d := {"t": "tone", "at": at, "dur": dur, "f": f, "a": a, "k": k}
	if f2 > 0.0:
		d["f2"] = f2
	d.merge(extra, true)
	return d


static func _n(at: float, dur: float, a: float, lp: float, env: String = "exp", dec: float = 0.05, extra: Dictionary = {}) -> Dictionary:
	var d := {"t": "noise", "at": at, "dur": dur, "a": a, "lp": lp, "env": env, "dec": dec}
	d.merge(extra, true)
	return d


static func _snap(f: float) -> float:
	return roundf(f * LOOP_T) / LOOP_T


static func _r(dur: float, ops: Array, peak: float = 0.8) -> Dictionary:
	# long, tonal sounds are rendered at 16 kHz (cheaper; content is dark anyway)
	var rate := SFX_RATE if dur < 1.5 else 16000
	return {"rate": rate, "dur": dur, "loop": false, "peak": peak, "ops": ops}


# --- SFX / stingers ------------------------------------------------------

static func recipe(id: StringName) -> Dictionary:
	match id:
		&"footstep":
			return _r(0.14, [_n(0, 0.12, 0.9, 0.18, "exp", 0.025), _t(0, 0.12, 95, 0.8, "thump", 62, {"tau": 0.03})], 0.5)
		&"ui_click":
			return _r(0.07, [_t(0, 0.06, 1100, 0.7, "sine"), _n(0, 0.02, 0.4, 0.6, "exp", 0.004)], 0.45)
		&"jump":
			return _r(0.2, [_t(0, 0.18, 200, 0.7, "sine", 420), _n(0, 0.18, 0.4, 0.3, "hump", 0.1, {"hp": 0.05})], 0.5)
		&"land":
			return _r(0.22, [_t(0, 0.2, 90, 0.9, "thump", 52, {"tau": 0.04}), _n(0, 0.15, 0.7, 0.12, "exp", 0.04)], 0.6)
		&"dash":
			return _r(0.3, [_n(0, 0.28, 1.0, 0.45, "hump", 0.1, {"hp": 0.08}), _t(0, 0.28, 700, 0.15, "sine", 280)], 0.55)
		&"sword_swing":
			return _r(0.32, [_n(0, 0.3, 1.0, 0.55, "hump", 0.1, {"hp": 0.12}), _t(0, 0.3, 900, 0.18, "sine", 350)], 0.55)
		&"sword_hit":
			return _r(0.4, [_n(0, 0.08, 1.0, 0.7, "exp", 0.012), _t(0, 0.35, 880, 0.45, "bell"), _t(0, 0.2, 130, 0.8, "thump", 70, {"tau": 0.03})], 0.8)
		&"hurt":
			return _r(0.45, [_t(0, 0.4, 320, 0.7, "sine", 110), _t(0, 0.4, 340, 0.4, "sine", 125), _n(0, 0.12, 0.6, 0.4, "exp", 0.03)], 0.7)
		&"seal_key":
			return _r(0.08, [_t(0, 0.07, 1500, 0.6, "sine"), _n(0, 0.015, 0.5, 0.8, "exp", 0.003)], 0.4)
		&"seal_open":
			return _r(1.6, [
				_t(0.0, 1.0, 440, 0.7, "bell"), _t(0.14, 1.0, 523.25, 0.6, "bell"),
				_t(0.28, 1.1, 659.25, 0.6, "bell"), _t(0.42, 1.2, 880, 0.55, "bell"),
				_t(0.0, 1.4, 55, 0.8, "thump", 55, {"tau": 0.01}), _n(0, 0.4, 0.3, 0.1, "hump", 0.1),
			], 0.75)
		&"typewriter":
			return _r(0.05, [_n(0, 0.03, 0.9, 0.5, "exp", 0.006), _t(0, 0.03, 2100, 0.25, "sine")], 0.3)
		&"curse_whisper":
			return _r(1.3, [
				_n(0, 1.3, 1.0, 0.35, "hump", 0.1, {"hp": 0.1, "lfo_k": 7.0, "lfo_d": 0.7}),
				_t(0, 1.3, 700, 0.1, "pad", 900), _t(0, 1.3, 1100, 0.06, "pad", 800),
			], 0.5)
		&"death_chord":
			return _r(3.0, [
				_t(0.0, 2.9, 110.0, 0.8, "padd"), _t(0.0, 2.9, 130.81, 0.6, "padd"),
				_t(0.0, 2.9, 164.81, 0.5, "padd"), _t(0.05, 2.8, 233.08, 0.35, "padd"),
				_t(0.0, 0.6, 140, 1.0, "thump", 40, {"tau": 0.15}), _n(0, 1.4, 0.3, 0.05, "exp", 0.5),
			], 0.85)
		&"rebirth_chord":
			return _r(3.0, [
				_t(0.0, 2.8, 110.0, 0.5, "pad"), _t(0.3, 2.6, 220.0, 0.5, "pad"),
				_t(0.5, 2.4, 261.63, 0.5, "pad"), _t(0.7, 2.2, 329.63, 0.45, "pad"),
				_t(0.9, 2.0, 440.0, 0.4, "bell"), _t(1.1, 1.8, 659.25, 0.3, "bell"),
			], 0.7)
		&"corpse_drag":
			return _r(0.55, [_n(0, 0.5, 1.0, 0.06, "hump", 0.1, {"hp": 0.02, "lfo_k": 5.0, "lfo_d": 0.6}), _t(0, 0.5, 70, 0.4, "pad")], 0.55)
		&"soul_slash":
			return _r(0.6, [
				_n(0, 0.5, 0.9, 0.6, "hump", 0.1, {"hp": 0.1}), _t(0, 0.5, 1300, 0.3, "sine", 220),
				_t(0.05, 0.55, 990, 0.3, "bell"), _t(0, 0.45, 600, 0.12, "pad", 900),
			], 0.7)
		&"wall_crack":
			return _r(0.4, [
				_n(0.0, 0.03, 1.0, 0.7, "exp", 0.006), _n(0.07, 0.03, 0.8, 0.6, "exp", 0.006),
				_n(0.15, 0.05, 0.9, 0.5, "exp", 0.01), _t(0, 0.3, 160, 0.6, "thump", 90, {"tau": 0.05}),
			], 0.65)
		&"wall_break":
			return _r(1.1, [
				_n(0, 0.9, 1.0, 0.2, "exp", 0.25), _t(0, 0.8, 80, 1.0, "thump", 38, {"tau": 0.12}),
				_n(0.12, 0.03, 0.7, 0.7, "exp", 0.008), _n(0.3, 0.03, 0.6, 0.7, "exp", 0.008),
				_n(0.5, 0.04, 0.5, 0.6, "exp", 0.01), _n(0.7, 0.04, 0.4, 0.6, "exp", 0.01),
			], 0.9)
		&"keeper_claw":
			return _r(0.45, [
				_n(0, 0.35, 1.0, 0.7, "hump", 0.1, {"hp": 0.2}), _t(0, 0.4, 900, 0.35, "sine", 380),
				_t(0, 0.4, 957, 0.3, "sine", 410), _t(0.2, 0.2, 100, 0.6, "thump", 60, {"tau": 0.04}),
			], 0.75)
		&"keeper_charge":
			return _r(1.0, [
				_t(0, 0.95, 70, 0.8, "sine", 320), _t(0, 0.95, 75, 0.5, "sine", 345),
				_n(0, 0.95, 0.8, 0.25, "rise", 0.1, {"hp": 0.04}),
			], 0.75)
		&"door_open":
			return _r(0.9, [
				_t(0, 0.7, 150, 0.4, "pad", 230, {"lfo_k": 9.0, "lfo_d": 0.5}),
				_n(0, 0.7, 0.7, 0.05, "hump", 0.1, {"lfo_k": 11.0, "lfo_d": 0.6}),
				_t(0.72, 0.18, 85, 0.9, "thump", 48, {"tau": 0.04}),
			], 0.65)
		&"echo_record":
			return _r(0.6, [_t(0, 0.5, 500, 0.6, "sine", 950), _t(0.15, 0.45, 1320, 0.45, "bell"), _n(0, 0.4, 0.15, 0.3, "hump", 0.1)], 0.55)
		&"echo_playback":
			return _r(0.6, [_t(0, 0.5, 950, 0.6, "sine", 500), _t(0.1, 0.45, 880, 0.45, "bell"), _n(0, 0.4, 0.15, 0.3, "hump", 0.1)], 0.55)
		&"plate_press":
			return _r(0.3, [_t(0, 0.25, 110, 0.9, "thump", 60, {"tau": 0.04}), _n(0, 0.04, 0.8, 0.5, "exp", 0.008), _t(0, 0.25, 540, 0.2, "bell")], 0.65)
		&"ui_open":
			return _r(0.35, [_t(0, 0.3, 659.25, 0.6, "bell"), _t(0.07, 0.28, 880, 0.5, "bell")], 0.45)
		&"ui_close":
			return _r(0.35, [_t(0, 0.3, 880, 0.55, "bell"), _t(0.07, 0.28, 659.25, 0.5, "bell")], 0.45)
		&"discovery":
			return _r(2.0, [
				_t(0.0, 1.5, 659.25, 0.7, "bell"), _t(0.22, 1.6, 987.77, 0.55, "bell"),
				_t(0.5, 1.5, 1318.5, 0.35, "bell"), _t(0.0, 1.8, 110, 0.3, "pad"),
			], 0.6)
		&"ending_bad":
			return _r(5.0, [
				_t(0.0, 1.8, 440, 0.6, "piano"), _t(0.8, 1.8, 349.23, 0.6, "piano"),
				_t(1.6, 2.0, 329.63, 0.6, "piano"), _t(2.5, 2.4, 220, 0.7, "piano"),
				_t(0.0, 4.9, 55, 0.8, "padd"), _t(0.0, 4.8, 65.4, 0.6, "padd"), _t(1.0, 3.9, 77.8, 0.4, "padd"),
				_t(2.5, 2.5, 110, 0.4, "bell"),
			], 0.8)
		&"ending_good":
			return _r(5.0, [
				_t(0.0, 1.8, 220, 0.6, "piano"), _t(0.5, 1.8, 277.18, 0.55, "piano"),
				_t(1.0, 1.8, 329.63, 0.55, "piano"), _t(1.5, 2.2, 440, 0.6, "piano"),
				_t(2.2, 2.6, 554.37, 0.5, "piano"), _t(2.9, 2.0, 659.25, 0.5, "bell"),
				_t(0.0, 4.8, 110, 0.5, "pad"), _t(1.0, 3.8, 164.81, 0.35, "pad"),
			], 0.75)
		&"ending_sever":
			return _r(5.0, [
				_t(0.0, 4.8, 55, 0.8, "padd"), _t(0.0, 3.0, 58.3, 0.6, "padd"),
				_t(0.4, 2.0, 466.16, 0.45, "bell"), _t(1.1, 2.4, 311.13, 0.45, "bell"),
				_t(2.2, 2.6, 233.08, 0.4, "bell"),
				_n(0.0, 0.05, 1.0, 0.7, "exp", 0.01), _n(2.8, 0.05, 0.7, 0.7, "exp", 0.01),
				_t(0.0, 0.7, 120, 1.0, "thump", 36, {"tau": 0.2}),
			], 0.85)
		_:
			return {}


# --- region beds ---------------------------------------------------------

static func _bed(ops: Array, peak: float) -> Dictionary:
	return {"rate": BED_RATE, "dur": LOOP_T, "loop": true, "peak": peak, "ops": ops}


static func _drone(f: float, a: float, lfo_k: float = 1.0, ph: float = 0.0) -> Dictionary:
	return _t(0.0, LOOP_T, _snap(f), a, "drone", -1.0, {"lfo_k": lfo_k, "lfo_d": 0.35, "lfo_ph": ph})


static func _wind(a: float, lp: float, lfo_k: float, ph: float = 0.0, hp: float = 0.01) -> Dictionary:
	return _n(0.0, LOOP_T, a, lp, "flat", 0.1, {"wrap": true, "hp": hp, "lfo_k": lfo_k, "lfo_d": 0.7, "lfo_ph": ph})


## kind: &"music" or &"amb"
static func bed_recipe(region: StringName, kind: StringName) -> Dictionary:
	var m := kind == &"music"
	match region:
		&"awakening":
			if m:
				return _bed([
					_drone(55, 0.8, 1, 0.0), _drone(82.5, 0.4, 2, 1.0),
					_t(1.0, 4.0, 440.0, 0.5, "bell"), _t(5.2, 4.0, 523.25, 0.45, "bell"),
					_t(8.6, 3.6, 329.63, 0.5, "piano"), _t(10.0, 2.0, 493.88, 0.3, "bell"),
				], 0.55)
			return _bed([_wind(1.0, 0.04, 2, 0.0, 0.004), _wind(0.5, 0.12, 3, 2.0, 0.02)], 0.5)
		&"decay":
			if m:
				return _bed([
					_drone(36.7, 0.9, 1), _drone(55.0, 0.4, 2, 2.0),
					_t(0.5, 3.5, 146.83, 0.55, "piano"), _t(3.6, 3.5, 174.61, 0.5, "piano"),
					_t(6.6, 3.5, 220.0, 0.5, "piano"), _t(9.4, 2.6, 293.66, 0.45, "piano"),
				], 0.55)
			var ops: Array = [_wind(0.35, 0.02, 1, 0.0, 0.0)]
			for dp in [[0.8, 1500.0, 0.8], [3.1, 1250.0, 0.6], [4.4, 1650.0, 0.5], [7.3, 1400.0, 0.9], [9.9, 1200.0, 0.55]]:
				ops.append(_t(dp[0], 0.18, dp[1], dp[2], "sine", dp[1] * 0.45))
			return _bed(ops, 0.5)
		&"library":
			if m:
				return _bed([
					_drone(43.65, 0.7, 1), _drone(65.4, 0.45, 2, 1.0),
					_t(0.0, 3.4, 174.61, 0.55, "piano"), _t(3.0, 3.4, 207.65, 0.5, "piano"),
					_t(6.0, 3.4, 261.63, 0.5, "piano"), _t(9.0, 3.0, 207.65, 0.45, "piano"),
				], 0.5)
			var ops2: Array = [_wind(0.12, 0.03, 1, 0.0, 0.0)]
			for i in 12:
				var tick := (i % 2) == 0
				ops2.append(_n(float(i), 0.03, 0.9, 0.7, "exp", 0.006))
				ops2.append(_t(float(i), 0.1, 1900.0 if tick else 1350.0, 0.6, "sine"))
			return _bed(ops2, 0.45)
		&"experiment":
			if m:
				return _bed([
					_drone(38.9, 0.8, 1), _drone(41.2, 0.6, 3, 1.0),
					_t(2.0, 3.0, 311.13, 0.4, "pad"), _t(7.0, 3.5, 329.63, 0.4, "pad"),
				], 0.5)
			return _bed([
				_t(0.0, LOOP_T, _snap(50), 0.8, "drone", -1.0, {"lfo_k": 2.0, "lfo_d": 0.3}),
				_t(0.0, LOOP_T, _snap(150), 0.3, "sine", -1.0, {"k": "drone"}),
				_n(1.3, 0.05, 0.8, 0.6, "exp", 0.01), _n(1.4, 0.03, 0.6, 0.7, "exp", 0.006),
				_n(5.2, 0.06, 0.8, 0.6, "exp", 0.012), _n(5.35, 0.04, 0.7, 0.7, "exp", 0.008),
				_n(9.1, 0.05, 0.8, 0.6, "exp", 0.01),
				_t(3.8, 2.5, 612.0, 0.22, "bell"), _t(8.4, 3.0, 431.0, 0.2, "bell"),
			], 0.5)
		&"mirrors":
			if m:
				return _bed([
					_t(0.0, 6.0, 880.0, 0.5, "glass"), _t(4.0, 6.0, 1318.5, 0.4, "glass"),
					_t(8.0, 6.0, 1046.5, 0.45, "glass"), _t(2.0, 6.0, 659.25, 0.4, "glass"),
					_t(6.0, 6.0, 783.99, 0.4, "glass"), _drone(110, 0.4, 1),
				], 0.5)
			return _bed([
				_wind(0.5, 0.35, 3, 0.0, 0.2), _wind(0.3, 0.5, 5, 1.5, 0.3),
				_t(1.5, 3.0, 2093.0, 0.1, "bell"), _t(7.0, 3.0, 2637.0, 0.1, "bell"),
			], 0.4)
		&"core":
			if m:
				var ops3: Array = [_drone(41.2, 0.9, 1), _drone(61.7, 0.5, 2, 1.0)]
				for i in 10:
					var b := float(i) * 1.2
					ops3.append(_t(b, 0.4, 62, 1.0, "thump", 38, {"tau": 0.05}))
					ops3.append(_t(b + 0.24, 0.35, 55, 0.7, "thump", 34, {"tau": 0.05}))
				return _bed(ops3, 0.7)
			return _bed([_wind(1.0, 0.015, 1, 0.0, 0.0), _wind(0.25, 0.15, 4, 1.0, 0.05)], 0.4)
		_:
			return {}


## Looping hiss/whisper layer whose volume follows curse.
static func curse_bed_recipe() -> Dictionary:
	return {"rate": BED_RATE, "dur": 6.0, "loop": true, "peak": 0.5, "ops": [
		_n(0.0, 6.0, 1.0, 0.4, "flat", 0.1, {"wrap": true, "hp": 0.12, "lfo_k": 9.0, "lfo_d": 0.8}),
		_n(0.0, 6.0, 0.4, 0.15, "flat", 0.1, {"wrap": true, "hp": 0.03, "lfo_k": 3.0, "lfo_d": 0.7, "lfo_ph": 1.0}),
	]}
