extends RefCounted
## Composes the 3/4-view terrain tile for every map cell from its neighbours:
## plateau tops with lit rims, cliff faces with strata + rounded end caps, ramps/stairs,
## lane dirt, patio flagstones, and cast shadows at the foot of cliffs.
## MainArena dedupes the results by key into one TileSet atlas.

const PA := preload("res://autoloads/PixelArt.gd")
const TA := preload("res://scripts/art/TileArt.gd")


static func _t(map: ArenaMap, x: int, y: int) -> int:
	return map.cell_type(Vector2i(x, y))


static func _e(map: ArenaMap, x: int, y: int) -> int:
	return map.cell_elev(Vector2i(x, y))


static func _is_face(map: ArenaMap, x: int, y: int) -> bool:
	return _t(map, x, y) == ArenaMap.Cell.FACE


## A cell drawn as plateau top (high grass, pads/props/burrows up there).
static func _is_top(map: ArenaMap, x: int, y: int) -> bool:
	var t := _t(map, x, y)
	return _e(map, x, y) == 1 and t != ArenaMap.Cell.FACE and t != ArenaMap.Cell.WALL


static func _is_low(map: ArenaMap, x: int, y: int) -> bool:
	var t := _t(map, x, y)
	return _e(map, x, y) == 0 and t != ArenaMap.Cell.WALL


## Unique appearance key for a cell.
static func cell_key(map: ArenaMap, x: int, y: int) -> String:
	var t := _t(map, x, y)
	var d: int = map.deco[map.idx(x, y)]
	match t:
		ArenaMap.Cell.WALL:
			return "wall"
		ArenaMap.Cell.FACE:
			var l := 0 if _is_face(map, x - 1, y) or _t(map, x - 1, y) == ArenaMap.Cell.RAMP else 1
			var r := 0 if _is_face(map, x + 1, y) or _t(map, x + 1, y) == ArenaMap.Cell.RAMP else 1
			var stairs_left := 1 if _t(map, x - 1, y) == ArenaMap.Cell.RAMP else 0
			var stairs_right := 1 if _t(map, x + 1, y) == ArenaMap.Cell.RAMP else 0
			return "face_%d_%d%d%d%d" % [d % 3, l, r, stairs_left, stairs_right]
		ArenaMap.Cell.RAMP:
			return "ramp_" + _ramp_dir(map, x, y)
	var base := _base_name(map, x, y, t, d)
	var mask := ""
	if _is_top(map, x, y):
		mask = "r%d%d%d%d" % [int(_is_low(map, x, y - 1)), int(_is_low(map, x - 1, y)),
			int(_is_low(map, x + 1, y)), int(_is_low(map, x, y + 1))]
	elif _is_low(map, x, y):
		var sn := _is_face(map, x, y - 1)
		var sw := _is_face(map, x - 1, y) or _is_top(map, x - 1, y)
		var snw := (_is_face(map, x - 1, y - 1) or _is_top(map, x - 1, y - 1)) and not sn and not sw
		mask = "s%d%d%d" % [int(sn), int(sw), int(snw)]
	return base + "|" + mask


static func _base_name(map: ArenaMap, x: int, y: int, t: int, d: int) -> String:
	var high := _is_top(map, x, y)
	match t:
		ArenaMap.Cell.PAD:
			return "pad_h" if high else "pad_l"
		ArenaMap.Cell.BURROW:
			return "burrow"
		ArenaMap.Cell.PATH:
			return "lane_%d" % (d % 3)
		ArenaMap.Cell.PATIO, ArenaMap.Cell.SILO:
			return "patio_%d" % (d % 3)
	# grass / obstacle ground: props in a lane sit on lane dirt, near the silo on patio
	var ch: String = (ArenaMap.TERRAIN[y] as String)[x]
	if ch == ",":
		return "lane_%d" % (d % 3)
	if t == ArenaMap.Cell.OBSTACLE and map._near_silo(x, y):
		return "patio_%d" % (d % 3)
	if high:
		return ("hflow_%d" % (d - 10)) if d >= 10 else ("high_%d" % d)
	return ("lflow_%d" % (d - 10)) if d >= 10 else ("low_%d" % d)


static func _ramp_dir(map: ArenaMap, x: int, y: int) -> String:
	if _is_low(map, x + 1, y) and not _is_low(map, x - 1, y):
		return "e"
	if _is_low(map, x - 1, y) and not _is_low(map, x + 1, y):
		return "w"
	if _is_face(map, x - 1, y) or _is_face(map, x + 1, y):
		return "s"      # stairs cut through a cliff face, descending south
	if _is_low(map, x, y - 1):
		return "n"      # slope on a plateau's north edge, descending north
	return "s"


# ------------------------------------------------------------------ painting

