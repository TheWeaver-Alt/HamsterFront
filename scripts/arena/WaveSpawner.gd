class_name WaveSpawner
extends Node
## Builds a scaled spawn schedule per wave and releases rats from the burrows.

const FLAVOR := [
	"THE SQUEAKENING", "TAILS OF WOE", "GNAW-GNAW TIME", "THE GOUDA CALLS",
	"WHISKERS AT DAWN", "FORK AND FURY", "THE BIG STINK", "ROOMBA RUMBLE",
	"CHEESE-MAD AND CHONKY", "THE HORNED HOUR",
]

var queue: Array = []
var time := 0.0
var active := false
var total_spawned := 0


func flavor(n: int) -> String:
	return String(FLAVOR[(n - 1) % FLAVOR.size()])


func start_wave(n: int) -> void:
	queue.clear()
	time = 0.0
	active = true
	total_spawned = 0
	var arena = GameManager.arena
	var nb: int = arena.burrows.size()
	var coop := GameManager.player_count() >= 2
	var count_mult := 1.4 if coop else 1.0
	var hp_mult := 1.0 + 0.16 * (n - 1)
	# Burrows open up over the first few waves.
	var open := mini(nb, 2 + n)
	var t := 1.5
	# Clan-Squeaker packs (up to 20 each).
	var packs := 1 + int(n / 2.0)
	if coop and n >= 3:
		packs += 1
	var pack_size := mini(20, roundi((8 + n * 2) * (1.15 if coop else 1.0)))
	for p in packs:
		var b := randi() % open
		for i in pack_size:
			_add(t + i * 0.12, Defs.Rat.SQUEAKER, b, hp_mult, i == 0)
		t += maxf(3.0, 7.0 - n * 0.35)
	var span := maxf(t, 6.0)
	# Warp-Gouda Jezzails.
	if n >= 2:
		for i in roundi(mini(n - 1, 6) * count_mult):
			_add(randf_range(3.0, span), Defs.Rat.JEZZAIL, randi() % open, hp_mult)
	# Plague-Stink Monks.
	if n >= 3:
		for i in roundi(mini(int((n - 1) / 2.0), 5) * count_mult):
			_add(randf_range(4.0, span), Defs.Rat.MONK, randi() % open, hp_mult)
	# Doom-Roombas on even waves from 4.
	if n >= 4 and n % 2 == 0:
		for i in mini(1 + int(n / 6.0), 3):
			_add(randf_range(5.0, span), Defs.Rat.ROOMBA, randi() % open, hp_mult)
	# Rat-Ogre mini-boss every 5th wave.
	if n % 5 == 0:
		for i in int(n / 5.0):
			_add(span * 0.6 + i * 4.0, Defs.Rat.OGRE, randi() % open, hp_mult)
	queue.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))


func _add(at: float, kind: int, burrow: int, hp_mult: float, lead: bool = false) -> void:
	queue.append({"t": at, "kind": kind, "burrow": burrow, "hp": hp_mult, "lead": lead})


func _physics_process(delta: float) -> void:
	if not active:
		return
	time += delta
	while not queue.is_empty() and float(queue[0]["t"]) <= time:
		var e: Dictionary = queue.pop_front()
		_spawn(e)
	if queue.is_empty():
		active = false


func _spawn(e: Dictionary) -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	var c: Vector2i = arena.burrows[int(e["burrow"])]
	var p: Vector2 = arena.cell_to_world(c) + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	var r = arena.spawn_rat(int(e["kind"]), p, float(e["hp"]))
	total_spawned += 1
	JuiceManager.burst(p, Pal.DIRT, 4, 50.0, 0.4, 2.0, 80.0)
	if randf() < 0.4:
		JuiceManager.burst(p, Pal.WARP, 2, 30.0, 0.4, 1.0, 0.0, true)
	if bool(e["lead"]) and randf() < 0.6:
		JuiceManager.bark(r, "Yes-yes! Steal-take the fat-cheek seeds!", true, "rat_spawn", 5.0)


func is_finished() -> bool:
	return not active and queue.is_empty()


func remaining() -> int:
	return queue.size()
