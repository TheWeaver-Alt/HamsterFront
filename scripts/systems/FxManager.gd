class_name FxManager
extends Node2D
## Pixel particle bursts, chunky multi-frame muzzle flashes, dithered shockwave rings,
## crackling lightning, beams and pop-in floating text — all batched into one _draw().
##
## Particle shapes: SQUARE, CROSS (tiny plus), STREAK (motion-blurred spark), PUFF (growing
## smoke ball), DEBRIS (tumbling 2x1 chip), CONFETTI (fluttering flake), EMBER (hot->cold ramp).
## Public API is stable: particle, burst, flash, ring, bolt, beam, float_text and the presets
## (sparks, warp_sparks, fur, dust, sawdust, seed_shells, steam, smoke, fire, confetti,
## explosion, impact, muzzle_smoke).

enum { SQUARE, CROSS, STREAK, PUFF, DEBRIS, CONFETTI, EMBER }

const MAX_PARTICLES := 1800
const MAX_PUFFS := 140

# particle SoA
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _aux := PackedFloat32Array()      # PUFF: growth px, DEBRIS/CONFETTI: spin rate
var _shape := PackedByteArray()
var _col: Array = []          # Color per particle
var _count := 0
var _puffs := 0

var _flashes: Array = []      # {pos, rot, size, life, max, color}
var _rings: Array = []        # {pos, r0, r1, life, max, color}
var _bolts: Array = []        # {a, b, life, max, color, jag, seed}
var _texts: Array = []        # {pos, text, life, max, color, rise, drift, big}
var _beams: Array = []        # {a, b, life, max, color, width}
var _clock := 0.0


func _ready() -> void:
	z_index = 20
	_px.resize(MAX_PARTICLES)
	_py.resize(MAX_PARTICLES)
	_vx.resize(MAX_PARTICLES)
	_vy.resize(MAX_PARTICLES)
	_life.resize(MAX_PARTICLES)
	_max.resize(MAX_PARTICLES)
	_size.resize(MAX_PARTICLES)
	_grav.resize(MAX_PARTICLES)
	_drag.resize(MAX_PARTICLES)
	_aux.resize(MAX_PARTICLES)
	_shape.resize(MAX_PARTICLES)
	_col.resize(MAX_PARTICLES)


# ------------------------------------------------------------------ API

func particle(pos: Vector2, vel: Vector2, life: float, color: Color, size: float = 1.0,
		gravity: float = 0.0, drag: float = 2.0, shape: int = SQUARE, aux: float = 0.0) -> void:
	if shape == PUFF:
		if _puffs >= MAX_PUFFS:
			return
		_puffs += 1
	var i := _count
	if _count >= MAX_PARTICLES:
		i = randi() % MAX_PARTICLES
		if _shape[i] == PUFF:
			_puffs -= 1
	else:
		_count += 1
	_px[i] = pos.x
	_py[i] = pos.y
	_vx[i] = vel.x
	_vy[i] = vel.y
	_life[i] = life
	_max[i] = life
	_size[i] = size
	_grav[i] = gravity
	_drag[i] = drag
	_aux[i] = aux
	_shape[i] = shape
	_col[i] = color


## Generic radial (or directional) burst.
func burst(pos: Vector2, n: int, colors: Array, speed_min: float, speed_max: float,
		life_min: float = 0.25, life_max: float = 0.6, size: float = 1.0, gravity: float = 0.0,
		drag: float = 3.0, dir: Vector2 = Vector2.ZERO, spread: float = PI, shape: int = SQUARE) -> void:
	for k in n:
		var a: float
		if dir == Vector2.ZERO:
			a = randf() * TAU
		else:
			a = dir.angle() + randf_range(-spread, spread)
		var v := Vector2.from_angle(a) * randf_range(speed_min, speed_max)
		var c: Color = colors[randi() % colors.size()]
		var s := size if randf() < 0.7 else size + 1.0
		var aux := randf_range(8.0, 22.0) if shape == DEBRIS or shape == CONFETTI else 0.0
		particle(pos, v, randf_range(life_min, life_max), c, s, gravity, drag, shape, aux)


