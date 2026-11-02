extends Node2D
## Draws a hamster mech (BRAWLER-01 or WHEELER-X). This node sits at (0,-12) under the mech, so
## the mech's feet are at local FEET. Everything is anchored at the feet so squash & stretch keeps
## the mech planted. Carries the hit-flash ShaderMaterial.
## Animation is driven by polling the mech each tick (walk phase, hop, downed, pouch, heat, HP).

const MechArtScript := preload("res://scripts/art/MechArt.gd")
const FEET := Vector2(0, 12)
const LOW_HP := 0.35
# WHEELER-X leg rest offsets from the feet origin: L-front, L-mid, L-back, R-front, R-mid, R-back
const W_REST := [Vector2(-8, -3), Vector2(-12, 0), Vector2(-8, 3), Vector2(8, -3), Vector2(12, 0), Vector2(8, 3)]
const W_GROUP := [0, 1, 0, 1, 0, 1]     # alternating tripods
const THIGH := 7.0
const SHIN := 8.0

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
var _last_frame := -1
var _was_hopping := false
var _was_downed := false
var _last_amount := 0
var _last_level := 0
var _smoke_t := 0.0
var _spark_t := 0.0
var _dome_flicker := 1.0
var _wheel_t := 0.0
var _feet: Array = []
var _steps: Array = []
var _ghosts: Array = []
var _was_dashing := false


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
		rotation = sin(idle_t * 30.0) * (0.24 if mech.chassis == "brawler" else 0.12)
	else:
		spin = 0.0
		rotation = lerp_angle(rotation, 0.0, minf(1.0, delta * 20.0))
	# inner wheel speed follows movement + heat
	_wheel_t += delta * (2.0 + spd * 0.12 + mech.wheel.heat * 0.08) * (0.0 if mech.downed else 1.0)
	_footsteps()
	if mech.chassis == "wheeler":
		_update_legs(delta)
		_update_ghosts(delta)
	_damage_fx(delta)
	_dome_flicker = 0.35 if (_low_hp() and randf() < 0.12) else 1.0
	queue_redraw()


func _low_hp() -> bool:
	return not mech.downed and mech.hp < mech.max_hp() * LOW_HP


func _arena():
	return GameManager.arena


func _footsteps() -> void:
	if mech.chassis != "brawler" or mech.downed or mech.hop_t > 0.0:
		return
	if mech.velocity.length() < 5.0:
		_last_frame = -1
		return
	var f := int(walk_t) % 6
	if f != _last_frame and (f == 0 or f == 3):
		var arena = _arena()
		if arena != null:
			var side := 4.0 if f == 0 else -4.0
			arena.fx.dust(mech.global_position + Vector2(side * mech.facing, 0), 2)
	_last_frame = f


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


# ------------------------------------------------------------------ WHEELER legs (world-planted IK)

func _update_legs(delta: float) -> void:
	var base: Vector2 = mech.global_position
	if _feet.size() != 6:
		_feet.clear()
		_steps.clear()
		for i in 6:
			_feet.append(base + (W_REST[i] as Vector2))
			_steps.append(null)
	if mech.downed or mech.hop_t > 0.0:
		for i in 6:
			var rest: Vector2 = W_REST[i]
			_feet[i] = base + (rest * 1.35 if mech.downed else rest * 0.6 + Vector2(0, -3))
			_steps[i] = null
		return
	var lead: Vector2 = mech.velocity * 0.1
	var moving_group := -1
	for i in 6:
		if _steps[i] != null:
			moving_group = W_GROUP[i]
	for i in 6:
		var target: Vector2 = base + (W_REST[i] as Vector2) + lead
		if _steps[i] != null:
			var st: Dictionary = _steps[i]
			st["t"] = float(st["t"]) + delta / 0.085
			var t: float = clampf(st["t"], 0.0, 1.0)
			_feet[i] = (st["from"] as Vector2).lerp(st["to"], t * t * (3.0 - 2.0 * t))
			if t >= 1.0:
				_steps[i] = null
		else:
			var foot: Vector2 = _feet[i]
			var d := foot.distance_to(target)
			if d > 22.0:
				_feet[i] = target
			elif d > 5.0 and (moving_group == -1 or moving_group == W_GROUP[i]):
				_steps[i] = {"t": 0.0, "from": foot, "to": target + lead * 0.5}
				moving_group = W_GROUP[i]


