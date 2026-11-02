class_name RatEnemy
extends CharacterBody2D
## The Under-Scurriers. One script, five behaviours:
## Clan-Squeaker (swarm), Warp-Gouda Jezzail (2-rat sniper), Plague-Stink Monk (gas),
## Doom-Roomba (bouncing siege engine) and Rat-Ogre Bruiser (throws Squeakers).
## Walkers follow the arena flow field toward the Silo, chewing any tower that blocks it.

const DECOY_TAUNT := 85.0
const FLIGHT_TIME := 0.8

var kind: int = Defs.Rat.SQUEAKER
var hp := 10.0
var max_hp := 10.0
var speed := 40.0
var dmg := 4.0
var attack_rate := 1.0
var attack_range := 6.0
var hit_radius := 4.0
var seed_value := 1
var bubble_height := 12.0
var dead := false
var flying := false

# Status effects.
var stun_t := 0.0
var slow_factor := 0.0
var slow_t := 0.0
var burn_dps := 0.0
var burn_t := 0.0
var knock_vel := Vector2.ZERO
var flash_t := 0.0
var trip_t := 0.0

# Behaviour state.
var attack_cd := 0.0
var attack_anim := 0.0
var target: Node2D = null
var anim_t := 0.0
var face := 1.0
var aim_t := 0.0
var aim_target: Node2D = null
var aim_point := Vector2.ZERO
var gas_cd := 2.0
var throw_cd := 3.0
var roam_dir := Vector2.RIGHT
var turn_t := 2.0
var zap_cd := 2.0
var _contact: Dictionary = {}
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO
var _fly_t := 0.0
var _retarget_t := 0.0
var _crowd := 0
var _trip_roll_t := 1.0
var _burn_fx_t := 0.0

@onready var shape_node: CollisionShape2D = $CollisionShape2D


func setup(k: int, hp_mult: float) -> RatEnemy:
	kind = k
	var d: Dictionary = Defs.RAT_DATA[k]
	max_hp = float(d["hp"]) * hp_mult
	hp = max_hp
	speed = float(d["speed"])
	dmg = float(d["dmg"]) * (1.0 + (hp_mult - 1.0) * 0.5)
	attack_rate = float(d["rate"])
	attack_range = float(d["range"])
	hit_radius = float(d["radius"])
	seed_value = int(d["seeds"])
	bubble_height = float(d["bubble"])
	return self


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Defs.L_RAT
	collision_mask = Defs.L_WORLD | Defs.L_TOWER | Defs.L_SILO
	var sh := CircleShape2D.new()
	sh.radius = maxf(2.0, hit_radius - 1.0)
	shape_node.shape = sh
	add_to_group("rats")
	material = Defs.flash_material()
	anim_t = randf() * 10.0
	roam_dir = Vector2.from_angle(randf() * TAU)
	attack_cd = randf() * attack_rate
	if GameManager.arena != null:
		GameManager.arena.register_rat(self)
		if kind == Defs.Rat.ROOMBA:
			var to_silo: Vector2 = GameManager.arena.silo.global_position - global_position
			roam_dir = to_silo.normalized().rotated(randf_range(-0.6, 0.6))
	if kind == Defs.Rat.OGRE:
		JuiceManager.bark(self, "SMASH-CRUSH! Rat-Ogre hungry-hungry!", true, "ogre_spawn", 3.0)
		JuiceManager.add_trauma(0.3)


func is_alive() -> bool:
	return not dead


# --- Status effects --------------------------------------------------------------

func apply_stun(t: float) -> void:
	if kind == Defs.Rat.OGRE:
		t *= 0.35
	stun_t = maxf(stun_t, t)


func apply_slow(f: float, t: float) -> void:
	slow_factor = maxf(slow_factor if slow_t > 0.0 else 0.0, clampf(f, 0.0, 0.85))
	slow_t = maxf(slow_t, t)


