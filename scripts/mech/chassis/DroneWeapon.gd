extends WeaponMount
## WHIRLYBIRD-Z: fire = seed bombs tossed ahead of the drone, alt = Rotor Gust, a cone of wind that blows rats
## back and stuns them briefly. ADR-0003.

const SELF := preload("res://scripts/mech/chassis/DroneWeapon.gd")
const GUST_REACH := 58.0
const GUST_CONE := 0.95        # radians either side of the aim

var _gust_t := 0.0


func _tick_extra(delta: float) -> void:
	_gust_t = maxf(0.0, _gust_t - delta)


func muzzle_pos(side: float = 0.0) -> Vector2:
	return global_position + aim * 8.0 + aim.orthogonal() * side


func _fire() -> void:
	var arena = _arena()
	if arena == null:
		return
	cooldown = 0.5 / mech.fire_rate_mult()
	var n: int = 1 + mech.stats.gi("extra_projectiles")
	var dmg: float = 12.0 * mech.damage_mult()
	var owner_ref: WeakRef = weakref(mech)
	var from: Vector2 = mech.global_position + Vector2(0, -2)
	for i in n:
		var spread := 0.0
		if n > 1:
			spread = lerpf(-0.22 * (n - 1), 0.22 * (n - 1), float(i) / float(n - 1))
		var to := from + Vector2.from_angle(aim.angle() + spread) * (34.0 + randf_range(-3.0, 3.0))
		# a WeakRef and a script constant, never the nodes: the drone can be gone before the bomb lands
		arena.shots.lob(from, to, 0.45, 5.0, "seed_bomb",
			func(p: Vector2): SELF._land(p, 18.0, dmg, owner_ref), {"owner": mech})
	recoil = 2.0
	mech.visual.kick(Vector2(0.04, -0.05))
	mech.knock -= aim * 10.0
	Sfx.play_var("throw", 1.4, 0.1, -8.0)


## A seed bomb lands: a small blast with falloff and a spray of seed shells.
static func _land(pos: Vector2, radius: float, dmg: float, owner_ref: WeakRef) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	var info := {"kind": "seedbomb"}
	var owner_node = owner_ref.get_ref()
	if owner_node != null:
		info["owner"] = owner_node
	for e in arena.enemies_in_radius(pos, radius):
		if is_instance_valid(e) and e.alive:
			var falloff := 1.0 - 0.4 * clampf(pos.distance_to(e.global_position) / radius, 0.0, 1.0)
			e.take_damage(dmg * falloff, pos, 90.0, info)
	arena.fx.seed_shells(pos, 6)
	arena.fx.burst(pos, 8, [PixelArt.C["S"], PixelArt.C["s"], PixelArt.C["y"]], 30, 90, 0.2, 0.4, 1.0, 120.0)
	arena.fx.ring(pos, radius, Color8(255, 222, 170), 0.2)
	JuiceManager.add_trauma(0.08)
	Sfx.play_var("explosion", 1.8, 0.1, -12.0)


## Rotor Gust: wind in a cone ahead. It hurts a little, shoves hard and stuns for under a second.
func _alt() -> void:
	var arena = _arena()
	if arena == null:
		return
	alt_cd = 2.2
	var origin: Vector2 = mech.global_position
	var reach: float = GUST_REACH * mech.stats.g("alt_size_mult")
	var dmg: float = 4.0 * mech.stats.g("alt_damage_mult") * mech.damage_mult()
	for e in arena.enemies_in_radius(origin, reach + 12.0):
		if not is_instance_valid(e) or not e.alive:
			continue
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius:
			continue
		if to.length() > 8.0 and absf(aim.angle_to(to)) > GUST_CONE:
			continue
		e.take_damage(dmg, origin, 420.0, {"owner": mech, "kind": "gust", "stun": 0.7})
	_gust_t = 0.35
	for k in 12:
		var along := 8.0 + k * 4.5
		var at := origin + Vector2(0, -8) + aim * along + aim.orthogonal() * randf_range(-along * 0.5, along * 0.5)
		arena.fx.particle(at, aim * randf_range(170.0, 260.0), 0.3, Color(1, 1, 1, 0.6), 1.0, 0.0, 3.0)
	arena.fx.ring(origin + aim * 14.0, 16.0, Color(1, 1, 1, 0.7), 0.2)
	mech.knock -= aim * 80.0
	mech.visual.kick(Vector2(0.2, -0.15))
	JuiceManager.add_trauma(0.15)
	Sfx.play_var("vent", 1.5, 0.08, -4.0)


func _draw_weapon() -> void:
	# a small seed-bomb nozzle under the pod
	var k: Color = PixelArt.C["k"]
	draw_rect(Rect2(-1 - recoil, -2, 9, 4), k)
	draw_rect(Rect2(-recoil, -1, 7, 2), PixelArt.C["g"])
	draw_rect(Rect2(6 - recoil, -1, 1, 2), PixelArt.C["G"])
	# the gust: three fading arcs that spread out along the aim
	if _gust_t > 0.0:
		var t := 1.0 - _gust_t / 0.35
		for i in 3:
			var r := 12.0 + i * 9.0 + t * 14.0
			draw_arc(Vector2.ZERO, r, -GUST_CONE * 0.8, GUST_CONE * 0.8, 10, Color(1, 1, 1, (1.0 - t) * 0.8), 1.0)