func _update_ghosts(delta: float) -> void:
	var dashing: bool = mech.dash_t > 0.0
	if dashing:
		_ghosts.append([mech.global_position, 0.2])
		if _ghosts.size() > 7:
			_ghosts.pop_front()
	var k := _ghosts.size() - 1
	while k >= 0:
		_ghosts[k][1] = float(_ghosts[k][1]) - delta
		if float(_ghosts[k][1]) <= 0.0:
			_ghosts.remove_at(k)
		k -= 1
	_was_dashing = dashing


static func _ik_knee(hip: Vector2, foot: Vector2, side: float) -> Vector2:
	var d := clampf(hip.distance_to(foot), 0.5, THIGH + SHIN - 0.05)
	var c := clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0)
	var a := acos(c)
	var base := (foot - hip).angle()
	var k1 := hip + Vector2.from_angle(base - a) * THIGH
	var k2 := hip + Vector2.from_angle(base + a) * THIGH
	# knees go up and outward
	var s1 := -k1.y + (k1.x - hip.x) * side * 0.3
	var s2 := -k2.y + (k2.x - hip.x) * side * 0.3
	return k1 if s1 > s2 else k2


# ------------------------------------------------------------------ drawing helpers

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
	if mech.chassis == "brawler":
		_draw_brawler()
	else:
		_draw_wheeler()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_brawler() -> void:
	var downed: bool = mech.downed
	var moving: bool = mech.velocity.length() > 5.0 and mech.hop_t <= 0.0
	var frame := int(walk_t) % 6
	var legs := "brawler_legs_%d" % frame if moving else "brawler_legs_idle"
	var bob := 0.0
	if moving:
		var g: Array = MechArtScript.GAIT[frame]
		bob = -1.0 if (int(g[1]) > 0 or int(g[3]) > 0) else 0.0
	else:
		bob = _breath_bob()
	if mech.hop_t > 0.0:
		legs = "brawler_legs_1"
	var rot := 0.0
	var off := Vector2(_flinch_dir * 2.0 * (_flinch / 0.14), 0)
	if downed:
		legs = "brawler_legs_down"
		rot = -0.3
		off.y += 2.0
		bob = 1.0
	var xf := _base_xf(off, rot)
	draw_set_transform_matrix(xf)
	var tint := Color.WHITE if not downed else Color(0.62, 0.58, 0.68)
	var heat: float = mech.wheel.heat
	var redline: bool = mech.wheel.is_redline()
	# jetpack bottle strapped on the back (+ plume while hopping)
	var has_jet: bool = mech.stats.has_flag("jetpack")
	if has_jet:
		draw_texture(PixelArt.tex("jetpack_bottle"), Vector2(-16, -19 + bob), tint)
		if mech.hop_t > 0.0:
			draw_texture(PixelArt.tex("jet_flame_%d" % (int(idle_t * 20.0) % 3)), Vector2(-16, -5 + bob))
	# legs + torso
	draw_texture(PixelArt.tex(legs), Vector2(-13, -22), tint)
	draw_texture(PixelArt.tex("brawler_torso"), Vector2(-13, -22 + bob), tint)
	# porthole: tiny hamster wheel spinning inside (glows red when redlining)
	var wheel_col := Color.WHITE
	if redline:
		wheel_col = Color(1.0, 0.45 + 0.25 * sin(idle_t * 20.0), 0.35)
	draw_texture(PixelArt.tex("porthole_wheel_%d" % (int(_wheel_t) % 4)), Vector2(-7, -12 + bob), wheel_col * tint)
	# pressure gauge needle follows wheel heat (shakes in the red)
	var gc := Vector2(3, -10.5 + bob)
	var ang := lerpf(-2.6, 0.5, clampf(heat / 100.0, 0.0, 1.0))
	if redline:
		ang += sin(idle_t * 60.0) * 0.25
	var tip := (gc + Vector2.from_angle(ang) * 1.4).round()
	draw_rect(Rect2(gc.round(), Vector2(1, 1)), PixelArt.C["k"])
	draw_rect(Rect2(tip, Vector2(1, 1)), PixelArt.C["r"] if heat > 80.0 else PixelArt.C["k"])
	# chimney glow + heat shimmer
	if redline:
		var glow := 0.5 + 0.5 * sin(idle_t * 14.0)
		draw_rect(Rect2(-12, -21 + bob, 5, 1), Color(1.0, 0.35, 0.15, 0.55 + 0.4 * glow))
		_shimmer(Vector2(-10, -23 + bob), 3)
	# pilot (tumbles when spinning out)
	var head_rot := spin * 0.75 if mech.wheel.is_spinning() else 0.0
	var hs := Vector2(1.0 + (_head - 1.0) * 0.9, 1.0 - (_head - 1.0) * 0.5)
	draw_set_transform_matrix(xf * Transform2D(head_rot, hs, 0.0, Vector2(0, -20 + bob)))
	draw_texture(_head_tex(), Vector2(-13, -10), tint)
	draw_set_transform_matrix(xf)
	# dome: cracked + flickering when badly damaged, fogged when venting
	var cracked: bool = downed or _low_hp()
	var dome := PixelArt.tex("brawler_dome_crack" if cracked else "brawler_dome")
	draw_texture(dome, Vector2(-9, -30 + bob), Color(1, 1, 1, _dome_flicker))
	if mech.wheel.is_venting():
		PixelArt.draw_disk(self, Vector2(0, -21 + bob), 6.0, Color(1, 1, 1, 0.35))
	# full cheeks squash against the glass
	if mech.pouch.head_level() >= 8 and not downed:
		for sx in [-6.0, 6.0]:
			draw_rect(Rect2(sx, -21 + bob, 1, 3), Color(1, 1, 1, 0.75))
			draw_rect(Rect2(sx + (-1.0 if sx < 0 else 1.0), -20 + bob, 1, 1), Color(1, 0.6, 0.7, 0.8))
	if downed or mech.wheel.is_spinning():
		_dizzy_stars(Vector2(0, -32 + bob))


