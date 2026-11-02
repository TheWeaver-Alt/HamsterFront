extends RefCounted
## Hamster pilots and their junkyard mechs. All parts face RIGHT.
## Names (legacy names are kept so the title screen / HUD keep working):
##   ham_head_0..8, ham_head_dizzy   pilot head; cheeks inflate with the pouch (26x20, centre 13,10)
##   brawler_torso                   BRAWLER-01 espresso-machine body (26x24 canvas, feet at 13,22)
##   brawler_legs_0..5               6-frame piston-leg walk cycle (same canvas)
##   brawler_legs_idle / _down       standing / slumped legs
##   brawler_body_0/1                legacy composites (legs + torso)
##   brawler_dome / _crack           glass cockpit (18x18, centre 9,9) / cracked variant
##   brawler_gun                     Sawdust Shotgun incl. pump (legacy, 18x9)
##   brawler_gun_body                shotgun without the pump forend (pump drawn live)
##   brawler_fist / _smear           Cardboard-Tube Fist (18x10) / punch motion smear (24x10)
##   porthole_wheel_0..3             tiny hamster wheel seen through the brawler's porthole (7x7)
##   jetpack_bottle                  Soda-Bottle Jetpack strapped to the back (8x14, nozzle down)
##   jet_flame_0..2                  fizzy rocket plume (8x10)
##   wheeler_ball / _crack           WHEELER-X glass ball (24x24, centre 12,12) / crack overlay
##   wheeler_hub                     spider-leg hub under the ball (16x6)
##   wheeler_wheel_0..3              inner exercise wheel, 4 rotation frames (20x20)
##   wheeler_ham_0..3, _idle         running / sitting hamster inside the ball (14x12)
##   wheeler_rails                   dual Toothpick Railguns, legacy composite (18x11)
##   wheeler_rail_housing / _barrel  railgun parts for per-barrel recoil (9x11 / 14x3)

const PA := preload("res://autoloads/PixelArt.gd")

# brawler gait: [back dx, back lift, front dx, front lift] per frame
const GAIT := [
	[2, 0, -2, 0], [1, 2, -1, 0], [-1, 2, 1, 0], [-2, 0, 2, 0], [-1, 0, 1, 2], [1, 0, -1, 2],
]


static func make(n: String) -> Image:
	if n.begins_with("ham_head_"):
		var suffix := n.substr(9)
		if suffix == "dizzy":
			return head(0.5, true)
		return head(clampi(int(suffix), 0, 8) / 8.0, false)
	if n.begins_with("brawler_legs_"):
		var s := n.substr(13)
		if s == "idle":
			return brawler_legs(-1, 0, 1, 0, false)
		if s == "down":
			return brawler_legs(-5, 0, 5, 0, true)
		var g: Array = GAIT[clampi(int(s), 0, 5)]
		return brawler_legs(g[0], g[1], g[2], g[3], false)
	if n.begins_with("porthole_wheel_"):
		return porthole_wheel(int(n.substr(15)))
	if n.begins_with("jet_flame_"):
		return jet_flame(int(n.substr(10)))
	if n.begins_with("wheeler_wheel_"):
		return inner_wheel(int(n.substr(14)))
	match n:
		"brawler_torso":
			return brawler_torso()
		"brawler_body_0":
			return _composite([brawler_legs(-1, 0, 1, 0, false), brawler_torso()])
		"brawler_body_1":
			return _composite([brawler_legs(-1, 2, 1, 0, false), brawler_torso()])
		"brawler_dome":
			return dome(false)
		"brawler_dome_crack":
			return dome(true)
		"brawler_gun":
			return brawler_gun(true)
		"brawler_gun_body":
			return brawler_gun(false)
		"brawler_fist":
			return brawler_fist()
		"brawler_fist_smear":
			return fist_smear()
		"jetpack_bottle":
			return jetpack_bottle()
		"wheeler_ball":
			return wheeler_ball()
		"wheeler_ball_crack":
			return ball_crack()
		"wheeler_hub":
			return wheeler_hub()
		"wheeler_ham_0":
			return wheeler_ham(0)
		"wheeler_ham_1":
			return wheeler_ham(2)
		"wheeler_ham_2":
			return wheeler_ham(1)
		"wheeler_ham_3":
			return wheeler_ham(3)
		"wheeler_ham_idle":
			return wheeler_ham(-1)
		"wheeler_rails":
			return wheeler_rails()
		"wheeler_rail_housing":
			return rail_housing()
		"wheeler_rail_barrel":
			var padded := PA.new_img(16, 5)
			PA.blit(padded, rail_barrel(), 1, 1)
			return PA.outline(padded)
	return null


