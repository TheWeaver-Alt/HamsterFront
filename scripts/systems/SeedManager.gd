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
	var magnet: Node2D = null

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
	for s in seeds:
		var sd: Seed = s
		if sd.life < 5.0 and int(sd.life * 8.0) % 2 == 0:
			continue
		var p := Vector2(roundf(sd.pos.x), roundf(sd.pos.y))
		if sd.z > 0.5:
			draw_rect(Rect2(p.x - 1, p.y + 1, 3, 1), shadow)
		var t := th if sd.horizontal else tv
		draw_texture(t, p - Vector2(t.get_width() / 2, t.get_height() / 2 + roundf(sd.z)))