## Chunky 3-frame muzzle flash: spiky star -> cross -> ring of embers.
func flash(pos: Vector2, rot: float, size: float, color: Color = Color8(255, 240, 120), life: float = 0.06) -> void:
	_flashes.append({"pos": pos, "rot": rot, "size": size, "life": life, "max": life, "color": color})


func ring(pos: Vector2, r1: float, color: Color, life: float = 0.25, r0: float = 2.0) -> void:
	_rings.append({"pos": pos, "r0": r0, "r1": r1, "life": life, "max": life, "color": color})


func bolt(a: Vector2, b: Vector2, color: Color = Color8(150, 220, 255), life: float = 0.12, jag: float = 5.0) -> void:
	_bolts.append({"a": a, "b": b, "life": life, "max": life, "color": color, "jag": jag, "seed": randi()})


func beam(a: Vector2, b: Vector2, color: Color, life: float = 0.08, width: float = 1.0) -> void:
	_beams.append({"a": a, "b": b, "life": life, "max": life, "color": color, "width": width})


func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, life: float = 0.8, rise: float = 16.0) -> void:
	if _texts.size() > 40:
		_texts.pop_front()
	# short texts (damage numbers, +seeds) pop in at double size
	var big := text.length() <= 5
	_texts.append({"pos": pos, "text": text, "life": life, "max": life, "color": color, "rise": rise,
		"drift": randf_range(-6.0, 6.0) if big else 0.0, "big": big})


# ------------------------------------------------------------------ presets

func sparks(pos: Vector2, color: Color = Color8(255, 214, 64), n: int = 6, dir: Vector2 = Vector2.ZERO) -> void:
	burst(pos, n, [color, color.lightened(0.4), Color.WHITE], 50, 150, 0.08, 0.26, 1.0, 0.0, 7.0, dir, 0.9, STREAK)
	particle(pos, Vector2.ZERO, 0.06, Color.WHITE, 1.0, 0.0, 0.0, CROSS)


func impact(pos: Vector2, dir: Vector2 = Vector2.ZERO, color: Color = Color8(255, 214, 64)) -> void:
	sparks(pos, color, 4, dir)
	ring(pos, 5.0, color.lightened(0.3), 0.12, 1.0)
	particle(pos, dir * 10.0, 0.3, Color(1, 1, 1, 0.5), 1.0, -10.0, 3.0, PUFF, 2.0)


func warp_sparks(pos: Vector2, n: int = 10) -> void:
	var cols := [PixelArt.C["z"], PixelArt.C["Z"], PixelArt.C["x"], Color.WHITE]
	for k in n:
		var shape := CROSS if k % 3 == 0 else (STREAK if k % 3 == 1 else SQUARE)
		var v := Vector2.from_angle(randf() * TAU) * randf_range(30, 110)
		particle(pos, v, randf_range(0.2, 0.55), cols[randi() % cols.size()], 1.0, -30.0, 3.0, shape)


func fur(pos: Vector2, n: int = 6) -> void:
	var cols := [PixelArt.C["m"], PixelArt.C["M"], PixelArt.C["q"]]
	burst(pos, n, cols, 30, 90, 0.3, 0.7, 1.0, 120.0, 3.0)
	burst(pos, maxi(1, n / 3), cols, 40, 110, 0.4, 0.8, 1.0, 160.0, 2.0, Vector2.ZERO, PI, DEBRIS)


func dust(pos: Vector2, n: int = 5) -> void:
	var cols := [Color(PixelArt.C["t"], 0.7), Color(PixelArt.C["T"], 0.6), Color(PixelArt.C["h"], 0.6)]
	for k in n:
		var v := Vector2(randf_range(-30, 30), randf_range(-14, 2))
		if k % 2 == 0:
			particle(pos + Vector2(randf_range(-3, 3), 0), v, randf_range(0.35, 0.6), cols[k % 3], 1.0, -6.0, 4.0, PUFF, 2.5)
		else:
			particle(pos, v * 1.4, randf_range(0.25, 0.5), cols[k % 3], 1.0, 40.0, 4.0)


