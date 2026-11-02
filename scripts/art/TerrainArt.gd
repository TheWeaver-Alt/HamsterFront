extends RefCounted
## Composes the 3/4-view terrain tile for every map cell from its neighbours:
## plateau tops with lit rims, cliff faces with strata + rounded end caps, ramps/stairs,
## lane dirt, patio flagstones, and cast shadows at the foot of cliffs.
## MainArena dedupes the results by key into one TileSet atlas.

const PA := preload("res://autoloads/PixelArt.gd")
const TA := preload("res://scripts/art/TileArt.gd")

# Organic colour patches (warm/cool on grass, dusty/damp on lane dirt) baked into the tiles so
# the repeating tile variants don't read as a grid. Half-resolution field, 2px granularity.
const PATCH_NONE := 0
const PATCH_WARM := 1
const PATCH_COOL := 2
const PATCH_DUST := 3
const PATCH_DAMP := 4
static var _patch_k: PackedByteArray = PackedByteArray()
static var _patch_a: PackedFloat32Array = PackedFloat32Array()
static var _patch_cell: PackedByteArray = PackedByteArray()
static var _base_cache: Dictionary = {}


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


static func _patchable(t: int) -> bool:
	return t == ArenaMap.Cell.GRASS or t == ArenaMap.Cell.HIGH or t == ArenaMap.Cell.PATH


static func _ensure_patches(map: ArenaMap) -> void:
	if _patch_cell.size() == ArenaMap.W * ArenaMap.H:
		return
	_base_cache.clear()
	var hw := ArenaMap.W * 8
	var hh := ArenaMap.H * 8
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 2
	var data := noise.get_image(hw, hh, false, false, true).get_data()
	_patch_k.resize(hw * hh)
	_patch_a.resize(hw * hh)
	_patch_cell.resize(ArenaMap.W * ArenaMap.H)
	_patch_cell.fill(0)
	for y in hh:
		for x in hw:
			var i := y * hw + x
			_patch_k[i] = PATCH_NONE
			_patch_a[i] = 0.0
			var cx := x >> 3
			var cy := y >> 3
			var ct := map.cell_type(Vector2i(cx, cy))
			if not _patchable(ct):
				continue
			var lane := ct == ArenaMap.Cell.PATH
			var n := data[i] / 127.5 - 1.0
			var a := 0.0
			var k := PATCH_NONE
			if n > 0.3:
				a = 0.1 if n > 0.42 else (0.05 if (x + y) % 2 == 0 else 0.0)
				k = PATCH_DUST if lane else PATCH_WARM
			elif n < -0.3:
				a = 0.11 if n < -0.42 else (0.055 if (x + y) % 2 == 0 else 0.0)
				k = PATCH_DAMP if lane else PATCH_COOL
			if a > 0.0:
				if lane:
					a *= 0.7
				_patch_k[i] = k
				_patch_a[i] = a
				_patch_cell[cy * ArenaMap.W + cx] = 1


static func _apply_patch(img: Image, x: int, y: int) -> void:
	var hw := ArenaMap.W * 8
	var cols := [Color.WHITE, Color(1.0, 0.95, 0.45), Color(0.0, 0.16, 0.1), Color(1.0, 0.9, 0.7), Color(0.22, 0.1, 0.04)]
	for py in 16:
		for px_ in 16:
			var i := ((y * 16 + py) >> 1) * hw + ((x * 16 + px_) >> 1)
			var a := _patch_a[i]
			if a <= 0.0:
				continue
			var c := img.get_pixel(px_, py)
			img.set_pixel(px_, py, c.lerp(cols[_patch_k[i]], a))


## Unique appearance key for a cell.
static func cell_key(map: ArenaMap, x: int, y: int) -> String:
	_ensure_patches(map)
	var key := _cell_key_base(map, x, y)
	if _patchable(_t(map, x, y)) and _patch_cell[y * ArenaMap.W + x] == 1:
		key += "|P%d_%d" % [x, y]
	return key


