class_name RatEnemy
extends CharacterBody2D
## Base Under-Scurrier. Follows the arena flow field to the Silo, gets distracted by
## decoys / nearby towers / mechs, and gnaws whatever it reaches.
## Per-kind behaviour lives in a RatBrain (scripts/enemies/brains/<Name>Brain.gd).

signal died(rat: RatEnemy)

const KINDS := {
	"squeaker": {"hp": 14.0, "speed": 40.0, "radius": 4.0, "bite": 4.0, "bite_rate": 0.7, "seeds": 2,
		"brain": "Squeaker", "mass": 1.0},
	"jezzail": {"hp": 34.0, "speed": 30.0, "radius": 6.0, "bite": 5.0, "bite_rate": 1.0, "seeds": 5,
		"brain": "Jezzail", "mass": 1.6},
	"monk": {"hp": 50.0, "speed": 29.0, "radius": 6.0, "bite": 6.0, "bite_rate": 1.0, "seeds": 6,
		"brain": "Monk", "mass": 1.6},
	"roomba": {"hp": 220.0, "speed": 62.0, "radius": 9.0, "bite": 0.0, "bite_rate": 1.0, "seeds": 14,
		"brain": "Roomba", "mass": 6.0},
	"ogre": {"hp": 760.0, "speed": 22.0, "radius": 12.0, "bite": 30.0, "bite_rate": 1.6, "seeds": 50,
		"brain": "Ogre", "mass": 12.0, "boss": true},
}

const SILO_BARKS := ["For the Great Horned Gouda! Munch-gnaw!", "Gnaw-gnaw! Seeds-seeds!", "Bucket-bucket is OURS!"]
const HIT_BARKS := ["Metal-fur-thing shoots! Scatter-flee!", "Ow-ow! Fur-thing bites back!", "Hide-hide! No-no! Charge-charge!"]
const FRIENDLY_FIRE_BARKS := ["Not me-me, you blind-fool!", "Watch-look where you roll-crash!", "Treachery-treason!"]

var kind: String = "squeaker"
var hp: float = 10.0
var max_hp: float = 10.0
var speed: float = 40.0
var radius: float = 4.0
var bite_dmg: float = 4.0
var bite_rate: float = 0.7
var seed_value: int = 2
var mass: float = 1.0
var is_boss := false
var alive := true

# status
var stun_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var melt := 0.0               # extra damage taken (water-laser armour melt), 0..1
var melt_t := 0.0
var trip_t := 0.0
var knock := Vector2.ZERO
var slow_mult := 1.0
var spawn_t := 0.0            # >0 while crawling out of a burrow

# AI
var target = null    # Node2D: silo stand-in is null + target_is_silo
var target_is_silo := true
var chewer := false           # personality: likes chewing nearby towers
var personal_offset := Vector2.ZERO
var bite_t := 0.0
var retarget_t := 0.0
var facing := 1.0
var anim_t := 0.0
var brain: RatBrain = null
var _flash := 0.0
var _sep := Vector2.ZERO
var _frame_i := 0
var _last_pos := Vector2.ZERO
var _stuck_t := 0.0
var _burn_fx_t := 0.0
var _silo_bark_done := false


func setup(k: String, hp_mult: float = 1.0, speed_mult: float = 1.0) -> void:
	kind = k
	var cfg: Dictionary = KINDS.get(k, KINDS["squeaker"])
	max_hp = float(cfg["hp"]) * hp_mult
	hp = max_hp
	speed = float(cfg["speed"]) * speed_mult * randf_range(0.9, 1.1)
	radius = float(cfg["radius"])
	bite_dmg = float(cfg["bite"]) * (1.0 + (hp_mult - 1.0) * 0.5)
	bite_rate = float(cfg["bite_rate"])
	seed_value = int(cfg["seeds"])
	mass = float(cfg["mass"])
	is_boss = cfg.get("boss", false)
	chewer = randf() < 0.25
	personal_offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	_frame_i = randi() % 3
	var path := "res://scripts/enemies/brains/%sBrain.gd" % cfg["brain"]
	if not ResourceLoader.exists(path):
		path = "res://scripts/enemies/brains/SqueakerBrain.gd"
	brain = load(path).new()


