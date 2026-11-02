class_name TowerBrain
extends RefCounted
## Behaviour plug-in for a TowerBase. Subclass per tower type in scripts/towers/brains/.
## Drawing: `draw(ci)` is called on the tower's Head node (origin = pad centre; the crate lid spans
## y -8..-1, its front face 0..5). The Head node carries the build pop / upgrade bounce / sugar-rush
## squash transforms, so brains may freely use ci.draw_set_transform for their own parts.

var tower: TowerBase


func setup(t: TowerBase) -> void:
	tower = t


func physics(_delta: float) -> void:
	pass


func draw(_ci: Node2D) -> void:
	pass


## Pivot of the rotating head relative to the pad centre (aim_head / muzzle use it).
func head_offset() -> Vector2:
	return Vector2(0, -8)


## Texture flung off as debris when the tower is destroyed (null = none).
func debris_texture() -> Texture2D:
	return null


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


## Called after the tower takes damage (amount already scaled).
func on_damaged(_amount: float) -> void:
	pass
