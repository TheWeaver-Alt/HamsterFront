extends RefCounted
## Hamster pilots and their junkyard mechs.
## Names:
##   ham_head_0..8       pilot head, cheeks inflate with pouch level (0 empty .. 8 full)
##   ham_head_dizzy      spinning-out face
##   brawler_body_0/1    BRAWLER-01 espresso-machine chassis (walk frames)
##   brawler_dome        glass cockpit overlay
##   brawler_gun         Sawdust Shotgun (points right, pivot ~(3,3))
##   brawler_fist        Cardboard-Tube Fist (points right)
##   wheeler_ball        WHEELER-X glass hamster ball
##   wheeler_ham_0/1     running hamster body inside the ball
##   wheeler_rails       dual Toothpick Railguns (points right)
##   mech_wreck          downed mech smoke-pile overlay

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	if n.begins_with("ham_head_"):
		var suffix := n.substr(9)
		if suffix == "dizzy":
			return head(4, true)
		return head(int(suffix), false)
	match n:
		"brawler_body_0":
			return brawler_body(0)
		"brawler_body_1":
			return brawler_body(1)
		"brawler_dome":
			return dome(7.0)
		"brawler_gun":
			return brawler_gun()
		"brawler_fist":
			return brawler_fist()
		"wheeler_ball":
			return wheeler_ball()
		"wheeler_ham_0":
			return wheeler_ham(0)
		"wheeler_ham_1":
			return wheeler_ham(1)
		"wheeler_rails":
			return wheeler_rails()
	return null


## Pilot head. level 0..8 controls cheek inflation.
static func head(level: int, dizzy: bool) -> Image:
	var img := PA.new_img(26, 20)
	var f := clampf(level / 8.0, 0.0, 1.0)
	var cx := 13.0
	var cy := 10.0
	var fur := PA.col("o")
	var cream := PA.col("c")
	# ears
	PA.disk(img, cx - 3.6, cy - 4.2, 1.9, fur)
	PA.disk(img, cx + 3.6, cy - 4.2, 1.9, fur)
	PA.px(img, int(cx - 4), int(cy - 5), PA.col("p"))
	PA.px(img, int(cx + 3), int(cy - 5), PA.col("p"))
	# head
	PA.disk(img, cx, cy - 0.5, 4.6, fur)
	PA.disk(img, cx, cy - 2.5, 2.6, PA.col("O").lightened(0.15))
	PA.disk(img, cx, cy - 1.0, 4.0, fur)
	# cheeks bulge outward & downward as the pouch fills
	var cr := 1.3 + f * 4.4
	var cdx := 2.8 + f * 2.8
	var cyy := cy + 1.4 + f * 1.2
	PA.disk(img, cx - cdx, cyy, cr, cream)
	PA.disk(img, cx + cdx, cyy, cr, cream)
	PA.ellipse(img, cx, cy + 1.6, 2.6, 2.0, cream)
	if f >= 0.5:
		# blush and strain lines
		PA.px(img, int(cx - cdx - 1), int(cyy), PA.col("p"))
		PA.px(img, int(cx + cdx), int(cyy), PA.col("p"))
	if f >= 0.85:
		PA.px(img, int(cx - cdx - 2), int(cyy - 2), PA.col("w"))
		PA.px(img, int(cx + cdx + 1), int(cyy - 2), PA.col("w"))
	# eyes
	var k := PA.col("k")
	if dizzy:
		# X X eyes
		for e in [-2, 2]:
			PA.px(img, int(cx + e - 1), int(cy - 2), k)
			PA.px(img, int(cx + e), int(cy - 1), k)
			PA.px(img, int(cx + e - 1), int(cy), k)
			PA.px(img, int(cx + e), int(cy - 2), k)
			PA.px(img, int(cx + e - 1), int(cy), k)
	elif f >= 0.85:
		# squinting > <
		PA.px(img, int(cx - 3), int(cy - 2), k)
		PA.px(img, int(cx - 2), int(cy - 1), k)
		PA.px(img, int(cx + 2), int(cy - 2), k)
		PA.px(img, int(cx + 1), int(cy - 1), k)
	else:
		PA.px(img, int(cx - 2), int(cy - 1), k)
		PA.px(img, int(cx + 2), int(cy - 1), k)
		PA.px(img, int(cx - 2), int(cy - 2), k)
		PA.px(img, int(cx + 2), int(cy - 2), k)
		PA.px(img, int(cx - 3), int(cy - 2), PA.col("w"))
		PA.px(img, int(cx + 1), int(cy - 2), PA.col("w"))
	# nose + mouth
	PA.px(img, int(cx), int(cy), PA.col("p"))
	if f < 0.5:
		PA.px(img, int(cx), int(cy + 1), PA.col("O"))
	else:
		PA.px(img, int(cx - 1), int(cy + 2), PA.col("O"))
		PA.px(img, int(cx), int(cy + 2), PA.col("O"))
	# buck teeth
	PA.px(img, int(cx), int(cy + 2) if f < 0.5 else int(cy + 3), PA.col("w"))
	return PA.outline(img)


