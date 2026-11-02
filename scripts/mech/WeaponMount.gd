class_name WeaponMount
extends Node2D
## Rotating weapon hardpoint. Handles firing for both chassis:
##   BRAWLER-01  fire = Sawdust Shotgun        alt = Cardboard-Tube Fist (melee punch)
##   WHEELER-X   fire = dual Toothpick Railguns alt = Burnout Dash (fire trail)

const PUNCH_TIME := 0.2

var mech = null   # MechPlayer
var cooldown := 0.0
var alt_cd := 0.0
var punch_t := 0.0
var barrel := 0
var recoil := 0.0
var aim := Vector2.RIGHT


func _ready() -> void:
	mech = get_parent()


func tick(delta: float, aim_dir: Vector2, fire_held: bool, alt_pressed: bool, can_act: bool) -> void:
	aim = aim_dir
	rotation = aim.angle()
	scale = Vector2(1, -1 if aim.x < 0.0 else 1)
	cooldown = maxf(0.0, cooldown - delta)
	alt_cd = maxf(0.0, alt_cd - delta)
	punch_t = maxf(0.0, punch_t - delta)
	recoil = move_toward(recoil, 0.0, 40.0 * delta)
	if can_act:
		if fire_held and cooldown <= 0.0:
			if mech.chassis == "brawler":
				_fire_shotgun()
			else:
				_fire_rails()
		if alt_pressed and alt_cd <= 0.0:
			if mech.chassis == "brawler":
				_punch()
			else:
				_dash()
	queue_redraw()


func muzzle_pos(side: float = 0.0) -> Vector2:
	return global_position + aim * 15.0 + aim.orthogonal() * side + (aim.orthogonal() * (4.0 if aim.x >= 0.0 else -4.0) if mech.chassis == "brawler" else Vector2.ZERO)


func _arena():
	return GameManager.arena


# ------------------------------------------------------------------ BRAWLER

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
	mech.knock -= aim * 55.0
	JuiceManager.add_trauma(0.16)
	Sfx.play_var("shotgun", 1.0, 0.08)


func _punch() -> void:
	var arena = _arena()
	if arena == null:
		return
	alt_cd = 0.75
	punch_t = PUNCH_TIME
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


# ------------------------------------------------------------------ WHEELER

func _fire_rails() -> void:
	var arena = _arena()
	if arena == null:
		return
	cooldown = 0.12 / mech.fire_rate_mult()
	barrel = 1 - barrel
	var side := -3.0 if barrel == 0 else 3.0
	var mp: Vector2 = muzzle_pos(side * (1.0 if aim.x >= 0.0 else -1.0))
	var dmg: float = 6.5 * mech.damage_mult()
	var pierce: int = 1 + mech.stats.gi("pierce")
	var extra: int = mech.stats.gi("extra_projectiles")
	var count := 1 + extra
	for i in count:
		var spread := 0.0
		if count > 1:
			spread = lerpf(-0.09 * extra, 0.09 * extra, float(i) / float(count - 1))
		var v := Vector2.from_angle(aim.angle() + spread + randf_range(-0.03, 0.03)) * 540.0
		arena.shots.fire(mp, v, dmg, {"kind": "toothpick", "life": 0.6, "radius": 2.0,
			"knockback": 18.0, "pierce": pierce, "owner": mech})
	arena.fx.flash(mp, aim.angle(), 7.0, Color8(150, 220, 255), 0.05)
	arena.fx.sparks(mp, Color8(90, 200, 230), 2, aim)
	recoil = 2.0
	JuiceManager.add_trauma(0.035)
	Sfx.play("rail", randf_range(0.95, 1.2), -6.0)


func _dash() -> void:
	var dir: Vector2 = mech.input.move if mech.input.move.length() > 0.2 else aim
	alt_cd = 1.5
	mech.start_dash(dir.normalized())
	Sfx.play("throw", 0.7, -2.0)
	JuiceManager.add_trauma(0.12)


# ------------------------------------------------------------------ draw

func _draw() -> void:
	if mech == null or mech.downed:
		return
	if mech.chassis == "brawler":
		# shotgun on the upper hardpoint, tube-fist on the lower one (keeps the pilot visible)
		var gun := PixelArt.tex("brawler_gun")
		draw_texture(gun, Vector2(-1.0 - recoil, -8.0).round())
		var fist := PixelArt.tex("brawler_fist")
		var ext := 0.0
		if punch_t > 0.0:
			var t := 1.0 - punch_t / PUNCH_TIME
			ext = sin(t * PI) * 14.0 * mech.stats.g("alt_size_mult")
		draw_texture(fist, Vector2(-6.0 + ext, 0.0).round())
	else:
		var rails := PixelArt.tex("wheeler_rails")
		draw_texture(rails, Vector2(-4.0 - recoil, -5.0).round())
