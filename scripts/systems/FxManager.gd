class_name FxManager
extends Node2D
## Pixel particle bursts, oversized muzzle flashes, shockwave rings, lightning bolts
## and floating text — all batched into one _draw() for speed.

const MAX_PARTICLES := 1800

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
var _col: Array = []          # Color per particle
var _count := 0

var _flashes: Array = []      # {pos, rot, size, life, max, color, points}
var _rings: Array = []        # {pos, r0, r1, life, max, color}
var _bolts: Array = []        # {points: PackedVector2Array, life, max, color}
var _texts: Array = []        # {pos, text, life, max, color, rise}
var _beams: Array = []        # {a, b, life, max, color, width}


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
	_col.resize(MAX_PARTICLES)


# ------------------------------------------------------------------ API

func particle(pos: Vector2, vel: Vector2, life: float, color: Color, size: float = 1.0,
		gravity: float = 0.0, drag: float = 2.0) -> void:
	var i := _count
	if _count >= MAX_PARTICLES:
		i = randi() % MAX_PARTICLES
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
	_col[i] = color


## Generic radial burst.
func burst(pos: Vector2, n: int, colors: Array, speed_min: float, speed_max: float,
		life_min: float = 0.25, life_max: float = 0.6, size: float = 1.0, gravity: float = 0.0,
		drag: float = 3.0, dir: Vector2 = Vector2.ZERO, spread: float = PI) -> void:
	for k in n:
		var a: float
		if dir == Vector2.ZERO:
			a = randf() * TAU
		else:
			a = dir.angle() + randf_range(-spread, spread)
		var v := Vector2.from_angle(a) * randf_range(speed_min, speed_max)
		var c: Color = colors[randi() % colors.size()]
		var s := size if randf() < 0.7 else size + 1.0
		particle(pos, v, randf_range(life_min, life_max), c, s, gravity, drag)


func flash(pos: Vector2, rot: float, size: float, color: Color = Color8(255, 240, 120), life: float = 0.06) -> void:
	_flashes.append({"pos": pos, "rot": rot, "size": size, "life": life, "max": life, "color": color})


func ring(pos: Vector2, r1: float, color: Color, life: float = 0.25, r0: float = 2.0) -> void:
	_rings.append({"pos": pos, "r0": r0, "r1": r1, "life": life, "max": life, "color": color})


func bolt(a: Vector2, b: Vector2, color: Color = Color8(150, 220, 255), life: float = 0.12, jag: float = 5.0) -> void:
	var pts := PackedVector2Array()
	var segs := maxi(3, int(a.distance_to(b) / 7.0))
	var n := (b - a).orthogonal().normalized()
	pts.append(a)
	for s in range(1, segs):
		var t := float(s) / segs
		pts.append(a.lerp(b, t) + n * randf_range(-jag, jag))
	pts.append(b)
	_bolts.append({"points": pts, "life": life, "max": life, "color": color})


func beam(a: Vector2, b: Vector2, color: Color, life: float = 0.08, width: float = 1.0) -> void:
	_beams.append({"a": a, "b": b, "life": life, "max": life, "color": color, "width": width})


func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, life: float = 0.8, rise: float = 16.0) -> void:
	if _texts.size() > 40:
		_texts.pop_front()
	_texts.append({"pos": pos, "text": text, "life": life, "max": life, "color": color, "rise": rise})


# ------------------------------------------------------------------ presets

func sparks(pos: Vector2, color: Color = Color8(255, 214, 64), n: int = 6, dir: Vector2 = Vector2.ZERO) -> void:
	burst(pos, n, [color, color.lightened(0.4), Color.WHITE], 40, 120, 0.1, 0.3, 1.0, 0.0, 6.0, dir, 0.9)


func warp_sparks(pos: Vector2, n: int = 10) -> void:
	burst(pos, n, [PixelArt.C["z"], PixelArt.C["Z"], PixelArt.C["x"], Color.WHITE], 30, 110, 0.2, 0.55, 1.0, -30.0, 3.0)


func fur(pos: Vector2, n: int = 6) -> void:
	burst(pos, n, [PixelArt.C["m"], PixelArt.C["M"], PixelArt.C["q"]], 30, 90, 0.3, 0.7, 1.0, 120.0, 3.0)


func dust(pos: Vector2, n: int = 5) -> void:
	burst(pos, n, [PixelArt.C["T"], PixelArt.C["t"], PixelArt.C["h"]], 10, 40, 0.3, 0.6, 1.0, -10.0, 4.0)


func sawdust(pos: Vector2, dir: Vector2, n: int = 10) -> void:
	burst(pos, n, [PixelArt.C["t"], PixelArt.C["c"], PixelArt.C["T"], PixelArt.C["y"]], 60, 200, 0.12, 0.35, 1.0, 60.0, 5.0, dir, 0.5)


