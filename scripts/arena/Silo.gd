extends StaticBody2D
## The Great Silo: a glossy plastic bucket overflowing with premium striped sunflower seeds.
## The seed mound visibly shrinks as the Silo's HP drops (seeds tumble off the top), it glints
## in the sun, bounces when seeds are banked, and the bucket picks up rat bites, cracks and a
## leaking hole as it takes damage.

const MOUND_SEEDS := 240
const MOUND_R := 25.0
const MOUND_SQUASH := 0.78
const RIM_Y := -41.0

var _mound: Array = []     # [Vector2 pos (relative to rim), int shape 0..2, int tint 0..3]
var _flash := 0.0
var _bump := 0.0
var _shake := 0.0
var _pop_cd := 0.0
var _leak_cd := 0.0
var _glints: Array = []    # [seed index, life]
var _glint_t := 0.0
var _shown_last := -1
var _t := 0.0


func _ready() -> void:
	collision_layer = GameManager.L_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ArenaMap.SILO_RADIUS - 2.0
	cs.shape = shape
	cs.position = ArenaMap.SILO_CENTER - position
	add_child(cs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in MOUND_SEEDS:
		var a := rng.randf_range(PI, TAU)
		var r := sqrt(rng.randf()) * MOUND_R
		var p := Vector2(cos(a) * r, sin(a) * r * MOUND_SQUASH)
		_mound.append([p, rng.randi_range(0, 2), rng.randi_range(0, 3)])
	# bottom-most seeds first so the mound drains from the top
	_mound.sort_custom(func(x, y): return x[0].y > y[0].y)


func hit() -> void:
	_flash = 1.0
	_shake = 0.2
	if _pop_cd <= 0.0:
		_pop_cd = 0.18
		_spray_seed(_top_point(), Vector2(randf_range(-70, 70), randf_range(-110, -60)))


func bump() -> void:
	_bump = 1.0
	for i in 3:
		_add_glint()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_bump = maxf(0.0, _bump - delta * 3.0)
	_shake = maxf(0.0, _shake - delta)
	_pop_cd = maxf(0.0, _pop_cd - delta)
	# sun glints on the seed pile
	_glint_t -= delta
	if _glint_t <= 0.0:
		_glint_t = randf_range(0.18, 0.5)
		_add_glint()
	var k := _glints.size() - 1
	while k >= 0:
		_glints[k][1] -= delta
		if _glints[k][1] <= 0.0:
			_glints.remove_at(k)
		k -= 1
	# seeds tumble off the top as the hoard shrinks
	var shown := _shown_count()
	if _shown_last >= 0 and shown < _shown_last:
		var n := mini(_shown_last - shown, 4)
		for i in n:
			var idx := shown + i
			var p: Vector2 = _mound[idx][0]
			_spray_seed(global_position + Vector2(0, RIM_Y) + p, Vector2(signf(p.x + 0.1) * randf_range(30, 80), randf_range(-60, -20)))
	_shown_last = shown
	# a leaking hole near the bottom when badly damaged
	if _frac() < 0.2 and shown > 0:
		_leak_cd -= delta
		if _leak_cd <= 0.0:
			_leak_cd = randf_range(0.25, 0.6)
			_spray_seed(global_position + Vector2(11, -11), Vector2(randf_range(20, 50), randf_range(-10, 10)))
	queue_redraw()


func _frac() -> float:
	return clampf(GameManager.silo_hp / maxf(1.0, GameManager.silo_max_hp), 0.0, 1.0)


func _shown_count() -> int:
	return int(MOUND_SEEDS * _frac())


func _top_point() -> Vector2:
	var shown := _shown_count()
	var top_y := 0.0
	if shown > 0:
		top_y = (_mound[shown - 1][0] as Vector2).y
	return global_position + Vector2(randf_range(-6, 6), RIM_Y + top_y)


func _add_glint() -> void:
	var shown := _shown_count()
	if shown < 4:
		return
	var lo := int(shown * 0.55)
	_glints.append([randi_range(lo, shown - 1), 0.45])


func _spray_seed(pos: Vector2, vel: Vector2) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	arena.fx.particle(pos, vel, randf_range(0.5, 0.8), PixelArt.C["s"] if randf() < 0.7 else PixelArt.C["S"], 1.0, 320.0, 1.0)


func _draw() -> void:
	var frac := _frac()
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(randi_range(-1, 1), 0)
	# ground contact shadow (not squashed)
	for dy in range(-3, 4):
		var hw := roundf(31.0 * sqrt(maxf(0.0, 1.0 - pow(dy / 3.6, 2.0))))
		draw_rect(Rect2(-hw, dy, hw * 2.0, 1), Color(0.05, 0.03, 0.08, 0.22 if absi(dy) < 2 else 0.14))
	var squash := 1.0 + sin(_bump * PI) * 0.07
	draw_set_transform(sh, 0.0, Vector2(1.0 / squash, squash))
	_draw_handle()
	_draw_mound(frac)
	var tint := Color.WHITE.lerp(Color(1, 0.55, 0.55), _flash)
	draw_texture(PixelArt.tex("silo_bucket"), Vector2(-28, -44), tint)
	_draw_damage(frac)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# danger: pulsing dotted ring when the hoard is nearly gone
	if frac < 0.3:
		var pulse := 0.45 + 0.35 * sin(_t * 8.0)
		PixelArt.draw_ring(self, Vector2(0, -22), 35.0 + sin(_t * 8.0), Color(1, 0.25, 0.2, pulse), 48)


## Wire handle standing up behind the seed pile (lit top edge, dark underside).
func _draw_handle() -> void:
	var lit := PixelArt.C["W"]
	var dk := PixelArt.C["G"]
	var last := Vector2(-999, -999)
	for i in 61:
		var a := PI + PI * i / 60.0
		var p := Vector2(cos(a) * 23.5, -38.0 + sin(a) * 29.0).round()
		if p == last:
			continue
		last = p
		draw_rect(Rect2(p, Vector2(1, 1)), lit)
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), dk)