static func brawler_body(frame: int) -> Image:
	var img := PA.new_img(26, 24)
	var ox := 2
	var oy := 2
	# legs
	var lift_l := 1 if frame == 1 else 0
	var lift_r := 1 if frame == 0 else 0
	PA.rect(img, ox + 4, oy + 15 - lift_l, 3, 4, PA.col("G"))
	PA.rect(img, ox + 3, oy + 18 - lift_l, 5, 2, PA.col("g"))
	PA.rect(img, ox + 15, oy + 15 - lift_r, 3, 4, PA.col("G"))
	PA.rect(img, ox + 14, oy + 18 - lift_r, 5, 2, PA.col("g"))
	# exhaust chimney (steam vent)
	PA.rect(img, ox + 1, oy + 0, 3, 7, PA.col("g"))
	PA.rect(img, ox + 1, oy + 0, 3, 1, PA.col("G"))
	PA.rect(img, ox + 1, oy + 1, 1, 6, PA.col("W"))
	# chrome top plate
	PA.rect(img, ox + 1, oy + 4, 20, 3, PA.col("W"))
	PA.rect(img, ox + 1, oy + 6, 20, 1, PA.col("g"))
	# red espresso body
	PA.rect(img, ox + 2, oy + 7, 18, 9, PA.col("r"))
	PA.rect(img, ox + 2, oy + 7, 18, 1, PA.col("r").lightened(0.25))
	PA.rect(img, ox + 18, oy + 7, 2, 9, PA.col("R"))
	PA.rect(img, ox + 2, oy + 15, 18, 1, PA.col("R"))
	# pressure gauge
	PA.disk(img, ox + 6.5, oy + 10.5, 2.3, PA.col("w"))
	PA.px(img, ox + 6, oy + 10, PA.col("k"))
	PA.px(img, ox + 7, oy + 9, PA.col("r"))
	# portafilter spout
	PA.rect(img, ox + 10, oy + 12, 6, 2, PA.col("G"))
	PA.rect(img, ox + 11, oy + 14, 4, 1, PA.col("g"))
	PA.px(img, ox + 9, oy + 12, PA.col("B"))
	PA.px(img, ox + 8, oy + 12, PA.col("B"))
	# duct tape X
	PA.line(img, ox + 12, oy + 8, ox + 18, oy + 13, PA.col("W"))
	PA.line(img, ox + 18, oy + 8, ox + 12, oy + 13, PA.col("W"))
	PA.line(img, ox + 13, oy + 8, ox + 18, oy + 12, PA.col("g"))
	# rivets
	PA.px(img, ox + 3, oy + 8, PA.col("W"))
	PA.px(img, ox + 3, oy + 14, PA.col("W"))
	return PA.outline(img)


static func dome(r: float) -> Image:
	var s := int(r * 2 + 4)
	var img := PA.new_img(s, s)
	var c := s / 2.0
	var glass := PA.col("a")
	glass.a = 0.28
	PA.disk(img, c, c, r, glass)
	var rim := PA.col("a")
	rim.a = 0.85
	PA.ring(img, c, c, r, 1.0, rim)
	# highlights
	var w := PA.col("w")
	PA.px(img, int(c - r * 0.55), int(c - r * 0.55), w)
	PA.px(img, int(c - r * 0.55) + 1, int(c - r * 0.7), w)
	PA.px(img, int(c - r * 0.75), int(c - r * 0.3), w)
	return img


