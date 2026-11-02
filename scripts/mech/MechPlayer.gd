class_name MechPlayer
extends CharacterBody2D
## A hamster-piloted junkyard mech. player_id 1/2 picks the input device from
## GameManager.player_devices and (by default) the chassis: P1 BRAWLER-01, P2 WHEELER-X.

signal went_down
signal revived

const BASE_STATS := {
	"brawler": {
		"max_hp": 140.0, "move_speed": 74.0, "sprint_mult": 1.6, "damage_mult": 1.0, "fire_rate_mult": 1.0,
		"pierce": 0.0, "extra_projectiles": 0.0, "pouch_capacity": 50.0, "pouch_slow": 0.4,
		"pickup_radius": 30.0, "heat_rate": 34.0, "heat_decay": 16.0, "alt_damage_mult": 1.0,
		"alt_size_mult": 1.0, "spit_damage_mult": 1.0, "revive_speed": 1.0, "lifesteal": 0.0,
		"seed_leak": 0.0, "damage_taken": 1.0, "vent_heal": 0.0, "spinout_bonus": 0.0,
	},
	"wheeler": {
		"max_hp": 100.0, "move_speed": 98.0, "sprint_mult": 1.55, "damage_mult": 1.0, "fire_rate_mult": 1.0,
		"pierce": 0.0, "extra_projectiles": 0.0, "pouch_capacity": 40.0, "pouch_slow": 0.4,
		"pickup_radius": 36.0, "heat_rate": 30.0, "heat_decay": 15.0, "alt_damage_mult": 1.0,
		"alt_size_mult": 1.0, "spit_damage_mult": 1.0, "revive_speed": 1.0, "lifesteal": 0.0,
		"seed_leak": 0.0, "damage_taken": 1.0, "vent_heal": 0.0, "spinout_bonus": 0.0,
	},
}
const NAMES := {"brawler": "BRAWLER-01", "wheeler": "WHEELER-X"}
const PLAYER_COLORS := [Color8(255, 150, 70), Color8(90, 200, 230)]

const REVIVE_BARKS := [
	"Get up, furball! Sleep when we're hibernating!",
	"Up! Up! The seeds need you!",
]
const OVERDRIVE_BARKS := ["WITNESS MY FLUFFY WRATH!", "SUGAR! RUSH! ENGAGED!"]
const SILO_LOW_BARK := "They're touching the good seeds! THE STRIPED ONES!"
const BANK_BARKS := ["Pthbbt! Deposited!", "Cheeks: emptied. Dignity: questionable."]
const SPIT_BARKS := ["PTOOOO!", "SEED STORM!", "TASTE MY HOARD!"]
const HURT_BARKS := ["Ow! My fluff!", "Hey! That's my good fur!", "Dented! I'm dented!"]
const WARP_BARKS := ["Whoa... the cheese... it SPEAKS...", "Which way is left?!", "Everything is GOUDA!"]

@export var player_id: int = 1

var chassis: String = "brawler"
var input: PlayerInput
var stats: StatBlock
var hp: float = 100.0
var downed := false
var down_t := 0.0
var revive_progress := 0.0
var owned_cards: Dictionary = {}
var selected_tower := 0
var facing := 1.0
var aim_dir := Vector2.RIGHT
var knock := Vector2.ZERO
var invuln := 0.0
var dumping := false
var buddy_active := false
var blood_brothers_t := 0.0
var invert_t := 0.0
var invert_cd := 14.0
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var ready_pressed := false
var context := ""              # current interaction prompt text
var context_ok := true

var _dump_acc := 0.0
var _dumped := 0
var _trail_t := 0.0
var _steam_t := 0.0
var _dash_hits: Array = []
var _hurt_bark_t := 0.0
var _spin_wander := Vector2.ZERO

@onready var pouch: CheekPouchComponent = $CheekPouchComponent
@onready var wheel: WheelHeatComponent = $WheelHeatComponent
@onready var weapon: WeaponMount = $WeaponMount
@onready var visual: Node2D = $Visual
@onready var overlay: Node2D = $Overlay


func setup(id: int, chassis_name: String, device: String) -> void:
	player_id = id
	chassis = chassis_name
	input = PlayerInput.new(device)
	stats = StatBlock.new(BASE_STATS[chassis])
	hp = stats.g("max_hp")


