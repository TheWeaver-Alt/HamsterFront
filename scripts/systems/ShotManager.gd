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
	var k := shots.size() - 1
	while k >= 0:
		var s: Shot = shots[k]
		var dead := false
		if s.lob:
			s.t += delta / s.duration
			s.spin += delta * 12.0
			s.pos = s.start.lerp(s.target, minf(s.t, 1.0))
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
					arena.fx.sparks(s.prev, Color8(200, 192, 178), 3)
			elif s.team == TEAM_HAMSTER:
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
		arena.fx.sparks(s.pos, Color8(255, 214, 64) if s.kind != "toothpick" else Color8(150, 220, 255), 3, -s.vel.normalized())
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


func _draw() -> void:
	for s in shots:
		var sh: Shot = s
		if sh.lob:
			_draw_lob(sh)
			continue
		var p := Vector2(roundf(sh.pos.x), roundf(sh.pos.y))
		var dir := sh.vel.normalized()
		match sh.kind:
			"pellet":
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color8(255, 222, 170))
				draw_rect(Rect2(p - dir * 2.0, Vector2(1, 1)), Color8(210, 168, 110))
			"toothpick":
				draw_line(p - dir * 7.0, p, Color8(210, 168, 110), 1.0)
				draw_line(p - dir * 2.0, p + dir, Color8(255, 248, 231), 1.0)
				draw_line(p - dir * 14.0, p - dir * 7.0, Color(0.59, 0.86, 1.0, 0.35), 1.0)
			"hull":
				var c := Color8(46, 42, 48)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 2)), c)
				draw_rect(Rect2(p, Vector2(1, 1)), Color8(236, 232, 214))
				if sh.burn > 0.0:
					draw_rect(Rect2(p - dir * 3.0, Vector2(2, 2)), Color8(255, 120, 40))
					draw_rect(Rect2(p - dir * 5.0, Vector2(1, 1)), Color8(255, 240, 120))
			"shrapnel":
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color8(46, 42, 48))
				draw_rect(Rect2(p, Vector2(1, 1)), Color8(236, 232, 214))
				draw_line(p - dir * 5.0, p - dir, Color(1, 1, 1, 0.4), 1.0)
			"jezzail":
				draw_line(p - dir * 10.0, p, Color(0.67, 1.0, 0.4, 0.5), 3.0)
				draw_line(p - dir * 8.0, p + dir, Color8(220, 255, 180), 1.0)
			"warp_bolt":
				PixelArt.draw_disk(self, p, 2.5, Color(0.67, 1.0, 0.4, 0.6))
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
			_:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), sh.color)


func _draw_lob(s: Shot) -> void:
	var t := clampf(s.t, 0.0, 1.0)
	var ground := Vector2(roundf(s.pos.x), roundf(s.pos.y))
	var up := sin(t * PI) * s.height
	var p := ground - Vector2(0, roundf(up))
	# shadow grows as it falls
	var sw := 2.0 + 3.0 * t
	draw_rect(Rect2(ground.x - sw / 2, ground.y, sw, 1), Color(0, 0, 0, 0.35))
	match s.kind:
		"mortar":
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color8(150, 110, 64))
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 1)), Color8(210, 168, 110))
			draw_rect(Rect2(p + Vector2(-1, -3), Vector2(2, 1)), Color8(255, 222, 170))
		"thrown_rat":
			var tex := PixelArt.tex("rat_squeaker_ball")
			draw_set_transform(p, s.spin, Vector2.ONE)
			draw_texture(tex, -tex.get_size() / 2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"gas_flask":
			PixelArt.draw_disk(self, p, 2.5, Color8(70, 210, 60))
			draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 2)), Color8(150, 110, 64))
		_:
			draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), s.color)