static func _composite(layers: Array) -> Image:
	var base: Image = (layers[0] as Image).duplicate()
	for i in range(1, layers.size()):
		PA.blit(base, layers[i], 0, 0)
	return base


static func _c(k: String, lighten: float = 0.0) -> Color:
	var c := PA.col(k)
	if lighten > 0.0:
		return c.lightened(lighten)
	if lighten < 0.0:
		return c.darkened(-lighten)
	return c


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


# ------------------------------------------------------------------ pilot head

## Pilot head. f 0..1 = cheek inflation. 26x20, centre (13,10).
static func head(f: float, dizzy: bool) -> Image:
	var img := PA.new_img(26, 20)
	var cx := 13.0
	var cy := 10.0
	var fur := _c("o")
	var fur_dk := _c("O")
	var fur_lt := _c("o", 0.22)
	var cream := _c("c")
	var cream_dk := _c("c", -0.12)
	var pink := _c("p")
	# ears (outer + pink inner)
	PA.disk(img, cx - 3.8, cy - 4.4, 2.0, fur_dk)
	PA.disk(img, cx + 3.8, cy - 4.4, 2.0, fur_dk)
	PA.disk(img, cx - 3.7, cy - 4.2, 1.1, pink)
	PA.disk(img, cx + 3.7, cy - 4.2, 1.1, pink)
	# head, lit from the top-left
	PA.disk(img, cx, cy - 0.5, 4.7, fur)
	PA.disk(img, cx - 1.3, cy - 2.3, 2.4, fur_lt)
	PA.px(img, int(cx + 3), int(cy + 1), fur_dk)
	PA.px(img, int(cx + 4), int(cy - 1), fur_dk)
	# forehead stripe
	PA.px(img, int(cx), int(cy - 5), fur_dk)
	PA.px(img, int(cx), int(cy - 4), fur_dk)
	# muzzle
	PA.ellipse(img, cx, cy + 1.6, 2.7, 2.1, cream)
	# cheeks bulge outward & downward as the pouch fills
	var cr := 1.3 + f * 4.4
	var cdx := 2.8 + f * 2.8
	var cyy := cy + 1.4 + f * 1.2
	for side in [-1.0, 1.0]:
		PA.disk(img, cx + side * cdx, cyy, cr, cream)
		# soft underside shading
		if cr > 2.0:
			PA.disk(img, cx + side * cdx + side * cr * 0.25, cyy + cr * 0.45, cr * 0.55, cream_dk)
			PA.disk(img, cx + side * cdx - side * cr * 0.1, cyy - cr * 0.15, cr * 0.75, cream)
	PA.ellipse(img, cx, cy + 1.6, 2.4, 1.9, cream)
	if f >= 0.3:
		var bl := 1 if f < 0.6 else 2
		for side in [-1, 1]:
			for k in bl:
				PA.px(img, int(cx + side * cdx) + k * side - (1 if side < 0 else 0), int(cyy), pink)
	if f >= 0.7:
		# stretched-cheek shine
		PA.px(img, int(cx - cdx - cr * 0.5), int(cyy - cr * 0.55), _c("w"))
		PA.px(img, int(cx + cdx + cr * 0.4), int(cyy - cr * 0.55), _c("w"))
	# whiskers (hidden once the cheeks are huge)
	if f < 0.55:
		var wx := cdx + cr + 1.0
		for side in [-1.0, 1.0]:
			PA.px(img, int(cx + side * wx), int(cy + 1), _c("W"))
			PA.px(img, int(cx + side * (wx + 1.0)), int(cy + 1), _c("W"))
			PA.px(img, int(cx + side * wx), int(cy + 3), _c("W"))
	# eyes
	var k := _c("k")
	var w := _c("w")
	if dizzy:
		for ex in [-3, 3]:
			var ec := Vector2i(int(cx) + ex, int(cy) - 1)
			for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, 1)]:
				PA.px(img, ec.x + d.x, ec.y + d.y, k)
		# wobbly mouth
		PA.px(img, int(cx - 1), int(cy + 2), fur_dk)
		PA.px(img, int(cx), int(cy + 3), fur_dk)
		PA.px(img, int(cx + 1), int(cy + 2), fur_dk)
	elif f >= 0.85:
		# squinting > <  with strained brows
		PA.px(img, int(cx - 3), int(cy - 2), k)
		PA.px(img, int(cx - 2), int(cy - 1), k)
		PA.px(img, int(cx - 3), int(cy), k)
		PA.px(img, int(cx + 3), int(cy - 2), k)
		PA.px(img, int(cx + 2), int(cy - 1), k)
		PA.px(img, int(cx + 3), int(cy), k)
		PA.px(img, int(cx - 4), int(cy - 4), fur_dk)
		PA.px(img, int(cx - 3), int(cy - 3), fur_dk)
		PA.px(img, int(cx + 4), int(cy - 4), fur_dk)
		PA.px(img, int(cx + 3), int(cy - 3), fur_dk)
	else:
		for ex in [-3, 2]:
			PA.rect(img, int(cx) + ex, int(cy) - 2, 2, 2, k)
			PA.px(img, int(cx) + ex, int(cy) - 2, w)
	# nose, mouth, buck teeth
	PA.px(img, int(cx), int(cy), pink)
	if not dizzy:
		if f < 0.5:
			PA.px(img, int(cx - 1), int(cy + 1), fur_dk)
			PA.px(img, int(cx + 1), int(cy + 1), fur_dk)
			PA.px(img, int(cx), int(cy + 2), w)
		else:
			PA.px(img, int(cx - 1), int(cy + 2), fur_dk)
			PA.px(img, int(cx), int(cy + 2), w)
			PA.px(img, int(cx + 1), int(cy + 2), fur_dk)
			if f >= 0.85:
				# a seed poking out of the stuffed mouth
				PA.px(img, int(cx + 1), int(cy + 3), _c("s"))
				PA.px(img, int(cx + 2), int(cy + 3), _c("S"))
	return PA.outline(img)


