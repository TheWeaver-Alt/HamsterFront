extends Node2D
## The Backyard. Owns the grid (TileMapLayer + buildable pads + burrows), the flow
## field, entity registries, the rat spatial hash, and the run's state flow:
## TITLE -> PREP -> WAVE -> DRAFT -> PREP ... -> GAME_OVER.

const MECH_SCENE := preload("res://scenes/MechPlayer.tscn")
const RAT_SCENE := preload("res://scenes/RatEnemy.tscn")
const TOWER_SCENE := preload("res://scenes/TowerBase.tscn")

enum Cell { GROUND, BLOCKED, PAD, BURROW, SILO }
enum Tile { GRASS_A, GRASS_B, FLOWERS, FLAGSTONE, DIRT, PAD, BURROW, HEDGE }

const SILO_CELL := Vector2i(18, 9)
const SILO_SIZE := Vector2i(4, 4)
const HASH_SIZE := 32.0
const MAX_SHELL_PILES := 40
const TOWER_PATH_COST := 14.0

const BURROWS := [
	Vector2i(2, 2), Vector2i(37, 20), Vector2i(37, 2), Vector2i(2, 20),
	Vector2i(20, 1), Vector2i(19, 21), Vector2i(1, 11), Vector2i(38, 11),
]
const OBSTACLES := [
	Vector2i(7, 8), Vector2i(7, 9), Vector2i(32, 13), Vector2i(32, 14),
	Vector2i(13, 17), Vector2i(14, 17), Vector2i(25, 5), Vector2i(26, 5),
	Vector2i(5, 15), Vector2i(34, 7), Vector2i(15, 4), Vector2i(24, 18),
]
const OUTER_PADS := [
	Vector2i(10, 4), Vector2i(11, 4), Vector2i(10, 5), Vector2i(11, 5),
	Vector2i(28, 4), Vector2i(29, 4), Vector2i(28, 5), Vector2i(29, 5),
	Vector2i(10, 17), Vector2i(11, 17), Vector2i(10, 18), Vector2i(11, 18),
	Vector2i(28, 17), Vector2i(29, 17), Vector2i(28, 18), Vector2i(29, 18),
	Vector2i(5, 11), Vector2i(34, 11), Vector2i(19, 4), Vector2i(20, 4),
	Vector2i(19, 18), Vector2i(20, 18), Vector2i(12, 11), Vector2i(27, 11),
]

@onready var ground: TileMapLayer = $Ground
@onready var ground_fx: Node2D = $GroundFX
@onready var entities: Node2D = $Entities
@onready var projectiles_node: Node2D = $Projectiles
@onready var fx_layer: FXLayer = $FX
@onready var glow_layer: FXLayer = $GlowFX
@onready var overlay: Node2D = $Overlay
@onready var camera: Camera2D = $Camera2D
@onready var hud: HUD = $UI/HUD
@onready var draft: CardDraft = $UI/CardDraft
@onready var spawner: WaveSpawner = $WaveSpawner

var cells := PackedInt32Array()
var cost_grid := PackedFloat32Array()
var flow := FlowField.new()
var burrows: Array = []
var pads: Array = []
var towers: Dictionary = {}
var rats: Array = []
var mechs: Array = []
var silo: Silo = null
var _hash: Dictionary = {}
var _flow_dirty := false
var _game_over_ms := 0
var _cable_tick := 0.0
var _stall_t := 0.0


