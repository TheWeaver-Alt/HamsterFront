extends RefCounted
## Under-Scurrier sprites. All face RIGHT; entities flip_h when moving left.
## Names:
##   rat_squeaker_0/1    Clan-Squeaker walk frames (bent fork, glowing eyes)
##   rat_squeaker_trip   tripped over a tail, flat on its face
##   rat_squeaker_ball   curled-up squeaker (being thrown by a Rat-Ogre)
##   rat_jezzail_0/1     Warp-Gouda Jezzail team: gunner + bipod rat under a rusty pipe rifle
##   rat_monk_0/1        Plague-Stink Monk (hooded robe; cheese flail is drawn live)
##   rat_roomba          Doom-Roomba: spiked robot vacuum, warp coils, tiny goggled rider
##   rat_ogre_0/1        Rat-Ogre Bruiser walk frames (oven mitts, scrap-iron plates, stitches)
##   rat_ogre_slam       Rat-Ogre arms raised overhead (slam / throw wind-up)

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
		"rat_jezzail_0":
			return jezzail(0)
		"rat_jezzail_1":
			return jezzail(1)
		"rat_monk_0":
			return monk(0)
		"rat_monk_1":
			return monk(1)
		"rat_roomba":
			return roomba()
		"rat_ogre_0":
			return ogre(0)
		"rat_ogre_1":
			return ogre(1)
		"rat_ogre_slam":
			return ogre(2)
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


## Two-rat sniper team. Gunner (left) shoulders a rusty pipe rifle whose barrel rests on the
## back of a crouching bipod rat (right). A glowing warp-cheese cell feeds the rifle.
## Muzzle pixel sits at image (31, 7) -> local (14, -10) when drawn with draw_sprite().
static func jezzail(frame: int) -> Image:
	var img := PA.new_img(34, 18)
	var ox := 1
	var oy := 1
	var fur := PA.col("m")
	var dark := PA.col("M")
	var pink := PA.col("q")
	var step := 0 if frame == 0 else 1
	# --- gunner tail
	PA.px(img, ox + 0, oy + 6, pink)
	PA.px(img, ox + 1, oy + 7, pink)
	PA.px(img, ox + 2, oy + 8, pink)
	PA.px(img, ox + 3, oy + 9, pink)
	# --- bipod rat (crouched, front)
	PA.ellipse(img, ox + 20, oy + 11, 4.0, 2.6, fur)
	PA.rect(img, ox + 17, oy + 13, 7, 1, dark)
	PA.disk(img, ox + 24, oy + 10.5, 2.2, fur)
	PA.px(img, ox + 26, oy + 11, fur)
	PA.px(img, ox + 27, oy + 11, PA.col("p"))
	PA.disk(img, ox + 22.5, oy + 8.4, 1.1, pink)
	PA.px(img, ox + 25, oy + 10, PA.col("z"))
	# bipod rat's legs braced
	PA.px(img, ox + 17 + step, oy + 15, dark)
	PA.px(img, ox + 18 + step, oy + 15, dark)
	PA.px(img, ox + 22 - step, oy + 15, dark)
	PA.px(img, ox + 23 - step, oy + 15, dark)
	# --- gunner rat (upright, behind)
	PA.ellipse(img, ox + 7, oy + 10, 3.8, 3.4, fur)
	PA.rect(img, ox + 4, oy + 12, 7, 1, dark)
	PA.disk(img, ox + 10, oy + 6.2, 2.5, fur)
	PA.px(img, ox + 12, oy + 6, fur)
	PA.px(img, ox + 13, oy + 6, PA.col("p"))
	PA.disk(img, ox + 8.6, oy + 3.4, 1.3, pink)
	PA.px(img, ox + 8, oy + 3, dark)
	# brass scope-monocle over the glowing eye
	PA.px(img, ox + 11, oy + 5, PA.col("z"))
	PA.px(img, ox + 11, oy + 4, PA.col("Y"))
	PA.px(img, ox + 12, oy + 5, PA.col("Y"))
	PA.px(img, ox + 10, oy + 5, PA.col("Y"))
	# gunner legs
	PA.px(img, ox + 5 - step, oy + 14, dark)
	PA.px(img, ox + 6 - step, oy + 14, dark)
	PA.px(img, ox + 8 + step, oy + 14, dark)
	PA.px(img, ox + 9 + step, oy + 14, dark)
	# --- rusty pipe rifle
	PA.rect(img, ox + 3, oy + 7, 5, 3, PA.col("b"))          # stock
	PA.rect(img, ox + 3, oy + 7, 5, 1, PA.col("t"))
	PA.rect(img, ox + 8, oy + 6, 21, 2, PA.col("O"))         # barrel
	PA.rect(img, ox + 8, oy + 7, 21, 1, PA.col("B"))
	for rx in [11, 16, 21, 25]:
		PA.px(img, ox + rx, oy + 6, PA.col("i"))             # rust flecks
	PA.rect(img, ox + 28, oy + 5, 2, 4, PA.col("G"))         # flared muzzle
	PA.rect(img, ox + 18, oy + 6, 1, 2, PA.col("g"))         # pipe clamp
	# warp-cheese power cell on top
	PA.rect(img, ox + 13, oy + 3, 4, 3, PA.col("Z"))
	PA.px(img, ox + 14, oy + 3, PA.col("z"))
	PA.px(img, ox + 15, oy + 4, PA.col("z"))
	PA.px(img, ox + 13, oy + 5, PA.col("x"))
	# gunner paw on the trigger, bipod paw on the barrel
	PA.px(img, ox + 9, oy + 9, pink)
	PA.px(img, ox + 23, oy + 8, pink)
	return PA.outline(img)


