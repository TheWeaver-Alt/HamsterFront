class_name MortarShell
extends Node2D
## A lobbed cedar-shaving canister that bursts into blinding sneezing powder.

var from := Vector2.ZERO
var to := Vector2.ZERO
var flight := 0.9
var damage := 20.0
var aoe := 30.0
var stun := 1.2
var height := 70.0
var _t := 0.0


func configure(a: Vector2, b: Vector2, dmg: float, area: float, stun_time: float) -> MortarShell:
	from = a
	to = b
	position = a
	damage = dmg
	aoe = area
	stun = stun_time
	flight = clampf(a.distance_to(b) / 160.0, 0.6, 1.1)
	return self


func _physics_process(delta: float) -> void:
	_t += delta / flight
	if _t >= 1.0:
		_land()
		return
	position = from.lerp(to, _t)
	queue_redraw()


func _land() -> void:
	var arena = GameManager.arena
	if arena != null:
		var sneezed := false
		for r in arena.get_rats_in_radius(to, aoe):
			r.take_damage(damage, (r.global_position - to).normalized() * 60.0, 0)
			r.apply_stun(stun)
			if not sneezed and randf() < 0.35:
				sneezed = JuiceManager.bark(r, "Achoo-choo! Eyes-burn!", true, "rat_sneeze", 4.0)
	JuiceManager.burst(to, Pal.SNEEZE, 26, 90.0, 0.9, 3.0, -10.0)
	JuiceManager.burst(to, Pal.CEDAR, 10, 120.0, 0.5, 2.0, 120.0)
	JuiceManager.ring(to, aoe, Pal.SNEEZE, 0.35)
	JuiceManager.add_trauma(0.22)
	SFX.play("boom", randf_range(1.1, 1.4), -4.0, 60)
	SFX.play("sneeze", randf_range(0.9, 1.2), -6.0, 80)
	queue_free()


func _draw() -> void:
	var h := 4.0 * height * _t * (1.0 - _t)
	var target_local := to - position
	# Landing marker.
	draw_arc(target_local.round(), aoe * 0.5, 0.0, TAU, 12, Color(Pal.SNEEZE, 0.35), 1.0)
	# Shadow + shell.
	draw_rect(Rect2(-2, 0, 5, 2), Pal.SHADOW)
	var y := roundf(-h)
	draw_rect(Rect2(-2, y - 3, 5, 6), Pal.CEDAR)
	draw_rect(Rect2(-2, y - 1, 5, 2), Pal.WHITE)
	draw_rect(Rect2(-1, y - 4, 3, 1), Pal.WOOD_DARK)
