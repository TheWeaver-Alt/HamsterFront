class_name TowerBrain
extends RefCounted
## Behaviour plug-in for a TowerBase. Subclass per tower type in scripts/towers/brains/.
## Drawing: `draw(ci)` is called inside the tower's Visual node draw callback with the origin at
## the pad centre (crate top is around y = -6). Use ci.draw_* calls.

var tower: TowerBase


func setup(t: TowerBase) -> void:
	tower = t


func physics(_delta: float) -> void:
	pass


func draw(_ci: Node2D) -> void:
	pass


## Return false to skip the shared wooden crate (e.g. the cardboard decoy).
func draws_base() -> bool:
	return true


func range_mult() -> float:
	return 1.0


## >0 makes rats inside this radius target the tower (Cardboard Decoy).
func taunt_radius() -> float:
	return 0.0


func on_upgrade() -> void:
	pass


func on_overdrive() -> void:
	pass


func on_destroyed() -> void:
	pass
