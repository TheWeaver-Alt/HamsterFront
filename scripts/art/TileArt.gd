extends RefCounted
## Backyard ground tiles (16x16). Names: tile_grass_0..3, tile_flowers_0..2, tile_path_0..2,
## tile_pad, tile_burrow, tile_fence, tile_dirt.
## Also used directly by TerrainArt (grass / flowers / path / pad / fence).

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


## A little V-shaped grass tuft: light tip, mid sides, dark root.
static func tuft(img: Image, x: int, y: int, light: Color, mid: Color, dark: Color, tall: bool = false) -> void:
	PA.px(img, x, y, light)
	PA.px(img, x - 1, y + 1, mid)
	PA.px(img, x + 1, y + 1, mid)
	PA.px(img, x, y + 1, dark)
	if tall:
		PA.px(img, x, y - 1, light.lightened(0.15))
		PA.px(img, x - 1, y, mid)


## Low-ground lawn: mottled greens, blade clusters, the odd clover / pebble.
static func grass(v: int) -> Image:
	var img := PA.new_img(S, S)
	var base := PA.col("E")
	var light := PA.col("e")
	var dark := PA.col("f")
	var mid_dk := base.lerp(dark, 0.35)
	var mid_lt := base.lerp(light, 0.35)
	var warm := base.lerp(PA.col("y"), 0.12)
	img.fill(base)
	var r := _rng(1000 + v * 97)
	# soft mottling in small clusters
	for c in 7:
		var cx := r.randi_range(0, 15)
		var cy := r.randi_range(0, 15)
		var col := mid_dk if c % 3 == 0 else (warm if c % 3 == 1 else mid_lt)
		for k in r.randi_range(3, 6):
			PA.px(img, cx + r.randi_range(-1, 1), cy + r.randi_range(-1, 1), col)
	for i in 14:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), dark)
	# blade clusters
	for i in 5 + (v % 2):
		tuft(img, r.randi_range(1, 14), r.randi_range(1, 13), light, mid_lt, dark, r.randf() < 0.35)
	match v:
		1:
			# three-leaf clover
			PA.px(img, 10, 4, light)
			PA.px(img, 11, 5, light)
			PA.px(img, 9, 5, light)
			PA.px(img, 10, 5, dark)
		3:
			# pebbles
			PA.px(img, 4, 11, PA.col("h"))
			PA.px(img, 5, 11, PA.col("l"))
			PA.px(img, 4, 12, PA.col("H"))
			PA.px(img, 11, 5, PA.col("h"))
			PA.px(img, 11, 6, PA.col("H"))
	return img


## Lawn with flowers: 0 daisies, 1 buttercups, 2 clover with pink clover balls.
static func flowers(v: int) -> Image:
	var img := grass(v)
	var r := _rng(5000 + v * 31)
	match v % 3:
		0:
			for i in 3:
				var x := r.randi_range(2, 13)
				var y := r.randi_range(2, 12)
				var w := PA.col("w")
				PA.px(img, x - 1, y, w)
				PA.px(img, x + 1, y, w)
				PA.px(img, x, y - 1, w)
				PA.px(img, x, y + 1, PA.col("W"))
				PA.px(img, x, y, PA.col("y"))
				PA.px(img, x, y + 2, PA.col("f"))
		1:
			for i in 4:
				var x := r.randi_range(2, 13)
				var y := r.randi_range(2, 12)
				PA.px(img, x, y, PA.col("y"))
				PA.px(img, x + 1, y, PA.col("y"))
				PA.px(img, x, y + 1, PA.col("Y"))
				PA.px(img, x + 1, y + 1, PA.col("Y"))
				PA.px(img, x, y + 2, PA.col("f"))
		_:
			for i in 3:
				var x := r.randi_range(2, 12)
				var y := r.randi_range(2, 12)
				var g := PA.col("e")
				PA.px(img, x, y, g)
				PA.px(img, x + 1, y, g)
				PA.px(img, x, y + 1, g)
				PA.px(img, x + 1, y + 1, PA.col("f"))
			var fx := r.randi_range(3, 12)
			var fy := r.randi_range(3, 11)
			PA.px(img, fx, fy, PA.col("p"))
			PA.px(img, fx + 1, fy, PA.col("P"))
			PA.px(img, fx, fy - 1, PA.col("p").lightened(0.3))
			PA.px(img, fx, fy + 1, PA.col("f"))
	return img


