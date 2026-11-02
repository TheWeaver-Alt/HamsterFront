extends RatBrain
## Doom-Roomba: a stolen robot vacuum strapped with spikes and green lightning coils.
## Ignores the flow field — drives in straight lines, bounces erratically off walls, props,
## pads and towers, drifting towards the Silo. Spikes hurt everything it rams (rats included),
## and its coils zap whatever is nearby.

const BUMP_CD := 0.7
const ZAP_EVERY := 1.5
const ZAP_RANGE := 56.0
const BARKS := ["Wheee-crash! Bounce-bounce!", "Vacuum-suck the seeds!", "Steer-left! LEFT-LEFT!", "Brakes? What-what brakes?!"]

var dir := Vector2.RIGHT
var _turn_t := 1.5
var _zap_t := 1.0
var _snd_t := 0.0
var _hit_cd: Dictionary = {}     # instance_id -> seconds until it can be hit again
var _brush := 0.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _scale := 1.0


func setup(r: RatEnemy) -> void:
	super.setup(r)
	r.collision_mask = GameManager.L_WORLD | GameManager.L_RAT_BLOCK | GameManager.L_TOWERS
	var to := (ArenaMap.SILO_CENTER - r.global_position).normalized()
	dir = to.rotated(randf_range(-0.9, 0.9))
	_last_pos = r.global_position
	_scale = maxf(1.0, (r.hp_scale - 1.0) * 0.5 + 1.0)
	_zap_t = randf_range(0.5, ZAP_EVERY)


func get_bark_offset() -> float:
	return -26.0


func physics(delta: float) -> void:
	_brush += delta * 25.0
	for k in _hit_cd.keys():
		_hit_cd[k] -= delta
		if _hit_cd[k] <= 0.0:
			_hit_cd.erase(k)
	# erratic steering + slow pull towards the Silo
	_turn_t -= delta
	if _turn_t <= 0.0:
		_turn_t = randf_range(1.2, 2.8)
		dir = dir.rotated(randf_range(-0.9, 0.9))
	var to_silo := (ArenaMap.SILO_CENTER - rat.global_position).normalized()
	dir = (dir + to_silo * 0.35 * delta).normalized()
	var v := dir * rat.speed * rat.slow_mult + rat.knock
	rat.velocity = v
	var col := rat.move_and_collide(v * delta)
	if col != null:
		_on_collide(col)
	_contacts()
	_zap_t -= delta
	if _zap_t <= 0.0:
		_zap_t = ZAP_EVERY * randf_range(0.8, 1.2)
		_zap()
	_snd_t -= delta
	if _snd_t <= 0.0:
		_snd_t = 1.1
		Sfx.play("roomba", randf_range(0.9, 1.1), -14.0)
	# unstick
	_stuck_t += delta
	if _stuck_t >= 0.6:
		if rat.global_position.distance_to(_last_pos) < 3.0:
			dir = Vector2.from_angle(randf() * TAU)
		_stuck_t = 0.0
		_last_pos = rat.global_position


func _can_hit(o) -> bool:
	var id: int = o.get_instance_id()
	if _hit_cd.has(id):
		return false
	_hit_cd[id] = BUMP_CD
	return true


func _on_collide(col: KinematicCollision2D) -> void:
	var arena = GameManager.arena
	var n := col.get_normal()
	dir = dir.bounce(n).rotated(randf_range(-0.6, 0.6)).normalized()
	if dir.dot(n) < 0.25:
		dir = (dir + n).normalized()
	rat.knock = rat.knock.bounce(n) * 0.5
	rat.global_position += n * 1.0
	var other = col.get_collider()
	var hit_pos := col.get_position()
	if other != null and other == arena.silo_node:
		if _can_hit(other):
			GameManager.damage_silo(25.0 * _scale)
			arena.on_silo_hit(hit_pos)
			JuiceManager.add_trauma(0.25)
			arena.fx.sparks(hit_pos, Color8(170, 255, 100), 10)
			if randf() < 0.3:
				JuiceManager.bark(rat, BARKS[1], "rat", false, 5.0)
	elif other is TowerBase:
		if other.alive and _can_hit(other):
			other.take_damage(20.0 * _scale, rat)
			arena.fx.sparks(hit_pos, Color8(255, 214, 64), 8)
			Sfx.play_var("punch", 0.7, 0.1, -6.0)
			JuiceManager.add_trauma(0.12)
	else:
		arena.fx.sparks(hit_pos, Color8(200, 192, 178), 4)
		JuiceManager.add_trauma(0.04)
		if randf() < 0.06:
			JuiceManager.bark(rat, BARKS[randi() % BARKS.size()], "rat", false, 6.0)


