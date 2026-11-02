extends RefCounted
## Props, pickups and icons.
## Names:
##   seed, seed_h          striped sunflower seed pickup (vertical / horizontal)
##   seed_icon             HUD seed icon
##   silo_bucket           The Great Silo plastic bucket (seed mound is drawn live)
##   obstacle_pot, obstacle_rock, obstacle_gnome, obstacle_can
##   icon_heart, icon_heat, icon_skull, icon_wave
## Ambient life (drawn by scripts/systems/AmbientLayer.gd), lean = l | c | r:
##   amb_tuft_<0..2>_<lean>, amb_tall_<lean>, amb_flower_<0..3>_<lean> (daisy/buttercup/bluebell/poppy),
##   amb_sunflower_<lean>, amb_butterfly_<0..3>_<0|1>, amb_bee_<0|1>, amb_leaf_<0|1>, amb_cloud_<0..2>

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	match n:
		"seed":
			return seed_v()
		"seed_h":
			return seed_h()
		"seed_icon":
			return seed_icon()
		"silo_bucket":
			return silo_bucket()
		"obstacle_pot":
			return pot()
		"obstacle_rock":
			return rock()
		"obstacle_gnome":
			return gnome()
		"obstacle_can":
			return watering_can()
		"icon_heart":
			return PA.from_ascii([".r.r.", "rrrrr", "rrrrr", ".rrr.", "..r.."], 1)
		"icon_heat":
			return PA.from_ascii(["..i..", ".iI..", ".iIi.", "iIIIi", ".iii."], 1)
		"icon_skull":
			return PA.from_ascii([".www.", "wwwww", "wkwkw", "wwwww", ".w.w."], 1)
	if n.begins_with("amb_"):
		return _ambient(n.substr(4))
	return null


static func seed_v() -> Image:
	return PA.from_ascii([".s.", "sSs", "sSs", "sSs", ".s."])


static func seed_h() -> Image:
	return PA.from_ascii([".sss.", "sSSSs", ".sss."])


static func seed_icon() -> Image:
	var img := PA.from_ascii([
		"..s..",
		".sSs.",
		"ssSss",
		"sSsSs",
		"ssSss",
		".sSs.",
		"..s..",
	], 1)
	return PA.outline(img, PA.col("w"))