# ------------------------------------------------------------------ BRAWLER-01

## Espresso-machine torso on a 26x24 canvas (legs drawn separately, feet at 13,22).
static func brawler_torso() -> Image:
	var img := PA.new_img(26, 24)
	var r := _c("r")
	var rl := _c("r", 0.28)
	var rd := _c("R")
	var W := _c("W")
	var g := _c("g")
	var G := _c("G")
	var w := _c("w")
	# --- steam chimney (back)
	PA.rect(img, 2, 2, 3, 8, g)
	PA.rect(img, 2, 2, 1, 8, W)
	PA.rect(img, 4, 2, 1, 8, G)
	PA.rect(img, 1, 1, 5, 2, G)
	PA.rect(img, 1, 1, 5, 1, g)
	PA.px(img, 1, 1, W)
	PA.rect(img, 2, 5, 3, 1, G)
	# --- chrome top plate with cup rail
	PA.rect(img, 3, 6, 20, 3, g)
	PA.rect(img, 3, 6, 20, 1, W)
	PA.rect(img, 3, 8, 20, 1, G)
	for x in [5, 7, 19, 21]:
		PA.px(img, x, 5, g)
	PA.rect(img, 5, 4, 3, 1, W)
	PA.rect(img, 19, 4, 3, 1, W)
	# --- red body, 3-tone
	PA.rect(img, 4, 9, 18, 9, r)
	PA.rect(img, 4, 9, 18, 1, rl)
	PA.rect(img, 4, 9, 1, 9, rl)
	PA.rect(img, 20, 10, 2, 8, rd)
	PA.rect(img, 4, 17, 18, 1, rd)
	PA.px(img, 5, 10, rl)
	# --- porthole window (the hamster wheel shows through it, drawn live)
	PA.disk(img, 9.5, 13.5, 3.5, G)
	PA.disk(img, 9.5, 13.5, 3.0, W)
	PA.disk(img, 9.5, 13.5, 2.4, _c("n"))
	PA.px(img, 7, 11, w)
	# --- pressure gauge (needle drawn live)
	PA.disk(img, 16.0, 11.5, 2.2, G)
	PA.disk(img, 16.0, 11.5, 1.6, w)
	PA.px(img, 17, 10, r)
	# --- group head + portafilter + handle (front)
	PA.rect(img, 18, 12, 4, 2, W)
	PA.rect(img, 18, 13, 4, 1, g)
	PA.rect(img, 17, 14, 5, 2, G)
	PA.rect(img, 17, 14, 5, 1, g)
	PA.rect(img, 22, 14, 3, 2, _c("B"))
	PA.rect(img, 22, 14, 3, 1, _c("b"))
	# drip tray grate
	for x in range(16, 23):
		PA.px(img, x, 17, W if x % 2 == 0 else g)
	# --- duct tape: vertical band + diagonal strip, with crinkle texture
	for y in range(9, 18):
		PA.px(img, 13, y, W)
		PA.px(img, 14, y, g if y % 3 == 0 else W)
	for i in 4:
		PA.px(img, 5 + i, 16 - i, W)
		PA.px(img, 6 + i, 16 - i, g if i % 2 == 0 else W)
	# rivets
	for p in [Vector2i(5, 10), Vector2i(19, 10), Vector2i(19, 16)]:
		PA.px(img, p.x, p.y, W)
	return PA.outline(img)


