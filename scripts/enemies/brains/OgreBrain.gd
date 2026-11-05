extends RatBrain
## Rat-Ogre Bruiser (mini-boss): a hulking mutant stitched together with oven mitts and scrap
## iron. Stomps towards the nearest mech / tower (else the Silo), does a telegraphed ground slam,
## and every few seconds hurls a Clan-Squeaker that lands dizzy and fighting.

const SLAM_R := 26.0
const SLAM_WINDUP := 0.7
const SLAM_CD := 2.4
const THROW_WINDUP := 0.55
const THROW_CD := 4.0
const THROW_MIN := 40.0
const THROW_MAX := 170.0
const FOE_RANGE := 140.0

const BARKS := ["OGRE SMASH-CRUSH!", "Tiny-fluff go SPLAT!", "Silo-seeds for OGRE!", "Ogre not stitched-made for losing!"]
const SLAM_BARKS := ["SMAAASH!", "FLAT-FLAT!"]
const THROW_BARKS := ["Fly-fly, little squeaker!", "YEET-THROW!", "Catch-catch, fur-thing!"]
const LANDED_BARKS := ["Wheee-crunch! Again-again!", "Not me-me, you blind-fool!", "Ow-ow-ow... charge-charge!"]

var state := "walk"           # walk | slam | throw | recover
var state_t := 0.0
var slam_cd := 1.5
var throw_cd := 2.5
var foe = null
var slam_at := Vector2.ZERO
var throw_at := Vector2.ZERO
var _seek_t := 0.0
var _bark_t := 6.0
var _step_t := 0.0
var _scale := 1.0
var _hurt_t := 0.0
var _last_action := ""


func setup(r: RatEnemy) -> void:
	super.setup(r)
	_scale = maxf(1.0, (r.hp_scale - 1.0) * 0.5 + 1.0)


func get_bark_offset() -> float:
	return -42.0


func physics(delta: float) -> void:
	_hurt_t = maxf(0.0, _hurt_t - delta)
	slam_cd -= delta
	throw_cd -= delta
	_bark_t -= delta
	match state:
		"slam":
			_hold()
			state_t -= delta
			if state_t <= 0.0:
				_do_slam()
				state = "recover"
				state_t = 0.5
		"throw":
			_hold()
			state_t -= delta
			if state_t <= 0.0:
				_do_throw()
				state = "recover"
				state_t = 0.45
		"recover":
			_hold()
			state_t -= delta
			if state_t <= 0.0:
				state = "walk"
		_:
			_walk(delta)
	if _bark_t <= 0.0:
		_bark_t = randf_range(7.0, 11.0)
		JuiceManager.bark(rat, BARKS[randi() % BARKS.size()], "boss", false, 5.0)


func _hold() -> void:
	rat.velocity = rat.knock
	rat.move_and_slide()


func _foe_valid(f) -> bool:
	if not is_instance_valid(f):
		return false
	if f is MechPlayer:
		return not f.downed
	return f.alive


func _walk(delta: float) -> void:
	var arena = GameManager.arena
	_seek_t -= delta
	if _seek_t <= 0.0:
		_seek_t = 0.6
		foe = _find_foe()
	if foe != null and not _foe_valid(foe):
		foe = null
	var goal: Vector2
	var reach: float
	if foe != null:
		goal = foe.global_position
		reach = rat.radius + SLAM_R * 0.8
	else:
		goal = ArenaMap.SILO_CENTER
		reach = ArenaMap.SILO_RADIUS + rat.radius + 10.0
	var d := rat.global_position.distance_to(goal)
	if d <= reach and slam_cd <= 0.0:
		_start_slam(goal, d)
		return
	if throw_cd <= 0.0:
		var tt = _find_throw_target()
		if tt != null:
			_start_throw(tt)
			return
	if d <= reach:
		_hold()
		return
	var dest := goal
	if foe == null:
		dest = arena.map.flow_waypoint(rat.global_position)
	rat.move_toward_point(dest, rat.speed * rat.slow_mult, delta)
	# heavy footsteps
	_step_t -= delta
	if _step_t <= 0.0 and rat.velocity.length() > 5.0:
		_step_t = 0.45
		JuiceManager.add_trauma(0.05)
		arena.fx.dust(rat.global_position + Vector2(randf_range(-6, 6), 0), 3)


