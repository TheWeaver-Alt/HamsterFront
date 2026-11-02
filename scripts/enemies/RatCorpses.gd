extends Node2D
## Lingering death animations for Under-Scurriers — purely visual. RatEnemy.die() hands a snapshot
## to this node (created lazily under the arena's y-sorted World) and frees itself immediately;
## everything here just plays out the fall, twitch, explode and ghost-rising, then fades.
## One node draws every corpse in a single pass; ghosts draw on a child above everything.

const MAX_CORPSES := 90
const MAX_GHOSTS := 24

class Corpse:
	var kind: String = "squeaker"
	var variant: int = 0
	var pos: Vector2
	var vel: Vector2
	var z: float = 0.0
	var vz: float = 0.0
	var t: float = 0.0
	var life: float = 1.3
	var facing: float = 1.0
	var spin: float = 0.0
	var stage: int = 0          # per-kind progress marker (landed, exploded, ...)
	var extra: Dictionary = {}

class Ghost:
	var pos: Vector2
	var t: float = 0.0
	var life: float = 1.2
	var sprite: String = "rat_sq_ghost"
	var scale: float = 1.0
	var phase: float = 0.0

var corpses: Array = []
var ghosts: Array = []
var _ghost_layer: Node2D


func _ready() -> void:
	_ghost_layer = Node2D.new()
	_ghost_layer.name = "Ghosts"
	_ghost_layer.z_index = 25
	_ghost_layer.z_as_relative = false
	_ghost_layer.draw.connect(_draw_ghosts)
	add_child(_ghost_layer)


## data: {kind, variant, pos, facing, knock, vel}
func add_corpse(data: Dictionary) -> void:
	if corpses.size() >= MAX_CORPSES:
		corpses.pop_front()
	var c := Corpse.new()
	c.kind = String(data.get("kind", "squeaker"))
	c.variant = int(data.get("variant", 0))
	c.pos = data.get("pos", Vector2.ZERO)
	c.facing = float(data.get("facing", 1.0))
	var knock: Vector2 = data.get("knock", Vector2.ZERO)
	var vel: Vector2 = data.get("vel", Vector2.ZERO)
	match c.kind:
		"squeaker":
			c.life = 1.35
			c.vz = randf_range(65.0, 90.0)
			c.vel = knock.limit_length(60.0) * 0.6 + Vector2(randf_range(-12, 12), 0)
			if randf() < 0.55:
				_add_ghost(c.pos, "rat_sq_ghost", 1.0, 0.4)
		"jezzail":
			c.life = 1.6
			c.vz = 55.0
			c.vel = knock.limit_length(40.0) * 0.5
			c.extra = {"rifle_pos": c.pos + Vector2(0, -10), "rifle_vel": Vector2(c.facing * randf_range(30, 50), 0),
				"rifle_z": 4.0, "rifle_vz": 110.0}
			_add_ghost(c.pos + Vector2(-6, 0), "rat_sq_ghost", 1.0, 0.45)
			_add_ghost(c.pos + Vector2(6, 0), "rat_sq_ghost", 1.0, 0.6)
		"monk":
			c.life = 1.8
			c.vel = Vector2.ZERO
			_add_ghost(c.pos, "rat_monk_ghost", 1.0, 0.35)
		"roomba":
			c.life = 2.6
			c.vel = vel.limit_length(90.0)
		"ogre":
			c.life = 3.0
			c.vel = Vector2.ZERO
			_add_ghost(c.pos + Vector2(-c.facing * 10.0, -6), "rat_sq_ghost", 2.0, 1.0)
		_:
			c.life = 1.2
	corpses.append(c)


func _add_ghost(pos: Vector2, sprite: String, scale: float, delay: float) -> void:
	if ghosts.size() >= MAX_GHOSTS:
		return
	var g := Ghost.new()
	g.pos = pos
	g.sprite = sprite
	g.scale = scale
	g.t = -delay
	g.life = 1.2 + 0.3 * scale
	g.phase = randf() * TAU
	ghosts.append(g)


func _process(delta: float) -> void:
	var k := corpses.size() - 1
	while k >= 0:
		var c: Corpse = corpses[k]
		c.t += delta
		_tick(c, delta)
		if c.t >= c.life:
			corpses.remove_at(k)
		k -= 1
	k = ghosts.size() - 1
	while k >= 0:
		var g: Ghost = ghosts[k]
		g.t += delta
		if g.t >= g.life:
			ghosts.remove_at(k)
		k -= 1
	queue_redraw()
	_ghost_layer.queue_redraw()


