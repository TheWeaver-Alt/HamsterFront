class_name Chassis
extends RefCounted
## The mech roster (ADR-0003). Whatever needs "the mechs" asks here. Each entry has two scripts in
## scripts/mech/chassis/: <script>Visual.gd (extends MechVisual: what it looks like) and <script>Weapon.gd
## (extends WeaponMount: what it fires). MechPlayer.setup() swaps them onto its Visual and WeaponMount nodes.
##
## Entry fields:
##   name, blurb   title-screen text (upper case: the pixel font has no lower case)
##   script        file prefix of the two chassis scripts
##   unlock        "start" or "workshop" (see is_unlocked)
##   weapon_pos    weapon hardpoint, relative to the mech's feet
##   weapon_front  how far the hardpoint sits ahead of the body along the facing
##   shadow        radius of the ground shadow
##   flies         true: it hovers, and cliffs and towers do not block it
##   stats         base stats (see MechPlayer and the header of autoloads/CardDB.gd)
##
## How each mech carries seed weight (ADR-0003): `pouch_slow` is the speed lost when the cheeks are full,
## `heat_weight` makes the exercise wheel heat up faster when full, and a flyer sags lower (DroneVisual).

## Selection order on the title screen.
const IDS := ["brawler", "wheeler", "tank", "drone"]

const DEFS := {
	"brawler": {
		"name": "BRAWLER-01", "blurb": "ESPRESSO + DUCT TAPE", "script": "Brawler", "unlock": "start",
		"weapon_pos": Vector2(0, -9), "weapon_front": 5.0, "shadow": 10.0, "flies": false,
		"stats": {
			"max_hp": 140.0, "move_speed": 74.0, "sprint_mult": 1.6, "damage_mult": 1.0, "fire_rate_mult": 1.0,
			"pierce": 0.0, "extra_projectiles": 0.0, "pouch_capacity": 50.0, "pouch_slow": 0.4,
			"pickup_radius": 30.0, "heat_rate": 34.0, "heat_decay": 16.0, "heat_weight": 0.0, "alt_damage_mult": 1.0,
			"alt_size_mult": 1.0, "spit_damage_mult": 1.0, "revive_speed": 1.0, "lifesteal": 0.0,
			"seed_leak": 0.0, "damage_taken": 1.0, "vent_heal": 0.0, "spinout_bonus": 0.0,
		},
	},
	"wheeler": {
		"name": "WHEELER-X", "blurb": "BALL ON SPIDER LEGS", "script": "Wheeler", "unlock": "start",
		"weapon_pos": Vector2(0, -28), "weapon_front": 0.0, "shadow": 12.0, "flies": false,
		"stats": {
			"max_hp": 100.0, "move_speed": 98.0, "sprint_mult": 1.55, "damage_mult": 1.0, "fire_rate_mult": 1.0,
			"pierce": 0.0, "extra_projectiles": 0.0, "pouch_capacity": 40.0, "pouch_slow": 0.25,
			"pickup_radius": 36.0, "heat_rate": 30.0, "heat_decay": 15.0, "heat_weight": 0.8, "alt_damage_mult": 1.0,
			"alt_size_mult": 1.0, "spit_damage_mult": 1.0, "revive_speed": 1.0, "lifesteal": 0.0,
			"seed_leak": 0.0, "damage_taken": 1.0, "vent_heal": 0.0, "spinout_bonus": 0.0,
		},
	},
	"tank": {
		"name": "HOWITZER-9", "blurb": "BISCUIT-TIN ARTILLERY", "script": "Tank", "unlock": "workshop",
		"weapon_pos": Vector2(0, -21), "weapon_front": 9.0, "shadow": 16.0, "flies": false,
		"stats": {
			"max_hp": 200.0, "move_speed": 56.0, "sprint_mult": 1.35, "damage_mult": 1.0, "fire_rate_mult": 1.0,
			"pierce": 0.0, "extra_projectiles": 0.0, "pouch_capacity": 90.0, "pouch_slow": 0.12,
			"pickup_radius": 34.0, "heat_rate": 26.0, "heat_decay": 15.0, "heat_weight": 0.0, "alt_damage_mult": 1.0,
			"alt_size_mult": 1.0, "spit_damage_mult": 1.0, "revive_speed": 1.0, "lifesteal": 0.0,
			"seed_leak": 0.0, "damage_taken": 1.0, "vent_heal": 0.0, "spinout_bonus": 0.0,
		},
	},
	"drone": {
		"name": "WHIRLYBIRD-Z", "blurb": "FLIES OVER CLIFFS", "script": "Drone", "unlock": "workshop",
		"weapon_pos": Vector2(0, -2), "weapon_front": 0.0, "shadow": 9.0, "flies": true,
		"stats": {
			"max_hp": 90.0, "move_speed": 112.0, "sprint_mult": 1.5, "damage_mult": 1.0, "fire_rate_mult": 1.0,
			"pierce": 0.0, "extra_projectiles": 0.0, "pouch_capacity": 30.0, "pouch_slow": 0.55,
			"pickup_radius": 44.0, "heat_rate": 30.0, "heat_decay": 16.0, "heat_weight": 0.0, "alt_damage_mult": 1.0,
			"alt_size_mult": 1.0, "spit_damage_mult": 1.0, "revive_speed": 1.0, "lifesteal": 0.0,
			"seed_leak": 0.0, "damage_taken": 1.0, "vent_heal": 0.0, "spinout_bonus": 0.0,
		},
	},
}


## The entry for an id; an unknown id gets the first mech's.
static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS[IDS[0]])


static func display_name(id: String) -> String:
	return String(def(id)["name"])


static func base_stats(id: String) -> Dictionary:
	return (def(id)["stats"] as Dictionary).duplicate()


static func flies(id: String) -> bool:
	return bool(def(id)["flies"])


## Every mech is unlocked until the Workshop exists. It will own the real list (ADR-0003): the tank and the drone
## are marked "workshop" and will be locked behind it.
static func is_unlocked(_id: String) -> bool:
	return true


## The ids a pilot can pick from, in selection order.
static func available() -> Array:
	return IDS.filter(func(id): return is_unlocked(id))


static func script_path(id: String, part: String) -> String:
	return "res://scripts/mech/chassis/%s%s.gd" % [def(id)["script"], part]


## Puts this chassis's Visual and Weapon scripts on a MechPlayer. Call it before the mech enters the tree,
## so the nodes' _ready runs with the right script.
static func apply(mech: Node, id: String) -> void:
	mech.get_node("Visual").set_script(load(script_path(id, "Visual")))
	mech.get_node("WeaponMount").set_script(load(script_path(id, "Weapon")))
