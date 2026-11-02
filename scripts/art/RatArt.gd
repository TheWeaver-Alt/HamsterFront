extends RefCounted
## Under-Scurrier sprites. All face RIGHT; entities flip horizontally when moving left.
## Everything is baked once into textures via PixelArt.tex(name); animation = picking names.
##
## Clan-Squeaker  (22x16, 4 swarm variants v = 0 plain, 1 eyepatch, 2 scarred, 3 bandana)
##   rat_sq_<v>_<pose>_<frame>
##     walk 0-3  scurry cycle        idle 0-1  sniff / twitch      bite 0-1  wind-up / lunge-chomp
##     hit 0     squash recoil       sneeze 0-1 "ah-" / "CHOO"     trip 0    faceplant
##     dead 0-1  belly-up twitch     tumble 0  hit pose rotated 90  zap 0-1   x-ray skeleton flash
##   rat_sq_ghost_<0-1>             rising rat ghost (shared by all units)
##   rat_squeaker_0/1/trip           legacy names (variant 0) used by menus
##   rat_squeaker_ball_<0-1>, rat_squeaker_ball   curled-up squeaker thrown by a Rat-Ogre
## Jezzail      rat_jez_<pose>_<frame>   walk 0-3, aim 0, recoil 0, fumble 0-1, dead 0; rat_jez_rifle_<0-3>
##              rat_jezzail_0/1 legacy
## Monk         rat_monk_<pose>_<frame>  walk 0-3, chant 0-1, dead 0; rat_monk_ghost_<0-1>; rat_monk_0/1 legacy
## Doom-Roomba  rat_roomba_<0-3> (spikes spin, light blinks), rat_roomba_wreck, rat_roomba (legacy)
## Rat-Ogre     rat_ogre_<pose>_<frame>  walk 0-3, windup 0, smash 0, throw 0, hurt 0, fall 0-2, dead 0
##              rat_ogre_0/1/slam legacy
## FX overlays  rat_fx_flame_<0-2> (burning), rat_fx_drip (laser melt)

const PA := preload("res://autoloads/PixelArt.gd")

const SQ_W := 22
const SQ_H := 16

static var _eye_cache: Dictionary = {}


## Eye pixel (image coords, unflipped) of a squeaker pose — for the live warp-glow overlay.
static func sq_eye(pose: String, f: int) -> Vector2i:
	var key := pose + str(f)
	if _eye_cache.has(key):
		return _eye_cache[key]
	var p := _sq_params(pose, f)
	var hx := 15.0 + int(p.get("lean", 0))
	var hy := 7.6 + int(p.get("bob", 0)) - int(p.get("head_up", 0))
	if p.get("squash", false):
		hy += 0.8
	var e := Vector2i(int(hx) + 1, int(hy) - 1)
	_eye_cache[key] = e
	return e


static func make(n: String) -> Image:
	match n:
		"rat_squeaker_0":
			return sq_pose(0, "walk", 0)
		"rat_squeaker_1":
			return sq_pose(0, "walk", 2)
		"rat_squeaker_trip":
			return sq_pose(0, "trip", 0)
		"rat_squeaker_ball":
			return squeaker_ball(0)
		"rat_jezzail_0":
			return jezzail("walk", 0)
		"rat_jezzail_1":
			return jezzail("walk", 2)
		"rat_monk_0":
			return monk("walk", 0)
		"rat_monk_1":
			return monk("walk", 2)
		"rat_roomba":
			return roomba(0)
		"rat_roomba_wreck":
			return roomba_wreck()
		"rat_ogre_0":
			return ogre("walk", 0)
		"rat_ogre_1":
			return ogre("walk", 2)
		"rat_ogre_slam":
			return ogre("windup", 0)
		"rat_fx_drip":
			return PA.from_ascii(["u", "a"])
	var parts := n.split("_")
	if n.begins_with("rat_sq_ghost_"):
		return sq_ghost(int(parts[3]))
	if n.begins_with("rat_sq_") and parts.size() == 5:
		return sq_pose(int(parts[2]), parts[3], int(parts[4]))
	if n.begins_with("rat_squeaker_ball_"):
		return squeaker_ball(int(parts[3]))
	if n.begins_with("rat_jez_rifle_"):
		return _rotated90(jez_rifle(), int(parts[3]))
	if n.begins_with("rat_jez_") and parts.size() == 4:
		return jezzail(parts[2], int(parts[3]))
	if n.begins_with("rat_monk_ghost_"):
		return monk_ghost(int(parts[3]))
	if n.begins_with("rat_monk_") and parts.size() == 4:
		return monk(parts[2], int(parts[3]))
	if n.begins_with("rat_roomba_") and parts.size() == 3:
		return roomba(int(parts[2]))
	if n.begins_with("rat_ogre_") and parts.size() == 4:
		return ogre(parts[2], int(parts[3]))
	if n.begins_with("rat_fx_flame_"):
		return flame(int(parts[3]))
	return null


# ================================================================== helpers

## Exact 90-degree turns (crisp), k = number of clockwise quarter turns.
static func _rotated90(src: Image, k: int) -> Image:
	var img: Image = src.duplicate()
	for i in (k % 4):
		img.rotate_90(CLOCKWISE)
	return img


## Nearest-neighbour rotation of `src` about `pivot` into a size x size canvas whose centre is the
## pivot. Re-outlined afterwards so the result stays crisp pixel art.
static func rotate_about(src: Image, pivot: Vector2, angle: float, size: int) -> Image:
	var out := PA.new_img(size, size)
	var c := Vector2(size / 2.0, size / 2.0)
	var ca := cos(-angle)
	var sa := sin(-angle)
	var sw := src.get_width()
	var sh := src.get_height()
	var outline_c := PA.col("k")
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var s := Vector2(d.x * ca - d.y * sa, d.x * sa + d.y * ca) + pivot
			var sx := int(floorf(s.x))
			var sy := int(floorf(s.y))
			if sx < 0 or sy < 0 or sx >= sw or sy >= sh:
				continue
			var p := src.get_pixel(sx, sy)
			if p.a > 0.5 and p != outline_c:
				out.set_pixel(x, y, p)
	return PA.outline(out)