func _ready() -> void:
	GameManager.arena = self
	_build_map()
	_build_tiles()
	_build_colliders()
	silo = Silo.new()
	silo.position = Vector2(SILO_CELL * Defs.CELL) + Vector2(SILO_SIZE * Defs.CELL) / 2.0
	entities.add_child(silo)
	_recompute_flow()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add_mat
	JuiceManager.register(camera, fx_layer, glow_layer, overlay)
	draft.finished.connect(_on_draft_finished)
	GameManager.silo_destroyed.connect(_on_silo_destroyed)
	for pid in [1, 2]:
		var m: MechPlayer = MECH_SCENE.instantiate()
		m.player_id = pid
		m.position = silo.position + Vector2(-44.0 if pid == 1 else 44.0, 44.0)
		entities.add_child(m)
		mechs.append(m)
		m.set_active(false)
	if not GameManager.quick_restart_players.is_empty():
		var ids: Array = GameManager.quick_restart_players.duplicate()
		GameManager.quick_restart_players.clear()
		for pid in ids:
			_join(int(pid), false)
		_begin_run()
	else:
		GameManager.set_state(GameManager.State.TITLE)
	_update_mouse_mode()


# --- Grid & tiles ------------------------------------------------------------------

func _idx(c: Vector2i) -> int:
	return c.y * Defs.GRID_W + c.x


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < Defs.GRID_W and c.y < Defs.GRID_H


func cell_type(c: Vector2i) -> int:
	if not in_grid(c):
		return Cell.BLOCKED
	return cells[_idx(c)]


func _set_cell(c: Vector2i, t: int) -> void:
	if in_grid(c):
		cells[_idx(c)] = t


func _build_map() -> void:
	cells.resize(Defs.GRID_W * Defs.GRID_H)
	cells.fill(Cell.GROUND)
	for x in Defs.GRID_W:
		_set_cell(Vector2i(x, 0), Cell.BLOCKED)
		_set_cell(Vector2i(x, Defs.GRID_H - 1), Cell.BLOCKED)
	for y in Defs.GRID_H:
		_set_cell(Vector2i(0, y), Cell.BLOCKED)
		_set_cell(Vector2i(Defs.GRID_W - 1, y), Cell.BLOCKED)
	for x in SILO_SIZE.x:
		for y in SILO_SIZE.y:
			_set_cell(SILO_CELL + Vector2i(x, y), Cell.SILO)
	for c in OBSTACLES:
		_set_cell(c, Cell.BLOCKED)
	burrows.clear()
	for c in BURROWS:
		_set_cell(c, Cell.BURROW)
		burrows.append(c)
	pads.clear()
	# Inner ring two cells out from the Silo, with four open corridors.
	var r0 := SILO_CELL - Vector2i(2, 2)
	var r1 := SILO_CELL + SILO_SIZE + Vector2i(1, 1)
	for x in range(r0.x, r1.x + 1):
		for y in range(r0.y, r1.y + 1):
			var on_ring := x == r0.x or x == r1.x or y == r0.y or y == r1.y
			if not on_ring:
				continue
			var mid_x := x == SILO_CELL.x + 1 or x == SILO_CELL.x + 2
			var mid_y := y == SILO_CELL.y + 1 or y == SILO_CELL.y + 2
			if mid_x or mid_y:
				continue
			_add_pad(Vector2i(x, y))
	for c in OUTER_PADS:
		_add_pad(c)


func _add_pad(c: Vector2i) -> void:
	if cell_type(c) == Cell.GROUND:
		_set_cell(c, Cell.PAD)
		pads.append(c)


