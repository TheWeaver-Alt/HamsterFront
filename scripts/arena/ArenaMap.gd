class_name ArenaMap
extends RefCounted
## The Backyard, 3/4 view with elevation: three canyon lanes run from the burrows (west) to the
## patio courtyard (east) where The Great Silo stands. Plateaus between the lanes carry most tower
## pads; cliff faces block walking (rats + mechs) except via ramps/stairs. Mechs with the Jetpack
## card can hop cliffs. A Dijkstra flow field (ramps are expensive) funnels rats down the lanes.

const W := 40
const H := 22
const TILE := 16

enum Cell { GRASS, PATH, PAD, BURROW, WALL, OBSTACLE, SILO, HIGH, FACE, RAMP, PATIO }

const RAMP_ELEV := -1
const RAMP_COST_MULT := 6

# Terrain legend:  # fence   H plateau top   F cliff face   r ramp/stairs
#                  , lane floor (dirt)   . courtyard grass   S silo footprint
const TERRAIN := [
	"########################################",
	"#HHHHHHHHHHHHHHHHHHHHHHHHHr............#",
	"#HHHHHHHHHHHHHHHHHHHHHHHHHr............#",
	"#FFFFFFFFFFFFFFFFFFFFFFFFFF............#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,...........#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,...........#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,...........#",
	"#HHHHHHHHHHHHHHHHHrHHHHHHHr............#",
	"#HHHHHHHHHHHHHHHHHHHHHHHHHr............#",
	"#FFFFFFFFFFFrFFFFFFFFFFFFFF.....SSSS...#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,....SSSS...#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,....SSSS...#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,....SSSS...#",
	"#HHHHHHHHHHHHHHHHHHHrHHHHHr............#",
	"#HHHHHHHHHHHHHHHHHHHHHHHHHr............#",
	"#FFFFFFFrFFFFFFFFFFFFFFFFFF............#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,...........#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,...........#",
	"#,,,,,,,,,,,,,,,,,,,,,,,,,,,...........#",
	"#HHHHHHHHHHHHHrHHHHHHHHHHHr............#",
	"#HHHHHHHHHHHHHHHHHHHHHHHHHr............#",
	"########################################",
]

const SILO_RECT := Rect2i(32, 9, 4, 4)
const SILO_CENTER := Vector2(544, 178)
const SILO_RADIUS := 26.0

# Burrows open progressively as waves advance (index order = unlock order).
const BURROWS := [
	Vector2i(2, 11), Vector2i(2, 5), Vector2i(2, 17), Vector2i(33, 2), Vector2i(33, 19),
]
const PADS := [
	# top plateau
	Vector2i(5, 2), Vector2i(11, 1), Vector2i(17, 2), Vector2i(23, 1),
	# upper plateau (between north + middle lanes)
	Vector2i(5, 8), Vector2i(11, 7), Vector2i(15, 8), Vector2i(22, 8),
	# lower plateau (between middle + south lanes)
	Vector2i(5, 14), Vector2i(11, 13), Vector2i(16, 14), Vector2i(23, 13),
	# bottom plateau
	Vector2i(5, 19), Vector2i(11, 20), Vector2i(17, 19), Vector2i(23, 20),
	# courtyard (low ground, in the rats' way)
	Vector2i(29, 4), Vector2i(29, 17), Vector2i(30, 8), Vector2i(30, 14), Vector2i(37, 6), Vector2i(37, 15),
]
const OBSTACLES := [
	# lane chokepoints
	{"cell": Vector2i(8, 4), "kind": "rock"},
	{"cell": Vector2i(14, 6), "kind": "pot"},
	{"cell": Vector2i(21, 4), "kind": "gnome"},
	{"cell": Vector2i(7, 12), "kind": "rock"},
	{"cell": Vector2i(15, 10), "kind": "can"},
	{"cell": Vector2i(23, 12), "kind": "pot"},
	{"cell": Vector2i(9, 18), "kind": "pot"},
	{"cell": Vector2i(16, 16), "kind": "rock"},
	{"cell": Vector2i(22, 18), "kind": "gnome"},
	# courtyard + plateau decor
	{"cell": Vector2i(37, 2), "kind": "can"},
	{"cell": Vector2i(37, 19), "kind": "rock"},
	{"cell": Vector2i(2, 1), "kind": "pot"},
	{"cell": Vector2i(20, 20), "kind": "rock"},
	{"cell": Vector2i(3, 13), "kind": "gnome"},
]

