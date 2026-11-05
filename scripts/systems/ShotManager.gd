class_name ShotManager
extends Node2D
## All projectiles (player, tower and rat) as lightweight data, collided against the
## arena's enemy spatial hash and drawn in a single _draw() pass.
##
## Straight shots:  fire(pos, vel, damage, {kind, team, pierce, life, radius, knockback, owner, burn, stun, color})
## Lobbed shots:    lob(from, to, duration, height, kind, on_land: Callable, {owner, ...})
##
## team 0 = hamsters (hit rats), team 1 = rats (hit mechs / towers / silo).

const TEAM_HAMSTER := 0
const TEAM_RAT := 1

class Shot:
	var pos: Vector2
	var prev: Vector2
	var vel: Vector2
	var life: float = 1.0
	var max_life: float = 1.0
	var damage: float = 1.0
	var radius: float = 2.0
	var pierce: int = 0
	var team: int = 0
	var kind: String = "pellet"
	var owner: Object = null
	var knockback: float = 0.0
	var burn: float = 0.0
	var stun: float = 0.0
	var color: Color = Color.WHITE
	var hit_ids: Array = []
	var spin: float = 0.0
	# lobbed
	var lob: bool = false
	var start: Vector2
	var target: Vector2
	var t: float = 0.0
	var duration: float = 1.0
	var height: float = 30.0
	var on_land: Callable

var shots: Array = []
var arena
var _tick := 0


func _ready() -> void:
	z_index = 6


func fire(pos: Vector2, vel: Vector2, damage: float, opts: Dictionary = {}) -> Shot:
	var s := Shot.new()
	s.pos = pos
	s.prev = pos
	s.vel = vel
	s.damage = damage
	s.kind = opts.get("kind", "pellet")
	s.team = opts.get("team", TEAM_HAMSTER)
	s.pierce = opts.get("pierce", 0)
	s.life = opts.get("life", 1.0)
	s.max_life = s.life
	s.radius = opts.get("radius", 2.0)
	s.knockback = opts.get("knockback", 0.0)
	s.owner = opts.get("owner", null)
	s.burn = opts.get("burn", 0.0)
	s.stun = opts.get("stun", 0.0)
	s.color = opts.get("color", Color.WHITE)
	s.spin = randf() * TAU
	shots.append(s)
	return s


func lob(from: Vector2, to: Vector2, duration: float, height: float, kind: String,
		on_land: Callable, opts: Dictionary = {}) -> Shot:
	var s := Shot.new()
	s.lob = true
	s.start = from
	s.target = to
	s.pos = from
	s.duration = maxf(0.05, duration)
	s.height = height
	s.kind = kind
	s.on_land = on_land
	s.team = opts.get("team", TEAM_HAMSTER)
	s.owner = opts.get("owner", null)
	s.color = opts.get("color", Color.WHITE)
	s.spin = randf() * TAU
	shots.append(s)
	return s


func clear_all() -> void:
	shots.clear()


func _physics_process(delta: float) -> void:
	_tick += 1
	var k := shots.size() - 1
	while k >= 0:
		var s: Shot = shots[k]
		var dead := false
		if s.lob:
			s.t += delta / s.duration
			s.spin += delta * 12.0
			s.pos = s.start.lerp(s.target, minf(s.t, 1.0))
			_lob_trail(s)
			if s.t >= 1.0:
				dead = true
				if s.on_land.is_valid():
					s.on_land.call(s.target)
		else:
			s.prev = s.pos
			s.pos += s.vel * delta
			s.life -= delta
			s.spin += delta * 20.0
			if s.life <= 0.0:
				dead = true
			elif is_instance_valid(arena) and arena.map.is_solid_at(s.pos):
				dead = true
				if is_instance_valid(arena):
					arena.fx.impact(s.prev, -s.vel.normalized(), Color8(200, 192, 178))
			elif s.team == TEAM_HAMSTER:
				if s.burn > 0.0 and _tick % 2 == 0 and is_instance_valid(arena):
					arena.fx.particle(s.pos - s.vel.normalized() * 3.0, Vector2(randf_range(-8, 8), -20), 0.25,
						PixelArt.C["I"], 1.0, -30.0, 2.0, FxManager.EMBER)
				dead = _collide_rats(s)
			else:
				dead = _collide_hamsters(s)
		if dead:
			shots.remove_at(k)
		k -= 1
	queue_redraw()


func _collide_rats(s: Shot) -> bool:
	if not is_instance_valid(arena):
		return false
	var near: Array = arena.enemies_in_radius(s.pos, s.radius + 14.0)
	for e in near:
		if not is_instance_valid(e) or not e.alive:
			continue
		var id: int = e.get_instance_id()
		if s.hit_ids.has(id):
			continue
		if s.pos.distance_to(e.global_position) > s.radius + e.radius:
			continue
		s.hit_ids.append(id)
		var info := {"owner": s.owner, "kind": s.kind, "burn": s.burn, "stun": s.stun}
		e.take_damage(s.damage, s.pos - s.vel.normalized() * 4.0, s.knockback, info)
		arena.fx.impact(s.pos, -s.vel.normalized(), Color8(255, 214, 64) if s.kind != "toothpick" else Color8(150, 220, 255))
		if s.pierce <= 0:
			return true
		s.pierce -= 1
	return false