func _ready() -> void:
	if stats == null:
		setup(player_id, "brawler" if player_id == 1 else "wheeler", "kbm" if player_id == 1 else "pad0")
	pouch.mech = self
	wheel.mech = self
	wheel.vented.connect(_on_vented)
	wheel.spun_out.connect(_on_spun_out)
	weapon.position = Vector2(0, -14) if chassis == "brawler" else Vector2(0, -25)
	collision_layer = GameManager.L_PLAYERS
	collision_mask = GameManager.L_WORLD | GameManager.L_TOWERS
	overlay.draw.connect(_draw_overlay)
	add_to_group("players")


func get_bark_offset() -> float:
	return -40.0


func display_name() -> String:
	return NAMES.get(chassis, "MECH")


func color() -> Color:
	return PLAYER_COLORS[clampi(player_id - 1, 0, 1)]


# ------------------------------------------------------------------ stats helpers

func damage_mult() -> float:
	var m := stats.g("damage_mult")
	if buddy_active:
		m *= 1.25
	return m


func fire_rate_mult() -> float:
	var m := stats.g("fire_rate_mult")
	if blood_brothers_t > 0.0:
		m *= 1.5
	return m


func max_hp() -> float:
	return stats.g("max_hp")


func heal(amount: float) -> void:
	if downed:
		return
	hp = minf(max_hp(), hp + amount)


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if GameManager.phase == "draft":
		return
	input.update(self)
	pouch.tick(delta)
	_hurt_bark_t = maxf(0.0, _hurt_bark_t - delta)
	if downed:
		_process_downed(delta)
		visual.tick(delta)
		weapon.tick(delta, aim_dir, false, false, false)
		overlay.queue_redraw()
		return
	invuln = maxf(0.0, invuln - delta)
	blood_brothers_t = maxf(0.0, blood_brothers_t - delta)
	_process_warp(delta)
	var move := input.move
	if invert_t > 0.0:
		move = -move
	var sprinting := input.held("sprint") and move.length() > 0.1 and wheel.can_sprint()
	wheel.tick(delta, sprinting)
	# --- movement
	var speed := stats.g("move_speed") * pouch.speed_mult()
	if sprinting:
		speed *= stats.g("sprint_mult")
	if wheel.is_venting():
		speed *= 0.3
	var desired := move * speed
	if wheel.is_spinning():
		if randf() < 0.08 or _spin_wander == Vector2.ZERO:
			_spin_wander = Vector2.from_angle(randf() * TAU) * stats.g("move_speed") * 0.9
		desired = _spin_wander
	if dash_t > 0.0:
		dash_t -= delta
		desired = dash_dir * 330.0
		_dash_damage()
	velocity = desired + knock
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	# --- aim
	if input.aim_explicit:
		aim_dir = input.aim
	else:
		var target = GameManager.arena.nearest_enemy(global_position, 150.0) if GameManager.arena else null
		if target:
			aim_dir = ((target.global_position as Vector2) + Vector2(0, -4) - (global_position + Vector2(0, -14))).normalized()
		elif move.length() > 0.2:
			aim_dir = move.normalized()
	if wheel.is_spinning():
		aim_dir = Vector2.from_angle(visual.spin)
	if absf(aim_dir.x) > 0.15:
		facing = signf(aim_dir.x)
	# --- weapons (spinning out = wild uncontrolled fire if trigger held)
	var can_act := not wheel.is_venting() and dash_t <= 0.0
	weapon.tick(delta, aim_dir, input.held("fire"), input.just("alt"), can_act)
	# --- trails & steam
	_trail_t -= delta
	if sprinting and _trail_t <= 0.0:
		_trail_t = 0.06
		_on_sprint_trail()
	if wheel.is_redline() or wheel.is_venting():
		_steam_t -= delta
		if _steam_t <= 0.0:
			_steam_t = 0.05 if wheel.is_venting() else 0.25
			var vent_pos := global_position + (Vector2(-10 * facing, -26) if chassis == "brawler" else Vector2(0, -26))
			GameManager.arena.fx.steam(vent_pos, 6 if wheel.is_venting() else 2)
	# --- actions
	_process_actions(delta)
	visual.tick(delta)
	overlay.queue_redraw()