func seed_shells(pos: Vector2, n: int = 4) -> void:
	burst(pos, n, [PixelArt.C["s"], PixelArt.C["S"]], 30, 90, 0.3, 0.6, 1.0, 160.0, 2.0)


func steam(pos: Vector2, n: int = 8) -> void:
	burst(pos, n, [Color(1, 1, 1, 0.8), Color(0.85, 0.9, 0.95, 0.7), PixelArt.C["W"]], 15, 60, 0.4, 0.9, 2.0, -40.0, 2.5)


func smoke(pos: Vector2, n: int = 4) -> void:
	burst(pos, n, [PixelArt.C["G"], PixelArt.C["K"], PixelArt.C["g"]], 5, 25, 0.5, 1.0, 2.0, -25.0, 1.5)


func fire(pos: Vector2, n: int = 3) -> void:
	burst(pos, n, [PixelArt.C["i"], PixelArt.C["I"], PixelArt.C["y"], PixelArt.C["r"]], 5, 30, 0.2, 0.45, 1.0, -60.0, 2.0)


func confetti(pos: Vector2, n: int = 24) -> void:
	burst(pos, n, [PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["Z"], PixelArt.C["v"]],
		60, 180, 0.5, 1.2, 1.0, 140.0, 2.5)


func explosion(pos: Vector2, radius: float, palette: String = "fire") -> void:
	var cols: Array
	match palette:
		"warp":
			cols = [PixelArt.C["z"], PixelArt.C["Z"], PixelArt.C["x"], Color.WHITE]
		"sneeze":
			cols = [PixelArt.C["t"], PixelArt.C["c"], PixelArt.C["w"], PixelArt.C["y"]]
		"steam":
			cols = [Color.WHITE, PixelArt.C["W"], PixelArt.C["a"]]
		_:
			cols = [PixelArt.C["I"], PixelArt.C["y"], PixelArt.C["i"], PixelArt.C["r"], Color.WHITE]
	burst(pos, int(radius * 1.2) + 8, cols, radius * 1.5, radius * 5.0, 0.2, 0.55, 2.0, 0.0, 5.0)
	smoke(pos, int(radius / 4.0) + 2)
	ring(pos, radius, cols[0], 0.25)
	flash(pos, randf() * TAU, radius * 0.9, cols[0], 0.08)


# ------------------------------------------------------------------ update / draw

func _process(delta: float) -> void:
	var i := 0
	while i < _count:
		_life[i] -= delta
		if _life[i] <= 0.0:
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
	_col[a] = _col[b]


func _draw() -> void:
	for i in _count:
		var c: Color = _col[i]
		var t := _life[i] / _max[i]
		if t < 0.3:
			c.a *= t / 0.3
		var s := _size[i]
		if t < 0.5 and s > 1.0:
			s -= 1.0
		draw_rect(Rect2(roundf(_px[i]), roundf(_py[i]), s, s), c)
	for r in _rings:
		var t: float = 1.0 - r["life"] / r["max"]
		var rad: float = lerpf(r["r0"], r["r1"], 1.0 - pow(1.0 - t, 2.0))
		var c: Color = r["color"]
		c.a = 1.0 - t
		PixelArt.draw_ring(self, r["pos"], rad, c)
	for b in _beams:
		var c: Color = b["color"]
		c.a = clampf(b["life"] / b["max"] * 1.5, 0.0, 1.0)
		draw_line(b["a"], b["b"], c, b["width"])
	for b in _bolts:
		var c: Color = b["color"]
		var glow := Color(c, 0.35)
		var pts: PackedVector2Array = b["points"]
		draw_polyline(pts, glow, 3.0)
		draw_polyline(pts, Color.WHITE if b["life"] > b["max"] * 0.5 else c, 1.0)
	for f in _flashes:
		_draw_flash(f)
	for tx in _texts:
		var t: float = 1.0 - tx["life"] / tx["max"]
		var c: Color = tx["color"]
		c.a = clampf(tx["life"] / tx["max"] * 2.0, 0.0, 1.0)
		var p: Vector2 = tx["pos"] - Vector2(0, tx["rise"] * (1.0 - pow(1.0 - t, 3.0)))
		PixelArt.draw_text_centered(self, p, tx["text"], c, true)


func _draw_flash(f: Dictionary) -> void:
	var pos: Vector2 = f["pos"]
	var s: float = f["size"] * (0.6 + 0.4 * f["life"] / f["max"])
	var rot: float = f["rot"]
	var c: Color = f["color"]
	# oversized 8-point star: long spike forward, shorter sides
	var pts := PackedVector2Array()
	var n := 8
	for k in n * 2:
		var a := rot + PI * k / n
		var r := s if k % 2 == 0 else s * 0.35
		if k == 0:
			r = s * 1.6
		pts.append(pos + Vector2.from_angle(a) * r)
	draw_colored_polygon(pts, c)
	PixelArt.draw_disk(self, pos, s * 0.45, Color.WHITE)