## Patio flagstones: irregular stones (Voronoi), bevelled edges, moss in the joints, cracks.
static func path(v: int) -> Image:
	var img := PA.new_img(S, S)
	var r := _rng(2000 + v * 53)
	var seeds: Array = []
	var cols: Array = []
	var stone_cols := [PA.col("h"), PA.col("l").darkened(0.08), PA.col("h").lerp(PA.col("t"), 0.25), PA.col("h").darkened(0.06)]
	var n := 3 + v % 2
	for i in n:
		seeds.append(Vector2(r.randf_range(2, 14), r.randf_range(2, 14)))
		cols.append(stone_cols[(i + v) % stone_cols.size()])
	var joint_mask := PackedByteArray()
	joint_mask.resize(S * S)
	var mortar := PA.col("H").darkened(0.15)
	for y in S:
		for x in S:
			var p := Vector2(x + 0.5, y + 0.5)
			var best := 0
			var bd := 1e9
			var second := 1e9
			for i in n:
				var d: float = p.distance_squared_to(seeds[i])
				if d < bd:
					second = bd
					bd = d
					best = i
				elif d < second:
					second = d
			var joint := sqrt(second) - sqrt(bd) < 1.1
			if x == 15 or y == 15:
				joint = true
			joint_mask[y * S + x] = 1 if joint else 0
			img.set_pixel(x, y, mortar if joint else cols[best])
	# bevel: lit top-left edges, shaded bottom-right edges
	for y in range(1, S - 1):
		for x in range(1, S - 1):
			if joint_mask[y * S + x] == 1:
				continue
			var c := img.get_pixel(x, y)
			if joint_mask[y * S + x - 1] == 1 or joint_mask[(y - 1) * S + x] == 1:
				img.set_pixel(x, y, c.lightened(0.18))
			elif joint_mask[y * S + x + 1] == 1 or joint_mask[(y + 1) * S + x] == 1:
				img.set_pixel(x, y, c.darkened(0.14))
	# speckles
	for i in 8:
		var x := r.randi_range(1, 14)
		var y := r.randi_range(1, 14)
		if joint_mask[y * S + x] == 0:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.08) if r.randf() < 0.5 else img.get_pixel(x, y).lightened(0.08))
	# moss in the joints
	for i in 6 + v * 2:
		var x := r.randi_range(0, 15)
		var y := r.randi_range(0, 15)
		if joint_mask[y * S + x] == 1:
			img.set_pixel(x, y, PA.col("f") if r.randf() < 0.6 else PA.col("E"))
	# a hairline crack
	if v == 1:
		PA.line(img, 5, 6, 7, 9, PA.col("H"))
	return img


## Build pad: a raised planter-crate top with planks, bevelled frame, nails and a painted marker.
static func pad() -> Image:
	var img := PA.new_img(S, S)
	var frame := PA.col("b")
	var frame_lt := PA.col("t")
	var frame_dk := PA.col("B")
	var plank := PA.col("t").darkened(0.05)
	var plank_lt := PA.col("c").darkened(0.12)
	var plank_dk := PA.col("T")
	img.fill(plank)
	# planks (3 horizontal boards) with grain
	for py in [2, 6, 10]:
		for x in range(2, 14):
			PA.px(img, x, py, plank_lt)
			PA.px(img, x, py + 3, plank_dk)
	for g in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(9, 8), Vector2i(10, 8), Vector2i(6, 12), Vector2i(11, 12)]:
		PA.px(img, g.x, g.y, plank_dk)
	# frame (bevelled)
	for i in S:
		PA.px(img, i, 0, frame_lt)
		PA.px(img, 0, i, frame_lt)
		PA.px(img, i, 1, frame)
		PA.px(img, 1, i, frame)
		PA.px(img, i, 14, frame_dk)
		PA.px(img, 14, i, frame)
		PA.px(img, i, 15, PA.col("k").lerp(frame_dk, 0.5))
		PA.px(img, 15, i, frame_dk)
	# nails on the frame corners and plank ends
	for p in [Vector2i(1, 1), Vector2i(14, 1), Vector2i(1, 14), Vector2i(14, 14), Vector2i(3, 4), Vector2i(12, 4), Vector2i(3, 12), Vector2i(12, 12)]:
		PA.px(img, p.x, p.y, PA.col("W"))
	# painted build marker (a faded yellow seed)
	var mk := PA.col("y").lerp(plank, 0.35)
	PA.px(img, 7, 6, mk)
	PA.px(img, 8, 6, mk)
	PA.px(img, 7, 7, mk)
	PA.px(img, 8, 7, mk)
	PA.px(img, 7, 8, mk)
	PA.px(img, 8, 8, mk)
	PA.px(img, 7, 9, mk.darkened(0.15))
	return img


