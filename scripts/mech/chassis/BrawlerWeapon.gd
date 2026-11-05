extends WeaponMount
## BRAWLER-01: Sawdust Shotgun (fire) and Cardboard-Tube Fist (alt). ADR-0003.

const PUNCH_TIME := 0.3      # visual timeline (damage is applied on press)
const PUMP_TIME := 0.34

var punch_t := 0.0
var _pump_t := 0.0
var _ejected := true


func _tick_extra(delta: float) -> void:
	punch_t = maxf(0.0, punch_t - delta)
	if _pump_t > 0.0:
		_pump_t = maxf(0.0, _pump_t - delta)
		if not _ejected and _pump_t < PUMP_TIME * 0.55:
			_ejected = true
			_eject_shell()


func _fire() -> void:
	_fire_shotgun()


func _alt() -> void:
	_punch()


## The shotgun sits off to one side of the machine, so the muzzle is nudged along the aim's normal.
func muzzle_pos(side: float = 0.0) -> Vector2:
	return global_position + aim * 15.0 + aim.orthogonal() * side + aim.orthogonal() * (4.0 if aim.x >= 0.0 else -4.0)


func _fire_shotgun() -> void:
	var arena = _arena()
	if arena == null:
		return
	cooldown = 0.62 / mech.fire_rate_mult()
	var n: int = 6 + mech.stats.gi("extra_projectiles")
	var dmg: float = 5.5 * mech.damage_mult()
	var pierce: int = mech.stats.gi("pierce")
	var mp := muzzle_pos()
	for i in n:
		var a := aim.angle() + randf_range(-0.28, 0.28)
		var v := Vector2.from_angle(a) * randf_range(250.0, 330.0)
		arena.shots.fire(mp, v, dmg, {"kind": "pellet", "life": randf_range(0.24, 0.34), "radius": 2.5,
			"knockback": 45.0, "pierce": pierce, "owner": mech})
	arena.fx.flash(mp, aim.angle(), 13.0, Color8(255, 240, 120), 0.07)
	arena.fx.flash(mp + aim * 6.0, aim.angle(), 6.0, Color8(255, 150, 70), 0.05)
	arena.fx.sawdust(mp, aim, 12)
	recoil = 4.0
	_pump_t = PUMP_TIME
	_ejected = false
	mech.visual.kick(Vector2(0.14, -0.12))
	mech.knock -= aim * 55.0
	JuiceManager.add_trauma(0.16)
	Sfx.play_var("shotgun", 1.0, 0.08)


func _punch() -> void:
	var arena = _arena()
	if arena == null:
		return
	alt_cd = 0.75
	punch_t = PUNCH_TIME
	mech.visual.kick(Vector2(0.16, -0.1))
	var size: float = mech.stats.g("alt_size_mult")
	var reach := 26.0 * size
	var dmg: float = 30.0 * mech.stats.g("alt_damage_mult") * mech.damage_mult()
	var origin := global_position
	var hit_any := false
	for e in arena.enemies_in_radius(origin, reach + 12.0):
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius:
			continue
		if to.length() > 6.0 and absf(aim.angle_to(to)) > 1.0:
			continue
		e.take_damage(dmg, origin, 260.0, {"owner": mech, "kind": "punch"})
		hit_any = true
	var fist := origin + aim * (14.0 * size)
	arena.fx.ring(fist, 12.0 * size, Color8(255, 248, 231), 0.18)
	arena.fx.flash(fist, aim.angle(), 7.0 * size, Color8(255, 248, 231), 0.06)
	if hit_any:
		JuiceManager.hit_stop(0.055)
		JuiceManager.add_trauma(0.32)
		Sfx.play_var("punch", 0.9, 0.1)
		arena.fx.burst(fist, 10, [PixelArt.C["t"], PixelArt.C["w"], PixelArt.C["y"]], 60, 160, 0.15, 0.3)
	else:
		JuiceManager.add_trauma(0.08)
		Sfx.play_var("punch", 1.25, 0.1, -6.0)


func _eject_shell() -> void:
	var arena = _arena()
	if arena == null:
		return
	var at := to_global(Vector2(6, -6))
	var v := Vector2(-aim.x * randf_range(20, 45), randf_range(-95, -70))
	arena.fx.particle(at, v, 0.7, PixelArt.C["r"], 1.0, 300.0, 0.8)
	arena.fx.particle(at, v * 0.6 + Vector2(0, 10), 0.4, PixelArt.C["t"], 1.0, 200.0, 2.0)


## Slide-action pump offset: snaps back mid-cycle, then forward again.
func _pump_offset() -> float:
	if _pump_t <= 0.0:
		return 0.0
	var t := 1.0 - _pump_t / PUMP_TIME
	if t < 0.3:
		return 0.0
	return -3.0 * sin(clampf((t - 0.3) / 0.7, 0.0, 1.0) * PI)


## Tube-fist extension along the punch timeline: wind-up, strike, hold, retract.
func _punch_ext() -> float:
	if punch_t <= 0.0:
		return 0.0
	var size: float = mech.stats.g("alt_size_mult")
	var reach := 16.0 * size
	var t := 1.0 - punch_t / PUNCH_TIME
	if t < 0.12:
		return -4.0 * (t / 0.12)
	if t < 0.3:
		var u := (t - 0.12) / 0.18
		return lerpf(-4.0, reach + 2.0, 1.0 - pow(1.0 - u, 3.0))
	if t < 0.5:
		return lerpf(reach + 2.0, reach, (t - 0.3) / 0.2)
	return lerpf(reach, 0.0, (t - 0.5) / 0.5)


func _draw_weapon() -> void:
	var k: Color = PixelArt.C["k"]
	# shoulder joints
	for jy in [-5.0, 4.0]:
		draw_rect(Rect2(-3, jy - 1, 3, 3), k)
		draw_rect(Rect2(-2, jy, 1, 1), PixelArt.C["W"])
	# shotgun with live pump forend
	var gx := -1.0 - recoil
	draw_texture(PixelArt.tex("brawler_gun_body"), Vector2(gx, -8.0).round())
	var pump := Vector2(gx + 9.0 + _pump_offset(), -3.0).round()
	draw_rect(Rect2(pump - Vector2(1, 1), Vector2(6, 3)), k)
	draw_rect(Rect2(pump, Vector2(4, 1)), PixelArt.C["t"])
	# tube fist: wind-up, smear on the strike, follow-through
	var ext := _punch_ext()
	var t := 1.0 - punch_t / PUNCH_TIME if punch_t > 0.0 else 1.0
	if t > 0.12 and t < 0.45:
		draw_texture(PixelArt.tex("brawler_fist_smear"), Vector2(-12.0 + ext, 0.0).round(), Color(1, 1, 1, 0.8))
	draw_texture(PixelArt.tex("brawler_fist"), Vector2(-6.0 + ext, 0.0).round())
