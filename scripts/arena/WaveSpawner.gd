extends Node
## Builds each wave's roster from a scaling budget and drips it out of the burrows.
## Each group telegraphs its burrow (green glow + dirt) before rats crawl out.

signal wave_started(n: int)

const SPAWN_BARKS := [
	"Yes-yes! Steal-take the fat-cheek seeds!",
	"Quick-quick! Bucket-bucket is unguarded-ish!",
	"For the Horned One! Swarm-swarm!",
]
const OGRE_BARKS := ["RAAAGH! SMASH-CRUSH FLUFF-THINGS!", "OGRE HUNGRY! OGRE THROW!"]

var arena = null
var active := false
var wave := 0
var t := 0.0
var groups: Array = []       # {time, burrow, units:Array, state, tele, next, hp, spd}
var total_units := 0
var spawned_units := 0


func start_wave(n: int) -> void:
	wave = n
	t = 0.0
	active = true
	groups = build_roster(n)
	total_units = 0
	spawned_units = 0
	for g in groups:
		total_units += g["units"].size()
	wave_started.emit(n)


func is_done() -> bool:
	return active and groups.is_empty()


func remaining_to_spawn() -> int:
	return total_units - spawned_units


func open_burrows(n: int) -> int:
	return clampi(2 + int((n - 1) / 2), 2, ArenaMap.BURROWS.size())


func build_roster(n: int) -> Array:
	var hp_mult := 1.0 + 0.16 * (n - 1) + 0.012 * (n - 1) * (n - 1)
	var spd_mult := 1.0 + 0.015 * (n - 1)
	var burrow_count := open_burrows(n)
	var out: Array = []
	var time := 1.0
	var packs := 1 + int(n * 0.7)
	var pack_size := mini(20, 8 + n * 2)
	var gap := maxf(3.5, 9.0 - n * 0.35)
	var specials: Array = []
	if n >= 2:
		for i in int(n / 2):
			specials.append("jezzail")
	if n >= 3:
		for i in int((n - 1) / 2):
			specials.append("monk")
	if n >= 4 and n % 2 == 0:
		for i in 1 + int((n - 4) / 4):
			specials.append("roomba")
	specials.shuffle()
	for p in packs:
		var units: Array = []
		for i in pack_size:
			units.append("squeaker")
		# sprinkle specials into the packs
		var per := int(ceil(float(specials.size()) / float(packs - p))) if specials.size() > 0 else 0
		for i in per:
			if specials.is_empty():
				break
			units.insert(randi_range(0, units.size()), specials.pop_back())
		out.append(_group(time, randi() % burrow_count, units, hp_mult, spd_mult))
		time += gap
	if n % 5 == 0:
		var ogres: Array = []
		for i in int(n / 5):
			ogres.append("ogre")
		out.append(_group(time * 0.6, randi() % burrow_count, ogres, hp_mult * 0.85, 1.0))
	return out


func _group(time: float, burrow_i: int, units: Array, hp_mult: float, spd_mult: float) -> Dictionary:
	return {"time": time, "burrow": ArenaMap.BURROWS[burrow_i], "units": units, "state": "wait",
		"tele": 1.4, "next": 0.0, "hp": hp_mult, "spd": spd_mult, "first": true}


func _physics_process(delta: float) -> void:
	if not active or arena == null:
		return
	t += delta
	var k := groups.size() - 1
	while k >= 0:
		var g: Dictionary = groups[k]
		match g["state"]:
			"wait":
				if t >= g["time"]:
					g["state"] = "tele"
					arena.burrow_warn(g["burrow"], g["tele"])
					Sfx.play("squeak_rat", 0.7, -8.0)
			"tele":
				g["tele"] -= delta
				if g["tele"] <= 0.0:
					g["state"] = "spawn"
			"spawn":
				g["next"] -= delta
				if g["next"] <= 0.0:
					var kind: String = g["units"].pop_front()
					g["next"] = 0.09 if kind == "squeaker" else 0.4
					_spawn(kind, g)
					if g["units"].is_empty():
						groups.remove_at(k)
		k -= 1


func _spawn(kind: String, g: Dictionary) -> void:
	var cell: Vector2i = g["burrow"]
	var pos := ArenaMap.cell_center(cell) + Vector2(randf_range(-3, 3), randf_range(-2, 2))
	var rat = arena.spawn_rat(kind, pos, g["hp"], g["spd"])
	spawned_units += 1
	arena.fx.dust(pos, 3)
	if g["first"]:
		g["first"] = false
		if randf() < 0.55:
			JuiceManager.bark(rat, SPAWN_BARKS[0] if randf() < 0.6 else SPAWN_BARKS[randi() % SPAWN_BARKS.size()], "rat", false, 1.0)
	if kind == "ogre":
		JuiceManager.add_trauma(0.6)
		Sfx.play("ogre_roar")
		JuiceManager.bark(rat, OGRE_BARKS[randi() % OGRE_BARKS.size()], "boss", true)
		GameManager.say("RAT-OGRE BRUISER!", "IT THROWS CLAN-SQUEAKERS. MOVE!", Color8(255, 90, 60))
