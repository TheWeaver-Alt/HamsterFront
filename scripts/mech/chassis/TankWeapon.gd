extends WeaponMount
## HOWITZER-9: fire = an artillery shell lobbed onto the nearest rat in the aim cone, alt = Stomp, a shockwave
## that stuns everything around it. ADR-0003.

const SELF := preload("res://scripts/mech/chassis/TankWeapon.gd")
const MIN_RANGE := 36.0
const MAX_RANGE := 190.0
const CONE := 0.6              # radians either side of the aim

var _slide := 0.0              # how far the barrel has slid back after a shot


func _tick_extra(delta: float) -> void:
	_slide = move_toward(_slide, 0.0, 22.0 * delta)


func muzzle_pos(side: float = 0.0) -> Vector2:
	return global_position + aim * 22.0 + aim.orthogonal() * side


## Where the shell should land: on the best rat in the aim cone, else a fixed distance along the aim.
func _aim_point() -> Vector2:
	var arena = _arena()
	var best = null
	var best_score := INF
	if arena != null:
		for e in arena.enemies:
			if not is_instance_valid(e) or not e.alive:
				continue
			var to: Vector2 = e.global_position - global_position
			var d := to.length()
			if d < MIN_RANGE or d > MAX_RANGE:
				continue
			var off := absf(aim.angle_to(to))
			if off > CONE:
				continue
			var score := d + off * 120.0
			if score < best_score:
				best_score = score
				best = e.global_position + (e.velocity * 0.6).limit_length(24.0)
	if best != null:
		return best
	return global_position + aim * 95.0


func _fire() -> void:
	var arena = _arena()
	if arena == null:
		return
	cooldown = 1.0 / mech.fire_rate_mult()
	var target := _aim_point()
	var mp := muzzle_pos()
	var dist := mp.distance_to(target)
	var flight := 0.55 + dist / 420.0
	var shells: int = 1 + mech.stats.gi("extra_projectiles") / 2
	var dmg: float = 20.0 * mech.damage_mult()
	var owner_ref: WeakRef = weakref(mech)
	for i in shells:
		var land := target
		if i > 0:
			land += Vector2(randf_range(-22.0, 22.0), randf_range(-14.0, 14.0))
		# a WeakRef and a script constant, never the nodes: the tank can be gone before the shell lands
		arena.shots.lob(mp, land, flight, 34.0 + dist * 0.14, "mortar",
			func(p: Vector2): SELF._land(p, 24.0, dmg, owner_ref), {"owner": mech})
	arena.fx.flash(mp, aim.angle(), 10.0, Color8(255, 222, 170), 0.08)
	arena.fx.burst(mp, 8, [PixelArt.C["w"], PixelArt.C["W"], PixelArt.C["y"]], 30, 90, 0.2, 0.5, 1.0, 100.0, 3.0, aim, 0.6)
	arena.fx.smoke(mp, 3)
	recoil = 4.0
	_slide = 4.0
	mech.visual.kick(Vector2(0.1, -0.08))
	mech.knock -= aim * 50.0
	JuiceManager.add_trauma(0.2)
	Sfx.play_var("mortar_fire", 0.8, 0.08, -2.0)


## A shell lands: damage with falloff, a blast, scorch, shaking.
static func _land(pos: Vector2, radius: float, dmg: float, owner_ref: WeakRef) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	var info := {"stun": 0.4, "kind": "shell"}
	var owner_node = owner_ref.get_ref()
	if owner_node != null:
		info["owner"] = owner_node
	for e in arena.enemies_in_radius(pos, radius):
		if is_instance_valid(e) and e.alive:
			var falloff := 1.0 - 0.4 * clampf(pos.distance_to(e.global_position) / radius, 0.0, 1.0)
			e.take_damage(dmg * falloff, pos, 120.0, info)
	arena.fx.explosion(pos, radius * 0.8, "fire")
	arena.fx.ring(pos, radius, Color8(255, 222, 170), 0.25)
	arena.hazards.add("scorch", pos, radius * 0.4, 6.0)
	JuiceManager.add_trauma(0.22)
	Sfx.play_var("explosion", 1.1, 0.1, -8.0)


## Stomp: a shockwave around the tank that damages a little, knocks back and stuns for about a second.
func _alt() -> void:
	var arena = _arena()
	if arena == null:
		return
	alt_cd = 3.0
	var origin: Vector2 = mech.global_position + Vector2(0, -2)
	var radius: float = 46.0 * mech.stats.g("alt_size_mult")
	var dmg: float = 12.0 * mech.stats.g("alt_damage_mult") * mech.damage_mult()
	var hit_any := false
	for e in arena.enemies_in_radius(origin, radius + 10.0):
		if not is_instance_valid(e) or not e.alive:
			continue
		if origin.distance_to(e.global_position) > radius + e.radius:
			continue
		e.take_damage(dmg, origin, 280.0, {"owner": mech, "kind": "stomp", "stun": 1.1})
		hit_any = true
	arena.fx.ring(origin, radius, Color8(255, 248, 231), 0.3)
	arena.fx.ring(origin, radius * 0.6, PixelArt.C["t"], 0.25)
	arena.fx.dust(origin, 14)
	mech.visual.kick(Vector2(0.3, -0.35))
	JuiceManager.add_trauma(0.4)
	if hit_any:
		JuiceManager.hit_stop(0.05)
	Sfx.play_var("explosion", 0.7, 0.08, -4.0)


func _draw_weapon() -> void:
	draw_texture(PixelArt.tex("tank_barrel"), Vector2(-2.0 - _slide, -2.0).round())
