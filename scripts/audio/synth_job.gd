extends RefCounted
## Chunked, time-sliced procedural synth. Renders a recipe (see sound_bank.gd)
## into a 16-bit mono AudioStreamWAV. Call step(budget_usec) until it returns true.

const CHUNK := 1024
const LOOP_FADE_SEC := 0.5

var id: StringName = &""
var rate: int = 22050
var n: int = 0
var loop: bool = false
var peak: float = 0.8
var stream: AudioStreamWAV = null
var done: bool = false

var _ops: Array = []
var _buf: PackedFloat32Array
var _bytes: PackedByteArray
var _phase: int = 0
var _op_i: int = 0
var _pos: int = 0
var _seed: int = 1
var _scale: float = 1.0
var _maxv: float = 0.0
var _total_us: int = 0


func setup(p_id: StringName, recipe: Dictionary) -> void:
	id = p_id
	rate = int(recipe.get("rate", 22050))
	n = maxi(64, int(float(recipe.get("dur", 0.2)) * float(rate)))
	loop = bool(recipe.get("loop", false))
	peak = float(recipe.get("peak", 0.8))
	_seed = absi(String(p_id).hash()) % 2147483647 + 7
	_buf = PackedFloat32Array()
	_buf.resize(n)
	_ops = (recipe.get("ops", []) as Array).duplicate(true)
	for op in _ops:
		_prep(op as Dictionary)


func total_usec() -> int:
	return _total_us


func step(budget_usec: int) -> bool:
	var t0 := Time.get_ticks_usec()
	while not done:
		match _phase:
			0:
				_step_ops()
			1:
				_step_peak()
			2:
				_step_convert()
		if Time.get_ticks_usec() - t0 >= budget_usec:
			break
	_total_us += Time.get_ticks_usec() - t0
	return done


# --- preparation ---------------------------------------------------------

func _prep(op: Dictionary) -> void:
	var t: String = op.get("t", "tone")
	var at: float = op.get("at", 0.0)
	var dur: float = op.get("dur", 0.1)
	op["_s0"] = int(at * float(rate))
	var cnt := maxi(1, int(dur * float(rate)))
	if t == "noise":
		op["_y"] = 0.0
		op["_h"] = 0.0
		var lp: float = clampf(op.get("lp", 0.5), 0.003, 1.0)
		op["lp"] = lp
		op["_g"] = sqrt((2.0 - lp) / lp) * 0.5
		if op.get("wrap", false):
			cnt += int(LOOP_FADE_SEC * float(rate))
		op["_nom"] = int(dur * float(rate))
	else:
		_prep_tone(op, dur)
	op["_cnt"] = cnt


