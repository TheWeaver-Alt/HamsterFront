class_name MainArena
extends Node2D
## The Backyard. Builds the map, owns the entity registries + enemy spatial hash, runs the
## build -> wave -> card-draft loop, and handles co-op synergy effects.

const MechScene := preload("res://scenes/MechPlayer.tscn")
const RatScene := preload("res://scenes/RatEnemy.tscn")
const TowerScene := preload("res://scenes/TowerBase.tscn")

const HASH := 32
const FIRST_BUILD_TIME := 25.0
const BUILD_TIME := 15.0
const TerrainArt := preload("res://scripts/art/TerrainArt.gd")

@onready var ground: TileMapLayer = $Ground
@onready var hazards: HazardManager = $Hazards
@onready var seeds: SeedManager = $Seeds
@onready var world: Node2D = $World
@onready var shots: ShotManager = $Shots
@onready var fx: FxManager = $Fx
@onready var barks: Node2D = $Barks
@onready var camera: Camera2D = $Camera2D
@onready var spawner = $WaveSpawner
@onready var hud = $HUDLayer/HUD
@onready var draft_ui = $DraftLayer/CardDraftUI
@onready var flash_rect: ColorRect = $OverlayLayer/Flash
@onready var pause_menu = $OverlayLayer/PauseMenu
@onready var game_over_ui = $OverlayLayer/GameOver
@onready var tether: Node2D = $Tether
@onready var burrow_fx: Node2D = $BurrowFx

var map: ArenaMap
var enemies: Array = []
var towers: Array = []
var pad_towers: Dictionary = {}
var silo_node = null   # Silo.gd (StaticBody2D)
var build_timer := 0.0
var boss = null
var hallucination: CanvasLayer = null
var math_quiz = null      # Learning Mode quiz (scripts/ui/MathQuiz.gd), drawn above the card draft

var _grid: Dictionary = {}
var _burrow_warn: Dictionary = {}     # Vector2i -> seconds left
var _silo_hit_sfx_t := 0.0
var _low_silo_stage := 0
var _alarm_t := 0.0
var _tether_tick := 0.0
var _clear_pending := false


func _ready() -> void:
	process_priority = -100
	process_physics_priority = -100
	GameManager.arena = self
	GameManager.new_run()
	JuiceManager.register_world(camera, barks, flash_rect)
	map = ArenaMap.new()
	map.build()
	for p in map.validate():
		push_error(p)
	hazards.arena = self
	seeds.arena = self
	shots.arena = self
	spawner.arena = self
	_build_tiles()
	_build_colliders()
	_build_props()
	_spawn_players()
	_build_quiz_layer()
	_build_ambient()
	tether.draw.connect(_draw_tether)
	burrow_fx.draw.connect(_draw_burrows)
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.silo_changed.connect(_on_silo_changed)
	draft_ui.finished.connect(_on_draft_finished)
	build_timer = FIRST_BUILD_TIME
	GameManager.set_phase("build")
	GameManager.say("DEFEND THE GREAT SILO!", "BUILD TOWERS ON THE WOODEN PADS", Color8(255, 214, 64))
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if _has_kbm_player() else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	JuiceManager.unregister_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameManager.arena == self:
		GameManager.arena = null
	Engine.time_scale = 1.0


func _has_kbm_player() -> bool:
	for i in GameManager.num_players:
		if GameManager.player_devices[i] == "kbm":
			return true
	return false


# ------------------------------------------------------------------ construction