## Piston legs. dx/lift per leg; `slump` = downed splay.
static func brawler_legs(back_dx: int, back_lift: int, front_dx: int, front_lift: int, slump: bool) -> Image:
	var img := PA.new_img(26, 24)
	_leg(img, Vector2i(8, 17), back_dx, back_lift, true, slump)
	_leg(img, Vector2i(17, 17), front_dx, front_lift, false, slump)
	return PA.outline(img)


static func _leg(img: Image, hip: Vector2i, dx: int, lift: int, back: bool, slump: bool) -> void:
	var shade := -0.25 if back else 0.0
	var G := _c("G", shade)
	var g := _c("g", shade)
	var W := _c("W", shade)
	var foot := Vector2i(hip.x + dx, 21 - lift)
	var knee := Vector2i(hip.x + int(roundf(dx * 0.5)), 19 - int(roundf(lift * 0.6)))
	if slump:
		knee = Vector2i(hip.x + int(roundf(dx * 0.6)), 20)
		foot = Vector2i(hip.x + dx, 21)
	# hip socket
	PA.rect(img, hip.x - 1, hip.y - 1, 4, 2, G)
	# chunky thigh piston, lit from the left
	PA.line(img, hip.x - 1, hip.y, knee.x - 1, knee.y, W)
	PA.line(img, hip.x, hip.y, knee.x, knee.y, g)
	PA.line(img, hip.x + 1, hip.y, knee.x + 1, knee.y, G)
	PA.line(img, hip.x + 2, hip.y, knee.x + 2, knee.y, G)
	# shin
	PA.line(img, knee.x, knee.y, foot.x, foot.y, g)
	PA.line(img, knee.x + 1, knee.y, foot.x + 1, foot.y, G)
	# knee pad
	PA.rect(img, knee.x - 1, knee.y, 3, 1, W)
	PA.px(img, knee.x + 2, knee.y, g)
	# big boot: dark sole, lit top, steel toe cap
	PA.rect(img, foot.x - 2, foot.y, 6, 2, G)
	PA.rect(img, foot.x - 2, foot.y, 6, 1, g)
	PA.px(img, foot.x - 2, foot.y, W)
	PA.rect(img, foot.x + 3, foot.y, 1, 2, W)
	PA.px(img, foot.x + 4, foot.y + 1, g)