func apply_burn(dps: float, t: float) -> void:
	burn_dps = maxf(burn_dps, dps)
	burn_t = maxf(burn_t, t)


func take_damage(amount: float, knock: Vector2 = Vector2.ZERO, source_pid: int = 0, show_flash: bool = true) -> void:
	if dead:
		return
	hp -= amount
	if show_flash:
		flash_t = 0.08
	var heavy := kind == Defs.Rat.OGRE or kind == Defs.Rat.ROOMBA
	knock_vel += knock * (0.15 if heavy else 1.0)
	if source_pid > 0 and randf() < 0.06:
		JuiceManager.bark(self, "Metal-fur-thing shoots! Scatter-flee!", true, "rat_hit", 6.0)
	if hp <= 0.0:
		_die(source_pid)


func _die(_source_pid: int) -> void:
	dead = true
	var arena = GameManager.arena
	if arena != null:
		arena.on_rat_killed(self)
		var total := maxi(1, roundi(seed_value * GameManager.gmodf("seed_value_mult")))
		arena.spawn_seeds(global_position, total)
	JuiceManager.burst(global_position, Pal.RAT_FUR_LIGHT, 6, 70.0, 0.4, 2.0, 80.0)
	JuiceManager.burst(global_position, Pal.WARP, 4, 50.0, 0.35, 1.0, 0.0, true)
	match kind:
		Defs.Rat.OGRE:
			JuiceManager.hitstop(0.12)
			JuiceManager.add_trauma(0.7)
			JuiceManager.ring(global_position, 40.0, Pal.WARP, 0.5, true)
			JuiceManager.burst(global_position, Pal.METAL, 16, 140.0, 0.7, 2.0, 160.0)
			SFX.play("boom", 0.7)
		Defs.Rat.ROOMBA:
			JuiceManager.add_trauma(0.45)
			JuiceManager.burst(global_position, Pal.METAL_DARK, 14, 130.0, 0.6, 2.0, 150.0)
			JuiceManager.burst(global_position, Pal.WARP, 12, 120.0, 0.4, 2.0, 0.0, true)
			SFX.play("boom", 1.2)
		_:
			SFX.play("rat_die", randf_range(0.9, 1.4), -6.0, 25)
	queue_free()


# --- Main loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	_tick_status(delta)
	if dead:
		return
	(material as ShaderMaterial).set_shader_parameter("flash", 1.0 if flash_t > 0.0 else 0.0)
	if flying:
		_process_flight(delta)
		queue_redraw()
		return
	if stun_t > 0.0 or trip_t > 0.0:
		velocity = knock_vel
		knock_vel = knock_vel.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	if kind == Defs.Rat.ROOMBA:
		_roomba(delta)
	else:
		_walker(delta)
	queue_redraw()