static func _cell_key_base(map: ArenaMap, x: int, y: int) -> String:
	var t := _t(map, x, y)
	var d: int = map.deco[map.idx(x, y)]
	match t:
		ArenaMap.Cell.WALL:
			if (x == 0 or x == ArenaMap.W - 1) and y > 0 and y < ArenaMap.H - 1:
				return "wall_v"
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
	if key == "wall_v":
		return TA.fence_side()
	if t == ArenaMap.Cell.FACE:
		return _face(map, x, y, key)
	if t == ArenaMap.Cell.RAMP:
		return _ramp(key.substr(5))
	var parts := key.split("|")
	if not _base_cache.has(parts[0]):
		_base_cache[parts[0]] = _base(parts[0])
	var img: Image = (_base_cache[parts[0]] as Image).duplicate()
	if parts.size() > 2 and parts[2].begins_with("P"):
		_ensure_patches(map)
		_apply_patch(img, x, y)
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
			TA._burrow_hole(img)
			return img
	return TA.grass(0)


## Sunlit plateau grass: brighter than the lawn below, with blade clusters and sun specks.
static func _high_grass(v: int) -> Image:
	var img := PA.new_img(16, 16)
	var base := PA.col("e").darkened(0.08)
	var lt := PA.col("e").lightened(0.12)
	var tip := PA.col("e").lerp(PA.col("y"), 0.35).lightened(0.1)
	var dk := PA.col("E")
	var warm := base.lerp(PA.col("y"), 0.15)
	img.fill(base)
	var r := RandomNumberGenerator.new()
	r.seed = 7000 + v * 131
	for c in 6:
		var cx := r.randi_range(0, 15)
		var cy := r.randi_range(0, 15)
		var col := warm if c % 2 == 0 else base.darkened(0.06)
		for k in r.randi_range(3, 6):
			PA.px(img, cx + r.randi_range(-1, 1), cy + r.randi_range(-1, 1), col)
	for i in 12:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), dk)
	for i in 4 + v % 2:
		TA.tuft(img, r.randi_range(1, 14), r.randi_range(1, 13), tip, lt, dk, r.randf() < 0.4)
	# sun specks
	for i in 2:
		PA.px(img, r.randi_range(1, 14), r.randi_range(1, 14), PA.col("w").lerp(tip, 0.5))
	return img


## Plateau flowers: 0 daisies, 1 bluebells, 2 poppies (on top of sunlit grass).
static func _flowers_on(img: Image, v: int) -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = 9100 + v * 17
	for i in 3:
		var x := r.randi_range(2, 13)
		var y := r.randi_range(2, 12)
		match v % 3:
			0:
				var w := PA.col("w")
				PA.px(img, x - 1, y, w)
				PA.px(img, x + 1, y, w)
				PA.px(img, x, y - 1, w)
				PA.px(img, x, y + 1, PA.col("W"))
				PA.px(img, x, y, PA.col("y"))
			1:
				PA.px(img, x, y, PA.col("u"))
				PA.px(img, x, y + 1, PA.col("A"))
				PA.px(img, x + 1, y + 1, PA.col("u"))
				PA.px(img, x, y + 2, PA.col("E"))
			_:
				PA.px(img, x, y, PA.col("r"))
				PA.px(img, x + 1, y, PA.col("r").lightened(0.2))
				PA.px(img, x, y + 1, PA.col("R"))
				PA.px(img, x + 1, y + 1, PA.col("k"))
				PA.px(img, x, y + 2, PA.col("E"))
	return img


