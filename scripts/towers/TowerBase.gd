class_name TowerBase
extends StaticBody2D
## Modular turret on a build pad. Kind-specific behaviour lives in a TowerBrain
## (scripts/towers/brains/<Name>Brain.gd). Handles HP/armour, levels, gas corrosion and the
## Sugar Rush Overdrive (OverchargeTimer) triggered when a pilot crams cheek seeds in.

signal destroyed(tower: TowerBase)

const BRAINS := {
	"gatling": "Gatling", "laser": "Laser", "mortar": "Mortar", "tesla": "Tesla", "decoy": "Decoy",
}

var kind: String = "gatling"
var level: int = 1
var cell: Vector2i = Vector2i.ZERO
var hp: float = 100.0
var max_hp: float = 100.0
var alive := true
var hit_radius := 8.0
var head_angle := -PI / 2.0
var corrode_t := 0.0
var brain: TowerBrain = null
var enemies_in_range: Array = []
var anim_t := 0.0
var _flash := 0.0

# --- presentation (visual only)
const BUILD_TIME := 0.78      # crate drops in, then the head screws itself on
const DROP_TIME := 0.3
const DROP_HEIGHT := 46.0
const UPGRADE_TIME := 0.6
const RAINBOW_AMOUNT := 0.28  # Sugar Rush shader shimmer (kept low so the art stays readable)
var head: Node2D = null       # brains draw here; carries build/upgrade/overdrive transforms
var front: Node2D = null      # drawn over the head: front sprinkles, level pips, bars
var _build_t := 0.0
var _landed := false
var _upgrade_t := 99.0
var _hit_t := 0.0
var _smoke_t := 0.0
var _mat_cache: Array = [-1.0, -1.0, -1.0]
var _drips: Array = []        # [x, y, speed] corrosion drips sliding down the crate front
var _crate_key := -1          # crate layer only redraws when its look changes
var _front_key := -1

@onready var range_area: Area2D = $Range
@onready var range_shape: CollisionShape2D = $Range/CollisionShape2D
@onready var overcharge_timer: Timer = $OverchargeTimer
@onready var visual: Node2D = $Visual


func setup(k: String, c: Vector2i) -> void:
	kind = k
	cell = c
	position = ArenaMap.cell_center(c)
	var path := "res://scripts/towers/brains/%sBrain.gd" % BRAINS.get(k, "Gatling")
	if not ResourceLoader.exists(path):
		path = "res://scripts/towers/brains/GatlingBrain.gd"
	brain = load(path).new()


func _ready() -> void:
	if brain == null:
		setup(kind, cell)
	collision_layer = GameManager.L_TOWERS
	collision_mask = 0
	range_area.collision_layer = 0
	range_area.collision_mask = GameManager.L_ENEMIES
	range_area.monitorable = false
	range_shape.shape = range_shape.shape.duplicate()   # sub-resource is shared between instances
	range_area.body_entered.connect(_on_body_entered)
	range_area.body_exited.connect(_on_body_exited)
	overcharge_timer.one_shot = true
	overcharge_timer.timeout.connect(_on_overdrive_end)
	visual.material = PixelArt.make_flash_material()
	visual.draw.connect(_draw_visual)
	head = Node2D.new()
	head.name = "Head"
	head.use_parent_material = true
	head.draw.connect(_draw_head)
	visual.add_child(head)
	front = Node2D.new()
	front.name = "Front"
	front.draw.connect(_draw_front)
	visual.add_child(front)
	max_hp = base_max_hp()
	hp = max_hp
	brain.setup(self)
	refresh_range()
	add_to_group("towers")
	_build_t = 0.0
	_update_head_transform()
	_clear_mechs()


