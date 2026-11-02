class_name FXLayer
extends Node2D
## Lightweight batched pixel particle system: squares, beams, rings,
## flashes and floating pixel-font text, all drawn in one _draw pass.

const MAX_PARTS := 1400


class FxPart:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var color := Color.WHITE
	var size := 2.0
	var grav := 0.0
	var drag := 0.0


class FxLine:
	var pts := PackedVector2Array()
	var life := 0.0
	var max_life := 0.1
	var color := Color.WHITE
	var width := 1.0


class FxRing:
	var pos := Vector2.ZERO
	var radius := 10.0
	var life := 0.0
	var max_life := 0.3
	var color := Color.WHITE


class FxFlash:
	var pos := Vector2.ZERO
	var radius := 6.0
	var life := 0.0
	var max_life := 0.06
	var color := Color.WHITE


class FxText:
	var pos := Vector2.ZERO
	var text := ""
	var life := 0.0
	var max_life := 0.8
	var color := Color.WHITE


var parts: Array = []
var lines: Array = []
var rings: Array = []
var flashes: Array = []
var texts: Array = []
var _was_drawing := false


func burst(pos: Vector2, color: Color, count: int = 8, speed: float = 60.0, life: float = 0.4,
		size: float = 2.0, grav: float = 0.0, dir: Vector2 = Vector2.ZERO, spread: float = TAU, drag: float = 3.0) -> void:
	for i in count:
		if parts.size() >= MAX_PARTS:
			return
		var p := FxPart.new()
		p.pos = pos
		var ang := randf() * TAU
		if dir != Vector2.ZERO:
			ang = dir.angle() + randf_range(-spread * 0.5, spread * 0.5)
		p.vel = Vector2.from_angle(ang) * speed * randf_range(0.35, 1.0)
		p.max_life = life * randf_range(0.6, 1.2)
		p.life = p.max_life
		p.color = color
		p.size = size
		p.grav = grav
		p.drag = drag
		parts.append(p)


func particle(pos: Vector2, vel: Vector2, color: Color, life: float, size: float = 2.0, grav: float = 0.0, drag: float = 0.0) -> void:
	if parts.size() >= MAX_PARTS:
		return
	var p := FxPart.new()
	p.pos = pos
	p.vel = vel
	p.max_life = life
	p.life = life
	p.color = color
	p.size = size
	p.grav = grav
	p.drag = drag
	parts.append(p)


func line(pts: PackedVector2Array, color: Color, width: float = 1.0, life: float = 0.08) -> void:
	var l := FxLine.new()
	l.pts = pts
	l.color = color
	l.width = width
	l.max_life = life
	l.life = life
	lines.append(l)


func ring(pos: Vector2, radius: float, color: Color, life: float = 0.3) -> void:
	var r := FxRing.new()
	r.pos = pos
	r.radius = radius
	r.color = color
	r.max_life = life
	r.life = life
	rings.append(r)


func flash(pos: Vector2, radius: float, color: Color, life: float = 0.06) -> void:
	var f := FxFlash.new()
	f.pos = pos
	f.radius = radius
	f.color = color
	f.max_life = life
	f.life = life
	flashes.append(f)


func text(pos: Vector2, txt: String, color: Color, life: float = 0.9) -> void:
	var t := FxText.new()
	t.pos = pos
	t.text = txt.to_upper()
	t.color = color
	t.max_life = life
	t.life = life
	texts.append(t)


func _process(delta: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var p: FxPart = parts[i]
		p.life -= delta
		if p.life <= 0.0:
			parts[i] = parts[parts.size() - 1]
			parts.pop_back()
		else:
			p.vel.y += p.grav * delta
			if p.drag > 0.0:
				p.vel *= maxf(0.0, 1.0 - p.drag * delta)
			p.pos += p.vel * delta
		i -= 1
	_age(lines, delta)
	_age(rings, delta)
	_age(flashes, delta)
	i = texts.size() - 1
	while i >= 0:
		var t: FxText = texts[i]
		t.life -= delta
		t.pos.y -= 18.0 * delta
		if t.life <= 0.0:
			texts.remove_at(i)
		i -= 1
	var drawing := not (parts.is_empty() and lines.is_empty() and rings.is_empty() and flashes.is_empty() and texts.is_empty())
	if drawing or _was_drawing:
		queue_redraw()
	_was_drawing = drawing


func _age(arr: Array, delta: float) -> void:
	var i := arr.size() - 1
	while i >= 0:
		var e = arr[i]
		e.life -= delta
		if e.life <= 0.0:
			arr.remove_at(i)
		i -= 1


func _draw() -> void:
	for f in flashes:
		var ff: FxFlash = f
		var t := ff.life / ff.max_life
		draw_circle(ff.pos.round(), maxf(1.0, roundf(ff.radius * (0.5 + 0.5 * t))), ff.color)
	for r in rings:
		var rr: FxRing = r
		var t := 1.0 - rr.life / rr.max_life
		var c := rr.color
		c.a *= 1.0 - t
		draw_arc(rr.pos.round(), maxf(1.0, rr.radius * t), 0.0, TAU, 20, c, 2.0)
	for l in lines:
		var ll: FxLine = l
		var c := ll.color
		c.a *= clampf(ll.life / ll.max_life * 1.5, 0.0, 1.0)
		if ll.pts.size() >= 2:
			draw_polyline(ll.pts, c, ll.width)
	for p in parts:
		var pp: FxPart = p
		var t := pp.life / pp.max_life
		var s := maxf(1.0, roundf(pp.size * (0.4 + 0.6 * t)))
		var c := pp.color
		c.a *= minf(1.0, t * 2.5)
		draw_rect(Rect2(floorf(pp.pos.x - s * 0.5), floorf(pp.pos.y - s * 0.5), s, s), c)
	for tx in texts:
		var tt: FxText = tx
		var c := tt.color
		c.a = minf(1.0, tt.life / tt.max_life * 2.0)
		PixelFont.draw_centered(self, tt.text, tt.pos, c, 1, Color(0, 0, 0, c.a * 0.8))
