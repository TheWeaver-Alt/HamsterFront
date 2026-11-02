extends CanvasLayer
## "Eat the Forbidden Brie" corruption: the pilot hallucinates giant shadowy cats prowling
## and peeking around the screen edges. Purely visual, never blocks input.
## CONTRACT: MainArena creates a CanvasLayer, sets this script and adds it as a child when any
## player has the "forbidden_brie" flag. Freezes while the tree is paused.

const MAX_CATS := 3
const SHADOW := Color(0.04, 0.01, 0.07, 1.0)   # drawn opaque inside a CanvasGroup...
const SHADOW_ALPHA := 0.7                        # ...which fades the whole silhouette uniformly
const EYE := Color8(200, 255, 90)

var _canvas: Node2D           # current draw target (switches between layers below)
var _vignette: Node2D
var _group: CanvasGroup
var _shadows: Node2D
var _eyes: Node2D
var _cats: Array = []
var _spawn_t := 1.5
var _t := 0.0


func _ready() -> void:
	if layer == 1:
		layer = 5
	_vignette = Node2D.new()
	_vignette.name = "Vignette"
	_vignette.draw.connect(_draw_vignette)
	add_child(_vignette)
	_group = CanvasGroup.new()
	_group.name = "Silhouettes"
	_group.self_modulate = Color(1, 1, 1, SHADOW_ALPHA)
	add_child(_group)
	_shadows = Node2D.new()
	_shadows.draw.connect(_draw_shadows)
	_group.add_child(_shadows)
	_eyes = Node2D.new()
	_eyes.name = "Eyes"
	_eyes.draw.connect(_draw_eyes)
	add_child(_eyes)
	_canvas = _shadows


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _cats.size() < MAX_CATS:
		_spawn_t = randf_range(3.0, 7.0)
		_spawn_cat()
	var k := _cats.size() - 1
	while k >= 0:
		var c: Dictionary = _cats[k]
		c["t"] += delta
		var t: float = c["t"]
		var life: float = c["life"]
		# peek in, prowl, retreat
		var target := 0.0
		if t < 1.4:
			target = clampf(t / 1.4, 0.0, 1.0)
		elif t < life - 1.6:
			target = 1.0
		else:
			target = clampf((life - t) / 1.6, 0.0, 1.0)
		c["peek"] = lerpf(c["peek"], target, minf(1.0, delta * 3.0))
		c["along"] += c["speed"] * delta
		# occasional lunge
		c["lunge_cd"] -= delta
		if c["lunge_cd"] <= 0.0 and t > 1.4 and t < life - 2.0:
			c["lunge_cd"] = randf_range(2.5, 5.0)
			c["lunge"] = 1.0
		c["lunge"] = maxf(0.0, c["lunge"] - delta * 2.2)
		c["blink"] -= delta
		if c["blink"] < -0.14:
			c["blink"] = randf_range(1.5, 4.0)
		if t >= life:
			_cats.remove_at(k)
		k -= 1
	_vignette.queue_redraw()
	_shadows.queue_redraw()
	_eyes.queue_redraw()


func _spawn_cat() -> void:
	# 0 bottom, 2 left, 3 right (the top edge sits under the HUD bar, so cats skip it)
	var edges: Array = [0, 2, 3]
	edges.shuffle()
	var edge: int = edges[0]
	for e in edges:
		var taken := false
		for c in _cats:
			if c["edge"] == e:
				taken = true
		if not taken:
			edge = e
			break
	var span := 640.0 if edge < 2 else 360.0
	_cats.append({
		"edge": edge,
		"along": randf_range(span * 0.3, span * 0.7) if edge == 0 else randf_range(span * 0.15, span * 0.85),
		"speed": randf_range(-14.0, 14.0),
		"scale": randf_range(1.5, 2.1),
		"t": 0.0,
		"life": randf_range(7.0, 12.0),
		"peek": 0.0,
		"lunge": 0.0,
		"lunge_cd": randf_range(1.5, 3.5),
		"blink": randf_range(1.0, 3.0),
		"phase": randf() * TAU,
	})
	Sfx.play("squeak_hamster", 0.45, -16.0)


## Transform for a cat: origin on the screen edge, local -Y points into the screen.
func _cat_xform(c: Dictionary) -> Transform2D:
	var along: float = c["along"]
	var edge: int = c["edge"]
	var span := 640.0 if edge < 2 else 360.0
	along = fposmod(along, span + 160.0) - 80.0
	var s: float = c["scale"]
	match edge:
		0:
			return Transform2D(0.0, Vector2(s, s), 0.0, Vector2(along, 360))
		1:
			return Transform2D(PI, Vector2(s, s), 0.0, Vector2(along, 0))
		2:
			return Transform2D(PI / 2.0, Vector2(s, s), 0.0, Vector2(0, along))
		_:
			return Transform2D(-PI / 2.0, Vector2(s, s), 0.0, Vector2(640, along))


