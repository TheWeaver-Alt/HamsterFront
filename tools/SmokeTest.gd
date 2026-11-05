extends Node
## Automated playtest: two bot pilots defend the Silo through several waves, building towers,
## banking/cramming seeds, spitting, sprinting into overheat and drafting cards.
## Usage:
##   godot --path . res://tools/SmokeTest.tscn -- --waves=4 --speed=3 [--shots] [--spawn-all] [--lob-free] [--stuck]
## Prints a summary; screenshots go to res://screenshots/ when --shots is given (needs a GPU/Xvfb).

const ArenaScene := preload("res://scenes/MainArena.tscn")

var arena = null
var waves_target := 3
var speed := 3.0
var take_shots := false
var spawn_all := false
var _spawned_all := false
var lob_free := false
var economy := false
var mechs_check := false
var _mech_stage := 0
var _mech_frames := 0
var _mech_failed := 0
var _mech_rats: Array = []
var cards_check := false
var _cards_done := false
var _economy_done := false
var _economy_failed := 0
var _gate_stage := 0
var _gate_frames := 0
var _gate_asked := 0
var _gate_level := 0
var _gate_fail_base := 0
var _gate_tower = null
var _gate_learning: Array = []
var stuck := false
var _stuck_stage := 0
var _stuck_cases := 0
var _stuck_wedged := 0
var _embedded_frames := 0
var _embedded_episodes := 0
var _embedded_streak := 0
var _lob_stage := 0
var _lob_rat = null
var stress := 0
var _hops := 0
var _was_hopping: Dictionary = {}
var _perf_samples: Array = []
var t := 0.0
var frame := 0
var shot_i := 0
var _bot_t := 0.0
var _next_shot := 4.0
var _built := 0
var _errors_seen := 0
var _max_wave := 0
var _drafts := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--waves="):
			waves_target = int(a.get_slice("=", 1))
		elif a.begins_with("--speed="):
			speed = float(a.get_slice("=", 1))
		elif a == "--shots":
			take_shots = true
		elif a == "--spawn-all":
			spawn_all = true
		elif a.begins_with("--learning="):
			var lv := int(a.get_slice("=", 1))
			GameManager.learning_levels = [lv, lv]
		elif a.begins_with("--chassis="):
			var picks := a.get_slice("=", 1).split(",")
			GameManager.player_chassis = [picks[0], picks[picks.size() - 1]]
		elif a == "--mechs":
			mechs_check = true
		elif a == "--cards":
			cards_check = true
		elif a == "--economy":
			economy = true
		elif a == "--lob-free":
			lob_free = true
		elif a == "--stuck":
			stuck = true
		elif a == "--kid":
			GameManager.difficulty = "kid"
		elif a.begins_with("--stress="):
			stress = int(a.get_slice("=", 1))
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.num_players = 2
	GameManager.player_devices = ["bot", "bot"]
	arena = ArenaScene.instantiate()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	for p in GameManager.players:
		p.input.set_device("bot")
		p.stats.set_flag("jetpack")   # bots hop cliffs to reach plateau pads
	GameManager.seeds = 400
	GameManager.seeds_changed.emit(GameManager.seeds)
	Engine.time_scale = speed
	print("[smoke] start: waves=%d speed=%.1f" % [waves_target, speed])


