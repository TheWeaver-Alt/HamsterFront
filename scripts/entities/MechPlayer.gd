class_name MechPlayer
extends CharacterBody2D
## A hamster pilot in a scrap-built mech.
## player_id 1 = BRAWLER-01 (keyboard + mouse, or gamepad 1)
## player_id 2 = WHEELER-X  (gamepad 0, or arrow-key cluster)

@export var player_id: int = 1

const ACCEL := 900.0
const SPRINT_MULT := 1.6
const SPIN_TIME := 1.5
const DASH_TIME := 0.18
const DASH_SPEED := 380.0
const REVIVE_TIME := 2.0
const BUILD_REACH := 120.0
const PIVOT := Vector2(0, -8)

var mech_kind := "brawler"
var prefix := "p1_"
var pad_device := 1
var hp := 100.0
var max_hp := 100.0
var base_speed := 90.0
var aim_dir := Vector2.RIGHT
var aim_world := Vector2.ZERO
var facing_dir := Vector2.RIGHT
var use_mouse := false
var active := false
var downed := false
var down_t := 0.0
var revive_progress := 0.0
var spin_t := 0.0
var spin_angle := 0.0
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var iframes := 0.0
var flash_t := 0.0
var knock_vel := Vector2.ZERO
var move_vel := Vector2.ZERO
var fire_boost_t := 0.0
var selected_bp := -1
var build_target := Vector2i(-1, -1)
var anim_t := 0.0
var walk_cycle := 0.0
var sprinting := false
var bubble_height := 32.0
var _trail_dist := 0.0
var _last_pos := Vector2.ZERO
var _move_input := Vector2.ZERO
var _smoke_t := 0.0
var _swore := false

@onready var pouch: CheekPouchComponent = $CheekPouchComponent
@onready var wheel: WheelHeatComponent = $WheelHeatComponent
@onready var weapon: WeaponMount = $WeaponMount


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Defs.L_MECH
	collision_mask = Defs.L_WORLD | Defs.L_TOWER | Defs.L_SILO
	prefix = "p%d_" % player_id
	mech_kind = "brawler" if player_id == 1 else "wheeler"
	pad_device = 1 if player_id == 1 else 0
	use_mouse = player_id == 1
	base_speed = 88.0 if mech_kind == "brawler" else 122.0
	material = Defs.flash_material()
	add_to_group("mechs")
	wheel.tripped.connect(_on_wheel_tripped)
	wheel.vented.connect(_on_wheel_vented)
	recalc_stats(true)
	_last_pos = global_position


func set_active(on: bool) -> void:
	active = on
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	collision_layer = Defs.L_MECH if on else 0
	if on:
		downed = false
		spin_t = 0.0
		recalc_stats(true)


func recalc_stats(full_heal: bool) -> void:
	var base := 140.0 if mech_kind == "brawler" else 95.0
	max_hp = base + GameManager.pmodf(player_id, "max_hp_bonus")
	if full_heal:
		hp = max_hp
	else:
		hp = minf(hp, max_hp)


func display_name() -> String:
	return "BRAWLER-01" if mech_kind == "brawler" else "WHEELER-X"


# --- Queries used by other systems -------------------------------------------------

func is_alive() -> bool:
	return active and not downed


func is_targetable() -> bool:
	return active and not downed


func can_collect() -> bool:
	return active and not downed and not pouch.is_full()


func collect_seed(v: int) -> bool:
	return pouch.add_seeds(v) > 0


func damage_mult() -> float:
	var m := GameManager.pmodf(player_id, "damage_mult")
	if GameManager.gmodb("buddy_bounce"):
		var o = _partner()
		if o != null and o.is_alive():
			var op: Vector2 = o.global_position
			if global_position.distance_to(op) < 56.0:
				m *= 1.25
	return m


func _partner():
	if GameManager.arena == null:
		return null
	return GameManager.arena.other_mech(self)


# --- Input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if player_id == 1 and event is InputEventMouseMotion:
		use_mouse = true
	elif event is InputEventJoypadMotion and event.device == pad_device:
		var jm := event as InputEventJoypadMotion
		if (jm.axis == JOY_AXIS_RIGHT_X or jm.axis == JOY_AXIS_RIGHT_Y) and absf(jm.axis_value) > 0.4:
			use_mouse = false