## Glass cockpit dome with chrome collar. 18x18, centre (9,9), r 7.
static func dome(cracked: bool) -> Image:
	var img := PA.new_img(18, 18)
	var c := 9.0
	var r := 7.0
	PA.disk(img, c, c, r, _alpha(_c("a"), 0.2))
	# denser glass towards the bottom (reflection of the machine)
	for y in range(10, 17):
		for x in 18:
			var p := img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, _alpha(_c("A"), 0.26))
	PA.ring(img, c, c, r, 1.0, _alpha(_c("a"), 0.9))
	# chrome mounting collar
	PA.rect(img, 3, 14, 13, 1, _c("W"))
	PA.rect(img, 3, 15, 13, 1, _c("g"))
	for x in [5, 9, 13]:
		PA.px(img, x, 15, _c("G"))
	# highlights
	var w := _c("w")
	PA.px(img, 5, 4, w)
	PA.px(img, 6, 3, w)
	PA.px(img, 7, 3, w)
	PA.px(img, 4, 6, w)
	PA.px(img, 4, 5, _alpha(w, 0.7))
	PA.px(img, 12, 4, _alpha(w, 0.6))
	PA.px(img, 13, 11, _alpha(w, 0.45))
	if cracked:
		var cw := _alpha(w, 0.95)
		var ck := _alpha(_c("k"), 0.6)
		PA.line(img, 6, 5, 9, 8, cw)
		PA.line(img, 9, 8, 8, 11, cw)
		PA.line(img, 9, 8, 12, 7, cw)
		PA.px(img, 12, 6, cw)
		PA.px(img, 9, 8, ck)
	return img


static func porthole_wheel(n: int) -> Image:
	var img := PA.new_img(7, 7)
	var c := Vector2(3.5, 3.5)
	PA.ring(img, c.x, c.y, 3.4, 1.0, _c("g"))
	for k in 4:
		var a := (n % 4) * PI / 8.0 + k * PI / 2.0
		var tip := c + Vector2.from_angle(a) * 2.6
		PA.line(img, 3, 3, int(roundf(tip.x - 0.5)), int(roundf(tip.y - 0.5)), _alpha(_c("W"), 0.85))
	# the tiny hamster jogging at the bottom of the wheel
	PA.px(img, 3, 5, _c("o"))
	PA.px(img, 4, 5, _c("o"))
	PA.px(img, 3, 4, _c("c"))
	return img


