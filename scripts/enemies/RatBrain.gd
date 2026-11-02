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
	ci.draw_sprite("rat_squeaker_%d" % ci.anim_frame())


## Drawn while the rat is still crawling out of its burrow (spawn_t > 0).
func draw_spawning(ci: RatEnemy) -> void:
	var t := PixelArt.tex("rat_squeaker_0")
	ci.draw_texture_rect_region(t, Rect2(-8, -4, 16, 4), Rect2(2, 0, 16, 4))


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