static func silo_bucket() -> Image:
	# Glossy blue plastic bucket: thick rolled rim, moulded rings, gloss stripe, handle lugs,
	# and a SEEDS sticker with a sunflower logo. Footprint 56x44, base at the bottom row.
	var w := 56
	var h := 44
	var img := PA.new_img(w, h)
	var blue := PA.col("A")
	var blue_lt := PA.col("a")
	var blue_dk := PA.col("n")
	var top_w := 49.0
	var bot_w := 39.0
	for y in range(5, h - 1):
		var t := float(y - 5) / float(h - 6)
		var row_w := lerpf(top_w, bot_w, t)
		var x0 := int(roundf(w / 2.0 - row_w / 2.0))
		var x1 := int(roundf(w / 2.0 + row_w / 2.0))
		for x in range(x0, x1):
			var u := float(x - x0) / maxf(1.0, float(x1 - x0 - 1))   # 0 left .. 1 right
			var c := blue
			if u < 0.07:
				c = blue_lt.darkened(0.05)
			elif u < 0.13:
				c = blue.lightened(0.18)
			elif u > 0.9:
				c = blue_dk
			elif u > 0.78:
				c = blue.darkened(0.18)
			# vertical gloss stripe
			if u > 0.24 and u < 0.29:
				c = PA.col("w").lerp(blue_lt, 0.35)
			elif u >= 0.29 and u < 0.31:
				c = blue_lt
			img.set_pixel(x, y, c)
		# moulded rings
		if y == 15 or y == 27 or y == 37:
			for x in range(x0 + 1, x1 - 1):
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.2))
				PA.px(img, x, y + 1, img.get_pixel(x, y + 1).lightened(0.12))
	# rolled rim (a little wider than the body)
	for x in range(2, w - 2):
		var u2 := float(x - 2) / float(w - 5)
		PA.px(img, x, 1, blue_lt.lightened(0.25) if u2 < 0.7 else blue_lt)
		PA.px(img, x, 2, blue_lt)
		PA.px(img, x, 3, blue if u2 < 0.8 else blue.darkened(0.15))
		PA.px(img, x, 4, blue_dk)
	PA.px(img, 1, 2, blue_lt)
	PA.px(img, 1, 3, blue)
	PA.px(img, w - 2, 2, blue)
	PA.px(img, w - 2, 3, blue_dk)
	# handle lugs
	for side in [3, w - 6]:
		PA.rect(img, side, 5, 3, 3, PA.col("g"))
		PA.px(img, side + 1, 5, PA.col("W"))
		PA.px(img, side + 1, 6, PA.col("G"))
	# sticker: white border, red label, SEEDS text and a little sunflower
	PA.rect(img, 13, 16, 30, 13, PA.col("w"))
	PA.rect(img, 14, 17, 28, 11, PA.col("r"))
	PA.rect(img, 14, 17, 28, 1, PA.col("r").lightened(0.3))
	PA.rect(img, 14, 27, 28, 1, PA.col("R"))
	PA.stamp_text(img, 22, 19, "SEEDS", PA.col("w"))
	PA.disk(img, 18.0, 22.0, 2.6, PA.col("y"))
	PA.disk(img, 18.0, 22.0, 1.2, PA.col("B"))
	PA.px(img, 18, 25, PA.col("E"))
	PA.px(img, 18, 26, PA.col("E"))
	# base: dark foot + floor contact
	for x in range(9, w - 9):
		PA.px(img, x, h - 2, blue_dk.darkened(0.2))
	# scuffs
	PA.px(img, 9, 34, blue_dk)
	PA.px(img, 10, 35, blue_dk)
	PA.px(img, 44, 11, blue_dk)
	PA.px(img, 45, 31, blue.darkened(0.25))
	return PA.outline(img)


static func pot() -> Image:
	var img := PA.new_img(18, 23)
	# bushy geranium: dark back leaves, mid, lit front leaves, red flower clusters
	PA.disk(img, 9, 7, 5.6, PA.col("f"))
	PA.disk(img, 5, 8, 3.4, PA.col("E"))
	PA.disk(img, 13, 7, 3.6, PA.col("E"))
	PA.disk(img, 9, 4, 3.0, PA.col("E"))
	PA.disk(img, 7, 6, 2.0, PA.col("e"))
	PA.disk(img, 12, 5, 1.6, PA.col("e"))
	for f in [Vector2i(8, 2), Vector2i(5, 5), Vector2i(13, 4), Vector2i(10, 8)]:
		PA.px(img, f.x, f.y, PA.col("r"))
		PA.px(img, f.x + 1, f.y, PA.col("r").lightened(0.25))
		PA.px(img, f.x, f.y + 1, PA.col("R"))
	# terracotta pot: lit left, shaded right, rolled rim
	for y in range(11, 22):
		var t := float(y - 11) / 10.0
		var hw := lerpf(7.0, 5.0, t)
		var x0 := int(9 - hw)
		var x1 := int(9 + hw)
		for x in range(x0, x1):
			var c := PA.col("i").darkened(0.28)
			if x < x0 + 2:
				c = PA.col("i").darkened(0.05)
			elif x < x0 + 3:
				c = PA.col("i").darkened(0.15)
			elif x > x1 - 3:
				c = PA.col("O").darkened(0.15)
			PA.px(img, x, y, c)
	PA.rect(img, 1, 10, 16, 3, PA.col("i"))
	PA.rect(img, 1, 10, 16, 1, PA.col("i").lightened(0.2))
	PA.rect(img, 1, 12, 16, 1, PA.col("O"))
	PA.rect(img, 13, 10, 3, 3, PA.col("O"))
	PA.px(img, 6, 16, PA.col("O"))
	PA.px(img, 7, 17, PA.col("O"))
	return PA.outline(img)


