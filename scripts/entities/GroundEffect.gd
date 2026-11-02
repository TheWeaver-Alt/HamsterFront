class_name GroundEffect
extends Node2D
## Persistent ground hazards: Plague-Monk gas, gatling shell piles,
## and Wheeler-X burning rubber trails. Ticks at a fixed interval.

enum Kind { GAS, SHELLS, TRAIL }

var kind: int = Kind.GAS
var radius := 20.0
var life := 4.0
var max_life := 4.0
var power := 1.0
var source_pid := 0
var _tick := 0.0
var _t := 0.0
var _bits: Array = []


func setup(k: int, r: float, l: float, p: float, pid: int = 0) -> GroundEffect:
	kind = k
	radius = r
	life = l
	max_life = l
	power = p
	source_pid = pid
	return self


func _ready() -> void:
	z_index = -1
	_t = randf() * 10.0
	match kind:
		Kind.SHELLS:
			add_to_group("shell_piles")
			for i in 7:
				_bits.append(Vector3(randf_range(-radius * 0.7, radius * 0.7), randf_range(-radius * 0.45, radius * 0.45), randi() % 2))
		Kind.GAS:
			for i in 5:
				_bits.append(Vector3(randf_range(-radius * 0.5, radius * 0.5), randf_range(-radius * 0.3, radius * 0.3), randf_range(0.5, 1.0)))


func _physics_process(delta: float) -> void:
	life -= delta
	_t += delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		var interval := 0.5 if kind == Kind.GAS else 0.1
		_tick = interval
		_apply(interval)
	if kind != Kind.SHELLS or life < 1.5:
		queue_redraw()


func _apply(interval: float) -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	match kind:
		Kind.GAS:
			for t in arena.towers.values():
				var tp: Vector2 = t.global_position
				if tp.distance_to(global_position) <= radius + 8.0:
					t.add_corrode()
			for m in arena.mechs:
				if m.is_targetable():
					var mp: Vector2 = m.global_position
					if mp.distance_to(global_position) <= radius:
						m.take_damage(3.0 * power, self)
		Kind.SHELLS:
			var slow := GameManager.gmodf("shell_slow")
			var dmg := GameManager.gmodf("shell_damage")
			for r in arena.get_rats_in_radius(global_position, radius + 3.0):
				r.apply_slow(slow, 0.25)
				if dmg > 0.0:
					r.take_damage(dmg * interval, Vector2.ZERO, 0, false)
		Kind.TRAIL:
			for r in arena.get_rats_in_radius(global_position, radius + 3.0):
				r.take_damage(power * interval, Vector2.ZERO, source_pid, false)
			if randf() < 0.3:
				JuiceManager.particle(global_position + Vector2(randf_range(-3, 3), 0), Vector2(0, -20), Pal.FIRE, 0.35, 1.0)


func _draw() -> void:
	var fade := clampf(life / 1.5, 0.0, 1.0)
	match kind:
		Kind.GAS:
			for b in _bits:
				var v: Vector3 = b
				var off := Vector2(v.x + sin(_t * 1.7 + v.x) * 3.0, v.y + cos(_t * 1.3 + v.y) * 2.0)
				var c := Pal.GAS
				c.a *= fade
				draw_circle(off.round(), roundf(radius * 0.55 * v.z), c)
			var core := Color(Pal.WARP, 0.18 * fade)
			draw_circle(Vector2.ZERO, roundf(radius * 0.4), core)
		Kind.SHELLS:
			for b in _bits:
				var v: Vector3 = b
				var c := Color(Pal.SEED, fade)
				draw_rect(Rect2(roundf(v.x), roundf(v.y), 2, 1), c)
				if v.z > 0.5:
					draw_rect(Rect2(roundf(v.x) + 1, roundf(v.y) - 1, 1, 1), Color(Pal.SEED_STRIPE, fade))
		Kind.TRAIL:
			var t := life / max_life
			var c := Pal.INK.lerp(Pal.FIRE, t * 0.7)
			c.a = t * 0.85
			draw_rect(Rect2(-2, -1, 4, 3), c)
			if t > 0.5:
				draw_rect(Rect2(-1, -2 - roundf(sin(_t * 20.0)), 1, 1), Pal.FIRE_HOT)
