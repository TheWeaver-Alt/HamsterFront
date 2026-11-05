extends RefCounted
## Title-screen portraits of the four mechs, composed from the real sprite parts (ADR-0003).
## Names: mech_icon_<chassis id>, each 46x34. The mech stands on the bottom row but one, a pixel or two from the edge.

const PA := preload("res://autoloads/PixelArt.gd")
const MechArt := preload("res://scripts/art/MechArt.gd")
const TankArt := preload("res://scripts/art/TankArt.gd")
const DroneArt := preload("res://scripts/art/DroneArt.gd")

const W := 46
const H := 34
const FY := 30     # the row the mech's feet stand on


static func make(n: String) -> Image:
	if not n.begins_with("mech_icon_"):
		return null
	var img := PA.new_img(W, H)
	match n.substr(10):
		"brawler":
			_brawler(img, 23)
		"wheeler":
			_wheeler(img, 23)
		"tank":
			_tank(img, 19)
		"drone":
			_drone(img, 23)
		_:
			return null
	return img


static func _part(n: String) -> Image:
	for p in [MechArt, TankArt, DroneArt]:
		var i: Image = p.make(n)
		if i != null:
			return i
	return null


## Draws the named part with its top-left at (x, y).
static func _put(img: Image, n: String, x: int, y: int) -> void:
	var src := _part(n)
	img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))


static func _brawler(img: Image, fx: int) -> void:
	_put(img, "brawler_body_0", fx - 13, FY - 22)
	_put(img, "ham_head_2", fx - 13, FY - 30)
	_put(img, "brawler_dome", fx - 9, FY - 30)
	_put(img, "brawler_gun", fx - 2, FY - 17)


static func _wheeler(img: Image, fx: int) -> void:
	# six spider legs at rest
	for side in [-1, 1]:
		for rest in [[8, -3], [12, 0], [8, 3]]:
			var hip := Vector2i(fx + side * 4, FY - 8)
			var foot := Vector2i(fx + side * int(rest[0]), FY + int(rest[1]))
			var knee := Vector2i(int((hip.x + foot.x) / 2.0) + side, hip.y - 3)
			PA.line(img, hip.x, hip.y, knee.x, knee.y, PA.col("k"))
			PA.line(img, knee.x, knee.y, foot.x, foot.y, PA.col("k"))
			PA.line(img, hip.x, hip.y + 0, knee.x, knee.y, PA.col("W"))
			PA.line(img, knee.x, knee.y, foot.x, foot.y, PA.col("g"))
	_put(img, "wheeler_hub", fx - 8, FY - 6)
	_put(img, "wheeler_wheel_0", fx - 10, FY - 24)
	_put(img, "wheeler_ham_idle", fx - 7, FY - 17)
	_put(img, "ham_head_2", fx - 13, FY - 29)
	_put(img, "wheeler_ball", fx - 12, FY - 26)
	_put(img, "wheeler_rails", fx - 4, FY - 16)


static func _tank(img: Image, fx: int) -> void:
	_put(img, "tank_treads_1", fx - 19, FY - 9)
	_put(img, "ham_head_2", fx - 4 - 13, FY - 19 - 10)
	_put(img, "tank_hull", fx - 17, FY - 19)
	_put(img, "tank_hatch", fx - 10, FY - 18)
	_put(img, "tank_barrel", fx + 9 - 2, FY - 21 - 2)
	_put(img, "tank_turret", fx + 2, FY - 25)


static func _drone(img: Image, fx: int) -> void:
	var lift := 0
	_put(img, "drone_skids", fx - 10, FY - 4 - lift)
	_put(img, "ham_head_2", fx - 13, FY - 20 - lift)
	_put(img, "drone_pod", fx - 11, FY - 18 - lift)
	_put(img, "drone_frame", fx - 17, FY - 22 - lift)
	# the rotors sit a little inside the frame's ends so the portrait fits
	_put(img, "drone_rotor_1", fx - 21, FY - 28 - lift)
	_put(img, "drone_rotor_2", fx + 7, FY - 28 - lift)
