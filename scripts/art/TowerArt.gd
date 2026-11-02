extends RefCounted
## Tower sprites. Heads that rotate are drawn pointing RIGHT around their centre.
## Level variants use a _1/_2/_3 suffix (level 1 also answers to the bare name).
## Names:
##   tower_base[_1..3]        wooden crate plinth every tower sits on (L2 brackets, L3 gold trim)
##   tower_gatling[_1..3]     Sunflower Gatling head (petals + 3/4/5 barrels)
##   tower_laser[_1..3]       upside-down hamster water bottle on a wire stand (tube drawn live)
##   tower_mortar[_1..3]      cardboard-tube mortar + sack of cedar shavings (points up-right)
##   tower_tesla_coil[_1..3]  copper Tesla coil with glowing top ball
##   tower_decoy[_1..3]       painted cardboard hamster cutout (googly eyes drawn live)
##   tower_rubble             destroyed-tower debris
##   shell                    single sunflower hull (ground decal)

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
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
			return gatling(lvl)
		"tower_laser":
			return laser(lvl)
		"tower_mortar":
			return mortar(lvl)
		"tower_tesla_coil":
			return tesla_coil(lvl)
		"tower_decoy":
			return decoy(lvl)
	match n:
		"tower_rubble":
			return rubble()
		"shell":
			return shell()
	return null


static func base(lvl: int = 1) -> Image:
	var img := PA.new_img(20, 14)
	# top face
	PA.rect(img, 1, 1, 18, 8, PA.col("t"))
	PA.rect(img, 1, 4, 18, 1, PA.col("T"))
	PA.rect(img, 1, 1, 18, 1, PA.col("c"))
	# front face
	PA.rect(img, 1, 9, 18, 4, PA.col("T"))
	PA.rect(img, 1, 12, 18, 1, PA.col("B"))
	PA.rect(img, 6, 9, 1, 4, PA.col("B"))
	PA.rect(img, 13, 9, 1, 4, PA.col("B"))
	PA.px(img, 2, 2, PA.col("W"))
	PA.px(img, 17, 2, PA.col("W"))
	if lvl >= 2:
		# riveted metal corner brackets
		for x in [1, 16]:
			PA.rect(img, x, 9, 3, 4, PA.col("g"))
			PA.px(img, x + 1, 10, PA.col("W"))
			PA.px(img, x + 1, 12, PA.col("G"))
		PA.rect(img, 1, 1, 3, 2, PA.col("g"))
		PA.rect(img, 16, 1, 3, 2, PA.col("g"))
	if lvl >= 3:
		# gold trim + a gold seed emblem on the front
		PA.rect(img, 1, 8, 18, 1, PA.col("y"))
		PA.rect(img, 1, 1, 18, 1, PA.col("y"))
		PA.px(img, 9, 10, PA.col("Y"))
		PA.px(img, 10, 10, PA.col("y"))
		PA.px(img, 9, 11, PA.col("y"))
		PA.px(img, 10, 11, PA.col("Y"))
	return PA.outline(img)


static func gatling(lvl: int = 1) -> Image:
	var img := PA.new_img(22, 22)
	var c := Vector2(10, 11)
	var petals := 10 + (lvl - 1) * 2
	# petals
	for i in petals:
		var a := TAU * i / float(petals)
		var p := c + Vector2(cos(a), sin(a)) * 5.6
		PA.disk(img, p.x, p.y, 2.3, PA.col("y"))
	for i in petals:
		var a := TAU * (i + 0.5) / float(petals)
		var p := c + Vector2(cos(a), sin(a)) * 6.0
		PA.px(img, int(p.x), int(p.y), PA.col("Y") if lvl < 2 else PA.col("i"))
	if lvl >= 2:
		# orange petal tips
		for i in petals:
			var a := TAU * i / float(petals)
			var p := c + Vector2(cos(a), sin(a)) * 7.4
			PA.px(img, int(p.x), int(p.y), PA.col("i"))
	# seed-head centre
	PA.disk(img, c.x, c.y, 4.0, PA.col("B"))
	for d in [Vector2i(-2, -1), Vector2i(1, -2), Vector2i(0, 1), Vector2i(-1, 2), Vector2i(2, 1)]:
		PA.px(img, int(c.x) + d.x, int(c.y) + d.y, PA.col("b"))
	if lvl >= 3:
		PA.ring(img, c.x, c.y, 4.0, 1.0, PA.col("r"))
	# gatling barrels (3 / 4 / 5)
	var rows: Array = [[8, "g"], [10, "W"], [12, "g"]]
	if lvl == 2:
		rows = [[7, "g"], [9, "W"], [11, "W"], [13, "g"]]
	elif lvl >= 3:
		rows = [[6, "g"], [8, "W"], [10, "W"], [12, "W"], [14, "g"]]
	for r in rows:
		var ry: int = r[0]
		PA.rect(img, 12, ry, 8, 2, PA.col(r[1]))
		PA.rect(img, 12, ry, 8, 1, PA.col("w") if r[1] == "W" else PA.col("W"))
	PA.rect(img, 11, int(rows[0][0]) - 1, 2, rows.size() * 2 + 2, PA.col("G"))
	if lvl >= 3:
		PA.rect(img, 16, int(rows[0][0]) - 1, 1, rows.size() * 2 + 2, PA.col("y"))
	return PA.outline(img)