static func brawler_gun(with_pump: bool) -> Image:
	var img := PA.new_img(18, 9)
	# wooden stock with grain
	PA.rect(img, 0, 4, 5, 3, _c("b"))
	PA.rect(img, 0, 4, 5, 1, _c("t"))
	PA.px(img, 2, 5, _c("B"))
	PA.px(img, 3, 6, _c("B"))
	# receiver + trigger guard
	PA.rect(img, 4, 3, 5, 3, _c("G"))
	PA.rect(img, 4, 3, 5, 1, _c("g"))
	PA.px(img, 6, 6, _c("G"))
	PA.px(img, 7, 6, _c("G"))
	# barrel
	PA.rect(img, 8, 3, 7, 2, _c("g"))
	PA.rect(img, 8, 3, 7, 1, _c("W"))
	PA.px(img, 11, 3, _c("G"))
	PA.px(img, 11, 4, _c("G"))
	# sawdust hopper funnel
	PA.rect(img, 5, 1, 4, 2, _c("T"))
	PA.rect(img, 4, 0, 6, 1, _c("t"))
	PA.px(img, 6, 0, _c("y"))
	PA.px(img, 8, 0, _c("Y"))
	# flared muzzle bell
	PA.rect(img, 15, 2, 2, 4, _c("G"))
	PA.px(img, 17, 2, _c("G"))
	PA.px(img, 17, 5, _c("G"))
	PA.px(img, 15, 2, _c("g"))
	if with_pump:
		PA.rect(img, 9, 5, 4, 1, _c("t"))
	return PA.outline(img)


static func brawler_fist() -> Image:
	var img := PA.new_img(18, 10)
	# cardboard tube with spiral seam
	PA.rect(img, 1, 3, 9, 4, _c("t"))
	PA.rect(img, 1, 3, 9, 1, _c("c"))
	PA.rect(img, 1, 6, 9, 1, _c("T"))
	for i in [1, 5]:
		PA.px(img, i, 6, _c("T"))
		PA.px(img, i + 1, 5, _c("T"))
		PA.px(img, i + 2, 4, _c("T"))
	# wrist tape
	PA.rect(img, 9, 3, 2, 4, _c("W"))
	PA.px(img, 10, 4, _c("g"))
	# red boxing glove with lace + thumb
	PA.disk(img, 12.5, 5.0, 3.7, _c("r"))
	PA.px(img, 15, 7, _c("R"))
	PA.px(img, 16, 6, _c("R"))
	PA.px(img, 14, 8, _c("R"))
	PA.px(img, 11, 3, _c("r", 0.4))
	PA.px(img, 12, 2, _c("r", 0.4))
	PA.px(img, 13, 2, _c("r", 0.3))
	PA.disk(img, 11.0, 7.6, 1.3, _c("r"))
	PA.px(img, 12, 5, _c("w"))
	PA.px(img, 12, 6, _c("w"))
	return PA.outline(img)


static func fist_smear() -> Image:
	var img := PA.new_img(24, 10)
	for x in 16:
		var a := 0.06 + 0.3 * float(x) / 15.0
		for y in range(3, 7):
			PA.px(img, x + 2, y, _alpha(_c("w"), a))
	for x in range(0, 14, 3):
		PA.px(img, x, 2, _alpha(_c("W"), 0.5))
		PA.px(img, x + 1, 8, _alpha(_c("W"), 0.4))
	return img


static func jetpack_bottle() -> Image:
	var img := PA.new_img(8, 14)
	var soda := Color8(110, 200, 120)
	var soda_dk := Color8(60, 140, 80)
	# petal base (upside down, so the base is on top)
	PA.rect(img, 1, 0, 6, 1, soda_dk)
	PA.rect(img, 1, 1, 6, 9, soda)
	PA.rect(img, 6, 1, 1, 9, soda_dk)
	PA.rect(img, 2, 1, 1, 8, _alpha(_c("w"), 0.8))
	# label
	PA.rect(img, 1, 4, 6, 3, _c("r"))
	PA.rect(img, 1, 4, 6, 1, _c("r", 0.3))
	PA.px(img, 3, 5, _c("w"))
	PA.px(img, 4, 5, _c("w"))
	# shoulders, neck and red cap = nozzle
	PA.rect(img, 2, 10, 4, 1, soda)
	PA.rect(img, 3, 11, 2, 1, soda_dk)
	PA.rect(img, 3, 12, 2, 2, _c("R"))
	# straps
	PA.rect(img, 0, 2, 8, 1, _c("B"))
	PA.rect(img, 0, 8, 8, 1, _c("B"))
	return PA.outline(img)