## A pilot builds from up to 14px away, which is inside the tower's solid 14x12 collider. Godot
## pushes an overlapped mech out the short way, and on a pad with a fence or cliff face a few
## pixels behind it that is into the wall: the mech ends up wedged between the two for good.
## So slide every overlapping mech sideways, to the nearest spot that is clear.
func _clear_mechs() -> void:
	var box := ($CollisionShape2D.shape as RectangleShape2D).size * 0.5
	var centre: Vector2 = $CollisionShape2D.global_position
	for m in GameManager.players:
		if not is_instance_valid(m) or m.flies():
			continue
		var body := m.get_node("CollisionShape2D") as CollisionShape2D
		var r := (body.shape as CircleShape2D).radius
		var d := (body.global_position - centre).abs() - box
		if Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0) >= r:
			continue
		var side := signf(body.global_position.x - centre.x)
		if side == 0.0:
			side = 1.0
		var reach := Vector2(box.x + r + 1.0, box.y + r + 1.0)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = body.shape
		q.collision_mask = GameManager.L_WORLD | GameManager.L_TOWERS | GameManager.L_CLIFF
		q.exclude = [m.get_rid()]
		for step: Vector2 in [Vector2(side, 0), Vector2(-side, 0), Vector2(0, -1), Vector2(0, 1)]:
			var dest := body.global_position
			if step.x != 0.0:
				dest.x = centre.x + step.x * reach.x
			else:
				dest.y = centre.y + step.y * reach.y
			q.transform = Transform2D(0.0, dest)
			if get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty():
				m.global_position += dest - body.global_position
				break


func base_max_hp() -> float:
	var m := float(GameManager.TOWER_INFO[kind]["hp"]) * GameManager.gstats.g("tower_hp_mult", 1.0)
	m *= 1.0 + 0.25 * (level - 1)
	if kind == "decoy":
		m *= GameManager.gstats.g("decoy_hp_mult", 1.0)
	return m


## Re-read global modifiers (called after a card changes them).
func refresh_stats() -> void:
	var old := max_hp
	max_hp = base_max_hp()
	if max_hp > old:
		hp += max_hp - old
	hp = minf(hp, max_hp)
	refresh_range()


func refresh_range() -> void:
	var cs := range_shape.shape as CircleShape2D
	if cs == null:
		cs = CircleShape2D.new()
		range_shape.shape = cs
	cs.radius = range_radius()


# ------------------------------------------------------------------ stat helpers

const HIGH_GROUND_RANGE := 1.15


func range_radius() -> float:
	return float(GameManager.TOWER_INFO[kind]["range"]) * (1.0 + 0.1 * (level - 1)) \
		* GameManager.gstats.g("tower_range_mult", 1.0) * brain.range_mult() * high_ground_mult(global_position)


## Towers on a plateau see further (+15% range).
static func high_ground_mult(pos: Vector2) -> float:
	var arena = GameManager.arena
	if arena != null and arena.map != null and arena.map.is_high_ground(pos):
		return HIGH_GROUND_RANGE
	return 1.0


func damage_mult() -> float:
	var m := GameManager.gstats.g("tower_damage_mult", 1.0) * (1.0 + 0.4 * (level - 1))
	if is_overdrive():
		m *= 1.5
	return m


func fire_rate_mult() -> float:
	var m := GameManager.gstats.g("tower_fire_rate_mult", 1.0) * (1.0 + 0.15 * (level - 1))
	if is_overdrive():
		m *= 2.0
	if corrode_t > 0.0:
		m *= 0.65
	return m


func is_overdrive() -> bool:
	return overcharge_timer != null and not overcharge_timer.is_stopped()


func taunt_radius() -> float:
	return brain.taunt_radius()


func get_bark_offset() -> float:
	return -32.0


## Adds a child canvas layer drawn above the y-sorted world (beams, arcs...).
## `draw_cb` is connected to the layer's draw signal; call layer.queue_redraw() each frame.
func add_fx_layer(draw_cb: Callable, z: int = 12) -> Node2D:
	var layer := Node2D.new()
	layer.z_index = z
	layer.name = "FxLayer"
	layer.draw.connect(draw_cb)
	add_child(layer)
	return layer


