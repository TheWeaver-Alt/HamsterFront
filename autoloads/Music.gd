extends Node
## Music — procedurally composed chiptune loops, synthesized on a worker thread at startup.
##   "title"  bouncy C-major theme for the title screen
##   "battle" driving A-minor theme during waves
##   "build"  the battle theme's calmer arrangement (no lead, softer drums) between waves
## The track follows the current scene / GameManager.phase automatically and ducks under
## the card draft, Learning Mode quizzes and the pause menu. M toggles music on/off.

const RATE := 22050
const VOLUME_DB := -13.0
const DUCK_DB := -9.0
const FADE_SPEED := 18.0      # dB per second

var enabled := true
var _tracks: Dictionary = {}          # name -> AudioStreamWAV
var _ready_flag := false
var _mutex := Mutex.new()
var _players: Array = []              # two players for crossfades
var _active := 0
var _current := ""
var _target_db := VOLUME_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return   # no audio to hear; skip the synthesis work in tests
	WorkerThreadPool.add_task(_compose_all)


func toggle() -> void:
	enabled = not enabled


# ------------------------------------------------------------------ track selection

func _process(delta: float) -> void:
	if not _ready_flag:
		return
	var want := _wanted_track()
	if want != _current:
		_switch_to(want)
	# ducking / fades
	var target := VOLUME_DB
	if not enabled or want == "":
		target = -80.0
	elif _is_ducked():
		target = VOLUME_DB + DUCK_DB
	for i in _players.size():
		var p: AudioStreamPlayer = _players[i]
		var goal := target if i == _active else -80.0
		p.volume_db = move_toward(p.volume_db, goal, FADE_SPEED * delta * (3.0 if goal < p.volume_db else 1.0))
		if i != _active and p.playing and p.volume_db <= -79.0:
			p.stop()


func _wanted_track() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var n := String(scene.name)
	if n == "TitleScreen":
		return "title"
	if GameManager.phase == "gameover":
		return ""
	if GameManager.arena != null:
		return "battle" if GameManager.phase == "wave" else "build"
	return _current


func _is_ducked() -> bool:
	if GameManager.phase == "draft":
		return true
	var arena = GameManager.arena
	if arena != null:
		if arena.math_quiz != null and arena.math_quiz.active:
			return true
		if arena.pause_menu != null and arena.pause_menu.visible:
			return true
	return false


func _switch_to(track: String) -> void:
	_current = track
	if track == "" or not _tracks.has(track):
		return
	_active = 1 - _active
	var p: AudioStreamPlayer = _players[_active]
	p.stream = _tracks[track]
	p.volume_db = -40.0
	# build <-> battle share a tempo/key: start in sync with the old position
	var other: AudioStreamPlayer = _players[1 - _active]
	var pos := 0.0
	if other.playing and (track == "battle" or track == "build"):
		pos = other.get_playback_position()
	p.play(pos)


# ------------------------------------------------------------------ composition

func _compose_all() -> void:
	var title := _render(_song_title())
	var battle := _render(_song_battle(false))
	var build := _render(_song_battle(true))
	call_deferred("_on_composed", title, battle, build)


func _on_composed(title: PackedFloat32Array, battle: PackedFloat32Array, build: PackedFloat32Array) -> void:
	_tracks["title"] = _wav(title)
	_tracks["battle"] = _wav(battle)
	_tracks["build"] = _wav(build)
	_ready_flag = true


static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## A song = {bpm, steps (16ths), voices: Array of {wave, vol, notes: [[step, len_steps, midi], ...]}, drums: [[step, kind], ...]}
func _song_title() -> Dictionary:
	var bpm := 132.0
	var chords := [[48, 52, 55], [45, 48, 52], [41, 45, 48], [43, 47, 50]]   # C Am F G
	var lead_bars := [
		[72, -1, 76, -1, 79, -1, 76, 77, 79, -1, 84, -1, 81, -1, 79, -1],
		[76, -1, 72, -1, 74, 76, 77, -1, 76, -1, 72, -1, 69, -1, -1, -1],
		[77, -1, 81, -1, 84, -1, 81, 79, 77, -1, 76, -1, 74, -1, 72, -1],
		[74, -1, 79, -1, 77, 76, 74, -1, 71, -1, 74, -1, 79, -1, -1, -1],
	]
	return _arrange(bpm, chords, lead_bars, 2, false, 0.2)


func _song_battle(calm: bool) -> Dictionary:
	var bpm := 148.0
	var chords := [[45, 48, 52], [41, 45, 48], [48, 52, 55], [43, 47, 50]]   # Am F C G
	var lead_bars := [
		[69, -1, 72, 76, 74, -1, 72, -1, 71, 72, 74, -1, 76, -1, 72, -1],
		[77, -1, 76, 74, 72, -1, 69, -1, 72, -1, 74, 72, 69, -1, 65, -1],
		[72, -1, 76, -1, 79, 76, 84, -1, 83, -1, 79, -1, 76, -1, 79, -1],
		[74, -1, 71, 74, 79, -1, 77, 76, 74, -1, 71, -1, 67, 69, 71, -1],
	]
	return _arrange(bpm, chords, lead_bars, 2, calm, 0.16)


