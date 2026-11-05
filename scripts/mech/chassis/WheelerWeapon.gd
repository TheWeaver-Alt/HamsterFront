extends WeaponMount
## WHEELER-X: dual Toothpick Railguns (fire) and Burnout Dash (alt). ADR-0003.

var barrel := 0
var _bkick := [0.0, 0.0]
var _coil := [0.0, 0.0]


func _tick_extra(delta: float) -> void:
	for b in 2:
		_bkick[b] = move_toward(float(_bkick[b]), 0.0, 30.0 * delta)
		_coil[b] = maxf(0.0, float(_coil[b]) - delta * 5.0)


func _fire() -> void:
	_fire_rails()


func _alt() -> void:
	_dash()


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
	_bkick[barrel] = 3.0
	_coil[barrel] = 1.0
	mech.visual.kick(Vector2(0.03, -0.03))
	JuiceManager.add_trauma(0.035)
	Sfx.play("rail", randf_range(0.95, 1.2), -6.0)


func _dash() -> void:
	var dir: Vector2 = mech.input.move if mech.input.move.length() > 0.2 else aim
	alt_cd = 1.5
	mech.start_dash(dir.normalized())
	Sfx.play("throw", 0.7, -2.0)
	JuiceManager.add_trauma(0.12)


func _draw_weapon() -> void:
	var hx := -4.0 - recoil * 0.5
	var bar := PixelArt.tex("wheeler_rail_barrel")
	draw_texture(bar, Vector2(-1.0 - float(_bkick[0]), -4.0).round())
	draw_texture(bar, Vector2(-1.0 - float(_bkick[1]), 1.0).round())
	draw_texture(PixelArt.tex("wheeler_rail_housing"), Vector2(hx, -5.0).round())
	# coils glow on the barrel that just fired
	for b in 2:
		var cg: float = _coil[b]
		if cg <= 0.0:
			continue
		var by := -3.0 if b == 0 else 2.0
		for cx in [2.0, 5.0, 8.0]:
			draw_rect(Rect2(Vector2(cx - float(_bkick[b]), by - 1.0).round(), Vector2(1, 1)), Color(0.75, 1.0, 1.0, cg))