func _tick_status(delta: float) -> void:
	flash_t = maxf(0.0, flash_t - delta)
	stun_t = maxf(0.0, stun_t - delta)
	trip_t = maxf(0.0, trip_t - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	attack_anim = maxf(0.0, attack_anim - delta)
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_factor = 0.0
	if burn_t > 0.0:
		burn_t -= delta
		_burn_fx_t -= delta
		if _burn_fx_t <= 0.0:
			_burn_fx_t = 0.12
			JuiceManager.particle(global_position + Vector2(randf_range(-3, 3), -4), Vector2(randf_range(-8, 8), -30), Pal.FIRE, 0.35, 1.0)
		take_damage(burn_dps * delta, Vector2.ZERO, 0, false)
		if burn_t <= 0.0:
			burn_dps = 0.0


func _speed() -> float:
	var s := speed * GameManager.gmodf("rat_speed_mult")
	if slow_t > 0.0:
		s *= 1.0 - slow_factor
	return s


## Untyped on purpose: a freed tower passed to a typed Node2D parameter would
## fail the argument type check before is_instance_valid() could run.
func _valid(t) -> bool:
	return is_instance_valid(t) and t.is_alive()


# --- Walker behaviour (everything but the Roomba) --------------------------------

func _walker(delta: float) -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	_retarget_t -= delta
	if _retarget_t <= 0.0 or not _valid(target):
		_retarget_t = randf_range(0.25, 0.4)
		_choose_target(arena)
	var desired := Vector2.ZERO
	var hold := false
	if kind == Defs.Rat.JEZZAIL:
		hold = _jezzail(delta, arena)
	if not hold:
		if _valid(target):
			var dist := _dist_to(target, arena)
			var reach := 8.0 if kind == Defs.Rat.JEZZAIL else attack_range
			if dist <= reach:
				_attack(target, arena)
			else:
				desired = _dir_toward(target, arena)
		else:
			desired = _flow_dir(arena)
	desired += _separation(arena) * 0.9
	velocity = desired.limit_length(1.0) * _speed() + knock_vel
	knock_vel = knock_vel.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 1.0:
		face = signf(velocity.x)
	match kind:
		Defs.Rat.MONK:
			_monk(delta, arena)
		Defs.Rat.OGRE:
			_ogre(delta, arena)
		Defs.Rat.SQUEAKER:
			_trip_check(delta)


func _choose_target(arena) -> void:
	var pos := global_position
	target = null
	var decoy = arena.nearest_tower(pos, DECOY_TAUNT, Defs.Tower.DECOY)
	if decoy != null:
		target = decoy
		return
	match kind:
		Defs.Rat.SQUEAKER:
			var m = arena.nearest_mech(pos, 34.0)
			if m != null:
				target = m
				return
		Defs.Rat.OGRE:
			var m2 = arena.nearest_mech(pos, 28.0)
			if m2 != null:
				target = m2
				return
		Defs.Rat.MONK:
			var t = arena.nearest_tower(pos, 90.0)
			if t != null:
				target = t
				return
	var c: Vector2i = arena.world_to_cell(pos)
	var n: Vector2i = arena.flow_next_cell(c)
	var blocker = arena.tower_at_cell(n)
	if blocker != null:
		target = blocker
		return
	var silo = arena.silo
	if silo.distance_to_edge(pos) < 26.0:
		target = silo


func _dist_to(t: Node2D, arena) -> float:
	if t == arena.silo:
		return arena.silo.distance_to_edge(global_position) - hit_radius
	return global_position.distance_to(t.global_position) - hit_radius - 7.0


func _dir_toward(t: Node2D, arena) -> Vector2:
	var tp := t.global_position
	if t == arena.silo:
		tp = arena.silo.closest_point(global_position)
	return (tp - global_position).normalized()


func _flow_dir(arena) -> Vector2:
	var c: Vector2i = arena.world_to_cell(global_position)
	var n: Vector2i = arena.flow_next_cell(c)
	if n == c or n.x < 0:
		var sp: Vector2 = arena.silo.global_position
		return (sp - global_position).normalized()
	var tp: Vector2 = arena.cell_to_world(n)
	return (tp - global_position).normalized()


func _separation(arena) -> Vector2:
	var push := Vector2.ZERO
	_crowd = 0
	var rad := hit_radius + 5.0
	for r in arena.get_rats_in_radius(global_position, rad + 4.0):
		if r == self or r.flying:
			continue
		var rp: Vector2 = r.global_position
		var d := global_position - rp
		var l := d.length()
		var min_d: float = hit_radius + float(r.hit_radius)
		if l < min_d and l > 0.01:
			push += d / l * (1.0 - l / min_d)
			_crowd += 1
		elif l <= 0.01:
			push += Vector2.from_angle(randf() * TAU)
	return push


func _trip_check(delta: float) -> void:
	_trip_roll_t -= delta
	if _trip_roll_t > 0.0:
		return
	_trip_roll_t = 1.0
	# 10% chance to trip over each other's tails when packed in tight.
	if _crowd >= 2 and randf() < 0.10:
		trip_t = 0.9
		knock_vel = Vector2.from_angle(randf() * TAU) * 40.0
		SFX.play("squeak", randf_range(1.2, 1.6), -10.0, 80)
		if randf() < 0.3:
			JuiceManager.bark(self, "Tail-tangle! Ow-ow!", true, "rat_trip", 5.0)


func _attack(t: Node2D, arena) -> void:
	if attack_cd > 0.0:
		return
	attack_cd = attack_rate
	attack_anim = 0.2
	var is_silo: bool = t == arena.silo
	match kind:
		Defs.Rat.OGRE:
			JuiceManager.add_trauma(0.35)
			JuiceManager.burst(t.global_position, Pal.DIRT, 10, 90.0, 0.4, 2.0, 120.0)
			SFX.play("punch", 0.6)
			t.take_damage(dmg, self)
			if randf() < 0.3:
				JuiceManager.bark(self, "SMASH-CRUSH!", true, "ogre_smash", 4.0)
		Defs.Rat.MONK:
			t.take_damage(dmg, self)
			JuiceManager.burst(t.global_position, Pal.WARP, 4, 40.0, 0.3, 2.0, 0.0, true)
		_:
			t.take_damage(dmg, self)
	if is_silo and randf() < 0.25:
		JuiceManager.bark(self, "For the Great Horned Gouda! Munch-gnaw!", true, "rat_silo", 7.0)


func _jezzail(delta: float, arena) -> bool:
	if aim_t > 0.0:
		aim_t -= delta
		if _valid(aim_target):
			aim_point = aim_point.lerp(_center_of(aim_target, arena), clampf(2.5 * delta, 0.0, 1.0))
		face = signf(aim_point.x - global_position.x + 0.001)
		if aim_t <= 0.0:
			var muzzle := global_position + Vector2(10.0 * face, -5)
			var dir := (aim_point - muzzle).normalized()
			var p := Projectile.new().configure(muzzle, dir * 260.0, dmg, "jezzail", false)
			p.radius = 3.0
			p.life = 1.2
			arena.add_projectile(p)
			JuiceManager.flash(muzzle, 5.0, Pal.WARP, 0.07)
			JuiceManager.burst(muzzle, Pal.WARP, 6, 80.0, 0.3, 1.0, 0.0, true, dir, 0.8)
			SFX.play("jezzail", randf_range(0.9, 1.1), -4.0)
			attack_cd = attack_rate
		return true
	var pos := global_position
	var t = arena.nearest_mech(pos, 150.0)
	if t == null:
		t = arena.nearest_tower(pos, 140.0)
	if t == null and arena.silo.distance_to_edge(pos) < 140.0:
		t = arena.silo
	if t == null:
		return false
	if attack_cd <= 0.0:
		aim_t = 1.2
		aim_target = t
		aim_point = _center_of(t, arena)
		if randf() < 0.3:
			JuiceManager.bark(self, "Hold-still, fur-ball! Warp-shot!", true, "rat_jez", 6.0)
	return true


func _center_of(t: Node2D, arena) -> Vector2:
	if t == arena.silo:
		return arena.silo.closest_point(global_position)
	return t.global_position + Vector2(0, -6)


func _monk(delta: float, arena) -> void:
	gas_cd -= delta
	if gas_cd <= 0.0:
		gas_cd = randf_range(3.0, 4.0)
		arena.spawn_ground(GroundEffect.Kind.GAS, global_position, 22.0, 5.0, 1.0)
		if randf() < 0.2:
			JuiceManager.bark(self, "Breathe-breathe the holy stink!", true, "rat_monk", 8.0)


func _ogre(delta: float, arena) -> void:
	throw_cd -= delta
	if throw_cd > 0.0:
		return
	var pos := global_position
	var t = arena.nearest_mech(pos, 160.0)
	if t == null:
		t = arena.nearest_tower(pos, 150.0)
	if t == null and arena.silo.distance_to_edge(pos) < 150.0:
		t = arena.silo
	if t == null:
		throw_cd = 1.0
		return
	throw_cd = randf_range(3.8, 5.0)
	var tp := _center_of(t, arena)
	var to := tp + (pos - tp).normalized() * 12.0 + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	arena.spawn_thrown_rat(pos + Vector2(0, -16), to, 1.0)
	attack_anim = 0.3
	SFX.play("whoosh", 0.7)
	if randf() < 0.35:
		JuiceManager.bark(self, "Fly-fly, little clan-brother!", true, "ogre_throw", 6.0)


# --- Thrown flight (Squeakers launched by a Rat-Ogre) ------------------------------

func start_flight(to: Vector2) -> void:
	flying = true
	_fly_from = global_position
	_fly_to = to
	_fly_t = 0.0
	collision_layer = 0
	collision_mask = 0


func _process_flight(delta: float) -> void:
	_fly_t += delta / FLIGHT_TIME
	global_position = _fly_from.lerp(_fly_to, minf(_fly_t, 1.0))
	if _fly_t < 1.0:
		return
	flying = false
	collision_layer = Defs.L_RAT
	collision_mask = Defs.L_WORLD | Defs.L_TOWER | Defs.L_SILO
	stun_t = 0.4
	var arena = GameManager.arena
	if arena == null:
		return
	JuiceManager.add_trauma(0.15)
	JuiceManager.burst(global_position, Pal.DIRT, 8, 60.0, 0.4, 2.0, 100.0)
	SFX.play("punch", 1.4, -6.0)
	var hit_friend := false
	for r in arena.get_rats_in_radius(global_position, 14.0):
		if r != self:
			r.take_damage(10.0, Vector2.ZERO, 0)
			if not hit_friend:
				hit_friend = true
				JuiceManager.bark(r, "Not me-me, you blind-fool!", true, "rat_ff", 4.0)
	for m in arena.mechs:
		if m.is_targetable():
			var mp: Vector2 = m.global_position
			if mp.distance_to(global_position) < 16.0:
				m.take_damage(12.0, self)
	var t = arena.tower_at_world(global_position)
	if t != null:
		t.take_damage(12.0, self)


# --- Doom-Roomba -------------------------------------------------------------------

func _roomba(delta: float) -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	turn_t -= delta
	if turn_t <= 0.0:
		turn_t = randf_range(1.5, 3.5)
		var to_silo: Vector2 = arena.silo.global_position - global_position
		roam_dir = to_silo.normalized().rotated(randf_range(-1.3, 1.3))
	var motion := roam_dir * _speed() * delta + knock_vel * delta
	knock_vel = knock_vel.move_toward(Vector2.ZERO, 300.0 * delta)
	var col := move_and_collide(motion)
	if col != null:
		var other := col.get_collider()
		if other != null and other.has_method("take_damage") and _contact_ok(other):
			other.take_damage(dmg, self)
			JuiceManager.add_trauma(0.15)
			JuiceManager.burst(col.get_position(), Pal.WARP, 6, 80.0, 0.3, 1.0, 0.0, true)
			SFX.play("punch", 1.2, -6.0, 60)
		roam_dir = roam_dir.bounce(col.get_normal()).rotated(randf_range(-0.4, 0.4)).normalized()
	face = signf(roam_dir.x + 0.001)
	# Contact damage to everything nearby, rats included.
	var barked := false
	for r in arena.get_rats_in_radius(global_position, hit_radius + 6.0):
		if r == self or r.kind == Defs.Rat.ROOMBA:
			continue
		if _contact_ok(r):
			var rp: Vector2 = r.global_position
			r.take_damage(dmg * 0.5, (rp - global_position).normalized() * 160.0, 0)
			if not barked:
				barked = JuiceManager.bark(r, "Not me-me, you blind-fool!", true, "rat_ff", 4.0)
	for m in arena.mechs:
		if m.is_targetable():
			var mp: Vector2 = m.global_position
			if mp.distance_to(global_position) < hit_radius + 7.0 and _contact_ok(m):
				m.take_damage(dmg, self)
				m.apply_knock((mp - global_position).normalized() * 180.0)
	zap_cd -= delta
	if zap_cd <= 0.0:
		zap_cd = randf_range(1.8, 3.0)
		_zap(arena)


func _contact_ok(n: Object) -> bool:
	var id := n.get_instance_id()
	var now := Time.get_ticks_msec()
	if int(_contact.get(id, 0)) > now:
		return false
	_contact[id] = now + 500
	return true


func _zap(arena) -> void:
	var pos := global_position + Vector2(0, -8)
	var candidates: Array = []
	for r in arena.get_rats_in_radius(pos, 60.0):
		if r != self:
			candidates.append(r)
	for m in arena.mechs:
		if m.is_targetable():
			var mp: Vector2 = m.global_position
			if mp.distance_to(pos) < 70.0:
				candidates.append(m)
	var t = arena.nearest_tower(pos, 70.0)
	if t != null:
		candidates.append(t)
	if candidates.is_empty():
		return
	var victim = candidates[randi() % candidates.size()]
	var vp: Vector2 = victim.global_position
	JuiceManager.bolt(pos, vp + Vector2(0, -4), Pal.WARP, 0.15, 5.0)
	SFX.play("zap", randf_range(0.8, 1.0), -6.0)
	if victim is RatEnemy:
		victim.take_damage(6.0, Vector2.ZERO, 0)
	else:
		victim.take_damage(6.0, self)


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var lift := 0.0
	if flying:
		lift = roundf(4.0 * 34.0 * _fly_t * (1.0 - _fly_t))
	var sh_w := hit_radius * 2.0
	draw_rect(Rect2(-hit_radius, hit_radius * 0.5, sh_w, 2), Pal.SHADOW)
	if kind == Defs.Rat.JEZZAIL and aim_t > 0.0:
		var muzzle := Vector2(10.0 * face, -5)
		var tl := (aim_point - global_position).round()
		var c := Color(Pal.WARP, 0.35 + 0.5 * (1.0 - aim_t / 1.2))
		if aim_t < 0.3 and int(anim_t * 30.0) % 2 == 0:
			c = Pal.WHITE
		draw_line(muzzle, tl, c, 1.0)
		draw_rect(Rect2(tl.x - 1, tl.y - 1, 3, 3), c, false, 1.0)
	var spin := 0.0
	if trip_t > 0.0:
		spin = anim_t * 14.0
	draw_set_transform(Vector2(0, -lift), spin, Vector2(face, 1.0))
	match kind:
		Defs.Rat.SQUEAKER:
			_draw_squeaker(Vector2.ZERO, true)
		Defs.Rat.JEZZAIL:
			_draw_jezzail()
		Defs.Rat.MONK:
			_draw_monk()
		Defs.Rat.ROOMBA:
			_draw_roomba()
		Defs.Rat.OGRE:
			_draw_ogre()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if stun_t > 0.0 and not flying:
		for i in 3:
			var a := anim_t * 6.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 5.0, -hit_radius * 2.0 - 3.0 + sin(a) * 1.5)
			draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), Pal.SUNFLOWER)
	if kind != Defs.Rat.SQUEAKER and hp < max_hp:
		var w := hit_radius * 2.0 + 2.0
		var y := -hit_radius * 2.0 - 6.0
		if kind == Defs.Rat.OGRE:
			y = -30.0
		draw_rect(Rect2(-w / 2.0, y, w, 2), Pal.INK)
		draw_rect(Rect2(-w / 2.0, y, w * clampf(hp / max_hp, 0.0, 1.0), 2), Pal.WARP)