var cells: PackedInt32Array = PackedInt32Array()
var elev: PackedInt32Array = PackedInt32Array()      # 0 low, 1 plateau, -1 ramp
var region: PackedInt32Array = PackedInt32Array()    # connected same-level area id (-1 ramps/none)
var deco: PackedInt32Array = PackedInt32Array()      # visual variant per cell
var dist: PackedInt32Array = PackedInt32Array()      # flow-field cost to the Silo
var next_cell: PackedInt32Array = PackedInt32Array() # next cell index towards the Silo (-1 = goal/none)


func build() -> void:
	cells.resize(W * H)
	elev.resize(W * H)
	deco.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in H:
		var row: String = TERRAIN[y]
		for x in W:
			var i := idx(x, y)
			deco[i] = rng.randi_range(0, 3)
			if rng.randf() < 0.07:
				deco[i] = 10 + rng.randi_range(0, 2)   # flowers
			var ch := row[x]
			match ch:
				"#":
					cells[i] = Cell.WALL
					elev[i] = 0
				"H":
					cells[i] = Cell.HIGH
					elev[i] = 1
				"F":
					cells[i] = Cell.FACE
					elev[i] = 1
				"r":
					cells[i] = Cell.RAMP
					elev[i] = RAMP_ELEV
				",":
					cells[i] = Cell.PATH
					elev[i] = 0
				"S":
					cells[i] = Cell.SILO
					elev[i] = 0
				_:
					cells[i] = Cell.PATIO if _near_silo(x, y) else Cell.GRASS
					elev[i] = 0
	for b in BURROWS:
		cells[idx(b.x, b.y)] = Cell.BURROW
	for p in PADS:
		cells[idx(p.x, p.y)] = Cell.PAD
	for o in OBSTACLES:
		var c: Vector2i = o["cell"]
		cells[idx(c.x, c.y)] = Cell.OBSTACLE
	_compute_regions()
	compute_flow()


func _near_silo(x: int, y: int) -> bool:
	return x >= SILO_RECT.position.x - 2 and x < SILO_RECT.end.x + 2 \
		and y >= SILO_RECT.position.y - 2 and y < SILO_RECT.end.y + 2


func idx(x: int, y: int) -> int:
	return y * W + x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func cell_type(c: Vector2i) -> int:
	if not in_bounds(c):
		return Cell.WALL
	return cells[idx(c.x, c.y)]


func cell_elev(c: Vector2i) -> int:
	if not in_bounds(c):
		return 0
	return elev[idx(c.x, c.y)]


func is_walkable(c: Vector2i) -> bool:
	var t := cell_type(c)
	return t == Cell.GRASS or t == Cell.PATH or t == Cell.BURROW or t == Cell.HIGH \
		or t == Cell.RAMP or t == Cell.PATIO


## Can a walker step directly from cell a to the 4/8-neighbour cell b?
func passable(a: Vector2i, b: Vector2i) -> bool:
	if not is_walkable(b) or not is_walkable(a):
		return false
	var ea := cell_elev(a)
	var eb := cell_elev(b)
	return ea == eb or ea == RAMP_ELEV or eb == RAMP_ELEV


## True for cells that stop projectiles (fence + garden props). Shots fly over cliffs.
func is_solid_at(pos: Vector2) -> bool:
	var c := Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))
	var t := cell_type(c)
	return t == Cell.WALL or t == Cell.OBSTACLE


## Solid for walkers that can't fly: fence, props, cliff faces, the silo.
func blocks_walker(c: Vector2i) -> bool:
	var t := cell_type(c)
	return t == Cell.WALL or t == Cell.OBSTACLE or t == Cell.FACE or t == Cell.SILO


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


static func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


# ------------------------------------------------------------------ elevation queries

