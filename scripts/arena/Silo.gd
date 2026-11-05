extends StaticBody2D
## The Great Silo (ADR-0002): a corrugated steel grain silo with a seed-level window on its front.
## The window shows how full the seed store is (GameManager.seeds / silo_capacity), the walls show rat
## damage (bites, cracks, then a leaking hole), and each upgrade level stands taller. It glints in the
## sun, bounces when seeds are banked, rattles when rats hit it and puffs gold when upgraded.

const MiscArt := preload("res://scripts/art/MiscArt.gd")
const SPRITE_X := -28.0
const USE_RANGE := 52.0

var _flash := 0.0
var _bump := 0.0
var _shake := 0.0
var _gold := 0.0
var _pop_cd := 0.0
var _leak_cd := 0.0
var _glints: Array = []    # [Vector2 local position, life]
var _glint_t := 0.0
var _shown_fill := 0.0     # eased store fill, so the window level glides
var _tag_a := 0.0          # fade of the UPGRADE tag
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
	_shown_fill = GameManager.store_fill()


func hit() -> void:
	_flash = 1.0
	_shake = 0.2
	if _pop_cd <= 0.0:
		_pop_cd = 0.18
		_spray_seed(global_position + Vector2(randf_range(-8, 8), _wall_top() + 2.0), Vector2(randf_range(-70, 70), randf_range(-110, -60)))


func bump() -> void:
	_bump = 1.0
	for i in 3:
		_add_glint()


## An upgrade was bought: the sprite swaps to the taller silo, so bounce, flash gold and throw sparks.
func upgraded() -> void:
	_bump = 1.0
	_gold = 1.0
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	var top := global_position + Vector2(0, -_height() + 10)
	arena.fx.burst(top, 30, [PixelArt.C["y"], PixelArt.C["w"], PixelArt.C["Y"], PixelArt.C["o"]], 50, 160, 0.4, 0.9, 1.0, 120.0)
	arena.fx.ring(global_position + Vector2(0, -22), 40.0, PixelArt.C["y"], 0.35)


func _height() -> int:
	return MiscArt.silo_height(GameManager.silo_level)


## Top-left of the sprite, in this node's local space (the foot of the silo sits on y = 0).
func _origin() -> Vector2:
	return Vector2(SPRITE_X, -_height() + 1)


## Local y where the straight wall starts, under the roof rim.
func _wall_top() -> float:
	return _origin().y + MiscArt.silo_body_top(GameManager.silo_level)


