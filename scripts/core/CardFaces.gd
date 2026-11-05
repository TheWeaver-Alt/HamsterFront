class_name CardFaces
extends RefCounted
## What a card looks like to a child. CardDB owns the rules; this owns the picture-first face:
## a drawing of what the card does, one to three arrows for how strong it is, and a name of one or two words.
## No percentages and no sentences: the long text in CardDB stays as the line for grown-ups.
##
## Fields per card id:
##   short      the name on the card, at most MAX_SHORT characters (the pixel font has no lower case)
##   icon       the picture: PixelArt.tex("card_" + icon), painted by scripts/art/CardArt.gd
##   power      1..3 arrows: how strong the good part is
##   bad_icon   cursed cards only: the picture for the downside
##   bad_power  cursed cards only: 1..3 arrows pointing down: how bad the downside is

const MAX_SHORT := 13

const FACES := {
	# ---- mech mods
	"toothpick_pierce": {"short": "PIERCE", "icon": "pierce", "power": 2},
	"wd40": {"short": "COOL WHEEL", "icon": "wheel_cool", "power": 3},
	"titanium_cheeks": {"short": "BIG CHEEKS", "icon": "cheeks", "power": 2},
	"espresso": {"short": "FAST FIRE", "icon": "bullets", "power": 2},
	"duct_tape": {"short": "TOUGH", "icon": "heart_tape", "power": 2},
	"big_fist": {"short": "BIG FIST", "icon": "fist", "power": 2},
	"fridge_magnet": {"short": "MAGNET", "icon": "magnet", "power": 2},
	"turbo_treads": {"short": "FAST FEET", "icon": "boot", "power": 1},
	"extra_barrel": {"short": "MORE SHOTS", "icon": "barrels", "power": 2},
	"cheek_hydraulics": {"short": "LIGHT CHEEKS", "icon": "weight_down", "power": 2},
	"overclocked_wheel": {"short": "SPRINT", "icon": "wheel_fire", "power": 2},
	"spit_polish": {"short": "BIG SPIT", "icon": "spit", "power": 2},
	"vampire_sunflower": {"short": "VAMPIRE", "icon": "sun_vamp", "power": 1},
	"radiator_fins": {"short": "COOL DOWN", "icon": "radiator", "power": 2},
	"jetpack": {"short": "JETPACK", "icon": "bottle", "power": 3},
	"bubble_wrap": {"short": "BUBBLE", "icon": "bubble", "power": 2},
	# ---- tower blueprints
	"flaming_hulls": {"short": "FIRE SHOTS", "icon": "gatling_fire", "power": 2},
	"prismatic": {"short": "RAINBOW", "icon": "prism", "power": 2},
	"sneezy": {"short": "SNEEZE", "icon": "sneeze", "power": 2},
	"static_cling": {"short": "CHAIN ZAP", "icon": "chain", "power": 2},
	"googly": {"short": "GOOGLY", "icon": "googly", "power": 2},
	"bulk_discount": {"short": "CHEAPER", "icon": "coupon", "power": 2},
	"sugar_insurance": {"short": "LONG RUSH", "icon": "sugar", "power": 2},
	"hull_avalanche": {"short": "STICKY SHELLS", "icon": "shells", "power": 2},
	"reinforced": {"short": "TOUGH TOWERS", "icon": "tower_shield", "power": 2},
	"magnifier": {"short": "BIG RANGE", "icon": "magnify", "power": 2},
	"salted_seeds": {"short": "SALTY SEEDS", "icon": "salt", "power": 2},
	# ---- co-op synergies
	"jumper_cables": {"short": "ZAP CABLE", "icon": "cables", "power": 3},
	"blood_brothers": {"short": "TEAM BOOST", "icon": "brothers", "power": 2},
	"buddy_system": {"short": "STAY CLOSE", "icon": "buddies", "power": 2},
	"communal_cheeks": {"short": "SHARE SEEDS", "icon": "shared", "power": 2},
	# ---- warp-cheese corruptions: a good picture and a bad picture
	"forbidden_brie": {"short": "POWER!", "icon": "burst", "power": 3, "bad_icon": "cat", "bad_power": 1},
	"warp_gouda": {"short": "ZOOM!", "icon": "boot", "power": 2, "bad_icon": "invert", "bad_power": 2},
	"gorgonzola": {"short": "TOWER RUSH", "icon": "tower_fast", "power": 3, "bad_icon": "tower_hurt", "bad_power": 2},
	"moldy_muenster": {"short": "TOUGH + MEAN", "icon": "heart_tape", "power": 2, "bad_icon": "leak", "bad_power": 1},
	"wheel_of_unreason": {"short": "RAPID FIRE", "icon": "bullets", "power": 2, "bad_icon": "wheel_fire", "bad_power": 2},
	"squeaky_breath": {"short": "MORE SEEDS", "icon": "seeds_more", "power": 2, "bad_icon": "rat_chase", "bad_power": 2},
}


## The face for a card dictionary (or an id). Always has a "short", so callers never need a fallback.
static func of(card) -> Dictionary:
	var id: String = card if card is String else String(card.get("id", ""))
	if FACES.has(id):
		return FACES[id]
	var name_text: String = "" if card is String else String(card.get("name", id))
	return {"short": name_text.substr(0, MAX_SHORT), "icon": "burst", "power": 1}


## Problems with the faces, for the smoke test. Empty means every card has a sound face.
static func validate(cards: Array) -> Array:
	var problems: Array = []
	var seen := {}
	for card in cards:
		var id: String = card["id"]
		seen[id] = true
		if not FACES.has(id):
			problems.append("%s has no face" % id)
			continue
		var f: Dictionary = FACES[id]
		var short := String(f.get("short", ""))
		if short.is_empty() or short.length() > MAX_SHORT:
			problems.append("%s: short name '%s' must be 1..%d characters" % [id, short, MAX_SHORT])
		if short != short.to_upper():
			problems.append("%s: short name must be upper case" % id)
		var power := int(f.get("power", 0))
		if power < 1 or power > 3:
			problems.append("%s: power %d must be 1..3" % [id, power])
		if _art(String(f.get("icon", ""))) == null:
			problems.append("%s: no picture named card_%s" % [id, f.get("icon", "")])
		var cursed: bool = card["tier"] == "cursed"
		if cursed:
			var bp := int(f.get("bad_power", 0))
			if bp < 1 or bp > 3:
				problems.append("%s: bad_power %d must be 1..3" % [id, bp])
			if _art(String(f.get("bad_icon", ""))) == null:
				problems.append("%s: no picture named card_%s for the downside" % [id, f.get("bad_icon", "")])
		elif f.has("bad_icon"):
			problems.append("%s: only cursed cards have a bad_icon" % id)
	for id in FACES:
		if not seen.has(id):
			problems.append("face '%s' belongs to no card" % id)
	return problems


static func _art(icon: String) -> Image:
	if icon.is_empty():
		return null
	return (load("res://scripts/art/CardArt.gd") as GDScript).call("make", "card_" + icon)