## Elevation of the ground at pos: 0 = low ground, 1 = plateau, -1 = ramp.
func elev_at(pos: Vector2) -> int:
	return cell_elev(to_cell(pos))


## True if a walker can get from a to b without climbing a cliff (same connected area,
## or either point on a ramp).
func same_level(a: Vector2, b: Vector2) -> bool:
	var ca := to_cell(a)
	var cb := to_cell(b)
	if not in_bounds(ca) or not in_bounds(cb):
		return true
	var ra := region[idx(ca.x, ca.y)]
	var rb := region[idx(cb.x, cb.y)]
	if ra < 0 or rb < 0:
		return cell_elev(ca) == cell_elev(cb) or cell_elev(ca) == RAMP_ELEV or cell_elev(cb) == RAMP_ELEV
	return ra == rb


func is_high_ground(pos: Vector2) -> bool:
	return elev_at(pos) == 1


## Connected areas of equal elevation (pads/props/burrows included), ramps excluded.
func _compute_regions() -> void:
	region.resize(W * H)
	for i in W * H:
		region[i] = -1
	var next_id := 0
	for y in H:
		for x in W:
			var i := idx(x, y)
			if region[i] >= 0 or not _regionable(Vector2i(x, y)):
				continue
			var e := elev[i]
			var stack: Array = [Vector2i(x, y)]
			region[i] = next_id
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if not in_bounds(n):
						continue
					var ni := idx(n.x, n.y)
					if region[ni] < 0 and _regionable(n) and elev[ni] == e:
						region[ni] = next_id
						stack.append(n)
			next_id += 1


func _regionable(c: Vector2i) -> bool:
	var t := cell_type(c)
	return t != Cell.WALL and t != Cell.FACE and t != Cell.RAMP


# ------------------------------------------------------------------ flow field

func compute_flow() -> void:
	var n := W * H
	dist.resize(n)
	next_cell.resize(n)
	for i in n:
		dist[i] = 1 << 30
		next_cell[i] = -1
	var open: Array = []   # [cost, index]
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
			var step := 14 if d.x != 0 and d.y != 0 else 10
			if elev[ni] == RAMP_ELEV or elev[i] == RAMP_ELEV:
				step *= RAMP_COST_MULT
			var nc := cost + step
			if nc < dist[ni]:
				dist[ni] = nc
				open.append([nc, ni])
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


## Passable neighbours (8-way, no corner cutting, no cliff crossing).
func _neighbours(x: int, y: int) -> Array:
	var out: Array = []
	var here := Vector2i(x, y)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var c := Vector2i(x + dx, y + dy)
			if not passable(here, c):
				continue
			if dx != 0 and dy != 0:
				if not passable(here, Vector2i(x + dx, y)) or not passable(here, Vector2i(x, y + dy)):
					continue
			out.append(Vector2i(dx, dy))
	return out


## World-space waypoint a rat at `pos` should steer towards. Returns SILO_CENTER near the goal.
func flow_waypoint(pos: Vector2) -> Vector2:
	var c := to_cell(pos)
	if not in_bounds(c):
		return SILO_CENTER
	var i := idx(c.x, c.y)
	if not is_walkable(c) or dist[i] >= (1 << 30):
		# pushed into a pad/prop/face edge: step to the best walkable neighbour
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
	for y in H:
		if (TERRAIN[y] as String).length() != W:
			problems.append("terrain row %d has length %d" % [y, (TERRAIN[y] as String).length()])
	for b in BURROWS:
		if dist[idx(b.x, b.y)] >= (1 << 30):
			problems.append("burrow %s cannot reach the silo" % [b])
	for p in PADS:
		var ch: String = (TERRAIN[p.y] as String)[p.x]
		if ch != "H" and ch != "." and ch != ",":
			problems.append("pad %s sits on '%s'" % [p, ch])
	for y in range(1, H):
		for x in W:
			if (TERRAIN[y] as String)[x] == "F":
				var above: String = (TERRAIN[y - 1] as String)[x]
				if above != "H" and above != "r":
					problems.append("cliff face at %d,%d has no plateau above" % [x, y])
	return problems