func _physics_process(delta: float) -> void:
	frame += 1
	t += delta
	_max_wave = maxi(_max_wave, GameManager.wave)
	if Engine.time_scale > 0.2 and Engine.time_scale < speed and GameManager.phase != "gameover":
		Engine.time_scale = speed
	if _stuck_stage != 1:
		_drive_bots(delta)
	_count_embedded()
	if stuck and _stuck_stage == 0 and GameManager.phase == "build" and frame >= 10:
		_stuck_stage = 1
		_stuck_run()
	for p in GameManager.players:
		var h: bool = p.hop_t > 0.0
		if h and not _was_hopping.get(p.player_id, false):
			_hops += 1
		_was_hopping[p.player_id] = h
	if stress > 0 and frame == 60:
		for k in stress:
			var b: Vector2i = ArenaMap.BURROWS[k % ArenaMap.BURROWS.size()]
			arena.spawn_rat("squeaker", ArenaMap.cell_center(b) + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 3.0, 1.0)
	if stress > 0 and frame > 60 and frame % 30 == 0:
		_perf_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		if _perf_samples.size() % 10 == 0:
			print("[smoke] stress enemies=%d physics_ms=%.2f fps=%d particles_shots=%d" % [arena.enemies.size(), _perf_samples[-1], Engine.get_frames_per_second(), arena.shots.shots.size()])
	if spawn_all and not _spawned_all and frame >= 90 and (not stuck or _stuck_stage == 2):
		_spawned_all = true
		for k in ["squeaker", "jezzail", "monk", "roomba", "ogre"]:
			arena.spawn_rat(k, ArenaMap.cell_center(ArenaMap.BURROWS[0]) + Vector2(randf_range(-6, 6), 0), 1.0, 1.0)
	if cards_check and not _cards_done:
		_cards_check()
	if mechs_check and _mech_stage < 3 and frame >= 30 and (not stuck or _stuck_stage == 2):
		_mechs_step()
	if economy and not _economy_done and frame >= 20:
		_economy_check()
	if economy and _economy_done and _gate_stage < 3 and (not stuck or _stuck_stage == 2):
		_gate_step()
	if lob_free:
		_lob_free_step()
	if GameManager.phase == "gameover" or GameManager.wave > waves_target or t > 60.0 * waves_target + 60.0:
		_finish()


func _process(_delta: float) -> void:
	if take_shots and t >= _next_shot:
		_next_shot += 9.0
		_shot()


func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var path := "res://screenshots/smoke_%02d.png" % shot_i
	img.save_png(path)
	print("[smoke] screenshot ", path, " phase=", GameManager.phase, " wave=", GameManager.wave)
	shot_i += 1


func _drive_bots(delta: float) -> void:
	_bot_t += delta
	var i := 0
	for p in GameManager.players:
		if not is_instance_valid(p):
			continue
		var inp: PlayerInput = p.input
		var held := {}
		var move := Vector2.ZERO
		var target = arena.nearest_enemy(p.global_position, 200.0)
		var quiz_up: bool = arena.math_quiz != null and arena.math_quiz.active
		if GameManager.phase == "draft" or quiz_up:
			# mash confirm on alternate frames so the draft UI sees presses
			held["confirm"] = frame % 6 < 3
			if frame % 40 == 0:
				held["right"] = true
		else:
			# build phase: spend seeds on new towers, then upgrades (sprinting = jetpack hops)
			var build_dest := Vector2.INF
			if GameManager.phase == "build" and GameManager.seeds >= 40:
				var pad := _nearest_free_pad(p.global_position)
				if pad != Vector2i(-1, -1) and _built < 16:
					build_dest = ArenaMap.cell_center(pad)
					if p.global_position.distance_to(build_dest) < 10.0 and frame % 20 == 0:
						p.selected_tower = (_built + i) % 5
						held["build"] = true
						_built += 1
				else:
					var tw = _cheapest_upgrade(p.global_position)
					if tw != null:
						build_dest = tw.global_position + Vector2(0, 14)
						if p.global_position.distance_to(build_dest) < 12.0 and frame % 20 == 0:
							held["build"] = true
			if build_dest != Vector2.INF:
				move = (build_dest - p.global_position).normalized() if p.global_position.distance_to(build_dest) > 4.0 else Vector2.ZERO
				held["sprint"] = true
			elif p.pouch.fill() > 0.8:
				# go bank (or cram a tower if one is right here)
				var to_silo: Vector2 = ArenaMap.SILO_CENTER + Vector2(0, 34) - p.global_position
				move = to_silo.normalized() if to_silo.length() > 20.0 else Vector2.ZERO
				if to_silo.length() < 40.0 and frame % 10 == 0:
					held["interact"] = true
			else:
				# orbit the silo, stay near the action
				var ang := _bot_t * 0.6 + i * PI
				var dest := ArenaMap.SILO_CENTER + Vector2(cos(ang) * 70.0, sin(ang) * 55.0)
				if target != null and randf() < 0.5:
					dest = target.global_position.lerp(ArenaMap.SILO_CENTER, 0.5)
				move = (dest - p.global_position).normalized() if p.global_position.distance_to(dest) > 6.0 else Vector2.ZERO
			if target != null:
				inp.bot_aim = (target.global_position - p.global_position).normalized()
				held["fire"] = true
				if p.global_position.distance_to(target.global_position) < 30.0 and frame % 30 == i:
					held["alt"] = true
			# sprint in bursts to exercise the wheel, vent sometimes
			if build_dest == Vector2.INF and int(_bot_t * 0.5 + i) % 3 == 0:
				held["sprint"] = true
			if p.wheel.heat > 70.0 and frame % 50 == 0 and randf() < 0.5:
				held["vent"] = true
			if p.pouch.amount > 20 and frame % 600 == 300 + i:
				held["spit"] = true
			if GameManager.phase == "build" and (GameManager.seeds < 40 or arena.build_timer < 8.0) and frame % 30 == 0:
				held["ready"] = true
		inp.bot_move = move
		inp.bot_held = held
		i += 1