func _legs(o: Vector2, phase: float) -> void:
	var s := sin(anim_t * 14.0 + phase)
	var a := 1.0 if s > 0.0 else 0.0
	draw_rect(Rect2(o.x - 3, o.y + 2, 1, 2 - a), Pal.RAT_FUR_DARK)
	draw_rect(Rect2(o.x + 2, o.y + 2, 1, 1 + a), Pal.RAT_FUR_DARK)


func _draw_squeaker(o: Vector2, fork: bool) -> void:
	var wig := roundf(sin(anim_t * 9.0) * 1.5)
	draw_line(o + Vector2(-4, 1), o + Vector2(-7, wig), Pal.RAT_PINK, 1.0)
	draw_line(o + Vector2(-7, wig), o + Vector2(-9, wig - 1), Pal.RAT_PINK, 1.0)
	_legs(o, 0.0)
	draw_rect(Rect2(o.x - 4, o.y - 3, 8, 5), Pal.RAT_FUR)
	draw_rect(Rect2(o.x - 2, o.y, 5, 2), Pal.RAT_FUR_LIGHT)
	var lunge := 1.0 if attack_anim > 0.0 else 0.0
	draw_rect(Rect2(o.x + 3 + lunge, o.y - 4, 4, 4), Pal.RAT_FUR)
	draw_rect(Rect2(o.x + 7 + lunge, o.y - 2, 1, 1), Pal.RAT_PINK)
	draw_rect(Rect2(o.x + 3 + lunge, o.y - 6, 2, 2), Pal.RAT_FUR_DARK)
	draw_rect(Rect2(o.x + 4 + lunge, o.y - 5, 1, 1), Pal.RAT_PINK)
	draw_rect(Rect2(o.x + 5 + lunge, o.y - 3, 1, 1), Pal.WARP)
	if fork:
		var fx := o.x + 5 + lunge * 2.0
		draw_line(Vector2(fx, o.y), Vector2(fx + 4, o.y - 4), Pal.METAL, 1.0)
		draw_rect(Rect2(fx + 3, o.y - 6, 1, 2), Pal.METAL_LIGHT)
		draw_rect(Rect2(fx + 5, o.y - 5, 1, 2), Pal.METAL_LIGHT)


