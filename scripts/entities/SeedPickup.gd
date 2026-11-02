class_name SeedPickup
extends Node2D
## Dropped striped sunflower seed. Bounces, then gets vacuumed into cheek pouches.

const LIFETIME := 25.0

var value := 1
var vel := Vector2.ZERO
var life := LIFETIME
var _z := 0.0
var _zv := 0.0
var _flip := false


func launch(v: Vector2) -> SeedPickup:
	vel = v
	_zv = randf_range(50.0, 90.0)
	_flip = randf() < 0.5
	return self


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if _zv != 0.0 or _z > 0.0:
		_z += _zv * delta
		_zv -= 320.0 * delta
		if _z <= 0.0:
			_z = 0.0
			_zv = -_zv * 0.35 if absf(_zv) > 25.0 else 0.0
	position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 160.0 * delta)
	position = position.clamp(Vector2(18, 18), Vector2(622, 350))
	var arena = GameManager.arena
	if arena != null:
		for m in arena.mechs:
			if not m.can_collect():
				continue
			var mp: Vector2 = m.global_position
			var d := position.distance_to(mp)
			var mr: float = m.pouch.magnet_radius()
			if d < 7.0:
				if m.collect_seed(value):
					SFX.play("pickup", randf_range(0.9, 1.3), -10.0, 40)
					queue_free()
					return
			elif d < mr:
				var pull := lerpf(240.0, 70.0, d / mr)
				vel = (mp - position).normalized() * pull
	queue_redraw()


func _draw() -> void:
	if life < 4.0 and int(life * 8.0) % 2 == 0:
		return
	draw_rect(Rect2(-1, 1, 3, 1), Pal.SHADOW)
	var y := roundf(-_z) - 2.0
	var c := Pal.SEED_GOLD if value >= 3 else Pal.SEED
	if _flip:
		draw_rect(Rect2(-1, y, 3, 2), c)
		draw_rect(Rect2(0, y + 2, 1, 1), c)
		draw_rect(Rect2(0, y, 1, 2), Pal.SEED_STRIPE)
	else:
		draw_rect(Rect2(-1, y, 2, 3), c)
		draw_rect(Rect2(1, y + 1, 1, 1), c)
		draw_rect(Rect2(-1, y + 1, 2, 1), Pal.SEED_STRIPE)