func _tick(c: Corpse, delta: float) -> void:
	var arena = GameManager.arena
	match c.kind:
		"squeaker", "jezzail":
			if c.stage == 0:
				c.vz -= 420.0 * delta
				c.z = maxf(0.0, c.z + c.vz * delta)
				c.pos += c.vel * delta
				if c.z <= 0.0 and c.t > 0.05:
					c.stage = 1
					if arena != null and is_instance_valid(arena):
						arena.fx.dust(c.pos, 2)
			else:
				c.vel = c.vel.move_toward(Vector2.ZERO, 200.0 * delta)
			if c.kind == "jezzail":
				var rz: float = c.extra["rifle_z"]
				var rvz: float = c.extra["rifle_vz"]
				rvz -= 380.0 * delta
				rz = rz + rvz * delta
				if rz <= 0.0:
					rz = 0.0
					rvz = -rvz * 0.3 if absf(rvz) > 40.0 else 0.0
					c.extra["rifle_vel"] = (c.extra["rifle_vel"] as Vector2) * 0.5
				c.extra["rifle_z"] = rz
				c.extra["rifle_vz"] = rvz
				c.extra["rifle_pos"] = (c.extra["rifle_pos"] as Vector2) + (c.extra["rifle_vel"] as Vector2) * delta
		"roomba":
			c.pos += c.vel * delta
			c.vel = c.vel.move_toward(Vector2.ZERO, 120.0 * delta)
			c.spin += delta * (24.0 * maxf(0.0, 1.0 - c.t / 0.8))
			if c.stage == 0 and arena != null and is_instance_valid(arena):
				if randf() < 0.35:
					arena.fx.sparks(c.pos + Vector2(randf_range(-8, 8), -8), Color8(170, 255, 100), 2)
				if randf() < 0.2:
					arena.fx.smoke(c.pos + Vector2(0, -10), 1)
			if c.stage == 0 and c.t >= 0.75:
				c.stage = 1
				_roomba_boom(c)
		"ogre":
			if c.stage == 0 and c.t >= 0.48:
				c.stage = 1
				if arena != null and is_instance_valid(arena):
					arena.fx.dust(c.pos + Vector2(-c.facing * 18.0, 0), 12)
					arena.fx.ring(c.pos + Vector2(-c.facing * 14.0, 0), 22.0, PixelArt.C["T"], 0.3)
				JuiceManager.add_trauma(0.3)
				Sfx.play("punch", 0.45, -2.0)


func _roomba_boom(c: Corpse) -> void:
	var arena = GameManager.arena
	if arena == null or not is_instance_valid(arena):
		return
	var p := c.pos + Vector2(0, -6)
	arena.fx.explosion(p, 18.0, "warp")
	arena.fx.burst(p, 14, [PixelArt.C["g"], PixelArt.C["W"], PixelArt.C["G"]], 50, 150, 0.3, 0.7, 1.0, 180.0)
	arena.hazards.add("scorch", c.pos, 12.0, 10.0)
	JuiceManager.add_trauma(0.18)
	Sfx.play("explosion", 1.35, -6.0)
	_add_ghost(c.pos + Vector2(0, -8), "rat_sq_ghost", 1.0, 0.0)


func _fade(c: Corpse, fade_time: float) -> float:
	return clampf((c.life - c.t) / fade_time, 0.0, 1.0)


