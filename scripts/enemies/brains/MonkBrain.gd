extends RatBrain
## Plague-Stink Monk: area denial. Waddles to the nearest tower (else the Silo) swinging a moldy
## cheese on a chain, leaving toxic gas clouds that hurt mechs and corrode tower armour.

const GAS_EVERY := 2.5
const GAS_NEAR_TOWER := 1.5
const TOWER_SEEK := 110.0
const RA := preload("res://scripts/art/RatArt.gd")
const BARKS := [
	"Breathe-breathe the holy stink!",
	"Pestilence-blessings for all-all!",
	"Smell-taste the Gouda's glory!",
	"Rot-rot! Mold-mold! Hallelujah-squeak!",
]

var gas_t := 1.2
var tower = null
var _seek_t := 0.0
var _flail_a := 0.0
var _flail_spd := 7.0
var _pose_key := "walk_0"


func setup(r: RatEnemy) -> void:
	super.setup(r)
	_flail_a = randf() * TAU
	gas_t = randf_range(0.8, 1.8)


func get_bark_offset() -> float:
	return -24.0


func physics(delta: float) -> void:
	gas_t -= delta
	_seek_t -= delta
	if _seek_t <= 0.0:
		_seek_t = 0.5
		tower = _find_tower()
	var near_tower := false
	var swinging := false
	if tower != null and is_instance_valid(tower) and tower.alive and GameManager.arena.taunting_decoy(rat.global_position) == null:
		var d: float = rat.global_position.distance_to(tower.global_position)
		var reach: float = rat.radius + tower.hit_radius + 4.0
		near_tower = d < 36.0
		if d <= reach:
			rat.velocity = rat.knock
			rat.move_and_slide()
			rat.target = tower
			rat.target_is_silo = false
			rat._bite_target()
			swinging = true
		else:
			rat.move_toward_point(tower.global_position, rat.speed * rat.slow_mult, delta)
	else:
		tower = null
		rat.default_ai(delta)
		swinging = rat.velocity.length() < 3.0
	_flail_spd = lerpf(_flail_spd, 13.0 if swinging else 7.0, minf(1.0, delta * 4.0))
	_flail_a += delta * _flail_spd
	if gas_t <= 0.0:
		gas_t = GAS_NEAR_TOWER if near_tower else GAS_EVERY
		_drop_gas()
	if randf() < 0.08:
		GameManager.arena.fx.particle(rat.global_position + _cheese_off(), Vector2(randf_range(-6, 6), -14.0),
			0.8, Color(0.4, 1.0, 0.3, 0.7), 1.0, -10.0, 1.0)


func _find_tower():
	var best = null
	var bd := TOWER_SEEK
	for t in GameManager.arena.towers:
		if not is_instance_valid(t) or not t.alive or not rat.can_walk_to(t.global_position):
			continue
		var d: float = rat.global_position.distance_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func _drop_gas() -> void:
	var arena = GameManager.arena
	var pos: Vector2 = rat.global_position + Vector2(-rat.facing * 3.0, -2.0)
	var dps := 4.0 * maxf(1.0, (rat.hp_scale - 1.0) * 0.5 + 1.0)
	arena.hazards.add("gas", pos, 20.0, 6.0, dps)
	arena.fx.burst(pos + Vector2(0, -4), 8, [PixelArt.C["Z"], PixelArt.C["x"], PixelArt.C["z"]], 10, 40, 0.3, 0.7, 1.0, -20.0, 2.0)
	Sfx.play("gas", randf_range(0.8, 1.1), -8.0)
	if randf() < 0.1:
		JuiceManager.bark(rat, BARKS[randi() % BARKS.size()], "rat", false, 8.0)


## Paw that holds the chain, in local space (follows the walk / chant frames).
func _hand() -> Vector2:
	var hp: Vector2i = RA.MONK_HAND.get(_pose_key, Vector2i(14, 12))
	return Vector2((hp.x - 10) * rat.facing, hp.y - 21) + rat.vis_off


func _cheese_off() -> Vector2:
	return _hand() + Vector2(cos(_flail_a) * 9.0, sin(_flail_a) * 4.0)


func draw(ci: RatEnemy) -> void:
	var pose := "walk"
	var f := ci.walk_frame() if ci.moving() else 0
	if not ci.moving() or _flail_spd > 10.0:
		pose = "chant"
		f = int(ci.anim_t * 3.0) % 2
	_pose_key = "%s_%d" % [pose, f]
	var behind := sin(_flail_a) < 0.0
	if behind:
		_draw_flail(ci)
	ci.draw_sprite("rat_monk_%s" % _pose_key)
	if not behind:
		_draw_flail(ci)


func spawn_sprite(_ci: RatEnemy) -> String:
	return "rat_monk_walk_0"


func _draw_flail(ci: RatEnemy) -> void:
	var hand := _hand()
	var tip := _cheese_off()
	# chain links alternate light / dark
	for i in range(1, 5):
		var p := hand.lerp(tip, i / 5.0)
		ci.draw_rect(Rect2(p.round(), Vector2(1, 1)), PixelArt.C["W"] if i % 2 == 0 else PixelArt.C["G"])
	var c := tip.round()
	# moldy cheese wedge: outline, rind, holes and fuzzy green mould
	ci.draw_rect(Rect2(c + Vector2(-3, -2), Vector2(7, 5)), PixelArt.C["k"])
	ci.draw_rect(Rect2(c + Vector2(-2, -1), Vector2(5, 3)), PixelArt.C["y"])
	ci.draw_rect(Rect2(c + Vector2(-2, -1), Vector2(5, 1)), PixelArt.C["I"])
	ci.draw_rect(Rect2(c + Vector2(1, 0), Vector2(1, 1)), PixelArt.C["Y"])
	ci.draw_rect(Rect2(c + Vector2(-1, 1), Vector2(1, 1)), PixelArt.C["Y"])
	ci.draw_rect(Rect2(c + Vector2(-2, 1), Vector2(1, 1)), PixelArt.C["Z"])
	ci.draw_rect(Rect2(c + Vector2(2, -1), Vector2(1, 1)), PixelArt.C["x"])
	ci.draw_rect(Rect2(c + Vector2(-3, -3), Vector2(1, 1)), PixelArt.C["Z"])
	# stink wisps
	var w := int(ci.anim_t * 4.0) % 3
	ci.draw_rect(Rect2(c + Vector2(-1 + w, -4 - w), Vector2(1, 1)), Color(0.67, 1.0, 0.4, 0.7))
