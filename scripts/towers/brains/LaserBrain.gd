extends TowerBrain
## Water-Bottle Laser: the metal ball-bearing dripper tube refracts sunlight into a continuous,
## armour-melting beam. Locks onto one rat and ramps damage the longer it holds it (up to 2.5x).
## Mutation "laser_split": a beam that passes through a friendly mech refracts into 3 beams.

const BASE_DPS := 20.0
const RAMP_TIME := 2.0
const RAMP_MAX := 2.5
const TICK := 0.1
const SPLIT_RADIUS := 110.0
const MECH_HIT := 10.0

var _target = null
var _on_t := 0.0
var _tick := 0.0
var _loud_tick := 0
var _sfx_t := 0.0
var _aim := Vector2(0.6, 0.8)
var _segments: Array = []     # [Vector2 a, Vector2 b] in world space
var _impacts: Array = []      # Vector2 world points
var _layer: Node2D
var _t := 0.0
var _bubbles: Array = []      # [x, y] in bottle-image pixels, rising
var _bubble_cd := 0.0
var _glint_t := 3.0           # idle sun glint sweeping across the bottle
var _had_beam := false
const WARMUP := 0.35


func setup(t: TowerBase) -> void:
	super.setup(t)
	_layer = tower.add_fx_layer(_draw_beams)


func debris_texture() -> Texture2D:
	return PixelArt.tex("tower_laser_%d_0" % tower.level)


func _emitter_cap() -> Vector2:
	return tower.global_position + Vector2(0.0, -6.0)


func _emitter() -> Vector2:
	return _emitter_cap() + _aim * 5.0


func _valid(e) -> bool:
	return e != null and is_instance_valid(e) and e.alive and e.spawn_t <= 0.0 \
		and tower.global_position.distance_to(e.global_position) <= tower.range_radius() + e.radius


func physics(delta: float) -> void:
	_t += delta
	_tick_bubbles(delta)
	_segments.clear()
	_impacts.clear()
	if not _valid(_target):
		_target = tower.best_target("first")
		_on_t = 0.0
	if _target == null:
		_aim = _aim.lerp(Vector2(0.6 + sin(_t) * 0.3, 0.8).normalized(), minf(1.0, delta * 3.0))
		if _had_beam:
			_had_beam = false
			_layer.queue_redraw()
		return
	_had_beam = true
	_on_t += delta
	var end: Vector2 = _target.global_position + Vector2(0, -4)
	_aim = _aim.lerp((end - _emitter_cap()).normalized(), minf(1.0, delta * 18.0)).normalized()
	var origin := _emitter()
	var ramp := 1.0 + (RAMP_MAX - 1.0) * clampf(_on_t / RAMP_TIME, 0.0, 1.0)
	var victims: Array = []
	# primary beam (possibly refracted through a friendly mech)
	_trace(origin, _target, victims)
	# extra beams from the laser_beams stat (base 1)
	var extra := int(GameManager.gstats.g("laser_beams", 1.0)) - 1
	if extra > 0:
		var pool: Array = tower.get_targets()
		pool.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
		for e in pool:
			if extra <= 0:
				break
			if e == _target or victims.has(e):
				continue
			_trace(origin, e, victims)
			extra -= 1
	# damage in small ticks
	_tick += delta
	while _tick >= TICK:
		_tick -= TICK
		_loud_tick += 1
		var dmg := BASE_DPS * tower.damage_mult() * ramp * TICK
		for v in victims:
			if is_instance_valid(v) and v.alive:
				v.take_damage(dmg, origin, 0.0, {"melt": 0.5, "quiet": _loud_tick % 3 != 0,
					"owner": tower, "kind": "laser"})
	# fx + sfx
	_sfx_t -= delta
	if _sfx_t <= 0.0:
		_sfx_t = 0.3
		Sfx.play("laser", 0.9 + ramp * 0.15, -16.0)
	if randf() < 0.35 and _impacts.size() > 0:
		var ip: Vector2 = _impacts[randi() % _impacts.size()]
		GameManager.arena.fx.sparks(ip, Color8(150, 220, 255) if not tower.is_overdrive() else _rainbow(randf()), 2)
	_layer.queue_redraw()


