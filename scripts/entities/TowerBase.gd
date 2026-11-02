class_name TowerBase
extends StaticBody2D
## Modular turret built on a grid pad. One script drives all five towers:
## Sunflower Gatling, Water-Bottle Laser, Cedar-Shaving Mortar,
## Exercise-Wheel Tesla Coil and Cardboard Decoy Hamster.
## Cram cheek seeds into it to trigger a Sugar Rush Overdrive (OverchargeTimer).

const OVERDRIVE_RATE := 2.5
const OVERDRIVE_DMG := 1.5

var kind: int = Defs.Tower.GATLING
var cell := Vector2i.ZERO
var owner_pid := 0
var data: Dictionary = {}
var hp := 100.0
var max_hp := 100.0
var reach := 100.0
var dead := false
var bubble_height := 22.0
var corrode := 0
var corrode_t := 0.0
var cd := 0.0
var flash_t := 0.0
var overdrive := false
var build_t := 0.0
var anim_t := 0.0
var aim_angle := -PI * 0.5
var spin := 0.0
var spin_boost := false
var laser_target: Node2D = null
var laser_ramp := 0.0
var prism_mech: Node2D = null
var prism_targets: Array = []
var look := Vector2.RIGHT
var _laser_sfx_t := 0.0
var _laser_flash_t := 0.0

@onready var detection: Area2D = $DetectionRange
@onready var detection_shape: CollisionShape2D = $DetectionRange/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var overcharge_timer: Timer = $OverchargeTimer


func setup(k: int, c: Vector2i, pid: int = 0) -> TowerBase:
	kind = k
	cell = c
	owner_pid = pid
	return self


func _ready() -> void:
	data = Defs.TOWER_DATA[kind]
	collision_layer = Defs.L_TOWER
	collision_mask = 0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	body_shape.shape = rect
	reach = float(data["range"])
	var circle := CircleShape2D.new()
	circle.radius = reach
	detection_shape.shape = circle
	detection.collision_layer = 0
	detection.collision_mask = Defs.L_RAT
	detection.monitorable = false
	overcharge_timer.one_shot = true
	overcharge_timer.timeout.connect(_on_overcharge_timeout)
	max_hp = float(data["hp"])
	if kind == Defs.Tower.DECOY:
		max_hp *= GameManager.gmodf("decoy_hp_mult")
	hp = max_hp
	add_to_group("towers")
	material = Defs.flash_material()
	anim_t = randf() * 5.0


func is_alive() -> bool:
	return not dead


func display_name() -> String:
	return String(data.get("name", "Tower"))


# --- Damage, corrosion & overdrive -------------------------------------------------

func take_damage(amount: float, _source = null) -> void:
	if dead or build_t < 1.0:
		return
	var mult := (1.0 + 0.15 * corrode) * GameManager.gmodf("tower_damage_taken_mult")
	hp -= amount * mult
	flash_t = 0.08
	if hp <= 0.0:
		_destroy()


func add_corrode() -> void:
	corrode = mini(corrode + 1, 5)
	corrode_t = 6.0


func start_overdrive(seeds_used: int) -> void:
	overdrive = true
	hp = minf(max_hp, hp + seeds_used * 2.0)
	overcharge_timer.start(GameManager.gmodf("overdrive_duration"))
	JuiceManager.ring(global_position, 26.0, Pal.SUGAR, 0.4, true)
	JuiceManager.popup(global_position + Vector2(0, -28), "SUGAR RUSH!", Pal.SUGAR)


func overdrive_left() -> float:
	return overcharge_timer.time_left if overdrive else 0.0


func _on_overcharge_timeout() -> void:
	overdrive = false
	JuiceManager.burst(global_position + Vector2(0, -8), Pal.SUGAR, 8, 40.0, 0.5, 1.0)


func _destroy() -> void:
	dead = true
	var arena = GameManager.arena
	if arena != null:
		arena.on_tower_destroyed(self)
	JuiceManager.burst(global_position, Pal.CARDBOARD, 14, 120.0, 0.6, 2.0, 160.0)
	JuiceManager.burst(global_position, Pal.METAL, 10, 100.0, 0.6, 2.0, 160.0)
	JuiceManager.add_trauma(0.35)
	SFX.play("build", 0.6)
	if kind == Defs.Tower.DECOY and GameManager.gmodb("decoy_explode") and arena != null:
		for r in arena.get_rats_in_radius(global_position, 42.0):
			var rp: Vector2 = r.global_position
			r.take_damage(45.0, (rp - global_position).normalized() * 180.0, 0)
		for i in 14:
			var p := Projectile.new().configure(global_position, Vector2.from_angle(TAU * i / 14.0) * 200.0, 10.0, "shard", true, 0)
			p.life = 0.4
			arena.add_projectile(p)
		JuiceManager.ring(global_position, 42.0, Pal.CARDBOARD, 0.35)
		JuiceManager.add_trauma(0.3)
		SFX.play("boom", 1.3)
	queue_free()


