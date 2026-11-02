extends RefCounted
## Tower sprites (3/4 view, lit from the top-left). Heads that rotate are drawn pointing RIGHT
## around their centre. Level variants use a _1/_2/_3 suffix (level 1 also answers to the bare name).
## Names:
##   tower_base[_1..3]                 plank crate every tower sits on (L2 brackets, L3 gold trim)
##   tower_cracks_1 / _2               crack overlays for the crate (<50% / <25% HP)
##   tower_gatling_stem_<lvl>          sunflower stem + leaves (does not rotate)
##   tower_gatling_petals_<lvl>_<f>    sunflower bloom, f = 0..2 petal sway
##   tower_gatling_barrels_<lvl>_<f>   gatling barrel cluster, f = 0..2 spin
##   tower_gatling[_1..3]              legacy combined head (petals + barrels)
##   tower_laser_<lvl>_<f>             upside-down water bottle on a wire stand, f = 0..2 water slosh
##   tower_laser[_1..3]                = frame 0
##   tower_mortar[_1..3]               cardboard-tube mortar on a plank turntable + cedar sack
##   tower_tesla_coil[_1..3]           insulator stack, copper winding, torus rings, top ball
##   tesla_intern_<f>                  the hamster intern running the wheel, f = 0..3
##   tower_decoy[_1..3]                painted cardboard hamster cutout (googly eyes drawn live)
##   tower_decoy_<lvl>_d<1|2>          chewed-up decoy (bites taken out of the edges)
##   tower_debris_<0..3>               crate splinters flung out when a tower is destroyed
##   tower_rubble                      destroyed-tower debris (ground)
##   shell                             single sunflower hull (ground decal)

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	# explicit multi-part names first
	if n.begins_with("tower_gatling_stem_"):
		return gatling_stem(int(n.substr(19)))
	if n.begins_with("tower_gatling_petals_"):
		var p := n.substr(21).split("_")
		return gatling_petals(int(p[0]), int(p[1]) if p.size() > 1 else 0)
	if n.begins_with("tower_gatling_barrels_"):
		var p2 := n.substr(22).split("_")
		return gatling_barrels(int(p2[0]), int(p2[1]) if p2.size() > 1 else 0)
	if n.begins_with("tesla_intern_"):
		return tesla_intern(int(n.substr(13)))
	if n.begins_with("tower_debris_"):
		return debris(int(n.substr(13)))
	if n.begins_with("tower_cracks_"):
		return cracks(int(n.substr(13)))
	if n.begins_with("tower_decoy_") and n.substr(12).contains("_d"):
		var p3 := n.substr(12).split("_d")
		return decoy(int(p3[0]), int(p3[1]))
	if n.begins_with("tower_laser_") and n.substr(12).contains("_"):
		var p4 := n.substr(12).split("_")
		return laser(int(p4[0]), int(p4[1]))
	var lvl := 1
	var base_name := n
	var us := n.rfind("_")
	if us > 0 and n.substr(us + 1).is_valid_int():
		lvl = clampi(int(n.substr(us + 1)), 1, 3)
		base_name = n.substr(0, us)
	match base_name:
		"tower_base":
			return base(lvl)
		"tower_gatling":
			var img := gatling_petals(lvl, 0)
			PA.blit(img, gatling_barrels(lvl, 0), 0, 0)
			return img
		"tower_laser":
			return laser(lvl, 0)
		"tower_mortar":
			return mortar(lvl)
		"tower_tesla_coil":
			return tesla_coil(lvl)
		"tower_decoy":
			return decoy(lvl, 0)
	match n:
		"tower_rubble":
			return rubble()
		"shell":
			return shell()
	return null


# ------------------------------------------------------------------ helpers

## Rotated filled ellipse (rx along `ang`).
static func rot_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, ang: float, c: Color) -> void:
	var ca := cos(ang)
	var sa := sin(ang)
	var r := maxf(rx, ry) + 1.0
	for y in range(int(floorf(cy - r)), int(ceilf(cy + r)) + 1):
		for x in range(int(floorf(cx - r)), int(ceilf(cx + r)) + 1):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var u := dx * ca + dy * sa
			var v := -dx * sa + dy * ca
			if (u * u) / (rx * rx) + (v * v) / (ry * ry) <= 1.0:
				PA.px(img, x, y, c)