func _build_tiles() -> void:
	# Compose every cell's 3/4-view tile from its neighbours, dedupe into one atlas.
	var keys: Array = []
	var key_index: Dictionary = {}
	var cell_keys: Array = []
	for y in ArenaMap.H:
		for x in ArenaMap.W:
			var k: String = TerrainArt.cell_key(map, x, y)
			if not key_index.has(k):
				key_index[k] = keys.size()
				keys.append([k, x, y])
			cell_keys.append(key_index[k])
	var cols := 32
	var rows := int(ceil(float(keys.size()) / cols))
	var atlas := Image.create(16 * cols, 16 * rows, false, Image.FORMAT_RGBA8)
	for i in keys.size():
		var img: Image = TerrainArt.cell_image(map, keys[i][1], keys[i][2], keys[i][0])
		atlas.blit_rect(img, Rect2i(0, 0, 16, 16), Vector2i((i % cols) * 16, int(i / cols) * 16))
	var tex := ImageTexture.create_from_image(atlas)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	for i in keys.size():
		src.create_tile(Vector2i(i % cols, int(i / cols)))
	ts.add_source(src, 0)
	ground.tile_set = ts
	for y in ArenaMap.H:
		for x in ArenaMap.W:
			var ti: int = cell_keys[y * ArenaMap.W + x]
			ground.set_cell(Vector2i(x, y), 0, Vector2i(ti % cols, int(ti / cols)))


func _build_colliders() -> void:
	# fence
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = GameManager.L_WORLD
	walls.collision_mask = 0
	var W := ArenaMap.W * 16.0
	var H := ArenaMap.H * 16.0
	for r in [Rect2(0, 0, W, 16), Rect2(0, H - 16, W, 16), Rect2(0, 0, 16, H), Rect2(W - 16, 0, 16, H)]:
		_add_rect(walls, r)
	add_child(walls)
	# pads block rats only
	var pads := StaticBody2D.new()
	pads.name = "PadBlockers"
	pads.collision_layer = GameManager.L_RAT_BLOCK
	pads.collision_mask = 0
	for p in ArenaMap.PADS:
		_add_rect(pads, Rect2(ArenaMap.cell_center(p) - Vector2(7, 7), Vector2(14, 14)))
	add_child(pads)
	# cliffs: faces are solid, and plateau edges (without a ramp) are thin walls
	var cliffs := StaticBody2D.new()
	cliffs.name = "Cliffs"
	cliffs.collision_layer = GameManager.L_RAT_BLOCK | GameManager.L_CLIFF
	cliffs.collision_mask = 0
	for y in ArenaMap.H:
		var run_start := -1
		for x in ArenaMap.W + 1:
			var face := x < ArenaMap.W and map.cell_type(Vector2i(x, y)) == ArenaMap.Cell.FACE
			if face and run_start < 0:
				run_start = x
			elif not face and run_start >= 0:
				_add_rect(cliffs, Rect2(run_start * 16, y * 16, (x - run_start) * 16, 16))
				run_start = -1
	for y in ArenaMap.H:
		for x in ArenaMap.W:
			var c := Vector2i(x, y)
			if map.cell_elev(c) != 1 or map.cell_type(c) == ArenaMap.Cell.FACE or map.cell_type(c) == ArenaMap.Cell.WALL:
				continue
			# west / east / north / south drops to low ground
			if _is_drop(Vector2i(x - 1, y)):
				_add_rect(cliffs, Rect2(x * 16 - 2, y * 16, 4, 16))
			if _is_drop(Vector2i(x + 1, y)):
				_add_rect(cliffs, Rect2(x * 16 + 14, y * 16, 4, 16))
			if _is_drop(Vector2i(x, y - 1)):
				_add_rect(cliffs, Rect2(x * 16, y * 16 - 2, 16, 4))
			if _is_drop(Vector2i(x, y + 1)):
				_add_rect(cliffs, Rect2(x * 16, y * 16 + 14, 16, 4))
	add_child(cliffs)


func _is_drop(c: Vector2i) -> bool:
	var t := map.cell_type(c)
	return map.cell_elev(c) == 0 and t != ArenaMap.Cell.WALL


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)


func _build_props() -> void:
	for o in ArenaMap.OBSTACLES:
		var body := StaticBody2D.new()
		body.collision_layer = GameManager.L_WORLD
		body.collision_mask = 0
		var c: Vector2i = o["cell"]
		body.position = ArenaMap.cell_center(c) + Vector2(0, 6)
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(14, 12)
		cs.shape = sh
		cs.position = Vector2(0, -6)
		body.add_child(cs)
		var spr := Sprite2D.new()
		spr.texture = PixelArt.tex("obstacle_" + String(o["kind"]))
		spr.centered = false
		spr.offset = Vector2(-spr.texture.get_width() / 2, -spr.texture.get_height() + 2)
		body.add_child(spr)
		world.add_child(body)
	silo_node = StaticBody2D.new()
	silo_node.name = "Silo"
	silo_node.set_script(load("res://scripts/arena/Silo.gd"))
	silo_node.position = ArenaMap.SILO_CENTER + Vector2(0, 22)
	world.add_child(silo_node)


