extends RefCounted
## Backyard ground tiles (16x16). Names: tile_grass_0..3, tile_flowers_0..2, tile_path_0..2,
## tile_pad, tile_burrow, tile_fence, tile_dirt.

const PA := preload("res://autoloads/PixelArt.gd")
const S := 16


static func make(n: String) -> Image:
	if n.begins_with("tile_grass_"):
		return grass(int(n.substr(11)))
	if n.begins_with("tile_flowers_"):
		return flowers(int(n.substr(13)))
	if n.begins_with("tile_path_"):
		return path(int(n.substr(10)))
	match n:
		"tile_pad":
			return pad()
		"tile_burrow":
			return burrow()
		"tile_fence":
			return fence()
		"tile_dirt":
			return dirt()
	return null


static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


static func grass(v: int) -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("E"))
	var r := _rng(1000 + v * 97)
	for i in 22:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("f"))
	for i in 12:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("e"))
	# grass blades: light tip over dark root
	for i in 4 + v:
		var x := r.randi_range(1, 14)
		var y := r.randi_range(2, 14)
		PA.px(img, x, y, PA.col("e"))
		PA.px(img, x, y + 1, PA.col("f"))
		if r.randf() < 0.5:
			PA.px(img, x + 1, y - 1, PA.col("e"))
	if v == 3:
		# pebbles
		PA.px(img, 4, 11, PA.col("h"))
		PA.px(img, 5, 11, PA.col("l"))
		PA.px(img, 11, 5, PA.col("h"))
	return img


static func flowers(v: int) -> Image:
	var img := grass(v)
	var r := _rng(5000 + v * 31)
	var petal_cols := ["p", "w", "y"]
	for i in 2 + v % 2:
		var x := r.randi_range(3, 12)
		var y := r.randi_range(3, 12)
		var pc := PA.col(petal_cols[(v + i) % 3])
		PA.px(img, x - 1, y, pc)
		PA.px(img, x + 1, y, pc)
		PA.px(img, x, y - 1, pc)
		PA.px(img, x, y + 1, pc)
		PA.px(img, x, y, PA.col("y") if pc != PA.col("y") else PA.col("O"))
		PA.px(img, x, y + 2, PA.col("f"))
	return img


static func path(v: int) -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("h"))
	var mortar := PA.col("H")
	var r := _rng(2000 + v * 53)
	# irregular flagstones separated by mortar lines
	var split_y := 6 + v * 2
	for x in S:
		PA.px(img, x, split_y, mortar)
		PA.px(img, x, 15, mortar)
	var vx1 := 4 + v * 3
	var vx2 := 11 - v
	for y in split_y:
		PA.px(img, vx1, y, mortar)
	for y in range(split_y, 16):
		PA.px(img, vx2, y, mortar)
	for y in S:
		PA.px(img, 15, y, mortar)
	# highlights on stone top-left edges
	for x in S:
		if img.get_pixel(x, split_y + 1) != mortar:
			PA.px(img, x, split_y + 1, PA.col("l"))
		if img.get_pixel(x, 0) != mortar:
			PA.px(img, x, 0, PA.col("l"))
	# speckles & cracks
	for i in 10:
		PA.px(img, r.randi_range(0, 14), r.randi_range(0, 14), PA.col("l") if r.randf() < 0.5 else PA.col("H"))
	if v == 1:
		PA.line(img, 7, 9, 9, 12, PA.col("H"))
	# moss in mortar
	for i in 3:
		var mx := r.randi_range(0, 15)
		PA.px(img, mx, split_y, PA.col("f"))
	return img


static func pad() -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("b"))
	var dark := PA.col("B")
	# frame
	for i in S:
		PA.px(img, i, 0, dark)
		PA.px(img, i, 15, dark)
		PA.px(img, 0, i, dark)
		PA.px(img, 15, i, dark)
	# planks
	for x in range(1, 15):
		PA.px(img, x, 5, dark)
		PA.px(img, x, 10, dark)
		PA.px(img, x, 1, PA.col("t"))
		PA.px(img, x, 6, PA.col("t"))
		PA.px(img, x, 11, PA.col("t"))
	# wood grain
	PA.px(img, 4, 3, dark)
	PA.px(img, 5, 3, dark)
	PA.px(img, 10, 8, dark)
	PA.px(img, 7, 13, dark)
	PA.px(img, 8, 13, dark)
	# nails
	for p in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
		PA.px(img, p.x, p.y, PA.col("W"))
	# faint build marker
	PA.px(img, 7, 7, PA.col("y"))
	PA.px(img, 8, 7, PA.col("y"))
	PA.px(img, 7, 8, PA.col("y"))
	PA.px(img, 8, 8, PA.col("y"))
	return img


static func burrow() -> Image:
	var img := grass(1)
	PA.disk(img, 8, 8.5, 7.5, PA.col("T"))
	PA.disk(img, 8, 8.5, 6.2, PA.col("b"))
	PA.disk(img, 8, 9, 4.8, PA.col("B"))
	PA.disk(img, 8, 9.5, 3.8, PA.col("k"))
	# dirt clods
	PA.px(img, 2, 4, PA.col("T"))
	PA.px(img, 13, 3, PA.col("T"))
	PA.px(img, 14, 12, PA.col("b"))
	PA.px(img, 1, 12, PA.col("b"))
	# rim highlight
	PA.px(img, 6, 3, PA.col("t"))
	PA.px(img, 7, 2, PA.col("t"))
	PA.px(img, 9, 2, PA.col("t"))
	return img


static func fence() -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("f"))
	# pickets 3px wide with 1px gaps
	for p in 4:
		var x0 := p * 4
		for y in range(1, 16):
			PA.px(img, x0, y, PA.col("t"))
			PA.px(img, x0 + 1, y, PA.col("b"))
			PA.px(img, x0 + 2, y, PA.col("B"))
		# pointed tip
		PA.px(img, x0 + 1, 0, PA.col("b"))
		PA.px(img, x0, 1, PA.col("f"))
		PA.px(img, x0 + 2, 1, PA.col("f"))
	# rails
	for x in S:
		PA.px(img, x, 5, PA.col("B"))
		PA.px(img, x, 11, PA.col("B"))
		PA.px(img, x, 4, PA.col("T"))
		PA.px(img, x, 10, PA.col("T"))
	return img


static func dirt() -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("b"))
	var r := _rng(3131)
	for i in 30:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("B") if r.randf() < 0.6 else PA.col("T"))
	return img
