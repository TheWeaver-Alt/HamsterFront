extends Node
## Automated playtest: two bot pilots defend the Silo through several waves, building towers,
## banking/cramming seeds, spitting, sprinting into overheat and drafting cards.
## Usage:
##   godot --path . res://tools/SmokeTest.tscn -- --waves=4 --speed=3 [--shots] [--spawn-all]
## Prints a summary; screenshots go to res://screenshots/ when --shots is given (needs a GPU/Xvfb).

const ArenaScene := preload("res://scenes/MainArena.tscn")

var arena = null
var waves_target := 3
var speed := 3.0
var take_shots := false
var spawn_all := false
var stress := 0
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
	_drive_bots(delta)
	if stress > 0 and frame == 60:
		for k in stress:
			var b: Vector2i = ArenaMap.BURROWS[k % ArenaMap.BURROWS.size()]
			arena.spawn_rat("squeaker", ArenaMap.cell_center(b) + Vector2(randf_range(-6, 6), randf_range(-6, 6)), 3.0, 1.0)
	if stress > 0 and frame > 60 and frame % 30 == 0:
		_perf_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		if _perf_samples.size() % 10 == 0:
			print("[smoke] stress enemies=%d physics_ms=%.2f fps=%d particles_shots=%d" % [arena.enemies.size(), _perf_samples[-1], Engine.get_frames_per_second(), arena.shots.shots.size()])
	if spawn_all and frame == 90:
		for k in ["squeaker", "jezzail", "monk", "roomba", "ogre"]:
			arena.spawn_rat(k, ArenaMap.cell_center(ArenaMap.BURROWS[0]) + Vector2(randf_range(-6, 6), 0), 1.0, 1.0)
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
		if GameManager.phase == "draft":
			# mash confirm on alternate frames so the draft UI sees presses
			held["confirm"] = frame % 6 < 3
			if frame % 40 == 0:
				held["right"] = true
		else:
			# build phase: walk to free pads and build
			if GameManager.phase == "build" and _built < 10:
				var pad := _nearest_free_pad(p.global_position)
				if pad != Vector2i(-1, -1):
					var dest := ArenaMap.cell_center(pad)
					move = (dest - p.global_position).normalized() if p.global_position.distance_to(dest) > 4.0 else Vector2.ZERO
					if p.global_position.distance_to(dest) < 10.0 and frame % 20 == 0:
						p.selected_tower = (_built + i) % 5
						held["build"] = true
						_built += 1
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
			if int(_bot_t * 0.5 + i) % 3 == 0:
				held["sprint"] = true
			if p.wheel.heat > 70.0 and frame % 50 == 0 and randf() < 0.5:
				held["vent"] = true
			if p.pouch.amount > 20 and frame % 600 == 300 + i:
				held["spit"] = true
			if GameManager.phase == "build" and _built >= 6 and frame % 30 == 0:
				held["ready"] = true
		inp.bot_move = move
		inp.bot_held = held
		i += 1


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


func _finish() -> void:
	set_physics_process(false)
	Engine.time_scale = 1.0
	if take_shots:
		_shot()
	print("[smoke] DONE phase=%s wave=%d max_wave=%d kills=%d silo=%.0f/%.0f seeds=%d towers=%d enemies=%d cards=%s" % [
		GameManager.phase, GameManager.wave, _max_wave, GameManager.kills, GameManager.silo_hp, GameManager.silo_max_hp,
		GameManager.seeds, arena.towers.size(), arena.enemies.size(), GameManager.owned_cards])
	for p in GameManager.players:
		print("[smoke] P%d %s hp=%.0f/%.0f pouch=%d heat=%.0f cards=%s" % [p.player_id, p.chassis, p.hp, p.max_hp(), p.pouch.amount, p.wheel.heat, p.owned_cards])
	get_tree().quit()
