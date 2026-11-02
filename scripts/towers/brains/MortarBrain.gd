extends TowerBrain
## Cedar-Shaving Mortar: lobs canisters of cedar shavings + sneezing powder at the densest rat
## pack in range, leading moving targets. The blast blinds/stuns everything caught in it.
## Sugar Rush: fires a three-canister spread.

const BASE_RATE := 0.5        # shots per second
const BASE_DAMAGE := 18.0
const BASE_RADIUS := 30.0
const BASE_STUN := 1.2
const MIN_RANGE := 40.0

var _cd := 1.0
var _recoil := 0.0
var _facing := 1.0
var _t := 0.0
var _dust_cd := 2.0
const MUZZLE := Vector2(7.6, -15.4)   # muzzle mouth, local, facing right


func debris_texture() -> Texture2D:
	return PixelArt.tex("tower_mortar_%d" % tower.level)


func _muzzle_local() -> Vector2:
	return Vector2(MUZZLE.x * _facing, MUZZLE.y)


func physics(delta: float) -> void:
	_t += delta
	_cd -= delta
	_recoil = move_toward(_recoil, 0.0, delta * 2.2)
	# idle: the odd puff of cedar dust drifts out of the tube
	_dust_cd -= delta
	if _dust_cd <= 0.0:
		_dust_cd = randf_range(2.0, 4.0)
		var mp := tower.global_position + _muzzle_local()
		GameManager.arena.fx.particle(mp, Vector2(randf_range(-6, 6), randf_range(-14, -8)), 1.0,
			PixelArt.C["c"], 1.0, -4.0, 1.5)
		GameManager.arena.fx.particle(mp + Vector2(1, 0), Vector2(randf_range(-4, 4), randf_range(-10, -6)), 0.8,
			PixelArt.C["t"], 1.0, -4.0, 1.5)
	if _cd > 0.0:
		return
	var target = _pick_target()
	if target == null:
		return
	_cd = 1.0 / (BASE_RATE * tower.fire_rate_mult())
	_fire(target)


## Densest cluster outside the minimum range (counts neighbours of the first 12 candidates).
func _pick_target():
	var arena = GameManager.arena
	var best = null
	var best_n := -1
	var checked := 0
	for e in tower.get_targets():
		if tower.global_position.distance_to(e.global_position) < MIN_RANGE:
			continue
		var n: int = arena.enemies_in_radius(e.global_position, 26.0).size()
		if e.is_boss:
			n += 4
		if n > best_n:
			best_n = n
			best = e
		checked += 1
		if checked >= 12:
			break
	return best


func _fire(target) -> void:
	var arena = GameManager.arena
	var from := tower.global_position + _muzzle_local()
	var tpos: Vector2 = target.global_position
	var dist := from.distance_to(tpos)
	var flight := 0.8 + dist / 500.0
	# lead the target along its current velocity
	var lead: Vector2 = target.velocity * flight * 0.85
	var aim := tpos + lead.limit_length(60.0)
	_facing = -1.0 if aim.x < tower.global_position.x else 1.0
	from = tower.global_position + _muzzle_local()
	var shots := [aim]
	if tower.is_overdrive():
		shots.append(aim + Vector2(randf_range(-26, -14), randf_range(-12, 12)))
		shots.append(aim + Vector2(randf_range(14, 26), randf_range(-12, 12)))
	var radius := BASE_RADIUS * GameManager.gstats.g("mortar_radius_mult", 1.0) * (1.0 + 0.1 * (tower.level - 1))
	var dmg := BASE_DAMAGE * tower.damage_mult()
	var stun := BASE_STUN + GameManager.gstats.g("mortar_stun_bonus", 0.0)
	# a WeakRef, not the tower: the tower can die while the shell is in flight, and calling a
	# lambda whose captured node was freed logs an engine error
	var owner_ref: WeakRef = weakref(tower)
	for s in shots:
		var land_pos: Vector2 = s
		arena.shots.lob(from, land_pos, flight, 50.0 + dist * 0.15, "mortar",
			func(p: Vector2): _land(p, radius, dmg, stun, owner_ref), {"owner": tower})
	_recoil = 1.0
	arena.fx.flash(from, -PI / 2.0 + 0.6 * _facing, 6.0, Color8(255, 222, 170), 0.07)
	arena.fx.burst(from, 8, [PixelArt.C["t"], PixelArt.C["c"], PixelArt.C["y"]], 30, 90, 0.2, 0.5, 1.0, 120.0,
		3.0, Vector2(0.5 * _facing, -1.0), 0.6)
	arena.fx.smoke(from, 3)
	JuiceManager.add_trauma(0.08)
	Sfx.play_var("mortar_fire", 1.0, 0.08, -4.0)