## Adds the beam from `from` to target `e`, refracting through a mech when the mutation is owned.
func _trace(from: Vector2, e, victims: Array) -> void:
	var end: Vector2 = e.global_position + Vector2(0, -4)
	if GameManager.gstats.has_flag("laser_split"):
		for p in GameManager.living_players():
			var body: Vector2 = p.global_position + Vector2(0, -12)
			if from.distance_to(body) < from.distance_to(end) and _seg_dist(body, from, end) < MECH_HIT:
				_segments.append([from, body])
				_impacts.append(body)
				var near: Array = GameManager.arena.enemies_in_radius(body, SPLIT_RADIUS)
				near.sort_custom(func(a, b): return body.distance_squared_to(a.global_position) < body.distance_squared_to(b.global_position))
				var n := 0
				for r in near:
					if n >= 3:
						break
					if not is_instance_valid(r) or not r.alive or r.spawn_t > 0.0:
						continue
					var rp: Vector2 = r.global_position + Vector2(0, -4)
					_segments.append([body, rp])
					_impacts.append(rp)
					if not victims.has(r):
						victims.append(r)
					n += 1
				if randf() < 0.2:
					GameManager.arena.fx.sparks(body, Color8(255, 248, 231), 3)
				return
	_segments.append([from, end])
	_impacts.append(end)
	if not victims.has(e):
		victims.append(e)


## Bubbles rise through the water; faster and more of them while the beam is on.
func _tick_bubbles(delta: float) -> void:
	var beaming := _target != null
	_bubble_cd -= delta * (3.0 if beaming else 1.0)
	if _bubble_cd <= 0.0 and _bubbles.size() < 6:
		_bubble_cd = randf_range(0.35, 0.9)
		_bubbles.append([float(randi_range(6, 11)), 19.0])
	var k := _bubbles.size() - 1
	while k >= 0:
		var b: Array = _bubbles[k]
		b[1] = float(b[1]) - delta * (14.0 if beaming else 7.0)
		b[0] = float(b[0]) + sin(_t * 9.0 + k) * delta * 3.0
		if float(b[1]) < 10.0:
			_bubbles.remove_at(k)
		k -= 1
	_glint_t -= delta
	if _glint_t < -0.5:
		_glint_t = randf_range(2.5, 5.0)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _rainbow(offset: float) -> Color:
	return Color.from_hsv(fmod(_t * 1.5 + offset, 1.0), 0.65, 1.0)


func _draw_beams() -> void:
	if _segments.is_empty():
		return
	var origin := tower.global_position
	var od := tower.is_overdrive()
	var pulse := 0.5 + 0.5 * sin(_t * 30.0)
	var ramp := clampf(_on_t / RAMP_TIME, 0.0, 1.0)
	var warm := clampf(_on_t / WARMUP, 0.0, 1.0)
	# during warm-up the beam flickers in thin before it locks to full strength
	if warm < 1.0 and int(_t * 40.0) % 3 == 0:
		return
	var i := 0
	for seg in _segments:
		var a: Vector2 = seg[0] - origin
		var b: Vector2 = seg[1] - origin
		var glow := Color(0.59, 0.86, 1.0, (0.38 + 0.15 * pulse) * warm)
		if od:
			glow = _rainbow(i * 0.2)
			glow.a = 0.5
		var w := (3.0 + ramp * 2.0 + (1.0 if od else 0.0)) * lerpf(0.4, 1.0, warm)
		_layer.draw_line(a, b, glow, w)
		_layer.draw_line(a, b, Color(0.8, 0.96, 1.0, 0.75 * warm), maxf(1.0, 2.0 * warm))
		# wobbling white-hot core
		var core := Color8(255, 255, 230)
		var n := (b - a).orthogonal().normalized()
		var steps := maxi(2, int(a.distance_to(b) / 6.0))
		var pts := PackedVector2Array()
		for s2 in steps + 1:
			var t := float(s2) / steps
			var wob := sin(_t * 40.0 + s2 * 1.7 + i) * 0.6 if s2 > 0 and s2 < steps else 0.0
			pts.append((a.lerp(b, t) + n * wob).round())
		_layer.draw_polyline(pts, core, 1.0 if not od else 2.0)
		# heat shimmer: faint pixels wavering either side of the beam
		if warm >= 1.0:
			var len_px := a.distance_to(b)
			for h in int(len_px / 9.0):
				var t2 := fmod(h * 0.137 + _t * 0.6, 1.0)
				var side := 1.0 if h % 2 == 0 else -1.0
				var off := side * (2.5 + ramp * 1.5 + sin(_t * 17.0 + h * 2.3) * 1.2)
				var hp := (a.lerp(b, t2) + n * off).round()
				_layer.draw_rect(Rect2(hp, Vector2(1, 1)), Color(1, 1, 0.9, 0.22 + 0.18 * ramp))
		i += 1
	for ip in _impacts:
		var p: Vector2 = (ip - origin).round()
		var s := (2.0 + pulse * 2.0) * warm
		var c := Color8(255, 255, 230) if not od else _rainbow(0.5)
		_layer.draw_rect(Rect2(p - Vector2(s, 0), Vector2(s * 2 + 1, 1)), Color(c, 0.85))
		_layer.draw_rect(Rect2(p - Vector2(0, s), Vector2(1, s * 2 + 1)), Color(c, 0.85))
		PixelArt.draw_disk(_layer, p, 1.5 + pulse, Color(1, 1, 1, 0.9))
		# scorch dot on the target
		_layer.draw_rect(Rect2(p + Vector2(-1, 2), Vector2(3, 1)), Color(1.0, 0.5, 0.2, 0.5 * ramp))