## Recolour every opaque pixel matching `from` (approx) to `to`.
static func _swap(img: Image, from: Color, to: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5 and absf(p.r - from.r) + absf(p.g - from.g) + absf(p.b - from.b) < 0.02:
				img.set_pixel(x, y, to)


# ================================================================== CLAN-SQUEAKER

static func _sq_fur(v: int) -> Color:
	match v:
		1:
			return PA.col("m").lerp(PA.col("b"), 0.35)       # muddy brown
		2:
			return PA.col("m").lightened(0.14)                # pale, mangy
		3:
			return PA.col("m").darkened(0.1)                  # sooty
	return PA.col("m")


## Pose parameters for the squeaker painter.
static func _sq_params(pose: String, f: int) -> Dictionary:
	# legs: [near-back x, near-front x, far-back x, far-front x], lift: pixels raised per leg
	match pose:
		"walk":
			match f % 4:
				0:
					return {"bob": 0, "legs": [8, 11, 5, 13], "lift": [0, 0, 0, 0], "tail": 0, "fork": "carry"}
				1:
					return {"bob": -1, "legs": [6, 13, 7, 11], "lift": [0, 1, 1, 0], "tail": 1, "fork": "carry"}
				2:
					return {"bob": 0, "legs": [5, 13, 8, 11], "lift": [0, 0, 0, 0], "tail": 2, "fork": "carry"}
				_:
					return {"bob": -1, "legs": [7, 11, 6, 13], "lift": [1, 0, 0, 1], "tail": 3, "fork": "carry"}
		"idle":
			if f % 2 == 0:
				return {"bob": 0, "legs": [7, 12, 6, 11], "tail": 0, "fork": "rest"}
			return {"bob": 0, "legs": [7, 12, 6, 11], "tail": 1, "fork": "rest", "head_up": 1, "nose": 1, "whisk": 1}
		"bite":
			if f % 2 == 0:
				return {"bob": 0, "lean": -1, "head_up": 1, "legs": [6, 12, 5, 11], "tail": 3,
					"fork": "raise", "eyes": "squint"}
			return {"bob": 0, "lean": 2, "legs": [5, 14, 6, 13], "tail": 1, "fork": "jab",
				"mouth": 1, "eyes": "angry"}
		"hit":
			return {"bob": 0, "lean": -1, "squash": true, "legs": [6, 12, 7, 11], "lift": [0, 1, 0, 0],
				"tail": 2, "fork": "rest", "eyes": "shut", "mouth": 1}
		"sneeze":
			if f % 2 == 0:
				return {"bob": 0, "lean": -1, "head_up": 2, "legs": [7, 12, 6, 11], "tail": 3,
					"fork": "rest", "eyes": "shut", "nose": 1}
			return {"bob": 0, "lean": 1, "head_up": -1, "legs": [6, 13, 7, 12], "tail": 0,
				"fork": "rest", "eyes": "shut", "mouth": 1, "squash": true}
	return {"bob": 0, "legs": [7, 12, 6, 11], "tail": 0, "fork": "carry"}


static func sq_pose(v: int, pose: String, f: int) -> Image:
	match pose:
		"trip":
			return _sq_trip(v)
		"dead":
			return _sq_dead(v, f)
		"tumble":
			var h := _sq_draw(v, _sq_params("hit", 0))
			h.rotate_90(CLOCKWISE)
			return h
		"zap":
			return _sq_zap(v, f)
	return _sq_draw(v, _sq_params(pose, f))


static func _sq_leg(img: Image, x: int, top: int, lift: int, col: Color, foot: Color) -> void:
	var bottom := 13 - lift
	for y in range(top, bottom + 1):
		PA.px(img, x, y, col)
	PA.px(img, x + 1, bottom + 1 if lift == 0 else bottom, foot)


const _SQ_TAILS := [
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, 1), Vector2i(-3, 1), Vector2i(-4, 0), Vector2i(-4, -1), Vector2i(-3, -2)],
	[Vector2i(0, 0), Vector2i(-1, 1), Vector2i(-2, 1), Vector2i(-3, 1), Vector2i(-4, 1), Vector2i(-4, 0), Vector2i(-4, -1)],
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 1), Vector2i(-4, 2), Vector2i(-3, 3), Vector2i(-2, 3)],
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-2, -1), Vector2i(-3, -1), Vector2i(-4, -2), Vector2i(-4, -3), Vector2i(-3, -4)],
]


static func _sq_tail(img: Image, phase: int, base: Vector2i) -> void:
	var path: Array = _SQ_TAILS[phase % 4]
	for i in path.size():
		var o: Vector2i = path[i]
		var c := PA.col("q")
		if i == 0:
			c = PA.col("P")
		elif i == path.size() - 1:
			c = PA.col("q").lightened(0.25)
		PA.px(img, base.x + o.x, base.y + o.y, c)


static func _sq_draw(v: int, p: Dictionary) -> Image:
	var img := PA.new_img(SQ_W, SQ_H)
	var fur := _sq_fur(v)
	var dark := fur.darkened(0.3)
	var light := fur.lightened(0.24)
	var belly := fur.lightened(0.24).lerp(PA.col("q"), 0.1)
	var far := fur.darkened(0.48)
	var pink := PA.col("q")
	var bob: int = p.get("bob", 0)
	var lean: int = p.get("lean", 0)
	var hu: int = p.get("head_up", 0)
	var squash: bool = p.get("squash", false)
	var legs: Array = p.get("legs", [7, 12, 6, 11])
	var lift: Array = p.get("lift", [0, 0, 0, 0])
	var eyes: String = p.get("eyes", "open")
	var leg_top := 11 + bob
	# far-side legs (behind body)
	_sq_leg(img, legs[2], leg_top, lift[2], far, far)
	_sq_leg(img, legs[3], leg_top, lift[3], far, far)
	# tail
	_sq_tail(img, int(p.get("tail", 0)), Vector2i(5, 10 + bob))
	# body
	var bx := 9.5 + lean * 0.5
	var by := 9.2 + bob
	var rx := 5.4
	var ry := 3.2
	if squash:
		rx = 6.0
		ry = 2.6
		by += 0.6
	PA.ellipse(img, bx, by, rx, ry, fur)
	PA.ellipse(img, bx + 1.2, by + 1.4, rx - 2.2, ry - 1.7, belly)
	# hunched back highlight + fur tufts
	var top_y := int(roundf(by - ry + 0.4))
	for x in range(int(bx - 3.0), int(bx + 2.0)):
		PA.px(img, x, top_y, light)
	PA.px(img, int(bx) - 4, top_y + 1, light)
	PA.px(img, int(bx) - 2, top_y + 1, dark)
	PA.px(img, int(bx), top_y + 2, dark)
	PA.px(img, int(bx) - 4, int(by) + 1, dark)
	# underside shade
	for x in range(int(bx - 3.0), int(bx + 3.0)):
		PA.px(img, x, int(roundf(by + ry - 0.5)), dark)
	# near-side legs
	_sq_leg(img, legs[0], leg_top, lift[0], dark, pink)
	_sq_leg(img, legs[1], leg_top, lift[1], dark, pink)
	# head
	var hx := 15.0 + lean
	var hy := 7.6 + bob - hu
	if squash:
		hy += 0.8
	PA.disk(img, hx, hy, 2.8, fur)
	PA.ellipse(img, hx + 2.5, hy + 1.0, 2.0, 1.2, fur)                    # snout
	PA.px(img, int(hx) + 2, int(hy) + 2, belly)                              # chin
	PA.px(img, int(hx), int(hy) - 2, light)                                  # brow highlight
	PA.px(img, int(hx) + 1, int(hy) - 2, light)
	PA.px(img, int(hx) - 2, int(hy) + 1, dark)                               # cheek shade
	# ear
	var ex := int(hx) - 1
	var ey := int(hy) - 3
	PA.disk(img, ex + 0.5, ey + 0.8, 1.35, pink)
	PA.px(img, ex - 1, ey + 1, dark)
	PA.px(img, ex, ey, dark)
	PA.px(img, ex + 1, ey + 1, PA.col("P"))
	if v == 2:
		PA.px(img, ex, ey - 1, Color(0, 0, 0, 0))                            # ragged notch
		PA.px(img, ex + 1, ey - 1, Color(0, 0, 0, 0))
	# nose
	var nose := Vector2i(int(hx + 4.4), int(hy) + 1 - int(p.get("nose", 0)))
	PA.px(img, nose.x, nose.y, PA.col("p"))
	# eye
	var eye := Vector2i(int(hx) + 1, int(hy) - 1)
	match eyes:
		"shut":
			PA.px(img, eye.x - 1, eye.y, PA.col("k"))
			PA.px(img, eye.x, eye.y + 1, PA.col("k"))
		"squint":
			PA.px(img, eye.x, eye.y, PA.col("Z"))
			PA.px(img, eye.x - 1, eye.y - 1, dark)
		"angry":
			PA.px(img, eye.x, eye.y, PA.col("z"))
			PA.px(img, eye.x, eye.y + 1, PA.col("Z"))
			PA.px(img, eye.x - 1, eye.y - 1, PA.col("k"))
			PA.px(img, eye.x, eye.y - 1, PA.col("k"))
		_:
			PA.px(img, eye.x, eye.y, PA.col("z"))
			PA.px(img, eye.x, eye.y + 1, PA.col("Z"))
	# whiskers
	var wk: int = p.get("whisk", 0)
	PA.px(img, nose.x + 1, nose.y - 1 - wk, PA.col("W"))
	PA.px(img, nose.x + 1, nose.y + 1, PA.col("W"))
	# mouth / buck teeth
	if int(p.get("mouth", 0)) == 1:
		PA.px(img, nose.x - 1, nose.y + 1, PA.col("K"))
		PA.px(img, nose.x - 1, nose.y + 2, PA.col("w"))
		PA.px(img, nose.x - 2, nose.y + 2, PA.col("K"))
	else:
		PA.px(img, nose.x - 1, nose.y + 1, PA.col("w"))
	# variant markings
	match v:
		1:
			# eyepatch + strap
			PA.px(img, eye.x, eye.y, PA.col("k"))
			PA.px(img, eye.x, eye.y + 1, PA.col("k"))
			PA.px(img, eye.x + 1, eye.y, PA.col("k"))
			PA.line(img, eye.x - 1, eye.y - 1, eye.x - 3, eye.y + 1, PA.col("K"))
		2:
			# scar slash across the snout
			PA.px(img, eye.x + 1, eye.y - 1, PA.col("P"))
			PA.px(img, eye.x + 2, eye.y, PA.col("P"))
			PA.px(img, eye.x + 3, eye.y + 1, PA.col("P"))
		3:
			# red bandana with fluttering knot tails
			var by2 := int(hy) - 2
			for xx in range(int(hx) - 2, int(hx) + 2):
				PA.px(img, xx, by2, PA.col("r"))
			PA.px(img, int(hx) - 1, by2 - 1, PA.col("r"))
			PA.px(img, int(hx), by2 - 1, PA.col("r").lightened(0.25))
			var flap := int(p.get("tail", 0)) % 2
			PA.px(img, int(hx) - 3, by2 + flap, PA.col("R"))
			PA.px(img, int(hx) - 4, by2 + 1 - flap, PA.col("R"))
			PA.px(img, int(hx) - 3, by2 + 1, PA.col("r"))
	# bent fork in the front paw
	_sq_fork(img, String(p.get("fork", "carry")), bob, lean, int(p.get("tail", 0)))
	return PA.outline(img)


