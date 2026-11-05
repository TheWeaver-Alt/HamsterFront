extends RefCounted
## Picture-first card art (see scripts/core/CardFaces.gd): one chunky 16x16 picture per card, drawn at 3x.
## Names: card_<icon>. make() returns null for any other name, so PixelArt tries its next painter.
## Every picture is painted from a few shared parts (hearts, rats, seeds, flames, bolts, hamster faces).

const PA := preload("res://autoloads/PixelArt.gd")
const SIZE := 16


static func make(n: String) -> Image:
	if not n.begins_with("card_"):
		return null
	var img := PA.new_img(SIZE, SIZE)
	if not _paint(n.substr(5), img):
		return null
	return PA.outline(img, PA.col("k"))


static func _paint(id: String, img: Image) -> bool:
	match id:
		"pierce": _pierce(img)
		"wheel_cool": _wheel_cool(img)
		"cheeks": _cheeks(img)
		"bullets": _bullets(img)
		"heart_tape": _heart_tape(img)
		"fist": _fist(img)
		"magnet": _magnet(img)
		"boot": _boot(img)
		"barrels": _barrels(img)
		"weight_down": _weight_down(img)
		"wheel_fire": _wheel_fire(img)
		"spit": _spit(img)
		"sun_vamp": _sun_vamp(img)
		"radiator": _radiator(img)
		"bottle": _bottle(img)
		"bubble": _bubble(img)
		"gatling_fire": _gatling_fire(img)
		"prism": _prism(img)
		"sneeze": _sneeze(img)
		"chain": _chain(img)
		"googly": _googly(img)
		"coupon": _coupon(img)
		"sugar": _sugar(img)
		"shells": _shells(img)
		"tower_shield": _tower_shield(img)
		"magnify": _magnify(img)
		"salt": _salt(img)
		"cables": _cables(img)
		"brothers": _brothers(img)
		"buddies": _buddies(img)
		"shared": _shared(img)
		"cat": _cat(img)
		"invert": _invert(img)
		"tower_fast": _tower_fast(img)
		"tower_hurt": _tower_hurt(img)
		"leak": _leak(img)
		"seeds_more": _seeds_more(img)
		"rat_chase": _rat_chase(img)
		"burst": _burst(img)
		_:
			return false
	return true


# ------------------------------------------------------------------ shared parts

static func _px(img: Image, x: int, y: int, k: String) -> void:
	PA.px(img, x, y, PA.col(k))


static func _rect(img: Image, x: int, y: int, w: int, h: int, k: String) -> void:
	PA.rect(img, x, y, w, h, PA.col(k))


static func _disk(img: Image, cx: float, cy: float, r: float, k: String) -> void:
	PA.disk(img, cx, cy, r, PA.col(k))


static func _ring(img: Image, cx: float, cy: float, r: float, t: float, k: String) -> void:
	PA.ring(img, cx, cy, r, t, PA.col(k))


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, k: String) -> void:
	PA.line(img, x0, y0, x1, y1, PA.col(k))


## Rows of palette keys ('.' is empty); `x` stands for the `main` key.
static func _stamp(img: Image, x: int, y: int, rows: Array, main: String = "y") -> void:
	for r in rows.size():
		var row: String = rows[r]
		for c in row.length():
			if row[c] != ".":
				_px(img, x + c, y + r, main if row[c] == "x" else row[c])


## A heart from the heart curve, centred at (cx, cy), about 2.3 * s wide.
static func _heart(img: Image, cx: float, cy: float, s: float, k: String = "r") -> void:
	for yy in SIZE:
		for xx in SIZE:
			var u := (xx + 0.5 - cx) / s
			var v := -(yy + 0.5 - cy) / s
			var a := u * u + v * v - 1.0
			if a * a * a - u * u * v * v * v <= 0.0:
				_px(img, xx, yy, k)


