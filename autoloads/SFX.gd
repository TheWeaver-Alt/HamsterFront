extends Node
## Procedural 8-bit sound effects. Every sample is synthesised at startup into
## AudioStreamWAV buffers, so the project ships with zero audio assets.

const RATE := 22050
const VOICES := 24

enum Wave { SQUARE, SAW, SINE, NOISE, TRIANGLE }

var master_db := -4.0
var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build()


## Plays a named sound. min_interval_ms throttles rapid repeats (gatlings!).
func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0, min_interval_ms: int = 35) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if min_interval_ms > 0 and now - int(_last_play.get(sound, -100000)) < min_interval_ms:
		return
	_last_play[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.volume_db = master_db + vol_db
	p.play()


func _build() -> void:
	_streams["squeak"] = _make(_synth(0.09, 1400.0, 2300.0, Wave.SQUARE, 0.22, 0.0, 40.0))
	_streams["rat_die"] = _make(_synth(0.16, 1900.0, 600.0, Wave.SQUARE, 0.22, 0.1, 30.0))
	_streams["blip"] = _make(_synth(0.035, 880.0, 900.0, Wave.SQUARE, 0.16))
	_streams["blip_rat"] = _make(_synth(0.03, 1500.0, 1300.0, Wave.SQUARE, 0.13))
	_streams["shotgun"] = _make(_synth(0.2, 200.0, 50.0, Wave.SQUARE, 0.55, 0.8))
	_streams["rail"] = _make(_synth(0.13, 2600.0, 300.0, Wave.SAW, 0.3, 0.2))
	_streams["punch"] = _make(_synth(0.13, 170.0, 40.0, Wave.SINE, 0.8, 0.35))
	_streams["whoosh"] = _make(_synth(0.12, 900.0, 300.0, Wave.NOISE, 0.18, 1.0))
	_streams["hull"] = _make(_synth(0.045, 700.0, 300.0, Wave.SQUARE, 0.14, 0.6))
	_streams["boom"] = _make(_synth(0.5, 95.0, 28.0, Wave.SINE, 0.85, 0.6))
	_streams["zap"] = _make(_synth(0.17, 900.0, 1300.0, Wave.SAW, 0.22, 0.5, 60.0))
	_streams["pickup"] = _make(_synth(0.05, 1000.0, 1700.0, Wave.TRIANGLE, 0.2))
	_streams["bank"] = _make(_synth(0.22, 600.0, 1300.0, Wave.SQUARE, 0.18, 0.0, 12.0))
	_streams["hurt"] = _make(_synth(0.16, 520.0, 140.0, Wave.SQUARE, 0.3, 0.15))
	_streams["build"] = _make(_synth(0.16, 230.0, 110.0, Wave.SQUARE, 0.3, 0.3))
	_streams["steam"] = _make(_synth(0.5, 3000.0, 1800.0, Wave.NOISE, 0.22, 1.0))
	_streams["vend"] = _make(_synth(0.4, 130.0, 70.0, Wave.SQUARE, 0.35, 0.25, 8.0))
	_streams["laser"] = _make(_synth(0.08, 1600.0, 1750.0, Wave.SINE, 0.08, 0.05, 50.0))
	_streams["spit"] = _make(_synth(0.32, 260.0, 1200.0, Wave.NOISE, 0.5, 0.7))
	_streams["overdrive"] = _make(_synth(0.55, 300.0, 1600.0, Wave.SQUARE, 0.25, 0.0, 22.0))
	_streams["card"] = _make(_synth(0.08, 1200.0, 1900.0, Wave.TRIANGLE, 0.22))
	_streams["alarm"] = _make(_synth(0.32, 820.0, 600.0, Wave.SQUARE, 0.2, 0.0, 8.0))
	_streams["sneeze"] = _make(_synth(0.26, 500.0, 180.0, Wave.NOISE, 0.32, 0.9))
	_streams["jezzail"] = _make(_synth(0.22, 1300.0, 180.0, Wave.SAW, 0.35, 0.45))
	_streams["trip"] = _make(_synth(0.3, 600.0, 2400.0, Wave.SQUARE, 0.2, 0.0, 70.0))
	_streams["error"] = _make(_synth(0.12, 160.0, 150.0, Wave.SQUARE, 0.22))
	_streams["join"] = _make(_synth(0.3, 500.0, 1500.0, Wave.TRIANGLE, 0.3, 0.0, 6.0))
	_streams["wave"] = _make(_synth(0.6, 220.0, 440.0, Wave.SQUARE, 0.25, 0.05, 5.0))


func _synth(dur: float, f0: float, f1: float, wave: int, vol: float, noise: float = 0.0, vibrato: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var attack := 0.004 * RATE
	var held_noise := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if vibrato > 0.0:
			f *= 1.0 + 0.08 * sin(float(i) / RATE * TAU * vibrato)
		phase += f / RATE
		var ph := phase - floorf(phase)
		var s := 0.0
		match wave:
			Wave.SQUARE:
				s = 1.0 if ph < 0.5 else -1.0
			Wave.SAW:
				s = ph * 2.0 - 1.0
			Wave.SINE:
				s = sin(ph * TAU)
			Wave.TRIANGLE:
				s = 4.0 * absf(ph - 0.5) - 1.0
			Wave.NOISE:
				# Sample-and-hold noise pitched by frequency for crunchy 8-bit hiss.
				if ph < f / RATE:
					held_noise = randf_range(-1.0, 1.0)
				s = held_noise
		if noise > 0.0 and wave != Wave.NOISE:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := (1.0 - t)
		env *= env
		var a := minf(1.0, float(i) / attack)
		out[i] = s * vol * env * a
	return out


func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