func _draw_jezzail() -> void:
	# Back rat (the bipod) and front rat (the gunner).
	_draw_squeaker(Vector2(-5, 1), false)
	_draw_squeaker(Vector2(3, 0), false)
	draw_line(Vector2(-6, -5), Vector2(10, -5), Pal.RUST, 2.0)
	draw_rect(Rect2(9, -6, 2, 2), Pal.METAL_DARK)
	draw_rect(Rect2(-1, -7, 3, 2), Pal.WARP_DARK)
	if int(anim_t * 4.0) % 2 == 0:
		draw_rect(Rect2(0, -7, 1, 1), Pal.WARP)


func _draw_monk() -> void:
	var wig := roundf(sin(anim_t * 8.0))
	draw_line(Vector2(-4, 3), Vector2(-8, 2 + wig), Pal.RAT_PINK, 1.0)
	draw_rect(Rect2(-5, -6, 10, 10), Color("4a5a2a"))
	draw_rect(Rect2(-5, 2, 10, 2), Color("33401c"))
	draw_rect(Rect2(-3, -10, 7, 6), Color("3a4720"))
	draw_rect(Rect2(-1, -8, 4, 3), Pal.INK)
	draw_rect(Rect2(0, -7, 1, 1), Pal.WARP)
	draw_rect(Rect2(2, -7, 1, 1), Pal.WARP)
	draw_rect(Rect2(4, -9, 2, 2), Pal.RAT_PINK)
	var a := anim_t * 6.0
	var hand := Vector2(5, -3)
	var cheese := hand + Vector2(cos(a) * 7.0, sin(a) * 3.5)
	draw_line(hand, cheese, Pal.METAL, 1.0)
	draw_rect(Rect2(roundf(cheese.x) - 2, roundf(cheese.y) - 2, 4, 3), Color("d8d040"))
	draw_rect(Rect2(roundf(cheese.x) - 1, roundf(cheese.y) - 1, 1, 1), Pal.WARP_DARK)
	if int(anim_t * 5.0) % 3 == 0:
		draw_rect(Rect2(roundf(cheese.x), roundf(cheese.y) - 4, 1, 1), Pal.WARP)