func sawdust(pos: Vector2, dir: Vector2, n: int = 10) -> void:
	var cols := [PixelArt.C["t"], PixelArt.C["c"], PixelArt.C["T"], PixelArt.C["y"]]
	burst(pos, n, cols, 60, 200, 0.12, 0.35, 1.0, 60.0, 5.0, dir, 0.5)
	burst(pos, maxi(1, n / 3), cols, 50, 140, 0.25, 0.45, 1.0, 140.0, 3.0, dir, 0.7, DEBRIS)
	particle(pos + dir * 3.0, dir * 20.0, 0.35, Color(PixelArt.C["c"], 0.45), 1.0, -12.0, 3.0, PUFF, 3.0)


func seed_shells(pos: Vector2, n: int = 4) -> void:
	burst(pos, n, [PixelArt.C["s"], PixelArt.C["S"], PixelArt.C["s"]], 30, 100, 0.35, 0.7, 1.0, 180.0, 2.0, Vector2.ZERO, PI, DEBRIS)


func steam(pos: Vector2, n: int = 8) -> void:
	var cols := [Color(1, 1, 1, 0.75), Color(0.85, 0.9, 0.95, 0.65), Color(PixelArt.C["W"], 0.6)]
	for k in n:
		var v := Vector2(randf_range(-25, 25), randf_range(-60, -15))
		particle(pos + Vector2(randf_range(-2, 2), 0), v, randf_range(0.45, 0.9), cols[k % 3], 1.0, -30.0, 2.5, PUFF, 3.5)


func smoke(pos: Vector2, n: int = 4) -> void:
	var cols := [Color(PixelArt.C["G"], 0.7), Color(PixelArt.C["K"], 0.65), Color(PixelArt.C["g"], 0.55)]
	for k in n:
		var v := Vector2(randf_range(-14, 14), randf_range(-26, -6))
		particle(pos + Vector2(randf_range(-3, 3), randf_range(-2, 2)), v, randf_range(0.6, 1.1), cols[k % 3], 1.0, -18.0, 1.5, PUFF, 4.0)


func muzzle_smoke(pos: Vector2, dir: Vector2) -> void:
	particle(pos, dir * 26.0 + Vector2(0, -6), 0.4, Color(0.9, 0.9, 0.95, 0.4), 1.0, -16.0, 4.0, PUFF, 3.0)


func fire(pos: Vector2, n: int = 3) -> void:
	for k in n:
		var v := Vector2(randf_range(-10, 10), randf_range(-36, -10))
		particle(pos + Vector2(randf_range(-2, 2), 0), v, randf_range(0.25, 0.5), PixelArt.C["I"], 1.0 + float(k % 2), -50.0, 2.0, EMBER)


func confetti(pos: Vector2, n: int = 24) -> void:
	burst(pos, n, [PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["Z"], PixelArt.C["v"]],
		60, 180, 0.6, 1.3, 1.0, 120.0, 2.8, Vector2.ZERO, PI, CONFETTI)