func _build_tiles() -> void:
	var img := Image.create_empty(Defs.CELL * 8, Defs.CELL, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	_paint_grass(img, Tile.GRASS_A, Pal.GRASS_A, rng, false)
	_paint_grass(img, Tile.GRASS_B, Pal.GRASS_B, rng, false)
	_paint_grass(img, Tile.FLOWERS, Pal.GRASS_A, rng, true)
	_paint_flagstone(img, Tile.FLAGSTONE, rng)
	_paint_dirt(img, Tile.DIRT, rng)
	_paint_pad(img, Tile.PAD)
	_paint_flagstone(img, Tile.BURROW, rng)
	_paint_burrow(img, Tile.BURROW)
	_paint_hedge(img, Tile.HEDGE, rng)
	var tex := ImageTexture.create_from_image(img)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Defs.CELL, Defs.CELL)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(Defs.CELL, Defs.CELL)
	for i in 8:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	ground.tile_set = ts
	var deco := RandomNumberGenerator.new()
	deco.seed = 42
	for y in Defs.GRID_H:
		for x in Defs.GRID_W:
			var c := Vector2i(x, y)
			var tile := Tile.GRASS_A
			match cell_type(c):
				Cell.BLOCKED:
					tile = Tile.HEDGE
				Cell.PAD:
					tile = Tile.PAD
				Cell.BURROW:
					tile = Tile.BURROW
				Cell.SILO:
					tile = Tile.FLAGSTONE
				_:
					if _near_burrow(c) or _near_silo(c):
						tile = Tile.FLAGSTONE
					else:
						var roll := deco.randf()
						if roll < 0.08:
							tile = Tile.FLOWERS
						elif roll < 0.12:
							tile = Tile.DIRT
						elif roll < 0.55:
							tile = Tile.GRASS_B
			ground.set_cell(c, 0, Vector2i(tile, 0))


func _near_burrow(c: Vector2i) -> bool:
	for b in burrows:
		var bc: Vector2i = b
		if absi(bc.x - c.x) <= 1 and absi(bc.y - c.y) <= 1:
			return true
	return false


func _near_silo(c: Vector2i) -> bool:
	return c.x >= SILO_CELL.x - 1 and c.x <= SILO_CELL.x + SILO_SIZE.x and c.y >= SILO_CELL.y - 1 and c.y <= SILO_CELL.y + SILO_SIZE.y


func _px(img: Image, tile: int, x: int, y: int, col: Color) -> void:
	img.set_pixel(tile * Defs.CELL + clampi(x, 0, 15), clampi(y, 0, 15), col)


func _fill(img: Image, tile: int, col: Color) -> void:
	for y in Defs.CELL:
		for x in Defs.CELL:
			_px(img, tile, x, y, col)


func _paint_grass(img: Image, tile: int, base: Color, rng: RandomNumberGenerator, flowers: bool) -> void:
	_fill(img, tile, base)
	for i in 22:
		_px(img, tile, rng.randi_range(0, 15), rng.randi_range(0, 15), Pal.GRASS_DARK)
	for i in 10:
		var x := rng.randi_range(0, 15)
		var y := rng.randi_range(1, 15)
		_px(img, tile, x, y, Pal.GRASS_LIGHT)
		_px(img, tile, x, y - 1, Pal.GRASS_LIGHT)
	if flowers:
		for i in 3:
			var x := rng.randi_range(2, 13)
			var y := rng.randi_range(2, 13)
			var petal := Pal.SUNFLOWER if i % 2 == 0 else Pal.WHITE
			_px(img, tile, x - 1, y, petal)
			_px(img, tile, x + 1, y, petal)
			_px(img, tile, x, y - 1, petal)
			_px(img, tile, x, y + 1, petal)
			_px(img, tile, x, y, Pal.SUNFLOWER_DARK)


