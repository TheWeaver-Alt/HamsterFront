class_name HazardManager
extends Node2D
## Area hazards and ground decals.
##   "shells"  sunflower hull piles from Gatlings: slow rats standing in them
##   "fire"    burning rubber / flaming hulls: hurts rats (team 0)
##   "gas"     Plague-Stink Monk clouds: hurt mechs, corrode tower armour (team 1)
##   "skid"    cosmetic rubber skid marks
##   "scorch"  cosmetic blast marks
## Ground stuff draws here (under entities); gas draws on the `top` child above entities.

class Hazard:
	var kind: String
	var pos: Vector2
	var radius: float
	var life: float
	var max_life: float
	var dps: float = 0.0
	var count: int = 1
	var offsets: PackedVector2Array = PackedVector2Array()
	var rot: float = 0.0
	var seed_i: int = 0

const TICK := 0.2

var hazards: Array = []
var arena
var top: Node2D
var _tick_t := 0.0
var _shell_grid: Dictionary = {}     # Vector2i(16px cell) -> Array[Hazard] (shell piles only)
var _shell_dirty := true


func _ready() -> void:
	z_index = 0
	top = Node2D.new()
	top.z_index = 15
	top.name = "HazardTop"
	top.draw.connect(_draw_top)
	add_child(top)


func add(kind: String, pos: Vector2, radius: float, life: float, dps: float = 0.0) -> Hazard:
	if hazards.size() > 220:
		# drop the oldest cosmetic first
		for i in hazards.size():
			if hazards[i].kind == "skid" or hazards[i].kind == "scorch":
				hazards.remove_at(i)
				break
	var h := Hazard.new()
	if kind == "shells":
		_shell_dirty = true
	h.kind = kind
	h.pos = pos
	h.radius = radius
	h.life = life
	h.max_life = life
	h.dps = dps
	h.rot = randf() * TAU
	h.seed_i = randi()
	hazards.append(h)
	return h


## Adds hulls to the nearest shell pile (or starts a new one).
func add_shells(pos: Vector2, n: int = 1) -> void:
	var life := 10.0 * GameManager.gstats.g("shell_life_mult", 1.0)
	for h in hazards:
		if h.kind == "shells" and h.pos.distance_to(pos) < 9.0:
			h.count = mini(h.count + n, 8)
			h.life = life
			h.max_life = life
			while h.offsets.size() < h.count * 2:
				h.offsets.append(Vector2(randf_range(-5, 5), randf_range(-3, 3)))
			return
	var nh := add("shells", pos, 9.0, life)
	nh.count = n
	for i in n * 2:
		nh.offsets.append(Vector2(randf_range(-5, 5), randf_range(-3, 3)))


## Movement multiplier (<=1) for a rat standing at pos.
func slow_factor(pos: Vector2) -> float:
	if _shell_dirty:
		_rebuild_shell_grid()
	var bucket = _shell_grid.get(Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0)))
	if bucket == null:
		return 1.0
	var slow := 0.0
	for h in bucket:
		if absf(h.pos.x - pos.x) < h.radius and absf(h.pos.y - pos.y) < h.radius:
			slow += 0.08 * h.count
	return 1.0 - minf(slow * GameManager.gstats.g("shell_slow_mult", 1.0), 0.6)


func _rebuild_shell_grid() -> void:
	_shell_dirty = false
	_shell_grid.clear()
	for h in hazards:
		if h.kind != "shells":
			continue
		# a pile (radius 9) can touch up to 4 cells
		for c in [h.pos + Vector2(-9, -9), h.pos + Vector2(9, -9), h.pos + Vector2(-9, 9), h.pos + Vector2(9, 9)]:
			var key := Vector2i(floori(c.x / 16.0), floori(c.y / 16.0))
			if not _shell_grid.has(key):
				_shell_grid[key] = [h]
			elif not _shell_grid[key].has(h):
				_shell_grid[key].append(h)


func _physics_process(delta: float) -> void:
	var k := hazards.size() - 1
	while k >= 0:
		var h: Hazard = hazards[k]
		h.life -= delta
		if h.life <= 0.0:
			if h.kind == "shells":
				_shell_dirty = true
			hazards.remove_at(k)
		k -= 1
	_tick_t += delta
	if _tick_t >= TICK:
		_tick_t -= TICK
		_apply_damage()
	queue_redraw()
	top.queue_redraw()


func _apply_damage() -> void:
	if not is_instance_valid(arena):
		return
	for h in hazards:
		match h.kind:
			"fire":
				for e in arena.enemies_in_radius(h.pos, h.radius + 6.0):
					if is_instance_valid(e) and e.alive and e.global_position.distance_to(h.pos) < h.radius + e.radius:
						e.take_damage(h.dps * TICK, h.pos, 0.0, {"kind": "fire", "burn": 1.5, "quiet": true})
			"gas":
				for p in GameManager.players:
					if is_instance_valid(p) and not p.downed and p.global_position.distance_to(h.pos) < h.radius:
						p.take_damage(h.dps * TICK, h.pos, true)
				for t in arena.towers:
					if is_instance_valid(t) and t.alive and t.global_position.distance_to(h.pos) < h.radius + 6.0:
						t.take_damage(h.dps * 1.4 * TICK, null)
						t.corrode(TICK)


# ------------------------------------------------------------------ drawing