static func _sq_fork(img: Image, mode: String, bob: int, lean: int, _ph: int) -> void:
	var w := PA.col("W")
	var g := PA.col("g")
	var paw := PA.col("q")
	match mode:
		"carry":
			# held low and forward, top prong comically bent upwards
			var y := 12 + bob
			PA.px(img, 13 + lean, y, paw)
			for x in range(14, 17):
				PA.px(img, x + lean, y, w)
			PA.px(img, 17 + lean, y - 1, g)
			PA.px(img, 18 + lean, y - 1, w)
			PA.px(img, 19 + lean, y - 2, w)
			PA.px(img, 19 + lean, y - 3, w)
			PA.px(img, 19 + lean, y, w)
			PA.px(img, 20 + lean, y, w)
		"rest":
			# fork tip resting on the ground
			var y2 := 12 + bob
			PA.px(img, 13 + lean, y2, paw)
			PA.px(img, 14 + lean, y2, w)
			PA.px(img, 15 + lean, y2 + 1, w)
			PA.px(img, 16 + lean, y2 + 1, g)
			PA.px(img, 17 + lean, y2 + 1, w)
			PA.px(img, 17 + lean, y2, w)
		"raise":
			PA.px(img, 12 + lean, 10 + bob, paw)
			PA.px(img, 13 + lean, 9 + bob, w)
			PA.px(img, 14 + lean, 8 + bob, w)
			PA.px(img, 15 + lean, 7 + bob, g)
			PA.px(img, 15 + lean, 5 + bob, w)
			PA.px(img, 16 + lean, 6 + bob, w)
			PA.px(img, 16 + lean, 4 + bob, w)
		"jab":
			# full-length stab (ignores lean so it stays inside the canvas)
			PA.px(img, 14, 11 + bob, paw)
			for x in range(15, 18):
				PA.px(img, x, 11 + bob, w)
			PA.px(img, 18, 11 + bob, g)
			PA.px(img, 19, 10 + bob, w)
			PA.px(img, 20, 10 + bob, w)
			PA.px(img, 19, 12 + bob, w)
			PA.px(img, 20, 12 + bob, w)


static func _sq_trip(v: int) -> Image:
	# faceplant: rump up, nose in the dirt, legs flailing, fork flung ahead
	var img := PA.new_img(SQ_W, SQ_H)
	var fur := _sq_fur(v)
	var dark := fur.darkened(0.3)
	var light := fur.lightened(0.24)
	var pink := PA.col("q")
	# tail sticking straight up
	PA.line(img, 5, 8, 3, 3, pink)
	PA.px(img, 4, 2, PA.col("q").lightened(0.25))
	# hind legs kicking in the air
	PA.line(img, 7, 7, 6, 4, dark)
	PA.line(img, 9, 7, 10, 4, dark)
	PA.px(img, 6, 3, pink)
	PA.px(img, 11, 4, pink)
	# tilted body (rump high)
	for i in 6:
		PA.disk(img, 7.0 + i * 1.4, 8.5 + i * 0.7, 3.0 - i * 0.12, fur)
	PA.px(img, 7, 6, light)
	PA.px(img, 8, 6, light)
	# squashed face on the ground
	PA.ellipse(img, 15.5, 12.5, 3.0, 1.8, fur)
	PA.px(img, 18, 13, PA.col("p"))
	PA.px(img, 15, 12, PA.col("k"))
	PA.px(img, 16, 13, PA.col("k"))
	PA.px(img, 14, 10, pink)
	PA.px(img, 13, 10, PA.col("P"))
	# front paws splayed
	PA.px(img, 12, 14, dark)
	PA.px(img, 19, 14, dark)
	# fork flung ahead
	PA.px(img, 19, 5, PA.col("W"))
	PA.px(img, 20, 4, PA.col("W"))
	PA.px(img, 18, 6, PA.col("g"))
	if v == 3:
		PA.px(img, 16, 11, PA.col("r"))
		PA.px(img, 17, 11, PA.col("r"))
	return PA.outline(img)


