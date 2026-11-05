extends MechVisual
## BRAWLER-01, "The Tin-Can Titan": an espresso machine on piston legs with a glass cockpit (ADR-0003).

var _last_frame := -1


func _spin_wobble() -> float:
	return 0.24


func _tick_extra(_delta: float) -> void:
	_footsteps()


func vent_offset() -> Vector2:
	return Vector2(-10 * mech.facing, -26)


func sprint_trail() -> void:
	var arena = GameManager.arena
	arena.fx.steam(mech.global_position + Vector2(-10 * mech.facing, -26), 1)
	arena.fx.dust(mech.global_position, 1)


func _footsteps() -> void:
	if mech.downed or mech.hop_t > 0.0:
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


func _draw_mech() -> void:
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