func _physics_process(delta: float) -> void:
	if not active:
		return
	anim_t += delta
	flash_t = maxf(0.0, flash_t - delta)
	iframes = maxf(0.0, iframes - delta)
	fire_boost_t = maxf(0.0, fire_boost_t - delta)
	knock_vel = knock_vel.move_toward(Vector2.ZERO, 600.0 * delta)
	(material as ShaderMaterial).set_shader_parameter("flash", 1.0 if flash_t > 0.0 else 0.0)
	modulate.a = 0.55 if (iframes > 0.0 and not downed and int(anim_t * 20.0) % 2 == 0) else 1.0
	if downed:
		_process_downed(delta)
		queue_redraw()
		return
	var game_over := GameManager.state == GameManager.State.GAME_OVER
	_move_input = Vector2.ZERO if game_over else Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	if _move_input.length() > 0.2:
		facing_dir = _move_input.normalized()
	_update_aim()
	if spin_t > 0.0:
		_process_spin(delta)
		queue_redraw()
		return
	sprinting = not game_over and Input.is_action_pressed(prefix + "sprint") and _move_input.length() > 0.1 and wheel.can_sprint()
	wheel.process_heat(delta, sprinting)
	if spin_t > 0.0:
		queue_redraw()
		return
	var spd := base_speed * GameManager.pmodf(player_id, "speed_mult") * pouch.speed_factor()
	if sprinting:
		spd *= SPRINT_MULT
	if wheel.is_venting():
		spd *= 0.55
	if dash_t > 0.0:
		dash_t -= delta
		move_vel = dash_dir * DASH_SPEED
	else:
		move_vel = move_vel.move_toward(_move_input * spd, ACCEL * delta)
	velocity = move_vel + knock_vel
	move_and_slide()
	_clamp_to_arena()
	walk_cycle += velocity.length() * delta * 0.25
	_wheeler_trail()
	_vent_fx()
	if not game_over:
		_handle_actions()
	_revive_partner(delta)
	queue_redraw()


func _update_aim() -> void:
	var eye := global_position + PIVOT
	if use_mouse:
		aim_world = get_global_mouse_position()
		var v := aim_world - eye
		if v.length() > 2.0:
			aim_dir = v.normalized()
		return
	var stick := Input.get_vector(prefix + "aim_left", prefix + "aim_right", prefix + "aim_up", prefix + "aim_down")
	if stick.length() > 0.3:
		aim_dir = stick.normalized()
	else:
		# No right stick (or keyboard P2): soft auto-aim at the nearest rat.
		var arena = GameManager.arena
		var r = null
		if arena != null:
			r = arena.nearest_rat(global_position, 150.0)
		if r != null:
			var to_r: Vector2 = r.global_position - eye
			aim_dir = to_r.normalized()
		elif _move_input.length() > 0.2:
			aim_dir = _move_input.normalized()
	aim_world = eye + aim_dir * 30.0


func _handle_actions() -> void:
	if Input.is_action_pressed(prefix + "fire"):
		weapon.try_primary(aim_dir)
	if Input.is_action_pressed(prefix + "alt"):
		weapon.try_alt(aim_dir, _move_input)
	if Input.is_action_just_pressed(prefix + "vent"):
		wheel.vent()
	if Input.is_action_just_pressed(prefix + "interact"):
		_interact()
	if Input.is_action_just_pressed(prefix + "spit"):
		pouch.spit(aim_dir)
	_handle_build_input()


func _interact() -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	var silo_d: float = arena.silo.distance_to_edge(global_position)
	if silo_d < 14.0:
		pouch.dump_to_silo(arena.silo)
		return
	var t = arena.nearest_tower(global_position, 26.0)
	if t != null:
		pouch.cram_into_tower(t)
		return
	JuiceManager.bark(self, "Bank at the Silo, or cram a tower!", false, "nointeract%d" % player_id, 3.0)


# --- Building ------------------------------------------------------------------