## Canyon lane floor: calm packed dirt (gameplay must pop on it) with soft clumps, a few
## pebbles and one small detail per variant (crack / root / rat footprints).
static func _lane(v: int) -> Image:
	var img := PA.new_img(16, 16)
	var base := PA.col("t").darkened(0.2)
	var grain := base.darkened(0.11)
	img.fill(base)
	var r := RandomNumberGenerator.new()
	r.seed = 4400 + v * 61
	for c in 5:
		var cx := r.randi_range(0, 15)
		var cy := r.randi_range(0, 15)
		var col := base.darkened(0.05) if c % 2 == 0 else base.lightened(0.05)
		for k in r.randi_range(4, 8):
			PA.px(img, cx + r.randi_range(-2, 2), cy + r.randi_range(-1, 1), col)
	for i in 7:
		PA.px(img, r.randi_range(0, 15), r.randi_range(0, 15), grain)
	# a pebble or two: lit top, soft shadow
	for i in 1 + (1 if v == 1 else 0):
		var x := r.randi_range(2, 12)
		var y := r.randi_range(2, 12)
		PA.px(img, x, y, PA.col("l").darkened(0.05))
		PA.px(img, x + 1, y, PA.col("h"))
		PA.px(img, x, y + 1, base.darkened(0.2))
		PA.px(img, x + 1, y + 1, base.darkened(0.2))
	var line_c := base.darkened(0.2)
	match v:
		0:
			PA.line(img, 4, 10, 6, 11, line_c)
			PA.px(img, 7, 11, line_c)
		1:
			PA.line(img, 10, 4, 13, 5, PA.col("b"))
			PA.px(img, 11, 4, PA.col("T"))
		2:
			for f in [Vector2i(3, 6), Vector2i(7, 8), Vector2i(11, 6)]:
				PA.px(img, f.x, f.y, line_c)
				PA.px(img, f.x + 1, f.y - 1, line_c)
				PA.px(img, f.x + 1, f.y + 1, line_c)
	return img


## Plateau top: lit rims where the ground drops away, with blades poking over the edge.
static func _rims(img: Image, mask: String) -> void:
	var dark := PA.col("f").darkened(0.4)
	var lip := PA.col("e").lerp(PA.col("y"), 0.35).lightened(0.2)
	var lip2 := PA.col("e").lightened(0.15)
	if mask[1] == "1":   # north drop
		for x in 16:
			PA.px(img, x, 0, dark if (x * 5) % 7 != 0 else PA.col("E"))
			PA.px(img, x, 1, lip)
			PA.px(img, x, 2, lip2)
	if mask[2] == "1":   # west drop
		for y in 16:
			PA.px(img, 0, y, dark)
			PA.px(img, 1, y, lip)
			PA.px(img, 2, y, lip2 if y % 3 != 0 else img.get_pixel(2, y))
	if mask[3] == "1":   # east drop (in shadow)
		for y in 16:
			PA.px(img, 15, y, dark)
			PA.px(img, 14, y, PA.col("E").darkened(0.2))
			PA.px(img, 13, y, PA.col("E") if y % 4 == 0 else img.get_pixel(13, y))
	if mask[4] == "1":   # south drop (no face drawn)
		for x in 16:
			PA.px(img, x, 15, dark)
			PA.px(img, x, 14, PA.col("E").darkened(0.15))


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