static func _seed(img: Image, x: int, y: int) -> void:
	_stamp(img, x, y, [".s.", "sSs", "sSs", "sSs", ".s."])


static func _flame(img: Image, x: int, y: int) -> void:
	_stamp(img, x, y, ["..i..", "..ii.", ".iii.", ".iIi.", "iiIii", "iIIIi", ".iIi."])


## A zigzag lightning bolt, 5 wide and 8 tall.
static func _bolt(img: Image, x: int, y: int, k: String = "y") -> void:
	for dx in 2:
		_line(img, x + 3 + dx, y, x + 1 + dx, y + 3, k)
		_line(img, x + 1 + dx, y + 3, x + 3 + dx, y + 4, k)
		_line(img, x + 3 + dx, y + 4, x + 1 + dx, y + 7, k)
	_px(img, x + 3, y, "w")


## A rat's head, 6 wide and 5 tall.
static func _rat(img: Image, x: int, y: int, mad: bool = false) -> void:
	_stamp(img, x, y, [".q..q.", "mmmmmm", "mkmmkm", "mmmmmm", "..qq.."])
	if mad:
		_px(img, x + 1, y + 2, "r")
		_px(img, x + 4, y + 2, "r")


## A hamster's face: round, with ears, eyes, nose and pale cheeks.
static func _face(img: Image, cx: float, cy: float, r: float) -> void:
	_disk(img, cx - r * 0.7, cy - r * 0.85, r * 0.38, "o")
	_disk(img, cx + r * 0.7, cy - r * 0.85, r * 0.38, "o")
	_disk(img, cx, cy, r, "o")
	_disk(img, cx - r * 0.45, cy + r * 0.35, r * 0.42, "c")
	_disk(img, cx + r * 0.45, cy + r * 0.35, r * 0.42, "c")
	_px(img, int(cx - r * 0.4), int(cy - r * 0.2), "k")
	_px(img, int(cx + r * 0.3), int(cy - r * 0.2), "k")
	_px(img, int(cx - 0.4), int(cy + r * 0.15), "p")


## A small turret on a cardboard crate; (x, y) is the crate's top-left corner, the crate is 9 wide.
static func _tower(img: Image, x: int, y: int) -> void:
	_rect(img, x, y + 4, 9, 5, "t")
	_rect(img, x, y + 8, 9, 1, "T")
	_px(img, x + 1, y + 5, "b")
	_px(img, x + 7, y + 5, "b")
	_disk(img, x + 4.5, y + 3.0, 3.0, "g")
	_rect(img, x + 5, y + 2, 5, 2, "G")


## A rat's face, round, with ears, eyes and a pink nose.
static func _ratface(img: Image, cx: float, cy: float, r: float, mad: bool = false) -> void:
	_disk(img, cx - r * 0.75, cy - r * 0.8, r * 0.42, "m")
	_disk(img, cx + r * 0.75, cy - r * 0.8, r * 0.42, "m")
	_px(img, int(cx - r * 0.75), int(cy - r * 0.8), "q")
	_px(img, int(cx + r * 0.75), int(cy - r * 0.8), "q")
	_disk(img, cx, cy, r, "m")
	var eye := "r" if mad else "k"
	_px(img, int(cx - r * 0.45), int(cy - r * 0.1), eye)
	_px(img, int(cx + r * 0.35), int(cy - r * 0.1), eye)
	_px(img, int(cx - 0.5), int(cy + r * 0.45), "q")


## A snowflake centred on (cx, cy), `r` pixels across each arm.
static func _snow(img: Image, cx: int, cy: int, r: int) -> void:
	for p in [[0, -r, 0, r], [-r, 0, r, 0], [-r + 1, -r + 1, r - 1, r - 1], [r - 1, -r + 1, -r + 1, r - 1]]:
		_line(img, cx + p[0], cy + p[1], cx + p[2], cy + p[3], "u")
	_px(img, cx, cy, "w")


