extends Node2D
## AmbientLayer — the backyard's ambient life, layered around the gameplay:
##   * ground decor, inserted just above the terrain and below everything else: wind-swayed grass
##     tufts, tall grass and wild flowers that bend away from mechs (colour patches are baked into
##     the terrain tiles by TerrainArt);
##   * tall sunflowers along the fence (y-sorted in World, see ambient/Sunflower.gd);
##   * this node itself (z 30): drifting cloud shadows, butterflies, bumblebees, pollen motes,
##     falling leaves, dusk fireflies and a soft vignette;
##   * a CanvasModulate time-of-day tint: fresh morning -> golden afternoon -> sunset -> dusk as
##     GameManager.wave rises (HUD / menus live on CanvasLayers, so they're unaffected).
## Everything is batched into a few _draw() calls with precomputed data (~0.1 ms per frame).
##
## MainArena creates this node, calls setup(arena) and adds it as a child of the arena.

const SunflowerScript := preload("res://scripts/systems/ambient/Sunflower.gd")
const LEANS := ["l", "c", "r"]
const MAP_W := 640.0
const MAP_H := 352.0

const TOD_KEYS := [
	[0.0, Color(0.97, 0.98, 1.0)],     # fresh morning
	[3.0, Color(1.0, 1.0, 1.0)],       # midday
	[6.0, Color(1.0, 0.96, 0.89)],     # warm afternoon
	[9.0, Color(1.0, 0.91, 0.78)],     # golden hour
	[12.0, Color(0.98, 0.83, 0.79)],   # sunset
	[15.0, Color(0.83, 0.81, 0.96)],   # dusk
	[20.0, Color(0.78, 0.79, 0.94)],   # evening
]

var arena = null
var map: ArenaMap = null
var ground_dyn: Node2D = null
var tint_node: CanvasModulate = null
var t := 0.0

# wind
var _gust_x := -999.0
var _gust_cd := 3.0
var _ground_t := 0.0

# ground decor (struct of arrays)
var _d_pos := PackedVector2Array()
var _d_kind := PackedInt32Array()       # 0..2 tufts, 3 tall grass, 10..13 flowers
var _d_phase := PackedFloat32Array()
var _d_tex: Dictionary = {}             # kind -> [tex_l, tex_c, tex_r]
var _flower_spots := PackedVector2Array()

# sky / critters
var _clouds: Array = []                 # [Vector2 pos, Texture2D, float speed]
var _butterflies: Array = []            # Dictionary per butterfly
var _bees: Array = []
var _motes := PackedVector2Array()
var _mote_phase := PackedFloat32Array()
var _leaves: Array = []                 # [pos, vel, land_y, life, frame_t]
var _leaf_cd := 4.0
var _fireflies: Array = []              # [pos, vel, phase]
var _vignette: Texture2D = null
var _tint_now := Color.WHITE
var _dusk := 0.0


func setup(a) -> void:
	arena = a
	map = a.map


func _ready() -> void:
	z_index = 30
	if arena == null:
		arena = get_parent()
		map = arena.map
	_load_textures()
	_build_vignette()
	_place_decor()
	_spawn_critters()
	_tint_now = _tod_color(float(GameManager.wave))
	_install_children.call_deferred()


# ------------------------------------------------------------------ setup

func _install_children() -> void:
	if not is_instance_valid(arena):
		return
	var after: int = arena.ground.get_index()
	ground_dyn = Node2D.new()
	ground_dyn.name = "AmbientGroundLife"
	ground_dyn.draw.connect(_draw_ground_dyn)
	arena.add_child(ground_dyn)
	arena.move_child(ground_dyn, after + 1)
	tint_node = CanvasModulate.new()
	tint_node.name = "TimeOfDay"
	tint_node.color = _tint_now
	arena.add_child(tint_node)
	_plant_sunflowers()


func _load_textures() -> void:
	for v in 3:
		_d_tex[v] = _lean_set("amb_tuft_%d_" % v)
	_d_tex[3] = _lean_set("amb_tall_")
	for k in 4:
		_d_tex[10 + k] = _lean_set("amb_flower_%d_" % k)


func _lean_set(prefix: String) -> Array:
	var out: Array = []
	for l in LEANS:
		out.append(PixelArt.tex(prefix + l))
	return out