func _process_actions(delta: float) -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	if input.just("cycle"):
		selected_tower = (selected_tower + 1) % GameManager.TOWER_TYPES.size()
		Sfx.play("select")
	for i in 5:
		if input.just("sel%d" % (i + 1)):
			selected_tower = i
			Sfx.play("select")
	if input.just("vent"):
		wheel.vent()
	if input.just("spit"):
		_spit()
	# context
	var near_silo := global_position.distance_to(ArenaMap.SILO_CENTER) < 52.0
	var tower = arena.tower_near(global_position, 24.0)
	var pad: Vector2i = arena.free_pad_near(global_position, 14.0)
	context = ""
	context_ok = true
	if dumping:
		if not near_silo or pouch.amount <= 0:
			_finish_dump()
		else:
			_dump_acc += delta * 70.0
			while _dump_acc >= 1.0 and pouch.amount > 0:
				_dump_acc -= 1.0
				pouch.take(1)
				_dumped += 1
				GameManager.add_seeds(1)
				arena.fx.particle(global_position + Vector2(0, -20), (ArenaMap.SILO_CENTER + Vector2(0, -30) - global_position).normalized() * 160.0 + Vector2(randf_range(-20, 20), -40), 0.35, PixelArt.C["s"], 1.0, 120.0, 0.5)
			context = "BANKING... %d" % _dumped
	elif near_silo and pouch.amount > 0:
		context = "[%s] BANK %d SEEDS" % [input.glyph("interact"), pouch.amount]
		if input.just("interact"):
			dumping = true
			_dumped = 0
			_dump_acc = 0.0
	elif tower != null:
		if pouch.amount >= 10:
			context = "[%s] CRAM SEEDS: SUGAR RUSH!" % input.glyph("interact")
			if input.just("interact"):
				_cram(tower)
		elif tower.level < GameManager.MAX_TOWER_LEVEL:
			var c: int = GameManager.tower_cost(tower.kind, tower.level + 1)
			context = "[%s] UPGRADE LV%d  %d" % [input.glyph("build"), tower.level + 1, c]
			context_ok = GameManager.can_afford(c)
		else:
			context = "%s  MAX LV" % GameManager.TOWER_INFO[tower.kind]["short"]
		if input.just("build"):
			arena.try_upgrade(self, tower)
	elif pad != Vector2i(-1, -1):
		var kind: String = GameManager.TOWER_TYPES[selected_tower]
		var c := GameManager.tower_cost(kind)
		context = "[%s] BUILD %s %d  [%s]>" % [input.glyph("build"), GameManager.TOWER_INFO[kind]["short"], c, input.glyph("cycle")]
		context_ok = GameManager.can_afford(c)
		if input.just("build"):
			arena.try_build(self, pad, kind)
	elif pouch.is_full():
		context = "POUCH FULL! BANK AT SILO"
		context_ok = false
	if input.just("ready"):
		ready_pressed = true


func _finish_dump() -> void:
	dumping = false
	if _dumped > 0:
		Sfx.play("bank", 1.0)
		GameManager.arena.fx.float_text(ArenaMap.SILO_CENTER + Vector2(0, -40), "+%d" % _dumped, PixelArt.C["y"], 1.0, 20.0)
		GameManager.arena.silo_node.bump()
		if _dumped >= 25 and randf() < 0.5:
			JuiceManager.bark(self, BANK_BARKS[randi() % BANK_BARKS.size()])
	_dumped = 0


func _cram(tower) -> void:
	var n := pouch.take_all()
	tower.overcharge(n, self)
	JuiceManager.bark(self, OVERDRIVE_BARKS[0] if randf() < 0.7 else OVERDRIVE_BARKS[1], "hamster", true)
	Sfx.play("overdrive")
	JuiceManager.add_trauma(0.25)
	GameManager.arena.fx.burst(tower.global_position + Vector2(0, -10), 30,
		[PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["Z"]], 40, 140, 0.3, 0.8, 1.0, 60.0)


func _spit() -> void:
	if pouch.amount < 5:
		Sfx.play("deny", 1.0, -6.0)
		return
	var arena = GameManager.arena
	var n := pouch.take_all()
	var count := clampi(n, 10, 70)
	var dmg := (7.0 + n * 0.12) * stats.g("spit_damage_mult") * damage_mult()
	var origin := global_position + Vector2(0, -16)
	for i in count:
		var a := TAU * i / count + randf_range(-0.05, 0.05)
		var v := Vector2.from_angle(a) * randf_range(230.0, 330.0)
		arena.shots.fire(origin, v, dmg, {"kind": "shrapnel", "life": 0.5, "radius": 3.0, "knockback": 90.0,
			"pierce": 2, "owner": self})
	for e in arena.enemies_in_radius(origin, 48.0):
		if is_instance_valid(e) and e.alive:
			e.take_damage(dmg * 0.5, origin, 200.0, {"owner": self, "kind": "spit"})
	arena.fx.explosion(origin, 26.0, "fire")
	arena.fx.seed_shells(origin, 30)
	arena.fx.ring(origin, 60.0, PixelArt.C["w"], 0.35)
	JuiceManager.add_trauma(0.7)
	JuiceManager.hit_stop(0.09)
	JuiceManager.screen_flash(Color(1, 1, 0.8, 0.35), 0.12)
	Sfx.play("spit")
	JuiceManager.bark(self, SPIT_BARKS[randi() % SPIT_BARKS.size()], "hamster", true)


