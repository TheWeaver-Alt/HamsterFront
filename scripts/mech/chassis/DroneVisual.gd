extends MechVisual
## WHIRLYBIRD-Z, "The Whirly-Gig": a hamster in a glass pod slung under a two-rotor frame. It hovers, so cliffs
## and towers do not stop it, and the fuller its cheeks the lower it sags. ADR-0003.

const HOVER_LIGHT := 14.0      # height above its shadow with empty cheeks
const HOVER_HEAVY := 6.0       # height with full cheeks

var _rotor_t := 0.0


## It floats; a full pouch drags it lower, and a downed drone is on the ground.
func hover_height() -> float:
	if mech == null or mech.downed:
		return 0.0
	return roundf(lerpf(HOVER_LIGHT, HOVER_HEAVY, mech.pouch.fill()) + sin(idle_t * 3.0))


func _tick_extra(delta: float) -> void:
	_rotor_t += delta * (34.0 if not mech.downed else 0.0)


func vent_offset() -> Vector2:
	return Vector2(0, -28 - hover_height())


func sprint_trail() -> void:
	var arena = GameManager.arena
	arena.fx.steam(mech.global_position + Vector2(0, -12 - hover_height()), 1)


func _draw_mech() -> void:
	var downed: bool = mech.downed
	var tint := Color.WHITE if not downed else Color(0.62, 0.58, 0.68)
	var rot := -0.1 if downed else 0.0
	var off := Vector2(_flinch_dir * 2.0 * (_flinch / 0.14), 3.0 if downed else 0.0)
	var xf := _base_xf(off, rot)
	draw_set_transform_matrix(xf)
	draw_texture(PixelArt.tex("drone_skids"), Vector2(-10, -4), tint)
	# the pilot sits in the pod (tumbles when spinning out)
	var head_rot := spin * 0.75 if mech.wheel.is_spinning() else 0.0
	var hs := Vector2(1.0 + (_head - 1.0) * 0.9, 1.0 - (_head - 1.0) * 0.5)
	draw_set_transform_matrix(xf * Transform2D(head_rot, hs, 0.0, Vector2(0, -10)))
	draw_texture(_head_tex(), Vector2(-13, -10), tint)
	draw_set_transform_matrix(xf)
	draw_texture(PixelArt.tex("drone_pod"), Vector2(-11, -18), Color(1, 1, 1, _dome_flicker) * tint)
	if downed or _low_hp():
		draw_texture(PixelArt.tex("drone_pod_crack"), Vector2(-11, -18))
	draw_texture(PixelArt.tex("drone_frame"), Vector2(-17, -22), tint)
	var spin_frame := int(_rotor_t)
	draw_texture(PixelArt.tex("drone_rotor_%d" % (spin_frame % 4)), Vector2(-24, -28), tint)
	draw_texture(PixelArt.tex("drone_rotor_%d" % ((spin_frame + 2) % 4)), Vector2(10, -28), tint)
	var redline: bool = mech.wheel.is_redline()
	if redline:
		_shimmer(Vector2(-2, -25), 3)
	if mech.wheel.is_venting():
		PixelArt.draw_disk(self, Vector2(0, -10), 8.0, Color(1, 1, 1, 0.3))
	if downed or mech.wheel.is_spinning():
		_dizzy_stars(Vector2(0, -30))