func _handle_build_input() -> void:
	var prev_bp := selected_bp
	if Input.is_action_just_pressed(prefix + "build_next"):
		selected_bp += 1
		if selected_bp > 4:
			selected_bp = -1
	if Input.is_action_just_pressed(prefix + "build_prev"):
		selected_bp -= 1
		if selected_bp < -1:
			selected_bp = 4
	if Input.is_action_just_pressed(prefix + "build_cancel"):
		selected_bp = -1
	if player_id == 1:
		for i in 5:
			if Input.is_action_just_pressed("p1_select_%d" % (i + 1)):
				selected_bp = -1 if selected_bp == i else i
	if selected_bp != prev_bp:
		SFX.play("card", 0.8 + 0.1 * selected_bp, -8.0)
		if selected_bp >= 0:
			var kind: int = Defs.TOWER_ORDER[selected_bp]
			JuiceManager.popup(global_position + Vector2(0, -40), "%s - %d" % [Defs.tower_short(kind), GameManager.tower_cost(kind)], Pal.SUNFLOWER, 0.7)
	_update_build_target()
	if selected_bp >= 0 and Input.is_action_just_pressed(prefix + "build_place"):
		_place_tower()


func selected_tower_kind() -> int:
	if selected_bp < 0:
		return -1
	return Defs.TOWER_ORDER[selected_bp]


func _update_build_target() -> void:
	build_target = Vector2i(-1, -1)
	if selected_bp < 0:
		return
	var arena = GameManager.arena
	if arena == null:
		return
	var c: Vector2i
	if use_mouse:
		c = arena.find_free_pad_near(aim_world, 14.0)
	else:
		c = arena.find_free_pad_near(global_position + facing_dir * 18.0, 40.0)
	if c.x >= 0:
		var wp: Vector2 = arena.cell_to_world(c)
		if wp.distance_to(global_position) > BUILD_REACH:
			c = Vector2i(-1, -1)
	build_target = c


func _place_tower() -> void:
	var arena = GameManager.arena
	if build_target.x < 0:
		JuiceManager.bark(self, "No free build pad there!", false, "nopad%d" % player_id, 2.0)
		SFX.play("error")
		return
	var kind := selected_tower_kind()
	var cost := GameManager.tower_cost(kind)
	if not GameManager.spend_seeds(cost):
		JuiceManager.bark(self, "Silo's short on seeds! Bank more!", false, "broke%d" % player_id, 2.5)
		SFX.play("error")
		return
	arena.build_tower(kind, build_target, player_id)
	if randf() < 0.25:
		JuiceManager.bark(self, "Hammer time! Hamster time!", false, "build", 8.0)


# --- Movement extras -------------------------------------------------------------

func apply_knock(v: Vector2) -> void:
	knock_vel += v


func start_dash(d: Vector2) -> void:
	dash_t = DASH_TIME
	dash_dir = d
	iframes = maxf(iframes, DASH_TIME)
	wheel.add_heat(12.0)


func _clamp_to_arena() -> void:
	global_position = global_position.clamp(Vector2(20, 20), Vector2(620, 346))


func _wheeler_trail() -> void:
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if mech_kind != "wheeler" or not (sprinting or dash_t > 0.0):
		_trail_dist = 0.0
		return
	_trail_dist += moved
	if _trail_dist >= 7.0:
		_trail_dist = 0.0
		var dps := 16.0 * GameManager.pmodf(player_id, "trail_damage_mult")
		GameManager.arena.spawn_ground(GroundEffect.Kind.TRAIL, global_position + Vector2(0, 2), 6.0, 2.5, dps, player_id)


func _vent_fx() -> void:
	var back := Vector2(-6.0 * signf(aim_dir.x + 0.001), -12)
	if wheel.is_venting():
		JuiceManager.particle(global_position + back, Vector2(randf_range(-20, 20), randf_range(-70, -40)), Pal.STEAM, 0.6, 3.0, -10.0)
	elif wheel.is_redline() and randf() < 0.35:
		JuiceManager.particle(global_position + back, Vector2(randf_range(-10, 10), -30), Color(Pal.HEAT, 0.7), 0.5, 2.0)