func _ready() -> void:
	collision_layer = GameManager.L_ENEMIES
	collision_mask = GameManager.L_WORLD | GameManager.L_RAT_BLOCK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CircleShape2D.new()
	shape.radius = maxf(2.5, radius * 0.75)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	material = PixelArt.make_flash_material()
	add_to_group("enemies")
	if brain == null:
		setup(kind)
	brain.setup(self)
	_last_pos = global_position


func get_bark_offset() -> float:
	return brain.get_bark_offset()


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_frame_i += 1
	anim_t += delta
	_flash = maxf(0.0, _flash - delta * 8.0)
	(material as ShaderMaterial).set_shader_parameter("flash", _flash)
	if spawn_t > 0.0:
		spawn_t -= delta
		queue_redraw()
		return
	# statuses
	if burn_t > 0.0:
		burn_t -= delta
		_apply_raw_damage(burn_dps * delta)
		_burn_fx_t -= delta
		if _burn_fx_t <= 0.0:
			_burn_fx_t = 0.12
			GameManager.arena.fx.fire(global_position + Vector2(randf_range(-3, 3), -6), 1)
		if not alive:
			return
	if melt_t > 0.0:
		melt_t -= delta
		if melt_t <= 0.0:
			melt = 0.0
	slow_mult = GameManager.arena.hazards.slow_factor(global_position) if (_frame_i % 4 == 0) else slow_mult
	stun_t = maxf(0.0, stun_t - delta)
	trip_t = maxf(0.0, trip_t - delta)
	bite_t = maxf(0.0, bite_t - delta)
	knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	if stun_t > 0.0 or trip_t > 0.0:
		velocity = knock
		move_and_slide()
	else:
		brain.physics(delta)
	if absf(velocity.x) > 3.0:
		facing = signf(velocity.x)
	queue_redraw()


## Default AI used by most brains: pick a target, walk there, gnaw it.
func default_ai(delta: float, speed_scale: float = 1.0) -> void:
	retarget_t -= delta
	if retarget_t <= 0.0 or (target != null and not _target_valid(target)):
		retarget_t = randf_range(0.35, 0.6)
		_pick_target()
	var spd := speed * slow_mult * speed_scale
	var reach := attack_reach()
	var dest: Vector2
	if target_is_silo or target == null:
		var d_silo := global_position.distance_to(ArenaMap.SILO_CENTER)
		if d_silo < ArenaMap.SILO_RADIUS + radius + 6.0:
			velocity = knock
			move_and_slide()
			_bite_silo()
			return
		dest = GameManager.arena.map.flow_waypoint(global_position)
		if dest == ArenaMap.SILO_CENTER:
			dest += personal_offset * 2.0
		else:
			dest += personal_offset
	else:
		var tpos: Vector2 = target.global_position
		if global_position.distance_to(tpos) <= reach + _target_radius(target):
			velocity = knock
			move_and_slide()
			_bite_target()
			return
		dest = tpos
	move_toward_point(dest, spd, delta)


func move_toward_point(dest: Vector2, spd: float, _delta: float) -> void:
	var dir := (dest - global_position)
	if dir.length() > 0.5:
		dir = dir.normalized()
	else:
		dir = Vector2.ZERO
	if _frame_i % 3 == 0:
		_sep = _separation()
	velocity = (dir + _sep * 0.9).normalized() * spd + knock if (dir + _sep).length() > 0.01 else knock
	move_and_slide()
	# unstick: if barely moving for a while, wiggle
	if _frame_i % 20 == 0:
		if global_position.distance_to(_last_pos) < 1.5 and spd > 1.0:
			_stuck_t += 0.33
			if _stuck_t > 1.0:
				knock += Vector2.from_angle(randf() * TAU) * 40.0
				target = null
				target_is_silo = true
				_stuck_t = 0.0
		else:
			_stuck_t = 0.0
		_last_pos = global_position


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for o in GameManager.arena.enemies_in_radius(global_position, radius + 8.0):
		if o == self or not is_instance_valid(o) or not o.alive:
			continue
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		var minl: float = radius + o.radius
		if l < minl and l > 0.01:
			push += d / l * (1.0 - l / minl) * clampf(o.mass / mass, 0.3, 3.0)
			brain.on_bump(o)
	return push