static func _sq_dead(v: int, f: int) -> Image:
	# belly-up, X-eyes, tongue out, little legs twitching skyward
	var img := PA.new_img(SQ_W, SQ_H)
	var fur := _sq_fur(v)
	var dark := fur.darkened(0.3)
	var belly := fur.lightened(0.34).lerp(PA.col("q"), 0.12)
	var pink := PA.col("q")
	# limp tail
	PA.line(img, 4, 12, 1, 13, pink)
	PA.px(img, 1, 12, pink)
	# legs up (twitch on frame 1)
	var t := f % 2
	for lx in [7, 9, 12, 14]:
		var top := 6 if (lx + t) % 3 != 0 else 7
		for y in range(top, 10):
			PA.px(img, lx, y, dark)
		PA.px(img, lx, top - 1, pink)
	# body on its back
	PA.ellipse(img, 10.5, 11.2, 5.4, 2.8, fur)
	PA.ellipse(img, 10.5, 10.4, 4.0, 1.6, belly)
	for x in range(6, 15):
		PA.px(img, x, 13, dark)
	# head upside down
	PA.disk(img, 16.5, 11.5, 2.6, fur)
	PA.ellipse(img, 19.0, 12.2, 1.6, 1.1, fur)
	PA.px(img, 20, 12, PA.col("p"))
	# X eyes
	PA.px(img, 16, 11, PA.col("k"))
	PA.px(img, 17, 12, PA.col("k"))
	PA.px(img, 17, 11, PA.col("k"))
	PA.px(img, 16, 12, PA.col("k"))
	# tongue
	PA.px(img, 18, 14, PA.col("p"))
	PA.px(img, 18, 13, PA.col("P"))
	# ear flopped
	PA.px(img, 15, 14, pink)
	if v == 3:
		PA.px(img, 17, 9, PA.col("r"))
		PA.px(img, 16, 9, PA.col("r"))
	elif v == 1:
		PA.px(img, 16, 11, PA.col("K"))
	return PA.outline(img)


static func _sq_zap(v: int, f: int) -> Image:
	# electrocuted x-ray: dark silhouette with a bright skeleton (inverted on frame 1)
	var base := _sq_draw(v, _sq_params("hit", 0))
	var w := base.get_width()
	var h := base.get_height()
	var sil := PA.col("n") if f % 2 == 0 else PA.col("u").lightened(0.4)
	var bone := PA.col("w") if f % 2 == 0 else PA.col("n")
	for y in h:
		for x in w:
			var p := base.get_pixel(x, y)
			if p.a > 0.5 and p != PA.col("k"):
				base.set_pixel(x, y, sil)
	# skeleton: spine, ribs, skull, leg bones, tail bone
	PA.line(base, 5, 9, 12, 9, bone)
	for rx in [7, 9, 11]:
		PA.px(base, rx, 8, bone)
		PA.px(base, rx, 10, bone)
	PA.ring(base, 14.0, 8.5, 2.6, 1.0, bone)
	PA.px(base, 14, 8, PA.col("k"))
	PA.px(base, 17, 9, bone)
	PA.px(base, 18, 9, bone)
	for lx in [6, 12]:
		PA.line(base, lx, 11, lx, 13, bone)
	PA.line(base, 4, 10, 1, 12, bone)
	return base


static func sq_ghost(f: int) -> Image:
	var img := PA.new_img(18, 16)
	var body := Color(0.8, 1.0, 0.84, 0.72)
	var hi := Color(0.95, 1.0, 0.95, 0.85)
	var o := f % 2
	PA.ellipse(img, 8.0, 9.5, 4.6, 2.9, body)        # body
	PA.disk(img, 12.0, 7.0, 2.6, body)                # head
	PA.ellipse(img, 14.6, 7.9, 1.8, 1.0, body)        # snout
	PA.disk(img, 11.0, 4.3, 1.2, body)                # ear
	PA.px(img, 9, 7, hi)
	PA.px(img, 10, 7, hi)
	# wispy bottom instead of legs
	for x in range(4, 12):
		if (x + o) % 2 == 0:
			PA.px(img, x, 12, body)
	# curly spirit tail
	PA.px(img, 3, 10 - o, body)
	PA.px(img, 2, 9, body)
	PA.px(img, 2, 8 - o, body)
	PA.px(img, 3, 7, body)
	# hollow eyes + O mouth
	PA.px(img, 12, 6, PA.col("x"))
	PA.px(img, 13, 6, PA.col("x"))
	PA.px(img, 15, 9, PA.col("x"))
	# halo
	var halo := PA.col("y")
	for hx in range(10, 14):
		PA.px(img, hx, 1, halo)
	PA.px(img, 9, 2, halo)
	PA.px(img, 14, 2, halo)
	return PA.outline(img, Color(0.25, 0.6, 0.3, 0.6))


static func squeaker_ball(f: int) -> Image:
	var img := PA.new_img(14, 14)
	var fur := PA.col("m")
	PA.disk(img, 7, 7, 4.8, fur)
	PA.disk(img, 6.5, 7.5, 3.2, fur.darkened(0.2))
	PA.disk(img, 7.5, 6.5, 2.0, fur.lightened(0.15))
	# tail wrapped around + panicked eye
	if f % 2 == 0:
		PA.line(img, 3, 10, 6, 12, PA.col("q"))
		PA.px(img, 9, 5, PA.col("z"))
		PA.px(img, 10, 4, PA.col("q"))
	else:
		PA.line(img, 10, 3, 12, 6, PA.col("q"))
		PA.px(img, 5, 8, PA.col("z"))
		PA.px(img, 4, 9, PA.col("q"))
	PA.px(img, 7, 9, PA.col("w"))
	return PA.outline(img)


# ================================================================== JEZZAIL

## Loose pipe rifle (used when the team is shot apart).
static func jez_rifle() -> Image:
	var img := PA.new_img(28, 9)
	_jez_rifle_into(img, 1, 3, false)
	return PA.outline(img)


## Paints the rusty pipe rifle with its stock's top-left at (x, y). Barrel = 21px.
static func _jez_rifle_into(img: Image, x: int, y: int, glow: bool = true) -> void:
	# wooden stock with grain
	PA.rect(img, x, y + 1, 6, 3, PA.col("b"))
	PA.rect(img, x, y + 1, 6, 1, PA.col("t"))
	PA.px(img, x + 2, y + 2, PA.col("B"))
	PA.px(img, x + 4, y + 3, PA.col("B"))
	PA.px(img, x, y + 3, PA.col("B"))
	# trigger guard
	PA.px(img, x + 6, y + 3, PA.col("G"))
	PA.px(img, x + 7, y + 4, PA.col("G"))
	# rusty pipe barrel
	PA.rect(img, x + 6, y, 21, 2, PA.col("O"))
	PA.rect(img, x + 6, y + 1, 21, 1, PA.col("B").lightened(0.1))
	PA.rect(img, x + 6, y, 21, 1, PA.col("i").darkened(0.15))
	for rx in [8, 12, 17, 22]:
		PA.px(img, x + rx, y, PA.col("i"))
		PA.px(img, x + rx + 1, y + 1, PA.col("O").darkened(0.3))
	# pipe clamps
	for cx in [10, 16]:
		PA.rect(img, x + cx, y - 1, 1, 4, PA.col("g"))
		PA.px(img, x + cx, y - 1, PA.col("W"))
	# flared muzzle
	PA.rect(img, x + 26, y - 1, 2, 4, PA.col("G"))
	PA.px(img, x + 26, y - 1, PA.col("W"))
	# warp-cheese power cell in a glass tube
	PA.rect(img, x + 11, y - 3, 5, 3, PA.col("a").darkened(0.2))
	PA.rect(img, x + 12, y - 3, 3, 2, PA.col("Z") if glow else PA.col("x"))
	if glow:
		PA.px(img, x + 12, y - 3, PA.col("z"))
		PA.px(img, x + 13, y - 2, PA.col("z"))
	PA.px(img, x + 11, y - 4, PA.col("G"))
	PA.px(img, x + 15, y - 4, PA.col("G"))


