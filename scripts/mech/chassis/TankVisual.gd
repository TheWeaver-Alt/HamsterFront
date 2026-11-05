extends MechVisual
## HOWITZER-9, "The Biscuit Tin": a gold biscuit-tin hull on rubber treads, the pilot peeking out of the rear
## hatch, a turret dome up front. The barrel is the weapon node's (TankWeapon). ADR-0003.

var _last_tread := -1


func _spin_wobble() -> float:
	return 0.1


func _tick_extra(_delta: float) -> void:
	if mech.downed or mech.hop_t > 0.0 or mech.velocity.length() < 5.0:
		_last_tread = -1
		return
	var f := int(walk_t * 1.5) % 4
	if f != _last_tread and f % 2 == 0:
		var arena = _arena()
		if arena != null:
			arena.fx.dust(mech.global_position + Vector2(-15.0 * mech.facing, 0), 1)
	_last_tread = f


func vent_offset() -> Vector2:
	return Vector2(-13 * mech.facing, -23)


func sprint_trail() -> void:
	var arena = GameManager.arena
	arena.fx.steam(mech.global_position + vent_offset(), 1)
	arena.fx.dust(mech.global_position + Vector2(-15.0 * mech.facing, 0), 2)


func _draw_mech() -> void:
	var downed: bool = mech.downed
	var moving: bool = mech.velocity.length() > 5.0 and mech.hop_t <= 0.0 and not downed
	var tread := int(walk_t * 1.5) % 4 if moving else 0
	# a tank does not bob when idle; it shudders a little while the treads turn
	var bob := 0.0
	if moving and int(walk_t * 3.0) % 2 == 0:
		bob = -1.0
	var rot := -0.08 if downed else 0.0
	var off := Vector2(_flinch_dir * 2.0 * (_flinch / 0.14), 3.0 if downed else 0.0)
	var xf := _base_xf(off, rot)
	draw_set_transform_matrix(xf)
	var tint := Color.WHITE if not downed else Color(0.62, 0.58, 0.68)
	draw_texture(PixelArt.tex("tank_treads_%d" % tread), Vector2(-19, -9), tint)
	# the pilot, centred over the rear hatch (tumbles when spinning out)
	var head_rot := spin * 0.75 if mech.wheel.is_spinning() else 0.0
	var hs := Vector2(1.0 + (_head - 1.0) * 0.9, 1.0 - (_head - 1.0) * 0.5)
	draw_set_transform_matrix(xf * Transform2D(head_rot, hs, 0.0, Vector2(-4, -19 + bob)))
	draw_texture(_head_tex(), Vector2(-13, -10), tint)
	draw_set_transform_matrix(xf)
	# the hull hides the pilot's lower half; the hatch lip sits in front of it
	draw_texture(PixelArt.tex("tank_hull"), Vector2(-17, -19 + bob), tint)
	if downed or _low_hp():
		draw_texture(PixelArt.tex("tank_hull_crack"), Vector2(-17, -19 + bob))
	draw_texture(PixelArt.tex("tank_hatch"), Vector2(-10, -18 + bob), tint)
	draw_texture(PixelArt.tex("tank_turret"), Vector2(2, -25 + bob), Color(1, 1, 1, _dome_flicker) * tint)
	var redline: bool = mech.wheel.is_redline()
	if redline:
		_shimmer(Vector2(-14, -22 + bob), 3)
	if mech.wheel.is_venting():
		PixelArt.draw_disk(self, Vector2(-13, -23 + bob), 4.0, Color(1, 1, 1, 0.35))
	if downed or mech.wheel.is_spinning():
		_dizzy_stars(Vector2(-4, -32 + bob))
