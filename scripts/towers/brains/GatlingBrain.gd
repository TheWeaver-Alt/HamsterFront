extends TowerBrain
## Sunflower Gatling: rapid-fire hull spitter. Every few hulls leaves a shell pile on the
## ground that slows rats. "Flaming Hulls" mutation makes shots set rats on fire.

const BASE_RATE := 7.0        # shots per second
const BASE_DAMAGE := 3.4
const SHELL_EVERY := 4

var _cd := 0.0
var _shots := 0
var _spin := 0.0
var _spin_speed := 0.0


func physics(delta: float) -> void:
	_cd -= delta
	_spin += _spin_speed * delta
	var target = tower.best_target("first")
	if target == null:
		_spin_speed = move_toward(_spin_speed, 0.0, 30.0 * delta)
		return
	_spin_speed = move_toward(_spin_speed, 30.0, 80.0 * delta)
	var aligned := tower.aim_head(target.global_position + Vector2(0, -4), delta, 12.0)
	if aligned and _cd <= 0.0:
		_cd = 1.0 / (BASE_RATE * tower.fire_rate_mult())
		_fire(target)


func _fire(target) -> void:
	var arena = GameManager.arena
	var flaming := GameManager.gstats.has_flag("gatling_flaming")
	var mp := tower.muzzle(11.0)
	var dir := Vector2.from_angle(tower.head_angle + randf_range(-0.06, 0.06))
	arena.shots.fire(mp, dir * 330.0, BASE_DAMAGE * tower.damage_mult(), {
		"kind": "hull", "life": 0.6, "radius": 2.5, "knockback": 10.0, "owner": tower,
		"burn": 2.0 if flaming else 0.0})
	arena.fx.flash(mp, tower.head_angle, 4.0, Color8(255, 214, 64) if not flaming else Color8(255, 120, 40), 0.04)
	arena.fx.particle(mp, -dir.orthogonal() * randf_range(30, 60) + Vector2(0, -30), 0.4, PixelArt.C["s"], 1.0, 200.0, 1.0)
	Sfx.play("gatling", randf_range(0.9, 1.15), -14.0)
	_shots += 1
	if _shots % SHELL_EVERY == 0:
		arena.hazards.add_shells(target.global_position + Vector2(randf_range(-4, 4), randf_range(-2, 3)), 1)


func draw(ci: Node2D) -> void:
	var tex := PixelArt.tex("tower_gatling")
	var flip := -1.0 if cos(tower.head_angle) < 0.0 else 1.0
	ci.draw_set_transform(Vector2(0, -8), tower.head_angle, Vector2(1, flip))
	ci.draw_texture(tex, Vector2(-10, -11))
	# spinning barrel glint
	if _spin_speed > 1.0:
		var gy := -2 + (int(_spin) % 3) * 2
		ci.draw_rect(Rect2(12, gy, 6, 1), Color8(255, 248, 231))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if GameManager.gstats.has_flag("gatling_flaming") and randf() < 0.3:
		ci.draw_rect(Rect2(randi_range(-3, 3), -16 + randi_range(-2, 2), 1, 1), PixelArt.C["i"])