func _cheapest_upgrade(pos: Vector2):
	var best = null
	var bd := INF
	for t in arena.towers:
		if not is_instance_valid(t) or t.level >= GameManager.MAX_TOWER_LEVEL:
			continue
		if GameManager.tower_cost(t.kind, t.level + 1) > GameManager.seeds:
			continue
		var d := pos.distance_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func _nearest_free_pad(pos: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for c in ArenaMap.PADS:
		if arena.pad_towers.has(c):
			continue
		var d := pos.distance_to(ArenaMap.cell_center(c))
		if d < bd:
			bd = d
			best = c
	return best


## Regression for "Lambda capture ... was freed" (--lob-free): a mortar shell is in flight when
## its tower dies. Stage 0 builds a mortar and fires it at a rat, then destroys the tower;
## stage 1 waits for the shell to land (a freed capture logs an ERROR, which tools/check.sh fails on).
func _lob_free_step() -> void:
	if _lob_stage == 0 and GameManager.phase == "build" and frame >= 100 and (not stuck or _stuck_stage == 2):
		_lob_stage = 3
		var cell := _nearest_free_pad(ArenaMap.SILO_CENTER)
		if cell == Vector2i(-1, -1) or not arena.try_build(GameManager.players[0], cell, "mortar"):
			push_error("lob-free: could not build a mortar")
			return
		var tower = arena.pad_towers[cell]
		_lob_rat = arena.spawn_rat("squeaker", tower.global_position + Vector2(48, 0), 1.0, 0.01)
		tower.brain._fire(_lob_rat)
		if not _mortar_in_flight():
			push_error("lob-free: the mortar did not fire")
			return
		tower.destroy()
		_lob_stage = 1
	elif _lob_stage == 1 and not _mortar_in_flight():
		if is_instance_valid(_lob_rat):
			_lob_rat.take_damage(9999.0, _lob_rat.global_position, 0.0, {})
		print("[smoke] lob-free: mortar shell landed after its tower was destroyed")
		_lob_stage = 2


## Counts and reports a failed economy assertion (the ERROR line is what tools/check.sh fails on).
func _econ_fail(msg: String) -> void:
	_economy_failed += 1
	push_error("economy: " + msg)


## Silo store rules (--economy, ADR-0002): the capacity caps add_seeds and banking, and upgrades raise it.
func _economy_check() -> void:
	_economy_done = true
	var p = GameManager.players[0]
	var saved_seeds: int = GameManager.seeds
	var saved_learning: Array = GameManager.learning_levels.duplicate()
	GameManager.learning_levels = [0, 0]
	p.pouch.take_all()
	if GameManager.silo_level != 1 or GameManager.silo_capacity != int(GameManager.SILO_CAPACITY[0]):
		_econ_fail("a new run should start at Silo level 1")
	GameManager.seeds = GameManager.silo_capacity - 10
	var got: int = GameManager.add_seeds(30)
	if got != 10 or GameManager.seeds != GameManager.silo_capacity or GameManager.store_space() != 0:
		_econ_fail("add_seeds should fill the store and return 10, got %d (seeds=%d)" % [got, GameManager.seeds])
	if GameManager.add_seeds(5) != 0:
		_econ_fail("add_seeds should add nothing to a full store")
	p.pouch.add(20)
	if p._bank_seeds(20) != 0 or p.pouch.amount != 20:
		_econ_fail("banking into a full store must leave the seeds in the cheeks")
	GameManager.seeds = GameManager.silo_capacity - 8
	if p._bank_seeds(20) != 8 or p.pouch.amount != 12 or GameManager.seeds != GameManager.silo_capacity:
		_econ_fail("banking should move only what fits (8), pouch=%d seeds=%d" % [p.pouch.amount, GameManager.seeds])
	p.pouch.take_all()
	# each upgrade costs seeds and raises the capacity; the top level refuses another
	for lv in range(2, GameManager.SILO_CAPACITY.size() + 1):
		GameManager.seeds = 1000
		var cost: int = GameManager.silo_upgrade_cost()
		arena.try_upgrade_silo(p)
		if GameManager.silo_level != lv or GameManager.silo_capacity != int(GameManager.SILO_CAPACITY[lv - 1]) or GameManager.seeds != 1000 - cost:
			_econ_fail("upgrade to level %d failed (level=%d capacity=%d seeds=%d)" % [lv, GameManager.silo_level, GameManager.silo_capacity, GameManager.seeds])
	GameManager.seeds = 1000
	arena.try_upgrade_silo(p)
	if GameManager.silo_level != GameManager.SILO_CAPACITY.size() or GameManager.seeds != 1000:
		_econ_fail("the top level must refuse another upgrade")
	GameManager.silo_level = 1
	GameManager.silo_capacity = int(GameManager.SILO_CAPACITY[0])
	GameManager.seeds = 1
	arena.try_upgrade_silo(p)
	if GameManager.silo_level != 1:
		_econ_fail("an upgrade must not go through without the seeds")
	# back to the run's starting state
	GameManager.learning_levels = saved_learning
	GameManager.seeds = saved_seeds
	GameManager.seeds_changed.emit(GameManager.seeds)
	if _economy_failed == 0:
		print("[smoke] economy: ok")


## Learning Mode gate (--economy): with Learning Mode on, upgrading the Silo and then a tower each freeze
## time and ask exactly one puzzle. The bots solve it by mashing confirm, and the tree must be unpaused after.
func _gate_step() -> void:
	var p = GameManager.players[0]
	if _gate_stage == 0:
		_gate_fail_base = _economy_failed
		_gate_learning = GameManager.learning_levels.duplicate()
		GameManager.learning_levels = [2, 2]
		GameManager.seeds = 400
		GameManager.seeds_changed.emit(GameManager.seeds)
		_gate_asked = GameManager.math_asked
		_gate_frames = 0
		arena.try_upgrade_silo(p)
		_gate_stage = 1
		return
	_gate_frames += 1
	if _gate_frames > 2400:
		_econ_fail("the Learning Mode gate never finished (stage %d)" % _gate_stage)
		_finish_gate()
	elif _gate_stage == 1 and GameManager.silo_level == 2:
		_gate_assert("Silo upgrade")
		_gate_tower = null
		for t in arena.towers:
			if is_instance_valid(t) and t.alive and t.level < GameManager.MAX_TOWER_LEVEL:
				_gate_tower = t
				break
		if _gate_tower == null:
			var cell := _nearest_free_pad(ArenaMap.SILO_CENTER)
			if cell != Vector2i(-1, -1) and arena.try_build(p, cell, "gatling"):
				_gate_tower = arena.pad_towers[cell]
		if _gate_tower == null:
			_econ_fail("there was no tower to upgrade for the gate check")
			_finish_gate()
			return
		GameManager.seeds = 400
		_gate_asked = GameManager.math_asked
		_gate_level = _gate_tower.level
		_gate_frames = 0
		arena.try_upgrade(p, _gate_tower)
		_gate_stage = 2
	elif _gate_stage == 2 and is_instance_valid(_gate_tower) and _gate_tower.level > _gate_level:
		_gate_assert("tower upgrade")
		_finish_gate()


func _gate_assert(what: String) -> void:
	if GameManager.math_asked != _gate_asked + 1:
		_econ_fail("the %s should ask exactly one puzzle (asked %d, then %d)" % [what, _gate_asked, GameManager.math_asked])
	if get_tree().paused:
		_econ_fail("the tree stayed paused after the %s puzzle" % what)


func _finish_gate() -> void:
	GameManager.learning_levels = _gate_learning
	get_tree().paused = false
	GameManager.silo_level = 1
	GameManager.silo_capacity = int(GameManager.SILO_CAPACITY[0])
	_gate_stage = 3
	if _economy_failed == _gate_fail_base:
		print("[smoke] economy gate: ok (Silo and tower upgrades each asked one puzzle)")


## Picture-first cards (--cards): every card has a picture, arrows and a short name (see CardFaces.validate).
func _cards_check() -> void:
	_cards_done = true
	var problems := CardFaces.validate(CardDB.cards)
	for p in problems:
		push_error("cards: " + str(p))
	if problems.is_empty():
		print("[smoke] cards: ok (%d cards have a picture, arrows and a short name)" % CardDB.cards.size())


## The four mechs (--mechs, ADR-0003; run it with --chassis=tank,drone): the weight ordering, flight, the hover sag,
## the jetpack exclusion, the heat-weight rule, and that each new weapon and alt attack really hurts a rat.
func _mech_fail(msg: String) -> void:
	_mech_failed += 1
	push_error("mechs: " + msg)


func _mechs_step() -> void:
	var tank = GameManager.players[0]
	var drone = GameManager.players[1]
	if _mech_stage == 0:
		_mech_stage = 3
		if tank.chassis != "tank" or drone.chassis != "drone":
			_mech_fail("run this check with --chassis=tank,drone")
			return
		# weight: the speed lost with full cheeks, by mech (ADR-0003: tank < spider < robot < drone)
		var slow := {}
		for id in Chassis.IDS:
			slow[id] = float(Chassis.def(id)["stats"]["pouch_slow"])
		if not (slow["tank"] < slow["wheeler"] and slow["wheeler"] < slow["brawler"] and slow["brawler"] < slow["drone"]):
			_mech_fail("the weight order should be tank < wheeler < brawler < drone, got %s" % [slow])
		for m in [tank, drone]:
			m.pouch.amount = int(m.pouch.capacity())
			if absf(m.pouch.speed_mult() - (1.0 - float(slow[m.chassis]))) > 0.01:
				_mech_fail("%s full-pouch speed should be %.2f, got %.2f" % [m.chassis, 1.0 - float(slow[m.chassis]), m.pouch.speed_mult()])
		# the drone sags lower the fuller it is
		var low: float = drone.visual.hover_height()
		drone.pouch.amount = 0
		var high: float = drone.visual.hover_height()
		tank.pouch.amount = 0
		if low >= high:
			_mech_fail("a full drone should hover lower than an empty one (%.0f vs %.0f)" % [low, high])
		# flight: the drone ignores cliffs and towers, the tank does not
		if not drone.flies() or tank.flies():
			_mech_fail("only the drone should fly")
		if (drone.collision_mask & (GameManager.L_CLIFF | GameManager.L_TOWERS)) != 0:
			_mech_fail("the drone's collision mask must leave out cliffs and towers")
		if (tank.collision_mask & GameManager.L_CLIFF) == 0:
			_mech_fail("the tank must be stopped by cliffs")
		# the jetpack card never reaches the drone, and the filter is the only reason
		var jet: Dictionary = CardDB.get_card("jetpack").duplicate()
		drone.owned_cards.erase("jetpack")
		if CardDB.is_eligible(jet, drone):
			_mech_fail("the jetpack card must not be offered to the drone")
		jet.erase("not_chassis")
		if not CardDB.is_eligible(jet, drone):
			_mech_fail("without not_chassis the jetpack card should be offered (the filter is the only reason)")
		# the spider ball's rule: with heat_weight a full pouch heats the wheel faster
		tank.stats.base["heat_weight"] = 0.8
		tank.wheel.heat = 0.0
		tank.wheel.tick(0.5, true)
		var cool: float = tank.wheel.heat
		tank.wheel.heat = 0.0
		tank.pouch.amount = int(tank.pouch.capacity())
		tank.wheel.tick(0.5, true)
		var hot: float = tank.wheel.heat
		tank.stats.base["heat_weight"] = 0.0
		tank.pouch.amount = 0
		tank.wheel.heat = 0.0
		if hot < cool * 1.6:
			_mech_fail("heat_weight 0.8 should heat a full-pouch wheel about 1.8x faster (%.1f vs %.1f)" % [hot, cool])
		# weapons: gust and stomp act at once; shells and seed bombs need time to land
		tank.global_position = Vector2(470, 110)
		drone.global_position = Vector2(470, 150)
		tank.weapon.aim = Vector2.RIGHT
		drone.weapon.aim = Vector2.RIGHT
		var stomp_rat = arena.spawn_rat("squeaker", tank.global_position + Vector2(20, 0), 30.0, 0.01)
		var gust_rat = arena.spawn_rat("squeaker", drone.global_position + Vector2(30, 0), 30.0, 0.01)
		var shell_rat = arena.spawn_rat("squeaker", tank.global_position + Vector2(95, -30), 30.0, 0.01)
		var bomb_rat = arena.spawn_rat("squeaker", drone.global_position + Vector2(34, 40), 30.0, 0.01)
		_mech_rats = [shell_rat, bomb_rat, stomp_rat, gust_rat]
		_mech_frames = 0
		_mech_stage = 1
		return
	_mech_frames += 1
	# a few frames later the arena's spatial index knows the new rats: stomp and gust act at once, shell and bomb fly
	if _mech_stage == 1 and _mech_frames >= 12:
		var stomp_rat = _mech_rats[2]
		var gust_rat = _mech_rats[3]
		tank.weapon._alt()
		if stomp_rat.hp >= stomp_rat.max_hp or stomp_rat.stun_t <= 0.0:
			_mech_fail("the stomp should hurt and stun a rat beside the tank (hp %.1f/%.1f, stun %.2f)" % [stomp_rat.hp, stomp_rat.max_hp, stomp_rat.stun_t])
		drone.weapon._alt()
		if gust_rat.stun_t <= 0.0 or gust_rat.knock.length() < 1.0:
			_mech_fail("the gust should shove and stun a rat ahead of the drone (stun %.2f, knock %.1f)" % [gust_rat.stun_t, gust_rat.knock.length()])
		tank.weapon._fire()
		drone.weapon.aim = Vector2(0.65, 0.76).normalized()
		drone.weapon._fire()
		_mech_frames = 0
		_mech_stage = 2
		return
	if _mech_stage == 2 and _mech_frames >= 150:
		if _mech_rats[0].hp >= _mech_rats[0].max_hp:
			_mech_fail("the tank's shell should have damaged the rat it was aimed at")
		if _mech_rats[1].hp >= _mech_rats[1].max_hp:
			_mech_fail("the drone's seed bomb should have damaged the rat below it")
		for r in _mech_rats:
			if is_instance_valid(r) and r.alive:
				r.take_damage(99999.0, r.global_position, 0.0, {"quiet": true})
		_mech_stage = 3
		if _mech_failed == 0:
			print("[smoke] mechs: ok (weight order, flight, hover sag, jetpack filter, heat weight, stomp, gust, shell, seed bomb)")


func _mortar_in_flight() -> bool:
	for s in arena.shots.shots:
		if s.lob and s.kind == "mortar":
			return true
	return false


## How far (px) a mech's body circle sinks into a tower's collider; 0 or less when it is clear.
func _tower_overlap(p, tw) -> float:
	var box := tw.get_node("CollisionShape2D") as CollisionShape2D
	var body := p.get_node("CollisionShape2D") as CollisionShape2D
	var d: Vector2 = (body.global_position - box.global_position).abs() - (box.shape as RectangleShape2D).size * 0.5
	var dist := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)
	return (body.shape as CircleShape2D).radius - dist