func _on_wheel_tripped() -> void:
	spin_t = SPIN_TIME
	_swore = false
	dash_t = 0.0
	JuiceManager.bark(self, "I HAVE LOST CONTROL OF THE CARDIO WHEEL!", false, "spin%d" % player_id, 2.0)
	JuiceManager.add_trauma(0.25)
	SFX.play("trip")


func _process_spin(delta: float) -> void:
	spin_t -= delta
	spin_angle += delta * 18.0
	move_vel = Vector2.from_angle(spin_angle * 0.35) * base_speed * 0.9
	velocity = move_vel + knock_vel
	move_and_slide()
	_clamp_to_arena()
	aim_dir = Vector2.from_angle(spin_angle)
	if randf() < 0.3:
		JuiceManager.particle(global_position + Vector2(0, -8), Vector2.from_angle(randf() * TAU) * 60.0, Pal.FIRE_HOT, 0.25, 1.0)
	if not _swore and spin_t < 0.8:
		_swore = true
		JuiceManager.popup(global_position + Vector2(0, -38), "SQUEAK-#@!%&!", Pal.HEAT, 0.8)
		SFX.play("squeak", 0.6, -2.0, 0)
	if spin_t <= 0.0:
		spin_t = 0.0
		spin_angle = 0.0


func _on_wheel_vented() -> void:
	SFX.play("steam", randf_range(0.9, 1.1), -4.0)
	JuiceManager.burst(global_position + Vector2(0, -12), Pal.STEAM, 22, 90.0, 0.7, 3.0, -40.0)
	if GameManager.gmodb("blood_brothers"):
		var o = _partner()
		if o != null and o.is_alive():
			o.fire_boost_t = 5.0
			var op: Vector2 = o.global_position
			JuiceManager.popup(op + Vector2(0, -38), "BLOOD BROTHERS! +50%", Pal.TIER_COOP)


# --- Damage, downing & revives -------------------------------------------------------

func take_damage(amount: float, _source = null) -> void:
	if not active or downed or iframes > 0.0:
		return
	hp -= amount
	flash_t = 0.1
	JuiceManager.add_trauma(clampf(0.08 + amount * 0.012, 0.0, 0.5))
	SFX.play("hurt", randf_range(0.9, 1.1), -4.0, 80)
	if hp <= 0.0:
		_go_down()


func heal(amount: float) -> void:
	if not active or downed:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp - before >= 1.0:
		JuiceManager.popup(global_position + Vector2(0, -36), "+%d" % int(hp - before), Pal.HP_GREEN, 0.6)


func _go_down() -> void:
	downed = true
	hp = 0.0
	var partner = _partner()
	down_t = 12.0 if (partner != null and partner.is_alive()) else 6.0
	revive_progress = 0.0
	spin_t = 0.0
	dash_t = 0.0
	selected_bp = -1
	pouch.spill()
	JuiceManager.burst(global_position + PIVOT, Pal.INK_SOFT, 20, 80.0, 0.8, 3.0, -30.0)
	JuiceManager.burst(global_position + PIVOT, Pal.METAL, 10, 120.0, 0.5, 2.0, 200.0)
	JuiceManager.add_trauma(0.4)
	JuiceManager.bark(self, "Squeak! Mech integrity... zero!", false, "", 0.0)
	SFX.play("rat_die", 0.6)


func _process_downed(delta: float) -> void:
	move_vel = Vector2.ZERO
	velocity = knock_vel
	move_and_slide()
	down_t -= delta
	revive_progress = maxf(0.0, revive_progress - delta * 0.5)
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = 0.15
		JuiceManager.particle(global_position + Vector2(randf_range(-4, 4), -10), Vector2(randf_range(-6, 6), -25), Color(0.3, 0.3, 0.3, 0.7), 1.0, 3.0)
	if down_t <= 0.0:
		revive(0.6, null)


