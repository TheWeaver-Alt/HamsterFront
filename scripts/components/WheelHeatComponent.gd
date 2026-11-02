class_name WheelHeatComponent
extends Node
## Hamster Wheel Overheat. Sprinting builds heat; past redline the pilot trips
## inside the wheel and spins out for 1.5s unless they vent steam first.

signal tripped
signal vented

const MAX_HEAT := 100.0
const REDLINE := 75.0
const SPRINT_HEAT := 32.0
const PASSIVE_COOL := 9.0
const VENT_TIME := 0.6
const VENT_COOLDOWN := 1.4
const TRIP_RESET_HEAT := 45.0

var heat := 0.0
var vent_t := 0.0
var vent_cd := 0.0
var mech: Node = null
var _redline_warned := false


func _ready() -> void:
	mech = get_parent()


func process_heat(delta: float, sprinting: bool) -> void:
	vent_cd = maxf(0.0, vent_cd - delta)
	if vent_t > 0.0:
		vent_t -= delta
		heat = maxf(0.0, heat - (MAX_HEAT / VENT_TIME) * delta)
		return
	var pid: int = mech.player_id
	if sprinting and not GameManager.pmodb(pid, "no_overheat"):
		heat += SPRINT_HEAT * GameManager.pmodf(pid, "heat_rate_mult") * delta
	else:
		heat = maxf(0.0, heat - PASSIVE_COOL * delta)
	if heat >= REDLINE and not _redline_warned:
		_redline_warned = true
		SFX.play("alarm", 1.3, -6.0)
	elif heat < REDLINE - 10.0:
		_redline_warned = false
	if heat >= MAX_HEAT:
		heat = TRIP_RESET_HEAT
		tripped.emit()


func add_heat(amount: float) -> void:
	var pid: int = mech.player_id
	if GameManager.pmodb(pid, "no_overheat"):
		return
	heat = minf(MAX_HEAT - 0.01, heat + amount * GameManager.pmodf(pid, "heat_rate_mult"))


func vent() -> bool:
	if vent_t > 0.0 or vent_cd > 0.0 or heat < 5.0:
		return false
	vent_t = VENT_TIME
	vent_cd = VENT_COOLDOWN
	vented.emit()
	return true


func is_venting() -> bool:
	return vent_t > 0.0


func is_redline() -> bool:
	return heat >= REDLINE


func can_sprint() -> bool:
	return vent_t <= 0.0


func ratio() -> float:
	return heat / MAX_HEAT