static func _arrow(img: Image, x: int, y: int, down: bool, k: String) -> void:
	if down:
		_stamp(img, x, y, ["..x..", "..x..", "..x..", "xxxxx", ".xxx.", "..x.."], k)
	else:
		_stamp(img, x, y, ["..x..", ".xxx.", "xxxxx", "..x..", "..x..", "..x.."], k)


## A horizontal arrow from x0 to x1 (pointing at x1), two pixels thick.
static func _harrow(img: Image, x0: int, x1: int, y: int, k: String) -> void:
	var s := 1 if x1 > x0 else -1
	var shaft_end := x1 - s * 3
	_rect(img, mini(x0, shaft_end), y, absi(shaft_end - x0) + 1, 2, k)
	for j in 3:
		_rect(img, x1 - s * j, y - j, 1, 2 + 2 * j, k)


# ------------------------------------------------------------------ mech mods

static func _pierce(img: Image) -> void:
	_ratface(img, 4.5, 8.0, 3.8)
	_ratface(img, 11.5, 8.0, 3.8)
	_rect(img, 0, 7, 13, 1, "t")
	_rect(img, 0, 8, 13, 1, "T")
	_stamp(img, 13, 7, ["Ww.", "WWw"])
	_px(img, 0, 5, "y")
	_px(img, 1, 11, "y")


static func _wheel_cool(img: Image) -> void:
	_ring(img, 6.5, 9.5, 5.5, 2.0, "g")
	_line(img, 6, 4, 6, 14, "W")
	_line(img, 1, 9, 12, 9, "W")
	_disk(img, 6.5, 9.5, 1.5, "G")
	for p in [[12, 1, 12, 7], [9, 4, 15, 4], [10, 2, 14, 6], [14, 2, 10, 6]]:
		_line(img, p[0], p[1], p[2], p[3], "u")
	_px(img, 12, 4, "w")


static func _cheeks(img: Image) -> void:
	_disk(img, 4.5, 3.5, 2.0, "o")
	_disk(img, 11.5, 3.5, 2.0, "o")
	_px(img, 4, 4, "p")
	_px(img, 11, 4, "p")
	_disk(img, 8.0, 8.5, 5.5, "o")
	_disk(img, 3.8, 10.5, 3.3, "c")
	_disk(img, 12.2, 10.5, 3.3, "c")
	_px(img, 6, 7, "k")
	_px(img, 9, 7, "k")
	_px(img, 7, 9, "p")
	_px(img, 8, 9, "p")
	_px(img, 3, 10, "s")
	_px(img, 4, 11, "S")
	_px(img, 12, 10, "s")
	_px(img, 11, 11, "S")


static func _bullets(img: Image) -> void:
	for y in [2, 6, 10]:
		_rect(img, 5, y, 7, 3, "y")
		_rect(img, 12, y, 1, 3, "Y")
		_px(img, 13, y + 1, "Y")
		_rect(img, 1, y + 1, 3, 1, "W")
		_px(img, 5, y, "Y")


static func _heart_tape(img: Image) -> void:
	_heart(img, 8.0, 8.5, 5.6, "r")
	_px(img, 4, 5, "p")
	_px(img, 5, 4, "p")
	_line(img, 2, 11, 12, 2, "g")
	_line(img, 3, 12, 13, 3, "W")
	_line(img, 4, 13, 14, 4, "g")


static func _fist(img: Image) -> void:
	_rect(img, 4, 6, 8, 6, "o")
	for fx in [4, 6, 8, 10]:
		_rect(img, fx, 3 if fx in [6, 8] else 4, 2, 4, "o")
	for fx in [6, 8, 10]:
		_px(img, fx, 5, "O")
	_rect(img, 2, 8, 3, 3, "o")
	_rect(img, 5, 12, 6, 3, "W")
	_rect(img, 5, 12, 6, 1, "g")
	_px(img, 13, 2, "y")
	_px(img, 14, 4, "y")
	_px(img, 1, 3, "y")
	_px(img, 2, 5, "y")