static func _jez_rat(img: Image, cx: float, cy: float, head: Vector2, crouch: bool, eyes: String, fur: Color) -> void:
	var dark := fur.darkened(0.3)
	var light := fur.lightened(0.22)
	var pink := PA.col("q")
	if crouch:
		PA.ellipse(img, cx, cy, 4.2, 2.6, fur)
		PA.ellipse(img, cx + 0.5, cy + 1.0, 2.6, 1.2, fur.lightened(0.2))
	else:
		PA.ellipse(img, cx, cy, 3.6, 3.4, fur)
		PA.ellipse(img, cx + 0.8, cy + 1.0, 2.0, 2.0, fur.lightened(0.2))
	PA.px(img, int(cx) - 1, int(cy - 2.5), light)
	PA.px(img, int(cx), int(cy - 2.5), light)
	PA.px(img, int(cx) - 2, int(cy + 1), dark)
	# head
	PA.disk(img, head.x, head.y, 2.4, fur)
	PA.ellipse(img, head.x + 2.2, head.y + 0.7, 1.6, 1.0, fur)
	PA.px(img, int(head.x + 3.8), int(head.y) + 1, PA.col("p"))
	PA.px(img, int(head.x + 4.6), int(head.y), PA.col("W"))
	PA.disk(img, head.x - 1.4, head.y - 2.6, 1.2, pink)
	PA.px(img, int(head.x) - 2, int(head.y) - 3, dark)
	var e := Vector2i(int(head.x) + 1, int(head.y) - 1)
	match eyes:
		"shut":
			PA.px(img, e.x - 1, e.y, PA.col("k"))
			PA.px(img, e.x, e.y, PA.col("k"))
		"x":
			PA.px(img, e.x, e.y, PA.col("k"))
			PA.px(img, e.x - 1, e.y - 1, PA.col("k"))
			PA.px(img, e.x + 1, e.y + 1, PA.col("k"))
		_:
			PA.px(img, e.x, e.y, PA.col("z"))


## Two-rat sniper team. pose: walk 0-3 | aim | recoil | fumble 0-1 | dead.
## Muzzle at image (31, 7) -> local (14, -10) for walk/aim frames.
static func jezzail(pose: String, f: int) -> Image:
	var img := PA.new_img(34, 18)
	var fur := PA.col("m")
	var dark := fur.darkened(0.3)
	var pink := PA.col("q")
	if pose == "dead":
		# both rats belly-up, rifle dropped across them, power cell dark
		for rx in [7, 20]:
			PA.ellipse(img, rx, 13.5, 4.4, 2.2, fur)
			PA.ellipse(img, rx, 12.8, 3.0, 1.2, fur.lightened(0.24))
			for lx in [rx - 3, rx - 1, rx + 1, rx + 3]:
				PA.px(img, lx, 10, dark)
				PA.px(img, lx, 9, pink)
			PA.disk(img, rx + 5, 13.5, 2.2, fur)
			PA.px(img, rx + 5, 13, PA.col("k"))
			PA.px(img, rx + 6, 14, PA.col("k"))
			PA.px(img, rx + 6, 13, PA.col("k"))
			PA.px(img, rx + 5, 14, PA.col("k"))
			PA.px(img, rx + 7, 15, PA.col("p"))
		PA.line(img, 1, 14, 3, 15, pink)
		_jez_rifle_into(img, 3, 9, false)
		return PA.outline(img)
	var step := f % 4
	var gun_bob := 0
	var pod_bob := 0
	var dx := 0
	var g_head := Vector2(10.5, 4.4)
	var p_head := Vector2(25, 10.5)
	var g_eyes := "open"
	var p_eyes := "open"
	var legs_g := [5, 9]
	var legs_p := [18, 23]
	match pose:
		"walk":
			gun_bob = -1 if step == 1 else 0
			pod_bob = -1 if step == 3 else 0
			match step:
				0:
					legs_g = [5, 9]
					legs_p = [17, 23]
				1:
					legs_g = [6, 8]
					legs_p = [18, 22]
				2:
					legs_g = [7, 8]
					legs_p = [19, 21]
				_:
					legs_g = [6, 9]
					legs_p = [18, 22]
		"aim":
			gun_bob = 1
			g_eyes = "shut"
			p_eyes = "shut"
			legs_p = [16, 24]
		"recoil":
			dx = -2
			g_head = Vector2(9.0, 4.4)
			g_eyes = "shut"
			p_eyes = "shut"
			pod_bob = 1
		"fumble":
			g_head = Vector2(12.0, 5.4) if f % 2 == 0 else Vector2(11.5, 4.4)
			legs_g = [6, 9] if f % 2 == 0 else [5, 9]
	# tails
	PA.line(img, 1 + dx, 7 + gun_bob, 4 + dx, 10 + gun_bob, pink)
	PA.px(img, 1 + dx, 6 + gun_bob, pink.lightened(0.25))
	PA.line(img, 14, 13 + pod_bob, 16, 12 + pod_bob, pink)
	# legs
	for lx in legs_g:
		PA.rect(img, lx + dx, 13 + gun_bob, 1, 2 - gun_bob, dark)
		PA.px(img, lx + dx + 1, 15, pink)
	for lx in legs_p:
		PA.rect(img, lx, 13 + pod_bob, 1, 2 - pod_bob, dark)
		PA.px(img, lx + 1, 15, pink)
	# bipod rat (crouched, barrel resting on its shoulders)
	_jez_rat(img, 20.5, 11.0 + pod_bob, p_head + Vector2(0, pod_bob), true, p_eyes, fur)
	PA.px(img, 22, 10 + pod_bob, PA.col("u"))       # sweat drop
	# gunner rat (upright behind the stock)
	_jez_rat(img, 7.5 + dx, 10.5 + gun_bob, g_head + Vector2(dx, gun_bob), false, g_eyes, fur)
	# leather bandolier
	PA.line(img, 5 + dx, 10 + gun_bob, 8 + dx, 13 + gun_bob, PA.col("B"))
	PA.px(img, 6 + dx, 11 + gun_bob, PA.col("y"))
	# brass monocle-scope on the gunner
	var gx := int(g_head.x) + dx
	var gy := int(g_head.y) + gun_bob
	PA.px(img, gx + 2, gy - 1, PA.col("Y"))
	PA.px(img, gx + 1, gy - 2, PA.col("Y"))
	PA.px(img, gx, gy - 1, PA.col("Y"))
	# the rifle
	var ry := 7
	var rx := 3 + dx
	if pose == "recoil":
		ry = 6
	_jez_rifle_into(img, rx, ry + (0 if pose != "walk" else mini(gun_bob, pod_bob)))
	# paws
	PA.px(img, 10 + dx, 10 + gun_bob, pink)
	PA.px(img, 24, 9 + pod_bob, pink)
	if pose == "fumble":
		# frantic ramrod down the barrel
		var rod_y := 4 if f % 2 == 0 else 2
		PA.line(img, gx + 2, gy + 2, 30, rod_y, PA.col("W"))
		PA.px(img, 31, rod_y - 1, PA.col("g"))
	return PA.outline(img)


# ================================================================== PLAGUE-STINK MONK