static func rock() -> Image:
	var img := PA.new_img(19, 15)
	PA.ellipse(img, 9.5, 8.5, 8.0, 5.6, PA.col("H"))
	PA.ellipse(img, 8.5, 7.5, 6.8, 4.6, PA.col("h"))
	PA.ellipse(img, 6.5, 5.5, 3.6, 2.4, PA.col("l"))
	PA.px(img, 5, 4, PA.col("w").lerp(PA.col("l"), 0.5))
	# facets + crack
	PA.line(img, 11, 4, 13, 8, PA.col("H"))
	PA.line(img, 13, 8, 12, 11, PA.col("H"))
	PA.px(img, 14, 9, PA.col("H").darkened(0.2))
	for x in range(4, 16):
		PA.px(img, x, 12, PA.col("H").darkened(0.15))
	# moss cap
	PA.px(img, 8, 3, PA.col("E"))
	PA.px(img, 9, 3, PA.col("f"))
	PA.px(img, 10, 3, PA.col("E"))
	PA.px(img, 9, 2, PA.col("e"))
	# grass at the foot + pebble
	PA.px(img, 3, 12, PA.col("E"))
	PA.px(img, 2, 11, PA.col("e"))
	PA.px(img, 16, 12, PA.col("f"))
	PA.px(img, 17, 13, PA.col("h"))
	return PA.outline(img)


static func gnome() -> Image:
	var img := PA.new_img(15, 23)
	# pointy hat with a lit side and a floppy tip
	for y in range(1, 9):
		var hw := (y - 1) * 0.62 + 0.5
		for x in range(int(7 - hw), int(7 + hw) + 1):
			var c := PA.col("r") if x <= 7 else PA.col("R")
			PA.px(img, x, y, c)
	PA.px(img, 8, 0, PA.col("r"))
	PA.px(img, 9, 0, PA.col("R"))
	PA.px(img, 6, 4, PA.col("r").lightened(0.35))
	PA.px(img, 5, 6, PA.col("r").lightened(0.25))
	# face, rosy cheeks, big nose
	PA.disk(img, 7, 10, 2.7, PA.col("c"))
	PA.px(img, 6, 9, PA.col("k"))
	PA.px(img, 9, 9, PA.col("k"))
	PA.px(img, 7, 10, PA.col("p"))
	PA.px(img, 8, 10, PA.col("P"))
	PA.px(img, 5, 10, PA.col("p").lightened(0.2))
	# beard
	PA.disk(img, 7.5, 13.5, 3.2, PA.col("w"))
	PA.px(img, 7, 16, PA.col("w"))
	PA.px(img, 9, 14, PA.col("W"))
	PA.px(img, 8, 15, PA.col("W"))
	# coat, belt with buckle, boots
	PA.rect(img, 3, 15, 10, 5, PA.col("A"))
	PA.rect(img, 3, 15, 2, 5, PA.col("a"))
	PA.rect(img, 11, 15, 2, 5, PA.col("n"))
	PA.rect(img, 3, 17, 10, 1, PA.col("B"))
	PA.px(img, 7, 17, PA.col("y"))
	PA.px(img, 8, 17, PA.col("Y"))
	PA.rect(img, 3, 20, 4, 2, PA.col("B"))
	PA.rect(img, 8, 20, 4, 2, PA.col("B"))
	PA.px(img, 3, 20, PA.col("b"))
	PA.px(img, 8, 20, PA.col("b"))
	# tiny shovel
	PA.line(img, 13, 11, 13, 18, PA.col("b"))
	PA.rect(img, 12, 18, 3, 2, PA.col("g"))
	return PA.outline(img)