func _find_foe():
	var p = GameManager.nearest_player(rat.global_position, FOE_RANGE)
	if p != null and rat.can_walk_to(p.global_position):
		return p
	var best = null
	var bd := 90.0
	for t in GameManager.arena.towers:
		if not is_instance_valid(t) or not t.alive or not rat.can_walk_to(t.global_position):
			continue
		var d: float = rat.global_position.distance_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func _find_throw_target():
	var best = null
	var bd := THROW_MAX
	for p in GameManager.players:
		if not is_instance_valid(p) or p.downed:
			continue
		var d: float = rat.global_position.distance_to(p.global_position)
		if d > THROW_MIN and d < bd:
			bd = d
			best = p
	if best != null:
		return best
	bd = THROW_MAX
	for t in GameManager.arena.towers:
		if not is_instance_valid(t) or not t.alive:
			continue
		var d: float = rat.global_position.distance_to(t.global_position)
		if d > THROW_MIN and d < bd:
			bd = d
			best = t
	return best


func on_damaged(amount: float, _info: Dictionary) -> void:
	if amount >= 20.0:
		_hurt_t = 0.22


func _start_slam(goal: Vector2, d: float) -> void:
	_last_action = "slam"
	state = "slam"
	state_t = SLAM_WINDUP
	var to := (goal - rat.global_position).normalized()
	slam_at = rat.global_position + to * minf(d, 14.0)
	rat.facing = 1.0 if to.x >= 0.0 else -1.0
	Sfx.play("ogre_roar", 1.25, -8.0)
	if randf() < 0.35:
		JuiceManager.bark(rat, SLAM_BARKS[randi() % SLAM_BARKS.size()], "boss", false, 3.0)


func _start_throw(t) -> void:
	_last_action = "throw"
	state = "throw"
	state_t = THROW_WINDUP
	throw_at = t.global_position
	if t is MechPlayer:
		throw_at += t.velocity * 0.35     # lead the target a little
	rat.facing = 1.0 if throw_at.x >= rat.global_position.x else -1.0


func _do_slam() -> void:
	var arena = GameManager.arena
	var c := slam_at
	for p in GameManager.players:
		if is_instance_valid(p) and not p.downed and c.distance_to(p.global_position) < SLAM_R + 7.0:
			p.take_damage(25.0 * _scale, c)
			p.knock += (p.global_position - c).normalized() * 240.0
	for t in arena.towers:
		if is_instance_valid(t) and t.alive and c.distance_to(t.global_position) < SLAM_R + 8.0:
			t.take_damage(40.0 * _scale, rat)
	if c.distance_to(ArenaMap.SILO_CENTER) < ArenaMap.SILO_RADIUS + SLAM_R:
		GameManager.damage_silo(40.0 * _scale)
		arena.on_silo_hit(c)
	for e in arena.enemies_in_radius(c, SLAM_R):
		if e != rat and is_instance_valid(e) and e.alive and e.kind != "ogre":
			e.take_damage(12.0, c, 160.0, {"friendly": true, "kind": "slam"})
	arena.fx.ring(c, SLAM_R + 6.0, PixelArt.C["w"], 0.3)
	arena.fx.ring(c, SLAM_R * 0.6, PixelArt.C["T"], 0.25)
	arena.fx.burst(c, 26, [PixelArt.C["T"], PixelArt.C["b"], PixelArt.C["t"], PixelArt.C["E"]], 60, 180, 0.3, 0.7, 1.0, 160.0)
	arena.hazards.add("scorch", c, 14.0, 8.0)
	JuiceManager.add_trauma(0.55)
	JuiceManager.hit_stop(0.06)
	Sfx.play("explosion", 0.6, -2.0)
	slam_cd = SLAM_CD


func _do_throw() -> void:
	var arena = GameManager.arena
	var from: Vector2 = rat.global_position + Vector2(-rat.facing * 4.0, -34.0)
	var dist := from.distance_to(throw_at)
	var dur := clampf(dist / 150.0, 0.5, 1.2)
	var hp_mult := maxf(1.0, rat.hp_scale)
	# a lambda that uses `self` keeps this brain alive until the squeaker lands,
	# even if the ogre itself dies mid-throw
	var land := func(pos: Vector2) -> void: _on_rat_land(pos, hp_mult)
	arena.shots.lob(from, throw_at, dur, 46.0, "thrown_rat", land, {"team": 1, "owner": rat})
	Sfx.play("throw", 0.8, -2.0)
	if randf() < 0.4:
		JuiceManager.bark(rat, THROW_BARKS[randi() % THROW_BARKS.size()], "boss", false, 3.0)
	throw_cd = THROW_CD