func _land(pos: Vector2, radius: float, dmg: float, stun: float, owner_ref: WeakRef) -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	var info := {"stun": stun, "kind": "mortar"}
	var owner_node = owner_ref.get_ref()
	if owner_node != null:
		info["owner"] = owner_node
	for e in arena.enemies_in_radius(pos, radius):
		if is_instance_valid(e) and e.alive:
			var falloff := 1.0 - 0.4 * clampf(pos.distance_to(e.global_position) / radius, 0.0, 1.0)
			e.take_damage(dmg * falloff, pos, 70.0, info)
	arena.fx.explosion(pos, radius * 0.7, "sneeze")
	arena.fx.ring(pos, radius, Color8(255, 222, 170), 0.3)
	# lingering sneeze-powder puff
	arena.fx.burst(pos, 14, [Color(1, 0.95, 0.8, 0.8), PixelArt.C["c"], PixelArt.C["t"]], 5, 30, 0.6, 1.2, 2.0, -15.0, 1.5)
	arena.hazards.add("scorch", pos, radius * 0.4, 6.0)
	JuiceManager.add_trauma(0.2)
	Sfx.play_var("sneeze", 1.0, 0.15, -6.0)
	Sfx.play_var("explosion", 1.4, 0.1, -10.0)


func draw(ci: Node2D) -> void:
	var tex := PixelArt.tex("tower_mortar_%d" % tower.level)
	# compress-and-kick: squash down + back on firing, overshoot, settle (pivot on the turntable)
	var p := 1.0 - _recoil
	var env := exp(-p * 5.0) * (1.0 if _recoil > 0.0 else 0.0)
	var sy := 1.0 - 0.2 * env * cos(p * 11.0)
	var sx := 1.0 + 0.1 * env * cos(p * 11.0)
	var kick := Vector2(-2.5 * _facing, 1.0) * env
	ci.draw_set_transform(Vector2(0, 1.0 - sy * 1.0) + kick.round(), 0.0, Vector2(_facing * sx, sy))
	ci.draw_texture(tex, Vector2(-11, -20))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# reload: a fresh canister rises out of the sack towards the breech
	var rate := BASE_RATE * tower.fire_rate_mult()
	var ready := clampf(1.0 - _cd * rate, 0.0, 1.0)
	if ready < 1.0 and ready > 0.15:
		var cp := Vector2(-6.0 * _facing, -10.0 - roundf(ready * 4.0))
		ci.draw_rect(Rect2(cp + Vector2(-1, 0), Vector2(3, 3)), PixelArt.C["T"])
		ci.draw_rect(Rect2(cp + Vector2(-1, 0), Vector2(3, 1)), PixelArt.C["c"])
	elif ready >= 1.0 and int(_t * 2.0) % 2 == 0:
		# loaded: a wisp of shaving pokes out of the muzzle
		var mp := _muzzle_local() + Vector2(0, -2)
		ci.draw_rect(Rect2(mp.round(), Vector2(1, 1)), PixelArt.C["y"])
	if tower.is_overdrive():
		# candy-striped sparks pop out of the muzzle
		var mp2 := _muzzle_local()
		var c := Color.from_hsv(fmod(_t * 2.0, 1.0), 0.6, 1.0)
		ci.draw_rect(Rect2((mp2 + Vector2(sin(_t * 9.0) * 3.0, -2.0 - fmod(_t * 12.0, 5.0))).round(), Vector2(1, 1)), c)