static func jet_flame(n: int) -> Image:
	var img := PA.new_img(8, 10)
	var lens := [7, 9, 6]
	var L: int = lens[n % 3]
	# fizz foam at the nozzle
	PA.rect(img, 2, 0, 4, 2, _alpha(_c("w"), 0.95))
	PA.px(img, 1, 1, _alpha(_c("a"), 0.9))
	PA.px(img, 6, 0, _alpha(_c("a"), 0.9))
	# flame
	for y in range(2, L):
		var t := float(y - 2) / float(maxi(1, L - 2))
		var hw := lerpf(2.0, 0.5, t)
		for x in range(int(4.0 - hw), int(4.0 + hw)):
			var c := _c("I") if t < 0.35 else (_c("i") if t < 0.75 else _c("r"))
			PA.px(img, x, y, c)
	# bubbles
	PA.px(img, 1 + n, 4 + n, _alpha(_c("a"), 0.8))
	PA.px(img, 6 - n, 6, _alpha(_c("w"), 0.7))
	return img


# ------------------------------------------------------------------ WHEELER-X

static func wheeler_ball() -> Image:
	var img := PA.new_img(24, 24)
	var c := 12.0
	PA.disk(img, c, c, 10.0, _alpha(_c("a"), 0.2))
	for y in range(13, 23):
		for x in 24:
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, _alpha(_c("A"), 0.3))
	PA.ring(img, c, c, 9.0, 1.0, _alpha(_c("A"), 0.22))
	PA.ring(img, c, c, 10.0, 1.0, _alpha(_c("a"), 0.95))
	# equator seam
	for x in range(3, 22):
		PA.px(img, x, 12, _alpha(_c("w"), 0.28))
	# top hatch with vents + antenna
	PA.rect(img, 9, 2, 6, 2, _c("g"))
	PA.rect(img, 9, 2, 6, 1, _c("W"))
	for x in [10, 12, 14]:
		PA.px(img, x, 3, _c("G"))
	PA.px(img, 14, 1, _c("G"))
	PA.px(img, 15, 0, _c("G"))
	# side air vents
	for v in [Vector2i(19, 7), Vector2i(20, 9), Vector2i(20, 11)]:
		PA.px(img, v.x, v.y, _c("A"))
	# highlights
	var w := _c("w")
	PA.px(img, 6, 6, w)
	PA.px(img, 7, 5, w)
	PA.px(img, 8, 4, w)
	PA.px(img, 5, 8, w)
	PA.px(img, 5, 7, _alpha(w, 0.6))
	PA.px(img, 17, 17, _alpha(w, 0.5))
	PA.px(img, 16, 18, _alpha(w, 0.35))
	# weld mount at the bottom
	PA.rect(img, 9, 21, 6, 2, _c("g"))
	PA.rect(img, 10, 22, 4, 1, _c("G"))
	return img


static func ball_crack() -> Image:
	var img := PA.new_img(24, 24)
	var cw := _alpha(_c("w"), 0.9)
	PA.line(img, 15, 5, 13, 9, cw)
	PA.line(img, 13, 9, 15, 12, cw)
	PA.line(img, 13, 9, 10, 10, cw)
	PA.line(img, 6, 15, 8, 17, cw)
	PA.px(img, 13, 9, _alpha(_c("k"), 0.5))
	return img


static func wheeler_hub() -> Image:
	var img := PA.new_img(16, 6)
	PA.ellipse(img, 8, 3, 7.0, 2.6, _c("G"))
	PA.ellipse(img, 8, 2.4, 5.5, 1.6, _c("g"))
	for x in [2, 4, 11, 13]:
		PA.px(img, x, 3, _c("k"))
	PA.px(img, 8, 2, _c("W"))
	return PA.outline(img)