## Thick line made of disks (for tubes / stems).
static func stroke(img: Image, a: Vector2, b: Vector2, r: float, c: Color) -> void:
	var steps := maxi(2, int(a.distance_to(b) * 2.0))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		PA.disk(img, p.x, p.y, r, c)


static func _grain(img: Image, x0: int, y0: int, w: int, h: int, seed_v: int, c: Color) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	for i in int(w * h / 10):
		var x := r.randi_range(x0, x0 + w - 3)
		var y := r.randi_range(y0, y0 + h - 1)
		var l := r.randi_range(1, 3)
		for k in l:
			PA.px(img, x + k, y, c)


# ------------------------------------------------------------------ crate base

## 24x16 plank crate. Drawn at (-12, -9): top face y -8..-1, front face 0..5.
static func base(lvl: int = 1) -> Image:
	var img := PA.new_img(24, 16)
	var t := PA.col("t")
	var c := PA.col("c")
	var T := PA.col("T")
	var B := PA.col("B")
	var b := PA.col("b")
	# top face: three planks with dark gaps
	PA.rect(img, 1, 1, 22, 8, t)
	for gy in [3, 6]:
		PA.rect(img, 1, gy, 22, 1, B)
	for py in [1, 4, 7]:
		PA.rect(img, 1, py, 11, 1, c.lerp(t, 0.35))     # lit upper edge of each plank
	_grain(img, 2, 1, 20, 8, 11 + lvl, T)
	# knots
	PA.px(img, 15, 5, b)
	PA.px(img, 16, 5, B)
	PA.px(img, 6, 8, b)
	# lit left edge, shaded right edge
	PA.rect(img, 1, 1, 1, 8, c)
	PA.rect(img, 22, 1, 1, 8, T)
	# nails at plank ends
	for ny in [1, 4, 7]:
		PA.px(img, 3, ny, PA.col("W"))
		PA.px(img, 20, ny, PA.col("g"))
	# front face: vertical planks, darker, shadow under the lip
	PA.rect(img, 1, 9, 22, 6, T)
	PA.rect(img, 1, 9, 22, 1, B)
	for sx in [6, 12, 17]:
		PA.rect(img, sx, 10, 1, 5, B)
	PA.rect(img, 1, 10, 1, 5, t)
	PA.rect(img, 1, 14, 22, 1, B)
	PA.rect(img, 21, 10, 2, 4, T.darkened(0.15))
	# horizontal batten with nails
	PA.rect(img, 2, 12, 20, 1, b)
	PA.px(img, 4, 12, PA.col("g"))
	PA.px(img, 19, 12, PA.col("g"))
	_grain(img, 2, 10, 19, 4, 77 + lvl, b)
	if lvl >= 2:
		# riveted steel corner brackets (top + front)
		for x in [1, 20]:
			PA.rect(img, x, 9, 3, 6, PA.col("g"))
			PA.rect(img, x, 9, 3, 1, PA.col("W"))
			PA.px(img, x + 1, 11, PA.col("W"))
			PA.px(img, x + 1, 13, PA.col("G"))
		for x in [1, 20]:
			PA.rect(img, x, 1, 3, 2, PA.col("g"))
			PA.px(img, x + 1, 1, PA.col("W"))
	if lvl >= 3:
		# gold trim around the lid + a gold seed emblem with a ruby on the front
		PA.rect(img, 1, 1, 22, 1, PA.col("y"))
		PA.rect(img, 1, 8, 22, 1, PA.col("Y"))
		PA.rect(img, 10, 10, 4, 4, PA.col("Y"))
		PA.rect(img, 11, 10, 2, 4, PA.col("y"))
		PA.px(img, 11, 11, PA.col("s"))
		PA.px(img, 12, 12, PA.col("S"))
		PA.px(img, 12, 10, PA.col("r"))
	return PA.outline(img)