func _prep_tone(op: Dictionary, dur: float) -> void:
	var kind: String = op.get("k", "sine")
	var base := 4.0 / maxf(dur, 0.02)
	var ratios := PackedFloat32Array([1.0])
	var amps := PackedFloat32Array([1.0])
	var decs := PackedFloat32Array([base * 0.75])
	var att := 0.003
	match kind:
		"bell":
			ratios = PackedFloat32Array([1.0, 2.76, 5.4, 8.93])
			amps = PackedFloat32Array([1.0, 0.55, 0.3, 0.14])
			decs = PackedFloat32Array([base * 0.8, base * 1.3, base * 2.0, base * 3.0])
			att = 0.002
		"piano":
			ratios = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
			amps = PackedFloat32Array([1.0, 0.5, 0.3, 0.16])
			decs = PackedFloat32Array([base * 0.7, base * 1.0, base * 1.5, base * 2.2])
			att = 0.006
		"pad":
			ratios = PackedFloat32Array([1.0, 2.003, 0.5])
			amps = PackedFloat32Array([1.0, 0.3, 0.45])
			decs = PackedFloat32Array([0.0, 0.0, 0.0])
			att = -1.0 # hump envelope
		"padd":
			ratios = PackedFloat32Array([1.0, 2.004, 0.5])
			amps = PackedFloat32Array([1.0, 0.3, 0.5])
			decs = PackedFloat32Array([base * 0.5, base * 0.7, base * 0.4])
			att = 0.18
		"thump":
			decs = PackedFloat32Array([base * 1.1])
			att = 0.002
		"drone":
			ratios = PackedFloat32Array([1.0, 2.0, 3.0])
			amps = PackedFloat32Array([1.0, 0.35, 0.14])
			decs = PackedFloat32Array([0.0, 0.0, 0.0])
			att = -2.0 # flat envelope, lfo only
		"glass":
			ratios = PackedFloat32Array([1.0, 1.5, 2.0, 3.01])
			amps = PackedFloat32Array([1.0, 0.4, 0.3, 0.15])
			decs = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			att = -1.0
		_:
			pass
	# drop partials that would alias (above ~0.42 * sample rate) -- also saves CPU
	var fmax := maxf(float(op.get("f", 440.0)), float(op.get("f2", 0.0))) * (1.0 if kind != "thump" else 1.0)
	var lim := 0.42 * float(rate)
	var r2 := PackedFloat32Array()
	var a2 := PackedFloat32Array()
	var d2 := PackedFloat32Array()
	for i in ratios.size():
		if i == 0 or fmax * ratios[i] < lim:
			r2.append(ratios[i])
			a2.append(amps[i])
			d2.append(decs[i])
	op["_r"] = r2
	op["_a"] = a2
	op["_d"] = d2
	op["_att"] = att


# --- phase 0: ops --------------------------------------------------------

func _step_ops() -> void:
	if _op_i >= _ops.size():
		_phase = 1
		_pos = 0
		return
	var op: Dictionary = _ops[_op_i]
	var cnt: int = op["_cnt"]
	if _pos >= cnt:
		_op_i += 1
		_pos = 0
		return
	var i1 := mini(_pos + CHUNK, cnt)
	if String(op.get("t", "tone")) == "noise":
		_run_noise(op, _pos, i1)
	else:
		_run_tone(op, _pos, i1)
	_pos = i1


func _run_tone(op: Dictionary, i0: int, i1: int) -> void:
	var f: float = op.get("f", 440.0)
	var f2: float = op.get("f2", f)
	var amp: float = op.get("a", 0.5)
	var dur: float = op.get("dur", 0.1)
	var s0: int = op["_s0"]
	var ratios: PackedFloat32Array = op["_r"]
	var amps: PackedFloat32Array = op["_a"]
	var decs: PackedFloat32Array = op["_d"]
	var att: float = op["_att"]
	var kind: String = op.get("k", "sine")
	var np := ratios.size()
	var inv := 1.0 / float(rate)
	var tau_g: float = op.get("tau", 0.05)
	var lfo_k: float = op.get("lfo_k", 0.0)
	var lfo_d: float = op.get("lfo_d", 0.0)
	var lfo_ph: float = op.get("lfo_ph", 0.0)
	var t0 := float(i0) * inv
	var env: Array[float] = []
	var stp: Array[float] = []
	for p in np:
		env.append(exp(-t0 * decs[p]))
		stp.append(exp(-decs[p] * inv))
	var glide := absf(f2 - f) > 0.001
	for k in range(i0, i1):
		var gi := s0 + k
		if gi >= n:
			if loop:
				gi = gi % n
			else:
				break
		var t := float(k) * inv
		var ph: float
		if kind == "thump":
			ph = TAU * (f2 * t + (f - f2) * tau_g * (1.0 - exp(-t / tau_g)))
		elif glide:
			ph = TAU * (f * t + (f2 - f) * t * t / (2.0 * dur))
		else:
			ph = TAU * f * t
		var v := 0.0
		for p in np:
			v += amps[p] * env[p] * sin(ph * ratios[p])
			env[p] *= stp[p]
		var e := 1.0
		if att > 0.0:
			e = minf(t / att, 1.0)
			# short release so non-loop tones never click at their end
			var rem := dur - t
			if rem < 0.01:
				e *= maxf(rem, 0.0) * 100.0
		elif att == -1.0:
			var x := sin(PI * clampf(t / dur, 0.0, 1.0))
			e = x * x
		if lfo_d > 0.0:
			e *= (1.0 - lfo_d) + lfo_d * (0.5 + 0.5 * sin(TAU * lfo_k * t / dur + lfo_ph))
		_buf[gi] += v * e * amp


