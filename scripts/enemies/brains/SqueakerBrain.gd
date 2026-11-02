extends RatBrain
## Clan-Squeaker: swarm fodder with bent forks. Charges in packs of up to 20 and has a
## 10% chance to trip over a packmate's tail whenever it bumps into one (rate-limited),
## sometimes taking the rat behind it down too.

const TRIP_CHANCE := 0.10
const TRIP_TIME := 0.9
const TRIP_BARKS := ["Tail-tail! Who step-trip?!", "Clumsy-fool! My tail!", "Squeeek-trip!"]

var _bump_cd := 0.0


func physics(delta: float) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)
	rat.default_ai(delta)


func on_bump(other) -> void:
	if _bump_cd > 0.0 or other.kind != "squeaker":
		return
	_bump_cd = 1.0
	if randf() < TRIP_CHANCE:
		trip()
		# domino: the packmate we tripped over might go down too
		if randf() < 0.5 and other.brain.has_method("trip") and other.trip_t <= 0.0:
			other.brain.trip()


func trip() -> void:
	rat.trip_t = TRIP_TIME
	rat.knock += Vector2(rat.facing * 30.0, 0)
	if randf() < 0.25:
		JuiceManager.bark(rat, TRIP_BARKS[randi() % TRIP_BARKS.size()], "rat", false, 4.0)
	if is_instance_valid(GameManager.arena):
		GameManager.arena.fx.dust(rat.global_position, 3)


func draw(ci: RatEnemy) -> void:
	if ci.trip_t > 0.0:
		ci.draw_sprite("rat_squeaker_trip", Vector2(0, 2))
	else:
		ci.draw_sprite("rat_squeaker_%d" % ci.anim_frame())
