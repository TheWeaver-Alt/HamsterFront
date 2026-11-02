class_name Defs
extends RefCounted
## Shared enums, grid constants, physics layers and tuning tables.

enum Tower { GATLING, LASER, MORTAR, TESLA, DECOY }
enum Rat { SQUEAKER, JEZZAIL, MONK, ROOMBA, OGRE }

const CELL := 16
const GRID_W := 40
const GRID_H := 23
const SCREEN := Vector2(640, 360)

# Physics layer bit values.
const L_WORLD := 1
const L_MECH := 2
const L_RAT := 4
const L_TOWER := 8
const L_SILO := 16

const FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")

const TOWER_ORDER := [Tower.GATLING, Tower.LASER, Tower.MORTAR, Tower.TESLA, Tower.DECOY]

const TOWER_DATA := {
	Tower.GATLING: {
		"name": "Sunflower Gatling", "short": "GATLING", "cost": 25, "hp": 90.0,
		"range": 110.0, "rate": 7.0, "damage": 4.0,
	},
	Tower.LASER: {
		"name": "Water-Bottle Laser", "short": "LASER", "cost": 40, "hp": 80.0,
		"range": 130.0, "dps": 20.0,
	},
	Tower.MORTAR: {
		"name": "Cedar-Shaving Mortar", "short": "MORTAR", "cost": 45, "hp": 90.0,
		"range": 175.0, "min_range": 30.0, "rate": 0.45, "damage": 22.0, "aoe": 30.0, "stun": 1.2,
	},
	Tower.TESLA: {
		"name": "Exercise-Wheel Tesla", "short": "TESLA", "cost": 50, "hp": 100.0,
		"range": 90.0, "rate": 0.8, "damage": 18.0, "chains": 4, "chain_range": 50.0,
	},
	Tower.DECOY: {
		"name": "Cardboard Decoy", "short": "DECOY", "cost": 15, "hp": 150.0,
		"range": 85.0,
	},
}

const RAT_DATA := {
	Rat.SQUEAKER: {
		"name": "Clan-Squeaker", "hp": 18.0, "speed": 42.0, "dmg": 4.0, "rate": 0.8,
		"range": 6.0, "radius": 4.0, "seeds": 1, "bubble": 12.0,
	},
	Rat.JEZZAIL: {
		"name": "Warp-Gouda Jezzail", "hp": 32.0, "speed": 30.0, "dmg": 20.0, "rate": 3.6,
		"range": 150.0, "radius": 6.0, "seeds": 3, "bubble": 14.0,
	},
	Rat.MONK: {
		"name": "Plague-Stink Monk", "hp": 70.0, "speed": 26.0, "dmg": 7.0, "rate": 1.0,
		"range": 8.0, "radius": 5.0, "seeds": 4, "bubble": 16.0,
	},
	Rat.ROOMBA: {
		"name": "Doom-Roomba", "hp": 170.0, "speed": 72.0, "dmg": 16.0, "rate": 0.5,
		"range": 10.0, "radius": 9.0, "seeds": 6, "bubble": 14.0,
	},
	Rat.OGRE: {
		"name": "Rat-Ogre Bruiser", "hp": 650.0, "speed": 20.0, "dmg": 28.0, "rate": 1.6,
		"range": 10.0, "radius": 10.0, "seeds": 20, "bubble": 28.0,
	},
}


static func flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLASH_SHADER
	return m


static func tower_name(kind: int) -> String:
	return String(TOWER_DATA[kind]["name"])


static func tower_short(kind: int) -> String:
	return String(TOWER_DATA[kind]["short"])
