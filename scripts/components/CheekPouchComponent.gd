class_name CheekPouchComponent
extends Node
## The Cheek-Pouch: risk/reward seed storage. Fuller cheeks = slower mech (up to -40%).
## Seeds can be banked at the Silo, crammed into a tower (Sugar Rush Overdrive),
## or violently spat out as an emergency shrapnel blast.

signal pouch_changed(held: int, capacity: int)

const BASE_CAPACITY := 30
const BASE_MAGNET := 30.0
const MAX_SLOW := 0.4
const MIN_CRAM := 5
const MIN_SPIT := 5

var held := 0
var mech: Node = null
var _was_full := false


func _ready() -> void:
	mech = get_parent()


func _pid() -> int:
	return int(mech.player_id)


func capacity() -> int:
	return maxi(1, roundi(BASE_CAPACITY * GameManager.pmodf(_pid(), "pouch_capacity_mult")))


func fill() -> float:
	return clampf(float(held) / capacity(), 0.0, 1.0)


func is_full() -> bool:
	return held >= capacity()


func magnet_radius() -> float:
	return BASE_MAGNET * GameManager.pmodf(_pid(), "magnet_mult")


func speed_factor() -> float:
	var slow := MAX_SLOW * fill() * GameManager.pmodf(_pid(), "pouch_slow_mult")
	return 1.0 - clampf(slow, 0.0, MAX_SLOW)


## Returns how many seeds were accepted.
func add_seeds(n: int) -> int:
	var space := capacity() - held
	var taken := mini(space, n)
	if taken <= 0:
		return 0
	held += taken
	pouch_changed.emit(held, capacity())
	if is_full() and not _was_full:
		_was_full = true
		JuiceManager.bark(mech, "Mmphf! Caffn't... ffit... mmore... sfeeds!", false, "full%d" % _pid(), 6.0)
		SFX.play("squeak", 0.7, -4.0)
	return taken


func _emptied() -> void:
	held = 0
	_was_full = false
	pouch_changed.emit(held, capacity())


func dump_to_silo(silo: Node2D) -> bool:
	if held <= 0:
		JuiceManager.bark(mech, "My cheeks are empty!", false, "empty%d" % _pid(), 2.5)
		return false
	var n := held
	_emptied()
	GameManager.add_seeds(n)
	GameManager.seeds_banked_total += n
	var from: Vector2 = mech.global_position + Vector2(0, -16)
	var to: Vector2 = silo.global_position + Vector2(0, -26)
	for i in mini(n, 24):
		var v := (to - from) * randf_range(1.6, 2.4) + Vector2(randf_range(-30, 30), randf_range(-60, -20))
		JuiceManager.particle(from, v, Pal.SEED if i % 4 else Pal.SEED_GOLD, 0.5, 2.0, 120.0)
	JuiceManager.popup(to + Vector2(0, -8), "+%d SEEDS" % n, Pal.SEED_GOLD)
	SFX.play("bank", randf_range(0.95, 1.1), -2.0)
	if GameManager.gmodb("cheek_share") and GameManager.arena != null:
		for m in GameManager.arena.mechs:
			if m.is_alive():
				m.heal(n * 1.5)
	if randf() < 0.35:
		JuiceManager.bark(mech, "Deposit! Sweet cheek relief.", false, "bank", 8.0)
	return true


func cram_into_tower(tower: Node2D) -> bool:
	if held < MIN_CRAM:
		JuiceManager.bark(mech, "Need %d+ seeds to cram!" % MIN_CRAM, false, "cram%d" % _pid(), 2.5)
		SFX.play("error")
		return false
	var n := held
	_emptied()
	tower.start_overdrive(n)
	JuiceManager.bark(mech, "WITNESS MY FLUFFY WRATH!", false, "overdrive%d" % _pid(), 1.0)
	JuiceManager.add_trauma(0.3)
	JuiceManager.burst(tower.global_position + Vector2(0, -8), Pal.SUGAR, 24, 110.0, 0.6, 2.0, 0.0, true)
	SFX.play("overdrive")
	return true


## Emergency screen-clearing shrapnel blast. Damage scales with seeds spat.
func spit(_aim: Vector2) -> bool:
	if held < MIN_SPIT:
		JuiceManager.bark(mech, "Not enough cheek ammo!", false, "spit%d" % _pid(), 2.5)
		SFX.play("error")
		return false
	var arena = GameManager.arena
	if arena == null:
		return false
	var n := held
	_emptied()
	var pid := _pid()
	var dm: float = mech.damage_mult() * GameManager.pmodf(pid, "spit_damage_mult")
	var fire := GameManager.pmodb(pid, "spit_fire")
	var origin: Vector2 = mech.global_position + Vector2(0, -12)
	var count := clampi(n, 14, 48)
	for i in count:
		var ang := TAU * i / count + randf_range(-0.06, 0.06)
		var p := Projectile.new().configure(origin, Vector2.from_angle(ang) * randf_range(230.0, 320.0), 9.0 * dm, "seed", true, pid)
		p.pierce = 2
		p.life = randf_range(0.55, 0.75)
		p.knock = 120.0
		p.radius = 3.0
		if fire:
			p.burn_dps = 8.0
		arena.add_projectile(p)
	for r in arena.get_rats_in_radius(origin, 58.0):
		var rp: Vector2 = r.global_position
		r.take_damage((15.0 + n * 0.8) * dm, (rp - origin).normalized() * 220.0, pid)
		if fire:
			r.apply_burn(8.0, 3.0)
	JuiceManager.bark(mech, "PTOOEY!!", false, "", 0.0)
	JuiceManager.hitstop(0.09)
	JuiceManager.add_trauma(0.6)
	JuiceManager.ring(origin, 60.0, Pal.WHITE, 0.35)
	JuiceManager.flash(origin, 18.0, Pal.WHITE, 0.08)
	JuiceManager.burst(origin, Pal.SEED, 30, 200.0, 0.6, 2.0, 60.0)
	SFX.play("spit")
	SFX.play("boom", 1.4, -6.0)
	return true


## Drops half the pouch on the ground (used when the mech goes down).
func spill() -> void:
	var arena = GameManager.arena
	var n := held / 2
	_emptied()
	if arena != null and n > 0:
		arena.spawn_seeds(mech.global_position, n)
