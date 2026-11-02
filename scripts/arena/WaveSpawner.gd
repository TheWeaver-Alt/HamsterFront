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
	var packs := 1 + int(n * 0.7)
	var pack_size := mini(20, 8 + n * 2)
	var gap := maxf(3.5, 9.0 - n * 0.35)
	# Unit ramp (waves 1..10):
	#   jezzail  -  1  1  2  2  3  3  4  4  5      snipers walk with the swarm
	#   monk     -  -  1  1  2  2  3  3  4  4      gas priests walk with the swarm
	#   roomba   -  -  -  1  1  1  2  2  2  3      own groups, launched mid-wave
	#   ogre     every 5th wave (n/5 of them), with a slightly lighter swarm
	var jezzails := 0 if n < 2 else 1 + int((n - 2) / 2)
	var monks := 0 if n < 3 else 1 + int((n - 3) / 2)
	var roombas := 0 if n < 4 else 1 + int((n - 4) / 3)
	var ogres := int(n / 5) if n % 5 == 0 else 0
	if ogres > 0:
		packs = maxi(1, packs - 1)
	var specials: Array = []
	for i in jezzails:
		specials.append("jezzail")
	for i in monks:
		specials.append("monk")
	specials.shuffle()
	var time := 1.0
	for p in packs:
		var units: Array = []
		for i in pack_size:
			units.append("squeaker")
		# sprinkle specials evenly through the packs (never in the very first rank)
		var per := int(ceil(float(specials.size()) / float(packs - p))) if specials.size() > 0 else 0
		for i in per:
			if specials.is_empty():
				break
			units.insert(randi_range(2, units.size()), specials.pop_back())
		out.append(_group(time, randi() % burrow_count, units, hp_mult, spd_mult))
		time += gap
	var span := gap * packs
	for i in roombas:
		var rt := 1.0 + span * float(i + 1) / float(roombas + 1) + 0.5
		out.append(_group(rt, randi() % burrow_count, ["roomba"], hp_mult, spd_mult))
	if ogres > 0:
		var ogre_units: Array = []
		for i in ogres:
			ogre_units.append("ogre")
		out.append(_group(1.0 + span * 0.4, randi() % burrow_count, ogre_units, hp_mult * 0.85, 1.0))
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
					g["next"] = 0.09 if kind == "squeaker" else (1.6 if kind == "ogre" else 0.4)
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