func _on_rat_land(pos: Vector2, hp_mult: float) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena) or GameManager.phase == "gameover":
		return
	var dmg := 12.0 * sqrt(hp_mult)
	for p in GameManager.players:
		if is_instance_valid(p) and not p.downed and pos.distance_to(p.global_position) < 14.0 + 7.0:
			p.take_damage(dmg, pos)
	for t in arena.towers:
		if is_instance_valid(t) and t.alive and pos.distance_to(t.global_position) < 14.0 + 8.0:
			t.take_damage(dmg, null)
	for e in arena.enemies_in_radius(pos, 14.0):
		if is_instance_valid(e) and e.alive and e.kind != "ogre" and e.kind != "roomba":
			e.take_damage(8.0, pos, 120.0, {"friendly": true, "kind": "thrown"})
	arena.fx.dust(pos, 8)
	arena.fx.ring(pos, 14.0, PixelArt.C["T"], 0.2)
	JuiceManager.add_trauma(0.15)
	Sfx.play_var("punch", 0.6, 0.1, -4.0)
	if GameManager.phase != "wave" and GameManager.phase != "build":
		return
	var sq = arena.spawn_rat("squeaker", pos, hp_mult, 1.0)
	sq.spawn_t = 0.0
	sq.stun_t = 1.3
	if randf() < 0.3:
		JuiceManager.bark(sq, LANDED_BARKS[randi() % LANDED_BARKS.size()], "rat", false, 2.0)


func on_death(_info: Dictionary) -> void:
	var arena = GameManager.arena
	var pos := rat.global_position + Vector2(0, -14)
	arena.fx.explosion(pos, 34.0, "warp")
	arena.fx.explosion(pos + Vector2(randf_range(-8, 8), -6), 20.0, "fire")
	arena.fx.burst(pos, 30, [PixelArt.C["r"], PixelArt.C["w"], PixelArt.C["g"], PixelArt.C["m"]], 60, 200, 0.4, 1.0, 2.0, 160.0)
	arena.hazards.add("scorch", rat.global_position, 18.0, 20.0)
	JuiceManager.hit_stop(0.15)
	JuiceManager.add_trauma(0.9)
	JuiceManager.screen_flash(Color(0.67, 1.0, 0.4, 0.4), 0.2)
	Sfx.play("explosion", 0.55)
	Sfx.play("ogre_roar", 0.7, -4.0)
	JuiceManager.bark_at(pos + Vector2(0, -26), "Ogre... sleepy-tired...", "boss")
	GameManager.say("RAT-OGRE SQUASHED!", "THE STITCHES GAVE OUT", Color8(170, 255, 100))


func draw(ci: RatEnemy) -> void:
	var tms := Time.get_ticks_msec()
	if state == "slam":
		# telegraph: pulsing red danger ring that closes in on the impact point
		var prog := 1.0 - clampf(state_t / SLAM_WINDUP, 0.0, 1.0)
		var c := slam_at - ci.global_position
		var blink := 0.5 + 0.5 * sin(tms * 0.04)
		PixelArt.draw_disk(ci, c, SLAM_R, Color(1.0, 0.25, 0.2, 0.12 + 0.12 * prog))
		PixelArt.draw_ring(ci, c, SLAM_R, Color(1.0, 0.3, 0.2, 0.55 + 0.45 * blink))
		PixelArt.draw_ring(ci, c, SLAM_R * (1.0 - prog * 0.8) + 2.0, Color(1.0, 0.85, 0.5, 0.6))
	var sprite := "rat_ogre_walk_%d" % ci.walk_frame()
	if not ci.moving():
		sprite = "rat_ogre_walk_%d" % (int(ci.anim_t * 1.6) % 2)   # heavy breathing
	var shake := Vector2.ZERO
	match state:
		"slam":
			sprite = "rat_ogre_windup_0"
			shake = Vector2(randi_range(-1, 1), 0)
		"throw":
			sprite = "rat_ogre_throw_0"
			shake = Vector2(randi_range(-1, 1), 0)
		"recover":
			if _last_action == "slam" and state_t > 0.2:
				sprite = "rat_ogre_smash_0"
			else:
				sprite = "rat_ogre_walk_0"
				shake = Vector2(0, 1)
		_:
			if _hurt_t > 0.0:
				sprite = "rat_ogre_hurt_0"
	ci.draw_sprite(sprite, Vector2(0, 3) + shake)
	if state == "throw":
		var ball := PixelArt.tex("rat_squeaker_ball_%d" % (int(ci.anim_t * 8.0) % 2))
		var hand := Vector2(-12.0 * ci.facing, -31.0) + ci.vis_off
		ci.draw_texture(ball, (hand - ball.get_size() / 2.0).round())


func spawn_sprite(_ci: RatEnemy) -> String:
	return "rat_ogre_walk_0"