## Flail hand per pose/frame (image coords in the 20x22 canvas; local = image - (10, 21)).
const MONK_HAND := {
	"walk_0": Vector2i(14, 12), "walk_1": Vector2i(14, 11), "walk_2": Vector2i(14, 12), "walk_3": Vector2i(14, 11),
	"chant_0": Vector2i(15, 9), "chant_1": Vector2i(15, 8),
}


static func monk(pose: String, f: int) -> Image:
	var img := PA.new_img(20, 22)
	var robe := PA.col("b")
	var robe_dk := PA.col("B")
	var robe_lt := PA.col("b").lightened(0.18)
	var pink := PA.col("q")
	if pose == "dead":
		# empty robe crumpled in a heap, hood flat, tail poking out
		PA.ellipse(img, 10, 18, 7.5, 2.8, robe)
		PA.ellipse(img, 9, 17, 5.0, 1.8, robe_lt)
		PA.disk(img, 15, 16.5, 2.6, robe)
		PA.disk(img, 16, 17, 1.4, PA.col("k"))
		PA.px(img, 16, 17, PA.col("x"))
		PA.rect(img, 6, 18, 6, 1, PA.col("c"))
		PA.line(img, 2, 19, 0, 17, pink)
		PA.px(img, 5, 19, PA.col("x"))
		PA.px(img, 12, 19, PA.col("Z"))
		return PA.outline(img)
	var step := f % 4
	var bob := -1 if (pose == "walk" and step % 2 == 1) else 0
	var sway := 0
	if pose == "walk":
		sway = [0, 1, 0, -1][step]
	# tail poking out from under the robe
	PA.line(img, 2, 18 + bob, 4, 19 + bob, pink)
	PA.px(img, 1, 17 + bob, pink.lightened(0.2))
	# feet peeking out (alternate)
	if pose == "walk":
		PA.px(img, 7 + (1 if step < 2 else 0), 20, PA.col("M"))
		PA.px(img, 12 - (1 if step >= 2 else 0), 20, PA.col("M"))
	else:
		PA.px(img, 7, 20, PA.col("M"))
		PA.px(img, 12, 20, PA.col("M"))
	# robe body (widening towards the hem, hem sways)
	for y in range(7, 20):
		var t := float(y - 7) / 12.0
		var hw := lerpf(3.2, 6.0, t)
		var shift := int(roundf(sway * t))
		for x in range(int(9.5 - hw) + shift, int(9.5 + hw) + 1 + shift):
			var c := robe
			if x >= int(9.5 + hw) - 1 + shift:
				c = robe_dk
			elif x <= int(9.5 - hw) + 1 + shift:
				c = robe_lt
			PA.px(img, x, y + bob, c)
	# tattered hem
	for x in range(3, 17):
		if (x + step) % 3 == 0:
			PA.px(img, x + sway, 19 + bob, Color(0, 0, 0, 0))
		elif (x + step) % 3 == 1:
			PA.px(img, x + sway, 20 + bob, robe_dk)
	# patches, stitches and mould
	PA.rect(img, 6, 14 + bob, 2, 2, PA.col("t"))
	PA.px(img, 6, 14 + bob, PA.col("T"))
	PA.px(img, 12, 16 + bob, PA.col("x"))
	PA.px(img, 13, 17 + bob, PA.col("Z"))
	PA.px(img, 8, 17 + bob, PA.col("x"))
	# rope belt, knot and a little brass bell
	PA.rect(img, 5, 12 + bob, 10, 1, PA.col("c"))
	PA.px(img, 7, 13 + bob, PA.col("c"))
	PA.px(img, 7, 14 + bob, PA.col("t"))
	PA.px(img, 8, 15 + bob, PA.col("y"))
	# hood with a drooping tip
	var hx := 9.5
	var hy := 5.5 + bob
	if pose == "chant":
		hy -= 1
	PA.disk(img, hx, hy, 4.0, robe)
	PA.px(img, int(hx) - 3, int(hy) - 3, robe)
	PA.px(img, int(hx) - 4, int(hy) - 3, robe_dk)
	PA.px(img, int(hx) - 5, int(hy) - 2, robe_dk)
	PA.px(img, int(hx) - 1, int(hy) - 4, robe_lt)
	# shadowed opening, glowing eye, snout + whiskers poking out
	PA.disk(img, hx + 2.2, hy + 0.6, 2.0, PA.col("k"))
	PA.px(img, int(hx) + 2, int(hy), PA.col("z"))
	PA.px(img, int(hx) + 3, int(hy), PA.col("Z") if f % 2 == 0 else PA.col("x"))
	PA.px(img, int(hx) + 4, int(hy) + 1, PA.col("m"))
	PA.px(img, int(hx) + 5, int(hy) + 1, PA.col("p"))
	PA.px(img, int(hx) + 5, int(hy) + 2, PA.col("W"))
	# sleeve + paw (chant: raised)
	var hand: Vector2i = MONK_HAND.get("%s_%d" % [pose, f], Vector2i(14, 12))
	if pose == "chant":
		PA.line(img, 12, 9 + bob, hand.x - 1, hand.y, robe_dk)
	else:
		PA.rect(img, 11, 9 + bob, 3, 2, robe_dk)
	PA.px(img, hand.x, hand.y, pink)
	# trailing stink lines
	PA.px(img, 3, 9 + bob + (step % 2), Color(0.67, 1.0, 0.4, 0.8))
	PA.px(img, 2, 7 + bob - (step % 2), Color(0.67, 1.0, 0.4, 0.6))
	return PA.outline(img)


static func monk_ghost(f: int) -> Image:
	var img := PA.new_img(16, 18)
	var body := Color(0.8, 1.0, 0.84, 0.72)
	var o := f % 2
	PA.disk(img, 8, 6, 4.0, body)
	PA.ellipse(img, 8, 11, 4.4, 4.0, body)
	for x in range(4, 13):
		if (x + o) % 2 == 0:
			PA.px(img, x, 15, body)
	PA.px(img, 4, 3, body)
	PA.px(img, 3, 4, body)
	PA.disk(img, 9.5, 6.5, 1.8, Color(0.2, 0.45, 0.25, 0.8))
	PA.px(img, 9, 6, PA.col("z"))
	for hx in range(6, 11):
		PA.px(img, hx, 0, PA.col("y"))
	return PA.outline(img, Color(0.25, 0.6, 0.3, 0.6))


# ================================================================== DOOM-ROOMBA