static func cell_image(map: ArenaMap, x: int, y: int, key: String) -> Image:
	var t := _t(map, x, y)
	if key == "wall":
		return TA.fence()
	if t == ArenaMap.Cell.FACE:
		return _face(map, x, y, key)
	if t == ArenaMap.Cell.RAMP:
		return _ramp(key.substr(5))
	var parts := key.split("|")
	var img := _base(parts[0])
	var mask: String = parts[1] if parts.size() > 1 else ""
	if mask.begins_with("r"):
		_rims(img, mask)
	elif mask.begins_with("s"):
		_shadows(img, mask)
	return img


static func _base(name: String) -> Image:
	if name.begins_with("high_"):
		return _high_grass(int(name.substr(5)))
	if name.begins_with("hflow_"):
		return _flowers_on(_high_grass(int(name.substr(6))), int(name.substr(6)))
	if name.begins_with("low_"):
		return TA.grass(int(name.substr(4)))
	if name.begins_with("lflow_"):
		return TA.flowers(int(name.substr(6)))
	if name.begins_with("lane_"):
		return _lane(int(name.substr(5)))
	if name.begins_with("patio_"):
		return TA.path(int(name.substr(6)))
	match name:
		"pad_h", "pad_l":
			return TA.pad()
		"burrow":
			var img := _lane(1)
			PA.disk(img, 8, 8.5, 7.5, PA.col("T"))
			PA.disk(img, 8, 8.5, 6.2, PA.col("b"))
			PA.disk(img, 8, 9, 4.8, PA.col("B"))
			PA.disk(img, 8, 9.5, 3.8, PA.col("k"))
			PA.px(img, 6, 3, PA.col("t"))
			PA.px(img, 7, 2, PA.col("t"))
			PA.px(img, 9, 2, PA.col("t"))
			return img
	return TA.grass(0)


static func _high_grass(v: int) -> Image:
	var img := PA.new_img(16, 16)
	img.fill(PA.col("e").darkened(0.06))
	var r := RandomNumberGenerator.new()
	r.seed = 7000 + v * 131
	for i in 20:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("E"))
	for i in 10:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("e").lightened(0.25))
	for i in 3 + v:
		var x := r.randi_range(1, 14)
		var y := r.randi_range(2, 14)
		PA.px(img, x, y, PA.col("y").lightened(0.3).lerp(PA.col("e"), 0.5))
		PA.px(img, x, y + 1, PA.col("E"))
	return img


static func _flowers_on(img: Image, v: int) -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 9100 + v * 17
	var cols := ["p", "w", "y", "u"]
	for i in 2:
		var x := r.randi_range(3, 12)
		var y := r.randi_range(3, 12)
		var pc := PA.col(cols[(v + i) % cols.size()])
		PA.px(img, x - 1, y, pc)
		PA.px(img, x + 1, y, pc)
		PA.px(img, x, y - 1, pc)
		PA.px(img, x, y + 1, pc)
		PA.px(img, x, y, PA.col("y"))
	return img


static func _lane(v: int) -> Image:
	var img := PA.new_img(16, 16)
	img.fill(PA.col("t").darkened(0.18))
	var r := RandomNumberGenerator.new()
	r.seed = 4400 + v * 61
	for i in 26:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("T"))
	for i in 10:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), PA.col("t"))
	# pebbles
	for i in 2 + v:
		var x := r.randi_range(1, 14)
		var y := r.randi_range(1, 14)
		PA.px(img, x, y, PA.col("h"))
		PA.px(img, x + 1, y, PA.col("H"))
	# tiny rat footprints
	if v == 2:
		PA.px(img, 4, 6, PA.col("B"))
		PA.px(img, 6, 7, PA.col("B"))
		PA.px(img, 9, 6, PA.col("B"))
		PA.px(img, 11, 7, PA.col("B"))
	return img


## Plateau top: lit rims where the ground drops away.
static func _rims(img: Image, mask: String) -> void:
	var dark := PA.col("f").darkened(0.35)
	var lip := PA.col("e").lightened(0.35)
	if mask[1] == "1":   # north drop
		for x in 16:
			PA.px(img, x, 0, dark)
			PA.px(img, x, 1, lip)
	if mask[2] == "1":   # west drop
		for y in 16:
			PA.px(img, 0, y, dark)
			PA.px(img, 1, y, lip)
	if mask[3] == "1":   # east drop
		for y in 16:
			PA.px(img, 15, y, dark)
			PA.px(img, 14, y, PA.col("E").darkened(0.15))
	if mask[4] == "1":   # south drop (no face drawn)
		for x in 16:
			PA.px(img, x, 15, dark)


## Low ground: soft shadows cast by plateaus (light comes from the top-left).
static func _shadows(img: Image, mask: String) -> void:
	var sn := mask[1] == "1"
	var sw := mask[2] == "1"
	var snw := mask[3] == "1"
	for y in 16:
		for x in 16:
			var amt := 0.0
			if sn and y < 4:
				amt = maxf(amt, 0.42 - y * 0.09)
			if sw and x < 4:
				amt = maxf(amt, 0.34 - x * 0.08)
			if snw and x < 4 and y < 4:
				amt = maxf(amt, 0.3 - (x + y) * 0.05)
			if amt > 0.0:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, p.darkened(amt))


