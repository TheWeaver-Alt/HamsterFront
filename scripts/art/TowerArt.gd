extends RefCounted
## Tower sprites. Heads that rotate are drawn pointing RIGHT around their centre.
## Names:
##   tower_base           wooden crate plinth every tower sits on
##   tower_gatling        Sunflower Gatling head (petals + 3 barrels)
##   tower_rubble         destroyed-tower debris
##   shell                single sunflower hull (ground decal)

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	match n:
		"tower_base":
			return base()
		"tower_gatling":
			return gatling()
		"tower_rubble":
			return rubble()
		"shell":
			return shell()
	return null


static func base() -> Image:
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
	return PA.outline(img)


static func gatling() -> Image:
	var img := PA.new_img(22, 22)
	var c := Vector2(10, 11)
	# petals
	for i in 10:
		var a := TAU * i / 10.0
		var p := c + Vector2(cos(a), sin(a)) * 5.6
		PA.disk(img, p.x, p.y, 2.3, PA.col("y"))
	for i in 10:
		var a := TAU * (i + 0.5) / 10.0
		var p := c + Vector2(cos(a), sin(a)) * 6.0
		PA.px(img, int(p.x), int(p.y), PA.col("Y"))
	# seed-head centre
	PA.disk(img, c.x, c.y, 4.0, PA.col("B"))
	for d in [Vector2i(-2, -1), Vector2i(1, -2), Vector2i(0, 1), Vector2i(-1, 2), Vector2i(2, 1)]:
		PA.px(img, int(c.x) + d.x, int(c.y) + d.y, PA.col("b"))
	# gatling barrels
	PA.rect(img, 12, 8, 8, 2, PA.col("g"))
	PA.rect(img, 12, 10, 9, 2, PA.col("W"))
	PA.rect(img, 12, 12, 8, 2, PA.col("g"))
	PA.rect(img, 12, 10, 9, 1, PA.col("w"))
	PA.rect(img, 11, 7, 2, 8, PA.col("G"))
	return PA.outline(img)


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
