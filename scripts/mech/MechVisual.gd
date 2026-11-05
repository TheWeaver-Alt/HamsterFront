class_name MechVisual
extends Node2D
## Draws a hamster mech. This node sits at (0,-12) under the mech, so
## the mech's feet are at local FEET. Everything is anchored at the feet so squash & stretch keeps
## the mech planted. Carries the hit-flash ShaderMaterial.
## Animation is driven by polling the mech each tick (walk phase, hop, downed, pouch, heat, HP).
## The shared machinery lives here; each chassis (scripts/mech/chassis/<Name>Visual.gd, ADR-0003) overrides the
## hooks at the bottom: what it draws, its per-tick extras, its spin-out wobble, its steam vent and sprint trail.

const MechArtScript := preload("res://scripts/art/MechArt.gd")
const FEET := Vector2(0, 12)
const LOW_HP := 0.35

var mech = null   # MechPlayer
var walk_t := 0.0
var spin := 0.0   # spin-out angle (MechPlayer aims wildly along it)
var idle_t := 0.0
var _flash := 0.0
var _sq := Vector2.ONE
var _sq_v := Vector2.ZERO
var _head := 1.0
var _head_v := 0.0
var _flinch := 0.0
var _flinch_dir := 1.0
var _last_facing := 1.0
var _was_hopping := false
var _was_downed := false
var _last_amount := 0
var _last_level := 0
var _smoke_t := 0.0
var _spark_t := 0.0
var _dome_flicker := 1.0
var _wheel_t := 0.0


func _ready() -> void:
	mech = get_parent()
	material = PixelArt.make_flash_material()


func hit_flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)
	if amount >= 0.5:
		kick(Vector2(0.16, -0.14) * amount)
		_flinch = 0.14
		_flinch_dir = -mech.facing


## Squash & stretch impulse (x, y scale offsets; springs back to 1).
func kick(amount: Vector2) -> void:
	_sq += amount


func tick(delta: float) -> void:
	idle_t += delta
	var spd: float = mech.velocity.length()
	if not mech.downed and mech.hop_t <= 0.0 and spd > 5.0:
		walk_t += delta * spd * 0.11
	_flash = maxf(0.0, _flash - delta * 7.0)
	(material as ShaderMaterial).set_shader_parameter("flash", _flash)
	# springs
	_sq_v += ((Vector2.ONE - _sq) * 320.0 - _sq_v * 15.0) * delta
	_sq += _sq_v * delta
	_sq = _sq.clamp(Vector2(0.45, 0.45), Vector2(1.7, 1.7))
	_head_v += ((1.0 - _head) * 380.0 - _head_v * 13.0) * delta
	_head += _head_v * delta
	_flinch = maxf(0.0, _flinch - delta)
	# facing flip squash
	if mech.facing != _last_facing:
		_last_facing = mech.facing
		kick(Vector2(-0.4, 0.1))
	# jetpack takeoff / landing
	var hopping: bool = mech.hop_t > 0.0
	if hopping and not _was_hopping:
		kick(Vector2(-0.28, 0.34))
	elif not hopping and _was_hopping:
		kick(Vector2(0.4, -0.36))
	_was_hopping = hopping
	# revive pop
	if _was_downed and not mech.downed:
		_sq = Vector2(0.55, 1.5)
		_sq_v = Vector2.ZERO
		_head = 1.4
	_was_downed = mech.downed
	# cheeks: little squeeze per seed, bigger wobble per inflation step
	var amt: int = mech.pouch.amount
	var lvl: int = mech.pouch.head_level()
	if lvl != _last_level:
		_head += 0.22 if lvl > _last_level else -0.12
	elif amt > _last_amount:
		_head += 0.06
	_last_amount = amt
	_last_level = lvl
	# spin-out: whole mech wobbles, the pilot tumbles inside
	if mech.wheel.is_spinning():
		spin += delta * 22.0
		rotation = sin(idle_t * 30.0) * _spin_wobble()
	else:
		spin = 0.0
		rotation = lerp_angle(rotation, 0.0, minf(1.0, delta * 20.0))
	# inner wheel speed follows movement + heat
	_wheel_t += delta * (2.0 + spd * 0.12 + mech.wheel.heat * 0.08) * (0.0 if mech.downed else 1.0)
	_tick_extra(delta)
	_damage_fx(delta)
	_dome_flicker = 0.35 if (_low_hp() and randf() < 0.12) else 1.0
	queue_redraw()


func _low_hp() -> bool:
	return not mech.downed and mech.hp < mech.max_hp() * LOW_HP


func _arena():
	return GameManager.arena


func _damage_fx(delta: float) -> void:
	var arena = _arena()
	if arena == null or not _low_hp():
		return
	_smoke_t -= delta
	_spark_t -= delta
	var top: Vector2 = mech.global_position + Vector2(randf_range(-6, 6), -20)
	if _smoke_t <= 0.0:
		_smoke_t = randf_range(0.18, 0.35)
		arena.fx.smoke(top, 1)
	if _spark_t <= 0.0:
		_spark_t = randf_range(0.5, 1.1)
		arena.fx.sparks(top + Vector2(0, 6), Color8(255, 214, 64), 3)


func _head_tex() -> Texture2D:
	if mech.wheel.is_spinning() or mech.downed:
		return PixelArt.tex("ham_head_dizzy")
	return PixelArt.tex("ham_head_%d" % mech.pouch.head_level())


## Base transform: anchored at the feet, mirrored by facing, squashed.
func _base_xf(offset: Vector2, rot: float, flip: bool = true) -> Transform2D:
	var sx: float = _sq.x * (mech.facing if flip else 1.0)
	return Transform2D(rot, Vector2(sx, _sq.y), 0.0, (FEET + offset).round())


func _breath_bob() -> float:
	if mech.velocity.length() > 5.0 or mech.downed:
		return 0.0
	return -1.0 if fmod(idle_t, 1.6) < 0.8 else 0.0


func _draw() -> void:
	if mech == null:
		return
	_draw_mech()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shimmer(at: Vector2, cols: int) -> void:
	for c in cols:
		for s in 4:
			var y := at.y - s * 2.0 - fmod(idle_t * 14.0 + c * 0.7, 2.0)
			var x := at.x + c * 2.0 + roundf(sin(idle_t * 9.0 + s * 1.3 + c) * 1.0)
			draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(1.0, 0.55, 0.2, 0.55 - s * 0.12))


func _dizzy_stars(center: Vector2) -> void:
	for i in 3:
		var a := idle_t * 5.0 + i * TAU / 3.0
		var p := (center + Vector2(cos(a) * 7.0, sin(a) * 2.0)).round()
		var c: Color = PixelArt.C["y"] if i != 1 else PixelArt.C["w"]
		draw_rect(Rect2(p, Vector2(1, 1)), c)
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), Color(c, 0.5))
		draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), Color(c, 0.5))
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 1)), Color(c, 0.5))
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), Color(c, 0.5))


# ------------------------------------------------------------------ chassis hooks (overridden per chassis)

## Draws the whole mech body (called from _draw with no transform set).
func _draw_mech() -> void:
	pass


## Per-tick extras: leg planting, footsteps, afterimages.
func _tick_extra(_delta: float) -> void:
	pass


## How far the whole mech wobbles (radians) while spinning out.
func _spin_wobble() -> float:
	return 0.12


## How high the mech floats above its shadow (the drone hovers; everything else is 0).
func hover_height() -> float:
	return 0.0


## Where steam comes out, relative to the mech's feet.
func vent_offset() -> Vector2:
	return Vector2(0, -26)


## Effects left behind while sprinting.
func sprint_trail() -> void:
	pass