func explosion(pos: Vector2, radius: float, palette: String = "fire") -> void:
	var cols: Array
	var smoke_col: Color
	match palette:
		"warp":
			cols = [PixelArt.C["z"], PixelArt.C["Z"], PixelArt.C["x"], Color.WHITE]
			smoke_col = Color(0.15, 0.4, 0.15, 0.6)
		"sneeze":
			cols = [PixelArt.C["t"], PixelArt.C["c"], PixelArt.C["w"], PixelArt.C["y"]]
			smoke_col = Color(0.95, 0.88, 0.7, 0.55)
		"steam":
			cols = [Color.WHITE, PixelArt.C["W"], PixelArt.C["a"]]
			smoke_col = Color(0.95, 0.97, 1.0, 0.55)
		_:
			cols = [PixelArt.C["I"], PixelArt.C["y"], PixelArt.C["i"], PixelArt.C["r"], Color.WHITE]
			smoke_col = Color(PixelArt.C["G"], 0.65)
	# fast streak sparks + chunky debris + embers
	burst(pos, int(radius * 0.9) + 6, cols, radius * 3.0, radius * 7.0, 0.12, 0.3, 1.0, 0.0, 6.0, Vector2.ZERO, PI, STREAK)
	burst(pos, int(radius * 0.35) + 3, [PixelArt.C["B"], PixelArt.C["T"], PixelArt.C["G"], cols[0]], radius * 2.0, radius * 4.5,
		0.4, 0.8, 1.0, 220.0, 2.0, Vector2(0, -1), 1.3, DEBRIS)
	if palette == "fire":
		for k in int(radius / 3.0) + 2:
			particle(pos + Vector2(randf_range(-radius, radius), randf_range(-radius, radius)) * 0.4,
				Vector2(randf_range(-30, 30), randf_range(-60, -20)), randf_range(0.3, 0.6), PixelArt.C["I"], 1.0, -40.0, 2.0, EMBER)
	# smoke billows that grow and drift up
	for k in int(radius / 5.0) + 3:
		var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, radius * 0.6)
		particle(pos + off, off * 0.8 + Vector2(0, -18), randf_range(0.6, 1.1), smoke_col, maxf(2.0, radius * 0.18), -14.0, 2.0, PUFF, radius * 0.35)
	ring(pos, radius * 1.15, cols[0], 0.28, radius * 0.3)
	flash(pos, randf() * TAU, radius * 0.9, cols[0], 0.1)


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	_clock += delta
	var i := 0
	while i < _count:
		_life[i] -= delta
		if _life[i] <= 0.0:
			if _shape[i] == PUFF:
				_puffs -= 1
			_count -= 1
			_swap(i, _count)
			continue
		var d := maxf(0.0, 1.0 - _drag[i] * delta)
		_vx[i] *= d
		_vy[i] = _vy[i] * d + _grav[i] * delta
		_px[i] += _vx[i] * delta
		_py[i] += _vy[i] * delta
		i += 1
	_tick_list(_flashes, delta)
	_tick_list(_rings, delta)
	_tick_list(_bolts, delta)
	_tick_list(_beams, delta)
	_tick_list(_texts, delta)
	queue_redraw()


func _tick_list(arr: Array, delta: float) -> void:
	var k := arr.size() - 1
	while k >= 0:
		arr[k]["life"] -= delta
		if arr[k]["life"] <= 0.0:
			arr.remove_at(k)
		k -= 1


func _swap(a: int, b: int) -> void:
	_px[a] = _px[b]
	_py[a] = _py[b]
	_vx[a] = _vx[b]
	_vy[a] = _vy[b]
	_life[a] = _life[b]
	_max[a] = _max[b]
	_size[a] = _size[b]
	_grav[a] = _grav[b]
	_drag[a] = _drag[b]
	_aux[a] = _aux[b]
	_shape[a] = _shape[b]
	_col[a] = _col[b]


# ------------------------------------------------------------------ draw

const EMBER_RAMP := [Color8(255, 248, 200), Color8(255, 240, 120), Color8(255, 168, 48), Color8(226, 64, 64), Color8(84, 70, 98)]


func _draw() -> void:
	# puffs first so sparks read on top of smoke
	for i in _count:
		if _shape[i] == PUFF:
			_draw_particle(i)
	for i in _count:
		if _shape[i] != PUFF:
			_draw_particle(i)
	for r in _rings:
		_draw_ring(r)
	for b in _beams:
		var c: Color = b["color"]
		c.a = clampf(b["life"] / b["max"] * 1.5, 0.0, 1.0)
		draw_line(b["a"], b["b"], c, b["width"])
	for b in _bolts:
		_draw_bolt(b)
	for f in _flashes:
		_draw_flash(f)
	for tx in _texts:
		_draw_text(tx)