func _draw_mound(frac: float) -> void:
	var shown := int(MOUND_SEEDS * frac)
	if shown <= 0:
		return
	var dark := PixelArt.C["s"]
	var light := PixelArt.C["S"]
	var rim := Vector2(0, RIM_Y)
	# solid dark core so the pile never shows holes
	var top_y: float = (_mound[shown - 1][0] as Vector2).y
	var height := absf(top_y)
	for row in int(height) + 1:
		var f := clampf(row / maxf(1.0, MOUND_R * MOUND_SQUASH), 0.0, 1.0)
		var hw := roundf((MOUND_R - 1.0) * sqrt(maxf(0.0, 1.0 - f * f)))
		draw_rect(Rect2(-hw, RIM_Y - row, hw * 2.0, 1), dark.darkened(0.15))
	var jig := sin(_bump * PI)
	var tints := [dark, dark.lightened(0.18), dark.darkened(0.2), dark.lerp(PixelArt.C["T"], 0.25)]
	for i in shown:
		var p: Vector2 = _mound[i][0]
		var depth := absf(p.y) / (MOUND_R * MOUND_SQUASH)
		var q := (rim + p + Vector2(0, -jig * (1.0 + depth * 3.0))).round()
		var c: Color = tints[int(_mound[i][2])]
		match int(_mound[i][1]):
			0:
				draw_rect(Rect2(q, Vector2(2, 3)), c)
				draw_rect(Rect2(q + Vector2(1, 1), Vector2(1, 1)), light)
			1:
				draw_rect(Rect2(q, Vector2(3, 2)), c)
				draw_rect(Rect2(q + Vector2(1, 0), Vector2(1, 1)), light)
			_:
				draw_rect(Rect2(q, Vector2(1, 1)), c)
				draw_rect(Rect2(q + Vector2(1, 1), Vector2(1, 1)), light)
				draw_rect(Rect2(q + Vector2(2, 2), Vector2(1, 1)), c)
	for g in _glints:
		var idx: int = g[0]
		if idx >= shown:
			continue
		var gp: Vector2 = (rim + (_mound[idx][0] as Vector2) + Vector2(0, -jig * 2.0)).round()
		var life: float = g[1]
		var a := clampf(life / 0.2, 0.0, 1.0)
		draw_rect(Rect2(gp, Vector2(1, 1)), Color(1, 1, 0.9, a))
		if life > 0.15:
			var arm := Color(1, 1, 0.85, a * 0.7)
			draw_rect(Rect2(gp + Vector2(-1, 0), Vector2(1, 1)), arm)
			draw_rect(Rect2(gp + Vector2(1, 0), Vector2(1, 1)), arm)
			draw_rect(Rect2(gp + Vector2(0, -1), Vector2(1, 1)), arm)
			draw_rect(Rect2(gp + Vector2(0, 1), Vector2(1, 1)), arm)


## Rat damage accumulates on the bucket: rim bites, then cracks, then a leaking hole.
func _draw_damage(frac: float) -> void:
	var hole := PixelArt.C["k"]
	var crack := PixelArt.C["n"].darkened(0.35)
	var edge := PixelArt.C["a"]
	if frac < 0.8:
		for bx in [-15, 9]:
			draw_rect(Rect2(bx, -43, 3, 1), hole)
			draw_rect(Rect2(bx + 1, -42, 1, 1), hole)
			draw_rect(Rect2(bx - 1, -43, 1, 1), crack)
	if frac < 0.55:
		var pts := [Vector2(13, -38), Vector2(14, -34), Vector2(12, -31), Vector2(15, -27), Vector2(14, -24)]
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], crack, 1.0)
			draw_line(pts[i] + Vector2(-1, 0), pts[i + 1] + Vector2(-1, 0), Color(edge, 0.5), 1.0)
	if frac < 0.35:
		var pts2 := [Vector2(-18, -37), Vector2(-16, -33), Vector2(-17, -29), Vector2(-14, -25), Vector2(-15, -21)]
		for i in pts2.size() - 1:
			draw_line(pts2[i], pts2[i + 1], crack, 1.0)
		draw_line(Vector2(-16, -33), Vector2(-20, -30), crack, 1.0)
		draw_rect(Rect2(-2, -43, 5, 2), hole)
		draw_rect(Rect2(-1, -41, 3, 1), hole)
	if frac < 0.2:
		draw_rect(Rect2(9, -13, 4, 3), hole)
		draw_rect(Rect2(10, -14, 2, 1), crack)
		draw_rect(Rect2(10, -12, 1, 1), PixelArt.C["s"])