func _collide_hamsters(s: Shot) -> bool:
	for p in GameManager.players:
		if not is_instance_valid(p) or p.downed:
			continue
		if s.pos.distance_to(p.global_position + Vector2(0, -8)) < s.radius + 8.0:
			p.take_damage(s.damage, s.pos - s.vel.normalized() * 6.0)
			arena.fx.sparks(s.pos, Color8(170, 255, 100), 5)
			return true
	for t in arena.towers:
		if not is_instance_valid(t) or not t.alive:
			continue
		if s.pos.distance_to(t.global_position + Vector2(0, -6)) < s.radius + 9.0:
			t.take_damage(s.damage, s.owner)
			arena.fx.sparks(s.pos, Color8(170, 255, 100), 5)
			return true
	if s.pos.distance_to(ArenaMap.SILO_CENTER) < ArenaMap.SILO_RADIUS:
		GameManager.damage_silo(s.damage)
		arena.on_silo_hit(s.pos)
		return true
	return false


## Cosmetic smoke/ember trails for lobbed shots (no gameplay effect).
func _lob_trail(s: Shot) -> void:
	if not is_instance_valid(arena) or _tick % 3 != 0:
		return
	var t := clampf(s.t, 0.0, 1.0)
	var air := s.pos - Vector2(0, sin(t * PI) * s.height)
	match s.kind:
		"mortar":
			arena.fx.particle(air, Vector2(randf_range(-6, 6), -8), 0.5, Color(0.9, 0.85, 0.75, 0.45), 1.0, -10.0, 2.0, FxManager.PUFF, 2.5)
		"gas_flask":
			arena.fx.particle(air, Vector2(randf_range(-6, 6), -10), 0.4, Color(0.4, 1.0, 0.3, 0.5), 1.0, -10.0, 2.0, FxManager.PUFF, 2.0)
		"seed_bomb":
			arena.fx.particle(air, Vector2.ZERO, 0.25, Color(1, 0.9, 0.5, 0.5), 1.0, 0.0, 0.0, FxManager.CROSS)
		"thrown_rat":
			if _tick % 6 == 0:
				arena.fx.particle(air, Vector2.ZERO, 0.3, Color(1, 1, 1, 0.6), 1.0, 0.0, 0.0, FxManager.CROSS)


func _draw() -> void:
	var tms := Time.get_ticks_msec() * 0.001
	for s in shots:
		var sh: Shot = s
		if sh.lob:
			_draw_lob(sh)
			continue
		var p := Vector2(roundf(sh.pos.x), roundf(sh.pos.y))
		var dir := sh.vel.normalized()
		var side := dir.orthogonal()
		match sh.kind:
			"pellet":
				var tone := Color8(255, 222, 170) if int(sh.spin) % 2 == 0 else Color8(210, 168, 110)
				draw_line((p - dir * 4.0).round(), p, Color(0.82, 0.66, 0.43, 0.35), 1.0)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), tone)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(1, 1)), Color8(255, 248, 231))
			"toothpick":
				# speed lines either side, glowing wake, wooden shaft, bright point
				var wake := Color(0.59, 0.86, 1.0, 0.3)
				draw_line((p - dir * 16.0).round(), (p - dir * 7.0).round(), wake, 1.0)
				if int(sh.spin) % 2 == 0:
					draw_line((p - dir * 13.0 + side * 2.0).round(), (p - dir * 8.0 + side * 2.0).round(), Color(1, 1, 1, 0.22), 1.0)
				else:
					draw_line((p - dir * 13.0 - side * 2.0).round(), (p - dir * 8.0 - side * 2.0).round(), Color(1, 1, 1, 0.22), 1.0)
				draw_line((p - dir * 7.0).round(), p, Color8(210, 168, 110), 1.0)
				draw_line((p - dir * 2.0).round(), (p + dir).round(), Color8(255, 248, 231), 1.0)
			"hull":
				if sh.burn > 0.0:
					var fl := int(tms * 30.0) % 2
					draw_rect(Rect2((p - dir * (3.0 + fl)).round(), Vector2(2, 2)), Color8(255, 120, 40))
					draw_rect(Rect2((p - dir * 6.0).round(), Vector2(1, 1)), Color8(255, 240, 120))
					draw_rect(Rect2((p - dir * 8.0 + side).round(), Vector2(1, 1)), Color8(226, 64, 64))
				_draw_seed(p, int(sh.spin * 0.7) % 4, Color8(46, 42, 48), Color8(236, 232, 214))
			"shrapnel":
				draw_line((p - dir * 6.0).round(), (p - dir).round(), Color(1, 1, 1, 0.35), 1.0)
				_draw_seed(p, int(sh.spin) % 4, Color8(46, 42, 48), Color8(236, 232, 214))
			"jezzail":
				var pulse := 0.5 + 0.5 * sin(tms * 40.0)
				draw_line((p - dir * 12.0).round(), p, Color(0.67, 1.0, 0.4, 0.3 + 0.2 * pulse), 3.0)
				draw_line((p - dir * 9.0).round(), (p + dir).round(), Color8(220, 255, 180), 1.0)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
				for k in 3:
					var dp := p - dir * (14.0 + k * 3.0) + side * float((k * 7 + int(sh.spin)) % 3 - 1)
					draw_rect(Rect2(dp.round(), Vector2(1, 1)), Color(0.67, 1.0, 0.4, 0.5 - k * 0.15))
			"warp_bolt":
				var r := 2.5 + 0.6 * sin(tms * 25.0)
				PixelArt.draw_disk(self, p, r + 1.0, Color(0.67, 1.0, 0.4, 0.25))
				PixelArt.draw_disk(self, p, r, Color(0.67, 1.0, 0.4, 0.6))
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
			_:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), sh.color)


