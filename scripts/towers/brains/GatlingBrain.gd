extends TowerBrain
## Sunflower Gatling: rapid-fire hull spitter. Every few hulls leaves a shell pile on the
## ground that slows rats. "Flaming Hulls" mutation makes shots set rats on fire.
## Levels add barrels (3/4/5) and a wider spread; Sugar Rush spits candy-coloured flashes.

const BASE_RATE := 7.0        # shots per second
const BASE_DAMAGE := 3.4
const SHELL_EVERY := 4
const CANDY := ["r", "y", "u", "p", "Z", "v"]

var _cd := 0.0
var _shots := 0
var _spin := 0.0
var _spin_speed := 0.0
var _recoil := 0.0
var _phase := 0.0          # per-tower offset so neighbouring blooms don't sway in lockstep
var _glint_t := 0.0


func setup(t: TowerBase) -> void:
	super.setup(t)
	_phase = float((t.cell.x * 7 + t.cell.y * 13) % 10) * 0.37


func head_offset() -> Vector2:
	return Vector2(0, -12)


func debris_texture() -> Texture2D:
	return PixelArt.tex("tower_gatling_petals_%d_0" % tower.level)


func physics(delta: float) -> void:
	_cd -= delta
	_spin += _spin_speed * delta
	_recoil = move_toward(_recoil, 0.0, delta * 14.0)
	_glint_t -= delta
	var target = tower.best_target("first")
	if target == null:
		_spin_speed = move_toward(_spin_speed, 0.0, 30.0 * delta)
		# idle: the sunflower turns its face towards the sun and sways
		var sun := -2.25 + sin(tower.anim_t * 0.45 + _phase) * 0.3
		tower.head_angle = rotate_toward(tower.head_angle, sun, delta * 1.2)
		return
	_spin_speed = move_toward(_spin_speed, 30.0 + 10.0 * tower.level, 80.0 * delta)
	var aligned := tower.aim_head(target.global_position + Vector2(0, -4), delta, 12.0)
	if aligned and _cd <= 0.0:
		_cd = 1.0 / (BASE_RATE * tower.fire_rate_mult())
		_fire(target)


func _fire(target) -> void:
	var arena = GameManager.arena
	var flaming := GameManager.gstats.has_flag("gatling_flaming")
	var od := tower.is_overdrive()
	var mp := tower.muzzle(14.0)
	var spread := 0.06 + 0.02 * (tower.level - 1)
	var dir := Vector2.from_angle(tower.head_angle + randf_range(-spread, spread))
	arena.shots.fire(mp, dir * 330.0, BASE_DAMAGE * tower.damage_mult(), {
		"kind": "hull", "life": 0.6, "radius": 2.5, "knockback": 10.0, "owner": tower,
		"burn": 2.0 if flaming else 0.0})
	var flash_col := Color8(255, 214, 64)
	if flaming:
		flash_col = Color8(255, 120, 40)
	if od:
		flash_col = PixelArt.C[CANDY[_shots % CANDY.size()]]
	arena.fx.flash(mp, tower.head_angle, 4.0 + (2.0 if od else 0.0), flash_col, 0.04)
	arena.fx.particle(mp, -dir.orthogonal() * randf_range(30, 60) + Vector2(0, -30), 0.4, PixelArt.C["s"], 1.0, 200.0, 1.0)
	if od and _shots % 3 == 0:
		arena.fx.particle(mp, Vector2.from_angle(randf() * TAU) * 40.0, 0.35, flash_col, 1.0, 60.0, 2.0)
	Sfx.play("gatling", randf_range(0.9, 1.15) + (0.2 if od else 0.0), -14.0)
	_recoil = 1.0
	_shots += 1
	if _shots % SHELL_EVERY == 0:
		arena.hazards.add_shells(target.global_position + Vector2(randf_range(-4, 4), randf_range(-2, 3)), 1)


func draw(ci: Node2D) -> void:
	var lvl := tower.level
	# stem + leaves (don't rotate); leaves rustle while the barrels spin
	var rustle := 1.0 if _spin_speed > 8.0 and int(_spin * 0.5) % 2 == 0 else 0.0
	ci.draw_texture(PixelArt.tex("tower_gatling_stem_%d" % lvl), Vector2(-8, -16 - rustle))
	# bloom + barrels rotate with the aim; the whole head kicks back on every shot
	var sway: int = [0, 1, 2, 1][int(tower.anim_t * 2.4 + _phase) % 4]
	var spin := int(_spin) % 3
	var ang := tower.head_angle
	var flip := -1.0 if cos(ang) < 0.0 else 1.0
	var kick := (Vector2.from_angle(ang) * -1.6 * _recoil).round()
	ci.draw_set_transform(head_offset() + kick, ang, Vector2(1, flip))
	ci.draw_texture(PixelArt.tex("tower_gatling_petals_%d_%d" % [lvl, sway]), Vector2(-14, -14))
	ci.draw_texture(PixelArt.tex("tower_gatling_barrels_%d_%d" % [lvl, spin]), Vector2(-14, -14))
	# hot barrel tips while firing
	if _spin_speed > 12.0:
		var hc: Color = Color8(255, 214, 64) if not tower.is_overdrive() else PixelArt.C[CANDY[int(_spin) % CANDY.size()]]
		hc.a = clampf(_spin_speed / 50.0, 0.3, 0.9)
		ci.draw_rect(Rect2(12, -1 - (lvl - 1), 1, 2 + (lvl - 1) * 2), hc)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if GameManager.gstats.has_flag("gatling_flaming"):
		# little flames licking around the seed head
		var fl := int(tower.anim_t * 10.0) % 3
		ci.draw_rect(Rect2(-1 + fl - 1, -19 - fl, 1, 2), PixelArt.C["i"])
		ci.draw_rect(Rect2(1 - fl, -20 + fl % 2, 1, 1), PixelArt.C["I"])
	if lvl >= 3 and _glint_t <= 0.0:
		_glint_t = randf_range(1.5, 3.0)
	if lvl >= 3 and _glint_t > 1.2:
		# golden glint travelling round the petals
		var ga := tower.anim_t * 5.0
		var gp := head_offset() + Vector2.from_angle(ga) * 8.5
		ci.draw_rect(Rect2(gp.round(), Vector2(1, 1)), Color.WHITE)
		ci.draw_rect(Rect2(gp.round() + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 0.7, 0.5))
