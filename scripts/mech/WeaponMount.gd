class_name WeaponMount
extends Node2D
## Rotating weapon hardpoint: aim, cooldowns, recoil and the fire/alt triggers. What each chassis fires and
## how it is drawn lives in scripts/mech/chassis/<Name>Weapon.gd (ADR-0003), which overrides the hooks below.

var mech = null   # MechPlayer
var cooldown := 0.0
var alt_cd := 0.0
var recoil := 0.0
var aim := Vector2.RIGHT


func _ready() -> void:
	mech = get_parent()


func tick(delta: float, aim_dir: Vector2, fire_held: bool, alt_pressed: bool, can_act: bool) -> void:
	aim = aim_dir
	rotation = aim.angle()
	scale = Vector2(1, -1 if aim.x < 0.0 else 1)
	_layer_behind(aim.y < -0.55)
	cooldown = maxf(0.0, cooldown - delta)
	alt_cd = maxf(0.0, alt_cd - delta)
	recoil = move_toward(recoil, 0.0, 40.0 * delta)
	_tick_extra(delta)
	if can_act:
		if fire_held and cooldown <= 0.0:
			_fire()
		if alt_pressed and alt_cd <= 0.0:
			_alt()
	queue_redraw()


## Swing the weapons behind the body when aiming upward (cheap 3D depth).
func _layer_behind(behind: bool) -> void:
	var parent := get_parent()
	var vis := parent.get_node_or_null("Visual")
	if vis == null:
		return
	var vi: int = vis.get_index()
	var mi := get_index()
	if behind and mi > vi:
		parent.move_child(self, vi)
	elif not behind and mi < vi:
		parent.move_child(self, vi)


func muzzle_pos(side: float = 0.0) -> Vector2:
	return global_position + aim * 15.0 + aim.orthogonal() * side


func _arena():
	return GameManager.arena


func _draw() -> void:
	if mech == null or mech.downed:
		return
	_draw_weapon()


# ------------------------------------------------------------------ chassis hooks (overridden per chassis)

## Per-frame state decay for the chassis's own timers.
func _tick_extra(_delta: float) -> void:
	pass


## Primary fire (the trigger is held and the cooldown is up). Sets `cooldown`.
func _fire() -> void:
	pass


## Alt attack (pressed and `alt_cd` is up). Sets `alt_cd`.
func _alt() -> void:
	pass


## Draws the weapon in this node's rotated, flipped space.
func _draw_weapon() -> void:
	pass