## Tumbling striped seed/hull: 4 rotation frames, whole pixels only.
func _draw_seed(p: Vector2, frame: int, dark: Color, light: Color) -> void:
	match frame:
		0:
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 2)), dark)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), light)
		1:
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), dark)
			draw_rect(Rect2(p, Vector2(1, 1)), light)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), dark)
			draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 1)), dark)
		2:
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 3)), dark)
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), light)
		_:
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(1, 1)), dark)
			draw_rect(Rect2(p, Vector2(1, 1)), light)
			draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), dark)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), dark)


func _draw_lob(s: Shot) -> void:
	var t := clampf(s.t, 0.0, 1.0)
	var ground := Vector2(roundf(s.pos.x), roundf(s.pos.y))
	var up := sin(t * PI) * s.height
	var p := ground - Vector2(0, roundf(up))
	# shadow tightens and darkens as it falls
	var sw := roundf(2.0 + 4.0 * t)
	draw_rect(Rect2(ground.x - sw / 2.0, ground.y, sw, 1), Color(0, 0, 0, 0.2 + 0.25 * t))
	if t > 0.6:
		draw_rect(Rect2(ground.x - 1, ground.y, 2, 1), Color(0, 0, 0, 0.45))
	var frame := int(s.spin * 0.8) % 4
	match s.kind:
		"mortar":
			# tumbling cedar-shaving canister
			var body := Color8(150, 110, 64)
			var cap := Color8(210, 168, 110)
			var fuse := Color8(255, 222, 170)
			match frame:
				0:
					draw_rect(Rect2(p + Vector2(-2, -2), Vector2(4, 5)), body)
					draw_rect(Rect2(p + Vector2(-2, -2), Vector2(4, 1)), cap)
					draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 1)), fuse)
				1:
					draw_rect(Rect2(p + Vector2(-2, -1), Vector2(3, 3)), body)
					draw_rect(Rect2(p + Vector2(0, -2), Vector2(2, 2)), cap)
					draw_rect(Rect2(p + Vector2(2, -3), Vector2(1, 1)), fuse)
				2:
					draw_rect(Rect2(p + Vector2(-2, -1), Vector2(5, 4)), body)
					draw_rect(Rect2(p + Vector2(2, -1), Vector2(1, 4)), cap)
					draw_rect(Rect2(p + Vector2(3, 0), Vector2(1, 2)), fuse)
				_:
					draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 3)), body)
					draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 2)), cap)
					draw_rect(Rect2(p + Vector2(-2, 3), Vector2(1, 1)), fuse)
			if int(Time.get_ticks_msec() / 60) % 2 == 0:
				draw_rect(Rect2(p + Vector2(-1, -4), Vector2(1, 1)), Color8(255, 240, 120))
		"thrown_rat":
			var tex := PixelArt.tex("rat_squeaker_ball")
			draw_set_transform(p, float(frame) * PI * 0.5, Vector2.ONE)
			draw_texture(tex, (-tex.get_size() / 2).round())
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# motion arcs behind it
			var back := (s.start - s.target).normalized()
			for k in 3:
				draw_rect(Rect2((p + back * (7.0 + k * 3.0) + Vector2(0, k - 1)).round(), Vector2(1, 1)), Color(1, 1, 1, 0.5 - k * 0.15))
		"seed_bomb":
			_draw_seed(p, frame, PixelArt.C["s"], PixelArt.C["S"])
		"gas_flask":
			PixelArt.draw_disk(self, p, 2.5, Color8(70, 210, 60))
			draw_rect(Rect2(p + Vector2(-1, -1), Vector2(1, 1)), Color8(170, 255, 100))
			draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 2)), Color8(150, 110, 64))
		_:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), s.color)