func attack_reach() -> float:
	return radius + 3.0


func _target_radius(t) -> float:
	if t is MechPlayer:
		return 7.0
	if "hit_radius" in t:
		return t.hit_radius
	return 6.0


func _target_valid(t) -> bool:
	if not is_instance_valid(t):
		return false
	if t is MechPlayer:
		return not t.downed
	if "alive" in t:
		return t.alive
	return true


func _pick_target() -> void:
	var arena = GameManager.arena
	target = null
	target_is_silo = true
	var decoy = arena.taunting_decoy(global_position)
	if decoy != null:
		target = decoy
		target_is_silo = false
		return
	for p in GameManager.players:
		if is_instance_valid(p) and not p.downed and p.stats.has_flag("rat_magnet") \
				and p.global_position.distance_to(global_position) < 130.0:
			target = p
			target_is_silo = false
			return
	if chewer:
		var t = arena.tower_near(global_position, 40.0)
		if t != null:
			target = t
			target_is_silo = false
			return
	var pl := GameManager.nearest_player(global_position, 22.0)
	if pl != null:
		target = pl
		target_is_silo = false


func _bite_target() -> void:
	if bite_t > 0.0 or bite_dmg <= 0.0:
		return
	bite_t = bite_rate
	if target is MechPlayer:
		target.take_damage(bite_dmg, global_position)
	elif target.has_method("take_damage"):
		target.take_damage(bite_dmg, self)
		Sfx.play_var("chew", 1.2, 0.2, -10.0)
	anim_t += 0.3


func _bite_silo() -> void:
	if bite_t > 0.0 or bite_dmg <= 0.0:
		return
	bite_t = bite_rate
	GameManager.damage_silo(bite_dmg)
	GameManager.arena.on_silo_hit(global_position)
	if not _silo_bark_done and randf() < 0.12:
		_silo_bark_done = true
		JuiceManager.bark(self, SILO_BARKS[0] if randf() < 0.6 else SILO_BARKS[randi() % SILO_BARKS.size()], "rat")


# ------------------------------------------------------------------ damage

## info keys: owner (killer for credit), kind (string), burn (seconds), stun (seconds),
## melt (0..1 armour shred), quiet (no flash/sfx spam), friendly (rat-on-rat)
func take_damage(amount: float, from_pos: Vector2 = Vector2.INF, knockback: float = 0.0, info: Dictionary = {}) -> void:
	if not alive:
		return
	amount *= 1.0 + melt
	amount = brain.modify_damage(amount, info)
	var quiet: bool = info.get("quiet", false)
	if not quiet:
		_flash = 1.0
	if knockback > 0.0 and from_pos != Vector2.INF:
		knock += (global_position - from_pos).normalized() * knockback / mass
	var burn: float = info.get("burn", 0.0)
	if burn > 0.0:
		burn_t = maxf(burn_t, burn)
		burn_dps = maxf(burn_dps, 6.0)
	var stun: float = info.get("stun", 0.0)
	if stun > 0.0:
		stun_t = maxf(stun_t, stun / (2.0 if is_boss else 1.0))
	var m: float = info.get("melt", 0.0)
	if m > 0.0:
		melt = minf(1.0, maxf(melt, m))
		melt_t = 2.0
	if info.get("friendly", false) and randf() < 0.35:
		JuiceManager.bark(self, FRIENDLY_FIRE_BARKS[0] if randf() < 0.7 else FRIENDLY_FIRE_BARKS[randi() % FRIENDLY_FIRE_BARKS.size()], "rat")
	elif not quiet and randf() < 0.025:
		JuiceManager.bark(self, HIT_BARKS[0] if randf() < 0.7 else HIT_BARKS[randi() % HIT_BARKS.size()], "rat")
	if not quiet and randf() < 0.3:
		Sfx.play_var("squeak_rat", 1.0 if not is_boss else 0.5, 0.15, -12.0)
	if amount >= 18.0 and not quiet:
		GameManager.arena.fx.float_text(global_position + Vector2(0, -14), str(int(amount)), Color8(255, 248, 231), 0.6, 10.0)
	brain.on_damaged(amount, info)
	_apply_raw_damage(amount, info)