## Cliff face: overhanging grass lip with dangling blades + roots, an earthen wall that darkens
## towards the foot, a wavy darker stratum and a lit ledge, a few embedded rounded rocks with
## moss, and dark AO at the base. Strata wobble lines up across neighbouring tiles.
static func _face(map: ArenaMap, x: int, y: int, key: String) -> Image:
	var img := PA.new_img(16, 16)
	var bits := key.split("_")
	var v := int(bits[1])
	var flags: String = bits[2]
	var open_l := flags[0] == "1"
	var open_r := flags[1] == "1"
	var r := RandomNumberGenerator.new()
	r.seed = 8800 + v * 37
	var soil_top := PA.col("b").lerp(PA.col("T"), 0.45)
	var soil_bot := PA.col("B").lerp(PA.col("b"), 0.35)
	var stratum := PA.col("B")
	var ledge := PA.col("T").lightened(0.12)
	for xx in 16:
		var w := int(roundf(sin(xx * TAU / 16.0)))
		for yy in 16:
			var c: Color
			if yy <= 1:
				c = PA.col("e").darkened(0.08)                 # grass lip (plateau colour)
			elif yy == 2:
				c = PA.col("E")
			elif yy == 3:
				c = PA.col("B").darkened(0.35)                 # shadow under the lip
			elif yy >= 15:
				c = PA.col("K")
			else:
				var f := float(yy - 4) / 10.0
				c = soil_top.lerp(soil_bot, f)
				if (xx * 7 + yy * 3 + v) % 11 == 0:
					c = c.lightened(0.1)
				elif (xx * 5 + yy * 9 + v) % 13 == 0:
					c = c.darkened(0.12)
				if yy == 6 + w:
					c = ledge if (xx + v) % 6 != 0 else c
				elif yy == 10 + w:
					c = stratum
				elif yy == 14:
					c = c.darkened(0.2)
			img.set_pixel(xx, yy, c)
	# embedded rounded rocks
	for i in 2 + v % 2:
		var rx := r.randf_range(2.0, 13.0)
		var ry := r.randf_range(8.5, 12.0)
		var rw := r.randf_range(1.8, 2.8)
		PA.ellipse(img, rx, ry, rw, 1.6, PA.col("H"))
		PA.ellipse(img, rx - 0.4, ry - 0.4, rw - 0.8, 1.0, PA.col("h"))
		PA.px(img, int(rx - rw + 1.0), int(ry - 1.0), PA.col("l"))
		if r.randf() < 0.5:
			PA.px(img, int(rx), int(ry - 1.6), PA.col("f"))
			PA.px(img, int(rx) + 1, int(ry - 1.6), PA.col("E"))
	# dangling blades + hanging roots from the lip
	for xx in 16:
		if (xx * 3 + v) % 5 == 0:
			PA.px(img, xx, 3, PA.col("f"))
			if (xx + v) % 2 == 0:
				PA.px(img, xx, 4, PA.col("f").darkened(0.2))
	for k in 2:
		var hx := r.randi_range(1, 14)
		var ln := r.randi_range(2, 5)
		for i in ln:
			PA.px(img, hx + (1 if i == ln - 1 and k == 0 else 0), 4 + i, PA.col("B").darkened(0.15))
	# a vine on variant 2
	if v == 2:
		var vx := r.randi_range(4, 11)
		for yy in range(3, 11):
			PA.px(img, vx + (1 if yy % 3 == 0 else 0), yy, PA.col("f"))
			if yy % 2 == 0:
				PA.px(img, vx - 1, yy, PA.col("E"))
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
			# stone stairs cut into the cliff, soil walls with lit/shaded edges on both sides
			img.fill(PA.col("b"))
			for yy in 16:
				var k := yy % 4
				var c := step_top if k == 0 else (step if k < 3 else riser)
				for xx in range(3, 13):
					var cc := c
					if k == 1 and (xx + yy) % 7 == 0:
						cc = step.darkened(0.08)
					img.set_pixel(xx, yy, cc)
				PA.px(img, 3, yy, img.get_pixel(3, yy).lightened(0.1))
				PA.px(img, 12, yy, img.get_pixel(12, yy).darkened(0.15))
			for yy in 16:
				PA.px(img, 2, yy, PA.col("B"))
				PA.px(img, 13, yy, PA.col("B"))
				PA.px(img, 1, yy, PA.col("T") if yy % 3 == 0 else PA.col("b"))
			for xx in 16:
				PA.px(img, xx, 0, PA.col("E"))
			PA.px(img, 4, 2, PA.col("f"))
			PA.px(img, 11, 6, PA.col("f"))
		"n":
			# grassy slope with timber log steps going down to the north
			img.fill(PA.col("e").darkened(0.12))
			for yy in [2, 6, 10, 14]:
				for xx in range(1, 15):
					PA.px(img, xx, yy, PA.col("b"))
					PA.px(img, xx, yy - 1, PA.col("t"))
					PA.px(img, xx, yy + 1, PA.col("E").darkened(0.2))
				PA.px(img, 1, yy, PA.col("T"))
				PA.px(img, 14, yy, PA.col("B"))
			for yy in 16:
				PA.px(img, 0, yy, PA.col("f"))
				PA.px(img, 15, yy, PA.col("f"))
		_:
			# sideways stone ramp: steps run vertically, darker towards the low side
			img.fill(PA.col("h"))
			for xx in 16:
				var k := xx % 4
				if dir == "w":
					k = (15 - xx) % 4
				var c := step_top if k == 0 else (step if k < 3 else riser)
				var depth := float(xx) / 15.0 if dir == "e" else float(15 - xx) / 15.0
				for yy in 16:
					var cc := c.darkened(depth * 0.25)
					if k == 1 and (xx * 3 + yy) % 9 == 0:
						cc = cc.darkened(0.08)
					img.set_pixel(xx, yy, cc)
			for xx in 16:
				PA.px(img, xx, 0, PA.col("E"))
				PA.px(img, xx, 15, PA.col("H").darkened(0.2))
	return img
