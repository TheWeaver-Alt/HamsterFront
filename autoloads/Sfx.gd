extends Node
## Sfx — procedural 8-bit sound synthesis + pooled playback.
## Every sound is generated at startup into an AudioStreamWAV (16-bit mono).
##   Sfx.play("shotgun")                    # default pitch/volume
##   Sfx.play("squeak_rat", 1.3, -6.0)      # pitch scale, volume dB
## Unknown names are ignored silently, so gameplay code can call freely.

const RATE := 22050
const POOL := 24
const MAX_SAME := 4          # concurrent instances of one sound
const MIN_GAP_MS := 28       # retrigger guard per sound

var master_db: float = -4.0
var muted: bool = false

var _streams: Dictionary = {}
var _players: Array = []
var _last_play_ms: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 777
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_build_all()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(sound, -1000)) < MIN_GAP_MS:
		return
	var same := 0
	var free_p: AudioStreamPlayer = null
	var oldest: AudioStreamPlayer = null
	var oldest_pos := -1.0
	for p in _players:
		var ap: AudioStreamPlayer = p
		if ap.playing:
			if ap.get_meta("snd", "") == sound:
				same += 1
			var pos := ap.get_playback_position()
			if pos > oldest_pos:
				oldest_pos = pos
				oldest = ap
		elif free_p == null:
			free_p = ap
	if same >= MAX_SAME:
		return
	var use := free_p if free_p != null else oldest
	if use == null:
		return
	_last_play_ms[sound] = now
	use.stream = _streams[sound]
	use.pitch_scale = clampf(pitch, 0.05, 4.0)
	use.volume_db = master_db + volume_db
	use.set_meta("snd", sound)
	use.play()


## Random pitch variation helper.
func play_var(sound: String, base_pitch: float = 1.0, variance: float = 0.1, volume_db: float = 0.0) -> void:
	play(sound, base_pitch * (1.0 + randf_range(-variance, variance)), volume_db)


# ------------------------------------------------------------------ synthesis

func _build_all() -> void:
	_streams["shotgun"] = _wav(_mix([_noise(0.22, 0.9, 6.0, 0.35), _sweep_sine(0.16, 180, 50, 0.8, 8.0)]))
	_streams["rail"] = _wav(_mix([_sweep_square(0.09, 2400, 900, 0.35, 10.0), _noise(0.06, 0.3, 30.0, 0.0)]))
	_streams["punch"] = _wav(_mix([_sweep_sine(0.14, 170, 45, 1.0, 9.0), _noise(0.05, 0.5, 40.0, 0.2)]))
	_streams["gatling"] = _wav(_mix([_noise(0.05, 0.6, 50.0, 0.4), _sweep_square(0.04, 900, 500, 0.2, 30.0)]))
	_streams["laser"] = _wav(_mix([_sweep_square(0.12, 700, 760, 0.18, 2.0), _sweep_sine(0.12, 1400, 1500, 0.15, 2.0)]))
	_streams["mortar_fire"] = _wav(_mix([_sweep_sine(0.2, 120, 60, 0.9, 7.0), _noise(0.12, 0.4, 20.0, 0.6)]))
	_streams["explosion"] = _wav(_mix([_noise(0.6, 1.0, 4.5, 0.75), _sweep_sine(0.45, 90, 30, 0.9, 5.0)]))
	_streams["sneeze"] = _wav(_mix([_sweep_square(0.08, 500, 900, 0.3, 4.0), _noise(0.3, 0.7, 7.0, 0.1)]))
	_streams["zap"] = _wav(_crackle(0.22, 0.6))
	_streams["squeak_rat"] = _wav(_chirp(0.09, 1300, 2100, 1500, 0.35, true))
	_streams["squeak_hamster"] = _wav(_chirp(0.1, 1800, 2600, 2000, 0.3, false))
	_streams["rat_die"] = _wav(_mix([_chirp(0.16, 2000, 2400, 700, 0.35, true), _noise(0.08, 0.3, 25.0, 0.3)]))
	_streams["pickup"] = _wav(_sweep_square(0.045, 1500, 2300, 0.18, 8.0))
	_streams["bank"] = _wav(_arp([988, 1319, 1760], 0.05, 0.25))
	_streams["build"] = _wav(_mix([_noise(0.1, 0.6, 18.0, 0.5), _sweep_square(0.12, 300, 200, 0.3, 10.0)]))
	_streams["upgrade"] = _wav(_arp([523, 659, 784, 1047], 0.06, 0.25))
	_streams["hurt"] = _wav(_mix([_sweep_square(0.15, 300, 120, 0.35, 8.0), _noise(0.08, 0.3, 20.0, 0.2)]))
	_streams["overdrive"] = _wav(_arp([523, 784, 1047, 1319, 1568, 2093], 0.045, 0.25))
	_streams["spit"] = _wav(_mix([_noise(0.35, 1.0, 6.0, 0.5), _sweep_sine(0.3, 220, 40, 1.0, 5.0)]))
	_streams["vent"] = _wav(_noise(0.55, 0.45, 3.0, 0.0))
	_streams["spinout"] = _wav(_warble(0.6, 900, 0.3))
	_streams["card"] = _wav(_arp([784, 988, 1175, 1568], 0.05, 0.22))
	_streams["vend_drop"] = _wav(_mix([_sweep_sine(0.35, 110, 40, 1.0, 5.0), _noise(0.25, 0.7, 10.0, 0.5), _sweep_square(0.2, 620, 600, 0.12, 9.0)]))
	_streams["select"] = _wav(_sweep_square(0.035, 1200, 1250, 0.18, 10.0))
	_streams["wave_start"] = _wav(_horn([220, 277, 330], 0.55, 0.22))
	_streams["wave_clear"] = _wav(_arp([523, 659, 784, 1047, 784, 1047], 0.08, 0.22))
	_streams["game_over"] = _wav(_arp([392, 330, 262, 196, 131], 0.16, 0.25))
	_streams["blip_hamster"] = _wav(_sweep_square(0.025, 900, 950, 0.15, 6.0))
	_streams["blip_rat"] = _wav(_sweep_square(0.022, 600, 520, 0.14, 6.0))
	_streams["jezzail_charge"] = _wav(_sweep_square(0.5, 300, 1400, 0.12, 0.5))
	_streams["jezzail_fire"] = _wav(_mix([_noise(0.25, 0.9, 9.0, 0.3), _sweep_square(0.15, 1600, 200, 0.3, 6.0)]))
	_streams["roomba"] = _wav(_mix([_sweep_square(0.3, 90, 95, 0.15, 1.0), _noise(0.3, 0.12, 1.0, 0.8)]))
	_streams["ogre_roar"] = _wav(_mix([_noise(0.7, 0.8, 2.5, 0.85), _sweep_square(0.6, 110, 70, 0.3, 2.5)]))
	_streams["gas"] = _wav(_noise(0.3, 0.4, 6.0, 0.7))
	_streams["silo_hit"] = _wav(_mix([_sweep_sine(0.12, 140, 70, 0.6, 9.0), _noise(0.06, 0.3, 30.0, 0.5)]))
	_streams["alarm"] = _wav(_arp([880, 0, 880], 0.09, 0.2))
	_streams["throw"] = _wav(_sweep_square(0.18, 400, 1200, 0.18, 4.0))
	_streams["revive"] = _wav(_arp([659, 880, 1319], 0.07, 0.25))
	_streams["downed"] = _wav(_arp([440, 349, 262], 0.12, 0.25))
	_streams["chew"] = _wav(_noise(0.06, 0.35, 25.0, 0.6))
	_streams["deny"] = _wav(_sweep_square(0.12, 220, 200, 0.2, 5.0))
	_streams["tick"] = _wav(_sweep_square(0.02, 2000, 2000, 0.1, 10.0))


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _env(t: float, dur: float, decay: float) -> float:
	# fast attack, exponential decay, forced fade at the end
	var a := minf(1.0, t / 0.004)
	var d := exp(-t * decay)
	var tail := clampf((dur - t) / 0.01, 0.0, 1.0)
	return a * d * tail