## Ambient life (swaying grass, critters, cloud shadows, lighting) from scripts/systems/AmbientLayer.gd.
## The node is added under the arena; it may create its own children at any z_index and
## receives setup(arena) before entering the tree.
var ambient = null


func _build_ambient() -> void:
	var path := "res://scripts/systems/AmbientLayer.gd"
	if not ResourceLoader.exists(path):
		return
	ambient = Node2D.new()
	ambient.name = "Ambient"
	ambient.set_script(load(path))
	if ambient.has_method("setup"):
		ambient.setup(self)
	add_child(ambient)


func _build_quiz_layer() -> void:
	var path := "res://scripts/ui/MathQuiz.gd"
	if not ResourceLoader.exists(path):
		return
	var layer := CanvasLayer.new()
	layer.name = "QuizLayer"
	layer.layer = 25
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var quiz := Control.new()
	quiz.name = "MathQuiz"
	quiz.set_script(load(path))
	quiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(quiz)
	math_quiz = quiz


func _spawn_players() -> void:
	GameManager.players.clear()
	var starts := [ArenaMap.SILO_CENTER + Vector2(-40, 36), ArenaMap.SILO_CENTER + Vector2(40, 36)]
	for i in GameManager.num_players:
		var m = MechScene.instantiate()
		var chassis := "brawler" if i == 0 else "wheeler"
		if GameManager.num_players == 1:
			chassis = GameManager.p1_chassis
		m.setup(i + 1, chassis, GameManager.player_devices[i])
		m.position = starts[i]
		world.add_child(m)
		GameManager.players.append(m)


# ------------------------------------------------------------------ registries / queries

func spawn_rat(kind: String, pos: Vector2, hp_mult: float = 1.0, spd_mult: float = 1.0):
	var r = RatScene.instantiate()
	r.setup(kind, hp_mult, spd_mult)
	r.position = pos
	r.spawn_t = 0.5   # long enough to see the crawl-out animation
	world.add_child(r)
	register_enemy(r)
	if r.is_boss:
		boss = r
	return r


func register_enemy(e) -> void:
	enemies.append(e)


func unregister_enemy(e) -> void:
	enemies.erase(e)
	if e == boss:
		boss = null
		for o in enemies:
			if is_instance_valid(o) and o.alive and o.is_boss:
				boss = o
				break


func _rebuild_grid() -> void:
	_grid.clear()
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var key := Vector2i(floori(e.global_position.x / HASH), floori(e.global_position.y / HASH))
		if _grid.has(key):
			_grid[key].append(e)
		else:
			_grid[key] = [e]


