class_name ArenaMap
extends RefCounted
## The Backyard: 40x22 tile grid around The Great Silo, plus a Dijkstra flow field
## that every Under-Scurrier follows towards the Silo.

const W := 40
const H := 22
const TILE := 16

enum Cell { GRASS, PATH, PAD, BURROW, WALL, OBSTACLE, SILO }

const SILO_RECT := Rect2i(18, 9, 4, 4)
const SILO_CENTER := Vector2(320, 178)
const SILO_RADIUS := 26.0

# Burrows open progressively as waves advance (index order = unlock order).
const BURROWS := [
	Vector2i(2, 2), Vector2i(37, 19), Vector2i(37, 2), Vector2i(2, 19), Vector2i(2, 11), Vector2i(37, 10),
]
const PADS := [
	# inner ring
	Vector2i(16, 8), Vector2i(19, 7), Vector2i(23, 8), Vector2i(24, 11),
	Vector2i(23, 13), Vector2i(20, 14), Vector2i(16, 13), Vector2i(15, 10),
	# middle ring
	Vector2i(12, 6), Vector2i(27, 6), Vector2i(12, 15), Vector2i(27, 15),
	Vector2i(10, 10), Vector2i(29, 11), Vector2i(19, 4), Vector2i(20, 17),
	# forward pads near the burrows
	Vector2i(6, 5), Vector2i(33, 5), Vector2i(6, 16), Vector2i(33, 16), Vector2i(6, 10), Vector2i(33, 12),
]
const OBSTACLES := [
	{"cell": Vector2i(13, 9), "kind": "rock"},
	{"cell": Vector2i(26, 12), "kind": "rock"},
	{"cell": Vector2i(9, 3), "kind": "pot"},
	{"cell": Vector2i(30, 18), "kind": "pot"},
	{"cell": Vector2i(24, 4), "kind": "gnome"},
	{"cell": Vector2i(15, 18), "kind": "can"},
	{"cell": Vector2i(31, 8), "kind": "pot"},
	{"cell": Vector2i(8, 13), "kind": "rock"},
	{"cell": Vector2i(4, 14), "kind": "gnome"},
	{"cell": Vector2i(35, 6), "kind": "rock"},
	{"cell": Vector2i(22, 18), "kind": "pot"},
	{"cell": Vector2i(17, 3), "kind": "can"},
]

var cells: PackedInt32Array = PackedInt32Array()
var deco: PackedInt32Array = PackedInt32Array()     # visual variant per cell
var dist: PackedInt32Array = PackedInt32Array()     # flow-field distance (cost) to Silo
var next_cell: PackedInt32Array = PackedInt32Array() # index of the next cell towards the Silo (-1 = goal/none)


func build() -> void:
	cells.resize(W * H)
	deco.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in H:
		for x in W:
			var i := idx(x, y)
			cells[i] = Cell.GRASS
			deco[i] = rng.randi_range(0, 3)
			if rng.randf() < 0.07:
				deco[i] = 10 + rng.randi_range(0, 2)   # flowers
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				cells[i] = Cell.WALL
	for y in range(SILO_RECT.position.y, SILO_RECT.end.y):
		for x in range(SILO_RECT.position.x, SILO_RECT.end.x):
			cells[idx(x, y)] = Cell.SILO
	for b in BURROWS:
		cells[idx(b.x, b.y)] = Cell.BURROW
	for p in PADS:
		cells[idx(p.x, p.y)] = Cell.PAD
	for o in OBSTACLES:
		var c: Vector2i = o["cell"]
		cells[idx(c.x, c.y)] = Cell.OBSTACLE
	# flagstone paths from every burrow towards the silo (cosmetic, walkable)
	var goal := Vector2(19.5, 10.5)
	for b in BURROWS:
		var from := Vector2(b) + Vector2(0.5, 0.5)
		var steps := int(from.distance_to(goal) * 2.0)
		for s in steps:
			var p := from.lerp(goal, float(s) / steps)
			for o in [Vector2i(0, 0), Vector2i(1, 0)]:
				var c: Vector2i = Vector2i(floori(p.x), floori(p.y)) + o
				if in_bounds(c) and cells[idx(c.x, c.y)] == Cell.GRASS:
					cells[idx(c.x, c.y)] = Cell.PATH
					deco[idx(c.x, c.y)] = rng.randi_range(0, 2)
	compute_flow()