static func watering_can() -> Image:
	var img := PA.new_img(21, 15)
	# body: lit left, shaded right, rim band, rivets
	for y in range(5, 13):
		for x in range(5, 15):
			var c := PA.col("u")
			if x < 7:
				c = PA.col("a")
			elif x > 12:
				c = PA.col("A")
			PA.px(img, x, y, c)
	PA.rect(img, 5, 5, 10, 1, PA.col("a").lightened(0.2))
	PA.rect(img, 5, 9, 10, 1, PA.col("A"))
	PA.px(img, 6, 10, PA.col("W"))
	PA.px(img, 13, 10, PA.col("W"))
	PA.rect(img, 5, 12, 10, 1, PA.col("n"))
	# spout + rose head
	PA.line(img, 15, 10, 19, 5, PA.col("u"))
	PA.line(img, 15, 11, 19, 6, PA.col("A"))
	PA.rect(img, 18, 3, 3, 3, PA.col("g"))
	PA.px(img, 18, 3, PA.col("W"))
	# handle arc
	PA.ring(img, 10.0, 5.0, 3.6, 1.0, PA.col("A"))
	PA.px(img, 8, 2, PA.col("a"))
	# back handle
	PA.line(img, 5, 6, 2, 9, PA.col("A"))
	PA.px(img, 2, 10, PA.col("A"))
	# water drip
	PA.px(img, 20, 8, PA.col("u").lightened(0.3))
	return PA.outline(img)


# ------------------------------------------------------------------ ambient life sprites

static func _lean_off(lean: String) -> float:
	return -1.0 if lean == "l" else (1.0 if lean == "r" else 0.0)


static func _ambient(n: String) -> Image:
	var parts := n.split("_")
	var kind: String = parts[0]
	match kind:
		"tuft":
			return _amb_tuft(int(parts[1]), _lean_off(parts[2]))
		"tall":
			return _amb_tall(_lean_off(parts[1]))
		"flower":
			return _amb_flower(int(parts[1]), _lean_off(parts[2]))
		"sunflower":
			return _amb_sunflower(_lean_off(parts[1]))
		"butterfly":
			return _amb_butterfly(int(parts[1]), int(parts[2]))
		"bee":
			return _amb_bee(int(parts[1]))
		"leaf":
			return _amb_leaf(int(parts[1]))
		"cloud":
			return _amb_cloud(int(parts[1]))
	return null


## Draws one blade from (bx, base_y) up `ht` pixels, bending by `lean` towards the tip.
static func _blade(img: Image, bx: int, base_y: int, ht: int, lean: float, dk: Color, md: Color, lt: Color) -> void:
	for i in ht:
		var f := float(i) / float(maxi(1, ht - 1))
		var x := bx + int(roundf(lean * f * f * 1.6))
		var c := dk if f < 0.34 else (md if f < 0.75 else lt)
		PA.px(img, x, base_y - i, c)


static func _amb_tuft(v: int, lean: float) -> Image:
	var img := PA.new_img(8, 7)
	var dk := PA.col("f")
	var md := PA.col("E")
	var lt := PA.col("e")
	var specs := [[[2, 4], [3, 6], [4, 5], [5, 3]], [[1, 3], [3, 5], [4, 6], [6, 4]], [[2, 5], [4, 6], [5, 4]]]
	for b in specs[v % 3]:
		_blade(img, int(b[0]), 6, int(b[1]), lean, dk, md, lt)
	return img


static func _amb_tall(lean: float) -> Image:
	var img := PA.new_img(10, 11)
	var dk := PA.col("f")
	var md := PA.col("E")
	var lt := PA.col("e").lerp(PA.col("y"), 0.25)
	for b in [[2, 7], [3, 10], [5, 9], [6, 6], [7, 8]]:
		_blade(img, int(b[0]), 10, int(b[1]), lean, dk, md, lt)
	# seed head on the tallest blade
	var tx := 3 + int(roundf(lean * 1.6))
	PA.px(img, tx, 0, PA.col("t"))
	return img


