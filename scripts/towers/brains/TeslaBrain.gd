extends TowerBrain
## Exercise-Wheel Tesla Coil: a hamster (well, a hired intern) runs a wheel generator that charges
## a copper coil. Discharges chain lightning that jumps between rats. Mechs running alongside the
## wheel spin it faster, doubling the recharge rate.

const BASE_INTERVAL := 1.1
const BASE_DAMAGE := 14.0
const BASE_JUMPS := 3
const JUMP_RANGE := 48.0
const FALLOFF := 0.85
const SPIN_RADIUS := 28.0
const SPIN_SPEED := 40.0

var _cd := 0.8
var _wheel := 0.0
var _wheel_speed := 2.5
var _boost_t := 0.0
var _spin_text_cd := 0.0
var _zap_t := 0.0
var _t := 0.0


func _ball_local() -> Vector2:
	return Vector2(7, -21)


func _ball() -> Vector2:
	return tower.global_position + _ball_local()


func physics(delta: float) -> void:
	_t += delta
	_zap_t = maxf(0.0, _zap_t - delta)
	_spin_text_cd = maxf(0.0, _spin_text_cd - delta)
	# mechs jogging past spin the wheel
	var was_boosted := _boost_t > 0.0
	_boost_t = maxf(0.0, _boost_t - delta)
	for p in GameManager.living_players():
		if p.global_position.distance_to(tower.global_position) < SPIN_RADIUS and p.velocity.length() > SPIN_SPEED:
			_boost_t = 0.35
	var boosted := _boost_t > 0.0
	if boosted and not was_boosted and _spin_text_cd <= 0.0:
		_spin_text_cd = 2.0
		GameManager.arena.fx.float_text(tower.global_position + Vector2(-5, -26), "SPIN!", PixelArt.C["u"], 0.7, 10.0)
	var want_speed := 2.5 + (14.0 if boosted else 0.0) + (6.0 if tower.is_overdrive() else 0.0)
	_wheel_speed = move_toward(_wheel_speed, want_speed, delta * 30.0)
	_wheel += _wheel_speed * delta
	_cd -= delta * (2.0 if boosted else 1.0)
	if _cd > 0.0:
		return
	var first = tower.best_target("near")
	if first == null:
		_cd = 0.1
		return
	_cd = BASE_INTERVAL / tower.fire_rate_mult()
	_discharge(first)


func _discharge(first) -> void:
	var arena = GameManager.arena
	var od := tower.is_overdrive()
	var jumps := BASE_JUMPS + int(GameManager.gstats.g("tesla_chain_bonus", 0.0)) + (tower.level - 1) + (2 if od else 0)
	var dmg := BASE_DAMAGE * tower.damage_mult()
	var col := Color8(150, 220, 255)
	var from := _ball()
	var cur = first
	var hit: Array = []
	var link := 0
	while cur != null:
		var to: Vector2 = cur.global_position + Vector2(0, -4)
		var c := col if not od else Color.from_hsv(fmod(_t + link * 0.15, 1.0), 0.6, 1.0)
		arena.fx.bolt(from, to, c, 0.14, 4.0)
		arena.fx.sparks(to, c, 3)
		cur.take_damage(dmg, from, 30.0, {"owner": tower, "kind": "zap", "stun": 0.12})
		hit.append(cur)
		link += 1
		if link > jumps:
			break
		dmg *= FALLOFF
		from = to
		var nxt = null
		var bd := INF
		for e in arena.enemies_in_radius(to, JUMP_RANGE):
			if not is_instance_valid(e) or not e.alive or e.spawn_t > 0.0 or hit.has(e):
				continue
			var d := to.distance_squared_to(e.global_position)
			if d < bd:
				bd = d
				nxt = e
		cur = nxt
	arena.fx.flash(_ball(), randf() * TAU, 6.0, col, 0.06)
	arena.fx.ring(_ball(), 10.0, col, 0.15)
	_zap_t = 0.12
	JuiceManager.add_trauma(0.05 + 0.01 * link)
	Sfx.play_var("zap", 1.0 - 0.05 * mini(link, 6), 0.1, -6.0)


func draw(ci: Node2D) -> void:
	var lvl := tower.level
	var od := tower.is_overdrive()
	var center := Vector2(-5, -12)
	var g := PixelArt.C["G"]
	var gl := PixelArt.C["g"]
	# wheel stand
	ci.draw_line(center, Vector2(-9, -2), g, 1.0)
	ci.draw_line(center, Vector2(-1, -2), g, 1.0)
	# cable to the coil
	ci.draw_line(center + Vector2(1, 1), Vector2(3, -3), PixelArt.C["O"], 1.0)
	# wheel rim + spokes
	var rim := PixelArt.C["W"] if lvl < 3 else PixelArt.C["y"]
	PixelArt.draw_ring(ci, center, 7.0, rim, 40)
	PixelArt.draw_ring(ci, center, 6.0, gl, 36)
	for k in 4:
		var a := _wheel + k * PI / 4.0
		var d := Vector2.from_angle(a) * 5.5
		ci.draw_line((center - d).round(), (center + d).round(), gl, 1.0)
	ci.draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), g)
	# the intern hamster running at the bottom of the wheel
	var step := int(_wheel * 3.0) % 2
	var hp := center + Vector2(-1, 3)
	ci.draw_rect(Rect2(hp, Vector2(3, 2)), PixelArt.C["o"])
	ci.draw_rect(Rect2(hp + Vector2(2, -1), Vector2(2, 2)), PixelArt.C["o"])
	ci.draw_rect(Rect2(hp + Vector2(3, -1), Vector2(1, 1)), PixelArt.C["k"])
	ci.draw_rect(Rect2(hp + Vector2(step, 2), Vector2(1, 1)), PixelArt.C["p"])
	ci.draw_rect(Rect2(hp + Vector2(2 - step, 2), Vector2(1, 1)), PixelArt.C["p"])
	if _boost_t > 0.0:
		# motion streaks while boosted
		for k in 3:
			var a := _wheel * 2.0 + k * TAU / 3.0
			ci.draw_rect(Rect2((center + Vector2.from_angle(a) * 8.0).round(), Vector2(1, 1)), PixelArt.C["u"])
	# coil
	ci.draw_texture(PixelArt.tex("tower_tesla_coil_%d" % lvl), Vector2(1, -25))
	# top-ball glow: charges up as the next discharge approaches
	var ball := _ball_local()
	var charge := 1.0 - clampf(_cd / (BASE_INTERVAL / maxf(tower.fire_rate_mult(), 0.01)), 0.0, 1.0)
	var glow := Color(0.59, 0.86, 1.0, 0.15 + 0.35 * charge)
	if od:
		glow = Color.from_hsv(fmod(_t * 1.2, 1.0), 0.6, 1.0, 0.5)
	PixelArt.draw_disk(ci, ball, 3.0 + charge * 2.0, glow)
	if _zap_t > 0.0:
		PixelArt.draw_disk(ci, ball, 4.0, Color(1, 1, 1, 0.8))
	if charge > 0.7 or od:
		# crackling mini-arcs around the ball
		for k in 2:
			var a := randf() * TAU
			var p1 := ball + Vector2.from_angle(a) * 3.0
			var p2 := ball + Vector2.from_angle(a + randf_range(-0.6, 0.6)) * (5.0 + randf() * 3.0)
			ci.draw_line(p1.round(), p2.round(), Color8(220, 245, 255), 1.0)