func _draw_particle(i: int) -> void:
	var c: Color = _col[i]
	var t := _life[i] / _max[i]          # 1 -> 0
	var x := roundf(_px[i])
	var y := roundf(_py[i])
	var s := _size[i]
	match _shape[i]:
		SQUARE:
			if t < 0.3:
				c.a *= t / 0.3
			if t < 0.5 and s > 1.0:
				s -= 1.0
			draw_rect(Rect2(x, y, s, s), c)
		CROSS:
			if t < 0.4:
				c.a *= t / 0.4
			draw_rect(Rect2(x, y, 1, 1), Color.WHITE if t > 0.6 else c)
			if t > 0.25:
				draw_rect(Rect2(x - 1, y, 3, 1), c)
				draw_rect(Rect2(x, y - 1, 1, 3), c)
		STREAK:
			var v := Vector2(_vx[i], _vy[i])
			var l := clampf(v.length() * 0.03, 1.0, 6.0)
			var tail := Vector2(x, y) - v.normalized() * l
			var tc := c
			tc.a *= 0.45 * minf(1.0, t / 0.3)
			draw_line(tail.round(), Vector2(x, y), tc, 1.0)
			var hc := c if t < 0.5 else c.lightened(0.5)
			hc.a *= minf(1.0, t / 0.25)
			draw_rect(Rect2(x, y, 1, 1), hc)
		PUFF:
			var age := 1.0 - t
			var r := s + _aux[i] * (1.0 - pow(1.0 - age, 2.0))
			c.a *= clampf(t * 1.6, 0.0, 1.0)
			PixelArt.draw_disk(self, Vector2(x, y), r, c)
			if age < 0.4 and r > 2.5:
				var hl := c.lightened(0.25)
				hl.a *= 0.6
				draw_rect(Rect2(x - r * 0.4, y - r * 0.5, maxf(1.0, r * 0.5), 1), hl)
		DEBRIS:
			if t < 0.25:
				c.a *= t / 0.25
			var phase := int((_max[i] - _life[i]) * _aux[i]) % 4
			match phase:
				0:
					draw_rect(Rect2(x, y, 2, 1), c)
				1:
					draw_rect(Rect2(x, y, 1, 1), c)
					draw_rect(Rect2(x + 1, y + 1, 1, 1), c.darkened(0.25))
				2:
					draw_rect(Rect2(x, y, 1, 2), c)
				_:
					draw_rect(Rect2(x + 1, y, 1, 1), c)
					draw_rect(Rect2(x, y + 1, 1, 1), c.darkened(0.25))
		CONFETTI:
			if t < 0.3:
				c.a *= t / 0.3
			var flip := sin((_max[i] - _life[i]) * _aux[i])
			if absf(flip) > 0.7:
				draw_rect(Rect2(x, y, 2, 1), c)
			elif absf(flip) > 0.25:
				draw_rect(Rect2(x, y, 1, 1), c.darkened(0.2))
			else:
				draw_rect(Rect2(x, y, 1, 2), c.lightened(0.2))
		EMBER:
			var k := clampi(int((1.0 - t) * EMBER_RAMP.size()), 0, EMBER_RAMP.size() - 1)
			var ec: Color = EMBER_RAMP[k]
			if t < 0.25:
				ec.a = t / 0.25
			var es := s if t > 0.5 else 1.0
			draw_rect(Rect2(x, y, es, es), ec)


## Dithered shockwave: thick and solid at first, thinning into a broken pixel ring.
func _draw_ring(r: Dictionary) -> void:
	var t: float = 1.0 - r["life"] / r["max"]
	var rad: float = lerpf(r["r0"], r["r1"], 1.0 - pow(1.0 - t, 2.0))
	var c: Color = r["color"]
	c.a = 1.0 - t * t
	var center: Vector2 = r["pos"]
	var n := maxi(12, int(rad * 3.2))
	var thick := 2 if t < 0.45 else 1
	for k in n:
		if t > 0.55 and (k + int(t * 10.0)) % 2 == 1:
			continue
		var a := TAU * k / n
		var dir := Vector2(cos(a), sin(a))
		var p := (center + dir * rad).round()
		draw_rect(Rect2(p, Vector2(1, 1)), c)
		if thick == 2:
			draw_rect(Rect2((center + dir * (rad - 1.0)).round(), Vector2(1, 1)), Color(c, c.a * 0.6))


