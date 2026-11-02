class_name WeaponMount
extends Node2D
## Weapons for both mechs.
## BRAWLER-01: Sawdust Shotgun (primary) + hydraulic Cardboard-Tube Fist (alt).
## WHEELER-X: dual Toothpick Railguns (primary, hitscan, piercing) + Turbo Dash (alt).

const PUNCH_TIME := 0.18
const SHOTGUN_CD := 0.8
const RAIL_CD := 0.24
const FIST_CD := 0.55
const DASH_CD := 1.1
const RAIL_RANGE := 230.0

var mech: Node = null
var cd_primary := 0.0
var cd_alt := 0.0
var barrel := 1
var punch_t := 0.0
var muzzle_t := 0.0


func _ready() -> void:
	mech = get_parent()


func _physics_process(delta: float) -> void:
	cd_primary = maxf(0.0, cd_primary - delta)
	cd_alt = maxf(0.0, cd_alt - delta)
	punch_t = maxf(0.0, punch_t - delta)
	muzzle_t = maxf(0.0, muzzle_t - delta)


func _pid() -> int:
	return int(mech.player_id)


func fire_rate_mult() -> float:
	var m := GameManager.pmodf(_pid(), "fire_rate_mult")
	if float(mech.fire_boost_t) > 0.0:
		m *= 1.5
	return m


func punch_ratio() -> float:
	return punch_t / PUNCH_TIME


func muzzle_origin(dir: Vector2) -> Vector2:
	var base: Vector2 = mech.global_position + Vector2(0, -10)
	if mech.mech_kind == "wheeler":
		return base + Vector2(0, -4) + dir.orthogonal() * 3.0 * barrel + dir * 9.0
	return base + dir * 13.0


func try_primary(dir: Vector2) -> void:
	if cd_primary > 0.0:
		return
	if mech.mech_kind == "brawler":
		_shotgun(dir)
	else:
		_railgun(dir)


func try_alt(dir: Vector2, move: Vector2) -> void:
	if cd_alt > 0.0:
		return
	if mech.mech_kind == "brawler":
		_fist(dir)
	else:
		_dash(move if move.length() > 0.2 else dir)


func _shotgun(dir: Vector2) -> void:
	var arena = GameManager.arena
	cd_primary = SHOTGUN_CD / fire_rate_mult()
	var pid := _pid()
	var dm: float = mech.damage_mult()
	var pellets := 6 + GameManager.pmodi(pid, "pellet_bonus")
	var origin := muzzle_origin(dir)
	for i in pellets:
		var ang := dir.angle() + randf_range(-0.3, 0.3)
		var p := Projectile.new().configure(origin, Vector2.from_angle(ang) * randf_range(250.0, 330.0), 7.0 * dm, "pellet", true, pid)
		p.life = randf_range(0.3, 0.42)
		p.knock = 70.0 * GameManager.pmodf(pid, "knock_mult")
		p.radius = 2.0
		arena.add_projectile(p)
	JuiceManager.flash(origin, 7.0, Color(1.0, 0.9, 0.5), 0.06)
	JuiceManager.burst(origin, Pal.CEDAR, 8, 120.0, 0.35, 2.0, 0.0, false, dir, 1.0)
	JuiceManager.burst(origin, Color(0.85, 0.85, 0.85, 0.6), 4, 30.0, 0.5, 3.0, -20.0)
	JuiceManager.add_trauma(0.2)
	mech.apply_knock(-dir * 70.0)
	muzzle_t = 0.06
	SFX.play("shotgun", randf_range(0.9, 1.1), -2.0)


func _railgun(dir: Vector2) -> void:
	var arena = GameManager.arena
	cd_primary = RAIL_CD / fire_rate_mult()
	barrel = -barrel
	var pid := _pid()
	var origin := muzzle_origin(dir)
	var end: Vector2 = arena.raycast_solid(origin, origin + dir * RAIL_RANGE)
	var dmg: float = 12.0 * GameManager.pmodf(pid, "rail_damage_mult") * mech.damage_mult()
	var pierce := 1 + GameManager.pmodi(pid, "pierce_bonus")
	var hits: Array = arena.rats_on_segment(origin, end, 2.0)
	var count := 0
	for r in hits:
		r.take_damage(dmg, dir * 40.0, pid)
		JuiceManager.burst(r.global_position, Pal.TOOTHPICK, 3, 60.0, 0.2, 1.0, 0.0, false, dir, 1.2)
		count += 1
		if count > pierce:
			end = r.global_position
			break
	JuiceManager.beam(origin, end, Pal.BEAM, 1.0, 0.07, true)
	JuiceManager.beam(origin, end, Color(Pal.TOOTHPICK, 0.5), 3.0, 0.04, true)
	JuiceManager.flash(origin, 4.0, Pal.BEAM, 0.05)
	JuiceManager.burst(end, Pal.TOOTHPICK, 4, 50.0, 0.25, 1.0)
	JuiceManager.add_trauma(0.05)
	muzzle_t = 0.05
	SFX.play("rail", randf_range(0.95, 1.15), -6.0, 30)


func _fist(dir: Vector2) -> void:
	var arena = GameManager.arena
	cd_alt = FIST_CD
	punch_t = PUNCH_TIME
	var pid := _pid()
	var center: Vector2 = mech.global_position + Vector2(0, -8) + dir * 15.0
	var dmg: float = 34.0 * GameManager.pmodf(pid, "fist_damage_mult") * mech.damage_mult()
	var knock := 260.0 * GameManager.pmodf(pid, "knock_mult")
	var hit_any := false
	for r in arena.get_rats_in_radius(center, 18.0):
		r.take_damage(dmg, dir * knock, pid)
		r.apply_stun(0.3)
		hit_any = true
	if hit_any:
		JuiceManager.hitstop(0.06)
		JuiceManager.add_trauma(0.32)
		JuiceManager.burst(center, Pal.CARDBOARD, 10, 140.0, 0.35, 2.0, 0.0, false, dir, 1.6)
		JuiceManager.flash(center, 8.0, Pal.WHITE, 0.05)
		SFX.play("punch", randf_range(0.9, 1.1))
	else:
		SFX.play("whoosh", randf_range(1.2, 1.4), -6.0)
	JuiceManager.ring(center, 14.0, Color(Pal.WHITE, 0.7), 0.15)


func _dash(d: Vector2) -> void:
	cd_alt = DASH_CD
	mech.start_dash(d.normalized())
	JuiceManager.burst(mech.global_position, Pal.INK_SOFT, 8, 50.0, 0.5, 3.0, -20.0)
	SFX.play("whoosh", 0.8, -2.0)


func _draw() -> void:
	pass