func revive(frac: float, reviver: Node2D) -> void:
	if not downed:
		return
	downed = false
	hp = max_hp * frac
	iframes = 1.5
	revive_progress = 0.0
	if reviver != null:
		JuiceManager.bark(reviver, "Get up, furball! Sleep when we're hibernating!", false, "revive", 1.0)
	else:
		JuiceManager.bark(self, "Rebooted! Wheel... spinning... again!", false, "", 0.0)
	JuiceManager.ring(global_position + PIVOT, 22.0, Pal.HP_GREEN, 0.4)
	SFX.play("join", 1.2, -4.0)


func _revive_partner(delta: float) -> void:
	var o = _partner()
	if o == null or not o.downed:
		return
	var op: Vector2 = o.global_position
	if global_position.distance_to(op) < 24.0:
		o.revive_progress += delta * 1.5
		if o.revive_progress >= REVIVE_TIME:
			o.revive(0.5, self)


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var face := -1.0 if aim_dir.x < 0.0 else 1.0
	var tilt := 0.0
	if downed:
		tilt = 1.3 * face
	elif spin_t > 0.0:
		tilt = spin_angle
	draw_rect(Rect2(-8, 5, 16, 3), Pal.SHADOW)
	draw_set_transform(PIVOT, tilt, Vector2(face, 1.0))
	var aim_local := Vector2(absf(aim_dir.x), aim_dir.y)
	if tilt != 0.0:
		aim_local = Vector2.RIGHT
	if mech_kind == "brawler":
		_draw_brawler(aim_local)
	else:
		_draw_wheeler(aim_local)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlays()


func _draw_hamster(c: Vector2, fill: float) -> void:
	var r := 3.0 + fill * 2.5
	draw_rect(Rect2(roundf(c.x - r + 0.5), roundf(c.y - r - 1.0), 2, 2), Pal.HAMSTER_PINK)
	draw_rect(Rect2(roundf(c.x + r - 2.5), roundf(c.y - r - 1.0), 2, 2), Pal.HAMSTER_PINK)
	draw_circle(c.round(), r, Pal.HAMSTER)
	var cheek := 1.5 + fill * 2.5
	draw_circle((c + Vector2(-r + 1.0, 1.0)).round(), cheek, Pal.HAMSTER_LIGHT)
	draw_circle((c + Vector2(r - 1.0, 1.0)).round(), cheek, Pal.HAMSTER_LIGHT)
	if downed or spin_t > 0.0:
		draw_line(c + Vector2(-1, -2), c + Vector2(1, 0), Pal.INK, 1.0)
		draw_line(c + Vector2(1, -2), c + Vector2(-1, 0), Pal.INK, 1.0)
	else:
		draw_rect(Rect2(roundf(c.x), roundf(c.y - 1.0), 1, 1), Pal.INK)
		draw_rect(Rect2(roundf(c.x + 2.0), roundf(c.y - 1.0), 1, 1), Pal.INK)
	draw_rect(Rect2(roundf(c.x + r - 1.0), roundf(c.y), 1, 1), Pal.HAMSTER_PINK)
	if fill >= 1.0 and int(anim_t * 3.0) % 2 == 0:
		draw_rect(Rect2(roundf(c.x - r - 1.0), roundf(c.y - r), 1, 2), Pal.BEAM)