## Counts frames where any mech is sunk into a tower (it cannot walk there: a tower was built over
## it), as `embedded_frames` / `episodes` in the summary. A mech still sunk after a second is
## wedged for good, which is an ERROR.
func _count_embedded() -> void:
	var now := false
	for p in GameManager.players:
		if not is_instance_valid(p) or p.flies():
			continue
		for tw in arena.towers:
			if is_instance_valid(tw) and _tower_overlap(p, tw) > 0.5:
				now = true
	if not now:
		_embedded_streak = 0
		return
	_embedded_frames += 1
	_embedded_streak += 1
	if _embedded_streak == 1:
		_embedded_episodes += 1
	elif _embedded_streak == 60:
		push_error("stuck: a mech has been sunk in a tower for a second")


func _hold_build_phase(frames: int) -> void:
	for i in frames:
		arena.build_timer = 30.0
		await get_tree().physics_frame


## Regression for "stuck on a tower" (--stuck). A pilot builds from up to 14px away, inside the
## tower's collider. For every pad, build a tower with the pilot standing at several spots around
## it, then check the mech is clear of the new collider and can walk away. Before the fix, pads with
## a fence or cliff face just behind them left the mech wedged between the tower and that wall.
func _stuck_run() -> void:
	var p = GameManager.players[0]
	var saved_seeds: int = GameManager.seeds
	GameManager.seeds = 99999
	for pl in GameManager.players:
		pl.input.bot_move = Vector2.ZERO
		pl.input.bot_held = {}
	var offsets := [Vector2(0, 0), Vector2(0, 4), Vector2(0, 10), Vector2(0, -4), Vector2(0, -10), Vector2(8, 0), Vector2(-8, 0)]
	for cell: Vector2i in ArenaMap.PADS:
		if arena.pad_towers.has(cell):
			continue
		for off: Vector2 in offsets:
			p.global_position = ArenaMap.cell_center(cell) + off
			p.velocity = Vector2.ZERO
			p.knock = Vector2.ZERO
			await _hold_build_phase(2)
			if p.global_position.distance_to(ArenaMap.cell_center(cell)) >= 14.0:
				continue   # it started inside a cliff and was pushed out of build range
			if not arena.try_build(p, cell, "gatling"):
				push_error("stuck: could not build on pad %s" % [cell])
				continue
			var tw = arena.pad_towers[cell]
			await _hold_build_phase(3)
			var sunk := _tower_overlap(p, tw)
			var can_walk := false
			for k in 8:
				if not p.test_move(p.global_transform, Vector2.from_angle(TAU * k / 8.0) * 3.0):
					can_walk = true
					break
			_stuck_cases += 1
			if sunk > 0.5 or not can_walk:
				_stuck_wedged += 1
				if _stuck_wedged <= 5:
					push_error("stuck: pad %s, pilot %s from its centre: wedged in the tower (sunk %.1fpx, can walk away: %s)" % [cell, off, sunk, can_walk])
			tw.destroy()
			await _hold_build_phase(1)
	p.global_position = ArenaMap.SILO_CENTER + Vector2(-40, 36)
	GameManager.seeds = saved_seeds
	GameManager.seeds_changed.emit(GameManager.seeds)
	arena.build_timer = MainArena.FIRST_BUILD_TIME   # the bots get their usual first build phase
	_stuck_stage = 2


