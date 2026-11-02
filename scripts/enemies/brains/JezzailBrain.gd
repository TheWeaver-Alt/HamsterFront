extends RatBrain
## Warp-Gouda Jezzail: two-rat sniper team. Shuffles along the flow field until a mech, tower
## or the Silo is in range with clear line of sight, plants, paints the target with a long
## green laser sight (tracking, then locking + blinking for the last beat), fires a fast warp
## round, fumbles the reload and sometimes relocates.

const RANGE := 170.0
const AIM_TIME := 1.5
const LOCK_TIME := 0.35
const COOLDOWN := 3.0
const FUMBLE_TIME := 1.4
const SHOT_SPEED := 470.0
const BASE_SHOT_DMG := 22.0
const MUZZLE := Vector2(14, -10)

const AIM_BARKS := ["Hold-still, fur-thing! Steady-steady...", "Warp-shot! Aim-aim!", "Bipod! Stop wiggle-squirm!"]
const FIRE_BARKS := ["BOOM-CRACK!", "Got-got it! Maybe-maybe.", "Reload-quick! QUICK!"]

var state := "walk"           # walk | aim | fumble
var aim_t := 0.0
var cool_t := 0.0
var fumble_t := 0.0
var relocate_t := 0.0
var aim_target = null         # mech / tower; null + aim_silo = aiming at the Silo
var aim_silo := false
var aim_point := Vector2.ZERO
var _scan_t := 0.0
var sight: Node2D = null


func setup(r: RatEnemy) -> void:
	super.setup(r)
	sight = Node2D.new()
	sight.name = "LaserSight"
	sight.z_index = 30
	sight.z_as_relative = false
	r.add_child(sight)
	sight.draw.connect(_draw_sight)
	cool_t = randf_range(0.3, 1.2)


func get_bark_offset() -> float:
	return -24.0


func _muzzle_off() -> Vector2:
	return Vector2(MUZZLE.x * rat.facing, MUZZLE.y)


func physics(delta: float) -> void:
	cool_t = maxf(0.0, cool_t - delta)
	match state:
		"aim":
			_aim(delta)
		"fumble":
			fumble_t -= delta
			rat.velocity = rat.knock
			rat.move_and_slide()
			if fumble_t <= 0.0:
				state = "walk"
				if randf() < 0.4:
					relocate_t = randf_range(1.2, 2.4)
		_:
			_walk(delta)
	sight.queue_redraw()


func _walk(delta: float) -> void:
	relocate_t = maxf(0.0, relocate_t - delta)
	_scan_t -= delta
	if relocate_t <= 0.0 and cool_t <= 0.0 and _scan_t <= 0.0:
		_scan_t = 0.25
		if _find_target():
			_start_aim()
			return
	var arena = GameManager.arena
	if rat.global_position.distance_to(ArenaMap.SILO_CENTER) < ArenaMap.SILO_RADIUS + rat.radius + 8.0:
		rat.velocity = rat.knock
		rat.move_and_slide()
		return
	var dest: Vector2 = arena.map.flow_waypoint(rat.global_position) + rat.personal_offset
	rat.move_toward_point(dest, rat.speed * rat.slow_mult, delta)


func _find_target() -> bool:
	var arena = GameManager.arena
	var from: Vector2 = rat.global_position + _muzzle_off()
	var best = null
	var bd := RANGE
	for p in GameManager.players:
		if not is_instance_valid(p) or p.downed:
			continue
		var tp: Vector2 = p.global_position + Vector2(0, -10)
		var d := from.distance_to(tp)
		if d < bd and _los(from, tp):
			bd = d
			best = p
	if best == null:
		bd = RANGE
		for t in arena.towers:
			if not is_instance_valid(t) or not t.alive:
				continue
			var tp: Vector2 = t.global_position + Vector2(0, -6)
			var d := from.distance_to(tp)
			if d < bd and _los(from, tp):
				bd = d
				best = t
	if best != null:
		aim_target = best
		aim_silo = false
		return true
	var sp := ArenaMap.SILO_CENTER
	if from.distance_to(sp) < RANGE and _los(from, sp):
		aim_target = null
		aim_silo = true
		return true
	return false


func _los(a: Vector2, b: Vector2) -> bool:
	var map = GameManager.arena.map
	var steps := int(a.distance_to(b) / 6.0)
	for i in range(1, steps):
		if map.is_solid_at(a.lerp(b, float(i) / steps)):
			return false
	return true


func _target_point() -> Vector2:
	if aim_silo:
		return ArenaMap.SILO_CENTER
	var off := Vector2(0, -10) if aim_target is MechPlayer else Vector2(0, -6)
	return aim_target.global_position + off


func _start_aim() -> void:
	state = "aim"
	aim_t = AIM_TIME
	aim_point = _target_point()
	rat.facing = 1.0 if aim_point.x >= rat.global_position.x else -1.0
	Sfx.play("jezzail_charge", randf_range(0.95, 1.05), -6.0)
	if randf() < 0.18:
		JuiceManager.bark(rat, AIM_BARKS[randi() % AIM_BARKS.size()], "rat", false, 6.0)


