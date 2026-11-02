extends Node2D
## Draws a hamster mech (BRAWLER-01 or WHEELER-X) around its body centre.
## Carries the hit-flash ShaderMaterial. Rotates as a whole during wheel spin-outs.

var mech = null   # MechPlayer
var walk_t := 0.0
var spin := 0.0
var _flash := 0.0


func _ready() -> void:
	mech = get_parent()
	material = PixelArt.make_flash_material()


func hit_flash(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)


func tick(delta: float) -> void:
	var spd: float = mech.velocity.length()
	if spd > 5.0:
		walk_t += delta * (6.0 + spd * 0.06)
	_flash = maxf(0.0, _flash - delta * 7.0)
	(material as ShaderMaterial).set_shader_parameter("flash", _flash)
	if mech.wheel.is_spinning():
		spin += delta * 22.0
		rotation = spin
	else:
		spin = 0.0
		rotation = lerp_angle(rotation, 0.0, minf(1.0, delta * 20.0))
	queue_redraw()


func _head_tex() -> Texture2D:
	if mech.wheel.is_spinning() or mech.downed:
		return PixelArt.tex("ham_head_dizzy")
	return PixelArt.tex("ham_head_%d" % mech.pouch.head_level())


func _draw() -> void:
	if mech == null:
		return
	if mech.chassis == "brawler":
		_draw_brawler()
	else:
		_draw_wheeler()


func _draw_brawler() -> void:
	var frame := 0
	if mech.velocity.length() > 5.0:
		frame = int(walk_t) % 2
	var bob := 0.0 if frame == 0 else -1.0
	var dark := Color(1, 1, 1, 1) if not mech.downed else Color(0.55, 0.5, 0.6, 1)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(mech.facing, 1))
	if mech.downed:
		draw_set_transform(Vector2(0, 3), 0.35 * mech.facing, Vector2(mech.facing, 1))
	draw_texture(PixelArt.tex("brawler_body_%d" % frame), Vector2(-13, -10), dark)
	# redline blink on the chimney
	if mech.wheel.is_redline() and int(Time.get_ticks_msec() / 120) % 2 == 0:
		draw_rect(Rect2(-10, -9, 3, 2), Color8(255, 64, 40))
	# pilot + dome
	var head := _head_tex()
	draw_texture(head, Vector2(-13, -18 + bob * 0.0))
	var dome := PixelArt.tex("brawler_dome")
	draw_texture(dome, Vector2(-9, -18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_wheeler() -> void:
	var moving: float = clampf(mech.velocity.length() / 60.0, 0.0, 1.0)
	var g := PixelArt.C["G"]
	var gl := PixelArt.C["g"]
	if mech.downed:
		g = g.darkened(0.3)
		gl = gl.darkened(0.3)
	# spider legs
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var j := i % 3
		var phase := walk_t * 2.2 + i * 2.1
		var anchor := Vector2(side * 5.0, 1.0 + (j - 1) * 2.0)
		var foot := Vector2(side * (7.0 + j * 3.5), 12.0)
		foot.x += sin(phase) * 2.5 * moving
		var lift := maxf(0.0, cos(phase)) * 2.0 * moving
		foot.y -= lift
		if mech.downed:
			foot = Vector2(side * (9.0 + j * 3.0), 12.0)
		var knee := anchor + Vector2(side * (5.0 + j * 1.5), -6.0 + j * 1.5)
		draw_line(anchor.round(), knee.round(), g, 1.0)
		draw_line(knee.round(), foot.round(), gl, 1.0)
		draw_rect(Rect2(knee.round(), Vector2(1, 1)), PixelArt.C["W"])
		draw_rect(Rect2(foot.round() - Vector2(0, 0), Vector2(1, 1)), PixelArt.C["k"])
	# hamster running inside the ball
	var frame := int(walk_t * 1.5) % 2 if moving > 0.05 else 0
	var bob := -1.0 if frame == 1 else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(mech.facing, 1))
	draw_texture(PixelArt.tex("wheeler_ham_%d" % frame), Vector2(-7, -5 + bob))
	draw_texture(_head_tex(), Vector2(-13, -17 + bob))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture(PixelArt.tex("wheeler_ball"), Vector2(-12, -14))
	if mech.wheel.is_redline() and int(Time.get_ticks_msec() / 120) % 2 == 0:
		PixelArt.draw_ring(self, Vector2(0, -2), 10.0, Color8(255, 64, 40))