func _paint_flagstone(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_fill(img, tile, Pal.STONE)
	for i in 30:
		_px(img, tile, rng.randi_range(0, 15), rng.randi_range(0, 15), Pal.STONE_LIGHT if i % 3 == 0 else Pal.STONE_DARK)
	for i in Defs.CELL:
		_px(img, tile, i, 0, Pal.STONE_DARK)
		_px(img, tile, 0, i, Pal.STONE_DARK)
		_px(img, tile, i, 8, Pal.STONE_DARK)
	for y in range(1, 8):
		_px(img, tile, 8, y, Pal.STONE_DARK)
	for y in range(9, 16):
		_px(img, tile, 4, y, Pal.STONE_DARK)


func _paint_dirt(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_fill(img, tile, Pal.DIRT)
	for i in 26:
		_px(img, tile, rng.randi_range(0, 15), rng.randi_range(0, 15), Pal.DIRT_DARK)
	for i in 4:
		_px(img, tile, rng.randi_range(1, 14), rng.randi_range(1, 14), Pal.STONE_LIGHT)


func _paint_pad(img: Image, tile: int) -> void:
	_fill(img, tile, Pal.WOOD)
	for y in Defs.CELL:
		for x in Defs.CELL:
			if y % 5 == 0:
				_px(img, tile, x, y, Pal.WOOD_DARK)
			elif (x + y * 3) % 11 == 0:
				_px(img, tile, x, y, Pal.WOOD_LIGHT)
	for i in Defs.CELL:
		_px(img, tile, i, 0, Pal.INK_SOFT)
		_px(img, tile, i, 15, Pal.INK_SOFT)
		_px(img, tile, 0, i, Pal.INK_SOFT)
		_px(img, tile, 15, i, Pal.INK_SOFT)
	for corner in [Vector2i(1, 1), Vector2i(12, 1), Vector2i(1, 12), Vector2i(12, 12)]:
		var cc: Vector2i = corner
		for k in 3:
			_px(img, tile, cc.x + k, cc.y + (0 if cc.y < 8 else 2), Pal.SUNFLOWER)
			_px(img, tile, cc.x + (0 if cc.x < 8 else 2), cc.y + k, Pal.SUNFLOWER)
	_px(img, tile, 7, 7, Pal.METAL_LIGHT)
	_px(img, tile, 8, 8, Pal.METAL_LIGHT)


func _paint_burrow(img: Image, tile: int) -> void:
	for y in Defs.CELL:
		for x in Defs.CELL:
			var d := Vector2(x - 7.5, (y - 8.0) * 1.3).length()
			if d < 6.0:
				_px(img, tile, x, y, Pal.INK)
			elif d < 7.2:
				_px(img, tile, x, y, Pal.DIRT_DARK)
	_px(img, tile, 5, 8, Pal.WARP)
	_px(img, tile, 7, 8, Pal.WARP)
	_px(img, tile, 9, 10, Pal.WARP_DARK)
	_px(img, tile, 11, 10, Pal.WARP_DARK)


func _paint_hedge(img: Image, tile: int, rng: RandomNumberGenerator) -> void:
	_fill(img, tile, Pal.HEDGE)
	for i in 40:
		_px(img, tile, rng.randi_range(0, 15), rng.randi_range(0, 15), Pal.HEDGE_DARK)
	for i in 18:
		_px(img, tile, rng.randi_range(0, 15), rng.randi_range(0, 11), Pal.HEDGE_LIGHT)
	for x in Defs.CELL:
		_px(img, tile, x, 15, Pal.HEDGE_DARK)


func _build_colliders() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Defs.L_WORLD
	walls.collision_mask = 0
	add_child(walls)
	for y in Defs.GRID_H:
		var x := 0
		while x < Defs.GRID_W:
			if cell_type(Vector2i(x, y)) != Cell.BLOCKED:
				x += 1
				continue
			var start := x
			while x < Defs.GRID_W and cell_type(Vector2i(x, y)) == Cell.BLOCKED:
				x += 1
			var cs := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			sh.size = Vector2((x - start) * Defs.CELL, Defs.CELL)
			cs.shape = sh
			cs.position = Vector2((start + x) * Defs.CELL / 2.0, y * Defs.CELL + Defs.CELL / 2.0)
			walls.add_child(cs)


# --- Flow field --------------------------------------------------------------------

func _recompute_flow() -> void:
	var n := Defs.GRID_W * Defs.GRID_H
	cost_grid.resize(n)
	for i in n:
		var t := cells[i]
		cost_grid[i] = FlowField.BLOCKED if (t == Cell.BLOCKED or t == Cell.SILO) else 1.0
	for c in towers.keys():
		cost_grid[_idx(c)] = TOWER_PATH_COST
	var goals: Array = []
	for x in range(SILO_CELL.x - 1, SILO_CELL.x + SILO_SIZE.x + 1):
		for y in range(SILO_CELL.y - 1, SILO_CELL.y + SILO_SIZE.y + 1):
			var c := Vector2i(x, y)
			var t2 := cell_type(c)
			if t2 != Cell.SILO and t2 != Cell.BLOCKED:
				goals.append(c)
	flow.compute(Defs.GRID_W, Defs.GRID_H, cost_grid, goals)


func flow_next_cell(c: Vector2i) -> Vector2i:
	return flow.get_next(c)


# --- Coordinate helpers ---------------------------------------------------------------

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Defs.CELL), floori(p.y / Defs.CELL))