func _frac() -> float:
	return clampf(GameManager.silo_hp / maxf(1.0, GameManager.silo_max_hp), 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_bump = maxf(0.0, _bump - delta * 3.0)
	_shake = maxf(0.0, _shake - delta)
	_gold = maxf(0.0, _gold - delta * 2.0)
	_pop_cd = maxf(0.0, _pop_cd - delta)
	_shown_fill = lerpf(_shown_fill, GameManager.store_fill(), 1.0 - exp(-delta * 8.0))
	# sun glints: on the seed level in the window and on the roof's lit side
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
	# a leaking hole near the foot when badly damaged
	if _frac() < 0.2:
		_leak_cd -= delta
		if _leak_cd <= 0.0:
			_leak_cd = randf_range(0.25, 0.6)
			_spray_seed(global_position + Vector2(11, -11), Vector2(randf_range(20, 50), randf_range(-10, 10)))
	# the UPGRADE tag fades in while a pilot is within reach
	var near := false
	for p in GameManager.players:
		if is_instance_valid(p) and not p.downed and p.global_position.distance_to(ArenaMap.SILO_CENTER) < USE_RANGE:
			near = true
	_tag_a = move_toward(_tag_a, 1.0 if near and not GameManager.silo_maxed() else 0.0, delta * 5.0)
	queue_redraw()


func _add_glint() -> void:
	var o := _origin()
	var g := MiscArt.silo_gauge(GameManager.silo_level)
	var rows := int(roundf(_shown_fill * g.size.y))
	if rows > 1 and randf() < 0.6:
		_glints.append([o + Vector2(g.position.x + randi_range(0, g.size.x - 1), g.end.y - randi_range(1, rows)), 0.45])
	else:
		_glints.append([o + Vector2(randi_range(16, 20), MiscArt.silo_body_top(GameManager.silo_level) - randi_range(4, 11)), 0.45])


func _spray_seed(pos: Vector2, vel: Vector2) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	arena.fx.particle(pos, vel, randf_range(0.5, 0.8), PixelArt.C["s"] if randf() < 0.7 else PixelArt.C["S"], 1.0, 320.0, 1.0)


func _draw() -> void:
	var lv := GameManager.silo_level
	var h := _height()
	var frac := _frac()
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(randi_range(-1, 1), 0)
	# ground contact shadow (not squashed)
	for dy in range(-3, 4):
		var hw := roundf(25.0 * sqrt(maxf(0.0, 1.0 - pow(dy / 3.6, 2.0))))
		draw_rect(Rect2(-hw, dy, hw * 2.0, 1), Color(0.05, 0.03, 0.08, 0.22 if absi(dy) < 2 else 0.14))
	var squash := 1.0 + sin(_bump * PI) * 0.07
	draw_set_transform(sh, 0.0, Vector2(1.0 / squash, squash))
	var tint := Color.WHITE.lerp(Color(1, 0.55, 0.55), _flash).lerp(Color(1, 0.95, 0.6), _gold * 0.6)
	draw_texture(PixelArt.tex("silo_%d" % lv), _origin(), tint)
	_draw_gauge(lv)
	for g in _glints:
		_draw_glint(g[0], g[1])
	_draw_damage(frac)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# danger: pulsing dotted ring when the structure is nearly gone
	if frac < 0.3:
		var pulse := 0.45 + 0.35 * sin(_t * 8.0)
		PixelArt.draw_ring(self, Vector2(0, -22), 35.0 + sin(_t * 8.0), Color(1, 0.25, 0.2, pulse), 48)
	if _tag_a > 0.01:
		var cost := GameManager.silo_upgrade_cost()
		var col: Color = PixelArt.C["y"] if GameManager.can_afford(cost) else PixelArt.C["g"]
		PixelArt.draw_text_centered(self, Vector2(0, -h - 9), "UPGRADE %d" % cost, Color(col, _tag_a), true)


## Seeds filling the window from the bottom, a bright surface line, glass gloss, and a warning pulse when full.
func _draw_gauge(lv: int) -> void:
	var g := MiscArt.silo_gauge(lv)
	var gp := _origin() + Vector2(g.position)
	var rows := int(roundf(_shown_fill * g.size.y))
	for row in rows:
		var y := g.size.y - 1 - row
		for x in g.size.x:
			var n := (x * 7 + y * 13 + (x * y) % 5) % 8
			var c: Color = PixelArt.C["Y"]
			if n < 2:
				c = PixelArt.C["y"]
			elif n == 2:
				c = PixelArt.C["s"]
			elif n == 3:
				c = PixelArt.C["S"]
			draw_rect(Rect2(gp + Vector2(x, y), Vector2.ONE), c)
	if rows > 0:
		draw_rect(Rect2(gp + Vector2(0, g.size.y - rows), Vector2(g.size.x, 1)), PixelArt.C["I"])
	draw_rect(Rect2(gp, Vector2(1, g.size.y)), Color(1, 1, 1, 0.22))
	if GameManager.store_space() <= 0:
		var a := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(Rect2(gp - Vector2(1, 1), Vector2(g.size.x + 2, g.size.y + 2)), Color(PixelArt.C["r"], a), false, 1.0)


func _draw_glint(pos: Vector2, life: float) -> void:
	var gp := pos.round()
	var a := clampf(life / 0.2, 0.0, 1.0)
	draw_rect(Rect2(gp, Vector2(1, 1)), Color(1, 1, 0.9, a))
	if life > 0.15:
		var arm := Color(1, 1, 0.85, a * 0.7)
		draw_rect(Rect2(gp + Vector2(-1, 0), Vector2(1, 1)), arm)
		draw_rect(Rect2(gp + Vector2(1, 0), Vector2(1, 1)), arm)
		draw_rect(Rect2(gp + Vector2(0, -1), Vector2(1, 1)), arm)
		draw_rect(Rect2(gp + Vector2(0, 1), Vector2(1, 1)), arm)


## Rat damage accumulates on the structure: rim bites, then cracks, then a leaking hole.
func _draw_damage(frac: float) -> void:
	var hole := PixelArt.C["k"]
	var crack := PixelArt.C["G"].darkened(0.35)
	var edge := PixelArt.C["w"]
	var rim := _wall_top() - 3.0
	var wt := _wall_top()
	if frac < 0.8:
		for bx in [-15, 9]:
			draw_rect(Rect2(bx, rim, 3, 2), hole)
			draw_rect(Rect2(bx + 1, rim + 2, 1, 1), hole)
			draw_rect(Rect2(bx - 1, rim, 1, 1), crack)
	if frac < 0.55:
		var pts := [Vector2(13, wt + 4), Vector2(14, wt + 8), Vector2(12, wt + 11), Vector2(15, wt + 15), Vector2(14, wt + 18)]
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], crack, 1.0)
			draw_line(pts[i] + Vector2(-1, 0), pts[i + 1] + Vector2(-1, 0), Color(edge, 0.5), 1.0)
	if frac < 0.35:
		var pts2 := [Vector2(-16, wt + 6), Vector2(-14, wt + 10), Vector2(-15, wt + 14), Vector2(-12, wt + 18), Vector2(-13, wt + 22)]
		for i in pts2.size() - 1:
			draw_line(pts2[i], pts2[i + 1], crack, 1.0)
		draw_line(Vector2(-14, wt + 10), Vector2(-18, wt + 13), crack, 1.0)
		draw_rect(Rect2(-2, rim, 5, 2), hole)
		draw_rect(Rect2(-1, rim + 2, 3, 1), hole)
	if frac < 0.2:
		draw_rect(Rect2(9, -13, 4, 3), hole)
		draw_rect(Rect2(10, -14, 2, 1), crack)
		draw_rect(Rect2(10, -12, 1, 1), PixelArt.C["y"])
