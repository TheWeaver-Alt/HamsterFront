extends RefCounted
## WHIRLYBIRD-Z, "The Whirly-Gig": a glass pod with the pilot inside, slung under a rotor frame.
## All parts face RIGHT; the drone is symmetrical enough that the visual only mirrors the gun pod.
## Names:
##   drone_pod          glass bubble over a steel base (22x18); the pilot's head is drawn under it
##   drone_pod_crack    crack overlay (22x18)
##   drone_frame        the rotor frame: arms, a hub and two motors (34x6)
##   drone_rotor_0..3   a spinning rotor, 4 blur frames (14x5)
##   drone_skids        landing skids (20x5)

const PA := preload("res://autoloads/PixelArt.gd")


static func make(n: String) -> Image:
	if n.begins_with("drone_rotor_"):
		return _rotor(int(n.substr(12)))
	match n:
		"drone_pod":
			return PA.outline(_pod(), PA.col("k"))
		"drone_pod_crack":
			return _pod_crack()
		"drone_frame":
			return PA.outline(_frame(), PA.col("k"))
		"drone_skids":
			return PA.outline(_skids(), PA.col("k"))
	return null


static func _c(k: String) -> Color:
	return PA.col(k)


static func _pod() -> Image:
	var img := PA.new_img(22, 18)
	var glass := _c("a")
	PA.disk(img, 11.0, 8.5, 8.4, Color(glass.r, glass.g, glass.b, 0.2))
	PA.ring(img, 11.0, 8.5, 8.4, 1.3, _c("w"))
	# steel base the bubble sits in
	PA.rect(img, 6, 14, 10, 3, _c("g"))
	PA.rect(img, 6, 16, 10, 1, _c("G"))
	PA.rect(img, 6, 14, 10, 1, _c("W"))
	# glints
	for p in [[5, 4], [6, 3], [7, 3], [4, 6]]:
		PA.px(img, p[0], p[1], _c("w"))
	PA.px(img, 16, 12, Color(1, 1, 1, 0.6))
	return img


static func _pod_crack() -> Image:
	var img := PA.new_img(22, 18)
	var k := _c("k")
	PA.line(img, 8, 3, 11, 8, k)
	PA.line(img, 11, 8, 9, 12, k)
	PA.line(img, 11, 8, 15, 7, k)
	PA.px(img, 13, 10, _c("w"))
	return img


static func _frame() -> Image:
	var img := PA.new_img(34, 6)
	PA.rect(img, 5, 2, 24, 2, _c("G"))
	PA.rect(img, 5, 2, 24, 1, _c("g"))
	PA.disk(img, 17.0, 3.0, 3.0, _c("g"))
	PA.px(img, 16, 2, _c("W"))
	for mx in [3, 31]:
		PA.disk(img, mx + 0.0, 3.2, 3.0, _c("g"))
		PA.disk(img, mx + 0.0, 3.2, 1.4, _c("G"))
		PA.px(img, mx - 1, 1, _c("W"))
	return img


static func _rotor(frame: int) -> Image:
	var img := PA.new_img(14, 5)
	PA.ellipse(img, 7.0, 2.5, 7.0, 2.1, Color(1, 1, 1, 0.34))
	var blade := Color(0.85, 0.9, 0.95, 0.9)
	match frame % 4:
		0:
			PA.line(img, 0, 2, 13, 2, blade)
		1:
			PA.line(img, 0, 3, 13, 1, blade)
		2:
			PA.line(img, 0, 1, 13, 3, blade)
		_:
			PA.line(img, 1, 4, 12, 0, blade)
	PA.px(img, 7, 2, _c("G"))
	return img


static func _skids() -> Image:
	var img := PA.new_img(20, 5)
	for sx in [2, 12]:
		PA.rect(img, sx, 4, 6, 1, _c("g"))
		PA.rect(img, sx + 1, 1, 1, 3, _c("G"))
		PA.rect(img, sx + 4, 1, 1, 3, _c("G"))
	return img