func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c.x * Defs.CELL + Defs.CELL / 2.0, c.y * Defs.CELL + Defs.CELL / 2.0)


func arena_rect() -> Rect2:
	return Rect2(0, 0, Defs.GRID_W * Defs.CELL, Defs.GRID_H * Defs.CELL)


func is_solid_world(p: Vector2) -> bool:
	return cell_type(world_to_cell(p)) == Cell.BLOCKED


func is_walkable_world(p: Vector2) -> bool:
	var t := cell_type(world_to_cell(p))
	return t != Cell.BLOCKED and t != Cell.SILO and not towers.has(world_to_cell(p))


## Marches from a to b and returns the first point that hits a hedge or the Silo.
func raycast_solid(a: Vector2, b: Vector2) -> Vector2:
	var d := a.distance_to(b)
	var steps := maxi(1, int(d / 4.0))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if is_solid_world(p) or silo.contains_point(p):
			return p
	return b


# --- Spatial hash & queries -------------------------------------------------------------

func _rebuild_hash() -> void:
	_hash.clear()
	var i := rats.size() - 1
	while i >= 0:
		var r = rats[i]
		if not is_instance_valid(r) or r.dead:
			rats.remove_at(i)
		else:
			var rp: Vector2 = r.global_position
			var k := Vector2i(floori(rp.x / HASH_SIZE), floori(rp.y / HASH_SIZE))
			if _hash.has(k):
				_hash[k].append(r)
			else:
				_hash[k] = [r]
		i -= 1


func register_rat(r: Node2D) -> void:
	rats.append(r)


func get_rats_in_radius(p: Vector2, rad: float) -> Array:
	var out: Array = []
	var x0 := floori((p.x - rad) / HASH_SIZE)
	var x1 := floori((p.x + rad) / HASH_SIZE)
	var y0 := floori((p.y - rad) / HASH_SIZE)
	var y1 := floori((p.y + rad) / HASH_SIZE)
	var r2 := rad * rad
	for gx in range(x0, x1 + 1):
		for gy in range(y0, y1 + 1):
			var k := Vector2i(gx, gy)
			if not _hash.has(k):
				continue
			for r in _hash[k]:
				if r.dead:
					continue
				var rp: Vector2 = r.global_position
				if rp.distance_squared_to(p) <= r2:
					out.append(r)
	return out


func nearest_rat(p: Vector2, rad: float, exclude: Array = []):
	var best = null
	var best_d := rad * rad
	for r in get_rats_in_radius(p, rad):
		if r.flying or r in exclude:
			continue
		var rp: Vector2 = r.global_position
		var d := rp.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = r
	return best


## Rats whose bodies touch the segment a-b, sorted by distance from a.
func rats_on_segment(a: Vector2, b: Vector2, pad: float) -> Array:
	var hits: Array = []
	var mid := (a + b) * 0.5
	var half := a.distance_to(b) * 0.5 + 12.0
	for r in get_rats_in_radius(mid, half):
		if r.flying:
			continue
		var rp: Vector2 = r.global_position
		var cp := Geometry2D.get_closest_point_to_segment(rp, a, b)
		if cp.distance_to(rp) <= float(r.hit_radius) + pad:
			hits.append([a.distance_squared_to(cp), r])
	hits.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var out: Array = []
	for h in hits:
		out.append(h[1])
	return out


