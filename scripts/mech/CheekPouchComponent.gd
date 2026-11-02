class_name CheekPouchComponent
extends Node
## The pilot's cheek pouches. Seeds vacuumed up land here; the fuller they get,
## the bigger the hamster's head and the slower the mech (up to -40%).

signal changed(amount: int, capacity: int)
signal became_full

const FULL_BARKS := [
	"Mmphf! Caffn't... ffit... mmore... sfeeds!",
	"Mmmf! Fhull! Sho fhull!",
	"Nngh... cheekf... at... capafity!",
]

var mech = null   # MechPlayer
var amount: int = 0
var _was_full := false
var _leak_acc := 0.0


func capacity() -> int:
	return maxi(1, mech.stats.gi("pouch_capacity"))


func fill() -> float:
	return clampf(float(amount) / float(capacity()), 0.0, 1.0)


func space() -> int:
	return maxi(0, capacity() - amount)


func is_full() -> bool:
	return amount >= capacity()


## Adds up to n seeds; returns how many fit.
func add(n: int) -> int:
	var added := mini(n, space())
	if added <= 0:
		return 0
	amount += added
	changed.emit(amount, capacity())
	if is_full() and not _was_full:
		_was_full = true
		became_full.emit()
		JuiceManager.bark(mech, FULL_BARKS[randi() % FULL_BARKS.size()], "hamster", true)
	return added


func take(n: int) -> int:
	var t := mini(n, amount)
	amount -= t
	if not is_full():
		_was_full = false
	changed.emit(amount, capacity())
	return t


func take_all() -> int:
	return take(amount)


## Movement multiplier from cheek weight (1.0 empty .. 0.6 full by default).
func speed_mult() -> float:
	return 1.0 - mech.stats.g("pouch_slow") * fill()


## 0..8 sprite level for the pilot's inflating head.
func head_level() -> int:
	return clampi(int(roundf(fill() * 8.0)), 0, 8)


func tick(delta: float) -> void:
	# Moldy Muenster corruption: cheeks leak seeds onto the lawn
	var leak: float = mech.stats.g("seed_leak")
	if leak > 0.0 and amount > 0:
		_leak_acc += leak * delta
		while _leak_acc >= 1.0 and amount > 0:
			_leak_acc -= 1.0
			take(1)
			if is_instance_valid(GameManager.arena):
				GameManager.arena.seeds.spawn(mech.global_position + Vector2(0, -4), 1, 40.0)