# --- Main loop ---------------------------------------------------------------------

func _rate_mult() -> float:
	var m := GameManager.gmodf("tower_fire_rate_mult")
	if overdrive:
		m *= OVERDRIVE_RATE
	if kind == Defs.Tower.TESLA and spin_boost:
		m *= 2.0
	return m


func _dmg_mult() -> float:
	return OVERDRIVE_DMG if overdrive else 1.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	flash_t = maxf(0.0, flash_t - delta)
	if build_t < 1.0:
		build_t = minf(1.0, build_t + delta * 4.0)
		if build_t >= 1.0:
			JuiceManager.burst(global_position + Vector2(0, 6), Pal.DIRT, 10, 60.0, 0.4, 2.0, 60.0)
			JuiceManager.add_trauma(0.12)
			SFX.play("build", randf_range(0.9, 1.1), -4.0)
		queue_redraw()
		return
	if corrode_t > 0.0:
		corrode_t -= delta
		if corrode_t <= 0.0:
			corrode = 0
	(material as ShaderMaterial).set_shader_parameter("flash", 1.0 if flash_t > 0.0 else 0.0)
	cd = maxf(0.0, cd - delta)
	if overdrive and randf() < 0.3:
		JuiceManager.particle(global_position + Vector2(randf_range(-6, 6), -4), Vector2(0, -30), Pal.SUGAR, 0.5, 1.0, 0.0, true)
	match kind:
		Defs.Tower.GATLING:
			_gatling()
		Defs.Tower.LASER:
			_laser(delta)
		Defs.Tower.MORTAR:
			_mortar()
		Defs.Tower.TESLA:
			_tesla(delta)
		Defs.Tower.DECOY:
			_decoy(delta)
	queue_redraw()


func _targets() -> Array:
	var out: Array = []
	for b in detection.get_overlapping_bodies():
		var r := b as RatEnemy
		if r != null and not r.dead and not r.flying:
			out.append(r)
	return out


func _nearest_target(from: Vector2, max_d: float = INF) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for r in _targets():
		var rp: Vector2 = r.global_position
		var d := from.distance_to(rp)
		if d < best_d:
			best_d = d
			best = r
	return best


func _muzzle() -> Vector2:
	return global_position + Vector2(0, -7)


func _gatling() -> void:
	var t := _nearest_target(global_position)
	if t == null:
		aim_angle = lerp_angle(aim_angle, -PI * 0.5, 0.02)
		return
	var tp := t.global_position
	var want := (tp - _muzzle()).angle()
	aim_angle = lerp_angle(aim_angle, want, 0.5)
	if cd > 0.0:
		return
	cd = 1.0 / (float(data["rate"]) * _rate_mult())
	var dir := Vector2.from_angle(aim_angle + randf_range(-0.07, 0.07))
	var origin := _muzzle() + dir * 6.0
	var p := Projectile.new().configure(origin, dir * 300.0, float(data["damage"]) * _dmg_mult(), "hull", true, 0)
	p.life = reach / 300.0 + 0.15
	p.knock = 15.0
	p.shell_chance = 0.12
	if GameManager.gmodb("flaming_hulls"):
		p.burn_dps = 6.0
	GameManager.arena.add_projectile(p)
	JuiceManager.flash(origin, 2.0, Pal.FIRE_HOT, 0.04)
	SFX.play("hull", randf_range(0.9, 1.2), -10.0, 45)