## Dithered puff texture (solid core, checker mid, sparse rim) cached per radius.
static func _puff_tex(r: int) -> Texture2D:
	var key := "hz_puff_%d" % r
	if PixelArt.has_tex(key):
		return PixelArt.tex(key)
	var s := r * 2 + 2
	var img := PixelArt.new_img(s, s)
	var c := s / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / float(r)
			if d > 1.0:
				continue
			var on := false
			if d < 0.55:
				on = true
			elif d < 0.8:
				on = (x + y) % 2 == 0
			else:
				on = x % 2 == 0 and y % 2 == 0
			if on:
				img.set_pixel(x, y, Color.WHITE)
	return PixelArt.put(key, img)


## Little flame tongue frames (white; tinted when drawn).
static func _flame_tex(frame: int) -> Texture2D:
	var key := "hz_flame_%d" % frame
	if PixelArt.has_tex(key):
		return PixelArt.tex(key)
	var rows: Array
	match frame:
		0:
			rows = ["..o..", ".ooo.", ".oyo.", "oyyyo", "oyIyo", ".oyo."]
		1:
			rows = [".o...", ".oo..", "ooyo.", "oyyyo", "oyIyo", ".ooo."]
		_:
			rows = ["...o.", "..oo.", ".oyoo", "oyyyo", "oyIyo", ".ooo."]
	var img := PixelArt.from_ascii(rows, 0, {"o": PixelArt.C["i"], "y": PixelArt.C["y"], "I": PixelArt.C["I"]})
	return PixelArt.put(key, img)


func _draw() -> void:
	var shell_tex := PixelArt.tex("shell")
	var tms := Time.get_ticks_msec()
	for h in hazards:
		var fade: float = clampf(h.life / 1.0, 0.0, 1.0)
		match h.kind:
			"shells":
				for o in h.offsets:
					draw_texture(shell_tex, (h.pos + o).round(), Color(1, 1, 1, fade))
			"skid":
				var c: Color = Color(0.1, 0.06, 0.12, 0.5 * clampf(h.life / h.max_life * 2.0, 0.0, 1.0))
				var d: Vector2 = Vector2.from_angle(h.rot) * 2.0
				draw_line((h.pos - d).round(), (h.pos + d).round(), c, 1.0)
			"scorch":
				var a: float = 0.5 * clampf(h.life / h.max_life * 2.0, 0.0, 1.0)
				var pt: Texture2D = _puff_tex(int(h.radius))
				draw_texture(pt, (h.pos - pt.get_size() / 2.0).round(), Color(0.1, 0.06, 0.12, a))
			"fire":
				# glowing ember bed + 2-3 flickering flame tongues
				var glow: Texture2D = _puff_tex(maxi(3, int(h.radius * 0.7)))
				draw_texture(glow, (h.pos - glow.get_size() / 2.0).round(), Color(1.0, 0.45, 0.12, 0.35 * fade))
				var tongues: int = 2 + h.seed_i % 2
				for k in tongues:
					var fr: int = int(tms / 90 + h.seed_i + k * 7) % 3
					var ft: Texture2D = _flame_tex(fr)
					var off: Vector2 = Vector2((k - (tongues - 1) * 0.5) * 3.0, -2.0 - (k % 2))
					var sz: float = 0.7 + 0.3 * fade
					draw_set_transform((h.pos + off).round(), 0.0, Vector2(1, sz))
					draw_texture(ft, Vector2(-2, -6), Color(1, 1, 1, 0.85 * fade))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_top() -> void:
	var tms := Time.get_ticks_msec() * 0.001
	for h in hazards:
		if h.kind != "gas":
			continue
		var age: float = 1.0 - h.life / h.max_life
		var grow: float = clampf(age * 6.0, 0.35, 1.0)
		var fade: float = clampf(h.life / 1.2, 0.0, 1.0)
		# churning dithered puffs: dark core, bright highlights on top
		for i in 6:
			var a: float = h.rot + i * TAU / 6.0 + tms * (0.5 + 0.1 * (i % 3))
			var wob: float = 0.35 + 0.15 * sin(tms * 1.7 + i * 1.3 + h.seed_i)
			var o: Vector2 = Vector2.from_angle(a) * h.radius * wob * grow
			var r: int = int(h.radius * (0.42 + 0.12 * ((i + h.seed_i) % 3)) * grow)
			var pt: Texture2D = _puff_tex(maxi(3, r))
			var col: Color = Color(0.16, 0.55, 0.2, 0.42 * fade) if i % 2 == 0 else Color(0.27, 0.82, 0.24, 0.36 * fade)
			top.draw_texture(pt, (h.pos + o - pt.get_size() / 2.0).round(), col)
		var hl: Texture2D = _puff_tex(maxi(3, int(h.radius * 0.3 * grow)))
		top.draw_texture(hl, (h.pos + Vector2(-2, -4) - hl.get_size() / 2.0).round(), Color(0.67, 1.0, 0.39, 0.3 * fade))
		# rising bubbles that pop
		for b in 3:
			var cyc: float = fmod(tms * (0.8 + b * 0.2) + float(h.seed_i % 17) * 0.1 + b * 0.33, 1.0)
			var bx: float = h.pos.x + sin(tms * 2.0 + h.seed_i + b * 2.0) * h.radius * 0.5
			var by: float = h.pos.y + h.radius * 0.3 - cyc * h.radius * 1.2
			var bc: Color = Color(0.75, 1.0, 0.5, 0.8 * fade * (1.0 - cyc))
			if cyc < 0.85:
				top.draw_rect(Rect2(roundf(bx), roundf(by), 1, 1), bc)
			else:
				# pop: tiny cross
				top.draw_rect(Rect2(roundf(bx) - 1, roundf(by), 3, 1), bc)
				top.draw_rect(Rect2(roundf(bx), roundf(by) - 1, 1, 3), bc)