static func _magnet(img: Image) -> void:
	_rect(img, 2, 2, 4, 7, "r")
	_rect(img, 10, 2, 4, 7, "r")
	for yy in range(9, 15):
		for xx in SIZE:
			var dx := xx + 0.5 - 8.0
			var dy := yy + 0.5 - 9.0
			var d := dx * dx + dy * dy
			if d <= 36.0 and d >= 12.0:
				_px(img, xx, yy, "r")
	_rect(img, 2, 2, 4, 3, "W")
	_rect(img, 10, 2, 4, 3, "W")
	_px(img, 7, 3, "s")
	_px(img, 7, 4, "S")
	_px(img, 8, 6, "s")
	_px(img, 8, 7, "S")


static func _boot(img: Image) -> void:
	_rect(img, 1, 12, 14, 2, "W")
	_rect(img, 1, 13, 14, 1, "g")
	_rect(img, 4, 3, 5, 9, "o")
	_rect(img, 4, 8, 10, 4, "o")
	_rect(img, 11, 8, 3, 4, "O")
	_px(img, 8, 5, "w")
	_px(img, 8, 7, "w")
	_rect(img, 4, 3, 5, 1, "O")
	_rect(img, 0, 4, 2, 1, "W")
	_rect(img, 0, 7, 2, 1, "W")
	_rect(img, 0, 10, 2, 1, "W")


static func _barrels(img: Image) -> void:
	_rect(img, 1, 2, 3, 12, "T")
	for y in [2, 6, 10]:
		_rect(img, 4, y, 9, 3, "g")
		_rect(img, 4, y, 9, 1, "W")
		_rect(img, 4, y + 2, 9, 1, "G")
		_rect(img, 13, y, 2, 3, "G")
		_px(img, 15, y + 1, "y")


static func _weight_down(img: Image) -> void:
	_ring(img, 6.0, 4.5, 3.3, 1.6, "g")
	_disk(img, 6.0, 10.5, 4.8, "G")
	_px(img, 4, 8, "g")
	_px(img, 3, 9, "g")
	_px(img, 4, 9, "g")
	_arrow(img, 11, 2, true, "e")


static func _wheel_fire(img: Image) -> void:
	_ring(img, 8.0, 6.5, 5.5, 2.0, "g")
	_line(img, 8, 1, 8, 12, "W")
	_line(img, 3, 6, 13, 6, "W")
	_disk(img, 8.0, 6.5, 1.5, "G")
	_flame(img, 1, 9)
	_flame(img, 6, 8)
	_flame(img, 10, 9)


static func _spit(img: Image) -> void:
	for k in 8:
		var a := k * PI / 4.0
		var d := Vector2.from_angle(a)
		_px(img, int(7.5 + d.x * 4.5), int(7.5 + d.y * 4.5), "S")
		_px(img, int(7.5 + d.x * 6.0), int(7.5 + d.y * 6.0), "s")
	_disk(img, 8.0, 8.0, 2.6, "y")
	_disk(img, 8.0, 8.0, 1.2, "w")


static func _sun_vamp(img: Image) -> void:
	for k in 8:
		var a := k * PI / 4.0
		_disk(img, 8.0 + cos(a) * 5.0, 8.0 + sin(a) * 5.0, 2.0, "y")
	_disk(img, 8.0, 8.0, 3.6, "B")
	_px(img, 6, 7, "r")
	_px(img, 9, 7, "r")
	_rect(img, 6, 9, 1, 2, "w")
	_rect(img, 9, 9, 1, 2, "w")


static func _radiator(img: Image) -> void:
	_rect(img, 1, 3, 10, 2, "G")
	_rect(img, 1, 12, 10, 2, "G")
	for i in 4:
		_rect(img, 2 + i * 3, 5, 2, 7, "W")
		_rect(img, 2 + i * 3, 5, 1, 7, "w")
	_snow(img, 12, 5, 3)
	_px(img, 13, 11, "u")
	_px(img, 13, 12, "a")
	_px(img, 12, 14, "u")