## Enemies whose centre lies within r (+ their own radius) of pos.
func enemies_in_radius(pos: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := floori((pos.x - r - 12.0) / HASH)
	var x1 := floori((pos.x + r + 12.0) / HASH)
	var y0 := floori((pos.y - r - 12.0) / HASH)
	var y1 := floori((pos.y + r + 12.0) / HASH)
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var bucket = _grid.get(Vector2i(gx, gy))
			if bucket == null:
				continue
			for e in bucket:
				if not is_instance_valid(e) or not e.alive:
					continue
				var rr: float = r + e.radius
				if pos.distance_squared_to(e.global_position) <= rr * rr:
					out.append(e)
	return out


func nearest_enemy(pos: Vector2, r: float):
	var best = null
	var bd := INF
	for e in enemies_in_radius(pos, r):
		if e.spawn_t > 0.0:
			continue
		var d := pos.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func free_pad_near(pos: Vector2, r: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := r
	for p in ArenaMap.PADS:
		if pad_towers.has(p):
			continue
		var d := pos.distance_to(ArenaMap.cell_center(p))
		if d < bd:
			bd = d
			best = p
	return best


func tower_near(pos: Vector2, r: float):
	var best = null
	var bd := r
	for t in towers:
		if not is_instance_valid(t) or not t.alive:
			continue
		var d := pos.distance_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func taunting_decoy(pos: Vector2):
	var best = null
	var bd := INF
	for t in towers:
		if not is_instance_valid(t) or not t.alive or t.kind != "decoy":
			continue
		var d := pos.distance_to(t.global_position)
		if d < t.taunt_radius() and d < bd:
			bd = d
			best = t
	return best


# ------------------------------------------------------------------ building

func try_build(player, cell: Vector2i, kind: String) -> bool:
	if pad_towers.has(cell):
		return false
	var cost := GameManager.tower_cost(kind)
	if not GameManager.spend(cost):
		Sfx.play("deny")
		fx.float_text(ArenaMap.cell_center(cell) + Vector2(0, -16), "NEED %d SEEDS" % cost, PixelArt.C["r"], 0.9, 8.0)
		return false
	var t = TowerScene.instantiate()
	t.setup(kind, cell)
	world.add_child(t)
	towers.append(t)
	pad_towers[cell] = t
	fx.dust(t.global_position, 10)
	fx.burst(t.global_position, 12, [PixelArt.C["t"], PixelArt.C["T"], PixelArt.C["y"]], 30, 100, 0.2, 0.5, 1.0, 120.0)
	fx.float_text(t.global_position + Vector2(0, -20), "-%d" % cost, PixelArt.C["y"], 0.8, 10.0)
	JuiceManager.add_trauma(0.15)
	Sfx.play("build")
	return true


func try_upgrade(player, t) -> bool:
	if not is_instance_valid(t) or t.level >= GameManager.MAX_TOWER_LEVEL:
		Sfx.play("deny", 1.0, -6.0)
		return false
	var cost := GameManager.tower_cost(t.kind, t.level + 1)
	if not GameManager.can_afford(cost):
		Sfx.play("deny")
		fx.float_text(t.global_position + Vector2(0, -16), "NEED %d SEEDS" % cost, PixelArt.C["r"], 0.9, 8.0)
		return false
	# Learning Mode: solve a puzzle to activate the upgrade (time freezes meanwhile)
	var info: Dictionary = GameManager.TOWER_INFO[t.kind]
	if not await _solve_gate(player, "UPGRADE %s TO LV%d" % [info["short"], t.level + 1]):
		return false
	if GameManager.learning_level(player) > 0:
		if not is_instance_valid(t) or not t.alive or t.level >= GameManager.MAX_TOWER_LEVEL:
			return false
		cost = GameManager.tower_cost(t.kind, t.level + 1)
	if not GameManager.spend(cost):
		Sfx.play("deny")
		return false
	t.upgrade()
	Sfx.play("upgrade")
	return true


## Learning Mode gate: freezes time until this player solves a puzzle. Returns false when another
## quiz or the pause menu is already up. Without Learning Mode it returns true at once.
func _solve_gate(player, reason: String) -> bool:
	var lvl := GameManager.learning_level(player)
	if lvl <= 0 or math_quiz == null:
		return true
	if math_quiz.active or get_tree().paused:
		return false
	get_tree().paused = true
	math_quiz.ask(player, lvl, reason)
	while true:
		var res: Array = await math_quiz.solved
		if res.size() > 0 and res[0] == player:
			break
	if GameManager.phase != "gameover" and not pause_menu.visible:
		get_tree().paused = false
	if is_instance_valid(player):
		player.input.consume()
	return true


## Spends seeds to raise the Silo's store capacity (ADR-0002).
func try_upgrade_silo(player) -> bool:
	if GameManager.silo_maxed():
		Sfx.play("deny", 1.0, -6.0)
		return false
	var cost := GameManager.silo_upgrade_cost()
	if not GameManager.can_afford(cost):
		Sfx.play("deny")
		fx.float_text(ArenaMap.SILO_CENTER + Vector2(0, -48), "NEED %d SEEDS" % cost, PixelArt.C["r"], 0.9, 8.0)
		return false
	if not await _solve_gate(player, "UPGRADE SILO TO LV%d" % (GameManager.silo_level + 1)):
		return false
	var before := GameManager.silo_capacity
	if GameManager.phase == "gameover" or not GameManager.upgrade_silo():
		Sfx.play("deny")
		return false
	silo_node.upgraded()
	Sfx.play("upgrade")
	JuiceManager.add_trauma(0.2)
	GameManager.say("SILO LV%d" % GameManager.silo_level, "+%d SEED CAPACITY" % (GameManager.silo_capacity - before), Color8(255, 214, 64))
	return true


func on_tower_destroyed(t) -> void:
	towers.erase(t)
	if pad_towers.get(t.cell) == t:
		pad_towers.erase(t.cell)
	var rubble := Sprite2D.new()
	rubble.texture = PixelArt.tex("tower_rubble")
	rubble.position = t.global_position + Vector2(0, -2)
	rubble.modulate = Color(1, 1, 1, 0.8)
	hazards.add_child(rubble)
	var tw := rubble.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(rubble, "modulate:a", 0.0, 2.0)
	tw.tween_callback(rubble.queue_free)


# ------------------------------------------------------------------ events

func on_silo_hit(pos: Vector2) -> void:
	silo_node.hit()
	_silo_hit_sfx_t -= 0.0
	if _silo_hit_sfx_t <= 0.0:
		_silo_hit_sfx_t = 0.18
		Sfx.play_var("silo_hit", 1.0, 0.15, -8.0)
		fx.seed_shells(pos + Vector2(0, -6), 2)


func _on_silo_changed(hp: float, max_hp: float) -> void:
	var frac := hp / maxf(1.0, max_hp)
	if frac < 0.5 and _low_silo_stage < 1:
		_low_silo_stage = 1
		_bark_random_player("They're touching the good seeds! THE STRIPED ONES!")
		GameManager.say("SILO UNDER ATTACK!", "", Color8(255, 90, 60))
	elif frac < 0.25 and _low_silo_stage < 2:
		_low_silo_stage = 2
		_bark_random_player("They're touching the good seeds! THE STRIPED ONES!")
		GameManager.say("SILO CRITICAL!", "THE STRIPED ONES ARE IN DANGER", Color8(255, 64, 40))


func _bark_random_player(text: String) -> void:
	var living := GameManager.living_players()
	if living.size() > 0:
		JuiceManager.bark(living[randi() % living.size()], text, "hamster", true)


func on_player_vented(p) -> void:
	if not GameManager.gstats.has_flag("blood_brothers"):
		return
	for o in GameManager.players:
		if o != p and is_instance_valid(o) and not o.downed:
			o.blood_brothers_t = 6.0
			fx.float_text(o.global_position + Vector2(0, -44), "BLOOD BROTHERS!", PixelArt.C["r"], 1.0, 10.0)


func on_card_applied(card: Dictionary, _player) -> void:
	for t in towers:
		if is_instance_valid(t):
			t.refresh_stats()
	_update_hallucination()


func burrow_warn(cell: Vector2i, dur: float) -> void:
	_burrow_warn[cell] = dur
	fx.dust(ArenaMap.cell_center(cell), 6)


func _update_hallucination() -> void:
	var any := false
	for p in GameManager.players:
		if is_instance_valid(p) and p.stats.has_flag("forbidden_brie"):
			any = true
	if any and hallucination == null:
		var path := "res://scripts/ui/HallucinationOverlay.gd"
		if ResourceLoader.exists(path):
			hallucination = CanvasLayer.new()
			hallucination.layer = 5
			hallucination.set_script(load(path))
			add_child(hallucination)


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	_rebuild_grid()
	_silo_hit_sfx_t = maxf(0.0, _silo_hit_sfx_t - delta)
	for c in _burrow_warn.keys():
		_burrow_warn[c] -= delta
		if randf() < 0.2:
			fx.warp_sparks(ArenaMap.cell_center(c), 1)
		if _burrow_warn[c] <= -0.6:
			_burrow_warn.erase(c)
	burrow_fx.queue_redraw()
	match GameManager.phase:
		"build":
			build_timer -= delta
			var all_ready := true
			for p in GameManager.players:
				if is_instance_valid(p) and not p.ready_pressed:
					all_ready = false
			if build_timer <= 0.0 or (all_ready and GameManager.players.size() > 0):
				_start_wave()
		"wave":
			if spawner.is_done() and enemies.is_empty() and not _clear_pending:
				_clear_pending = true
				_wave_cleared()
	_process_synergies(delta)
	if GameManager.silo_hp / GameManager.silo_max_hp < 0.25 and GameManager.phase == "wave":
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = 3.0
			Sfx.play("alarm", 1.0, -6.0)
	tether.queue_redraw()


func _start_wave() -> void:
	for p in GameManager.players:
		p.ready_pressed = false
	GameManager.wave += 1
	GameManager.wave_changed.emit(GameManager.wave)
	GameManager.set_phase("wave")
	_clear_pending = false
	spawner.start_wave(GameManager.wave)
	Sfx.play("wave_start")
	JuiceManager.add_trauma(0.3)
	var sub := "THE UNDER-SCURRIERS ATTACK"
	if GameManager.wave % 5 == 0:
		sub = "SOMETHING BIG IS COMING..."
	GameManager.say("WAVE %d" % GameManager.wave, sub, Color8(170, 255, 100))


func _wave_cleared() -> void:
	Sfx.play("wave_clear")
	var bonus := 20 + GameManager.wave * 6
	var got := GameManager.add_seeds(bonus)
	var bonus_text := "+%d WAVE BONUS" % got
	if got < bonus:
		bonus_text += " (SILO FULL)"
	fx.float_text(ArenaMap.SILO_CENTER + Vector2(0, -48), bonus_text, PixelArt.C["y"], 1.6, 18.0)
	GameManager.say("WAVE %d CLEARED!" % GameManager.wave, "THE VENDING MACHINE APPROACHES", Color8(255, 214, 64))
	var repair := GameManager.gstats.g("tower_wave_repair", 0.0)
	for t in towers:
		if is_instance_valid(t) and repair > 0.0:
			t.repair(repair)
	for p in GameManager.players:
		if is_instance_valid(p):
			if p.downed:
				p._revive(0.5, null)
			else:
				p.heal(p.max_hp() * 0.25)
	await get_tree().create_timer(2.2).timeout
	if GameManager.phase == "gameover":
		return
	_open_draft()


func _open_draft() -> void:
	GameManager.set_phase("draft")
	shots.clear_all()
	get_tree().paused = true
	draft_ui.open(GameManager.players)


func _on_draft_finished() -> void:
	get_tree().paused = false
	build_timer = BUILD_TIME
	GameManager.set_phase("build")
	for p in GameManager.players:
		if is_instance_valid(p):
			p.input.consume()
			p.ready_pressed = false
	var next := GameManager.wave + 1
	var nb: int = spawner.open_burrows(next)
	if nb > spawner.open_burrows(GameManager.wave):
		GameManager.say("NEW BURROW DUG!", "WATCH THE EDGES OF THE YARD", Color8(170, 255, 100))
	else:
		GameManager.say("BUILD PHASE", "WAVE %d INCOMING" % next, Color8(255, 214, 64))


func _process_synergies(delta: float) -> void:
	var living := GameManager.living_players()
	var pair := living.size() >= 2
	var a = living[0] if pair else null
	var b = living[1] if pair else null
	# Buddy System
	var buddy := false
	if pair and GameManager.gstats.has_flag("buddy_system") and a.global_position.distance_to(b.global_position) < 64.0:
		buddy = true
		a.heal(2.0 * delta)
		b.heal(2.0 * delta)
	for p in GameManager.players:
		if is_instance_valid(p):
			p.buddy_active = buddy and not p.downed
	# Jumper Cables
	if pair and GameManager.gstats.has_flag("jumper_cables") and a.global_position.distance_to(b.global_position) < 220.0:
		_tether_tick -= delta
		if _tether_tick <= 0.0:
			_tether_tick = 0.1
			var pa: Vector2 = a.global_position + Vector2(0, -12)
			var pb: Vector2 = b.global_position + Vector2(0, -12)
			var mid := (pa + pb) / 2.0
			for e in enemies_in_radius(mid, pa.distance_to(pb) / 2.0 + 8.0):
				if _seg_dist(e.global_position + Vector2(0, -3), pa, pb) < 6.0 + e.radius:
					e.take_damage(30.0 * 0.1, e.global_position, 0.0, {"kind": "cable", "quiet": true, "owner": a})
					if randf() < 0.3:
						fx.sparks(e.global_position + Vector2(0, -4), Color8(150, 220, 255), 2)
			if randf() < 0.5:
				fx.bolt(pa, pb, Color8(150, 220, 255), 0.08, 3.0)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw_tether() -> void:
	if not GameManager.gstats.has_flag("jumper_cables"):
		return
	var living := GameManager.living_players()
	if living.size() < 2:
		return
	var pa: Vector2 = living[0].global_position + Vector2(0, -12)
	var pb: Vector2 = living[1].global_position + Vector2(0, -12)
	var d := pa.distance_to(pb)
	var col := Color8(150, 220, 255) if d < 220.0 else Color(0.6, 0.6, 0.6, 0.4)
	# sagging cable
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var p := pa.lerp(pb, t)
		p.y += sin(t * PI) * maxf(0.0, 30.0 - d * 0.1)
		pts.append(p.round())
	tether.draw_polyline(pts, Color(0.1, 0.06, 0.12, 0.8), 1.0)
	if d < 220.0 and int(Time.get_ticks_msec() / 60) % 2 == 0:
		for i in range(1, 12, 2):
			tether.draw_rect(Rect2(pts[i], Vector2(1, 1)), col)


func _draw_burrows() -> void:
	var tms := Time.get_ticks_msec() * 0.001
	var open_n: int = spawner.open_burrows(maxi(1, GameManager.wave + (1 if GameManager.phase != "wave" else 0)))
	for i in ArenaMap.BURROWS.size():
		var c: Vector2i = ArenaMap.BURROWS[i]
		var p := ArenaMap.cell_center(c) + Vector2(0, 1)
		if i < open_n:
			# glowing eyes in the dark
			if int(tms * 0.7 + i * 1.3) % 3 != 0:
				burrow_fx.draw_rect(Rect2(p + Vector2(-2, -1), Vector2(1, 1)), Color8(170, 255, 100))
				burrow_fx.draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 1)), Color8(170, 255, 100))
		else:
			# boarded-up burrow
			burrow_fx.draw_rect(Rect2(p + Vector2(-6, -3), Vector2(12, 2)), PixelArt.C["b"])
			burrow_fx.draw_rect(Rect2(p + Vector2(-6, 1), Vector2(12, 2)), PixelArt.C["T"])
	for c in _burrow_warn.keys():
		var p := ArenaMap.cell_center(c)
		var a := 0.35 + 0.35 * sin(tms * 18.0)
		PixelArt.draw_disk(burrow_fx, p, 9.0, Color(0.4, 1.0, 0.3, a * 0.5))
		PixelArt.draw_ring(burrow_fx, p, 12.0 + sin(tms * 10.0) * 2.0, Color(0.67, 1.0, 0.4, a))


# ------------------------------------------------------------------ pause / game over

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			for p in GameManager.players:
				if is_instance_valid(p) and p.input.device == "kbm":
					p.input.wheel_steps += 1
	var pause_pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.physical_keycode == KEY_P:
			pause_pressed = true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		pause_pressed = true
	if pause_pressed and GameManager.phase != "draft" and GameManager.phase != "gameover":
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_menu.visible = p
	if p:
		pause_menu.open()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p or not _has_kbm_player() else Input.MOUSE_MODE_HIDDEN


func _on_game_over() -> void:
	Sfx.play("game_over")
	JuiceManager.add_trauma(1.0)
	fx.explosion(ArenaMap.SILO_CENTER, 40.0, "warp")
	seeds.spawn(ArenaMap.SILO_CENTER, 60, 160.0)
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.8, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_over_ui.open()