## Upside-down hamster water bottle on a wire stand. Cap bottom sits at image (7, 20).
static func laser(lvl: int = 1) -> Image:
	var img := PA.new_img(16, 26)
	# wire stand legs
	PA.line(img, 2, 25, 5, 15, PA.col("g"))
	PA.line(img, 13, 25, 10, 15, PA.col("g"))
	PA.line(img, 3, 25, 6, 15, PA.col("G"))
	# bottle (translucent plastic)
	var plastic := PA.col("a")
	plastic.a = 0.55
	PA.rect(img, 4, 2, 8, 15, plastic)
	PA.rect(img, 5, 1, 6, 1, plastic)
	# water inside
	var water := PA.col("u") if lvl < 2 else Color8(120, 230, 255)
	water.a = 0.9
	PA.rect(img, 5, 6, 6, 11, water)
	PA.rect(img, 5, 6, 6, 1, PA.col("w"))
	# bubbles + highlight
	PA.px(img, 7, 9, PA.col("w"))
	PA.px(img, 9, 12, PA.col("a"))
	PA.rect(img, 4, 2, 1, 14, PA.col("w"))
	# label
	PA.rect(img, 5, 11, 6, 3, PA.col("y") if lvl < 3 else PA.col("p"))
	PA.px(img, 6, 12, PA.col("k"))
	PA.px(img, 8, 12, PA.col("k"))
	PA.px(img, 9, 12, PA.col("k"))
	# clamp rings
	PA.rect(img, 3, 7, 10, 1, PA.col("G"))
	PA.rect(img, 3, 15, 10, 1, PA.col("G"))
	# cap
	var cap := PA.col("r") if lvl < 3 else PA.col("y")
	PA.rect(img, 5, 17, 6, 3, cap)
	PA.rect(img, 5, 17, 6, 1, cap.lightened(0.3))
	if lvl >= 2:
		# second clamp + reflector dish
		PA.rect(img, 3, 3, 10, 1, PA.col("W"))
		PA.px(img, 2, 3, PA.col("W"))
		PA.px(img, 13, 3, PA.col("W"))
	if lvl >= 3:
		# tiny solar panel on top
		PA.rect(img, 3, 0, 10, 2, PA.col("n"))
		PA.px(img, 5, 0, PA.col("u"))
		PA.px(img, 8, 0, PA.col("u"))
		PA.px(img, 11, 0, PA.col("u"))
	return PA.outline(img)


## Cardboard-tube mortar pointing up-right; muzzle at image (15, 3).
static func mortar(lvl: int = 1) -> Image:
	var img := PA.new_img(20, 19)
	# swivel plate
	PA.ellipse(img, 9, 16, 7, 2.2, PA.col("G"))
	PA.ellipse(img, 9, 15.5, 5, 1.5, PA.col("g"))
	# sack of cedar shavings
	PA.ellipse(img, 4, 13, 3.5, 3.2, PA.col("b"))
	PA.ellipse(img, 4, 12, 2.6, 2.2, PA.col("T"))
	PA.px(img, 3, 9, PA.col("c"))
	PA.px(img, 4, 8, PA.col("t"))
	PA.px(img, 5, 9, PA.col("y"))
	# second tube (L3) behind
	if lvl >= 3:
		for i in 9:
			var p := Vector2(9, 13).lerp(Vector2(17, 6), i / 8.0)
			PA.disk(img, p.x, p.y, 1.8, PA.col("T"))
	# main cardboard tube
	for i in 11:
		var p := Vector2(7, 14).lerp(Vector2(15, 4), i / 10.0)
		PA.disk(img, p.x, p.y, 2.7, PA.col("t"))
	# tube bands
	var band := PA.col("T") if lvl < 2 else PA.col("W")
	for t in [0.3, 0.65]:
		var p := Vector2(7, 14).lerp(Vector2(15, 4), t)
		PA.line(img, int(p.x - 2), int(p.y - 1), int(p.x + 1), int(p.y + 2), band)
	if lvl >= 3:
		var p3 := Vector2(7, 14).lerp(Vector2(15, 4), 0.85)
		PA.line(img, int(p3.x - 2), int(p3.y - 1), int(p3.x + 1), int(p3.y + 2), PA.col("y"))
	# highlight
	PA.line(img, 6, 12, 13, 3, PA.col("c"))
	# muzzle opening with shavings poking out
	PA.disk(img, 15.5, 3.5, 2.0, PA.col("K"))
	PA.px(img, 16, 1, PA.col("c"))
	PA.px(img, 14, 2, PA.col("y"))
	return PA.outline(img)