## Builds voices from a 4-chord progression played `reps` times, with bass, arpeggio, lead and drums.
func _arrange(bpm: float, chords: Array, lead_bars: Array, reps: int, calm: bool, lead_vol: float) -> Dictionary:
	var bass: Array = []
	var arp: Array = []
	var lead: Array = []
	var drums: Array = []
	var bars := chords.size() * reps
	for b in bars:
		var ch: Array = chords[b % chords.size()]
		var root: int = ch[0]
		var base := b * 16
		# bass: driving 8ths, octave bounce
		for s in range(0, 16, 2):
			var n := root - 12 if s % 4 == 0 else root
			if s == 14 and not calm:
				n = int(ch[1]) - 12
			bass.append([base + s, 2, n])
		# arpeggio: 16ths up the chord
		for s in 16:
			var tone: int = ch[s % 3] + 12 + (12 if (s / 3) % 2 == 1 else 0)
			arp.append([base + s, 1, tone])
		# lead (skipped in the calm build arrangement except for a quiet echo every other bar)
		var mel: Array = lead_bars[b % lead_bars.size()]
		if not calm or b % 2 == 1:
			var s2 := 0
			while s2 < 16:
				var note: int = mel[s2]
				if note >= 0:
					var ln := 1
					while s2 + ln < 16 and int(mel[s2 + ln]) == -1 and ln < 4:
						ln += 1
					lead.append([base + s2, ln, note - (12 if calm else 0)])
				s2 += 1
		# drums
		for s in 16:
			if s % 8 == 0:
				drums.append([base + s, "kick"])
			if not calm and (s == 4 or s == 12):
				drums.append([base + s, "snare"])
			if s % 2 == 0 and (not calm or s % 4 == 0):
				drums.append([base + s, "hat"])
			if not calm and b % 4 == 3 and s >= 12:
				drums.append([base + s, "snare"])   # fill into the next phrase
	return {
		"bpm": bpm, "steps": bars * 16,
		"voices": [
			{"wave": "tri", "vol": 0.26 if not calm else 0.2, "notes": bass},
			{"wave": "pulse12", "vol": 0.05 if not calm else 0.06, "notes": arp},
			{"wave": "pulse50", "vol": lead_vol * (0.6 if calm else 1.0), "notes": lead, "vibrato": true},
		],
		"drums": drums, "drum_vol": 0.55 if not calm else 0.35,
	}


func _render(song: Dictionary) -> PackedFloat32Array:
	var step_len := 60.0 / float(song["bpm"]) / 4.0
	var total := int(float(song["steps"]) * step_len * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	for v in song["voices"]:
		var vol: float = v["vol"]
		var wave: String = v["wave"]
		var vib: bool = v.get("vibrato", false)
		for n in v["notes"]:
			var start := int(float(n[0]) * step_len * RATE)
			var length := int(float(n[1]) * step_len * RATE * 0.92)
			_tone(out, start, length, _freq(int(n[2])), wave, vol, vib)
	var dv: float = song["drum_vol"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for d in song["drums"]:
		var start := int(float(d[0]) * step_len * RATE)
		_drum(out, start, String(d[1]), dv, rng)
	for i in total:
		var x := out[i]
		out[i] = x / (1.0 + absf(x) * 0.6)   # soft clip
	return out


func _tone(out: PackedFloat32Array, start: int, length: int, f: float, wave: String, vol: float, vibrato: bool) -> void:
	var ph := 0.0
	var n := out.size()
	for i in length:
		var idx := start + i
		if idx >= n:
			break
		var t := float(i) / RATE
		var ff := f
		if vibrato and t > 0.09:
			ff *= 1.0 + 0.006 * sin(t * 34.0)
		ph = fmod(ph + ff / RATE, 1.0)
		var s := 0.0
		match wave:
			"tri":
				s = 4.0 * absf(ph - 0.5) - 1.0
				s = roundf(s * 7.0) / 7.0     # NES-style stepped triangle
			"pulse12":
				s = 1.0 if ph < 0.125 else -0.3
			_:
				s = 1.0 if ph < 0.5 else -1.0
		var env := minf(1.0, t / 0.004)
		var rel := float(length - i) / RATE
		env *= minf(1.0, rel / 0.02)
		if wave != "tri":
			env *= 0.65 + 0.35 * exp(-t * 9.0)
		out[idx] += s * vol * env


func _drum(out: PackedFloat32Array, start: int, kind: String, vol: float, rng: RandomNumberGenerator) -> void:
	var n := out.size()
	match kind:
		"kick":
			var ph := 0.0
			var length := int(0.14 * RATE)
			for i in length:
				var idx := start + i
				if idx >= n:
					return
				var t := float(i) / RATE
				ph += lerpf(150.0, 42.0, minf(1.0, t / 0.12)) / RATE
				out[idx] += sin(ph * TAU) * vol * 0.8 * exp(-t * 18.0)
		"snare":
			var length := int(0.13 * RATE)
			var ph := 0.0
			for i in length:
				var idx := start + i
				if idx >= n:
					return
				var t := float(i) / RATE
				ph += 185.0 / RATE
				var s := rng.randf_range(-1.0, 1.0) * 0.7 + sin(ph * TAU) * 0.35
				out[idx] += s * vol * 0.45 * exp(-t * 22.0)
		_:
			var length := int(0.03 * RATE)
			var prev := 0.0
			for i in length:
				var idx := start + i
				if idx >= n:
					return
				var t := float(i) / RATE
				var r := rng.randf_range(-1.0, 1.0)
				out[idx] += (r - prev) * vol * 0.16 * exp(-t * 90.0)
				prev = r


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = samples.size()
	return w