## Lightning that re-crackles every ~33ms, with a side fork or two.
func _draw_bolt(b: Dictionary) -> void:
	var a: Vector2 = b["a"]
	var e: Vector2 = b["b"]
	var c: Color = b["color"]
	var jag: float = b["jag"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b["seed"]) + int(_clock * 30.0)
	var segs := maxi(3, int(a.distance_to(e) / 7.0))
	var n := (e - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	pts.append(a.round())
	for s in range(1, segs):
		var t := float(s) / segs
		pts.append((a.lerp(e, t) + n * rng.randf_range(-jag, jag)).round())
	pts.append(e.round())
	var fresh: bool = b["life"] > b["max"] * 0.5
	draw_polyline(pts, Color(c, 0.3), 3.0)
	draw_polyline(pts, Color.WHITE if fresh else c, 1.0)
	# forks
	if pts.size() > 3:
		for f in 2:
			var k := rng.randi_range(1, pts.size() - 2)
			var dir := (e - a).normalized().rotated(rng.randf_range(-1.2, 1.2))
			var end := pts[k] + dir * rng.randf_range(4.0, 9.0)
			draw_line(pts[k], end.round(), Color(c, 0.8), 1.0)


## Oversized chunky flash. Frame 0: spiky star with a white core; frame 1: cross;
## frame 2: scattered embers. Spikes are rasterised in whole pixels.
func _draw_flash(f: Dictionary) -> void:
	var pos: Vector2 = (f["pos"] as Vector2).round()
	var size: float = f["size"]
	var rot: float = f["rot"]
	var c: Color = f["color"]
	var prog: float = 1.0 - f["life"] / f["max"]
	var fwd := Vector2.from_angle(rot)
	if prog < 0.34:
		_spike(pos, fwd, size * 1.7, 3.0, c)
		_spike(pos, fwd.rotated(PI * 0.5), size * 0.7, 2.0, c)
		_spike(pos, fwd.rotated(-PI * 0.5), size * 0.7, 2.0, c)
		_spike(pos, fwd.rotated(PI), size * 0.4, 2.0, c)
		_spike(pos, fwd.rotated(PI * 0.25), size * 0.55, 1.0, c)
		_spike(pos, fwd.rotated(-PI * 0.25), size * 0.55, 1.0, c)
		PixelArt.draw_disk(self, pos, maxf(1.5, size * 0.45), c.lightened(0.3))
		PixelArt.draw_disk(self, pos, maxf(1.0, size * 0.28), Color.WHITE)
	elif prog < 0.67:
		_spike(pos, fwd, size * 1.1, 2.0, c)
		_spike(pos, fwd.rotated(PI * 0.5), size * 0.45, 1.0, c)
		_spike(pos, fwd.rotated(-PI * 0.5), size * 0.45, 1.0, c)
		PixelArt.draw_disk(self, pos, maxf(1.0, size * 0.3), c.lightened(0.4))
	else:
		var cc := c
		cc.a = 0.8
		for k in 6:
			var a := rot + k * TAU / 6.0
			var p := (pos + Vector2.from_angle(a) * size * 0.6).round()
			draw_rect(Rect2(p, Vector2(1, 1)), cc)


func _spike(pos: Vector2, dir: Vector2, length: float, width: float, c: Color) -> void:
	var steps := int(length)
	var side := dir.orthogonal()
	for s in steps:
		var t := float(s) / maxf(1.0, length)
		var w := maxf(1.0, roundf(width * (1.0 - t)))
		var p := pos + dir * s
		var col := Color.WHITE if t < 0.25 else c
		if w <= 1.0:
			draw_rect(Rect2(p.round(), Vector2(1, 1)), col)
		else:
			var a := (p - side * floorf(w / 2.0)).round()
			draw_rect(Rect2(a, Vector2(1, 1)), col)
			draw_rect(Rect2((p + side * floorf(w / 2.0)).round(), Vector2(1, 1)), col)
			draw_rect(Rect2(p.round(), Vector2(1, 1)), col)


## Pop-in floating text: short numbers flash big for a moment, then rise and fade.
func _draw_text(tx: Dictionary) -> void:
	var t: float = 1.0 - tx["life"] / tx["max"]
	var c: Color = tx["color"]
	c.a = clampf(tx["life"] / tx["max"] * 2.5, 0.0, 1.0)
	var rise: float = tx["rise"] * (1.0 - pow(1.0 - t, 3.0))
	var p: Vector2 = tx["pos"] - Vector2(-float(tx["drift"]) * t, rise)
	var size := 6
	if tx["big"] and t < 0.12:
		size = 12
		p.y -= 3.0
	PixelArt.draw_text_centered(self, p.round(), tx["text"], c, true, size)