static func _bottle(img: Image) -> void:
	_rect(img, 6, 0, 4, 2, "r")
	_rect(img, 5, 2, 6, 9, "A")
	_rect(img, 6, 2, 1, 9, "a")
	_rect(img, 5, 5, 6, 3, "w")
	_rect(img, 6, 11, 4, 1, "a")
	_stamp(img, 5, 12, ["iIIIi", ".iIi.", ".iIi.", "..i.."])


static func _bubble(img: Image) -> void:
	_ring(img, 8.0, 8.0, 7.2, 1.6, "a")
	_face(img, 8.0, 9.0, 3.4)
	_px(img, 3, 4, "w")
	_px(img, 4, 3, "w")
	_px(img, 3, 5, "w")
	_px(img, 12, 12, "w")


# ------------------------------------------------------------------ tower blueprints

static func _gatling_fire(img: Image) -> void:
	_rect(img, 2, 10, 12, 5, "t")
	_rect(img, 2, 14, 12, 1, "T")
	_disk(img, 6.0, 8.0, 3.4, "g")
	_rect(img, 8, 6, 6, 3, "G")
	_rect(img, 8, 6, 6, 1, "g")
	_flame(img, 11, 0)
	_px(img, 9, 3, "I")


static func _prism(img: Image) -> void:
	for y in range(2, 14):
		var hw := (y - 2) * 0.5 + 0.5
		_rect(img, int(8.0 - hw), y, int(hw * 2.0), 1, "a")
		_px(img, int(8.0 - hw), y, "w")
	_rect(img, 2, 13, 12, 1, "w")
	_line(img, 0, 9, 5, 9, "w")
	_line(img, 11, 10, 15, 6, "r")
	_line(img, 11, 10, 15, 10, "y")
	_line(img, 11, 10, 15, 14, "A")


static func _sneeze(img: Image) -> void:
	for d in 4:
		_line(img, 1 + d, 14, 6 + d, 8, "G")
	_line(img, 5, 7, 9, 7, "g")
	_line(img, 5, 8, 9, 8, "g")
	_disk(img, 11.0, 4.5, 3.2, "w")
	_disk(img, 7.5, 3.0, 2.2, "w")
	_disk(img, 13.5, 8.0, 2.2, "W")
	_px(img, 3, 3, "y")
	_px(img, 15, 2, "y")
	_px(img, 9, 9, "y")


static func _chain(img: Image) -> void:
	_ratface(img, 8.0, 3.5, 3.0)
	_ratface(img, 3.5, 12.0, 3.0)
	_ratface(img, 12.5, 12.0, 3.0)
	for d in 2:
		_line(img, 6 + d, 6, 4 + d, 9, "y")
		_line(img, 10 - d, 6, 12 - d, 9, "y")
	_line(img, 7, 12, 9, 12, "y")
	_line(img, 7, 13, 9, 13, "y")


static func _googly(img: Image) -> void:
	_disk(img, 3.5, 3.5, 2.3, "t")
	_disk(img, 12.5, 3.5, 2.3, "t")
	_disk(img, 8.0, 8.5, 6.0, "t")
	_disk(img, 5.5, 7.0, 2.7, "w")
	_disk(img, 10.5, 7.0, 2.7, "w")
	_rect(img, 6, 7, 2, 2, "k")
	_rect(img, 9, 6, 2, 2, "k")
	_px(img, 8, 10, "p")
	_line(img, 6, 12, 10, 12, "T")


static func _coupon(img: Image) -> void:
	_disk(img, 6.0, 8.0, 5.2, "y")
	_ring(img, 6.0, 8.0, 5.2, 1.2, "Y")
	_rect(img, 5, 5, 2, 7, "Y")
	_px(img, 7, 6, "Y")
	_px(img, 4, 10, "Y")
	_arrow(img, 11, 3, true, "e")