func nearest_mech(p: Vector2, rad: float):
	var best = null
	var best_d := rad
	for m in mechs:
		if not m.is_targetable():
			continue
		var mp: Vector2 = m.global_position
		var d := mp.distance_to(p)
		if d < best_d:
			best_d = d
			best = m
	return best


func get_mech(pid: int):
	for m in mechs:
		if m.player_id == pid:
			return m
	return null


func other_mech(me: Node):
	for m in mechs:
		if m != me and m.active:
			return m
	return null


func nearest_tower(p: Vector2, rad: float, kind: int = -1):
	var best = null
	var best_d := rad
	for t in towers.values():
		if t.dead or t.build_t < 1.0:
			continue
		if kind >= 0 and t.kind != kind:
			continue
		var tp: Vector2 = t.global_position
		var d := tp.distance_to(p)
		if d < best_d:
			best_d = d
			best = t
	return best


func tower_at_cell(c: Vector2i):
	var t = towers.get(c, null)
	if t != null and (not is_instance_valid(t) or t.dead):
		return null
	return t


func tower_at_world(p: Vector2):
	var t = tower_at_cell(world_to_cell(p))
	if t == null:
		return null
	var tp: Vector2 = t.global_position
	if absf(tp.x - p.x) <= 7.0 and absf(tp.y - p.y) <= 7.0:
		return t
	return null


func find_free_pad_near(p: Vector2, max_d: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := max_d
	for c in pads:
		var pc: Vector2i = c
		if towers.has(pc):
			continue
		var d := cell_to_world(pc).distance_to(p)
		if d <= best_d:
			best_d = d
			best = pc
	return best


# --- Spawning ---------------------------------------------------------------------------

func spawn_rat(kind: int, p: Vector2, hp_mult: float = 1.0) -> RatEnemy:
	var r: RatEnemy = RAT_SCENE.instantiate()
	r.setup(kind, hp_mult)
	r.position = p
	entities.add_child(r)
	return r


func spawn_thrown_rat(from: Vector2, to: Vector2, hp_mult: float) -> void:
	var land := to
	if not is_walkable_world(land):
		land = from + Vector2(0, 16)
	land = land.clamp(Vector2(20, 20), Vector2(620, 344))
	var r := spawn_rat(Defs.Rat.SQUEAKER, from, hp_mult)
	r.start_flight(land)


func spawn_seeds(p: Vector2, total: int) -> void:
	if total <= 0:
		return
	var count := mini(total, 6)
	var per := total / count
	var extra := total - per * count
	for i in count:
		var s := SeedPickup.new()
		s.value = per + (1 if i < extra else 0)
		s.position = p
		s.launch(Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0))
		entities.add_child(s)


func add_projectile(p: Node2D) -> void:
	projectiles_node.add_child(p)


func spawn_ground(kind: int, p: Vector2, radius: float, life: float, power: float, pid: int = 0) -> void:
	if kind == GroundEffect.Kind.SHELLS and get_tree().get_nodes_in_group("shell_piles").size() >= MAX_SHELL_PILES:
		return
	var g := GroundEffect.new().setup(kind, radius, life, power, pid)
	g.position = p
	ground_fx.add_child(g)


func spawn_mortar(from: Vector2, to: Vector2, dmg: float, aoe: float, stun: float) -> void:
	var m := MortarShell.new().configure(from, to, dmg, aoe, stun)
	projectiles_node.add_child(m)


func build_tower(kind: int, c: Vector2i, pid: int) -> void:
	var t: TowerBase = TOWER_SCENE.instantiate()
	t.setup(kind, c, pid)
	t.position = cell_to_world(c)
	entities.add_child(t)
	towers[c] = t
	_flow_dirty = true
	JuiceManager.popup(t.position + Vector2(0, -26), Defs.tower_short(kind) + "!", Pal.SUNFLOWER, 0.7)
	SFX.play("build", 1.3, -6.0)