## Hooded plague monk. Hand (flail anchor) at image (13, 10) -> local (4, -9).
static func monk(frame: int) -> Image:
	var img := PA.new_img(18, 20)
	var ox := 1
	var oy := 1
	var robe := PA.col("b")
	var robe_dk := PA.col("B")
	var step := 0 if frame == 0 else 1
	# tail poking from under the robe
	PA.px(img, ox + 0, oy + 15, PA.col("q"))
	PA.px(img, ox + 1, oy + 16, PA.col("q"))
	PA.px(img, ox + 2, oy + 16, PA.col("q"))
	# robe body (widening towards the hem)
	for y in range(6, 17):
		var t := float(y - 6) / 10.0
		var hw := lerpf(3.0, 5.5, t)
		for x in range(int(8.0 - hw), int(8.0 + hw) + 1):
			var c := robe
			if x >= int(8.0 + hw) - 1:
				c = robe_dk
			PA.px(img, ox + x, oy + y, c)
	# ragged hem
	for x in range(3, 14):
		if (x + step) % 2 == 0:
			PA.px(img, ox + x, oy + 17, robe_dk)
	# sickly stains + rope belt
	PA.px(img, ox + 6, oy + 13, PA.col("x"))
	PA.px(img, ox + 7, oy + 14, PA.col("Z"))
	PA.px(img, ox + 10, oy + 15, PA.col("x"))
	PA.rect(img, ox + 4, oy + 11, 9, 1, PA.col("c"))
	PA.px(img, ox + 5, oy + 12, PA.col("c"))
	# hood
	PA.disk(img, ox + 8, oy + 5, 3.8, robe)
	PA.px(img, ox + 6, oy + 1, robe)
	PA.px(img, ox + 5, oy + 0, robe_dk)
	PA.disk(img, ox + 10.2, oy + 5.6, 1.9, PA.col("k"))      # shadowed opening
	PA.px(img, ox + 10, oy + 5, PA.col("z"))                 # glowing eye in the dark
	PA.px(img, ox + 12, oy + 6, PA.col("m"))                 # snout pokes out
	PA.px(img, ox + 13, oy + 6, PA.col("p"))
	PA.px(img, ox + 12, oy + 7, PA.col("W"))                 # whisker
	# sleeve + paw holding the chain
	PA.rect(img, ox + 10, oy + 8, 3, 2, robe_dk)
	PA.px(img, ox + 12, oy + 9, PA.col("q"))
	# feet
	PA.px(img, ox + 5 + step, oy + 18, PA.col("M"))
	PA.px(img, ox + 10 - step, oy + 18, PA.col("M"))
	return PA.outline(img)