static func brawler_gun() -> Image:
	var img := PA.new_img(18, 9)
	# grip/stock
	PA.rect(img, 1, 4, 4, 3, PA.col("B"))
	# barrel
	PA.rect(img, 4, 3, 11, 3, PA.col("b"))
	PA.rect(img, 4, 3, 11, 1, PA.col("t"))
	PA.rect(img, 9, 3, 1, 3, PA.col("g"))
	# sawdust hopper funnel
	PA.rect(img, 6, 1, 4, 2, PA.col("T"))
	PA.rect(img, 5, 0, 6, 1, PA.col("t"))
	# flared muzzle
	PA.rect(img, 14, 2, 2, 5, PA.col("G"))
	PA.px(img, 16, 2, PA.col("G"))
	PA.px(img, 16, 6, PA.col("G"))
	return PA.outline(img)


static func brawler_fist() -> Image:
	var img := PA.new_img(18, 10)
	# cardboard tube
	PA.rect(img, 1, 3, 9, 4, PA.col("t"))
	PA.rect(img, 1, 3, 9, 1, PA.col("c"))
	PA.rect(img, 4, 3, 1, 4, PA.col("T"))
	PA.rect(img, 7, 3, 1, 4, PA.col("T"))
	# boxing-glove fist
	PA.disk(img, 12.5, 5.0, 3.6, PA.col("r"))
	PA.px(img, 11, 3, PA.col("r").lightened(0.4))
	PA.px(img, 12, 2, PA.col("r").lightened(0.4))
	PA.rect(img, 9, 4, 2, 3, PA.col("w"))
	return PA.outline(img)


static func wheeler_ball() -> Image:
	var img := PA.new_img(24, 24)
	var c := 12.0
	var glass := PA.col("a")
	glass.a = 0.22
	PA.disk(img, c, c, 10.0, glass)
	var low := PA.col("A")
	low.a = 0.35
	for y in range(13, 22):
		for x in 24:
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color(low.r, low.g, low.b, 0.32))
	var rim := PA.col("a")
	rim.a = 0.95
	PA.ring(img, c, c, 10.0, 1.0, rim)
	var rim2 := PA.col("A")
	rim2.a = 0.7
	PA.ring(img, c, c, 9.0, 1.0, Color(rim2.r, rim2.g, rim2.b, 0.25))
	# air vents
	for v in [Vector2i(17, 5), Vector2i(19, 7), Vector2i(20, 10)]:
		PA.px(img, v.x, v.y, PA.col("A"))
	# highlights
	var w := PA.col("w")
	PA.px(img, 6, 6, w)
	PA.px(img, 7, 5, w)
	PA.px(img, 8, 4, w)
	PA.px(img, 5, 8, w)
	# weld mount at the bottom
	PA.rect(img, 9, 21, 6, 2, PA.col("g"))
	PA.rect(img, 10, 22, 4, 1, PA.col("G"))
	return img


static func wheeler_ham(frame: int) -> Image:
	var img := PA.new_img(14, 12)
	PA.ellipse(img, 7, 6, 5.0, 3.6, PA.col("o"))
	PA.ellipse(img, 7, 7.2, 3.2, 2.2, PA.col("c"))
	var f0 := Vector2i(3, 10) if frame == 0 else Vector2i(5, 10)
	var f1 := Vector2i(10, 10) if frame == 0 else Vector2i(8, 10)
	PA.px(img, f0.x, f0.y, PA.col("p"))
	PA.px(img, f0.x + 1, f0.y, PA.col("p"))
	PA.px(img, f1.x, f1.y, PA.col("p"))
	PA.px(img, f1.x + 1, f1.y, PA.col("p"))
	# little arms pumping
	var ay := 5 if frame == 0 else 6
	PA.px(img, 2, ay, PA.col("p"))
	PA.px(img, 12, 11 - ay, PA.col("p"))
	return PA.outline(img)


static func wheeler_rails() -> Image:
	var img := PA.new_img(18, 11)
	# housing
	PA.rect(img, 1, 3, 5, 5, PA.col("G"))
	PA.rect(img, 1, 3, 5, 1, PA.col("g"))
	# two rails
	for by in [2, 7]:
		PA.rect(img, 4, by, 11, 2, PA.col("W"))
		PA.rect(img, 4, by + 1, 11, 1, PA.col("g"))
		PA.px(img, 7, by, PA.col("u"))
		PA.px(img, 10, by, PA.col("u"))
		PA.px(img, 13, by, PA.col("u"))
		# toothpick tip
		PA.px(img, 15, by, PA.col("t"))
		PA.px(img, 16, by, PA.col("c"))
	return PA.outline(img)