func on_tower_destroyed(t: Node2D) -> void:
	var c: Vector2i = t.cell
	if towers.get(c) == t:
		towers.erase(c)
	_flow_dirty = true


func on_rat_killed(_r: Node2D) -> void:
	GameManager.kills += 1


func on_card_applied(card: Dictionary, pid: int) -> void:
	for m in mechs:
		if m.active:
			m.recalc_stats(false)
	var who := "P%d" % pid
	hud.show_banner("%s TOOK: %s" % [who, String(card["name"]).to_upper()], "", 2.5)


# --- Run state flow ---------------------------------------------------------------------

func _join(pid: int, announce: bool = true) -> void:
	if GameManager.is_joined(pid):
		return
	GameManager.join_player(pid)
	var m = get_mech(pid)
	if m == null:
		return
	m.position = silo.position + Vector2(-44.0 if pid == 1 else 44.0, 44.0)
	m.set_active(true)
	if announce:
		SFX.play("join")
		JuiceManager.ring(m.global_position, 24.0, Pal.player_color(pid), 0.4)
		JuiceManager.bark(m, "%s reporting for seed duty!" % m.display_name(), false, "", 0.0)
		hud.show_banner("PLAYER %d JOINED!" % pid, m.display_name(), 2.0)


func _begin_run() -> void:
	GameManager.prep_timer = GameManager.FIRST_PREP_TIME
	GameManager.set_state(GameManager.State.PREP)
	hud.show_banner("DEFEND THE GREAT SILO!", "BUILD TOWERS - BANK SEEDS - SQUASH RATS", 4.0)
	_update_mouse_mode()


func start_wave() -> void:
	GameManager.wave += 1
	GameManager.low_silo_barked = false
	_stall_t = 0.0
	GameManager.set_state(GameManager.State.WAVE)
	GameManager.wave_changed.emit(GameManager.wave)
	spawner.start_wave(GameManager.wave)
	hud.show_banner("WAVE %d" % GameManager.wave, spawner.flavor(GameManager.wave), 3.0)
	SFX.play("wave")
	JuiceManager.add_trauma(0.2)


func end_wave() -> void:
	var bonus := 10 + GameManager.wave * 3 + GameManager.gmodi("wave_seed_bonus")
	GameManager.add_seeds(bonus)
	JuiceManager.popup(silo.position + Vector2(0, -50), "WAVE BONUS +%d" % bonus, Pal.SEED_GOLD, 1.5)
	GameManager.set_state(GameManager.State.DRAFT)
	get_tree().paused = true
	draft.open(GameManager.joined_ids())
	_update_mouse_mode()


func _on_draft_finished() -> void:
	get_tree().paused = false
	for m in mechs:
		if m.active:
			if m.downed:
				m.revive(0.6, null)
			m.recalc_stats(false)
			m.heal(m.max_hp * 0.25)
	GameManager.prep_timer = GameManager.PREP_TIME
	GameManager.set_state(GameManager.State.PREP)
	_update_mouse_mode()


func _on_silo_destroyed() -> void:
	if GameManager.state == GameManager.State.GAME_OVER:
		return
	GameManager.set_state(GameManager.State.GAME_OVER)
	_game_over_ms = Time.get_ticks_msec()
	JuiceManager.set_base_time_scale(0.35)
	JuiceManager.add_trauma(1.0)
	JuiceManager.burst(silo.position + Vector2(0, -20), Pal.SEED, 60, 220.0, 1.4, 2.0, 160.0)
	JuiceManager.burst(silo.position + Vector2(0, -20), Pal.WARP, 30, 160.0, 1.0, 2.0, 0.0, true)
	JuiceManager.ring(silo.position, 90.0, Pal.WARP, 0.8, true)
	SFX.play("boom", 0.5)
	for r in rats:
		if is_instance_valid(r) and not r.dead:
			JuiceManager.bark(r, "The seeds are ours-ours! Praise the Gouda!", true, "rat_win", 30.0)
			break
	_update_mouse_mode()