static func burrow() -> Image:
	var img := grass(1)
	_burrow_hole(img)
	return img


## Shared burrow look: dirt mound ring, clods, deep hole with a lit lip, scratch marks.
static func _burrow_hole(img: Image) -> void:
	PA.disk(img, 8, 8.5, 7.6, PA.col("T"))
	PA.disk(img, 8, 8.5, 6.4, PA.col("b"))
	PA.disk(img, 8, 9.0, 5.0, PA.col("B"))
	PA.disk(img, 8, 9.5, 4.0, PA.col("K"))
	PA.disk(img, 8, 10.0, 3.0, PA.col("k"))
	# lit upper lip
	for x in range(5, 12):
		PA.px(img, x, 3, PA.col("t"))
	PA.px(img, 4, 4, PA.col("t"))
	PA.px(img, 12, 4, PA.col("t"))
	# clods
	for c in [Vector2i(1, 5), Vector2i(14, 3), Vector2i(14, 12), Vector2i(2, 13), Vector2i(12, 15)]:
		PA.px(img, c.x, c.y, PA.col("T"))
		PA.px(img, c.x, c.y + 1, PA.col("B"))
	# claw scratches
	PA.px(img, 3, 9, PA.col("B"))
	PA.px(img, 4, 10, PA.col("B"))
	PA.px(img, 12, 9, PA.col("B"))
	PA.px(img, 11, 10, PA.col("B"))


## Garden fence: pickets with lit/shaded sides and pointed tips, two rails, grass at the foot.
static func fence() -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("f").darkened(0.25))
	for p in 4:
		var x0 := p * 4
		for y in range(2, 15):
			PA.px(img, x0, y, PA.col("c").darkened(0.1))
			PA.px(img, x0 + 1, y, PA.col("t"))
			PA.px(img, x0 + 2, y, PA.col("T"))
		# pointed tip
		PA.px(img, x0 + 1, 0, PA.col("t"))
		PA.px(img, x0, 1, PA.col("c").darkened(0.1))
		PA.px(img, x0 + 1, 1, PA.col("t"))
		PA.px(img, x0 + 2, 1, PA.col("T"))
		# wood grain + knot
		PA.px(img, x0 + 1, 7 + (p % 3), PA.col("T"))
		# gap shadow
		for y in range(1, 15):
			PA.px(img, x0 + 3, y, PA.col("k").lerp(PA.col("f"), 0.4))
	# rails with top highlight + under-shadow
	for ry in [4, 10]:
		for x in S:
			PA.px(img, x, ry, PA.col("t"))
			PA.px(img, x, ry + 1, PA.col("b"))
			PA.px(img, x, ry + 2, PA.col("B"))
	# nail heads on rails
	for p in 4:
		PA.px(img, p * 4 + 1, 5, PA.col("g"))
		PA.px(img, p * 4 + 1, 11, PA.col("g"))
	# grass growing at the foot of the fence
	for x in S:
		PA.px(img, x, 15, PA.col("f"))
		if (x * 7) % 5 < 2:
			PA.px(img, x, 14, PA.col("E"))
	return img


## Side fence (left/right borders) seen from above: a line of picket tops on two rails,
## with a soft cast shadow on the grass to the right.
static func fence_side() -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("f").darkened(0.15))
	for y in S:
		PA.px(img, 11, y, PA.col("f").darkened(0.35))
		PA.px(img, 12, y, PA.col("f").darkened(0.28))
		PA.px(img, 4, y, PA.col("B"))
		PA.px(img, 10, y, PA.col("B"))
	for p in 4:
		var y0 := p * 4
		for y in range(y0, y0 + 3):
			PA.px(img, 5, y, PA.col("c").darkened(0.1))
			PA.px(img, 6, y, PA.col("t"))
			PA.px(img, 7, y, PA.col("t"))
			PA.px(img, 8, y, PA.col("T"))
			PA.px(img, 9, y, PA.col("b"))
		PA.px(img, 6, y0, PA.col("c"))
		PA.px(img, 7, y0 + 1, PA.col("g"))
	for y in S:
		if (y * 5) % 7 < 2:
			PA.px(img, 2, y, PA.col("E"))
			PA.px(img, 13, y, PA.col("E"))
	return img


static func dirt() -> Image:
	var img := PA.new_img(S, S)
	img.fill(PA.col("b"))
	var r := _rng(3131)
	for i in 30:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("B") if r.randf() < 0.6 else PA.col("T"))
	return img
