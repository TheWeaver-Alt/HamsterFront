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
var _built_t := 0.0

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
	max_hp = base_max_hp()
	hp = max_hp
	brain.setup(self)
	refresh_range()
	add_to_group("towers")
	_built_t = 0.35


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
	var want := (at - (global_position + Vector2(0, -8))).angle()
	head_angle = rotate_toward(head_angle, want, turn_speed * delta)
	return absf(angle_difference(head_angle, want)) < 0.3


func muzzle(dist: float = 10.0) -> Vector2:
	return global_position + Vector2(0, -8) + Vector2.from_angle(head_angle) * dist


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if not alive:
		return
	anim_t += delta
	_built_t = maxf(0.0, _built_t - delta)
	corrode_t = maxf(0.0, corrode_t - delta)
	_flash = maxf(0.0, _flash - delta * 7.0)
	var mat := visual.material as ShaderMaterial
	mat.set_shader_parameter("flash", _flash)
	mat.set_shader_parameter("rainbow", 1.0 if is_overdrive() else 0.0)
	mat.set_shader_parameter("warp", 0.6 if corrode_t > 0.0 else 0.0)
	if GameManager.phase == "wave" or GameManager.phase == "build":
		brain.physics(delta)
	if is_overdrive() and randf() < 0.3:
		GameManager.arena.fx.particle(global_position + Vector2(randf_range(-8, 8), -4),
			Vector2(randf_range(-10, 10), -40), 0.5,
			[PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"]][randi() % 4], 1.0, -20.0, 1.0)
	visual.queue_redraw()


# ------------------------------------------------------------------ events

func take_damage(amount: float, _source = null) -> void:
	if not alive:
		return
	amount *= GameManager.gstats.g("tower_damage_taken_mult", 1.0)
	hp -= amount
	_flash = 0.8
	brain.on_damaged(amount)
	if hp <= 0.0:
		destroy()


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
	_built_t = 0.25
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
	JuiceManager.add_trauma(0.35)
	Sfx.play("explosion", 1.3, -4.0)
	brain.on_destroyed()
	destroyed.emit(self)
	arena.on_tower_destroyed(self)
	queue_free()


# ------------------------------------------------------------------ draw

func _draw_visual() -> void:
	var pop := 0.0
	if _built_t > 0.0:
		pop = -sin(_built_t / 0.35 * PI) * 4.0
	visual.draw_set_transform(Vector2(0, pop), 0.0, Vector2.ONE)
	# ground shadow + crate
	visual.draw_rect(Rect2(-10, 4, 20, 3), Color(0, 0, 0, 0.25))
	if brain.draws_base():
		visual.draw_texture(PixelArt.tex("tower_base_%d" % level), Vector2(-10, -6))
	brain.draw(visual)
	visual.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_overdrive():
		_draw_sugar_ring()
	# level pips
	for i in level:
		visual.draw_rect(Rect2(-5 + i * 4, 5, 2, 2), PixelArt.C["y"])
	if hp < max_hp:
		PixelArt.draw_bar(visual, Rect2(-8, 9, 16, 1), hp / max_hp,
			PixelArt.C["Z"] if hp > max_hp * 0.35 else PixelArt.C["r"], PixelArt.C["k"], false)
	if is_overdrive():
		var left := overcharge_timer.time_left / maxf(overcharge_timer.wait_time, 0.01)
		PixelArt.draw_bar(visual, Rect2(-8, 11, 16, 1), left, PixelArt.C["p"], PixelArt.C["k"], false)


## Orbiting candy sprinkles around an overdriven tower.
func _draw_sugar_ring() -> void:
	var cols := [PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["Z"], PixelArt.C["v"]]
	var n := 10
	for i in n:
		var a := anim_t * 3.0 + TAU * i / n
		var p := Vector2(cos(a) * 13.0, -6.0 + sin(a) * 5.0)
		var c: Color = cols[i % cols.size()]
		visual.draw_rect(Rect2(p.round(), Vector2(2 if i % 2 == 0 else 1, 1)), c)