func idx(x: int, y: int) -> int:
	return y * W + x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func cell_type(c: Vector2i) -> int:
	if not in_bounds(c):
		return Cell.WALL
	return cells[idx(c.x, c.y)]


func is_walkable(c: Vector2i) -> bool:
	var t := cell_type(c)
	return t == Cell.GRASS or t == Cell.PATH or t == Cell.BURROW


## True for cells that stop projectiles (fence + garden props).
func is_solid_at(pos: Vector2) -> bool:
	var c := Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))
	var t := cell_type(c)
	return t == Cell.WALL or t == Cell.OBSTACLE


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


static func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


# ------------------------------------------------------------------ flow field

func compute_flow() -> void:
	var n := W * H
	dist.resize(n)
	next_cell.resize(n)
	for i in n:
		dist[i] = 1 << 30
		next_cell[i] = -1
	# goals: walkable cells touching the silo footprint
	var open: Array = []   # [cost, index] kept sorted by cost (small grid, simple is fine)
	for y in H:
		for x in W:
			if not is_walkable(Vector2i(x, y)):
				continue
			var touches := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if cell_type(Vector2i(x + dx, y + dy)) == Cell.SILO:
						touches = true
			if touches:
				dist[idx(x, y)] = 0
				open.append([0, idx(x, y)])
	while open.size() > 0:
		# pop min
		var best := 0
		for k in range(1, open.size()):
			if open[k][0] < open[best][0]:
				best = k
		var item: Array = open[best]
		open.remove_at(best)
		var cost: int = item[0]
		var i: int = item[1]
		if cost > dist[i]:
			continue
		var cx := i % W
		var cy := int(i / W)
		for d in _neighbours(cx, cy):
			var ni := idx(cx + d.x, cy + d.y)
			var nc := cost + (14 if d.x != 0 and d.y != 0 else 10)
			if nc < dist[ni]:
				dist[ni] = nc
				open.append([nc, ni])
	# resolve "next" pointers
	for y in H:
		for x in W:
			var i := idx(x, y)
			if not is_walkable(Vector2i(x, y)) or dist[i] == 0:
				continue
			var bd := dist[i]
			var bi := -1
			for d in _neighbours(x, y):
				var ni := idx(x + d.x, y + d.y)
				if dist[ni] < bd:
					bd = dist[ni]
					bi = ni
			next_cell[i] = bi


## Walkable neighbours (8-way, no corner cutting).
func _neighbours(x: int, y: int) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var c := Vector2i(x + dx, y + dy)
			if not is_walkable(c):
				continue
			if dx != 0 and dy != 0:
				if not is_walkable(Vector2i(x + dx, y)) or not is_walkable(Vector2i(x, y + dy)):
					continue
			out.append(Vector2i(dx, dy))
	return out


## World-space waypoint a rat at `pos` should steer towards. Returns SILO_CENTER near the goal.
func flow_waypoint(pos: Vector2) -> Vector2:
	var c := to_cell(pos)
	if not in_bounds(c):
		return SILO_CENTER
	var i := idx(c.x, c.y)
	if not is_walkable(c):
		# pushed into a pad/obstacle edge: find any walkable neighbour with the best distance
		var bd := 1 << 30
		var best := SILO_CENTER
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nc := Vector2i(c.x + dx, c.y + dy)
				if is_walkable(nc) and dist[idx(nc.x, nc.y)] < bd:
					bd = dist[idx(nc.x, nc.y)]
					best = cell_center(nc)
		return best
	if dist[i] == 0 or next_cell[i] < 0:
		return SILO_CENTER
	var ni := next_cell[i]
	return cell_center(Vector2i(ni % W, int(ni / W)))


func dist_at(pos: Vector2) -> int:
	var c := to_cell(pos)
	if not in_bounds(c):
		return 1 << 30
	return dist[idx(c.x, c.y)]


func validate() -> Array:
	var problems: Array = []
	for b in BURROWS:
		if dist[idx(b.x, b.y)] >= (1 << 30):
			problems.append("burrow %s cannot reach the silo" % [b])
	return problems