func _on_sprint_trail() -> void:
	var arena = GameManager.arena
	if chassis == "wheeler":
		arena.hazards.add("skid", global_position + Vector2(randf_range(-5, 5), 0), 2.0, 6.0)
		arena.hazards.add("fire", global_position, 6.0, 1.3, 16.0)
		if randf() < 0.5:
			arena.fx.fire(global_position, 2)
	else:
		arena.fx.steam(global_position + Vector2(-10 * facing, -26), 1)
		arena.fx.dust(global_position, 1)


func start_dash(dir: Vector2) -> void:
	dash_dir = dir
	dash_t = 0.2
	invuln = maxf(invuln, 0.25)
	_dash_hits.clear()


func _dash_damage() -> void:
	var arena = GameManager.arena
	arena.hazards.add("fire", global_position, 7.0, 1.6, 20.0)
	arena.fx.fire(global_position, 2)
	for e in arena.enemies_in_radius(global_position, 14.0):
		if is_instance_valid(e) and e.alive and not _dash_hits.has(e.get_instance_id()):
			_dash_hits.append(e.get_instance_id())
			e.take_damage(14.0 * stats.g("alt_damage_mult") * damage_mult(), global_position, 160.0, {"owner": self, "kind": "dash", "burn": 2.0})


func _process_warp(delta: float) -> void:
	if not stats.has_flag("warp_invert"):
		return
	invert_t = maxf(0.0, invert_t - delta)
	invert_cd -= delta
	if invert_cd <= 0.0:
		invert_cd = randf_range(12.0, 20.0)
		invert_t = 2.0
		JuiceManager.bark(self, WARP_BARKS[randi() % WARP_BARKS.size()], "hamster", true)
		GameManager.arena.fx.warp_sparks(global_position + Vector2(0, -16), 14)


# ------------------------------------------------------------------ damage / downed

func take_damage(amount: float, from_pos: Vector2 = Vector2.INF, quiet: bool = false) -> void:
	if downed or invuln > 0.0 or GameManager.phase == "draft":
		return
	amount *= stats.g("damage_taken")
	hp -= amount
	if not quiet:
		invuln = 0.2
		visual.hit_flash(1.0)
		JuiceManager.add_trauma(0.18)
		Sfx.play_var("hurt", 1.0, 0.1, -3.0)
		if from_pos != Vector2.INF:
			knock += (global_position - from_pos).normalized() * 120.0
		if _hurt_bark_t <= 0.0 and randf() < 0.25:
			_hurt_bark_t = 6.0
			JuiceManager.bark(self, HURT_BARKS[randi() % HURT_BARKS.size()])
	else:
		visual.hit_flash(0.35)
	if hp <= 0.0:
		_go_down()


func _go_down() -> void:
	hp = 0.0
	downed = true
	down_t = 0.0
	revive_progress = 0.0
	dumping = false
	dash_t = 0.0
	velocity = Vector2.ZERO
	var spill := int(pouch.amount / 2)
	pouch.take_all()
	var arena = GameManager.arena
	if spill > 0:
		arena.seeds.spawn(global_position, spill, 90.0)
	arena.fx.explosion(global_position + Vector2(0, -12), 18.0)
	arena.fx.burst(global_position + Vector2(0, -12), 16, [PixelArt.C["g"], PixelArt.C["W"], PixelArt.C["r"]], 60, 160, 0.3, 0.7, 1.0, 140.0)
	JuiceManager.add_trauma(0.6)
	JuiceManager.hit_stop(0.12)
	Sfx.play("downed")
	JuiceManager.bark(self, "Squeee! Mech down! MECH DOWN!", "hamster", true)
	GameManager.say("%s DOWN!" % display_name(), "STAND NEXT TO THEM TO REVIVE" if GameManager.is_coop() else "REBOOTING WHEEL...", color())
	went_down.emit()