func draw(ci: Node2D) -> void:
	var beaming := not _segments.is_empty()
	# water sloshes: lazily when idle, eagerly while beaming
	var slosh: int = [0, 1, 0, 2][int(_t * (7.0 if beaming else 2.0)) % 4]
	var bx := -9.0
	var by := -30.0
	ci.draw_texture(PixelArt.tex("tower_laser_%d_%d" % [tower.level, slosh]), Vector2(bx, by))
	# rising bubbles inside the bottle
	for b in _bubbles:
		ci.draw_rect(Rect2(Vector2(bx + roundf(float(b[0])), by + roundf(float(b[1]))), Vector2(1, 1)), Color(1, 1, 1, 0.8))
	# idle sun glint sweeping down the plastic
	if _glint_t < 0.0:
		var gy := by + 4.0 + (-_glint_t / 0.5) * 14.0
		ci.draw_rect(Rect2(bx + 5, roundf(gy), 1, 2), Color(1, 1, 1, 0.9))
		ci.draw_rect(Rect2(bx + 6, roundf(gy) + 1, 1, 1), Color(1, 1, 1, 0.5))
	# swivelling metal dripper tube + ball bearing catching the sun
	var cap := Vector2(0.0, -6.0)
	var tip := cap + _aim * 6.0
	ci.draw_line(cap.round(), tip.round(), PixelArt.C["G"], 2.0)
	ci.draw_line(cap.round(), tip.round(), PixelArt.C["W"], 1.0)
	var tp := tip.round()
	ci.draw_rect(Rect2(tp - Vector2(1, 1), Vector2(3, 3)), PixelArt.C["g"])
	ci.draw_rect(Rect2(tp - Vector2(1, 1), Vector2(2, 2)), PixelArt.C["W"])
	ci.draw_rect(Rect2(tp - Vector2(1, 1), Vector2(1, 1)), Color.WHITE)
	if beaming:
		var warm := clampf(_on_t / WARMUP, 0.0, 1.0)
		if warm < 1.0:
			# sunlight motes converge into the bearing
			for k in 4:
				var a := _t * 9.0 + k * TAU / 4.0
				var mp := tip + Vector2.from_angle(a) * (10.0 * (1.0 - warm) + 1.0)
				ci.draw_rect(Rect2(mp.round(), Vector2(1, 1)), Color(1, 1, 0.75, 0.9))
		else:
			# 4-point star glint on the bearing
			var arm := 2.0 + roundf(sin(_t * 18.0) * 1.0)
			var gc := Color(1, 1, 0.85, 0.85)
			ci.draw_rect(Rect2(tp.x - arm, tp.y, arm * 2.0 + 1.0, 1), gc)
			ci.draw_rect(Rect2(tp.x, tp.y - arm, 1, arm * 2.0 + 1.0), gc)
		# ramp gauge: the label glows brighter the longer the beam holds
		var r := clampf(_on_t / RAMP_TIME, 0.0, 1.0)
		ci.draw_rect(Rect2(bx + 5, by + 12, 8, 1), Color(1, 1, 0.7, 0.2 + 0.6 * r))
	if tower.is_overdrive():
		ci.draw_rect(Rect2(bx + 5, by + 8 + roundf(sin(_t * 9.0) * 2.0), 8, 1), _rainbow(0.0))