func _draw_roomba() -> void:
	var r := hit_radius
	for i in 8:
		var a := i * TAU / 8.0 + anim_t * 2.0
		var p := Vector2.from_angle(a) * (r + 1.0)
		draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y) - 1 - 3, 2, 2), Pal.METAL_LIGHT)
	draw_circle(Vector2(0, -3), r, Pal.METAL_DARK)
	draw_circle(Vector2(0, -4), r - 2.0, Color("3a3e4a"))
	draw_arc(Vector2(0, -4), r - 3.0, 0.0, TAU, 16, Pal.METAL, 1.0)
	draw_rect(Rect2(r - 4, -5, 2, 2), Color("ff3040") if int(anim_t * 4.0) % 2 == 0 else Color("801820"))
	# Lightning coil.
	draw_rect(Rect2(-2, -10, 4, 5), Pal.COPPER)
	draw_rect(Rect2(-1, -12, 2, 2), Pal.METAL_LIGHT)
	if randf() < 0.5:
		var tip := Vector2(randf_range(-6, 6), randf_range(-16, -11))
		draw_line(Vector2(0, -12), tip, Pal.WARP, 1.0)
	# Tiny rat driver.
	draw_rect(Rect2(-5, -9, 3, 3), Pal.RAT_FUR)
	draw_rect(Rect2(-4, -8, 1, 1), Pal.WARP)