static func _sugar(img: Image) -> void:
	_rect(img, 2, 6, 9, 8, "W")
	_rect(img, 4, 3, 9, 3, "w")
	_rect(img, 11, 6, 3, 6, "g")
	_px(img, 1, 2, "y")
	_px(img, 14, 1, "y")
	_disk(img, 11.0, 11.0, 3.6, "w")
	_ring(img, 11.0, 11.0, 3.6, 1.0, "k")
	_line(img, 11, 11, 11, 9, "k")
	_line(img, 11, 11, 13, 11, "k")


static func _shells(img: Image) -> void:
	for p in [[1, 9], [5, 10], [9, 9], [3, 5], [7, 5], [5, 1]]:
		_seed(img, p[0], p[1])
	_rect(img, 0, 14, 16, 1, "E")
	_disk(img, 3.0, 14.0, 1.8, "e")
	_disk(img, 12.0, 14.0, 2.0, "e")
	_px(img, 13, 11, "e")
	_px(img, 13, 12, "e")


static func _tower_shield(img: Image) -> void:
	_rect(img, 1, 8, 8, 5, "t")
	_rect(img, 1, 12, 8, 1, "T")
	_disk(img, 5.0, 6.5, 2.8, "g")
	_rect(img, 6, 5, 5, 2, "G")
	_rect(img, 8, 5, 7, 6, "A")
	_rect(img, 9, 11, 5, 2, "A")
	_rect(img, 10, 13, 3, 1, "A")
	_rect(img, 9, 6, 2, 6, "a")
	_px(img, 11, 7, "w")
	_px(img, 11, 8, "w")


static func _magnify(img: Image) -> void:
	_disk(img, 6.5, 6.5, 4.2, "a")
	_ring(img, 6.5, 6.5, 5.6, 1.6, "W")
	_line(img, 10, 10, 14, 14, "b")
	_line(img, 10, 11, 13, 14, "b")
	_line(img, 11, 10, 14, 13, "B")
	_rect(img, 4, 7, 5, 3, "t")
	_px(img, 6, 5, "g")
	_px(img, 6, 6, "g")
	_px(img, 4, 3, "w")


static func _salt(img: Image) -> void:
	_rect(img, 2, 1, 5, 3, "g")
	_px(img, 3, 2, "G")
	_px(img, 5, 2, "G")
	_rect(img, 2, 4, 5, 6, "W")
	_rect(img, 2, 4, 1, 6, "w")
	for p in [[4, 11], [3, 12], [5, 12], [4, 13], [6, 11], [2, 14]]:
		_px(img, p[0], p[1], "w")
	_seed(img, 9, 9)
	_px(img, 12, 5, "w")
	_px(img, 11, 7, "w")


# ------------------------------------------------------------------ co-op synergies

static func _cables(img: Image) -> void:
	_face(img, 3.6, 11.0, 3.2)
	_face(img, 12.4, 11.0, 3.2)
	_bolt(img, 6, 0)
	_line(img, 3, 7, 5, 3, "W")
	_line(img, 13, 7, 11, 3, "W")
	_px(img, 5, 3, "y")
	_px(img, 11, 3, "y")


static func _brothers(img: Image) -> void:
	_heart(img, 4.2, 5.5, 2.8)
	_heart(img, 11.8, 5.5, 2.8)
	_disk(img, 4.5, 12.5, 2.0, "W")
	_disk(img, 8.0, 13.0, 2.2, "w")
	_disk(img, 11.5, 12.5, 2.0, "W")
	_px(img, 8, 5, "y")
	_px(img, 8, 6, "y")
	_px(img, 7, 5, "y")
	_px(img, 9, 6, "y")


static func _buddies(img: Image) -> void:
	_face(img, 4.5, 10.0, 3.8)
	_face(img, 11.5, 10.0, 3.8)
	_rect(img, 7, 0, 2, 5, "e")
	_rect(img, 5, 2, 6, 2, "e")


