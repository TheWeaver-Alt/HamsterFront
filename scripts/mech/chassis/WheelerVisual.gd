extends MechVisual
## WHEELER-X, "The Turbo Ball": a glass hamster ball on six world-planted spider legs (ADR-0003).

# WHEELER-X leg rest offsets from the feet origin: L-front, L-mid, L-back, R-front, R-mid, R-back
const W_REST := [Vector2(-8, -3), Vector2(-12, 0), Vector2(-8, 3), Vector2(8, -3), Vector2(12, 0), Vector2(8, 3)]
const W_GROUP := [0, 1, 0, 1, 0, 1]     # alternating tripods
const THIGH := 7.0
const SHIN := 8.0

var _feet: Array = []
var _steps: Array = []
var _ghosts: Array = []
var _was_dashing := false


func _tick_extra(delta: float) -> void:
	_update_legs(delta)
	_update_ghosts(delta)


func sprint_trail() -> void:
	var arena = GameManager.arena
	arena.hazards.add("skid", mech.global_position + Vector2(randf_range(-5, 5), 0), 2.0, 6.0)
	arena.hazards.add("fire", mech.global_position, 6.0, 1.3, 16.0)
	if randf() < 0.5:
		arena.fx.fire(mech.global_position, 2)


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


func _draw_mech() -> void:
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