## Crack overlays for the crate (same 24x16 frame). 1 = cracked, 2 = splintered + chipped.
static func cracks(stage: int) -> Image:
	var img := PA.new_img(24, 16)
	var k := PA.col("K")
	var sp := PA.col("c")
	PA.line(img, 7, 2, 10, 5, k)
	PA.line(img, 10, 5, 9, 8, k)
	PA.px(img, 11, 4, sp)
	PA.line(img, 15, 10, 13, 13, k)
	PA.px(img, 16, 11, sp)
	if stage >= 2:
		PA.line(img, 16, 1, 19, 4, k)
		PA.line(img, 19, 4, 21, 4, k)
		PA.px(img, 17, 3, sp)
		PA.line(img, 4, 10, 6, 14, k)
		PA.px(img, 3, 11, sp)
		# chipped corner + splinters sticking out
		PA.rect(img, 1, 9, 3, 2, PA.col("B"))
		PA.px(img, 0, 8, PA.col("t"))
		PA.px(img, 22, 2, PA.col("t"))
		PA.px(img, 23, 1, PA.col("c"))
	return img


static func debris(i: int) -> Image:
	match i % 4:
		0:
			var a := PA.new_img(7, 3)
			PA.rect(a, 0, 0, 7, 2, PA.col("t"))
			PA.rect(a, 0, 1, 7, 1, PA.col("T"))
			PA.px(a, 5, 0, PA.col("W"))
			return a
		1:
			var b2 := PA.new_img(5, 3)
			PA.rect(b2, 0, 0, 5, 2, PA.col("T"))
			PA.rect(b2, 0, 0, 5, 1, PA.col("t"))
			return b2
		2:
			var c2 := PA.new_img(3, 3)
			PA.rect(c2, 0, 0, 3, 3, PA.col("b"))
			PA.px(c2, 0, 0, PA.col("t"))
			return c2
	var d := PA.new_img(1, 3)
	PA.px(d, 0, 0, PA.col("W"))
	PA.px(d, 0, 1, PA.col("g"))
	PA.px(d, 0, 2, PA.col("g"))
	return d


# ------------------------------------------------------------------ sunflower gatling

## Stem + leaves, 16x14, drawn at (-8, -16) so the stem rises from the crate lid into the bloom.
static func gatling_stem(lvl: int) -> Image:
	var img := PA.new_img(16, 14)
	var E := PA.col("E")
	var f := PA.col("f")
	var e := PA.col("e")
	PA.rect(img, 7, 2, 2, 12, E)
	PA.rect(img, 8, 2, 1, 12, f)
	# leaves
	rot_ellipse(img, 3.8, 9.0, 3.6, 1.5, -0.55, E)
	PA.line(img, 2, 10, 6, 8, f)
	PA.px(img, 2, 9, e)
	rot_ellipse(img, 12.0, 6.5, 3.4, 1.4, 0.6, E)
	PA.line(img, 10, 6, 14, 8, f)
	PA.px(img, 13, 6, e)
	if lvl >= 3:
		rot_ellipse(img, 4.5, 4.0, 2.4, 1.0, -0.8, e)
		PA.px(img, 3, 5, f)
	return PA.outline(img)


## Bloom (petals + seed head), 28x28 centred at (14,14). f = sway frame.
static func gatling_petals(lvl: int, f: int) -> Image:
	var img := PA.new_img(28, 28)
	var cx := 14.0
	var cy := 14.0
	var n := 12 + (lvl - 1) * 2
	var y := PA.col("y")
	var Y := PA.col("Y")
	var tip := PA.col("i") if lvl >= 2 else y.lightened(0.35)
	# back ring (darker, offset half a step)
	for i in n:
		var a := TAU * (i + 0.5) / n + sin(i * 1.7 + f * 2.1) * 0.06
		var p := Vector2(cx, cy) + Vector2.from_angle(a) * 6.6
		rot_ellipse(img, p.x, p.y, 3.4, 1.6, a, Y)
	# front ring
	for i in n:
		var a := TAU * i / n + sin(i * 2.3 + f * 2.1 + 1.0) * 0.08
		var p := Vector2(cx, cy) + Vector2.from_angle(a) * 6.4
		rot_ellipse(img, p.x, p.y, 3.6, 1.7, a, y)
		var tp := Vector2(cx, cy) + Vector2.from_angle(a) * 9.4
		PA.px(img, int(tp.x), int(tp.y), tip)
		# petal crease
		var mp := Vector2(cx, cy) + Vector2.from_angle(a) * 7.0
		PA.px(img, int(mp.x), int(mp.y), Y.lightened(0.2))
	if lvl >= 3:
		PA.ring(img, cx, cy, 5.6, 1.0, PA.col("r"))
	# seed head: dark disk with a golden-angle seed spiral
	PA.disk(img, cx, cy, 4.8, PA.col("B"))
	PA.disk(img, cx, cy, 3.8, PA.col("s").lerp(PA.col("B"), 0.4))
	for k in 22:
		var rr := sqrt(float(k)) * 0.92
		var aa := k * 2.39996
		var sp := Vector2(cx, cy) + Vector2.from_angle(aa) * rr
		PA.px(img, int(sp.x), int(sp.y), PA.col("b") if k % 3 != 0 else PA.col("Y").darkened(0.3))
	PA.px(img, int(cx) - 2, int(cy) - 3, PA.col("b").lightened(0.2))
	PA.px(img, int(cx) - 3, int(cy) - 2, PA.col("b").lightened(0.2))
	return PA.outline(img)