## Range radius a tower kind would have at a level (used for previews before it exists).
static func preview_radius(k: String, lvl: int = 1, world_pos: Vector2 = Vector2.INF) -> float:
	var r := float(GameManager.TOWER_INFO[k]["range"]) * (1.0 + 0.1 * (lvl - 1)) \
		* GameManager.gstats.g("tower_range_mult", 1.0)
	if world_pos != Vector2.INF:
		r *= high_ground_mult(world_pos)
	return r


## Dotted pixel range circle for a tower kind (build ghost / upgrade preview).
## Decoys show their taunt radius in pink.
## `world_pos` (optional) is the tower's spot in the arena, used for the high-ground bonus.
static func draw_range_preview(ci: CanvasItem, k: String, pos: Vector2, lvl: int = 1, world_pos: Vector2 = Vector2.INF) -> void:
	if not GameManager.TOWER_INFO.has(k):
		return
	var r := preview_radius(k, lvl, world_pos)
	var col := Color(1.0, 0.84, 0.25, 0.75)
	if k == "decoy":
		col = Color(1.0, 0.59, 0.71, 0.75)
	elif k == "mortar":
		# show the minimum range too
		_dotted_ring(ci, pos, 40.0, Color(1.0, 0.35, 0.25, 0.5), 3)
	_dotted_ring(ci, pos, r, col, 2)
	ci.draw_rect(Rect2(pos.round() - Vector2(1, 1), Vector2(2, 2)), col)


static func _dotted_ring(ci: CanvasItem, center: Vector2, r: float, col: Color, gap: int) -> void:
	var n := maxi(16, int(r * 2.2))
	var phase := int(Time.get_ticks_msec() / 120) % gap
	for i in n:
		if (i + phase) % gap != 0:
			continue
		var a := TAU * i / n
		ci.draw_rect(Rect2(roundf(center.x + cos(a) * r), roundf(center.y + sin(a) * r), 1, 1), col)


# ------------------------------------------------------------------ targeting

func _on_body_entered(b: Node) -> void:
	if b is RatEnemy and not enemies_in_range.has(b):
		enemies_in_range.append(b)


func _on_body_exited(b: Node) -> void:
	enemies_in_range.erase(b)


## Alive enemies inside range (exact distance check on top of the Area2D overlap).
func get_targets(r: float = -1.0) -> Array:
	if r < 0.0:
		r = range_radius()
	var out: Array = []
	var k := enemies_in_range.size() - 1
	while k >= 0:
		var e = enemies_in_range[k]
		if not is_instance_valid(e) or not e.alive:
			enemies_in_range.remove_at(k)
		elif e.spawn_t <= 0.0 and global_position.distance_to(e.global_position) <= r + e.radius:
			out.append(e)
		k -= 1
	return out


## mode: "first" (closest to the Silo along the flow field), "near", "strong"
func best_target(mode: String = "first", r: float = -1.0):
	var best = null
	var best_score := INF
	var map = GameManager.arena.map
	for e in get_targets(r):
		var score: float
		match mode:
			"near":
				score = global_position.distance_to(e.global_position)
			"strong":
				score = -e.hp
			_:
				score = float(map.dist_at(e.global_position)) + e.global_position.distance_to(ArenaMap.SILO_CENTER) * 0.1
		if score < best_score:
			best_score = score
			best = e
	return best


## Rotates the head towards a point; returns true when roughly aligned.
func aim_head(at: Vector2, delta: float, turn_speed: float = 10.0) -> bool:
	var want := (at - (global_position + brain.head_offset())).angle()
	head_angle = rotate_toward(head_angle, want, turn_speed * delta)
	return absf(angle_difference(head_angle, want)) < 0.3


