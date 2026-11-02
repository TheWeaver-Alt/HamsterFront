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


func setup(t: TowerBase) -> void:
	super.setup(t)
	_layer = tower.add_fx_layer(_draw_beams)


func _emitter_cap() -> Vector2:
	return tower.global_position + Vector2(-0.5, -6.0)


func _emitter() -> Vector2:
	return _emitter_cap() + _aim * 5.0


func _valid(e) -> bool:
	return e != null and is_instance_valid(e) and e.alive and e.spawn_t <= 0.0 \
		and tower.global_position.distance_to(e.global_position) <= tower.range_radius() + e.radius


func physics(delta: float) -> void:
	_t += delta
	_segments.clear()
	_impacts.clear()
	if not _valid(_target):
		_target = tower.best_target("first")
		_on_t = 0.0
	if _target == null:
		_aim = _aim.lerp(Vector2(0.6 + sin(_t) * 0.3, 0.8).normalized(), minf(1.0, delta * 3.0))
		_layer.queue_redraw()
		return
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
	var i := 0
	for seg in _segments:
		var a: Vector2 = seg[0] - origin
		var b: Vector2 = seg[1] - origin
		var glow := Color(0.59, 0.86, 1.0, 0.38 + 0.15 * pulse)
		if od:
			glow = _rainbow(i * 0.2)
			glow.a = 0.5
		var w := 3.0 + ramp * 2.0 + (1.0 if od else 0.0)
		_layer.draw_line(a, b, glow, w)
		_layer.draw_line(a, b, Color(0.8, 0.96, 1.0, 0.75), 2.0)
		# wobbling core
		var core := Color8(255, 255, 230)
		var n := (b - a).orthogonal().normalized()
		var steps := maxi(2, int(a.distance_to(b) / 6.0))
		var pts := PackedVector2Array()
		for s in steps + 1:
			var t := float(s) / steps
			var wob := sin(_t * 40.0 + s * 1.7 + i) * 0.6 if s > 0 and s < steps else 0.0
			pts.append((a.lerp(b, t) + n * wob).round())
		_layer.draw_polyline(pts, core, 1.0 if not od else 2.0)
		i += 1
	for ip in _impacts:
		var p: Vector2 = (ip - origin).round()
		var s := 2.0 + pulse * 2.0
		var c := Color8(255, 255, 230) if not od else _rainbow(0.5)
		_layer.draw_rect(Rect2(p - Vector2(s, 0), Vector2(s * 2 + 1, 1)), Color(c, 0.85))
		_layer.draw_rect(Rect2(p - Vector2(0, s), Vector2(1, s * 2 + 1)), Color(c, 0.85))
		PixelArt.draw_disk(_layer, p, 1.5 + pulse, Color(1, 1, 1, 0.9))


func draw(ci: Node2D) -> void:
	ci.draw_texture(PixelArt.tex("tower_laser_%d" % tower.level), Vector2(-8, -26))
	# swivelling dripper tube + ball bearing
	var cap := Vector2(-0.5, -6.0)
	var tip := cap + _aim * 5.0
	ci.draw_line(cap.round(), tip.round(), PixelArt.C["g"], 2.0)
	ci.draw_line(cap.round(), tip.round(), PixelArt.C["W"], 1.0)
	ci.draw_rect(Rect2(tip.round() - Vector2(1, 1), Vector2(2, 2)), PixelArt.C["W"])
	ci.draw_rect(Rect2(tip.round() - Vector2(1, 1), Vector2(1, 1)), Color.WHITE)
	# sun glint on the bottle while beaming
	if not _segments.is_empty() and int(_t * 8.0) % 2 == 0:
		ci.draw_rect(Rect2(-3, -24, 1, 1), Color.WHITE)
		ci.draw_rect(Rect2(-4, -23, 3, 1), Color(1, 1, 0.8, 0.8))
	# ramp gauge: water glows brighter the longer the beam holds
	if _on_t > 0.0 and not _segments.is_empty():
		var r := clampf(_on_t / RAMP_TIME, 0.0, 1.0)
		ci.draw_rect(Rect2(-3, -16, 6, 1), Color(1, 1, 0.7, 0.25 + 0.5 * r))
	if tower.is_overdrive():
		ci.draw_rect(Rect2(-3, -20 + roundf(sin(_t * 9.0) * 2.0), 6, 1), _rainbow(0.0))