## Soft vignette as four gradient edge strips (no full-screen overdraw).
func _build_vignette() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.06, 0.03, 0.1, 0.26), Color(0.06, 0.03, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 32
	gt.height = 4
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	_vignette = gt


func _place_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for y in ArenaMap.H:
		for x in ArenaMap.W:
			var c := Vector2i(x, y)
			var ct := map.cell_type(c)
			var origin := Vector2(x * 16, y * 16)
			var near_fence := map.cell_type(Vector2i(x - 1, y)) == ArenaMap.Cell.WALL \
				or map.cell_type(Vector2i(x + 1, y)) == ArenaMap.Cell.WALL \
				or map.cell_type(Vector2i(x, y + 1)) == ArenaMap.Cell.WALL \
				or map.cell_type(Vector2i(x, y - 1)) == ArenaMap.Cell.WALL
			match ct:
				ArenaMap.Cell.GRASS, ArenaMap.Cell.HIGH:
					var high := ct == ArenaMap.Cell.HIGH
					var n := rng.randi_range(0, 2) if rng.randf() < (0.55 if not high else 0.5) else 0
					for i in n:
						_add_decor(origin + Vector2(rng.randf_range(3, 13), rng.randf_range(5, 15)), rng.randi_range(0, 2), rng)
					if rng.randf() < (0.11 if not high else 0.15):
						var fk: int = 10 + (rng.randi_range(0, 3) if high else rng.randi_range(0, 1))
						var fp := origin + Vector2(rng.randf_range(3, 13), rng.randf_range(6, 15))
						_add_decor(fp, fk, rng)
						_flower_spots.append(fp + Vector2(0, -6))
					if near_fence and rng.randf() < 0.45:
						_add_decor(origin + Vector2(rng.randf_range(3, 13), rng.randf_range(8, 15)), 3, rng)
					if high and map.cell_type(Vector2i(x, y - 1)) != ArenaMap.Cell.HIGH \
							and map.cell_elev(Vector2i(x, y - 1)) == 0 and rng.randf() < 0.3:
						_add_decor(origin + Vector2(rng.randf_range(3, 13), 8), 3, rng)
				ArenaMap.Cell.PATH:
					if map.cell_type(Vector2i(x, y - 1)) == ArenaMap.Cell.FACE:
						# weeds at the foot of the cliff
						if rng.randf() < 0.5:
							_add_decor(origin + Vector2(rng.randf_range(2, 14), rng.randf_range(4, 7)), 3 if rng.randf() < 0.5 else 0, rng)
					elif rng.randf() < 0.05:
						_add_decor(origin + Vector2(rng.randf_range(3, 13), rng.randf_range(5, 15)), 2, rng)
				ArenaMap.Cell.PATIO:
					if rng.randf() < 0.12:
						_add_decor(origin + Vector2(rng.randf_range(2, 14), rng.randf_range(4, 15)), 2, rng)


func _add_decor(p: Vector2, kind: int, rng: RandomNumberGenerator) -> void:
	_d_pos.append(p.round())
	_d_kind.append(kind)
	_d_phase.append(rng.randf_range(-1.0, 1.0))


func _plant_sunflowers() -> void:
	var spots: Array = []
	# right fence, behind the courtyard
	var y := 40.0
	while y < 318.0:
		spots.append(Vector2(632, y))
		y += 34.0
	# bottom fence, between the HUD panels, avoiding the bottom-row pads
	var x := 150.0
	while x < 495.0:
		var clear := true
		for p in ArenaMap.PADS:
			if (p.y == 20 or p.y == 19) and absf(ArenaMap.cell_center(p).x - x) < 18.0:
				clear = false
		if clear:
			spots.append(Vector2(x, 350))
		x += 36.0
	# left fence, between the burrows
	for ly in [44.0, 140.0, 238.0, 318.0]:
		spots.append(Vector2(8, ly))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for s in spots:
		var f = Node2D.new()
		f.set_script(SunflowerScript)
		f.ambient = self
		f.phase = rng.randf_range(-1.0, 1.0)
		f.position = (s as Vector2) + Vector2(rng.randi_range(-2, 2), 0)
		arena.world.add_child(f)


func _spawn_critters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	for i in 3:
		_clouds.append([Vector2(rng.randf_range(-160, 600), rng.randf_range(-40, 280)),
			PixelArt.tex("amb_cloud_%d" % i), rng.randf_range(5.0, 9.0)])
	for i in 4:
		_butterflies.append({"p": _random_point(rng), "v": Vector2.ZERO, "target": _random_point(rng),
			"color": i % 4, "flap": 0.0, "frame": 0, "alt": 8.0, "rest": 0.0})
	for i in 2:
		_bees.append({"p": _random_point(rng), "v": Vector2.ZERO, "target": _random_point(rng),
			"frame": 0, "flap": 0.0, "hover": 0.0})
	for i in 40:
		_motes.append(Vector2(rng.randf_range(0, MAP_W), rng.randf_range(0, MAP_H)))
		_mote_phase.append(rng.randf_range(0.0, TAU))
	for i in 20:
		_fireflies.append([_random_point(rng), Vector2.ZERO, rng.randf_range(0.0, TAU)])


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	if _flower_spots.size() > 0 and rng.randf() < 0.6:
		return _flower_spots[rng.randi_range(0, _flower_spots.size() - 1)]
	return Vector2(rng.randf_range(30, MAP_W - 30), rng.randf_range(30, MAP_H - 24))


# ------------------------------------------------------------------ wind + time of day

## Signed wind strength at a point (about -1..1.5): a slow travelling wave plus gust bands.
func wind_at(p: Vector2, phase: float = 0.0) -> float:
	var w := sin(t * 1.6 - p.x * 0.045 + p.y * 0.012 + phase * 0.8) * 0.6 + 0.12
	var gd := absf(p.x - _gust_x)
	if gd < 70.0:
		w += 1.0 * (1.0 - gd / 70.0)
	return w


func _tod_color(w: float) -> Color:
	for i in range(TOD_KEYS.size() - 1):
		var a: Array = TOD_KEYS[i]
		var b: Array = TOD_KEYS[i + 1]
		if w <= float(b[0]):
			var f := clampf((w - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return (a[1] as Color).lerp(b[1], f)
	return TOD_KEYS[TOD_KEYS.size() - 1][1]


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	t += delta
	var w := float(GameManager.wave)
	_dusk = clampf((w - 10.0) / 5.0, 0.0, 1.0)
	var target := _tod_color(w)
	_tint_now = _tint_now.lerp(target, minf(1.0, delta * 0.35))
	if is_instance_valid(tint_node):
		tint_node.color = _tint_now
	# gusts sweep left -> right across the yard
	if _gust_x > MAP_W + 80.0 or _gust_x < -900.0:
		_gust_cd -= delta
		if _gust_cd <= 0.0:
			_gust_x = -80.0
			_gust_cd = randf_range(4.0, 9.0)
	else:
		_gust_x += 150.0 * delta
	# ground life redraws at ~16 fps (pixel-art sway frames)
	_ground_t -= delta
	if _ground_t <= 0.0 and is_instance_valid(ground_dyn):
		_ground_t = 0.06
		ground_dyn.queue_redraw()
	_update_clouds(delta)
	_update_butterflies(delta)
	_update_bees(delta)
	_update_motes(delta)
	_update_leaves(delta)
	_update_fireflies(delta)
	queue_redraw()


func _mech_positions() -> Array:
	var out: Array = []
	for p in GameManager.players:
		if is_instance_valid(p) and not p.downed:
			out.append(p.global_position)
	return out


func _update_clouds(delta: float) -> void:
	for c in _clouds:
		var p: Vector2 = c[0]
		p.x += float(c[2]) * delta
		p.y += sin(t * 0.07 + float(c[2])) * 1.5 * delta
		if p.x > MAP_W + 10.0:
			p.x = -180.0
			p.y = randf_range(-40, 280)
		c[0] = p


func _update_butterflies(delta: float) -> void:
	var mechs := _mech_positions()
	for b in _butterflies:
		var p: Vector2 = b["p"]
		var target: Vector2 = b["target"]
		var spd := 22.0
		var scared := false
		for m in mechs:
			var mp: Vector2 = m
			if p.distance_to(mp) < 28.0:
				target = p + (p - mp).normalized() * 70.0
				scared = true
				spd = 55.0
		if scared:
			b["rest"] = 0.0
			b["target"] = target.clamp(Vector2(20, 20), Vector2(MAP_W - 20, MAP_H - 20))
		if b["rest"] > 0.0:
			b["rest"] -= delta
			b["alt"] = move_toward(b["alt"], 2.0, delta * 20.0)
			b["flap"] += delta * 0.4
			if b["rest"] <= 0.0:
				b["target"] = _random_point_rt()
		else:
			var to := target - p
			if to.length() < 4.0:
				b["rest"] = randf_range(1.0, 3.5)
			var desired := to.normalized() * spd + Vector2(sin(t * 3.1 + p.y) * 10.0, cos(t * 2.3 + p.x) * 8.0)
			var v: Vector2 = (b["v"] as Vector2).lerp(desired, minf(1.0, delta * 2.5))
			b["v"] = v
			b["p"] = p + v * delta
			b["alt"] = 8.0 + sin(t * 4.0 + p.x * 0.1) * 3.0
			b["flap"] += delta
		if b["flap"] > (0.09 if b["rest"] <= 0.0 else 0.4):
			b["flap"] = 0.0
			b["frame"] = 1 - int(b["frame"])


func _random_point_rt() -> Vector2:
	if _flower_spots.size() > 0 and randf() < 0.6:
		return _flower_spots[randi() % _flower_spots.size()]
	return Vector2(randf_range(30, MAP_W - 30), randf_range(30, MAP_H - 24))


func _update_bees(delta: float) -> void:
	for b in _bees:
		var p: Vector2 = b["p"]
		var target: Vector2 = b["target"]
		b["flap"] += delta
		if b["flap"] > 0.04:
			b["flap"] = 0.0
			b["frame"] = 1 - int(b["frame"])
		if b["hover"] > 0.0:
			b["hover"] -= delta
			b["p"] = target + Vector2(sin(t * 9.0) * 2.0, cos(t * 7.0) * 1.5)
			if b["hover"] <= 0.0:
				b["target"] = _random_point_rt()
			continue
		var to := target - p
		if to.length() < 3.0:
			b["hover"] = randf_range(0.8, 2.2)
			continue
		var desired := to.normalized() * 48.0 + Vector2(sin(t * 11.0) * 18.0, cos(t * 13.0) * 14.0)
		var v: Vector2 = (b["v"] as Vector2).lerp(desired, minf(1.0, delta * 4.0))
		b["v"] = v
		b["p"] = p + v * delta


func _update_motes(delta: float) -> void:
	for i in _motes.size():
		var p := _motes[i]
		var ph := _mote_phase[i]
		p += Vector2(7.0 + sin(t * 0.8 + ph) * 4.0, sin(t * 1.3 + ph * 2.0) * 4.0) * delta
		if p.x > MAP_W:
			p.x -= MAP_W
		if p.y < 0.0:
			p.y += MAP_H
		elif p.y > MAP_H:
			p.y -= MAP_H
		_motes[i] = p


func _update_leaves(delta: float) -> void:
	_leaf_cd -= delta
	if _leaf_cd <= 0.0 and _leaves.size() < 8:
		_leaf_cd = randf_range(3.0, 7.0)
		_leaves.append([Vector2(randf_range(0, MAP_W * 0.8), -6.0), Vector2(10.0, 14.0),
			randf_range(40.0, MAP_H - 20.0), 5.0, 0.0])
	var k := _leaves.size() - 1
	while k >= 0:
		var lf: Array = _leaves[k]
		var p: Vector2 = lf[0]
		var land_y: float = lf[2]
		if p.y < land_y:
			p.x += (sin(t * 2.6 + float(k)) * 18.0 + 10.0) * delta
			p.y += 15.0 * delta
			lf[4] += delta
		else:
			lf[3] -= delta
		lf[0] = p
		if lf[3] <= 0.0 or p.x > MAP_W + 10.0:
			_leaves.remove_at(k)
		k -= 1


func _update_fireflies(delta: float) -> void:
	if _dusk <= 0.0:
		return
	for f in _fireflies:
		var p: Vector2 = f[0]
		var v: Vector2 = f[1]
		v = v.lerp(Vector2(sin(t * 0.7 + float(f[2]) * 3.0), cos(t * 0.9 + float(f[2]) * 2.0)) * 9.0, minf(1.0, delta))
		p += v * delta
		p = p.clamp(Vector2(20, 20), Vector2(MAP_W - 20, MAP_H - 20))
		f[0] = p
		f[1] = v


# ------------------------------------------------------------------ drawing

func _draw_ground_dyn() -> void:
	var mechs := _mech_positions()
	for i in _d_pos.size():
		var p := _d_pos[i]
		var w := wind_at(p, _d_phase[i])
		var li := 1
		if w > 0.5:
			li = 2
		elif w < -0.45:
			li = 0
		# bend away from mechs walking through
		for m in mechs:
			var mp: Vector2 = m
			var dx := p.x - mp.x
			if absf(dx) < 11.0 and absf(p.y - mp.y) < 7.0:
				li = 2 if dx > 0.0 else 0
		var tex: Texture2D = _d_tex[_d_kind[i]][li]
		ground_dyn.draw_texture(tex, Vector2(p.x - floorf(tex.get_width() / 2.0), p.y - tex.get_height() + 1))


func _draw() -> void:
	# cloud shadows
	for c in _clouds:
		var cp: Vector2 = c[0]
		draw_texture(c[1], cp.round())
	# pollen / dust motes
	for i in _motes.size():
		var a := 0.25 + 0.3 * (0.5 + 0.5 * sin(t * 2.0 + _mote_phase[i] * 3.0))
		draw_rect(Rect2(_motes[i].round(), Vector2(1, 1)), Color(1.0, 0.97, 0.75, a))
	# falling leaves
	for lf in _leaves:
		var lp: Vector2 = lf[0]
		var fade := clampf(float(lf[3]) / 1.5, 0.0, 1.0)
		var frame := int(float(lf[4]) * 4.0) % 2
		draw_texture(PixelArt.tex("amb_leaf_%d" % frame), lp.round(), Color(1, 1, 1, fade))
	# bees
	for b in _bees:
		var bp: Vector2 = b["p"]
		draw_rect(Rect2((bp + Vector2(0, 6)).round(), Vector2(2, 1)), Color(0.05, 0.03, 0.08, 0.2))
		draw_texture(PixelArt.tex("amb_bee_%d" % int(b["frame"])), (bp - Vector2(3, 2)).round())
	# butterflies
	for b in _butterflies:
		var bp2: Vector2 = b["p"]
		var alt: float = b["alt"]
		draw_rect(Rect2((bp2 + Vector2(-1, 0)).round(), Vector2(2, 1)), Color(0.05, 0.03, 0.08, 0.22))
		var tex := PixelArt.tex("amb_butterfly_%d_%d" % [int(b["color"]), int(b["frame"])])
		draw_texture(tex, (bp2 - Vector2(2, alt + 2)).round())
	# fireflies at dusk
	if _dusk > 0.0:
		var n := int(roundf(_fireflies.size() * _dusk))
		for i in n:
			var f: Array = _fireflies[i]
			var glow := pow(maxf(0.0, sin(t * 1.7 + float(f[2]) * 5.0)), 3.0)
			if glow < 0.05:
				continue
			var fp: Vector2 = (f[0] as Vector2).round()
			PixelArt.draw_disk(self, fp, 2.5, Color(0.75, 1.0, 0.35, 0.22 * glow * _dusk))
			draw_rect(Rect2(fp, Vector2(1, 1)), Color(1.0, 1.0, 0.7, glow * _dusk))
	# soft vignette: gradient strips along the four edges (rotated copies of one texture)
	if _vignette:
		var vw := 56.0
		draw_texture_rect(_vignette, Rect2(0, -8, vw, MAP_H + 16), false)
		draw_set_transform(Vector2(MAP_W, MAP_H + 8), PI, Vector2.ONE)
		draw_texture_rect(_vignette, Rect2(0, 0, vw, MAP_H + 16), false)
		draw_set_transform(Vector2(MAP_W + 8, -8), PI / 2.0, Vector2.ONE)
		draw_texture_rect(_vignette, Rect2(0, 0, 40, MAP_W + 16), false)
		draw_set_transform(Vector2(-8, MAP_H + 8), -PI / 2.0, Vector2.ONE)
		draw_texture_rect(_vignette, Rect2(0, 0, 40, MAP_W + 16), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