func muzzle(dist: float = 10.0) -> Vector2:
	return global_position + brain.head_offset() + Vector2.from_angle(head_angle) * dist


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if not alive:
		return
	anim_t += delta
	corrode_t = maxf(0.0, corrode_t - delta)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_hit_t = maxf(0.0, _hit_t - delta)
	_upgrade_t += delta
	_tick_build(delta)
	_set_mat(0, "flash", snappedf(_flash, 0.05))
	_set_mat(1, "rainbow", RAINBOW_AMOUNT if is_overdrive() else 0.0)
	_set_mat(2, "warp", 0.22 if corrode_t > 0.0 else 0.0)
	if _build_t >= DROP_TIME and (GameManager.phase == "wave" or GameManager.phase == "build"):
		brain.physics(delta)
	_tick_fx(delta)
	_update_head_transform()
	head.queue_redraw()
	# the crate and front layers are mostly static: redraw only while animating or on change
	var od := is_overdrive()
	var building := _build_t < BUILD_TIME
	var stage := 2 if hp < max_hp * 0.25 else (1 if hp < max_hp * 0.5 else 0)
	var ck := level * 10 + stage
	if building or od or not _drips.is_empty() or ck != _crate_key:
		_crate_key = ck if not building else -1
		visual.queue_redraw()
	var fk := level * 100000 + int(hp) * 2 + (1 if building else 0)
	if od or fk != _front_key:
		_front_key = fk
		front.queue_redraw()


func _set_mat(i: int, param: String, v: float) -> void:
	if not is_equal_approx(float(_mat_cache[i]), v):
		_mat_cache[i] = v
		(visual.material as ShaderMaterial).set_shader_parameter(param, v)


## Build-in timeline: crate (or decoy) falls, lands with a thud, then the head pops on.
func _tick_build(delta: float) -> void:
	if _build_t >= BUILD_TIME:
		return
	_build_t += delta
	if not _landed and _build_t >= DROP_TIME:
		_landed = true
		var fx = GameManager.arena.fx
		fx.dust(global_position + Vector2(-8, 4), 4)
		fx.dust(global_position + Vector2(8, 4), 4)
		fx.burst(global_position + Vector2(0, 4), 8, [PixelArt.C["t"], PixelArt.C["T"], PixelArt.C["c"]],
			30, 80, 0.2, 0.45, 1.0, 140.0, 4.0, Vector2(0, -1), 1.2)
		JuiceManager.add_trauma(0.07)
		Sfx.play("punch", 0.55, -6.0)


func _tick_fx(delta: float) -> void:
	var fx = GameManager.arena.fx
	# upgrade: a spiral of sparkles climbing the tower
	if _upgrade_t < 0.45 and randf() < 0.8:
		var a := _upgrade_t * 22.0
		var p := global_position + Vector2(cos(a) * 11.0, -2.0 - _upgrade_t * 50.0 + sin(a) * 3.0)
		fx.particle(p, Vector2(0, -20), 0.45, [PixelArt.C["y"], PixelArt.C["w"], PixelArt.C["Z"]][randi() % 3], 1.0, -10.0, 2.0)
	# sugar rush: candy sprinkles fountain up
	if is_overdrive() and randf() < 0.25:
		fx.particle(global_position + Vector2(randf_range(-9, 9), -6),
			Vector2(randf_range(-14, 14), randf_range(-60, -35)), 0.6,
			[PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["w"]][randi() % 5], 1.0, 90.0, 0.8)
	# heavy damage: smoke + the odd spark
	if hp < max_hp * 0.25:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = randf_range(0.22, 0.4)
			fx.smoke(global_position + Vector2(randf_range(-7, 7), -10), 1)
			if randf() < 0.3:
				fx.sparks(global_position + Vector2(randf_range(-8, 8), -4), Color8(255, 214, 64), 2)
	# corrosion: green drips run down the crate front
	if corrode_t > 0.0 and _drips.size() < 3 and randf() < 0.1:
		_drips.append([randi_range(-10, 9), randf_range(-1.0, 1.0), randf_range(5.0, 11.0)])
	var k := _drips.size() - 1
	while k >= 0:
		var d: Array = _drips[k]
		d[1] = float(d[1]) + float(d[2]) * delta
		if float(d[1]) > 7.0:
			_drips.remove_at(k)
		k -= 1