func _draw_wheeler() -> void:
	var downed: bool = mech.downed
	var spd: float = mech.velocity.length()
	var moving: bool = spd > 5.0 and mech.hop_t <= 0.0 and not downed
	var tint := Color.WHITE if not downed else Color(0.62, 0.58, 0.68)
	var lower := 4.0 if downed else 0.0
	var off := Vector2(_flinch_dir * 2.0 * (_flinch / 0.14), lower)
	# dash afterimages (world positions)
	if not _ghosts.is_empty():
		draw_set_transform(FEET, 0.0, Vector2.ONE)
		var ball := PixelArt.tex("wheeler_ball")
		for gh in _ghosts:
			var gp: Vector2 = (gh[0] as Vector2) - mech.global_position
			var a: float = clampf(float(gh[1]) / 0.2, 0.0, 1.0) * 0.45
			draw_texture(ball, (gp + Vector2(-12, -26)).round(), Color(1.0, 0.6, 0.3, a))
	# spider legs (world-planted, never mirrored)
	draw_set_transform(FEET, 0.0, Vector2.ONE)
	_draw_legs(lower)
	var xf := _base_xf(off, 0.0)
	draw_set_transform_matrix(xf)
	draw_texture(PixelArt.tex("wheeler_hub"), Vector2(-8, -6), tint)
	var has_jet: bool = mech.stats.has_flag("jetpack")
	if has_jet:
		draw_texture(PixelArt.tex("jetpack_bottle"), Vector2(-16, -21), tint)
		if mech.hop_t > 0.0:
			draw_texture(PixelArt.tex("jet_flame_%d" % (int(idle_t * 20.0) % 3)), Vector2(-16, -7))
	# inner exercise wheel behind the hamster
	var redline: bool = mech.wheel.is_redline()
	var wcol := Color(1.0, 0.5, 0.4) if redline else Color.WHITE
	draw_texture(PixelArt.tex("wheeler_wheel_%d" % (int(_wheel_t * 1.5) % 4)), Vector2(-10, -24), wcol * tint)
	# hamster: runs while moving, sits when idle, tumbles when spinning out
	var ham := "wheeler_ham_idle"
	var bob := _breath_bob()
	if moving:
		var f := int(walk_t * 0.9) % 4
		ham = "wheeler_ham_%d" % [0, 2, 1, 3][f]
		bob = -1.0 if f % 2 == 1 else 0.0
	var tumble := spin if mech.wheel.is_spinning() else 0.0
	var hs := Vector2(1.0 + (_head - 1.0) * 0.9, 1.0 - (_head - 1.0) * 0.5)
	var ball_c := Vector2(0, -14)
	draw_set_transform_matrix(xf * Transform2D(tumble, Vector2.ONE, 0.0, ball_c))
	draw_texture(PixelArt.tex(ham), Vector2(-7, 3 - 6 + bob), tint)
	draw_set_transform_matrix(xf * Transform2D(tumble, Vector2.ONE, 0.0, ball_c) * Transform2D(0.0, hs, 0.0, Vector2(0, -5 + bob)))
	draw_texture(_head_tex(), Vector2(-13, -10), tint)
	draw_set_transform_matrix(xf)
	# glass ball over everything
	draw_texture(PixelArt.tex("wheeler_ball"), Vector2(-12, -26), Color(1, 1, 1, _dome_flicker))
	if downed or _low_hp():
		draw_texture(PixelArt.tex("wheeler_ball_crack"), Vector2(-12, -26))
	if mech.wheel.is_venting():
		PixelArt.draw_disk(self, ball_c, 8.0, Color(1, 1, 1, 0.3))
	# full cheeks press on the glass
	if mech.pouch.head_level() >= 8 and not downed:
		for sx in [-8.0, 8.0]:
			draw_rect(Rect2(sx, -21, 1, 3), Color(1, 1, 1, 0.7))
			draw_rect(Rect2(sx + (-1.0 if sx < 0 else 1.0), -20, 1, 1), Color(1, 0.6, 0.7, 0.8))
	# antenna LED
	var led_on := int(idle_t * 3.0) % 2 == 0
	var led: Color = PixelArt.C["r"] if (redline or _low_hp()) else MechPlayer.PLAYER_COLORS[clampi(mech.player_id - 1, 0, 1)]
	if led_on or redline:
		draw_rect(Rect2(3, -27, 1, 1), led)
	if redline:
		_shimmer(Vector2(-2, -27), 3)
	if downed or mech.wheel.is_spinning():
		_dizzy_stars(Vector2(0, -30))