## Spiked robot vacuum. f 0-3: spikes spin around the rim, status light blinks, rider bobs.
## Coil tops at image (6,4)/(20,4) -> local (-7,-15)/(7,-15).
static func roomba(f: int) -> Image:
	var img := PA.new_img(26, 20)
	var cx := 13.0
	var spin := float(f % 4) * TAU / 48.0
	# spikes behind the shell (back half)
	for i in 12:
		var a := TAU * i / 12.0 + spin
		if sin(a) >= 0.0:
			continue
		var p := Vector2(cx + cos(a) * 12.2, 12.5 + sin(a) * 6.2)
		PA.px(img, int(roundf(p.x)), int(roundf(p.y)), PA.col("g"))
	# side skirt, shell, top plate and dome
	PA.ellipse(img, cx, 13.6, 10.6, 5.0, PA.col("K"))
	PA.ellipse(img, cx, 12.2, 10.6, 5.0, PA.col("G"))
	PA.ellipse(img, cx, 11.6, 9.0, 3.8, PA.col("g"))
	PA.ellipse(img, cx - 1.0, 10.8, 6.0, 2.2, PA.col("W"))
	PA.ellipse(img, cx, 11.2, 4.4, 1.9, PA.col("G"))
	# rim sheen sweeps around with the spin
	var sheen := int(f % 4) * 3
	PA.px(img, 6 + sheen, 9, PA.col("w"))
	PA.px(img, 7 + sheen, 9, PA.col("W"))
	# vent slots + dust bin
	for vx in [5, 7, 19, 21]:
		PA.px(img, vx, 13, PA.col("k"))
	PA.rect(img, 10, 15, 6, 1, PA.col("Z").darkened(0.4))
	# evil status light
	var lit := f % 2 == 0
	PA.px(img, int(cx), 11, PA.col("z") if lit else PA.col("x"))
	PA.px(img, int(cx) + 1, 11, PA.col("Z") if lit else PA.col("x"))
	# front bumper
	for x in range(5, 22):
		PA.px(img, x, 16, PA.col("k"))
	PA.px(img, 21, 13, PA.col("W"))
	PA.px(img, 22, 12, PA.col("W"))
	# spikes in front (front half)
	for i in 12:
		var a := TAU * i / 12.0 + spin
		if sin(a) < 0.0:
			continue
		var p := Vector2(cx + cos(a) * 11.6, 12.5 + sin(a) * 5.9)
		PA.px(img, int(roundf(p.x)), int(roundf(p.y)), PA.col("W"))
		var p2 := Vector2(cx + cos(a) * 12.8, 12.5 + sin(a) * 6.8)
		PA.px(img, int(roundf(p2.x)), int(roundf(p2.y)), PA.col("g"))
	# warp coils (copper windings, glowing tips)
	for coil_x in [6, 20]:
		PA.rect(img, coil_x - 1, 6, 3, 5, PA.col("O"))
		PA.px(img, coil_x - 1, 7, PA.col("Y"))
		PA.px(img, coil_x + 1, 9, PA.col("Y"))
		PA.px(img, coil_x, 8, PA.col("i"))
		PA.px(img, coil_x, 5, PA.col("z"))
		PA.px(img, coil_x, 4, PA.col("Z") if lit else PA.col("z"))
	# tiny rat rider in goggles with a fluttering scarf
	var rb := 1 if f % 2 == 1 else 0
	PA.disk(img, 13, 7.5 + rb, 2.0, PA.col("m"))
	PA.disk(img, 14.5, 5.5 + rb, 1.6, PA.col("m"))
	PA.px(img, 13, 3 + rb, PA.col("q"))
	PA.px(img, 15, 5 + rb, PA.col("u"))
	PA.px(img, 16, 5 + rb, PA.col("a"))
	PA.px(img, 16, 6 + rb, PA.col("p"))
	PA.px(img, 12, 6 + rb, PA.col("r"))
	PA.px(img, 11, 6 + rb + (f % 2), PA.col("r"))
	PA.px(img, 10, 7 - (f % 2), PA.col("R"))
	PA.line(img, 11, 9, 9, 11, PA.col("q"))      # tail draped over
	PA.px(img, 15, 8, PA.col("B"))               # joystick
	PA.px(img, 15, 7, PA.col("r"))
	return PA.outline(img)


static func roomba_wreck() -> Image:
	var img := PA.new_img(26, 20)
	var cx := 13.0
	PA.ellipse(img, cx, 14.0, 10.6, 4.6, PA.col("K"))
	PA.ellipse(img, cx, 13.0, 10.0, 4.2, PA.col("G").darkened(0.2))
	PA.ellipse(img, cx - 2.0, 12.0, 5.0, 2.0, PA.col("g").darkened(0.25))
	# cracked open lid, exposed wiring
	PA.line(img, 8, 10, 12, 13, PA.col("k"))
	PA.line(img, 12, 13, 15, 11, PA.col("k"))
	PA.px(img, 14, 12, PA.col("r"))
	PA.px(img, 16, 13, PA.col("y"))
	PA.px(img, 11, 12, PA.col("Z"))
	# bent coil + scattered spikes
	PA.line(img, 6, 11, 4, 7, PA.col("O"))
	PA.px(img, 4, 6, PA.col("x"))
	PA.line(img, 20, 11, 22, 9, PA.col("O"))
	for sp in [Vector2i(2, 15), Vector2i(24, 14), Vector2i(7, 17), Vector2i(19, 17)]:
		PA.px(img, sp.x, sp.y, PA.col("W"))
	PA.px(img, int(cx), 12, PA.col("x"))
	return PA.outline(img)


# ================================================================== RAT-OGRE

## Rat-Ogre Bruiser (38x36). pose: walk 0-3 | windup | smash | throw | hurt | dead | fall 0-2.
static func ogre(pose: String, f: int) -> Image:
	if pose == "fall":
		var src := _ogre_body("hurt", 0)
		var angles: Array = [0.45, 0.95, PI / 2.0]
		var ang: float = angles[clampi(f, 0, 2)]
		return rotate_about(src, Vector2(19, 33), -ang, 64)
	if pose == "dead":
		var lying := _ogre_body("hurt", 0)
		var out := rotate_about(lying, Vector2(19, 33), -PI / 2.0, 64)
		# X-eyes + lolling tongue on the toppled head (head ends up on the left, low)
		return out
	return _ogre_body(pose, f)


