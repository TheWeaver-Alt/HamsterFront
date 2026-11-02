class_name SeedManager
extends Node2D
## Dropped sunflower seeds. They pop out of dead rats, bounce, then get vacuumed
## into the nearest mech's cheek pouch (if it has room).

const MAX_SEEDS := 450
const LIFETIME := 24.0
const COLLECT_DIST := 6.0

class Seed:
	var pos: Vector2
	var vel: Vector2
	var z: float = 0.0
	var vz: float = 0.0
	var life: float = LIFETIME
	var horizontal: bool = false
	var magnet = null
	# cosmetic
	var spin: float = 0.0
	var phase: float = 0.0
	var squash: float = 0.0

var seeds: Array = []
var arena


func _ready() -> void:
	z_index = 0


func spawn(pos: Vector2, count: int, speed: float = 70.0) -> void:
	for i in count:
		if seeds.size() >= MAX_SEEDS:
			seeds.pop_front()
		var s := Seed.new()
		s.pos = pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		s.vel = Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed)
		s.vz = randf_range(60, 120)
		s.horizontal = randf() < 0.5
		s.spin = randf_range(14.0, 26.0) * (1.0 if randf() < 0.5 else -1.0)
		s.phase = randf() * 100.0
		seeds.append(s)


func _physics_process(delta: float) -> void:
	var players: Array = GameManager.players
	var k := seeds.size() - 1
	while k >= 0:
		var s: Seed = seeds[k]
		s.life -= delta
		if s.life <= 0.0:
			seeds.remove_at(k)
			k -= 1
			continue
		# pop & bounce
		if s.z > 0.0 or s.vz > 0.0:
			s.vz -= 380.0 * delta
			s.z += s.vz * delta
			if s.z <= 0.0:
				s.z = 0.0
				s.squash = 1.0
				s.vz = -s.vz * 0.35 if absf(s.vz) > 30.0 else 0.0
		s.vel *= maxf(0.0, 1.0 - 5.0 * delta)
		# magnet towards nearest mech with pouch space
		var target = null
		var best := INF
		for p in players:
			if not is_instance_valid(p) or p.downed or p.pouch.space() <= 0:
				continue
			var r: float = p.stats.g("pickup_radius")
			var d: float = s.pos.distance_to(p.global_position)
			if d < r and d < best:
				best = d
				target = p
		s.magnet = target
		if target != null:
			var to: Vector2 = target.global_position + Vector2(0, -6) - s.pos
			var pull := 140.0 + (1.0 - clampf(best / 60.0, 0.0, 1.0)) * 220.0
			s.vel = s.vel.lerp(to.normalized() * pull, minf(1.0, 10.0 * delta))
			if to.length() < COLLECT_DIST:
				_collect(target)
				seeds.remove_at(k)
				k -= 1
				continue
		s.pos += s.vel * delta
		if is_instance_valid(arena) and arena.map.is_solid_at(s.pos):
			s.pos -= s.vel * delta
			s.vel = -s.vel * 0.3
		k -= 1
	queue_redraw()


func _collect(p) -> void:
	var added: int = p.pouch.add(1)
	if added > 0:
		if is_instance_valid(arena) and randf() < 0.5:
			arena.fx.particle(p.global_position + Vector2(randf_range(-4, 4), -14), Vector2(0, -12), 0.18,
				Color8(255, 248, 231), 1.0, 0.0, 2.0, FxManager.CROSS)
		Sfx.play("pickup", randf_range(0.9, 1.3) + p.pouch.fill() * 0.6, -12.0)
		# Communal Cheeks synergy: partner gets a trickle too
		if GameManager.gstats.has_flag("shared_cheeks") and randf() < 0.5:
			for other in GameManager.players:
				if other != p and is_instance_valid(other) and not other.downed:
					other.pouch.add(1)


func _draw() -> void:
	var tv := PixelArt.tex("seed")
	var th := PixelArt.tex("seed_h")
	var shadow := Color(0, 0, 0, 0.25)
	var dark := PixelArt.C["s"]
	var light := PixelArt.C["S"]
	var tms := Time.get_ticks_msec() * 0.001
	var dt := get_process_delta_time()
	for s in seeds:
		var sd: Seed = s
		if sd.life < 5.0 and int(sd.life * 8.0) % 2 == 0:
			continue
		sd.squash = maxf(0.0, sd.squash - dt * 6.0)
		var p := Vector2(roundf(sd.pos.x), roundf(sd.pos.y))
		var airborne := sd.z > 0.5
		if airborne:
			var sw := 3.0 if sd.z < 8.0 else 2.0
			draw_rect(Rect2(p.x - 1, p.y + 1, sw, 1), shadow)
		if sd.magnet != null and sd.vel.length() > 60.0:
			# vacuum streak
			var back := -sd.vel.normalized()
			draw_line(p + back, (p + back * 5.0).round(), Color(1, 1, 1, 0.35), 1.0)
		var top := p - Vector2(0, roundf(sd.z))
		if airborne or sd.magnet != null:
			# tumbling: 4 whole-pixel rotation frames
			var f := int(absf(tms * sd.spin + sd.phase)) % 4
			_seed_frame(top, f, dark, light)
		elif sd.squash > 0.3:
			# landing squash: a flat 4x1 splat for a beat
			draw_rect(Rect2(top + Vector2(-2, 1), Vector2(4, 1)), dark)
			draw_rect(Rect2(top + Vector2(-1, 0), Vector2(2, 1)), light)
		else:
			var t := th if sd.horizontal else tv
			draw_texture(t, top - Vector2(t.get_width() / 2, t.get_height() / 2))
			# occasional glint so loose seeds catch the eye
			var g := fmod(tms * 0.7 + sd.phase, 3.0)
			if g < 0.12:
				var gc := Color(1, 1, 0.85, 1.0 - g / 0.12)
				draw_rect(Rect2(top + Vector2(0, -2), Vector2(1, 1)), gc)
				if g < 0.06:
					draw_rect(Rect2(top + Vector2(-1, -2), Vector2(3, 1)), Color(gc, gc.a * 0.5))
					draw_rect(Rect2(top + Vector2(0, -3), Vector2(1, 3)), Color(gc, gc.a * 0.5))


func _seed_frame(p: Vector2, f: int, dark: Color, light: Color) -> void:
	match f:
		0:
			draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 5)), dark)
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), dark)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), light)
		1:
			for k in 4:
				draw_rect(Rect2(p + Vector2(k - 2, 1 - k), Vector2(2, 1)), dark)
			draw_rect(Rect2(p + Vector2(0, 0), Vector2(1, 1)), light)
		2:
			draw_rect(Rect2(p + Vector2(-2, 0), Vector2(5, 1)), dark)
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), dark)
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), light)
		_:
			for k in 4:
				draw_rect(Rect2(p + Vector2(k - 2, k - 2), Vector2(2, 1)), dark)
			draw_rect(Rect2(p + Vector2(0, 0), Vector2(1, 1)), light)
