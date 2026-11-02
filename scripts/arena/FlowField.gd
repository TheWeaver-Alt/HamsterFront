class_name FlowField
extends RefCounted
## Dijkstra flow field over the arena grid. Every walkable cell stores the
## neighbour that leads most cheaply toward the goal cells (around the Silo).
## Tower cells are passable at high cost, so rats route around towers but
## will chew straight through if the players wall everything off.

const BLOCKED := INF
const DIRS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var w := 0
var h := 0
var dist := PackedFloat32Array()
var next_idx := PackedInt32Array()

# Binary min-heap stored in parallel arrays.
var _hp := PackedFloat32Array()
var _hi := PackedInt32Array()
var _hn := 0


func compute(width: int, height: int, cost: PackedFloat32Array, goals: Array) -> void:
	w = width
	h = height
	var n := w * h
	dist.resize(n)
	dist.fill(INF)
	next_idx.resize(n)
	next_idx.fill(-1)
	_hp.resize(n * 8 + 16)
	_hi.resize(n * 8 + 16)
	_hn = 0
	for g in goals:
		var gc: Vector2i = g
		var gi := gc.y * w + gc.x
		dist[gi] = 0.0
		next_idx[gi] = gi
		_push(0.0, gi)
	while _hn > 0:
		var d := _hp[0]
		var i := _hi[0]
		_pop()
		if d > dist[i]:
			continue
		var cx := i % w
		var cy := i / w
		var enter_cost := cost[i]
		for k in 8:
			var dv: Vector2i = DIRS[k]
			var nx := cx + dv.x
			var ny := cy + dv.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if cost[ni] >= BLOCKED:
				continue
			var step := enter_cost
			if k >= 4:
				# No diagonal corner-cutting past blocked cells.
				if cost[cy * w + nx] >= BLOCKED or cost[ny * w + cx] >= BLOCKED:
					continue
				step *= 1.41421
			var nd := d + step
			if nd < dist[ni]:
				dist[ni] = nd
				next_idx[ni] = i
				_push(nd, ni)


func get_next(c: Vector2i) -> Vector2i:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return Vector2i(-1, -1)
	var ni := next_idx[c.y * w + c.x]
	if ni < 0:
		return Vector2i(-1, -1)
	return Vector2i(ni % w, ni / w)


func get_dist(c: Vector2i) -> float:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return INF
	return dist[c.y * w + c.x]


func _push(p: float, item: int) -> void:
	if _hn >= _hp.size():
		_hp.resize(_hp.size() * 2)
		_hi.resize(_hi.size() * 2)
	var j := _hn
	_hn += 1
	while j > 0:
		var parent := (j - 1) / 2
		if _hp[parent] <= p:
			break
		_hp[j] = _hp[parent]
		_hi[j] = _hi[parent]
		j = parent
	_hp[j] = p
	_hi[j] = item


func _pop() -> void:
	_hn -= 1
	if _hn <= 0:
		return
	var p := _hp[_hn]
	var item := _hi[_hn]
	var j := 0
	while true:
		var l := j * 2 + 1
		if l >= _hn:
			break
		var r := l + 1
		var m := l
		if r < _hn and _hp[r] < _hp[l]:
			m = r
		if _hp[m] >= p:
			break
		_hp[j] = _hp[m]
		_hi[j] = _hi[m]
		j = m
	_hp[j] = p
	_hi[j] = item