func _draw_ogre() -> void:
	var stomp := roundf(absf(sin(anim_t * 4.0)) * 1.0)
	var swing := 3.0 if attack_anim > 0.0 else 0.0
	draw_line(Vector2(-8, 4), Vector2(-14, 1 + stomp), Pal.RAT_PINK, 2.0)
	draw_rect(Rect2(-7, 4, 4, 6 - stomp), Pal.RAT_FUR_DARK)
	draw_rect(Rect2(3, 4, 4, 5 + stomp), Pal.RAT_FUR_DARK)
	draw_rect(Rect2(-10, -16, 20, 21), Pal.RAT_FUR_DARK)
	draw_rect(Rect2(-9, -15, 18, 19), Pal.RAT_FUR)
	# Scrap-iron chest plate with rivets.
	draw_rect(Rect2(-5, -10, 10, 8), Pal.METAL)
	draw_rect(Rect2(-4, -9, 1, 1), Pal.METAL_LIGHT)
	draw_rect(Rect2(3, -9, 1, 1), Pal.METAL_LIGHT)
	draw_rect(Rect2(-4, -4, 1, 1), Pal.METAL_LIGHT)
	draw_rect(Rect2(3, -4, 1, 1), Pal.METAL_LIGHT)
	# Stitches.
	for i in 4:
		draw_rect(Rect2(-8 + i * 2, 0, 1, 1), Pal.RAT_FUR_LIGHT)
	# Head with horns and glowing eyes.
	draw_rect(Rect2(4, -22, 9, 8), Pal.RAT_FUR)
	draw_rect(Rect2(12, -19, 2, 2), Pal.RAT_PINK)
	draw_rect(Rect2(4, -25, 2, 3), Color("e8e0c8"))
	draw_rect(Rect2(9, -25, 2, 3), Color("e8e0c8"))
	draw_rect(Rect2(7, -20, 2, 1), Pal.WARP)
	draw_rect(Rect2(10, -20, 1, 1), Pal.WARP)
	# Oven-mitt fists.
	draw_rect(Rect2(-14, -8 + swing, 6, 7), Color("d0503a"))
	draw_rect(Rect2(-13, -7 + swing, 1, 1), Pal.WHITE)
	draw_rect(Rect2(10 + swing, -10, 6, 7), Color("d0503a"))
	draw_rect(Rect2(12 + swing, -8, 1, 1), Pal.WHITE)