## Head node transform: build pop + screw-in wobble, upgrade bounce, sugar-rush squash, hit jitter.
func _update_head_transform() -> void:
	var pos := Vector2.ZERO
	var sc := Vector2.ONE
	var rot := 0.0
	if _build_t < BUILD_TIME:
		if not brain.draws_base():
			pos.y = -_drop_offset()
			if _build_t >= DROP_TIME:
				var k0 := clampf((_build_t - DROP_TIME) / 0.18, 0.0, 1.0)
				sc = Vector2(1.0 + 0.18 * (1.0 - k0), 1.0 - 0.22 * (1.0 - k0))
		elif _build_t < DROP_TIME + 0.02:
			sc = Vector2.ZERO
		else:
			var k := clampf((_build_t - DROP_TIME) / (BUILD_TIME - DROP_TIME), 0.0, 1.0)
			var el := 1.0 - pow(2.0, -9.0 * k) * cos(k * PI * 3.2)
			sc = Vector2(lerpf(0.5, 1.0, k) * el, el)
			rot = sin(k * PI * 3.0) * (1.0 - k) * 0.35
	if _upgrade_t < UPGRADE_TIME:
		var u := _upgrade_t / UPGRADE_TIME
		var b := 1.0 + 0.3 * sin(u * PI * 2.5) * (1.0 - u)
		sc *= Vector2(b, b)
	if is_overdrive():
		var w := sin(anim_t * 13.0)
		sc *= Vector2(1.0 + 0.06 * w, 1.0 - 0.06 * w)
	if _hit_t > 0.0:
		pos.x += float(randi_range(-1, 1))
	# only touch the node when something changed (setting transforms invalidates the canvas item)
	if head.position != pos:
		head.position = pos
	if head.scale != sc:
		head.scale = sc
	if head.rotation != rot:
		head.rotation = rot


func _drop_offset() -> float:
	if _build_t >= DROP_TIME:
		return 0.0
	var p := _build_t / DROP_TIME
	return DROP_HEIGHT * (1.0 - p * p)


# ------------------------------------------------------------------ events

func take_damage(amount: float, _source = null) -> void:
	if not alive:
		return
	amount *= GameManager.gstats.g("tower_damage_taken_mult", 1.0)
	hp -= amount
	_flash = maxf(_flash, 0.8)
	_hit_t = 0.12
	brain.on_damaged(amount)
	if hp <= 0.0:
		destroy()


## Brief whole-tower white flash (e.g. a tesla discharge). Visual only.
func flash_pulse(amount: float) -> void:
	_flash = maxf(_flash, amount)


func corrode(dt: float) -> void:
	corrode_t = maxf(corrode_t, 0.4 + dt)


func repair(frac: float) -> void:
	hp = minf(max_hp, hp + max_hp * frac)


func overcharge(seeds: int, by = null) -> void:
	var dur := GameManager.gstats.g("overdrive_duration", 10.0)
	dur += clampf((seeds - 10) * 0.05, 0.0, 4.0)   # bigger crams last a bit longer
	overcharge_timer.start(dur)
	repair(0.5)
	_flash = 1.0
	GameManager.arena.fx.ring(global_position + Vector2(0, -8), 34.0, PixelArt.C["y"], 0.4)
	GameManager.arena.fx.float_text(global_position + Vector2(0, -26), "SUGAR RUSH!", PixelArt.C["p"], 1.2, 14.0)
	brain.on_overdrive()


func _on_overdrive_end() -> void:
	if alive:
		GameManager.arena.fx.float_text(global_position + Vector2(0, -24), "CRASH...", PixelArt.C["g"], 0.9, 8.0)


func upgrade() -> void:
	level = mini(level + 1, GameManager.MAX_TOWER_LEVEL)
	refresh_stats()
	hp = max_hp
	_flash = 1.0
	_upgrade_t = 0.0
	var fx = GameManager.arena.fx
	fx.ring(global_position + Vector2(0, -6), 26.0, PixelArt.C["Z"], 0.35)
	fx.burst(global_position + Vector2(0, -6), 18, [PixelArt.C["y"], PixelArt.C["w"], PixelArt.C["Z"]], 40, 120, 0.3, 0.6, 1.0, 80.0)
	fx.float_text(global_position + Vector2(0, -24), "LV %d!" % level, PixelArt.C["Z"], 1.0, 14.0)
	brain.on_upgrade()


