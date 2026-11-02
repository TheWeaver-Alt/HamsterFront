class_name StatBlock
extends RefCounted
## Stat-modifier dictionary.
##
## final(key) = (base[key] + sum(add[key])) * product(mul[key])
## Flags are simple named booleans / counters set by cards ("no_overheat", "gatling_flaming" ...).
##
## Card modifier format (see CardDB):
##   { "add": {"max_hp": 40}, "mul": {"fire_rate": 1.2}, "flags": ["no_overheat"] }

signal changed

var base: Dictionary = {}
var _add: Dictionary = {}
var _mul: Dictionary = {}
var _flags: Dictionary = {}


func _init(base_values: Dictionary = {}) -> void:
	base = base_values.duplicate()


func g(key: String, default_value: float = 0.0) -> float:
	var b: float = base.get(key, default_value)
	return (b + float(_add.get(key, 0.0))) * float(_mul.get(key, 1.0))


func gi(key: String, default_value: int = 0) -> int:
	return int(roundf(g(key, float(default_value))))


func add(key: String, amount: float) -> void:
	_add[key] = float(_add.get(key, 0.0)) + amount
	changed.emit()


func mul(key: String, factor: float) -> void:
	_mul[key] = float(_mul.get(key, 1.0)) * factor
	changed.emit()


func set_flag(flag_name: String, value: int = 1) -> void:
	_flags[flag_name] = int(_flags.get(flag_name, 0)) + value
	changed.emit()


func has_flag(flag_name: String) -> bool:
	return int(_flags.get(flag_name, 0)) > 0


func flag_count(flag_name: String) -> int:
	return int(_flags.get(flag_name, 0))


## Applies a card-style modifier dictionary.
func apply_mods(mods: Dictionary) -> void:
	var a: Dictionary = mods.get("add", {})
	for k in a.keys():
		add(k, float(a[k]))
	var m: Dictionary = mods.get("mul", {})
	for k in m.keys():
		mul(k, float(m[k]))
	var f: Array = mods.get("flags", [])
	for fl in f:
		set_flag(String(fl))


func reset() -> void:
	_add.clear()
	_mul.clear()
	_flags.clear()
	changed.emit()


func debug_string() -> String:
	return "base=%s add=%s mul=%s flags=%s" % [base, _add, _mul, _flags]