static func _shared(img: Image) -> void:
	_face(img, 3.2, 11.5, 3.0)
	_face(img, 12.8, 11.5, 3.0)
	for p in [[5, 7], [7, 4], [9, 4], [11, 7]]:
		_px(img, p[0], p[1], "s")
		_px(img, p[0], p[1] + 1, "S")
	_px(img, 8, 1, "y")
	_px(img, 8, 2, "y")


# ------------------------------------------------------------------ warp-cheese corruptions

static func _cat(img: Image) -> void:
	_rect(img, 1, 3, 14, 11, "V")
	_rect(img, 2, 1, 3, 3, "V")
	_rect(img, 11, 1, 3, 3, "V")
	_disk(img, 5.0, 8.0, 2.4, "z")
	_disk(img, 11.0, 8.0, 2.4, "z")
	_rect(img, 5, 6, 1, 4, "k")
	_rect(img, 11, 6, 1, 4, "k")
	for tx in [5, 7, 9, 11]:
		_px(img, tx, 12, "w")


static func _invert(img: Image) -> void:
	_harrow(img, 1, 14, 4, "e")
	_harrow(img, 14, 1, 10, "r")


static func _tower_fast(img: Image) -> void:
	_tower(img, 6, 7)
	_bolt(img, 0, 1)
	_rect(img, 1, 11, 3, 1, "W")
	_rect(img, 2, 13, 3, 1, "W")


static func _tower_hurt(img: Image) -> void:
	_rect(img, 2, 8, 12, 6, "t")
	_rect(img, 2, 13, 12, 1, "T")
	_disk(img, 8.0, 6.0, 3.5, "g")
	_rect(img, 10, 5, 5, 2, "G")
	_line(img, 6, 5, 8, 9, "k")
	_line(img, 8, 9, 6, 12, "k")
	_px(img, 4, 2, "y")
	_px(img, 13, 2, "y")
	_px(img, 1, 6, "r")


static func _leak(img: Image) -> void:
	_face(img, 8.0, 5.0, 4.4)
	_seed(img, 3, 10)
	_seed(img, 7, 11)
	_seed(img, 11, 10)
	_px(img, 4, 15, "W")
	_px(img, 8, 15, "W")
	_px(img, 12, 14, "W")


static func _seeds_more(img: Image) -> void:
	for p in [[1, 9], [5, 9], [9, 9], [3, 4], [7, 4]]:
		_seed(img, p[0], p[1])
	_rect(img, 12, 1, 2, 5, "e")
	_rect(img, 10, 2, 6, 2, "e")


static func _rat_chase(img: Image) -> void:
	_disk(img, 4.0, 4.0, 2.3, "m")
	_disk(img, 12.0, 4.0, 2.3, "m")
	_px(img, 4, 4, "q")
	_px(img, 12, 4, "q")
	_disk(img, 8.0, 9.0, 5.5, "m")
	_px(img, 6, 8, "r")
	_px(img, 10, 8, "r")
	_line(img, 5, 6, 7, 7, "k")
	_line(img, 11, 6, 9, 7, "k")
	_px(img, 8, 10, "q")
	_px(img, 7, 12, "w")
	_px(img, 9, 12, "w")
	_rect(img, 0, 7, 2, 1, "W")
	_rect(img, 0, 10, 2, 1, "W")


static func _burst(img: Image) -> void:
	for k in 12:
		var a := k * TAU / 12.0
		var len := 7.0 if k % 2 == 0 else 4.5
		var d := Vector2.from_angle(a)
		_line(img, 8, 8, int(7.5 + d.x * len), int(7.5 + d.y * len), "y" if k % 2 == 0 else "i")
	_disk(img, 8.0, 8.0, 3.0, "I")
	_disk(img, 8.0, 8.0, 1.5, "w")