func _draw_brawler(aim_local: Vector2) -> void:
	var moving := velocity.length() > 5.0
	var s := sin(walk_cycle)
	var l1 := maxf(0.0, s) * 2.0 if moving else 0.0
	var l2 := maxf(0.0, -s) * 2.0 if moving else 0.0
	var b := roundf(absf(s)) if moving else 0.0
	# Legs.
	draw_rect(Rect2(-6, 2, 3, 6 - l1), Pal.METAL_DARK)
	draw_rect(Rect2(-7, 7 - l1, 5, 2), Pal.METAL)
	draw_rect(Rect2(3, 2, 3, 6 - l2), Pal.METAL_DARK)
	draw_rect(Rect2(2, 7 - l2, 5, 2), Pal.METAL)
	# Steam pipe.
	draw_rect(Rect2(-11, -9 - b, 2, 5), Pal.METAL)
	draw_rect(Rect2(-12, -10 - b, 4, 1), Pal.METAL_LIGHT)
	# Espresso-machine body.
	draw_rect(Rect2(-9, -11 - b, 18, 15), Pal.INK)
	draw_rect(Rect2(-8, -10 - b, 16, 13), Pal.ESPRESSO_RED)
	draw_rect(Rect2(-8, -10 - b, 16, 2), Pal.METAL_LIGHT)
	draw_rect(Rect2(-8, 1 - b, 16, 2), Pal.ESPRESSO_DARK)
	draw_rect(Rect2(-8, -5 - b, 7, 2), Pal.TAPE)
	draw_rect(Rect2(-6, -8 - b, 2, 8), Pal.TAPE)
	draw_rect(Rect2(-3, -2 - b, 6, 2), Pal.METAL_DARK)
	draw_rect(Rect2(3, -2 - b, 4, 1), Pal.INK)
	draw_circle(Vector2(4, -6 - b), 2.0, Pal.WHITE)
	var needle := Vector2.from_angle(-PI * 0.5 + wheel.ratio() * PI) * 2.0
	draw_line(Vector2(4, -6 - b), Vector2(4, -6 - b) + needle, Pal.ESPRESSO_RED, 1.0)
	# Cockpit dome.
	var dome := Vector2(0, -15 - b)
	draw_circle(dome, 6.0, Color(0.15, 0.25, 0.32, 0.9))
	_draw_hamster(dome + Vector2(0, 1), pouch.fill())
	draw_circle(dome, 6.0, Pal.GLASS)
	draw_arc(dome, 6.0, 0.0, TAU, 16, Pal.GLASS_EDGE, 1.0)
	draw_rect(Rect2(dome.x - 3, dome.y - 4, 2, 1), Pal.WHITE)
	draw_rect(Rect2(-6, -11 - b, 12, 1), Pal.METAL_DARK)
	# Cardboard-Tube Fist (back arm) - extends on punch.
	var shoulder := Vector2(-1, -6 - b)
	var ext := sin(weapon.punch_ratio() * PI) * 11.0
	var fist_end := shoulder + aim_local * (6.0 + ext)
	draw_line(shoulder, fist_end, Pal.CARDBOARD_DARK, 4.0)
	draw_line(shoulder, fist_end, Pal.CARDBOARD, 2.0)
	draw_circle(fist_end, 3.0, Pal.CARDBOARD_DARK)
	draw_circle(fist_end, 2.0, Pal.CARDBOARD)
	# Sawdust Shotgun (front arm).
	var gun_base := Vector2(5, -4 - b)
	var gun_tip := gun_base + aim_local * 11.0
	draw_line(gun_base, gun_tip, Pal.INK, 4.0)
	draw_line(gun_base, gun_tip, Pal.WOOD, 2.0)
	draw_circle(gun_tip, 1.5, Pal.METAL)
	if weapon.muzzle_t > 0.0:
		draw_circle(gun_tip + aim_local * 3.0, 4.0, Pal.FIRE_HOT)