## Spiked robot vacuum with green lightning coils and a goggled rat rider.
## Coil tops at image (6,4)/(20,4) -> local (-7,-15)/(7,-15).
static func roomba() -> Image:
	var img := PA.new_img(26, 20)
	var cx := 13.0
	# side thickness, top shell, top plate
	PA.ellipse(img, cx, 13.5, 10.5, 5.0, PA.col("K"))
	PA.ellipse(img, cx, 12.0, 10.5, 5.0, PA.col("G"))
	PA.ellipse(img, cx, 11.5, 8.5, 3.6, PA.col("g"))
	PA.ellipse(img, cx, 11.0, 4.0, 1.8, PA.col("G"))
	# evil status light
	PA.px(img, int(cx), 11, PA.col("z"))
	PA.px(img, int(cx) + 1, 11, PA.col("Z"))
	# front bumper
	for x in range(5, 22):
		PA.px(img, x, 16, PA.col("k"))
	PA.px(img, 21, 13, PA.col("W"))
	PA.px(img, 22, 12, PA.col("W"))
	# spikes around the rim
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector2(cx + cos(a) * 11.5, 12.5 + sin(a) * 5.8)
		PA.px(img, int(roundf(p.x)), int(roundf(p.y)), PA.col("W"))
		var p2 := Vector2(cx + cos(a) * 12.6, 12.5 + sin(a) * 6.6)
		PA.px(img, int(roundf(p2.x)), int(roundf(p2.y)), PA.col("g"))
	# warp coils (copper windings, glowing tips)
	for coil_x in [6, 20]:
		PA.rect(img, coil_x - 1, 6, 3, 5, PA.col("O"))
		PA.px(img, coil_x - 1, 7, PA.col("Y"))
		PA.px(img, coil_x + 1, 9, PA.col("Y"))
		PA.px(img, coil_x, 5, PA.col("z"))
		PA.px(img, coil_x, 4, PA.col("Z"))
	# tiny rat rider in goggles
	PA.disk(img, 13, 7.5, 2.0, PA.col("m"))
	PA.disk(img, 14.5, 5.5, 1.6, PA.col("m"))
	PA.px(img, 13, 3, PA.col("q"))
	PA.px(img, 15, 5, PA.col("u"))
	PA.px(img, 16, 5, PA.col("u"))
	PA.px(img, 16, 6, PA.col("p"))
	PA.line(img, 11, 8, 9, 10, PA.col("q"))      # tail draped over
	PA.px(img, 15, 8, PA.col("B"))               # joystick
	PA.px(img, 15, 7, PA.col("r"))
	return PA.outline(img)


