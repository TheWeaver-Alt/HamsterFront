extends RefCounted
## Under-Scurrier sprites. All face RIGHT; entities flip_h when moving left.
## Names:
##   rat_squeaker_0/1    Clan-Squeaker walk frames (bent fork, glowing eyes)
##   rat_squeaker_trip   tripped over a tail, flat on its face
##   rat_squeaker_ball   curled-up squeaker (being thrown by a Rat-Ogre)

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	match n:
		"rat_squeaker_0":
			return squeaker(0)
		"rat_squeaker_1":
			return squeaker(1)
		"rat_squeaker_trip":
			return squeaker_trip()
		"rat_squeaker_ball":
			return squeaker_ball()
	return null


static func squeaker(frame: int) -> Image:
	var img := PA.new_img(20, 14)
	var ox := 1
	var oy := 1
	var fur := PA.col("m")
	var dark := PA.col("M")
	var pink := PA.col("q")
	# tail (wiggles per frame)
	var ty := 0 if frame == 0 else 1
	PA.px(img, ox + 0, oy + 3 + ty, pink)
	PA.px(img, ox + 1, oy + 4 + ty, pink)
	PA.px(img, ox + 2, oy + 5, pink)
	PA.px(img, ox + 3, oy + 6, pink)
	PA.px(img, ox + 4, oy + 6, pink)
	# body
	PA.ellipse(img, ox + 8, oy + 6.5, 4.6, 3.1, fur)
	PA.rect(img, ox + 5, oy + 8, 7, 1, dark)
	# hunched back highlight
	PA.px(img, ox + 7, oy + 3, fur.lightened(0.2))
	PA.px(img, ox + 8, oy + 3, fur.lightened(0.2))
	# head + snout
	PA.disk(img, ox + 12, oy + 5, 2.7, fur)
	PA.px(img, ox + 14, oy + 5, fur)
	PA.px(img, ox + 15, oy + 6, PA.col("p"))
	# ear
	PA.disk(img, ox + 11, oy + 2.4, 1.4, pink)
	PA.px(img, ox + 11, oy + 2, dark)
	# glowing warp eye
	PA.px(img, ox + 13, oy + 4, PA.col("z"))
	# whiskers
	PA.px(img, ox + 15, oy + 4, PA.col("W"))
	# legs
	if frame == 0:
		PA.px(img, ox + 6, oy + 10, dark)
		PA.px(img, ox + 7, oy + 10, dark)
		PA.px(img, ox + 10, oy + 10, dark)
		PA.px(img, ox + 11, oy + 10, dark)
	else:
		PA.px(img, ox + 5, oy + 10, dark)
		PA.px(img, ox + 8, oy + 10, dark)
		PA.px(img, ox + 9, oy + 10, dark)
		PA.px(img, ox + 12, oy + 10, dark)
	# bent fork held forward
	var fy := 0 if frame == 0 else 1
	PA.line(img, ox + 11, oy + 8, ox + 15, oy + 6 + fy, PA.col("W"))
	PA.px(img, ox + 16, oy + 5 + fy, PA.col("W"))
	PA.px(img, ox + 17, oy + 5 + fy, PA.col("g"))
	PA.px(img, ox + 16, oy + 7 + fy, PA.col("W"))
	PA.px(img, ox + 17, oy + 7 + fy, PA.col("g"))
	PA.px(img, ox + 12, oy + 8, PA.col("q"))  # paw
	return PA.outline(img)


static func squeaker_trip() -> Image:
	var img := PA.new_img(20, 10)
	var fur := PA.col("m")
	PA.ellipse(img, 9, 6, 5.0, 2.4, fur)
	PA.disk(img, 14, 6.5, 2.2, fur)
	PA.px(img, 16, 7, PA.col("p"))
	PA.px(img, 14, 5, PA.col("k"))      # x eye
	PA.px(img, 15, 6, PA.col("k"))
	PA.px(img, 13, 3, PA.col("q"))
	PA.line(img, 1, 6, 4, 7, PA.col("q"))
	# fork flung away
	PA.px(img, 18, 2, PA.col("W"))
	PA.px(img, 17, 3, PA.col("W"))
	PA.px(img, 6, 8, PA.col("M"))
	PA.px(img, 9, 8, PA.col("M"))
	return PA.outline(img)


static func squeaker_ball() -> Image:
	var img := PA.new_img(12, 12)
	PA.disk(img, 6, 6, 4.4, PA.col("m"))
	PA.disk(img, 6, 6, 2.2, PA.col("M"))
	PA.px(img, 8, 4, PA.col("z"))
	PA.line(img, 2, 9, 4, 10, PA.col("q"))
	return PA.outline(img)
