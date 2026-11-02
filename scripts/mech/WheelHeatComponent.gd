class_name WheelHeatComponent
extends Node
## The internal exercise wheel that powers the mech. Sprinting heats it; past 80%
## it redlines; at 100% the hamster trips and spins out for 1.5s. Venting steam
## dumps all heat (briefly rooting the mech).

signal vented
signal spun_out
signal redlined

const REDLINE := 80.0
const VENT_TIME := 0.45
const BASE_SPINOUT := 1.5

const SPINOUT_BARKS := [
	"I HAVE LOST CONTROL OF THE CARDIO WHEEL!",
	"#@%&! SQUEAK! #@%&!",
	"WHEEEEL! WHY WHEEEEL?!",
]

var mech = null   # MechPlayer
var heat: float = 0.0          # 0..100
var venting: float = 0.0       # seconds left
var spinout: float = 0.0       # seconds left
var _redline_announced := false
var _beep_t := 0.0


func is_spinning() -> bool:
	return spinout > 0.0


func is_venting() -> bool:
	return venting > 0.0


func is_redline() -> bool:
	return heat >= REDLINE


func can_sprint() -> bool:
	return spinout <= 0.0 and venting <= 0.0


func tick(delta: float, sprinting: bool) -> void:
	if spinout > 0.0:
		spinout -= delta
		if spinout <= 0.0:
			heat = 45.0
		return
	if venting > 0.0:
		venting -= delta
		heat = maxf(0.0, heat - 260.0 * delta)
		return
	var no_heat: bool = mech.stats.has_flag("no_overheat")
	if sprinting and not no_heat:
		heat += mech.stats.g("heat_rate") * delta
	else:
		heat = maxf(0.0, heat - mech.stats.g("heat_decay") * delta)
	if heat >= REDLINE:
		if not _redline_announced:
			_redline_announced = true
			redlined.emit()
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 0.22
			Sfx.play("tick", 1.6, -8.0)
	else:
		_redline_announced = false
	if heat >= 100.0:
		heat = 100.0
		start_spinout()


func start_spinout() -> void:
	spinout = BASE_SPINOUT + mech.stats.g("spinout_bonus")
	Sfx.play("spinout", randf_range(0.9, 1.1))
	JuiceManager.bark(mech, SPINOUT_BARKS[0] if randf() < 0.6 else SPINOUT_BARKS[randi() % SPINOUT_BARKS.size()], "hamster", true)
	spun_out.emit()


## Returns true if a vent actually happened.
func vent() -> bool:
	if heat < 8.0 or venting > 0.0 or spinout > 0.0:
		return false
	venting = VENT_TIME
	Sfx.play("vent", randf_range(0.9, 1.1))
	vented.emit()
	return true