func _apply_raw_damage(amount: float, info: Dictionary = {}) -> void:
	hp -= amount
	if hp <= 0.0 and alive:
		die(info)


func die(info: Dictionary = {}) -> void:
	if not alive:
		return
	alive = false
	var arena = GameManager.arena
	var n := int(roundf(seed_value * GameManager.gstats.g("seed_drop_mult", 1.0) * randf_range(0.8, 1.25)))
	arena.seeds.spawn(global_position + Vector2(0, -4), maxi(1, n), 60.0 + mass * 4.0)
	arena.fx.fur(global_position + Vector2(0, -4), 5 + int(mass * 2))
	arena.fx.warp_sparks(global_position + Vector2(0, -4), 4 + int(mass))
	Sfx.play_var("rat_die", 1.0 / sqrt(mass), 0.15, -6.0)
	GameManager.kills += 1
	var owner_node = info.get("owner", null)
	if owner_node != null and is_instance_valid(owner_node) and owner_node.has_method("on_kill"):
		owner_node.on_kill(self)
	brain.on_death(info)
	died.emit(self)
	arena.unregister_enemy(self)
	queue_free()


# ------------------------------------------------------------------ draw

func anim_frame() -> int:
	return int(anim_t * (6.0 + speed * 0.08)) % 2 if velocity.length() > 2.0 else 0


## Draws a RatArt sprite centred horizontally with its feet at the origin.
func draw_sprite(sprite_name: String, offset: Vector2 = Vector2.ZERO, modulate_c: Color = Color.WHITE) -> void:
	var t := PixelArt.tex(sprite_name)
	var sz := t.get_size()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	draw_texture(t, Vector2(-roundf(sz.x / 2.0), -sz.y + 1) + offset, modulate_c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	if spawn_t > 0.0:
		# crawling out of the burrow: only the head pokes out
		var t := PixelArt.tex("rat_squeaker_0")
		draw_texture_rect_region(t, Rect2(-8, -4, 16, 4), Rect2(2, 0, 16, 4))
		return
	draw_rect(Rect2(-radius, -1, radius * 2.0, 2), Color(0, 0, 0, 0.25))
	brain.draw(self)
	if stun_t > 0.0 or trip_t > 0.0:
		var a := anim_t * 8.0
		var top := Vector2(0, -radius * 2.0 - 8.0)
		for i in 3:
			var p := top + Vector2(cos(a + i * TAU / 3.0) * 5.0, sin(a + i * TAU / 3.0) * 1.5)
			draw_rect(Rect2(p.round(), Vector2(1, 1)), Color8(255, 214, 64))
	if melt > 0.0 and int(anim_t * 10.0) % 2 == 0:
		draw_rect(Rect2(-1, -radius * 2.0 - 3.0, 2, 1), Color8(90, 200, 230))
	if is_boss == false and hp < max_hp and max_hp >= 30.0:
		PixelArt.draw_bar(self, Rect2(-6, -radius * 2.0 - 6.0, 12, 1), hp / max_hp, Color8(170, 255, 100), Color8(26, 16, 32), false)