## Cliff face: grass lip, layered soil/stone strata, dark foot; rounded ends.
static func _face(map: ArenaMap, x: int, y: int, key: String) -> Image:
	var img := PA.new_img(16, 16)
	var bits := key.split("_")
	var v := int(bits[1])
	var flags: String = bits[2]
	var open_l := flags[0] == "1"
	var open_r := flags[1] == "1"
	var r := RandomNumberGenerator.new()
	r.seed = 8800 + v * 37 + x * 3
	var soil := PA.col("b")
	var soil_lt := PA.col("T")
	var soil_dk := PA.col("B")
	var stone := PA.col("h")
	for yy in 16:
		for xx in 16:
			var c := soil
			# strata bands
			var band := (yy + (xx / 5 + v) % 2) % 5
			if band == 0:
				c = soil_lt
			elif band == 3:
				c = soil_dk
			img.set_pixel(xx, yy, c)
	# stones embedded in the wall
	for i in 3:
		var sx := r.randi_range(1, 12)
		var sy := r.randi_range(5, 12)
		PA.rect(img, sx, sy, 3, 2, stone)
		PA.px(img, sx, sy, PA.col("l"))
		PA.px(img, sx + 2, sy + 1, PA.col("H"))
	# roots poking out
	PA.px(img, r.randi_range(2, 13), 4, PA.col("f"))
	# grass lip overhang (top of the cliff)
	for xx in 16:
		PA.px(img, xx, 0, PA.col("e").darkened(0.06))
		PA.px(img, xx, 1, PA.col("E"))
		PA.px(img, xx, 2, PA.col("f") if (xx + v) % 3 != 0 else PA.col("E"))
		PA.px(img, xx, 3, soil_dk)
	# dark foot where the cliff meets the ground
	for xx in 16:
		PA.px(img, xx, 15, PA.col("K"))
		PA.px(img, xx, 14, soil_dk.darkened(0.2))
	# rounded ends: show the low ground behind and shade the corner
	if open_l:
		_end_cap(img, map, x, y, true)
	if open_r:
		_end_cap(img, map, x, y, false)
	return img


static func _end_cap(img: Image, _map: ArenaMap, _x: int, _y: int, left: bool) -> void:
	var ground := TA.grass(2)
	for yy in 16:
		var cut := 0
		if yy >= 12:
			cut = yy - 11
		for k in cut:
			var xx := k if left else 15 - k
			img.set_pixel(xx, yy, ground.get_pixel(xx, yy).darkened(0.3))
		# shaded edge column
		var ex := cut if left else 15 - cut
		if ex >= 0 and ex < 16 and yy > 3:
			img.set_pixel(ex, yy, img.get_pixel(ex, yy).darkened(0.25) if left else img.get_pixel(ex, yy).darkened(0.4))


## Ramps & stairs. dir: e/w = descending sideways, n = slope on north edge, s = stairs through a face.
static func _ramp(dir: String) -> Image:
	var img := PA.new_img(16, 16)
	var step_top := PA.col("l")
	var step := PA.col("h")
	var riser := PA.col("H")
	match dir:
		"s":
			# stone stairs cut into the cliff, with soil walls on both sides
			img.fill(PA.col("b"))
			for yy in 16:
				var k := yy % 4
				var c := step_top if k == 0 else (step if k < 3 else riser)
				for xx in range(3, 13):
					img.set_pixel(xx, yy, c)
			for yy in 16:
				PA.px(img, 2, yy, PA.col("B"))
				PA.px(img, 13, yy, PA.col("B"))
			for xx in 16:
				PA.px(img, xx, 0, PA.col("E"))
		"n":
			# grassy slope with timber steps going down to the north
			img.fill(PA.col("e").darkened(0.1))
			for yy in [2, 6, 10, 14]:
				for xx in range(1, 15):
					PA.px(img, xx, yy, PA.col("b"))
					PA.px(img, xx, yy - 1, PA.col("t"))
			for yy in 16:
				PA.px(img, 0, yy, PA.col("f"))
				PA.px(img, 15, yy, PA.col("f"))
		_:
			# sideways ramp: steps run vertically, darker towards the low side
			img.fill(PA.col("h"))
			for xx in 16:
				var k := xx % 4
				if dir == "w":
					k = (15 - xx) % 4
				var c := step_top if k == 0 else (step if k < 3 else riser)
				var depth := float(xx) / 15.0 if dir == "e" else float(15 - xx) / 15.0
				for yy in 16:
					img.set_pixel(xx, yy, c.darkened(depth * 0.25))
			for xx in 16:
				PA.px(img, xx, 0, PA.col("E"))
	return img