## Barrel cluster pointing right, 32x28 frame sharing the bloom's centre (14,14). A short
## housing sits on the seed head; individual barrel tips poke out past the petals.
## f = spin frame (rotating highlight + clamp bolt).
static func gatling_barrels(lvl: int, f: int) -> Image:
	var img := PA.new_img(32, 28)
	var nb := 3 + (lvl - 1)
	var h := nb * 2 - 1
	var top := 14 - nb + 1
	var G := PA.col("G")
	var g := PA.col("g")
	var W := PA.col("W")
	# housing cylinder (lit top, dark underside) with a front ring
	PA.rect(img, 17, top - 1, 7, h + 2, g)
	PA.rect(img, 17, top - 1, 7, 1, W)
	PA.rect(img, 17, top + h, 7, 1, G)
	PA.rect(img, 23, top - 1, 1, h + 2, G)
	PA.px(img, 19 + (f % 3), top - 1, PA.col("w"))
	if lvl >= 3:
		PA.rect(img, 20, top - 1, 1, h + 2, PA.col("y"))
	# barrel tips: separate 1px tubes (transparent gaps so each gets its own outline)
	for i in nb:
		var by := top + i * 2
		var hi := (i + f) % nb == 0
		PA.rect(img, 24, by, 5, 1, PA.col("w") if hi else W)
		PA.px(img, 28, by, PA.col("K"))
	return PA.outline(img)


# ------------------------------------------------------------------ water-bottle laser