static func _amb_flower(k: int, lean: float) -> Image:
	var img := PA.new_img(7, 8)
	var off := int(roundf(lean))
	# stem + leaf
	PA.px(img, 3, 7, PA.col("f"))
	PA.px(img, 3, 6, PA.col("E"))
	PA.px(img, 3 + off, 5, PA.col("E"))
	PA.px(img, 3 + off, 4, PA.col("E"))
	PA.px(img, 2, 6, PA.col("e"))
	var hx := 3 + off
	var hy := 2
	match k:
		0:  # daisy
			PA.px(img, hx - 1, hy, PA.col("w"))
			PA.px(img, hx + 1, hy, PA.col("w"))
			PA.px(img, hx, hy - 1, PA.col("w"))
			PA.px(img, hx, hy + 1, PA.col("W"))
			PA.px(img, hx, hy, PA.col("y"))
		1:  # buttercup
			PA.px(img, hx, hy, PA.col("y"))
			PA.px(img, hx + 1, hy, PA.col("y").lightened(0.3))
			PA.px(img, hx, hy + 1, PA.col("Y"))
			PA.px(img, hx + 1, hy + 1, PA.col("Y"))
		2:  # bluebell
			PA.px(img, hx, hy - 1, PA.col("u"))
			PA.px(img, hx, hy, PA.col("A"))
			PA.px(img, hx + 1, hy, PA.col("u"))
			PA.px(img, hx, hy + 1, PA.col("A"))
		_:  # poppy
			PA.px(img, hx, hy, PA.col("r"))
			PA.px(img, hx + 1, hy, PA.col("r").lightened(0.2))
			PA.px(img, hx - 1, hy, PA.col("R"))
			PA.px(img, hx, hy - 1, PA.col("r"))
			PA.px(img, hx, hy + 1, PA.col("k"))
	return img


static func _amb_sunflower(lean: float) -> Image:
	var img := PA.new_img(17, 34)
	var off := int(roundf(lean))
	# stem (bends near the top)
	for y in range(13, 34):
		var x := 8 + (off if y < 20 else 0)
		PA.px(img, x, y, PA.col("E"))
		PA.px(img, x + 1, y, PA.col("f"))
	# leaves
	PA.ellipse(img, 5.0, 22.0, 3.2, 1.6, PA.col("E"))
	PA.ellipse(img, 4.5, 21.5, 2.0, 0.9, PA.col("e"))
	PA.ellipse(img, 12.0, 27.0, 3.2, 1.6, PA.col("f"))
	PA.ellipse(img, 12.0, 26.5, 2.0, 0.9, PA.col("E"))
	# head: petals ring + seed disc with sheen
	var hx := 8.5 + off
	var hy := 8.0
	for i in 12:
		var a := TAU * i / 12.0
		PA.disk(img, hx + cos(a) * 4.6, hy + sin(a) * 4.6, 1.8, PA.col("y") if i % 2 == 0 else PA.col("y").darkened(0.08))
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		PA.px(img, int(hx + cos(a) * 5.6), int(hy + sin(a) * 5.6), PA.col("Y"))
	PA.disk(img, hx, hy, 3.2, PA.col("B"))
	PA.disk(img, hx - 0.5, hy - 0.5, 1.8, PA.col("b"))
	for d in [Vector2i(-1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-2, 1), Vector2i(1, -2)]:
		PA.px(img, int(hx) + d.x, int(hy) + d.y, PA.col("T"))
	PA.px(img, int(hx) - 2, int(hy) - 4, PA.col("w").lerp(PA.col("y"), 0.4))
	return PA.outline(img)