func _draw_vignette() -> void:
	_canvas = _vignette
	# faint purple vignette while the cheese is in your system
	var pulse := 0.06 + 0.03 * sin(_t * 1.7)
	for i in 6:
		var a := pulse * (1.0 - i / 6.0)
		var c := Color(0.25, 0.05, 0.3, a)
		_canvas.draw_rect(Rect2(0, i * 3, 640, 3), c)
		_canvas.draw_rect(Rect2(0, 357 - i * 3, 640, 3), c)
		_canvas.draw_rect(Rect2(i * 3, 0, 3, 360), c)
		_canvas.draw_rect(Rect2(637 - i * 3, 0, 3, 360), c)


func _draw_shadows() -> void:
	_canvas = _shadows
	for c in _cats:
		_draw_cat_body(c)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_eyes() -> void:
	_canvas = _eyes
	for c in _cats:
		_draw_cat_eyes(c)
	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


func _head_pos(c: Dictionary) -> Vector2:
	var peek: float = c["peek"]
	var lunge: float = c["lunge"]
	var rise := -peek * 34.0 - sin(lunge * PI) * 14.0
	return Vector2(sin(_t * 0.8 + float(c["phase"])) * 3.0, rise)


func _draw_cat_body(c: Dictionary) -> void:
	var peek: float = c["peek"]
	if peek <= 0.01:
		return
	var lunge: float = c["lunge"]
	var ph: float = c["phase"]
	var head := _head_pos(c)
	var rise := head.y
	_canvas.draw_set_transform_matrix(_cat_xform(c))
	var sh := SHADOW
	# body + shoulders (mostly off-screen)
	_blob(Vector2(-6, 34 + rise * 0.3), 34.0, sh)
	_blob(Vector2(0, 18 + rise * 0.6), 26.0, sh)
	# swishing tail
	var tail_base := Vector2(30, 30 + rise * 0.2)
	for k in 12:
		var f := k / 11.0
		var sway := sin(_t * 2.2 + ph + f * 2.6) * 10.0 * f
		var p := tail_base + Vector2(8.0 * f + sway, -f * 46.0 * clampf(peek, 0.0, 1.0))
		_blob(p, lerpf(6.0, 3.5, f), sh)
	# head
	_blob(head, 21.0, sh)
	# ears
	for side in [-1.0, 1.0]:
		var e := PackedVector2Array([
			head + Vector2(side * 6.0, -14.0),
			head + Vector2(side * 20.0, -30.0 - sin(_t * 3.0 + side) * 2.0),
			head + Vector2(side * 19.0, -8.0),
		])
		_canvas.draw_colored_polygon(e, sh)
	# paw during lunge
	if lunge > 0.0:
		var paw := head + Vector2(16.0, -16.0 - sin(lunge * PI) * 22.0)
		_blob(paw, 7.0, sh)


func _draw_cat_eyes(c: Dictionary) -> void:
	var peek: float = c["peek"]
	if peek <= 0.05:
		return
	var lunge: float = c["lunge"]
	var ph: float = c["phase"]
	var head := _head_pos(c)
	_canvas.draw_set_transform_matrix(_cat_xform(c))
	var eye_a := clampf(peek * 1.6, 0.0, 1.0)
	# claws glinting during a lunge
	if lunge > 0.0:
		var paw := head + Vector2(16.0, -16.0 - sin(lunge * PI) * 22.0)
		for k in 3:
			_canvas.draw_rect(Rect2((paw + Vector2(-4 + k * 3, -9)).round(), Vector2(1, 3)), Color(0.9, 0.9, 1.0, 0.55))
	var blinking: bool = c["blink"] < 0.0
	for side in [-1.0, 1.0]:
		var ep := head + Vector2(side * 8.0, -3.0)
		if blinking:
			_canvas.draw_rect(Rect2((ep + Vector2(-3, 0)).round(), Vector2(7, 1)), Color(EYE, eye_a * 0.8))
		else:
			_canvas.draw_rect(Rect2((ep + Vector2(-3, -2)).round(), Vector2(7, 4)), Color(EYE, eye_a))
			_canvas.draw_rect(Rect2((ep + Vector2(-2, -3)).round(), Vector2(5, 6)), Color(EYE, eye_a))
			# slit pupil, glancing around
			var look := roundf(sin(_t * 0.9 + ph) * 1.5)
			_canvas.draw_rect(Rect2((ep + Vector2(look, -3)).round(), Vector2(1, 6)), Color(0.02, 0.0, 0.05, eye_a))
			_canvas.draw_rect(Rect2((ep + Vector2(-2, -2)).round(), Vector2(1, 1)), Color(1, 1, 1, eye_a * 0.7))
	# whiskers
	var wc := Color(0.85, 0.85, 1.0, 0.25 * eye_a)
	for side in [-1.0, 1.0]:
		for k in 2:
			_canvas.draw_line((head + Vector2(side * 9.0, 6.0 + k * 3)).round(), (head + Vector2(side * 30.0, 3.0 + k * 6)).round(), wc, 1.0)


func _blob(center: Vector2, r: float, col: Color) -> void:
	PixelArt.draw_disk(_canvas, center, r, col)