## 18x28 bottle hanging cap-down in a wire stand. Drawn at (-9, -30): cap mouth at local (0, -6).
## f = 0..2 water slosh frame.
static func laser(lvl: int = 1, f: int = 0) -> Image:
	var img := PA.new_img(18, 28)
	var G := PA.col("G")
	var g := PA.col("g")
	# wire stand legs + brace + feet
	PA.line(img, 2, 27, 6, 17, g)
	PA.line(img, 15, 27, 11, 17, g)
	PA.line(img, 3, 27, 7, 17, G)
	PA.line(img, 4, 23, 13, 23, G)
	PA.px(img, 1, 27, G)
	PA.px(img, 16, 27, G)
	# bottle body (translucent plastic), base on top, rounded shoulders down to the cap
	var plastic := PA.col("a")
	plastic.a = 0.42
	PA.rect(img, 4, 4, 10, 15, plastic)
	PA.rect(img, 5, 3, 8, 1, plastic)
	PA.rect(img, 5, 19, 8, 1, plastic)
	PA.rect(img, 6, 20, 6, 1, plastic)
	# water (fills the lower half: the bottle is upside down), surface sloshes per frame
	var water := PA.col("u") if lvl < 2 else Color8(120, 230, 255)
	if lvl >= 3:
		water = Color8(150, 245, 255)
	water.a = 0.88
	var tilt: int = [0, 1, -1][f % 3]
	for x in range(5, 13):
		var s := 9 + int(roundf(tilt * (x - 8.5) / 4.0))
		for yy in range(s, 20):
			PA.px(img, x, yy, water)
		PA.px(img, x, s, Color(1, 1, 1, 0.85))
	for x in range(6, 12):
		PA.px(img, x, 20, water)
	# rims: glassy edges + highlight streak
	var rim := PA.col("a")
	rim.a = 0.9
	PA.rect(img, 4, 4, 1, 15, rim)
	PA.rect(img, 13, 4, 1, 15, PA.col("A"))
	PA.rect(img, 5, 5, 1, 13, Color(1, 1, 1, 0.75))
	PA.rect(img, 6, 6, 1, 4, Color(1, 1, 1, 0.35))
	# measurement ticks
	for ty in [7, 10, 13, 16]:
		PA.px(img, 12, ty, PA.col("n"))
		if ty % 2 == 1:
			PA.px(img, 11, ty, PA.col("n"))
	# label with a tiny hamster face
	var lab := PA.col("y") if lvl < 2 else (PA.col("w") if lvl < 3 else PA.col("p"))
	PA.rect(img, 5, 12, 8, 4, lab)
	PA.rect(img, 5, 12, 8, 1, lab.lightened(0.3))
	PA.disk(img, 9, 14, 1.6, PA.col("o"))
	PA.px(img, 8, 13, PA.col("k"))
	PA.px(img, 10, 13, PA.col("k"))
	PA.px(img, 9, 14, PA.col("p"))
	# clamp rings
	for cy2 in [6, 18]:
		PA.rect(img, 3, cy2, 12, 1, G)
		PA.px(img, 4, cy2, PA.col("W"))
		PA.px(img, 14, cy2, g)
	# cap + neck
	var cap := PA.col("r") if lvl < 3 else PA.col("y")
	PA.rect(img, 6, 21, 6, 3, cap)
	PA.rect(img, 6, 21, 6, 1, cap.lightened(0.35))
	PA.rect(img, 11, 22, 1, 2, cap.darkened(0.3))
	PA.rect(img, 7, 24, 4, 1, G)
	if lvl >= 2:
		# chrome reflector dish over the base
		PA.rect(img, 3, 2, 12, 1, PA.col("W"))
		PA.px(img, 2, 3, PA.col("W"))
		PA.px(img, 15, 3, PA.col("W"))
		PA.px(img, 5, 2, PA.col("w"))
	if lvl >= 3:
		# tiny solar panel + antenna
		PA.rect(img, 3, 0, 12, 2, PA.col("n"))
		for sx in [5, 8, 11]:
			PA.px(img, sx, 0, PA.col("u"))
		PA.px(img, 15, 0, PA.col("g"))
		PA.px(img, 16, 0, PA.col("r"))
	return PA.outline(img)


# ------------------------------------------------------------------ cedar-shaving mortar