static func tesla_coil(lvl: int = 1) -> Image:
	var img := PA.new_img(12, 26)
	# base
	PA.rect(img, 1, 21, 10, 4, PA.col("G"))
	PA.rect(img, 1, 21, 10, 1, PA.col("g"))
	# copper winding
	for y in range(9, 21):
		var c := PA.col("O") if y % 2 == 0 else PA.col("Y")
		PA.rect(img, 3, y, 6, 1, c)
	PA.rect(img, 3, 9, 1, 12, PA.col("y"))
	# torus rings
	var rings := 1 + (1 if lvl >= 2 else 0)
	for i in rings:
		PA.ellipse(img, 6, 8 - i * 2, 4.5, 1.2, PA.col("g"))
		PA.ellipse(img, 6, 8 - i * 2, 3.0, 0.6, PA.col("W"))
	# top ball
	var r := 3.0 if lvl < 3 else 3.6
	PA.disk(img, 6, 4, r, PA.col("u") if lvl < 3 else PA.col("v"))
	PA.px(img, 5, 3, PA.col("w"))
	PA.px(img, 4, 4, PA.col("a"))
	return PA.outline(img)


## Painted cardboard hamster cutout. Eye sockets at image (7, 8) and (13, 8).
static func decoy(lvl: int = 1) -> Image:
	var img := PA.new_img(21, 26)
	var card := PA.col("t")
	# cardboard silhouette (slightly larger than the paint job)
	PA.disk(img, 6.5, 3.5, 2.6, card)
	PA.disk(img, 14, 3.5, 2.6, card)
	PA.disk(img, 10.5, 9, 6.6, card)
	PA.ellipse(img, 10.5, 17, 7.2, 7.0, card)
	PA.rect(img, 5, 22, 4, 3, card)
	PA.rect(img, 12, 22, 4, 3, card)
	# crude orange paint (sloppy: misses the edges)
	var paint := PA.col("o")
	PA.disk(img, 10, 9, 5.6, paint)
	PA.ellipse(img, 10.5, 17, 6.0, 5.8, paint)
	PA.disk(img, 6.5, 3.5, 1.4, PA.col("p"))
	PA.disk(img, 14, 3.5, 1.4, PA.col("p"))
	# cream belly + face patch
	PA.ellipse(img, 10.5, 18, 3.8, 4.0, PA.col("c"))
	PA.ellipse(img, 10.5, 11.5, 3.6, 2.2, PA.col("c"))
	# paint drips
	PA.px(img, 5, 21, paint)
	PA.px(img, 15, 20, paint)
	PA.px(img, 15, 21, paint)
	# painted smile, nose, whiskers
	PA.px(img, 10, 11, PA.col("p"))
	PA.px(img, 11, 11, PA.col("p"))
	PA.line(img, 8, 13, 10, 14, PA.col("k"))
	PA.line(img, 11, 14, 13, 13, PA.col("k"))
	PA.px(img, 4, 11, PA.col("k"))
	PA.px(img, 3, 12, PA.col("k"))
	PA.px(img, 17, 11, PA.col("k"))
	PA.px(img, 18, 12, PA.col("k"))
	# stubby arms
	PA.rect(img, 3, 16, 2, 4, paint)
	PA.rect(img, 16, 16, 2, 4, paint)
	# eye sockets (googly eyes go on top at runtime)
	PA.disk(img, 7.5, 8.5, 2.0, PA.col("w"))
	PA.disk(img, 13.5, 8.5, 2.0, PA.col("w"))
	if lvl >= 2:
		# painted-on handlebar mustache + tin-foil helmet
		PA.line(img, 7, 12, 9, 12, PA.col("B"))
		PA.line(img, 12, 12, 14, 12, PA.col("B"))
		PA.px(img, 6, 11, PA.col("B"))
		PA.px(img, 15, 11, PA.col("B"))
		PA.rect(img, 7, 3, 7, 2, PA.col("W"))
		PA.rect(img, 8, 2, 5, 1, PA.col("g"))
	if lvl >= 3:
		# crown + little red cape
		PA.rect(img, 7, 0, 7, 2, PA.col("y"))
		PA.px(img, 7, 0, PA.col("k"))
		PA.px(img, 10, 0, PA.col("r"))
		PA.px(img, 13, 0, PA.col("k"))
		PA.rect(img, 2, 15, 2, 8, PA.col("r"))
		PA.rect(img, 17, 15, 2, 8, PA.col("r"))
	# cardboard edge thickness on the right
	var out := PA.outline(img)
	return out


static func rubble() -> Image:
	var img := PA.new_img(20, 12)
	PA.ellipse(img, 10, 8, 8, 3, PA.col("T"))
	PA.rect(img, 4, 5, 4, 3, PA.col("t"))
	PA.rect(img, 11, 4, 5, 2, PA.col("b"))
	PA.line(img, 6, 3, 9, 6, PA.col("G"))
	PA.px(img, 14, 7, PA.col("g"))
	PA.px(img, 3, 9, PA.col("B"))
	return PA.outline(img)


static func shell() -> Image:
	var img := PA.new_img(3, 2)
	PA.px(img, 0, 0, PA.col("s"))
	PA.px(img, 1, 0, PA.col("S"))
	PA.px(img, 1, 1, PA.col("s"))
	PA.px(img, 2, 1, PA.col("s"))
	return img