## Draws a texture with its bottom-centre at `feet` (flipped by facing).
func _blit(tex_name: String, feet: Vector2, facing: float, a: float, lift: float = 0.0) -> void:
	var tex := PixelArt.tex(tex_name)
	var sz := tex.get_size()
	draw_set_transform(feet.round() - Vector2(0, roundf(lift)), 0.0, Vector2(facing, 1))
	draw_texture(tex, Vector2(-roundf(sz.x / 2.0), -sz.y + 1), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadow(p: Vector2, w: float, a: float) -> void:
	draw_rect(Rect2(p.round() + Vector2(-roundf(w / 2.0), -1), Vector2(roundf(w), 2)), Color(0.05, 0.03, 0.08, 0.22 * a))


func _draw() -> void:
	for cc in corpses:
		var c: Corpse = cc
		match c.kind:
			"squeaker":
				var a := _fade(c, 0.4)
				_shadow(c.pos, 8.0, a)
				var name: String
				if c.stage == 0:
					var ph := c.t / 0.36
					if ph < 0.33:
						name = "rat_sq_%d_hit_0" % c.variant
					elif ph < 0.66:
						name = "rat_sq_%d_tumble_0" % c.variant
					else:
						name = "rat_sq_%d_dead_0" % c.variant
				else:
					var tw := 1 if (c.t < 0.85 and int(c.t * 10.0) % 2 == 0) else 0
					name = "rat_sq_%d_dead_%d" % [c.variant, tw]
				_blit(name, c.pos, c.facing, a, c.z)
			"jezzail":
				var a2 := _fade(c, 0.45)
				_shadow(c.pos, 20.0, a2)
				_blit("rat_jez_dead_0" if c.stage > 0 or c.t > 0.15 else "rat_jez_recoil_0", c.pos, c.facing, a2, c.z)
				var rp: Vector2 = c.extra["rifle_pos"]
				var rz: float = c.extra["rifle_z"]
				var spin_f := int(c.t * 14.0) % 4 if rz > 0.5 else 0
				_blit("rat_jez_rifle_%d" % spin_f, rp, c.facing, a2, rz)
			"monk":
				var a3 := _fade(c, 0.5)
				_shadow(c.pos, 12.0, a3)
				if c.t < 0.12:
					_blit("rat_monk_chant_0", c.pos, c.facing, a3)
				else:
					_blit("rat_monk_dead_0", c.pos, c.facing, a3)
					# the cheese flail rolls away
					var cp := c.pos + Vector2(c.facing * minf(c.t * 30.0, 12.0), -2)
					draw_rect(Rect2(cp.round() + Vector2(-2, -2), Vector2(5, 4)), Color(PixelArt.C["k"], a3))
					draw_rect(Rect2(cp.round() + Vector2(-1, -1), Vector2(3, 2)), Color(PixelArt.C["y"], a3))
					draw_rect(Rect2(cp.round() + Vector2(0, -1), Vector2(1, 1)), Color(PixelArt.C["Z"], a3))
			"roomba":
				var a4 := _fade(c, 0.8)
				_shadow(c.pos, 20.0, a4)
				if c.stage == 0:
					_blit("rat_roomba_%d" % (int(c.spin) % 4), c.pos + Vector2(randi_range(-1, 1), 0), c.facing, a4)
				else:
					_blit("rat_roomba_wreck", c.pos, c.facing, a4)
			"ogre":
				var a5 := _fade(c, 0.7)
				var name2 := "rat_ogre_dead_0"
				if c.t < 0.16:
					name2 = "rat_ogre_fall_0"
				elif c.t < 0.32:
					name2 = "rat_ogre_fall_1"
				elif c.t < 0.48:
					name2 = "rat_ogre_fall_2"
				_shadow(c.pos + Vector2(-c.facing * 12.0, 0), 34.0, a5)
				var tex := PixelArt.tex(name2)
				var sz := tex.get_size()
				draw_set_transform(c.pos.round() + Vector2(0, 3), 0.0, Vector2(c.facing, 1))
				draw_texture(tex, -(sz / 2.0).round(), Color(1, 1, 1, a5))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				_blit("rat_sq_0_dead_0", c.pos, c.facing, _fade(c, 0.4))


func _draw_ghosts() -> void:
	for gg in ghosts:
		var g: Ghost = gg
		if g.t < 0.0:
			continue
		var u := g.t / g.life
		var a := clampf(1.0 - u, 0.0, 1.0) * clampf(g.t / 0.15, 0.0, 1.0) * 0.9
		var rise := (1.0 - pow(1.0 - u, 2.0)) * (22.0 * g.scale)
		var wob := roundf(sin(g.t * 6.0 + g.phase) * 2.0)
		var tex := PixelArt.tex("%s_%d" % [g.sprite, int(g.t * 5.0) % 2])
		var sz := tex.get_size() * g.scale
		var p := (g.pos + Vector2(wob - sz.x / 2.0, -sz.y - rise)).round()
		_ghost_layer.draw_texture_rect(tex, Rect2(p, sz), false, Color(1, 1, 1, a))