## 24x22, drawn at (-11, -20) and mirrored by facing. Muzzle mouth at image (18.5, 4.5).
static func mortar(lvl: int = 1) -> Image:
	var img := PA.new_img(24, 22)
	# plank turntable
	PA.ellipse(img, 11.5, 19.0, 9.5, 2.7, PA.col("B"))
	PA.ellipse(img, 11.5, 18.4, 9.0, 2.2, PA.col("b"))
	for lx in [6, 10, 14, 18]:
		PA.px(img, lx, 18, PA.col("B"))
		PA.px(img, lx, 19, PA.col("B"))
	PA.ellipse(img, 11.5, 18.0, 6.0, 1.3, PA.col("t"))
	# pivot post
	PA.rect(img, 10, 13, 3, 5, PA.col("G"))
	PA.rect(img, 10, 13, 1, 5, PA.col("g"))
	# sack of cedar shavings (burlap) with a tied neck
	PA.ellipse(img, 4.5, 15.0, 4.0, 3.6, PA.col("T"))
	PA.ellipse(img, 4.0, 14.2, 3.0, 2.6, PA.col("t"))
	for sp in [Vector2i(3, 13), Vector2i(5, 15), Vector2i(2, 16), Vector2i(6, 13)]:
		PA.px(img, sp.x, sp.y, PA.col("b"))
	PA.px(img, 4, 15, PA.col("B"))      # stamped "C"
	PA.px(img, 5, 14, PA.col("B"))
	PA.px(img, 5, 16, PA.col("B"))
	PA.rect(img, 3, 10, 3, 1, PA.col("c"))  # rope
	PA.px(img, 4, 9, PA.col("c"))
	PA.px(img, 3, 8, PA.col("y"))
	PA.px(img, 5, 8, PA.col("c"))
	PA.px(img, 4, 7, PA.col("t"))
	# twin tube behind (L3)
	if lvl >= 3:
		stroke(img, Vector2(12, 15), Vector2(20, 7), 2.0, PA.col("T"))
		PA.disk(img, 20.5, 6.5, 1.6, PA.col("K"))
	# main cardboard tube with lit top edge and shaded underside
	var a := Vector2(9.0, 16.0)
	var b := Vector2(18.0, 5.5)
	stroke(img, a + Vector2(0.8, 0.8), b + Vector2(0.8, 0.8), 2.9, PA.col("T"))
	stroke(img, a, b, 2.9, PA.col("t"))
	stroke(img, a + Vector2(-1.2, -1.0), b + Vector2(-1.2, -1.0), 0.6, PA.col("c"))
	# bands
	var band := PA.col("B") if lvl < 2 else PA.col("g")
	for t in [0.28, 0.6]:
		var p := a.lerp(b, t)
		PA.line(img, int(p.x - 2), int(p.y - 2), int(p.x + 2), int(p.y + 2), band)
		if lvl >= 2:
			PA.px(img, int(p.x - 1), int(p.y - 1), PA.col("W"))
	if lvl >= 3:
		var p3 := a.lerp(b, 0.84)
		PA.line(img, int(p3.x - 2), int(p3.y - 2), int(p3.x + 2), int(p3.y + 2), PA.col("y"))
	if lvl >= 2:
		# iron sight on top
		var sp2 := a.lerp(b, 0.45) + Vector2(-2.5, -2.5)
		PA.px(img, int(sp2.x), int(sp2.y), PA.col("G"))
		PA.px(img, int(sp2.x), int(sp2.y) - 1, PA.col("g"))
	# muzzle mouth with shavings poking out
	PA.ellipse(img, 18.6, 4.6, 2.6, 2.2, PA.col("T"))
	PA.ellipse(img, 18.8, 4.4, 1.8, 1.4, PA.col("K"))
	PA.px(img, 19, 2, PA.col("c"))
	PA.px(img, 18, 3, PA.col("y"))
	PA.px(img, 20, 3, PA.col("t"))
	return PA.outline(img)


# ------------------------------------------------------------------ exercise-wheel tesla coil

## 14x26 coil, drawn at (0, -28). Top ball centre at image (6.5, 3.5) -> local (6.5, -24.5).
static func tesla_coil(lvl: int = 1) -> Image:
	var img := PA.new_img(14, 26)
	var G := PA.col("G")
	var g := PA.col("g")
	# base box with a dial and vent slits
	PA.rect(img, 1, 21, 12, 4, G)
	PA.rect(img, 1, 21, 12, 1, g)
	PA.disk(img, 4.5, 23.0, 1.4, PA.col("w"))
	PA.px(img, 4, 23, PA.col("r"))
	for vx in [8, 10]:
		PA.rect(img, vx, 22, 1, 2, PA.col("K"))
	# ceramic insulator stack
	for i in 3:
		var iy := 20.0 - i * 1.4
		PA.ellipse(img, 6.5, iy, 3.6, 0.9, PA.col("W"))
		PA.ellipse(img, 6.5, iy + 0.4, 3.0, 0.5, g)
	# copper winding with a lit column and a shaded column
	for yy in range(8, 17):
		var cc := PA.col("O") if yy % 2 == 0 else PA.col("Y")
		PA.rect(img, 4, yy, 6, 1, cc)
	PA.rect(img, 5, 8, 1, 9, PA.col("y"))
	PA.rect(img, 9, 8, 1, 9, PA.col("O").darkened(0.25))
	PA.rect(img, 7, 8, 1, 9, Color(1, 1, 1, 0.18))
	# torus rings
	var rings := 1 + (1 if lvl >= 2 else 0)
	for i in rings:
		var ty := 7.0 - i * 2.2
		PA.ellipse(img, 6.5, ty, 5.6, 1.6, g)
		PA.ellipse(img, 6.5, ty - 0.4, 5.0, 1.0, PA.col("W"))
		PA.ellipse(img, 6.5, ty + 0.2, 2.6, 0.6, PA.col("K"))
	# top ball
	var r := 3.0 if lvl < 3 else 3.5
	var ball := PA.col("u") if lvl == 1 else (PA.col("W") if lvl == 2 else PA.col("v"))
	PA.disk(img, 6.5, 3.5, r, ball.darkened(0.25))
	PA.disk(img, 6.0, 3.0, r - 0.8, ball)
	PA.px(img, 5, 2, PA.col("w"))
	PA.px(img, 4, 3, Color(1, 1, 1, 0.6))
	return PA.outline(img)