func _contacts() -> void:
	var arena = GameManager.arena
	var pos := rat.global_position
	for p in GameManager.players:
		if not is_instance_valid(p) or p.downed:
			continue
		if pos.distance_to(p.global_position) < rat.radius + 8.0 and _can_hit(p):
			p.take_damage(15.0 * _scale, pos)
			p.knock += (p.global_position - pos).normalized() * 220.0
			arena.fx.sparks(p.global_position + Vector2(0, -8), Color8(255, 248, 231), 6)
	for e in arena.enemies_in_radius(pos, rat.radius + 1.0):
		if e == rat or not is_instance_valid(e) or not e.alive:
			continue
		if e.kind == "roomba" or e.kind == "ogre" or e.spawn_t > 0.0:
			continue
		if _can_hit(e):
			e.take_damage(10.0, pos, 140.0, {"friendly": true, "kind": "roomba"})


func _zap() -> void:
	var arena = GameManager.arena
	var pos := rat.global_position
	var cands: Array = []
	for p in GameManager.players:
		if is_instance_valid(p) and not p.downed and pos.distance_to(p.global_position) < ZAP_RANGE:
			cands.append(p)
	for t in arena.towers:
		if is_instance_valid(t) and t.alive and pos.distance_to(t.global_position) < ZAP_RANGE:
			cands.append(t)
	for e in arena.enemies_in_radius(pos, ZAP_RANGE * 0.6):
		if e != rat and is_instance_valid(e) and e.alive and e.kind == "squeaker":
			cands.append(e)
	if cands.is_empty():
		return
	var t = cands[randi() % cands.size()]
	var coil := pos + Vector2(7.0 * rat.facing, -15)
	arena.fx.bolt(coil, t.global_position + Vector2(0, -6), Color8(170, 255, 100), 0.15, 5.0)
	arena.fx.warp_sparks(t.global_position + Vector2(0, -6), 5)
	Sfx.play("zap", randf_range(1.0, 1.3), -8.0)
	if t is MechPlayer:
		t.take_damage(6.0 * _scale, pos, true)
	elif t is TowerBase:
		t.take_damage(8.0 * _scale, rat)
	else:
		t.take_damage(6.0, pos, 0.0, {"friendly": true, "kind": "zap"})


func draw(ci: RatEnemy) -> void:
	ci.draw_sprite("rat_roomba")
	# spinning side brush at the front corner
	var bp := Vector2(9.0 * ci.facing, -3.0)
	for i in 3:
		var a := _brush + i * TAU / 3.0
		ci.draw_line(bp, (bp + Vector2(cos(a) * 3.0, sin(a) * 1.5)).round(), PixelArt.C["y"], 1.0)
	# crackling warp arc between the coils
	if randf() < 0.6:
		var a0 := Vector2(-7, -15)
		var a1 := Vector2(7, -15)
		var prev := a0
		for s in range(1, 5):
			var p := a0.lerp(a1, s / 4.0) + Vector2(0, randi_range(-2, 1))
			ci.draw_line(prev.round(), p.round(), PixelArt.C["z"] if randf() < 0.7 else Color.WHITE, 1.0)
			prev = p


func draw_spawning(ci: RatEnemy) -> void:
	# the vacuum's dome lid and evil light poke out of the hole
	ci.draw_rect(Rect2(-7, -3, 14, 3), PixelArt.C["G"])
	ci.draw_rect(Rect2(-5, -4, 10, 1), PixelArt.C["g"])
	ci.draw_rect(Rect2(0, -3, 1, 1), PixelArt.C["z"])
