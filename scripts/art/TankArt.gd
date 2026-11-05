extends RefCounted
## HOWITZER-9, "The Biscuit Tin": a gold biscuit-tin hull on rubber treads, a turret dome and a long barrel.
## All parts face RIGHT (the visual mirrors them by facing).
## Names:
##   tank_treads_0..3   tread band, 4 scroll frames (38x9)
##   tank_hull          the tin: red lid, gold body, label, headlight (34x13)
##   tank_hull_crack    crack overlay for a badly damaged hull (34x13)
##   tank_hatch         the lip of the hatch the pilot peeks out of (12x4)
##   tank_turret        turret dome (14x9, symmetrical, so it can stay unrotated)
##   tank_barrel        barrel with a muzzle brake (18x5), pivot at its left end

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	if n.begins_with("tank_treads_"):
		return PA.outline(_treads(int(n.substr(12))), PA.col("k"))
	match n:
		"tank_hull":
			return PA.outline(_hull(), PA.col("k"))
		"tank_hull_crack":
			return _hull_crack()
		"tank_hatch":
			return PA.outline(_hatch(), PA.col("k"))
		"tank_turret":
			return PA.outline(_turret(), PA.col("k"))
		"tank_barrel":
			return PA.outline(_barrel(), PA.col("k"))
	return null


static func _c(k: String) -> Color:
	return PA.col(k)


static func _clear(img: Image, x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, Color(0, 0, 0, 0))


static func _treads(frame: int) -> Image:
	var img := PA.new_img(38, 9)
	PA.rect(img, 3, 1, 32, 7, _c("K"))
	PA.disk(img, 5.0, 4.5, 3.8, _c("K"))
	PA.disk(img, 33.0, 4.5, 3.8, _c("K"))
	# links crawl along the top and bottom edge
	for x in range(2, 36):
		if (x + frame * 2) % 6 < 3:
			PA.px(img, x, 1, _c("g"))
			PA.px(img, x, 7, _c("G"))
	# road wheels and the two big end wheels
	for wx in [10, 16, 21, 27]:
		PA.disk(img, wx + 0.5, 4.5, 2.2, _c("G"))
		PA.px(img, wx, 4, _c("W"))
	for wx in [5, 33]:
		PA.disk(img, wx + 0.5, 4.5, 2.6, _c("g"))
		PA.px(img, wx, 4, _c("W"))
		PA.px(img, wx, 3, _c("w"))
	return img


static func _hull() -> Image:
	var img := PA.new_img(34, 13)
	PA.rect(img, 0, 3, 32, 9, _c("y"))
	PA.rect(img, 0, 10, 32, 2, _c("Y"))
	PA.rect(img, 29, 3, 3, 9, _c("Y"))
	for yy in range(4, 9):
		PA.px(img, 1, yy, _c("w"))
	# the red lid, with rivets
	PA.rect(img, 0, 0, 32, 3, _c("r"))
	PA.rect(img, 0, 2, 32, 1, _c("R"))
	PA.rect(img, 0, 0, 32, 1, _c("p"))
	for rx in [3, 9, 15, 21, 27, 30]:
		PA.px(img, rx, 1, _c("R"))
	# a sloped nose: chamfer the bottom-right corner
	for p in [[31, 11], [30, 11], [31, 10], [31, 9], [29, 11]]:
		_clear(img, p[0], p[1])
	# biscuit label: white card with a cookie on it
	PA.rect(img, 11, 5, 14, 5, _c("w"))
	PA.rect(img, 11, 9, 14, 1, _c("c"))
	PA.disk(img, 15.0, 7.5, 2.0, _c("O"))
	PA.px(img, 14, 7, _c("B"))
	PA.px(img, 16, 8, _c("B"))
	PA.px(img, 15, 6, _c("B"))
	PA.rect(img, 19, 6, 4, 1, _c("r"))
	PA.rect(img, 19, 8, 3, 1, _c("r"))
	# headlight
	PA.disk(img, 30.0, 6.0, 1.4, _c("I"))
	PA.px(img, 30, 6, _c("w"))
	return img


static func _hull_crack() -> Image:
	var img := PA.new_img(34, 13)
	var k := _c("k")
	PA.line(img, 12, 3, 15, 7, k)
	PA.line(img, 15, 7, 13, 11, k)
	PA.line(img, 15, 7, 19, 6, k)
	PA.line(img, 25, 3, 23, 6, k)
	PA.px(img, 18, 5, _c("R"))
	PA.px(img, 23, 8, _c("R"))
	return img


static func _hatch() -> Image:
	var img := PA.new_img(12, 4)
	PA.rect(img, 0, 0, 12, 1, _c("W"))
	PA.rect(img, 1, 1, 10, 1, _c("g"))
	PA.rect(img, 2, 2, 8, 1, _c("G"))
	PA.rect(img, 3, 3, 6, 1, _c("G"))
	return img


static func _turret() -> Image:
	var img := PA.new_img(14, 9)
	PA.ellipse(img, 7.0, 6.5, 6.5, 2.2, _c("G"))
	PA.disk(img, 7.0, 4.2, 4.2, _c("g"))
	PA.rect(img, 2, 4, 10, 3, _c("g"))
	PA.rect(img, 3, 6, 8, 1, _c("G"))
	for p in [[5, 1], [6, 1], [7, 1], [4, 2], [5, 2]]:
		PA.px(img, p[0], p[1], _c("W"))
	PA.px(img, 10, 3, _c("G"))
	PA.px(img, 11, 4, _c("G"))
	return img


static func _barrel() -> Image:
	var img := PA.new_img(18, 5)
	PA.rect(img, 0, 0, 3, 5, _c("G"))
	PA.rect(img, 3, 1, 12, 3, _c("g"))
	PA.rect(img, 3, 1, 12, 1, _c("W"))
	PA.rect(img, 3, 3, 12, 1, _c("G"))
	PA.rect(img, 15, 0, 3, 5, _c("G"))
	PA.rect(img, 15, 0, 3, 1, _c("g"))
	PA.px(img, 17, 2, _c("k"))
	PA.px(img, 16, 2, _c("k"))
	return img