func _process_downed(delta: float) -> void:
	down_t += delta
	velocity = knock
	knock = knock.move_toward(Vector2.ZERO, 400.0 * delta)
	move_and_slide()
	if randf() < 0.15:
		GameManager.arena.fx.smoke(global_position + Vector2(randf_range(-6, 6), -16), 1)
	var helper = null
	for p in GameManager.players:
		if p != self and is_instance_valid(p) and not p.downed and p.global_position.distance_to(global_position) < 24.0:
			helper = p
	if helper != null:
		var rate: float = helper.stats.g("revive_speed")
		if GameManager.gstats.has_flag("shared_cheeks"):
			rate *= 2.0
		revive_progress += delta * rate / 1.8
		if revive_progress >= 1.0:
			_revive(0.5, helper)
	else:
		revive_progress = maxf(0.0, revive_progress - delta * 0.5)
	var auto_time := 8.0 if GameManager.living_players().is_empty() or not GameManager.is_coop() else 16.0
	if down_t >= auto_time:
		_revive(0.4, null)


func _revive(frac: float, helper) -> void:
	downed = false
	hp = max_hp() * frac
	invuln = 1.5
	wheel.heat = 0.0
	wheel.spinout = 0.0
	Sfx.play("revive")
	GameManager.arena.fx.ring(global_position + Vector2(0, -12), 30.0, PixelArt.C["Z"], 0.4)
	GameManager.arena.fx.burst(global_position + Vector2(0, -12), 20, [PixelArt.C["z"], PixelArt.C["w"], PixelArt.C["y"]], 40, 120, 0.3, 0.7)
	if helper != null:
		JuiceManager.bark(helper, REVIVE_BARKS[0] if randf() < 0.75 else REVIVE_BARKS[1], "hamster", true)
	revived.emit()


func on_kill(_enemy: Node) -> void:
	var ls := stats.g("lifesteal")
	if ls > 0.0:
		heal(ls)


func on_card_applied(_card: Dictionary) -> void:
	hp = minf(hp, max_hp())


func _on_vented() -> void:
	var arena = GameManager.arena
	arena.fx.steam(global_position + Vector2(0, -14), 24)
	arena.fx.ring(global_position + Vector2(0, -10), 26.0, Color(1, 1, 1, 0.8), 0.3)
	for e in arena.enemies_in_radius(global_position, 28.0):
		if is_instance_valid(e) and e.alive:
			e.take_damage(8.0 * damage_mult(), global_position, 140.0, {"owner": self, "kind": "steam"})
	var vh := stats.g("vent_heal")
	if vh > 0.0:
		heal(vh)
	arena.on_player_vented(self)


func _on_spun_out() -> void:
	GameManager.arena.fx.burst(global_position + Vector2(0, -14), 10, [PixelArt.C["w"], PixelArt.C["y"]], 40, 100, 0.3, 0.6)


# ------------------------------------------------------------------ draw

func _draw() -> void:
	# ground shadow
	var w := 18.0 if chassis == "brawler" else 22.0
	draw_rect(Rect2(-w / 2.0, -2, w, 3), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(-w / 2.0 + 2, -3, w - 4, 1), Color(0, 0, 0, 0.18))


func _draw_overlay() -> void:
	var col := color()
	var tag := "P%d" % player_id
	var top := -44.0
	if downed:
		PixelArt.draw_text_centered(overlay, Vector2(0, top), "DOWN!", Color8(255, 90, 60))
		if revive_progress > 0.0:
			PixelArt.draw_bar(overlay, Rect2(-10, top + 8, 20, 2), revive_progress, PixelArt.C["Z"])
		return
	# player tag
	PixelArt.draw_text_centered(overlay, Vector2(0, top + 2), tag, col)
	# context prompt
	if context != "":
		var c := Color8(255, 248, 231) if context_ok else Color8(160, 152, 140)
		PixelArt.draw_text_centered(overlay, Vector2(0, top - 8), context, c)
	if wheel.is_redline() and int(Time.get_ticks_msec() / 150) % 2 == 0:
		PixelArt.draw_text_centered(overlay, Vector2(10, top + 2), "!!", Color8(255, 64, 40))
	# mouse reticle for the keyboard+mouse pilot
	if input != null and input.device == "kbm":
		var m := get_global_mouse_position() - global_position
		m = m.round()
		overlay.draw_rect(Rect2(m + Vector2(-4, 0), Vector2(3, 1)), col)
		overlay.draw_rect(Rect2(m + Vector2(2, 0), Vector2(3, 1)), col)
		overlay.draw_rect(Rect2(m + Vector2(0, -4), Vector2(1, 3)), col)
		overlay.draw_rect(Rect2(m + Vector2(0, 2), Vector2(1, 3)), col)