func destroy() -> void:
	if not alive:
		return
	alive = false
	var arena = GameManager.arena
	arena.fx.explosion(global_position + Vector2(0, -6), 16.0)
	arena.fx.burst(global_position, 20, [PixelArt.C["t"], PixelArt.C["T"], PixelArt.C["b"]], 40, 140, 0.4, 0.9, 2.0, 160.0)
	arena.hazards.add("scorch", global_position, 9.0, 20.0)
	# splintered crate + the head flying off, as a short-lived debris node in the y-sorted world
	var debris := _Debris.new()
	debris.position = global_position
	arena.world.add_child(debris)
	debris.launch(brain.debris_texture(), brain.draws_base())
	JuiceManager.add_trauma(0.35)
	Sfx.play("explosion", 1.3, -4.0)
	brain.on_destroyed()
	destroyed.emit(self)
	arena.on_tower_destroyed(self)
	queue_free()


# ------------------------------------------------------------------ draw

## Crate layer (under the head): ground shadow, crate with drop/land squash, cracks, drips,
## and the back half of the sugar-rush sprinkle ring.
func _draw_visual() -> void:
	var off := _drop_offset()
	# ground shadow shrinks while the crate is still in the air
	var sw := 12.0 * (1.0 - off / (DROP_HEIGHT * 1.6))
	_draw_ellipse(visual, Vector2(0, 5), sw, 2.6, Color(0, 0, 0, 0.28))
	if is_overdrive():
		_draw_sprinkles(visual, false)
	if not brain.draws_base():
		return
	var sy := 1.0
	var sx := 1.0
	if _landed and _build_t < DROP_TIME + 0.16:
		var k := (_build_t - DROP_TIME) / 0.16
		sy = 1.0 - 0.2 * (1.0 - k)
		sx = 1.0 + 0.12 * (1.0 - k)
	visual.draw_set_transform(Vector2(0, -off + 6.0 - 6.0 * sy), 0.0, Vector2(sx, sy))
	visual.draw_texture(PixelArt.tex("tower_base_%d" % level), Vector2(-12, -9))
	var stage := 0
	if hp < max_hp * 0.25:
		stage = 2
	elif hp < max_hp * 0.5:
		stage = 1
	if stage > 0:
		visual.draw_texture(PixelArt.tex("tower_cracks_%d" % stage), Vector2(-12, -9))
	for d in _drips:
		var dx: int = d[0]
		var dy := roundf(float(d[1]))
		visual.draw_rect(Rect2(dx, dy, 1, 2), Color8(120, 230, 80, 220))
		visual.draw_rect(Rect2(dx, dy - 1, 1, 1), Color8(70, 160, 50, 160))
	visual.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_head() -> void:
	brain.draw(head)


## Over the head: front sprinkles, level pips, HP + overdrive bars.
func _draw_front() -> void:
	if is_overdrive():
		_draw_sprinkles(front, true)
	if _build_t < BUILD_TIME:
		return
	# level pips: little gold diamonds under the crate
	var n := level
	var x0 := -(n - 1) * 2.5
	for i in n:
		var p := Vector2(roundf(x0 + i * 5.0), 8.0)
		front.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), PixelArt.C["Y"])
		front.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), PixelArt.C["Y"])
		front.draw_rect(Rect2(p, Vector2(1, 1)), PixelArt.C["y"])
	if hp < max_hp:
		var frac := hp / max_hp
		var col := PixelArt.C["Z"]
		if frac < 0.5:
			col = PixelArt.C["y"]
		if frac < 0.25:
			col = PixelArt.C["r"] if int(anim_t * 6.0) % 2 == 0 else PixelArt.C["i"]
		PixelArt.draw_bar(front, Rect2(-8, 11, 16, 1), frac, col, PixelArt.C["k"], false)
	if is_overdrive():
		var left := overcharge_timer.time_left / maxf(overcharge_timer.wait_time, 0.01)
		PixelArt.draw_bar(front, Rect2(-8, 13, 16, 1), left, PixelArt.C["p"], PixelArt.C["k"], false)