static func _amb_butterfly(c: int, f: int) -> Image:
	var pal := [["y", "Y"], ["p", "P"], ["u", "A"], ["w", "W"]]
	var hi := PA.col(pal[c % 4][0])
	var lo := PA.col(pal[c % 4][1])
	var k := PA.col("k")
	var img := PA.new_img(5, 4)
	if f == 0:
		PA.px(img, 0, 0, hi)
		PA.px(img, 4, 0, hi)
		PA.px(img, 0, 1, hi)
		PA.px(img, 1, 1, hi)
		PA.px(img, 3, 1, hi)
		PA.px(img, 4, 1, hi)
		PA.px(img, 1, 2, lo)
		PA.px(img, 3, 2, lo)
	else:
		PA.px(img, 1, 0, hi)
		PA.px(img, 3, 0, hi)
		PA.px(img, 1, 1, lo)
		PA.px(img, 3, 1, lo)
	PA.px(img, 2, 0, k)
	PA.px(img, 2, 1, k)
	PA.px(img, 2, 2, k)
	return img


static func _amb_bee(f: int) -> Image:
	var img := PA.new_img(6, 4)
	var w := Color(1, 1, 1, 0.85)
	if f == 0:
		PA.px(img, 2, 0, w)
		PA.px(img, 3, 0, w)
	else:
		PA.px(img, 1, 1, w)
		PA.px(img, 4, 1, w)
	PA.px(img, 1, 2, PA.col("y"))
	PA.px(img, 2, 2, PA.col("k"))
	PA.px(img, 3, 2, PA.col("y"))
	PA.px(img, 4, 2, PA.col("k"))
	PA.px(img, 2, 3, PA.col("Y"))
	PA.px(img, 3, 3, PA.col("k"))
	PA.px(img, 5, 2, PA.col("k"))
	return img


static func _amb_leaf(f: int) -> Image:
	var img := PA.new_img(5, 4)
	if f == 0:
		PA.px(img, 0, 1, PA.col("E"))
		PA.px(img, 1, 1, PA.col("e"))
		PA.px(img, 2, 1, PA.col("e"))
		PA.px(img, 3, 2, PA.col("E"))
		PA.px(img, 1, 2, PA.col("f"))
		PA.px(img, 2, 2, PA.col("E"))
	else:
		PA.px(img, 2, 0, PA.col("e"))
		PA.px(img, 2, 1, PA.col("e"))
		PA.px(img, 1, 2, PA.col("E"))
		PA.px(img, 2, 2, PA.col("f"))
		PA.px(img, 2, 3, PA.col("E"))
	return img


## Soft drifting cloud shadow: union of blobs, flat translucent fill with a dithered rim.
static func _amb_cloud(i: int) -> Image:
	var w := 168
	var h := 84
	var img := PA.new_img(w, h)
	var r := RandomNumberGenerator.new()
	r.seed = 6100 + i * 71
	var blobs: Array = []
	for k in 6 + i:
		blobs.append(Vector3(r.randf_range(34, w - 34), r.randf_range(30, h - 30), r.randf_range(16, 30)))
	var core := Color(0.05, 0.08, 0.12, 0.12)
	var rim := Color(0.05, 0.08, 0.12, 0.06)
	var field := PackedFloat32Array()
	field.resize(w * h)
	field.fill(-1e9)
	for b in blobs:
		var bb: Vector3 = b
		var y0 := maxi(0, int(bb.y - bb.z / 1.25) - 1)
		var y1 := mini(h - 1, int(bb.y + bb.z / 1.25) + 1)
		var x0 := maxi(0, int(bb.x - bb.z) - 1)
		var x1 := mini(w - 1, int(bb.x + bb.z) + 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var d := bb.z - Vector2(x - bb.x, (y - bb.y) * 1.25).length()
				var i2 := y * w + x
				if d > field[i2]:
					field[i2] = d
	for y in h:
		for x in w:
			var best := field[y * w + x]
			if best > 3.0:
				img.set_pixel(x, y, core)
			elif best > 0.0 and (x + y) % 2 == 0:
				img.set_pixel(x, y, rim)
	return img