func _finish() -> void:
	if cards_check and not _cards_done:
		push_error("cards: the check did not run")
	if mechs_check and _mech_stage != 3:
		_mech_fail("the check did not finish (stage %d)" % _mech_stage)
	if economy and not _economy_done:
		_econ_fail("the check did not run")
	if economy and _economy_done and _gate_stage != 3:
		_econ_fail("the Learning Mode gate check did not finish (stage %d)" % _gate_stage)
	if lob_free and _lob_stage != 2:
		push_error("lob-free: the check did not complete (stage %d)" % _lob_stage)
	set_physics_process(false)
	Engine.time_scale = 1.0
	if take_shots:
		_shot()
	print("[smoke] DONE phase=%s wave=%d max_wave=%d kills=%d silo=%.0f/%.0f seeds=%d towers=%d enemies=%d cards=%s" % [
		GameManager.phase, GameManager.wave, _max_wave, GameManager.kills, GameManager.silo_hp, GameManager.silo_max_hp,
		GameManager.seeds, arena.towers.size(), arena.enemies.size(), GameManager.owned_cards])
	if stuck and _stuck_stage != 2:
		push_error("stuck: the check did not complete (stage %d)" % _stuck_stage)
	print("[smoke] stuck: cases=%d wedged=%d embedded_frames=%d episodes=%d" % [_stuck_cases, _stuck_wedged, _embedded_frames, _embedded_episodes])
	print("[smoke] jetpack hops=%d math_stars=%d asked=%d" % [_hops, GameManager.math_stars, GameManager.math_asked])
	print("[smoke] silo level=%d capacity=%d banked_total=%d" % [GameManager.silo_level, GameManager.silo_capacity, GameManager.seeds_banked_total])
	for p in GameManager.players:
		print("[smoke] P%d %s hp=%.0f/%.0f pouch=%d heat=%.0f cards=%s" % [p.player_id, p.chassis, p.hp, p.max_hp(), p.pouch.amount, p.wheel.heat, p.owned_cards])
	get_tree().quit()
