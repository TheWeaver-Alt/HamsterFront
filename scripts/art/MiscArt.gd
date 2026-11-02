extends RefCounted
## Props, pickups and icons.
## Names:
##   seed, seed_h          striped sunflower seed pickup (vertical / horizontal)
##   seed_icon             HUD seed icon
##   silo_bucket           The Great Silo plastic bucket (seed mound is drawn live)
##   obstacle_pot, obstacle_rock, obstacle_gnome, obstacle_can
##   icon_heart, icon_heat, icon_skull, icon_wave

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
	var w := 56
	var h := 44
	var img := PA.new_img(w, h)
	var top_w := 50.0
	var bot_w := 40.0
	var blue := PA.col("A")
	for y in range(4, h - 1):
		var t := float(y - 4) / float(h - 5)
		var row_w := lerpf(top_w, bot_w, t)
		var x0 := int(roundf(w / 2.0 - row_w / 2.0))
		var x1 := int(roundf(w / 2.0 + row_w / 2.0))
		for x in range(x0, x1):
			var c := blue
			if x < x0 + 3:
				c = PA.col("a")
			elif x > x1 - 4:
				c = PA.col("n")
			elif (x - x0) % 9 == 0:
				c = blue.darkened(0.12)
			img.set_pixel(x, y, c)
	# rim
	PA.rect(img, 2, 2, w - 4, 4, PA.col("a"))
	PA.rect(img, 2, 5, w - 4, 1, PA.col("A").darkened(0.2))
	PA.rect(img, 3, 2, w - 6, 1, PA.col("w"))
	# label sticker
	PA.rect(img, 15, 17, 26, 13, PA.col("r"))
	PA.rect(img, 15, 17, 26, 1, PA.col("r").lightened(0.3))
	PA.rect(img, 15, 29, 26, 1, PA.col("R"))
	PA.stamp_text(img, 18, 19, "SEEDS", PA.col("w"))
	# little seed logo
	PA.px(img, 27, 26, PA.col("s"))
	PA.px(img, 28, 25, PA.col("s"))
	PA.px(img, 28, 26, PA.col("S"))
	PA.px(img, 29, 26, PA.col("s"))
	PA.px(img, 28, 27, PA.col("s"))
	# scuffs / rat bite marks
	PA.px(img, 9, 34, PA.col("n"))
	PA.px(img, 10, 35, PA.col("n"))
	PA.px(img, 44, 12, PA.col("n"))
	return PA.outline(img)


static func pot() -> Image:
	var img := PA.new_img(18, 22)
	# leaves
	PA.disk(img, 9, 6, 5.0, PA.col("E"))
	PA.disk(img, 5, 7, 3.2, PA.col("f"))
	PA.disk(img, 13, 6, 3.4, PA.col("e"))
	PA.disk(img, 9, 3, 2.5, PA.col("e"))
	PA.px(img, 9, 2, PA.col("p"))
	PA.px(img, 6, 5, PA.col("p"))
	PA.px(img, 12, 4, PA.col("y"))
	# terracotta pot
	for y in range(10, 21):
		var t := float(y - 10) / 10.0
		var hw := lerpf(7.0, 5.0, t)
		for x in range(int(9 - hw), int(9 + hw)):
			var c := PA.col("i").darkened(0.25)
			if x < int(9 - hw) + 2:
				c = PA.col("i")
			elif x > int(9 + hw) - 3:
				c = PA.col("O")
			PA.px(img, x, y, c)
	PA.rect(img, 1, 10, 16, 3, PA.col("i"))
	PA.rect(img, 1, 12, 16, 1, PA.col("O"))
	return PA.outline(img)


static func rock() -> Image:
	var img := PA.new_img(18, 14)
	PA.ellipse(img, 9, 8, 7.5, 5.0, PA.col("H"))
	PA.ellipse(img, 8, 7, 6.0, 4.0, PA.col("h"))
	PA.disk(img, 6, 5, 2.0, PA.col("l"))
	PA.px(img, 12, 9, PA.col("H"))
	PA.px(img, 13, 8, PA.col("H"))
	PA.px(img, 4, 10, PA.col("f"))
	PA.px(img, 5, 11, PA.col("E"))
	return PA.outline(img)


static func gnome() -> Image:
	var img := PA.new_img(14, 22)
	# hat
	for y in range(1, 8):
		var hw := (y - 1) * 0.6 + 0.5
		for x in range(int(7 - hw), int(7 + hw) + 1):
			PA.px(img, x, y, PA.col("r"))
	PA.px(img, 6, 3, PA.col("r").lightened(0.3))
	# face
	PA.disk(img, 7, 9, 2.6, PA.col("c"))
	PA.px(img, 6, 9, PA.col("k"))
	PA.px(img, 8, 9, PA.col("k"))
	PA.px(img, 7, 10, PA.col("p"))
	# beard
	PA.disk(img, 7, 12.5, 3.0, PA.col("w"))
	PA.px(img, 7, 15, PA.col("w"))
	# body
	PA.rect(img, 3, 14, 9, 5, PA.col("A"))
	PA.rect(img, 3, 16, 9, 1, PA.col("B"))
	PA.rect(img, 3, 19, 4, 2, PA.col("B"))
	PA.rect(img, 8, 19, 4, 2, PA.col("B"))
	return PA.outline(img)


static func watering_can() -> Image:
	var img := PA.new_img(20, 14)
	PA.rect(img, 5, 4, 9, 8, PA.col("u"))
	PA.rect(img, 5, 4, 9, 1, PA.col("a"))
	PA.rect(img, 12, 4, 2, 8, PA.col("A"))
	PA.line(img, 14, 9, 18, 4, PA.col("u"))
	PA.line(img, 14, 10, 18, 5, PA.col("A"))
	PA.rect(img, 17, 2, 2, 3, PA.col("g"))
	PA.line(img, 5, 5, 2, 8, PA.col("A"))
	PA.px(img, 2, 9, PA.col("A"))
	PA.ring(img, 9.5, 4, 3.0, 1.0, PA.col("A"))
	return PA.outline(img)
