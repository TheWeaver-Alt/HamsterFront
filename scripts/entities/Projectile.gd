class_name Projectile
extends Node2D
## Simple manually-integrated projectile (pellets, hulls, spit seeds, jezzail bolts).
## Player projectiles query the arena's rat spatial hash; enemy ones hit mechs/towers/silo.

var from_player := true
var vel := Vector2.ZERO
var damage := 5.0
var radius := 2.0
var pierce := 0
var life := 1.0
var knock := 0.0
var style := "pellet"
var burn_dps := 0.0
var stun := 0.0
var shell_chance := 0.0
var source_pid := 0
var _hit: Array = []
var _spin := 0.0


func configure(pos: Vector2, v: Vector2, dmg: float, sty: String, player_team: bool = true, pid: int = 0) -> Projectile:
	position = pos
	vel = v
	damage = dmg
	style = sty
	from_player = player_team
	source_pid = pid
	return self


func _physics_process(delta: float) -> void:
	var arena = GameManager.arena
	if arena == null:
		queue_free()
		return
	position += vel * delta
	life -= delta
	_spin += delta * 20.0
	if life <= 0.0 or not arena.arena_rect().has_point(position):
		queue_free()
		return
	if arena.is_solid_world(position):
		_impact()
		return
	if from_player:
		_check_rats(arena)
	else:
		_check_targets(arena)
	queue_redraw()


func _check_rats(arena) -> void:
	for r in arena.get_rats_in_radius(position, radius + 12.0):
		if r.dead or r.flying or r in _hit:
			continue
		var rp: Vector2 = r.global_position
		if position.distance_to(rp) > radius + float(r.hit_radius):
			continue
		_hit.append(r)
		r.take_damage(damage, vel.normalized() * knock, source_pid)
		if burn_dps > 0.0:
			r.apply_burn(burn_dps, 3.0)
		if stun > 0.0:
			r.apply_stun(stun)
		if shell_chance > 0.0 and randf() < shell_chance:
			arena.spawn_ground(GroundEffect.Kind.SHELLS, position, 9.0, 10.0, 1.0)
		pierce -= 1
		if pierce < 0:
			_impact()
			return


func _check_targets(arena) -> void:
	for m in arena.mechs:
		if not m.is_targetable():
			continue
		var mp: Vector2 = m.global_position
		if position.distance_to(mp) <= radius + 7.0:
			m.take_damage(damage, self)
			_impact()
			return
	var t = arena.tower_at_world(position)
	if t != null:
		t.take_damage(damage, self)
		_impact()
		return
	if arena.silo.contains_point(position):
		arena.silo.take_damage(damage, self)
		_impact()


func _impact() -> void:
	var c := Pal.CARDBOARD
	match style:
		"jezzail":
			c = Pal.WARP
			JuiceManager.burst(position, c, 8, 70.0, 0.3, 2.0, 0.0, true)
		"hull":
			c = Pal.FIRE if burn_dps > 0.0 else Pal.SEED_STRIPE
			JuiceManager.burst(position, c, 2, 40.0, 0.2, 1.0)
		"seed":
			JuiceManager.burst(position, Pal.SEED, 2, 40.0, 0.25, 1.0)
		_:
			JuiceManager.burst(position, Pal.CEDAR, 2, 40.0, 0.2, 1.0)
	queue_free()


func _draw() -> void:
	var d := vel.normalized()
	match style:
		"pellet":
			draw_line(Vector2.ZERO, (-d * 4.0).round(), Color(Pal.CEDAR, 0.6), 1.0)
			draw_rect(Rect2(-1, -1, 2, 2), Pal.SNEEZE)
		"hull":
			var hc := Pal.FIRE if burn_dps > 0.0 else Pal.SEED
			draw_rect(Rect2(-1, -1, 3, 2), hc)
			draw_rect(Rect2(0, -1, 1, 1), Pal.FIRE_HOT if burn_dps > 0.0 else Pal.SEED_STRIPE)
		"seed":
			var a := Vector2.from_angle(_spin)
			draw_line((-a * 2.0).round(), (a * 2.0).round(), Pal.SEED, 2.0)
			draw_rect(Rect2(0, 0, 1, 1), Pal.SEED_STRIPE)
		"jezzail":
			draw_line(Vector2.ZERO, (-d * 7.0).round(), Pal.WARP, 2.0)
			draw_rect(Rect2(-1, -1, 2, 2), Pal.WHITE)
		"shard":
			draw_rect(Rect2(-1, -1, 3, 3), Pal.CARDBOARD)
		_:
			draw_rect(Rect2(-1, -1, 2, 2), Pal.WHITE)