static func inner_wheel(n: int) -> Image:
	var img := PA.new_img(20, 20)
	var c := Vector2(10, 10)
	PA.ring(img, c.x, c.y, 9.0, 1.0, _alpha(_c("g"), 0.55))
	PA.ring(img, c.x, c.y, 7.6, 1.0, _alpha(_c("g"), 0.25))
	# rungs between the rims
	for k in 12:
		var a := (n % 4) * PI / 24.0 + k * TAU / 12.0
		var p := c + Vector2.from_angle(a) * 8.3
		PA.px(img, int(p.x), int(p.y), _alpha(_c("W"), 0.6))
	for k in 4:
		var a := (n % 4) * PI / 8.0 + k * PI / 2.0
		var tip := c + Vector2.from_angle(a) * 7.4
		PA.line(img, 10, 10, int(roundf(tip.x)), int(roundf(tip.y)), _alpha(_c("W"), 0.35))
	PA.px(img, 10, 10, _alpha(_c("W"), 0.8))
	return img


## Hamster inside the ball. frame 0..3 running, -1 sitting.
static func wheeler_ham(frame: int) -> Image:
	var img := PA.new_img(14, 12)
	var fur := _c("o")
	var p := _c("p")
	if frame < 0:
		PA.ellipse(img, 7, 6.5, 4.6, 4.0, fur)
		PA.ellipse(img, 7, 7.5, 3.0, 2.6, _c("c"))
		PA.px(img, 6, 6, p)
		PA.px(img, 8, 6, p)
		PA.px(img, 4, 10, p)
		PA.px(img, 9, 10, p)
		PA.px(img, 2, 8, p)
		return PA.outline(img)
	var lean := 1.0 if frame % 2 == 1 else 0.0
	PA.ellipse(img, 7 + lean * 0.5, 6, 5.0, 3.6, fur)
	PA.ellipse(img, 6.5 + lean * 0.5, 4.6, 3.2, 1.6, fur.lightened(0.18))
	PA.ellipse(img, 7.5, 7.2, 3.2, 2.2, _c("c"))
	PA.px(img, 2, 6, p)   # tail
	var fx := [0, 1, 2, 1]
	var bx := [2, 1, 0, 1]
	var f := frame % 4
	PA.px(img, 9 + fx[f], 10, p)
	PA.px(img, 10 + fx[f], 10, p)
	PA.px(img, 3 + bx[f], 10 - (1 if f == 1 else 0), p)
	PA.px(img, 4 + bx[f], 10, p)
	# pumping arms
	var ay := [5, 6, 7, 6]
	PA.px(img, 12, ay[f], p)
	PA.px(img, 11, 11 - ay[f], p)
	return PA.outline(img)


static func rail_housing() -> Image:
	var img := PA.new_img(9, 11)
	PA.rect(img, 1, 2, 6, 7, _c("G"))
	PA.rect(img, 1, 2, 6, 1, _c("g"))
	PA.rect(img, 1, 2, 1, 7, _c("g"))
	PA.px(img, 2, 4, _c("W"))
	PA.px(img, 2, 7, _c("W"))
	# capacitor glow strip
	PA.rect(img, 4, 4, 2, 3, _c("u"))
	PA.px(img, 4, 4, _c("a"))
	return PA.outline(img)


static func rail_barrel() -> Image:
	var img := PA.new_img(14, 3)
	PA.rect(img, 0, 0, 11, 2, _c("W"))
	PA.rect(img, 0, 1, 11, 1, _c("g"))
	for x in [2, 5, 8]:
		PA.px(img, x, 0, _c("u"))
		PA.px(img, x, 1, _c("A"))
	PA.px(img, 11, 0, _c("t"))
	PA.px(img, 12, 0, _c("c"))
	PA.px(img, 11, 1, _c("T"))
	return img


static func wheeler_rails() -> Image:
	var img := PA.new_img(18, 11)
	var bar := rail_barrel()
	PA.blit(img, bar, 4, 2)
	PA.blit(img, bar, 4, 7)
	PA.blit(img, rail_housing(), 0, 0)
	return PA.outline(img)