func _laser(delta: float) -> void:
	var arena = GameManager.arena
	if laser_target != null:
		var still_ok: bool = is_instance_valid(laser_target) and laser_target.is_alive()
		if still_ok:
			var lp := laser_target.global_position
			still_ok = lp.distance_to(global_position) <= reach + 8.0
		if not still_ok:
			laser_target = null
			laser_ramp = 0.0
	if laser_target == null:
		laser_target = _nearest_target(global_position)
	prism_mech = null
	prism_targets.clear()
	if laser_target == null:
		return
	laser_ramp = minf(2.0, laser_ramp + delta * 0.8)
	var dps := float(data["dps"]) * (1.0 + laser_ramp) * _dmg_mult() * _rate_mult()
	var a := _muzzle()
	var b := laser_target.global_position + Vector2(0, -2)
	aim_angle = (b - a).angle()
	_laser_flash_t -= delta
	var show := _laser_flash_t <= 0.0
	if show:
		_laser_flash_t = 0.15
	if GameManager.gmodb("prism_lasers"):
		for m in arena.mechs:
			if not m.is_alive():
				continue
			var mp: Vector2 = m.global_position + Vector2(0, -10)
			var cp := Geometry2D.get_closest_point_to_segment(mp, a, b)
			if cp.distance_to(mp) < 9.0 and cp.distance_to(a) > 6.0:
				prism_mech = m
				break
	if prism_mech != null:
		var mp2: Vector2 = prism_mech.global_position + Vector2(0, -10)
		var exclude: Array = []
		for i in 3:
			var r = arena.nearest_rat(mp2, 130.0, exclude)
			if r == null:
				break
			exclude.append(r)
			prism_targets.append(r)
			r.take_damage(dps * delta, Vector2.ZERO, 0, show)
	else:
		laser_target.take_damage(dps * delta, Vector2.ZERO, 0, show)
	if randf() < 0.25:
		JuiceManager.particle(b, Vector2(randf_range(-30, 30), randf_range(-50, -10)), Pal.STEAM, 0.3, 1.0)
	_laser_sfx_t -= delta
	if _laser_sfx_t <= 0.0:
		_laser_sfx_t = 0.25
		SFX.play("laser", 1.0 + laser_ramp * 0.2, -14.0, 0)


func _mortar() -> void:
	if cd > 0.0:
		return
	var arena = GameManager.arena
	var best: Node2D = null
	var best_score := -1
	var min_r := float(data["min_range"])
	for r in _targets():
		var rp: Vector2 = r.global_position
		if rp.distance_to(global_position) < min_r:
			continue
		var score: int = arena.get_rats_in_radius(rp, 24.0).size()
		if score > best_score:
			best_score = score
			best = r
	if best == null:
		return
	cd = 1.0 / (float(data["rate"]) * _rate_mult())
	var aoe := float(data["aoe"]) * GameManager.gmodf("mortar_aoe_mult")
	var dmg := float(data["damage"]) * _dmg_mult()
	var tp := best.global_position
	arena.spawn_mortar(_muzzle() + Vector2(0, -4), tp, dmg, aoe, float(data["stun"]))
	if GameManager.gmodb("mortar_double"):
		var off := Vector2.from_angle(randf() * TAU) * aoe * 0.8
		arena.spawn_mortar(_muzzle() + Vector2(0, -4), tp + off, dmg, aoe, float(data["stun"]))
	JuiceManager.burst(_muzzle() + Vector2(0, -6), Pal.CEDAR, 6, 50.0, 0.4, 2.0, -20.0)
	JuiceManager.add_trauma(0.06)
	SFX.play("punch", 1.6, -6.0, 60)


func _tesla(delta: float) -> void:
	var arena = GameManager.arena
	spin_boost = false
	for m in arena.mechs:
		if m.is_alive():
			var mp: Vector2 = m.global_position
			var mv: Vector2 = m.velocity
			if mp.distance_to(global_position) < 28.0 and mv.length() > 30.0:
				spin_boost = true
	spin += delta * (16.0 if spin_boost else 4.0) * (2.0 if overdrive else 1.0)
	if spin_boost and randf() < 0.2:
		JuiceManager.particle(global_position + Vector2(randf_range(-6, 6), -12), Vector2(0, -20), Pal.TESLA, 0.3, 1.0, 0.0, true)
	if cd > 0.0:
		return
	var first := _nearest_target(global_position)
	if first == null:
		return
	cd = 1.0 / (float(data["rate"]) * _rate_mult())
	var chains := int(data["chains"]) + GameManager.gmodi("tesla_chain_bonus")
	var chain_r := float(data["chain_range"])
	var dmg := float(data["damage"]) * _dmg_mult()
	var hits: Array = []
	var prev := global_position + Vector2(0, -16)
	var cur = first
	for i in chains:
		if cur == null:
			break
		hits.append(cur)
		var cp: Vector2 = cur.global_position
		JuiceManager.bolt(prev, cp + Vector2(0, -3), Pal.TESLA, 0.14)
		JuiceManager.burst(cp, Pal.TESLA, 3, 50.0, 0.2, 1.0, 0.0, true)
		cur.take_damage(dmg * pow(0.85, i), Vector2.ZERO, 0)
		cur.apply_stun(0.15)
		prev = cp + Vector2(0, -3)
		cur = arena.nearest_rat(cp, chain_r, hits)
	SFX.play("zap", randf_range(0.9, 1.2), -6.0, 60)