func _run_noise(op: Dictionary, i0: int, i1: int) -> void:
	var amp: float = op.get("a", 0.5)
	var lp: float = op["lp"]
	var hpc: float = op.get("hp", 0.0)
	var g: float = op["_g"]
	var envk: String = op.get("env", "exp")
	var dec: float = maxf(op.get("dec", 0.05), 0.001)
	var s0: int = op["_s0"]
	var nom: int = op["_nom"]
	var wrap: bool = op.get("wrap", false)
	var fade := int(LOOP_FADE_SEC * float(rate))
	var lfo_k: float = op.get("lfo_k", 0.0)
	var lfo_d: float = op.get("lfo_d", 0.0)
	var lfo_ph: float = op.get("lfo_ph", 0.0)
	var y: float = op["_y"]
	var h: float = op["_h"]
	var inv := 1.0 / float(rate)
	var seed_v := _seed
	for k in range(i0, i1):
		var gi := s0 + k
		if gi >= n:
			if loop:
				gi = gi % n
			else:
				break
		seed_v = (seed_v * 1664525 + 1013904223) & 0xFFFFFFFF
		var x := float(seed_v >> 8) / 8388608.0 - 1.0
		y += lp * (x - y)
		var s := y
		if hpc > 0.0:
			h += hpc * (y - h)
			s = y - h
		s *= g
		var frac := float(k) / float(nom)
		var e := 1.0
		match envk:
			"exp":
				e = exp(-float(k) * inv / dec)
			"hump":
				e = sin(PI * clampf(frac, 0.0, 1.0))
			"rise":
				e = frac * frac
			"fall":
				e = (1.0 - clampf(frac, 0.0, 1.0))
			_:
				pass
		if envk != "exp" and not wrap:
			# tiny fades to avoid clicks
			if k < 32:
				e *= float(k) / 32.0
			elif nom - k < 64:
				e *= clampf(float(nom - k) / 64.0, 0.0, 1.0)
		if wrap:
			if k < fade:
				e *= sqrt(float(k) / float(fade))
			elif k >= nom:
				e *= sqrt(clampf(float(nom + fade - k) / float(fade), 0.0, 1.0))
		if lfo_d > 0.0:
			e *= (1.0 - lfo_d) + lfo_d * (0.5 + 0.5 * sin(TAU * lfo_k * frac + lfo_ph))
		_buf[gi] += s * e * amp
	_seed = seed_v
	op["_y"] = y
	op["_h"] = h


# --- phase 1/2 -----------------------------------------------------------

func _step_peak() -> void:
	var i1 := mini(_pos + CHUNK * 8, n)
	for i in range(_pos, i1):
		var a := absf(_buf[i])
		if a > _maxv:
			_maxv = a
	_pos = i1
	if _pos >= n:
		_scale = peak / _maxv if _maxv > 0.0001 else 1.0
		_phase = 2
		_pos = 0
		_bytes = PackedByteArray()
		_bytes.resize(n * 2)


func _step_convert() -> void:
	var i1 := mini(_pos + CHUNK * 4, n)
	for i in range(_pos, i1):
		var v := _buf[i] * _scale
		if not loop:
			if i < 16:
				v *= float(i) / 16.0
			elif n - i < 96:
				v *= float(n - i) / 96.0
		v = clampf(v, -1.0, 1.0)
		_bytes.encode_s16(i * 2, int(v * 32767.0))
	_pos = i1
	if _pos >= n:
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = rate
		s.stereo = false
		s.data = _bytes
		if loop:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = n
		stream = s
		_buf = PackedFloat32Array()
		_ops.clear()
		done = true