## Orbiting candy sprinkles; back half drawn behind the tower, front half in front.
func _draw_sprinkles(ci: Node2D, front_half: bool) -> void:
	var cols := [PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["w"], PixelArt.C["Z"]]
	var n := 12
	for i in n:
		var a := anim_t * 3.2 + TAU * i / n
		if (sin(a) >= 0.0) != front_half:
			continue
		var bob := sin(anim_t * 6.0 + i) * 1.5
		var p := Vector2(cos(a) * 14.0, -8.0 + sin(a) * 5.0 + bob)
		var c: Color = cols[i % cols.size()]
		if i % 2 == 0:
			ci.draw_rect(Rect2(p.round(), Vector2(2, 1)), c)
		else:
			ci.draw_rect(Rect2(p.round(), Vector2(1, 2)), c)


static func _draw_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var ri := int(ceilf(ry))
	for dy in range(-ri, ri + 1):
		var fy := (dy + 0.5) / ry
		if absf(fy) > 1.0:
			continue
		var hw := roundf(rx * sqrt(1.0 - fy * fy))
		if hw > 0:
			ci.draw_rect(Rect2(roundf(center.x - hw), roundf(center.y) + dy, hw * 2.0, 1), col)


## Splinters + head flying off when a tower is destroyed. Pieces bounce, settle, then fade.
class _Debris extends Node2D:
	var pieces: Array = []
	var life := 0.0

	func launch(head_tex: Texture2D, with_crate: bool) -> void:
		if with_crate:
			for i in 10:
				var ang := randf() * TAU
				pieces.append({"tex": PixelArt.tex("tower_debris_%d" % (i % 4)),
					"p": Vector2(randf_range(-7, 7), randf_range(-3, 3)), "z": randf_range(2.0, 8.0),
					"v": Vector2.from_angle(ang) * randf_range(25.0, 75.0), "vz": randf_range(70.0, 150.0),
					"rot": randf() * TAU, "vr": randf_range(-16.0, 16.0), "rest": false})
		if head_tex != null:
			pieces.append({"tex": head_tex, "p": Vector2.ZERO, "z": 12.0,
				"v": Vector2(randf_range(-45, 45), randf_range(-12, 12)), "vz": 170.0,
				"rot": 0.0, "vr": randf_range(-9.0, 9.0) + 3.0, "rest": false})

	func _process(delta: float) -> void:
		life += delta
		for pc in pieces:
			if pc["rest"]:
				continue
			pc["vz"] = float(pc["vz"]) - 420.0 * delta
			pc["z"] = float(pc["z"]) + float(pc["vz"]) * delta
			pc["p"] = (pc["p"] as Vector2) + (pc["v"] as Vector2) * delta
			pc["rot"] = float(pc["rot"]) + float(pc["vr"]) * delta
			if float(pc["z"]) <= 0.0:
				pc["z"] = 0.0
				if absf(float(pc["vz"])) > 45.0:
					pc["vz"] = -float(pc["vz"]) * 0.38
					pc["v"] = (pc["v"] as Vector2) * 0.5
					pc["vr"] = float(pc["vr"]) * 0.5
				else:
					pc["rest"] = true
					pc["rot"] = roundf(float(pc["rot"]) / (PI * 0.5)) * PI * 0.5
		modulate.a = clampf((4.5 - life) / 1.0, 0.0, 1.0)
		if life > 4.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for pc in pieces:
			var p: Vector2 = pc["p"]
			var z: float = pc["z"]
			draw_rect(Rect2(p.round() + Vector2(-1, 0), Vector2(3, 1)), Color(0, 0, 0, 0.22))
			var tex: Texture2D = pc["tex"]
			draw_set_transform((p - Vector2(0, z)).round(), float(pc["rot"]), Vector2.ONE)
			draw_texture(tex, -(tex.get_size() / 2.0).round())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