func _decoy(delta: float) -> void:
	var t := _nearest_target(global_position)
	var want := Vector2.RIGHT
	if t != null:
		want = (t.global_position - global_position).normalized()
	look = look.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
	if overdrive and hp < max_hp:
		hp = minf(max_hp, hp + 20.0 * delta)


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	var drop := roundf((1.0 - build_t) * -24.0)
	var jitter := Vector2.ZERO
	if overdrive:
		jitter = Vector2(randi_range(-1, 1), 0)
	draw_rect(Rect2(-7, 4, 14, 3), Pal.SHADOW)
	draw_set_transform(Vector2(0, drop) + jitter, 0.0, Vector2.ONE)
	match kind:
		Defs.Tower.GATLING:
			_draw_gatling()
		Defs.Tower.LASER:
			_draw_laser_body()
		Defs.Tower.MORTAR:
			_draw_mortar()
		Defs.Tower.TESLA:
			_draw_tesla()
		Defs.Tower.DECOY:
			_draw_decoy()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == Defs.Tower.LASER and laser_target != null and build_t >= 1.0:
		_draw_beams()
	if corrode > 0:
		for i in corrode:
			var dx := -6 + i * 3
			var dy := roundf(fmod(anim_t * 10.0 + i * 3.0, 8.0))
			draw_rect(Rect2(dx, -6 + dy, 1, 2), Pal.WARP)
	if overdrive:
		var a := Color(Pal.SUGAR, 0.5 + 0.5 * sin(anim_t * 20.0))
		draw_rect(Rect2(-9, -22, 18, 30), a, false, 1.0)
	if hp < max_hp and build_t >= 1.0:
		draw_rect(Rect2(-7, 9, 14, 2), Pal.INK)
		draw_rect(Rect2(-7, 9, 14.0 * clampf(hp / max_hp, 0.0, 1.0), 2), Pal.HP_GREEN)


func _draw_gatling() -> void:
	draw_rect(Rect2(-6, -2, 12, 8), Pal.METAL_DARK)
	draw_rect(Rect2(-5, -1, 10, 2), Pal.METAL)
	var c := Vector2(0, -7)
	for i in 8:
		var a := i * TAU / 8.0 + anim_t * 0.5
		var p := c + Vector2.from_angle(a) * 5.0
		draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y) - 1, 3, 3), Pal.SUNFLOWER)
	draw_circle(c, 3.0, Pal.SUNFLOWER_DARK)
	draw_rect(Rect2(-1, -8, 1, 1), Pal.SEED)
	draw_rect(Rect2(1, -7, 1, 1), Pal.SEED)
	var dir := Vector2.from_angle(aim_angle)
	for k in [-1.0, 0.0, 1.0]:
		var o: Vector2 = c + dir.orthogonal() * k * 1.5
		draw_line(o, o + dir * 8.0, Pal.INK, 1.0)


func _draw_laser_body() -> void:
	draw_rect(Rect2(-5, 0, 10, 6), Pal.WOOD_DARK)
	draw_rect(Rect2(-4, -2, 1, 3), Pal.WOOD)
	draw_rect(Rect2(3, -2, 1, 3), Pal.WOOD)
	# Upside-down water bottle.
	draw_rect(Rect2(-4, -17, 8, 13), Pal.WATER)
	draw_rect(Rect2(-3, -16, 1, 10), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(-2, -4, 4, 2), Pal.BEAM)
	var wobble := roundf(sin(anim_t * 3.0))
	draw_rect(Rect2(-3, -15 + wobble, 6, 1), Color(1, 1, 1, 0.35))
	# Ball-bearing dripper tube.
	var dir := Vector2.from_angle(aim_angle)
	var base := Vector2(0, -3)
	draw_line(base, base + dir * 6.0, Pal.METAL_LIGHT, 2.0)
	draw_rect(Rect2(roundf(base.x + dir.x * 6.0) - 1, roundf(base.y + dir.y * 6.0) - 1, 2, 2), Pal.METAL)


