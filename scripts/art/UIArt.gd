extends RefCounted
## UI sprites.
## Names:
##   vending_machine      84x116-ish snack machine that drops in for the card draft
##                        (dispense slot centre is at VEND_SLOT; the sign text is drawn live)
##   tier_icon_mod        wrench           (Mech Mod)
##   tier_icon_tower      sunflower turret (Tower Blueprint)
##   tier_icon_synergy    linked hearts    (Co-op Synergy)
##   tier_icon_cursed     horned cheese    (Warp-Cheese Corruption)
##   horned_gouda         The Great Horned Gouda (game-over idol)
##   coin                 little seed-coin
##   zzz_hamster          sleeping hamster head (pause menu)
##   star                 Learning Mode maths star

const PA := preload("res://autoloads/PixelArt.gd")

const VEND_SLOT := Vector2(34, 102)       # dispense slot centre inside the machine sprite
const VEND_SIGN := Rect2(6, 5, 74, 12)     # sign area (text drawn live, flickering)


static func make(n: String) -> Image:
	match n:
		"vending_machine":
			return vending_machine()
		"tier_icon_mod":
			return PA.outline(PA.from_ascii([
				"W...W",
				"WW.WW",
				".WWW.",
				"..g..",
				"..W..",
				"..g..",
				"..W..",
			], 1))
		"tier_icon_tower":
			return PA.outline(PA.from_ascii([
				".y.y.",
				"yyByy",
				".yBy.",
				"yyyyy",
				"..E..",
				".tTt.",
				"tTTTt",
			], 1))
		"tier_icon_synergy":
			return PA.outline(PA.from_ascii([
				".r.r.....",
				"rrrrr.p.p",
				"rrrrrpppp",
				".rrrppppp",
				"..r.ppp..",
				".....p...",
			], 1))
		"tier_icon_cursed":
			return PA.outline(PA.from_ascii([
				"W.....W",
				"lW...Wl",
				".lyyyl.",
				".yzyzy.",
				"yyyyyyy",
				"yYyyYyy",
				"YYYYYYY",
			], 1))
		"horned_gouda":
			return horned_gouda()
		"coin":
			return PA.outline(PA.from_ascii([
				".yyy.",
				"yYsYy",
				"ysSsy",
				"yYsYy",
				".yyy.",
			], 1))
		"zzz_hamster":
			return sleeping_hamster()
		"star":
			return PA.outline(PA.from_ascii([
				"...y...",
				"..yIy..",
				"yyyIyyy",
				".yyyyy.",
				"..yyy..",
				".yyYyy.",
				".y...y.",
			], 1))
	return null


static func vending_machine() -> Image:
	var w := 88
	var h := 120
	var img := PA.new_img(w, h)
	var ox := 1
	var oy := 1
	var red := PA.col("r")
	# cabinet
	PA.rect(img, ox, oy + 2, 84, 110, red)
	PA.rect(img, ox + 2, oy, 80, 2, red)
	PA.rect(img, ox + 77, oy + 2, 7, 110, PA.col("R"))
	PA.rect(img, ox, oy + 2, 2, 110, red.lightened(0.25))
	PA.rect(img, ox + 2, oy, 75, 1, red.lightened(0.35))
	# sign panel (live text goes on top)
	PA.rect(img, ox + 4, oy + 3, 76, 14, PA.col("k"))
	PA.rect(img, ox + 5, oy + 4, 74, 12, PA.col("K"))
	# glass window
	PA.rect(img, ox + 4, oy + 20, 56, 72, PA.col("G"))
	PA.rect(img, ox + 6, oy + 22, 52, 68, PA.col("n"))
	var snack_cols := ["y", "p", "Z", "u", "o", "v", "Y", "i", "c"]
	for row in 3:
		var sy := oy + 22 + row * 22
		for col in 3:
			var sx := ox + 7 + col * 17
			var c := PA.col(snack_cols[(row * 3 + col) % snack_cols.size()])
			# snack packet
			PA.rect(img, sx + 2, sy + 4, 12, 11, c)
			PA.rect(img, sx + 2, sy + 4, 12, 2, c.lightened(0.35))
			PA.rect(img, sx + 4, sy + 8, 8, 3, PA.col("w"))
			PA.px(img, sx + 7, sy + 9, PA.col("s"))
			PA.px(img, sx + 8, sy + 9, PA.col("S"))
			# spiral coil underneath
			for k in 6:
				PA.px(img, sx + 2 + k * 2, sy + 16 + (k % 2), PA.col("g"))
				PA.px(img, sx + 3 + k * 2, sy + 17 - (k % 2), PA.col("W"))
		# shelf
		PA.rect(img, ox + 6, sy + 19, 52, 2, PA.col("g"))
		PA.rect(img, ox + 6, sy + 19, 52, 1, PA.col("W"))
	# glass glare
	var glare := Color(1, 1, 1, 0.22)
	for k in 40:
		PA.px(img, ox + 12 + k, oy + 86 - int(k * 1.5), glare)
		PA.px(img, ox + 13 + k, oy + 86 - int(k * 1.5), glare)
	for k in 20:
		PA.px(img, ox + 36 + k, oy + 86 - int(k * 1.5), Color(1, 1, 1, 0.12))
	# control panel
	PA.rect(img, ox + 62, oy + 20, 14, 72, PA.col("G"))
	PA.rect(img, ox + 62, oy + 20, 14, 1, PA.col("g"))
	PA.rect(img, ox + 64, oy + 23, 10, 7, PA.col("k"))
	PA.stamp_text(img, ox + 65, oy + 24, "25", PA.col("z"))
	for by in 4:
		for bx in 3:
			PA.rect(img, ox + 64 + bx * 4, oy + 34 + by * 4, 2, 2, PA.col("W"))
	PA.rect(img, ox + 66, oy + 53, 6, 12, PA.col("g"))
	PA.rect(img, ox + 68, oy + 55, 2, 8, PA.col("k"))
	PA.rect(img, ox + 64, oy + 70, 10, 7, PA.col("k"))
	PA.rect(img, ox + 65, oy + 71, 8, 2, PA.col("G"))
	# dispense slot
	PA.rect(img, ox + 6, oy + 95, 56, 13, PA.col("k"))
	PA.rect(img, ox + 7, oy + 96, 54, 4, PA.col("G"))
	PA.rect(img, ox + 7, oy + 96, 54, 1, PA.col("g"))
	PA.stamp_text(img, ox + 26, oy + 102, "PUSH", PA.col("G"))
	# stickers: seed logo + rat warning
	PA.rect(img, ox + 63, oy + 82, 12, 7, PA.col("y"))
	PA.stamp_text(img, ox + 64, oy + 83, "NO", PA.col("k"))
	PA.px(img, ox + 73, oy + 85, PA.col("M"))
	# feet
	PA.rect(img, ox + 3, oy + 112, 10, 4, PA.col("k"))
	PA.rect(img, ox + 71, oy + 112, 10, 4, PA.col("k"))
	# rivets
	for p in [Vector2i(3, 19), Vector2i(3, 93), Vector2i(80, 19), Vector2i(80, 93)]:
		PA.px(img, ox + p.x, oy + p.y, PA.col("W"))
	return PA.outline(img)