## Rat-Ogre Bruiser. pose 0/1 = walk, 2 = arms overhead (slam/throw).
## Hunched, knuckle-dragging mutant: scrap-iron pauldron + hubcap belly plate, chest stitches,
## gingham oven mitts, jutting underbite snout.
static func ogre(pose: int) -> Image:
	var img := PA.new_img(38, 36)
	var fur := PA.col("m")
	var dark := PA.col("M")
	var belly := PA.col("m").lightened(0.22)
	var step := 1 if pose == 1 else 0
	var swing := 0
	if pose == 0:
		swing = -1
	elif pose == 1:
		swing = 1
	# thick tail
	PA.line(img, 6, 25, 2, 28, PA.col("q"))
	PA.line(img, 6, 26, 2, 29, PA.col("q"))
	PA.line(img, 2, 29, 1, 32, PA.col("q"))
	# stumpy legs
	PA.rect(img, 10, 25 - step, 6, 7 + step, dark)
	PA.rect(img, 19, 25 - (1 - step), 6, 7 + (1 - step), dark)
	PA.rect(img, 9, 31, 8, 2, PA.col("k"))
	PA.rect(img, 18, 31, 8, 2, PA.col("k"))
	# back arm (behind the body) for walk poses
	if pose != 2:
		PA.line(img, 9, 13, 6, 24 + swing, dark)
		PA.line(img, 10, 13, 7, 24 + swing, dark)
		PA.line(img, 11, 14, 8, 24 + swing, dark)
	# hunched torso + hump
	PA.ellipse(img, 16, 19, 10.0, 8.5, fur)
	PA.disk(img, 11, 12, 6.0, fur)
	PA.ellipse(img, 19, 21, 5.5, 4.6, belly)
	PA.rect(img, 9, 26, 15, 1, dark)
	# scrap-iron pauldron on the hump
	PA.rect(img, 5, 8, 10, 4, PA.col("g"))
	PA.rect(img, 5, 8, 10, 1, PA.col("W"))
	PA.rect(img, 5, 11, 10, 1, PA.col("G"))
	PA.px(img, 6, 9, PA.col("k"))
	PA.px(img, 13, 9, PA.col("k"))
	PA.px(img, 9, 10, PA.col("i"))
	# hubcap belly plate
	PA.disk(img, 18, 21, 3.2, PA.col("G"))
	PA.ring(img, 18, 21, 3.2, 1.0, PA.col("g"))
	PA.px(img, 18, 21, PA.col("W"))
	PA.px(img, 16, 20, PA.col("W"))
	# chest stitches (seam from neck to belly with cross ticks)
	PA.line(img, 21, 12, 22, 17, PA.col("k"))
	for sy in [13, 15, 17]:
		PA.px(img, 20, sy, PA.col("W"))
		PA.px(img, 23, sy - 1, PA.col("W"))
	# hump stitches
	PA.line(img, 8, 14, 13, 16, PA.col("k"))
	PA.px(img, 9, 13, PA.col("W"))
	PA.px(img, 11, 16, PA.col("W"))
	# head jutting forward, underbite snout
	PA.disk(img, 26, 11, 4.8, fur)
	PA.ellipse(img, 30.5, 13, 3.4, 2.3, fur)
	PA.px(img, 34, 12, PA.col("p"))
	PA.px(img, 33, 12, PA.col("P"))
	PA.rect(img, 27, 14, 6, 1, PA.col("k"))
	PA.px(img, 29, 13, PA.col("w"))   # upward tusks
	PA.px(img, 32, 13, PA.col("w"))
	PA.rect(img, 23, 8, 6, 1, dark)   # heavy brow
	PA.px(img, 25, 9, PA.col("z"))
	PA.px(img, 27, 9, PA.col("z"))
	PA.px(img, 26, 9, PA.col("x"))
	PA.disk(img, 22, 6, 2.0, PA.col("q"))   # torn ear
	PA.px(img, 22, 5, PA.col("k"))
	PA.px(img, 23, 4, PA.col("k"))
	# front arm + mitts
	if pose == 2:
		PA.line(img, 12, 10, 9, 4, fur)
		PA.line(img, 13, 10, 10, 4, fur)
		PA.line(img, 26, 8, 29, 3, fur)
		PA.line(img, 27, 8, 30, 3, fur)
		_mitt(img, 9, 3)
		_mitt(img, 30, 2)
	else:
		PA.line(img, 24, 15, 28, 24 - swing, fur)
		PA.line(img, 25, 15, 29, 24 - swing, fur)
		PA.line(img, 23, 16, 27, 24 - swing, fur)
		_mitt(img, 7, 26 + swing)
		_mitt(img, 29, 26 - swing)
	return PA.outline(img)


## Gingham oven mitt (quilted cuff above), centred on (cx, cy).
static func _mitt(img: Image, cx: int, cy: int) -> void:
	PA.disk(img, cx, cy, 3.6, PA.col("r"))
	for yy in range(cy - 3, cy + 4):
		for xx in range(cx - 3, cx + 4):
			if xx < 0 or yy < 0 or xx >= img.get_width() or yy >= img.get_height():
				continue
			if (xx + yy) % 2 == 0 and img.get_pixel(xx, yy) == PA.col("r") and (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) < 8:
				img.set_pixel(xx, yy, PA.col("w"))
	PA.px(img, cx + 3, cy - 1, PA.col("r"))   # thumb
	PA.px(img, cx + 4, cy - 1, PA.col("R"))
	PA.rect(img, cx - 3, cy - 5, 7, 2, PA.col("W"))
	PA.px(img, cx - 2, cy - 5, PA.col("g"))
	PA.px(img, cx + 1, cy - 5, PA.col("g"))