func _draw_beams() -> void:
	var a := Vector2(0, -3) + Vector2.from_angle(aim_angle) * 6.0
	var pulse := 0.6 + 0.4 * sin(anim_t * 30.0)
	var width := 1.0 + roundf(laser_ramp)
	var core := Color(Pal.BEAM, pulse)
	if prism_mech != null and is_instance_valid(prism_mech):
		var mp := prism_mech.global_position + Vector2(0, -10) - global_position
		draw_line(a, mp, core, width)
		for r in prism_targets:
			if is_instance_valid(r):
				var rp: Vector2 = r.global_position
				draw_line(mp, rp + Vector2(0, -2) - global_position, Color(Pal.SUGAR, pulse), 1.0)
	elif is_instance_valid(laser_target):
		var tp := laser_target.global_position + Vector2(0, -2) - global_position
		draw_line(a, tp, Color(Pal.WATER, 0.5), width + 2.0)
		draw_line(a, tp, core, width)


func _draw_mortar() -> void:
	draw_rect(Rect2(-6, -4, 12, 9), Pal.WOOD)
	draw_rect(Rect2(-6, -4, 12, 1), Pal.WOOD_LIGHT)
	for i in 5:
		draw_rect(Rect2(-5 + i * 2, -2 + (i % 2) * 3, 2, 1), Pal.CEDAR)
	var kick := 2.0 if cd > (1.0 / (float(data["rate"]) * _rate_mult())) - 0.15 else 0.0
	draw_rect(Rect2(-3, -11 + kick, 6, 8), Pal.METAL_DARK)
	draw_rect(Rect2(-3, -12 + kick, 6, 1), Pal.METAL_LIGHT)
	draw_rect(Rect2(-2, -11 + kick, 4, 1), Pal.INK)


func _draw_tesla() -> void:
	draw_rect(Rect2(-6, 2, 3, 4), Pal.METAL_DARK)
	draw_rect(Rect2(3, 2, 3, 4), Pal.METAL_DARK)
	var c := Vector2(0, -6)
	draw_arc(c, 7.0, 0.0, TAU, 20, Pal.METAL_LIGHT, 1.0)
	for i in 4:
		var a := spin + i * PI * 0.5
		draw_line(c, c + Vector2.from_angle(a) * 7.0, Pal.METAL, 1.0)
	draw_circle(c, 1.5, Pal.COPPER)
	draw_rect(Rect2(-2, -17, 4, 4), Pal.COPPER)
	draw_rect(Rect2(-1, -19, 2, 2), Pal.METAL_LIGHT)
	if int(anim_t * 10.0) % 3 == 0 or spin_boost:
		var tip := Vector2(randf_range(-5, 5), randf_range(-24, -19))
		draw_line(Vector2(0, -19), tip, Pal.TESLA, 1.0)


func _draw_decoy() -> void:
	var sway := roundf(sin(anim_t * 2.0))
	draw_rect(Rect2(-1, -2, 2, 8), Pal.WOOD_DARK)
	draw_rect(Rect2(-7 + sway, -16, 14, 14), Pal.CARDBOARD_DARK)
	draw_rect(Rect2(-6 + sway, -15, 12, 12), Pal.CARDBOARD)
	draw_rect(Rect2(-7 + sway, -19, 4, 4), Pal.CARDBOARD)
	draw_rect(Rect2(3 + sway, -19, 4, 4), Pal.CARDBOARD)
	draw_rect(Rect2(-6 + sway, -18, 2, 2), Pal.HAMSTER_PINK)
	draw_rect(Rect2(4 + sway, -18, 2, 2), Pal.HAMSTER_PINK)
	draw_rect(Rect2(-5 + sway, -7, 10, 3), Pal.HAMSTER_LIGHT)
	draw_rect(Rect2(-1 + sway, -8, 2, 1), Pal.HAMSTER_PINK)
	for ex in [-3.0, 3.0]:
		var ec := Vector2(ex + sway, -11)
		draw_circle(ec, 2.5, Pal.WHITE)
		var pupil: Vector2 = ec + look * 1.2 + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
		draw_rect(Rect2(roundf(pupil.x) - 1, roundf(pupil.y) - 1, 2, 2), Pal.INK)