func _noise(dur: float, vol: float, decay: float, lowpass: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := _rng.randf_range(-1.0, 1.0)
		lp = lerpf(s, lp, lowpass)
		out[i] = lp * vol * _env(t, dur, decay)
	return out


func _sweep_sine(dur: float, f0: float, f1: float, vol: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		ph += TAU * f / RATE
		out[i] = sin(ph) * vol * _env(t, dur, decay)
	return out


func _sweep_square(dur: float, f0: float, f1: float, vol: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		ph += f / RATE
		var sq := 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		out[i] = sq * vol * _env(t, dur, decay)
	return out


## Rodent squeak: up then down pitch with vibrato.
func _chirp(dur: float, f0: float, fpeak: float, f1: float, vol: float, square: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		var f := lerpf(f0, fpeak, u / 0.35) if u < 0.35 else lerpf(fpeak, f1, (u - 0.35) / 0.65)
		f *= 1.0 + 0.04 * sin(t * 180.0)
		ph += f / RATE
		var s := (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) if square else sin(ph * TAU)
		var e := minf(1.0, t / 0.006) * clampf((dur - t) / 0.02, 0.0, 1.0)
		out[i] = s * vol * e
	return out


func _crackle(dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hold := 0.0
	var cnt := 0
	for i in n:
		var t := float(i) / RATE
		if cnt <= 0:
			hold = _rng.randf_range(-1.0, 1.0)
			cnt = _rng.randi_range(4, 40)
		cnt -= 1
		out[i] = hold * vol * _env(t, dur, 6.0)
	return out


func _warble(dur: float, f: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var ff := f * (1.0 + 0.5 * sin(t * 40.0)) * (1.0 + t)
		ph += ff / RATE
		out[i] = (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * vol * clampf((dur - t) / 0.05, 0.0, 1.0)
	return out


func _arp(freqs: Array, step: float, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		if float(f) <= 0.0:
			var silence := PackedFloat32Array()
			silence.resize(int(step * RATE))
			out.append_array(silence)
		else:
			out.append_array(_sweep_square(step, float(f), float(f), vol, 3.0))
	return out


func _horn(freqs: Array, dur: float, vol: float) -> PackedFloat32Array:
	var parts: Array = []
	for f in freqs:
		parts.append(_sweep_square(dur, float(f), float(f) * 0.98, vol / freqs.size() * 1.6, 1.5))
	return _mix(parts)


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, (p as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		var arr: PackedFloat32Array = p
		for i in arr.size():
			out[i] += arr[i]
	for i in n:
		out[i] = clampf(out[i], -1.0, 1.0)
	return out