static func _ogre_body(pose: String, f: int) -> Image:
	var img := PA.new_img(38, 36)
	var fur := PA.col("m")
	var dark := PA.col("M")
	var light := fur.lightened(0.18)
	var belly := fur.lightened(0.22)
	var step := f % 4
	var bob := 0
	var lstep := 0     # left leg lift
	var rstep := 0
	var lx := 0        # left / right foot fore-aft shift
	var rx := 0
	var swing := 0
	match pose:
		"walk":
			bob = 1 if step % 2 == 1 else 0
			lstep = 2 if step == 0 else 0
			rstep = 2 if step == 2 else 0
			lx = [1, 0, -1, 0][step]
			rx = -lx
			swing = [-2, 0, 2, 0][step]
		"smash":
			bob = 2
		"hurt":
			bob = 1
	# thick tail
	PA.line(img, 6, 25 + bob, 2, 28 + bob, PA.col("q"))
	PA.line(img, 6, 26 + bob, 2, 29 + bob, PA.col("q"))
	PA.line(img, 2, 29 + bob, 1, 32, PA.col("q"))
	PA.px(img, 4, 27 + bob, PA.col("P"))
	# stumpy legs with wrapped feet
	PA.rect(img, 10 + lx, 25 + bob, 6, 6 - lstep - bob, dark)
	PA.rect(img, 19 + rx, 25 + bob, 6, 6 - rstep - bob, dark)
	PA.rect(img, 9 + lx, 31 - lstep, 8, 2, PA.col("k"))
	PA.rect(img, 18 + rx, 31 - rstep, 8, 2, PA.col("k"))
	PA.px(img, 11 + lx, 30 - lstep, PA.col("W"))
	PA.px(img, 13 + lx, 30 - lstep, PA.col("W"))
	PA.px(img, 20 + rx, 30 - rstep, PA.col("W"))
	PA.px(img, 22 + rx, 30 - rstep, PA.col("W"))
	# back arm (behind the body) for walk poses
	if pose == "walk" or pose == "hurt":
		PA.line(img, 9, 13 + bob, 6, 24 + swing + bob, dark)
		PA.line(img, 10, 13 + bob, 7, 24 + swing + bob, dark)
		PA.line(img, 11, 14 + bob, 8, 24 + swing + bob, dark)
	# hunched torso + hump
	PA.ellipse(img, 16, 19 + bob, 10.0, 8.5, fur)
	PA.disk(img, 11, 12 + bob, 6.0, fur)
	PA.ellipse(img, 19, 21 + bob, 5.5, 4.6, belly)
	PA.rect(img, 9, 26 + bob, 15, 1, dark)
	# fur texture strokes + muscle shading
	for st in [Vector2i(8, 17), Vector2i(12, 20), Vector2i(7, 21), Vector2i(14, 13), Vector2i(23, 19)]:
		PA.px(img, st.x, st.y + bob, dark)
		PA.px(img, st.x + 1, st.y + 1 + bob, dark)
	PA.px(img, 13, 9 + bob, light)
	PA.px(img, 14, 10 + bob, light)
	PA.px(img, 17, 12 + bob, light)
	# scrap-iron pauldron with rivets and rust
	PA.rect(img, 5, 8 + bob, 10, 4, PA.col("g"))
	PA.rect(img, 5, 8 + bob, 10, 1, PA.col("W"))
	PA.rect(img, 5, 11 + bob, 10, 1, PA.col("G"))
	PA.px(img, 6, 9 + bob, PA.col("k"))
	PA.px(img, 13, 9 + bob, PA.col("k"))
	PA.px(img, 9, 10 + bob, PA.col("i"))
	PA.px(img, 10, 10 + bob, PA.col("O"))
	# hubcap belly plate with spokes
	PA.disk(img, 18, 21 + bob, 3.4, PA.col("G"))
	PA.ring(img, 18, 21 + bob, 3.4, 1.0, PA.col("g"))
	PA.px(img, 18, 21 + bob, PA.col("W"))
	PA.px(img, 16, 20 + bob, PA.col("W"))
	PA.px(img, 18, 19 + bob, PA.col("g"))
	PA.px(img, 20, 21 + bob, PA.col("g"))
	PA.px(img, 18, 23 + bob, PA.col("g"))
	# chest stitches
	PA.line(img, 21, 12 + bob, 22, 17 + bob, PA.col("k"))
	for sy in [13, 15, 17]:
		PA.px(img, 20, sy + bob, PA.col("W"))
		PA.px(img, 23, sy - 1 + bob, PA.col("W"))
	PA.line(img, 8, 14 + bob, 13, 16 + bob, PA.col("k"))
	PA.px(img, 9, 13 + bob, PA.col("W"))
	PA.px(img, 11, 16 + bob, PA.col("W"))
	# head jutting forward, underbite snout
	var hx := 26
	var hy := 11 + bob
	if pose == "hurt":
		hx -= 1
		hy -= 1
	PA.disk(img, hx, hy, 4.8, fur)
	PA.ellipse(img, hx + 4.5, hy + 2, 3.4, 2.3, fur)
	PA.px(img, hx + 8, hy + 1, PA.col("p"))
	PA.px(img, hx + 7, hy + 1, PA.col("P"))
	PA.rect(img, hx + 1, hy + 3, 6, 1, PA.col("k"))
	PA.px(img, hx + 3, hy + 2, PA.col("w"))   # upward tusks
	PA.px(img, hx + 6, hy + 2, PA.col("w"))
	PA.rect(img, hx - 3, hy - 3, 6, 1, dark)   # heavy brow
	if pose == "hurt":
		PA.px(img, hx - 1, hy - 2, PA.col("k"))
		PA.px(img, hx, hy - 1, PA.col("k"))
		PA.px(img, hx + 1, hy - 2, PA.col("k"))
		PA.px(img, hx + 4, hy + 4, PA.col("p"))   # tongue
	else:
		PA.px(img, hx - 1, hy - 2, PA.col("z"))
		PA.px(img, hx + 1, hy - 2, PA.col("z"))
		PA.px(img, hx, hy - 2, PA.col("x"))
	PA.disk(img, hx - 4, hy - 5, 2.0, PA.col("q"))   # torn ear with a brass ring
	PA.px(img, hx - 4, hy - 6, PA.col("k"))
	PA.px(img, hx - 3, hy - 7, PA.col("k"))
	PA.px(img, hx - 5, hy - 3, PA.col("y"))
	# front arm + mitts
	match pose:
		"windup":
			PA.line(img, 12, 10, 9, 4, fur)
			PA.line(img, 13, 10, 10, 4, fur)
			PA.line(img, 26, 8, 29, 3, fur)
			PA.line(img, 27, 8, 30, 3, fur)
			_mitt(img, 9, 3)
			_mitt(img, 30, 2)
		"smash":
			PA.line(img, 23, 15 + bob, 30, 27, fur)
			PA.line(img, 24, 15 + bob, 31, 27, fur)
			PA.line(img, 12, 16 + bob, 8, 27, dark)
			_mitt(img, 32, 30)
			_mitt(img, 7, 30)
		"throw":
			# one arm cocked back overhead (squeaker drawn live in the mitt), other braced forward
			PA.line(img, 12, 10 + bob, 7, 3, fur)
			PA.line(img, 13, 10 + bob, 8, 3, fur)
			_mitt(img, 7, 3)
			PA.line(img, 24, 15 + bob, 30, 20 + bob, fur)
			_mitt(img, 31, 21 + bob)
		_:
			PA.line(img, 24, 15 + bob, 28, 24 - swing + bob, fur)
			PA.line(img, 25, 15 + bob, 29, 24 - swing + bob, fur)
			PA.line(img, 23, 16 + bob, 27, 24 - swing + bob, fur)
			_mitt(img, 7, 26 + swing + bob)
			_mitt(img, 29, 26 - swing + bob)
	return PA.outline(img)


## Gingham oven mitt (quilted cuff above), centred on (cx, cy).
static func _mitt(img: Image, cx: int, cy: int) -> void:
	PA.disk(img, cx, cy, 3.6, PA.col("r"))
	for yy in range(cy - 3, cy + 4):
		for xx in range(cx - 3, cx + 4):
			if xx < 0 or yy < 0 or xx >= img.get_width() or yy >= img.get_height():
				continue
			if (xx + yy) % 2 == 0 and img.get_pixel(xx, yy) == PA.col("r") and (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) < 8:
				img.set_pixel(xx, yy, PA.col("w"))
	PA.px(img, cx + 3, cy - 1, PA.col("r"))   # thumb
	PA.px(img, cx + 4, cy - 1, PA.col("R"))
	if cy - 5 >= 0:
		PA.rect(img, cx - 3, cy - 5, 7, 2, PA.col("W"))
		PA.px(img, cx - 2, cy - 5, PA.col("g"))
		PA.px(img, cx + 1, cy - 5, PA.col("g"))


static func flame(f: int) -> Image:
	var rows: Array
	match f % 3:
		0:
			rows = ["..I..", ".IyI.", ".iyi.", "iiyii", ".iri."]
		1:
			rows = [".I...", ".iI..", "iyIi.", "iyyi.", ".iri."]
		_:
			rows = ["...I.", "..Ii.", ".iIyi", ".iyyi", ".iri."]
	return PA.from_ascii(rows, 1)