## Hamster intern sprinting in the wheel, 8x6, four run frames.
static func tesla_intern(f: int) -> Image:
	var img := PA.new_img(9, 7)
	var o := PA.col("o")
	PA.ellipse(img, 3.5, 3.5, 3.0, 2.0, o)
	PA.ellipse(img, 3.5, 4.2, 1.8, 1.0, PA.col("c"))
	PA.disk(img, 6.2, 2.8, 1.6, o)
	PA.px(img, 6, 1, PA.col("p"))
	PA.px(img, 7, 2, PA.col("k"))
	PA.px(img, 8, 3, PA.col("p"))
	var legs := [[1, 5], [3, 5], [2, 6], [4, 6]]
	var fa: Array = legs[f % 4]
	PA.px(img, fa[0], 6, PA.col("p"))
	PA.px(img, fa[1], 6, PA.col("p"))
	# little sweat drop on the fast frames
	if f % 2 == 1:
		PA.px(img, 1, 1, PA.col("a"))
	return PA.outline(img)


# ------------------------------------------------------------------ cardboard decoy

const DECOY_BITES := [
	[Vector2(1, 15), 2.2], [Vector2(20, 18), 2.4], [Vector2(15, 1), 1.8],
	[Vector2(2, 22), 2.0], [Vector2(19, 9), 2.0], [Vector2(9, 27), 1.8],
]