func _aim(delta: float) -> void:
	rat.velocity = rat.knock
	rat.move_and_slide()
	aim_t -= delta
	if aim_t > LOCK_TIME:
		if not aim_silo:
			var valid: bool = is_instance_valid(aim_target) and ((aim_target is MechPlayer and not aim_target.downed) or (not (aim_target is MechPlayer) and aim_target.alive))
			if not valid:
				state = "walk"
				return
		aim_point = _target_point()
	rat.facing = 1.0 if aim_point.x >= rat.global_position.x else -1.0
	if aim_t <= 0.0:
		_fire()


func _fire() -> void:
	var arena = GameManager.arena
	var from: Vector2 = rat.global_position + _muzzle_off()
	var dir := (aim_point - from).normalized()
	var dmg := BASE_SHOT_DMG * maxf(1.0, (rat.hp_scale - 1.0) * 0.5 + 1.0)
	arena.shots.fire(from, dir * SHOT_SPEED, dmg, {"kind": "jezzail", "team": 1, "radius": 3.0,
		"life": (RANGE + 60.0) / SHOT_SPEED, "owner": rat})
	arena.fx.flash(from, dir.angle(), 8.0, Color8(170, 255, 100), 0.08)
	arena.fx.warp_sparks(from, 8)
	arena.fx.smoke(from, 3)
	rat.knock -= dir * 70.0
	Sfx.play("jezzail_fire", randf_range(0.95, 1.05), -2.0)
	JuiceManager.add_trauma(0.12)
	if randf() < 0.12:
		JuiceManager.bark(rat, FIRE_BARKS[randi() % FIRE_BARKS.size()], "rat", false, 6.0)
	state = "fumble"
	fumble_t = FUMBLE_TIME
	cool_t = COOLDOWN


func draw(ci: RatEnemy) -> void:
	var sprite := "rat_jez_walk_%d" % ci.walk_frame() if ci.moving() else "rat_jez_walk_0"
	var cell := Vector2(16, 4)
	match state:
		"aim":
			sprite = "rat_jez_aim_0"
		"fumble":
			if fumble_t > FUMBLE_TIME - 0.22:
				sprite = "rat_jez_recoil_0"
				cell = Vector2(14, 3)
			else:
				sprite = "rat_jez_fumble_%d" % (int(fumble_t * 8.0) % 2)
	if ci.hit_anim > 0.0 and state != "aim":
		sprite = "rat_jez_recoil_0"
		cell = Vector2(14, 3)
	ci.draw_sprite(sprite)
	# the warp-cheese cell pulses, brighter while charging a shot
	var sz := Vector2(34, 18)
	var charge := 0.0
	if state == "aim":
		charge = clampf(1.0 - aim_t / AIM_TIME, 0.0, 1.0)
	var pulse := 0.35 + 0.3 * sin(ci.anim_t * (6.0 + charge * 20.0)) + charge * 0.35
	ci.draw_sprite_px(sz, cell, Color(0.8, 1.0, 0.55, clampf(pulse, 0.0, 1.0)), Vector2(2, 1))
	if state == "fumble" and randf() < 0.2:
		var m := _muzzle_off()
		ci.draw_rect(Rect2(m.round() + Vector2(randi_range(-1, 1), -2), Vector2(1, 1)), PixelArt.C["g"])


func spawn_sprite(_ci: RatEnemy) -> String:
	return "rat_jez_walk_0"


## Laser sight drawn on a child canvas item above everything so it is always readable.
func _draw_sight() -> void:
	if state != "aim" or rat == null or not rat.alive:
		return
	var tms := Time.get_ticks_msec()
	var from := _muzzle_off()
	var to := aim_point - rat.global_position
	var dir := (to - from).normalized()
	var locked := aim_t <= LOCK_TIME
	var charge := clampf(1.0 - aim_t / AIM_TIME, 0.0, 1.0)
	var col: Color
	if locked:
		col = Color.WHITE if (tms / 45) % 2 == 0 else Color8(170, 255, 100)
	else:
		var pulse := 0.5 + 0.5 * sin(tms * 0.025)
		col = Color(0.67, 1.0, 0.4, 0.6 + 0.35 * pulse)
	# glow, core, and a faint over-shoot past the target
	sight.draw_line(from.round(), to.round(), Color(0.4, 1.0, 0.3, 0.22 + 0.25 * charge), 3.0)
	sight.draw_line(from.round(), to.round(), col, 1.0)
	sight.draw_line(to.round(), (from + dir * (RANGE + 40.0)).round(), Color(0.67, 1.0, 0.4, 0.14), 1.0)
	# target reticle: brackets close in as the shot charges
	var r := lerpf(9.0, 4.0, charge)
	var c := to.round()
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner: Vector2 = c + s * r
		sight.draw_rect(Rect2(corner, Vector2(1, 1)), col)
		sight.draw_rect(Rect2(corner - Vector2(s.x, 0), Vector2(1, 1)), col)
		sight.draw_rect(Rect2(corner - Vector2(0, s.y), Vector2(1, 1)), col)
	sight.draw_rect(Rect2(c, Vector2(1, 1)), col)
	# muzzle charge glow
	PixelArt.draw_disk(sight, from, 1.0 + charge * 2.0, Color(0.67, 1.0, 0.4, 0.5 + 0.4 * charge))
	if locked:
		PixelArt.draw_text_centered(sight, c + Vector2(0, -r - 9), "!", Color8(255, 90, 60))