func _draw_legs(lower: float) -> void:
	if _feet.size() != 6:
		return
	var base: Vector2 = mech.global_position
	var k: Color = PixelArt.C["k"]
	var g: Color = PixelArt.C["g"]
	var gd: Color = PixelArt.C["G"]
	var w: Color = PixelArt.C["W"]
	if mech.downed:
		g = g.darkened(0.3)
		gd = gd.darkened(0.3)
	# back legs first for depth
	for order in [0, 3, 1, 4, 2, 5]:
		var i: int = order
		var side := -1.0 if i < 3 else 1.0
		var j := i % 3
		var hip := Vector2(side * 4.0, -4.0 + (j - 1) * 1.0 + lower)
		var foot: Vector2 = (_feet[i] as Vector2) - base
		var lift := 0.0
		if _steps[i] != null:
			lift = sin(clampf(float(_steps[i]["t"]), 0.0, 1.0) * PI) * 3.0
		foot.y -= lift
		var reach := hip.distance_to(foot)
		if reach > THIGH + SHIN:
			foot = hip + (foot - hip).normalized() * (THIGH + SHIN)
		var knee := _ik_knee(hip, foot, side)
		var hp2 := hip.round()
		var kn := knee.round()
		var ft := foot.round()
		draw_line(hp2, kn, k, 3.0)
		draw_line(kn, ft, k, 3.0)
		draw_line(hp2, kn, w, 1.0)
		draw_line(kn, ft, g, 1.0)
		draw_rect(Rect2(kn - Vector2(1, 1), Vector2(2, 2)), gd)
		draw_rect(Rect2(kn - Vector2(1, 1), Vector2(1, 1)), w)
		draw_rect(Rect2(ft - Vector2(1, 0), Vector2(2, 1)), k)


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