## 22x28 painted cutout, drawn at (-11, -27). Eye sockets at image (7.5, 9.5) and (14.5, 9.5).
## dmg 0..2 takes chewed bites out of the edges.
static func decoy(lvl: int = 1, dmg: int = 0) -> Image:
	var img := PA.new_img(22, 28)
	var card := PA.col("t")
	var cardd := PA.col("T")
	# cardboard silhouette (a bit larger than the paint job)
	PA.disk(img, 6.5, 4.0, 2.8, card)
	PA.disk(img, 15.5, 4.0, 2.8, card)
	PA.disk(img, 11.0, 10.0, 7.0, card)
	PA.ellipse(img, 11.0, 18.5, 7.6, 7.2, card)
	PA.rect(img, 5, 23, 5, 4, card)
	PA.rect(img, 12, 23, 5, 4, card)
	# corrugated right edge (cardboard thickness)
	for yy in 28:
		for xx in range(21, 7, -1):
			if img.get_pixel(xx, yy).a > 0.5:
				PA.px(img, xx, yy, cardd if yy % 2 == 0 else PA.col("B"))
				break
	# sloppy orange paint
	var paint := PA.col("o")
	PA.disk(img, 10.6, 10.0, 5.9, paint)
	PA.ellipse(img, 11.0, 18.5, 6.4, 6.0, paint)
	PA.disk(img, 6.5, 4.0, 1.5, PA.col("p"))
	PA.disk(img, 15.5, 4.0, 1.5, PA.col("p"))
	PA.rect(img, 6, 23, 3, 3, paint)
	PA.rect(img, 13, 23, 3, 3, paint)
	# cream face patch + belly, blush cheeks
	PA.ellipse(img, 11.0, 13.0, 3.8, 2.3, PA.col("c"))
	PA.ellipse(img, 11.0, 19.5, 4.0, 4.2, PA.col("c"))
	PA.px(img, 6, 13, PA.col("p"))
	PA.px(img, 15, 13, PA.col("p"))
	PA.px(img, 7, 13, PA.col("p"))
	# painted heart on the belly
	PA.px(img, 10, 18, PA.col("r"))
	PA.px(img, 12, 18, PA.col("r"))
	PA.rect(img, 10, 19, 3, 1, PA.col("r"))
	PA.px(img, 11, 20, PA.col("r"))
	# paint drips + brush streaks
	PA.px(img, 5, 22, paint)
	PA.px(img, 16, 21, paint)
	PA.px(img, 16, 22, paint)
	PA.px(img, 8, 6, paint.lightened(0.2))
	PA.px(img, 9, 6, paint.lightened(0.2))
	# nose, smile, whiskers
	PA.px(img, 10, 12, PA.col("p"))
	PA.px(img, 11, 12, PA.col("p"))
	PA.line(img, 8, 14, 10, 15, PA.col("k"))
	PA.line(img, 12, 15, 14, 14, PA.col("k"))
	PA.px(img, 4, 12, PA.col("k"))
	PA.px(img, 3, 13, PA.col("k"))
	PA.px(img, 18, 12, PA.col("k"))
	PA.px(img, 19, 13, PA.col("k"))
	# stubby arms
	PA.rect(img, 3, 17, 2, 4, paint)
	PA.rect(img, 17, 17, 2, 4, paint)
	# eye sockets (googly eyes go on top at runtime)
	PA.disk(img, 7.5, 9.5, 2.1, PA.col("w"))
	PA.disk(img, 14.5, 9.5, 2.1, PA.col("w"))
	# a strip of tape holding a patch on
	var tape := PA.col("W")
	tape.a = 0.75
	PA.line(img, 13, 21, 17, 17, tape)
	PA.line(img, 14, 21, 18, 17, tape)
	if lvl >= 2:
		# painted-on handlebar mustache + tin-foil helmet
		PA.line(img, 8, 13, 10, 13, PA.col("B"))
		PA.line(img, 12, 13, 14, 13, PA.col("B"))
		PA.px(img, 7, 12, PA.col("B"))
		PA.px(img, 15, 12, PA.col("B"))
		PA.rect(img, 7, 3, 9, 2, PA.col("W"))
		PA.rect(img, 8, 2, 7, 1, PA.col("g"))
		PA.px(img, 9, 3, PA.col("w"))
		PA.px(img, 13, 4, PA.col("g"))
	if lvl >= 3:
		# crown with a ruby + red cape behind the arms
		PA.rect(img, 7, 0, 9, 2, PA.col("y"))
		PA.px(img, 7, 0, PA.col("k"))
		PA.px(img, 11, 0, PA.col("r"))
		PA.px(img, 15, 0, PA.col("k"))
		PA.px(img, 9, 1, PA.col("Y"))
		PA.px(img, 13, 1, PA.col("Y"))
		PA.rect(img, 1, 16, 2, 8, PA.col("r"))
		PA.rect(img, 19, 16, 2, 8, PA.col("R"))
	# chewed bites: carve chunks out of the silhouette, exposing darker cardboard
	var nb := 0 if dmg <= 0 else (3 if dmg == 1 else DECOY_BITES.size())
	for i in nb:
		var bite: Array = DECOY_BITES[i]
		var bc: Vector2 = bite[0]
		var br: float = bite[1]
		for yy in range(int(bc.y - br - 2), int(bc.y + br + 3)):
			for xx in range(int(bc.x - br - 2), int(bc.x + br + 3)):
				if xx < 0 or yy < 0 or xx >= 22 or yy >= 28:
					continue
				var d := Vector2(xx + 0.5, yy + 0.5).distance_to(bc)
				if d <= br:
					img.set_pixel(xx, yy, Color(0, 0, 0, 0))
				elif d <= br + 1.0 and img.get_pixel(xx, yy).a > 0.5:
					img.set_pixel(xx, yy, PA.col("B"))
	return PA.outline(img)


# ------------------------------------------------------------------ misc

static func rubble() -> Image:
	var img := PA.new_img(22, 12)
	PA.ellipse(img, 11, 8, 9, 3, PA.col("T"))
	PA.rect(img, 4, 5, 5, 2, PA.col("t"))
	PA.rect(img, 4, 5, 5, 1, PA.col("c"))
	PA.rect(img, 12, 4, 6, 2, PA.col("b"))
	PA.line(img, 7, 3, 10, 6, PA.col("G"))
	PA.px(img, 15, 7, PA.col("g"))
	PA.px(img, 3, 9, PA.col("B"))
	PA.px(img, 18, 8, PA.col("W"))
	return PA.outline(img)


static func shell() -> Image:
	var img := PA.new_img(3, 2)
	PA.px(img, 0, 0, PA.col("s"))
	PA.px(img, 1, 0, PA.col("S"))
	PA.px(img, 1, 1, PA.col("s"))
	PA.px(img, 2, 1, PA.col("s"))
	return img
