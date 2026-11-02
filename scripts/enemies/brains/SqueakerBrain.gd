extends RatBrain
## Clan-Squeaker: swarm fodder with bent forks. Charges in packs of up to 20 and has a
## 10% chance to trip over a packmate's tail whenever it bumps into one (rate-limited),
## sometimes taking the rat behind it down too.

const TRIP_CHANCE := 0.10
const TRIP_TIME := 0.9
const TRIP_BARKS := ["Tail-tail! Who step-trip?!", "Clumsy-fool! My tail!", "Squeeek-trip!"]

const RA := preload("res://scripts/art/RatArt.gd")

var _bump_cd := 0.0
var _choo := false


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
	var v := ci.variant
	var pose := "walk"
	var f := 0
	var glow := true
	if ci.zap_anim > 0.0:
		pose = "zap"
		f = int(ci.anim_t * 30.0) % 2
		glow = false
	elif ci.trip_t > 0.0:
		pose = "trip"
		glow = false
	elif ci.sneeze_t > 0.0:
		pose = "sneeze"
		f = 0 if fmod(ci.sneeze_t, 0.55) > 0.2 else 1
		glow = false
		if f == 1 and not _choo:
			_choo = true
			_sneeze_puff(ci)
		elif f == 0:
			_choo = false
	elif ci.hit_anim > 0.0:
		pose = "hit"
		glow = false
	elif ci.atk_anim > 0.0:
		pose = "bite"
		f = 1 if ci.atk_anim > 0.15 else 0
	elif ci.moving():
		f = ci.walk_frame()
	else:
		pose = "idle"
		f = ci.idle_frame()
	var off := Vector2(0, 2) if pose == "trip" else Vector2.ZERO
	ci.draw_sprite("rat_sq_%d_%s_%d" % [v, pose, f], off)
	# glowing warp eye (the eyepatch variant only has the patch)
	if glow and v != 1:
		var e := Vector2(RA.sq_eye(pose, f))
		var sz := Vector2(RA.SQ_W, RA.SQ_H)
		var halo := Color(0.67, 1.0, 0.4, 0.28)
		ci.draw_sprite_px(sz, e + Vector2(-1, 0), halo)
		ci.draw_sprite_px(sz, e + Vector2(1, 0), halo)
		ci.draw_sprite_px(sz, e + Vector2(0, -1), halo)
		if int(ci.anim_t * 7.0 + ci.idle_seed * 3.0) % 9 == 0:
			ci.draw_sprite_px(sz, e, Color.WHITE)


func _sneeze_puff(ci: RatEnemy) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	var nose := ci.global_position + Vector2(ci.facing * 9.0, -6.0)
	arena.fx.burst(nose, 6, [PixelArt.C["t"], PixelArt.C["c"], PixelArt.C["w"]], 20, 70, 0.2, 0.45, 1.0, 20.0, 4.0,
		Vector2(ci.facing, 0), 0.6)
	if randf() < 0.3:
		Sfx.play_var("squeak_rat", 1.6, 0.1, -14.0)