func restart() -> void:
	GameManager.quick_restart_players = GameManager.joined_ids()
	GameManager.reset()
	get_tree().paused = false
	JuiceManager.set_base_time_scale(1.0)
	get_tree().reload_current_scene()


func _update_mouse_mode() -> void:
	var hide_cursor := GameManager.in_combat_state() and GameManager.is_joined(1)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hide_cursor else Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_rebuild_hash()
	if _flow_dirty:
		_flow_dirty = false
		_recompute_flow()
	var st := GameManager.state
	if st == GameManager.State.PREP:
		GameManager.prep_timer -= delta
		if GameManager.prep_timer <= 0.0 or Input.is_action_just_pressed("call_wave"):
			start_wave()
	elif st == GameManager.State.WAVE:
		if spawner.is_finished():
			if rats.is_empty():
				end_wave()
			else:
				_stall_t += delta
				if _stall_t > 45.0:
					# Soft-lock guard: stragglers stuck behind hedges succumb to warp-fatigue.
					for r in rats:
						if is_instance_valid(r) and not r.dead:
							r.take_damage(r.max_hp * 0.1 * delta, Vector2.ZERO, 0, false)
	_jumper_cables(delta)
	_check_low_silo()


func _process(_delta: float) -> void:
	var st := GameManager.state
	if st == GameManager.State.TITLE:
		if Input.is_action_just_pressed("p1_fire") or Input.is_action_just_pressed("p1_interact"):
			_join(1, false)
			_begin_run()
		elif Input.is_action_just_pressed("p2_start") or Input.is_action_just_pressed("p2_interact") or Input.is_action_just_pressed("p2_fire"):
			_join(2, false)
			_begin_run()
	elif st == GameManager.State.PREP or st == GameManager.State.WAVE:
		if not GameManager.is_joined(1) and (Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p1_fire")):
			_join(1)
			_update_mouse_mode()
		if not GameManager.is_joined(2) and (Input.is_action_just_pressed("p2_start") or Input.is_action_just_pressed("p2_interact")):
			_join(2)
	elif st == GameManager.State.GAME_OVER:
		if Time.get_ticks_msec() - _game_over_ms > 1800:
			var again := Input.is_action_just_pressed("p1_interact") or Input.is_action_just_pressed("p1_fire")
			again = again or Input.is_action_just_pressed("p2_start") or Input.is_action_just_pressed("p2_interact")
			if again:
				restart()


func _jumper_cables(delta: float) -> void:
	if not GameManager.gmodb("jumper_cables"):
		return
	var a = get_mech(1)
	var b = get_mech(2)
	if a == null or b == null or not a.is_alive() or not b.is_alive():
		return
	var pa: Vector2 = a.global_position + Vector2(0, -10)
	var pb: Vector2 = b.global_position + Vector2(0, -10)
	if pa.distance_to(pb) > 260.0:
		return
	JuiceManager.bolt(pa, pb, Pal.TESLA, 0.035, 3.0)
	_cable_tick -= delta
	if _cable_tick > 0.0:
		return
	_cable_tick = 0.1
	for r in rats_on_segment(pa, pb, 3.0):
		r.take_damage(4.5, Vector2.ZERO, 0)
		if randf() < 0.3:
			JuiceManager.burst(r.global_position, Pal.TESLA, 3, 60.0, 0.2, 1.0, 0.0, true)


func _check_low_silo() -> void:
	if GameManager.low_silo_barked or GameManager.state != GameManager.State.WAVE:
		return
	if GameManager.silo_ratio() < 0.3:
		GameManager.low_silo_barked = true
		var m = nearest_mech(silo.position, 9999.0)
		if m != null:
			JuiceManager.bark(m, "They're touching the good seeds! THE STRIPED ONES!", false, "", 0.0)
		SFX.play("alarm")
		hud.show_banner("SILO CRITICAL!", "", 2.0)