func _draw_wheeler(aim_local: Vector2) -> void:
	var moving := velocity.length() > 5.0
	var b := roundf(absf(sin(walk_cycle * 2.0))) if moving else 0.0
	var bc := Vector2(0, -4 - b)
	# Spider legs.
	for i in 4:
		var side := -1.0 if i < 2 else 1.0
		var inner := float(i % 2)
		var lift := maxf(0.0, sin(walk_cycle * 1.5 + i * PI * 0.5)) * 2.0 if moving else 0.0
		var hip := bc + Vector2(side * (3.0 + inner * 2.0), 5.0)
		var knee := hip + Vector2(side * (4.0 + inner * 2.0), -5.0 - lift)
		var foot := Vector2(side * (9.0 + inner * 3.0), 8.0 - lift)
		draw_line(hip, knee, Pal.METAL_DARK, 1.0)
		draw_line(knee, foot, Pal.METAL_DARK, 1.0)
		draw_rect(Rect2(roundf(foot.x), roundf(foot.y), 1, 1), Pal.METAL_LIGHT)
		if sprinting and randf() < 0.2:
			draw_rect(Rect2(roundf(foot.x), roundf(foot.y) - 1, 1, 1), Pal.FIRE)
	# Mount ring.
	draw_rect(Rect2(bc.x - 5, bc.y + 6, 10, 2), Pal.METAL)
	# Glass hamster ball with pilot.
	draw_circle(bc, 8.0, Color(0.15, 0.25, 0.32, 0.85))
	draw_circle(bc + Vector2(0, 3), 4.0, Pal.HAMSTER)
	draw_rect(Rect2(bc.x - 2, bc.y + 4, 4, 2), Pal.HAMSTER_LIGHT)
	_draw_hamster(bc + Vector2(1, -2), pouch.fill())
	draw_circle(bc, 8.0, Pal.GLASS)
	draw_arc(bc, 8.0, 0.0, TAU, 20, Pal.GLASS_EDGE, 1.0)
	draw_rect(Rect2(bc.x - 5, bc.y - 5, 2, 1), Pal.WHITE)
	draw_rect(Rect2(bc.x - 6, bc.y - 3, 1, 2), Pal.WHITE)
	# Dual Toothpick Railguns.
	var perp := aim_local.orthogonal()
	for k in [-1.0, 1.0]:
		var base: Vector2 = bc + Vector2(0, -7) + perp * 2.0 * k
		var tip: Vector2 = base + aim_local * 13.0
		draw_line(base, tip, Pal.TOOTHPICK, 1.0)
		draw_rect(Rect2(roundf(base.x) - 1, roundf(base.y) - 1, 3, 2), Pal.COPPER)
	if weapon.muzzle_t > 0.0:
		var t2: Vector2 = bc + Vector2(0, -7) + aim_local * 15.0
		draw_circle(t2, 3.0, Pal.BEAM)


func _draw_overlays() -> void:
	var col := Pal.player_color(player_id)
	PixelFont.draw_centered(self, "P%d" % player_id, Vector2(0, -36), col, 1, Pal.INK)
	if wheel.is_redline() and int(anim_t * 8.0) % 2 == 0:
		PixelFont.draw_text(self, "!!", Vector2(6, -36), Pal.HEAT, 1, Pal.INK)
	if fire_boost_t > 0.0:
		draw_arc(PIVOT, 13.0, 0.0, TAU, 20, Color(Pal.TIER_COOP, 0.6), 1.0)
	if downed:
		var ratio := revive_progress / REVIVE_TIME
		draw_arc(PIVOT + Vector2(0, -14), 6.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 16, Pal.HP_GREEN, 2.0)
		PixelFont.draw_centered(self, "DOWN %d" % ceili(down_t), Vector2(0, -44), Pal.WHITE, 1, Pal.INK)
	if selected_bp >= 0:
		var kind := selected_tower_kind()
		var cost := GameManager.tower_cost(kind)
		var ok := GameManager.seeds >= cost
		var arena = GameManager.arena
		if build_target.x >= 0 and arena != null:
			var wp: Vector2 = arena.cell_to_world(build_target)
			var lp := (wp - global_position).round()
			var c := Pal.HP_GREEN if ok else Pal.BLOOD_BAR
			if int(anim_t * 6.0) % 2 == 0:
				c.a = 0.6
			draw_rect(Rect2(lp.x - 8, lp.y - 8, 16, 16), c, false, 1.0)
			draw_rect(Rect2(lp.x - 6, lp.y - 6, 12, 12), Color(c, 0.25))
			PixelFont.draw_centered(self, "%s %d" % [Defs.tower_short(kind), cost], lp + Vector2(0, -16), c, 1, Pal.INK)
		else:
			PixelFont.draw_centered(self, "NO PAD", Vector2(0, 12), Color(Pal.WHITE, 0.6), 1, Pal.INK)
	if use_mouse and GameManager.in_combat_state():
		var lp := (aim_world - global_position).round()
		draw_rect(Rect2(lp.x - 4, lp.y, 3, 1), col)
		draw_rect(Rect2(lp.x + 2, lp.y, 3, 1), col)
		draw_rect(Rect2(lp.x, lp.y - 4, 1, 3), col)
		draw_rect(Rect2(lp.x, lp.y + 2, 1, 3), col)