static func horned_gouda() -> Image:
	var w := 76
	var h := 64
	var img := PA.new_img(w, h)
	var cx := 38.0
	# horns (curving up and out)
	for side in [-1.0, 1.0]:
		for k in 16:
			var t := k / 15.0
			var x: float = cx + side * (14.0 + t * 16.0 + sin(t * PI) * 4.0)
			var y := 26.0 - t * 22.0 + t * t * 6.0
			var r := lerpf(4.0, 1.2, t)
			PA.disk(img, x, y, r, PA.col("l") if k % 4 != 0 else PA.col("h"))
	# wheel side band
	PA.ellipse(img, cx, 44, 30, 15, PA.col("Y"))
	PA.rect(img, int(cx - 30), 34, 60, 10, PA.col("Y"))
	# wheel top face
	PA.ellipse(img, cx, 34, 30, 13, PA.col("y"))
	# holes
	for hp in [Vector2(cx - 18, 32), Vector2(cx + 16, 36), Vector2(cx - 6, 41), Vector2(cx + 22, 29), Vector2(cx - 24, 46), Vector2(cx + 8, 49)]:
		PA.ellipse(img, hp.x, hp.y, 3.0, 2.0, PA.col("Y").darkened(0.15))
	# glowing eyes
	for side in [-1.0, 1.0]:
		PA.ellipse(img, cx + side * 9.0, 32, 4.5, 3.2, PA.col("z"))
		PA.rect(img, int(cx + side * 9.0), 30, 1, 5, PA.col("k"))
	# evil grin with teeth
	for k in 21:
		var x := int(cx - 10 + k)
		var y := 39 + int(sin(k / 20.0 * PI) * 3.0)
		PA.px(img, x, y, PA.col("k"))
		if k % 4 == 1:
			PA.px(img, x, y + 1, PA.col("w"))
	# wax rind bottom stripe
	PA.rect(img, int(cx - 30), 52, 60, 2, PA.col("r"))
	return PA.outline(img)


static func sleeping_hamster() -> Image:
	var img := PA.new_img(26, 18)
	var cx := 13.0
	PA.disk(img, cx - 4, 4.5, 2.0, PA.col("o"))
	PA.disk(img, cx + 4, 4.5, 2.0, PA.col("o"))
	PA.ellipse(img, cx, 10, 9.0, 6.0, PA.col("o"))
	PA.ellipse(img, cx, 12, 6.0, 3.5, PA.col("c"))
	# closed eyes
	PA.rect(img, int(cx - 4), 9, 2, 1, PA.col("k"))
	PA.rect(img, int(cx + 3), 9, 2, 1, PA.col("k"))
	PA.px(img, int(cx), 11, PA.col("p"))
	PA.px(img, int(cx - 1), 13, PA.col("O"))
	return PA.outline(img)
