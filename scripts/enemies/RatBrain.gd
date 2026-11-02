class_name RatBrain
extends RefCounted
## Behaviour plug-in for a RatEnemy. Subclass per unit type in scripts/enemies/brains/.
## Override any of these; the defaults give a generic walk-to-silo-and-gnaw rat.

var rat: RatEnemy


func setup(r: RatEnemy) -> void:
	rat = r


## Called every physics frame while the rat is not stunned/tripped.
func physics(delta: float) -> void:
	rat.default_ai(delta)


## Draw the rat (called from RatEnemy._draw, so draw_* calls go through `rat`).
func draw(ci: RatEnemy) -> void:
	ci.draw_sprite("rat_sq_%d_walk_%d" % [ci.variant, ci.walk_frame()] if ci.moving() else "rat_sq_%d_idle_%d" % [ci.variant, ci.idle_frame()])


## Sprite that rises out of the burrow while spawning.
func spawn_sprite(ci: RatEnemy) -> String:
	return "rat_sq_%d_idle_1" % ci.variant


## Drawn while the rat is still crawling out of its burrow (spawn_t > 0): ears, then head, then
## shoulders rise out of a churned dirt ring, clipped at ground level.
func draw_spawning(ci: RatEnemy) -> void:
	var p := ci.spawn_progress()
	var t := PixelArt.tex(spawn_sprite(ci))
	var sz := t.get_size()
	var w := ci.radius * 2.0 + 6.0
	var hw := roundf(w / 2.0)
	# dark hole with a churned dirt mound heaped on both sides
	ci.draw_rect(Rect2(-hw + 1, -1, hw * 2.0 - 2.0, 2), Color(0.06, 0.03, 0.06, 0.9))
	ci.draw_rect(Rect2(-hw + 2, -2, hw * 2.0 - 4.0, 1), Color(0.06, 0.03, 0.06, 0.6))
	for side in [-1.0, 1.0]:
		var sd: float = side
		var x0: float = sd * (hw - 1.0)
		ci.draw_rect(Rect2(Vector2(x0 - 1.0, -2), Vector2(2, 2)), PixelArt.C["T"])
		ci.draw_rect(Rect2(Vector2(x0 + sd - 0.5, -1), Vector2(1, 1)), PixelArt.C["b"])
		ci.draw_rect(Rect2(Vector2(x0 - sd - 0.5, -3), Vector2(1, 1)), PixelArt.C["t"])
	var show_h := clampi(int(roundf(sz.y * (0.2 + 0.8 * p))), 2, int(sz.y))
	var jig := Vector2(randi_range(-1, 1) if p < 0.9 else 0, 0)
	ci.draw_set_transform(jig, 0.0, Vector2(ci.facing, 1))
	ci.draw_texture_rect_region(t, Rect2(-roundf(sz.x / 2.0), -show_h, sz.x, show_h), Rect2(0, 0, sz.x, show_h))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# flicking dirt clods
	if randf() < 0.5:
		ci.draw_rect(Rect2(Vector2(randi_range(-int(w / 2.0), int(w / 2.0)), -randi_range(2, 6)), Vector2(1, 1)), PixelArt.C["T"])


## Snapshot for the death animation (see RatCorpses.gd).
func corpse_data(ci: RatEnemy) -> Dictionary:
	return {"kind": ci.kind, "variant": ci.variant, "pos": ci.global_position, "facing": ci.facing,
		"knock": ci.knock, "vel": ci.velocity}


func on_damaged(_amount: float, _info: Dictionary) -> void:
	pass


func on_death(_info: Dictionary) -> void:
	pass


func get_bark_offset() -> float:
	return -20.0


## Called when this rat physically bumps a packmate (separation overlap).
func on_bump(_other) -> void:
	pass


## Lets a brain scale incoming damage (armour, shields...). Return the final amount.
func modify_damage(amount: float, _info: Dictionary) -> float:
	return amount
