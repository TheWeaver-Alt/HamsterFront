extends Node
## GameManager — run state: wave, Silo HP, banked seeds, phase, players, global modifiers.

signal seeds_changed(amount: int)
signal silo_changed(hp: float, max_hp: float)
signal wave_changed(wave: int)
signal phase_changed(phase: String)
signal announce(text: String, sub: String, color: Color)
signal game_over_triggered

const TILE := 16
const MAP_W := 40
const MAP_H := 22

# Collision layer bits
const L_WORLD := 1
const L_RAT_BLOCK := 2
const L_PLAYERS := 4
const L_ENEMIES := 8
const L_TOWERS := 16
const L_CLIFF := 32        # cliff edges/faces: block walkers; jetpacking mechs ignore them

const TOWER_TYPES := ["gatling", "laser", "mortar", "tesla", "decoy"]
const TOWER_INFO := {
	"gatling": {"name": "SUNFLOWER GATLING", "short": "GATLING", "cost": 30, "hp": 120.0, "range": 92.0,
		"desc": "RAPID HULL SPITTER. SHELL PILES SLOW RATS."},
	"laser": {"name": "WATER-BOTTLE LASER", "short": "LASER", "cost": 50, "hp": 100.0, "range": 112.0,
		"desc": "CONTINUOUS ARMOR-MELTING SUNBEAM."},
	"mortar": {"name": "CEDAR-SHAVING MORTAR", "short": "MORTAR", "cost": 60, "hp": 110.0, "range": 176.0,
		"desc": "LOBS SNEEZING POWDER. STUNS PACKS."},
	"tesla": {"name": "EXERCISE-WHEEL TESLA", "short": "TESLA", "cost": 70, "hp": 130.0, "range": 76.0,
		"desc": "CHAIN LIGHTNING. RUN NEXT TO IT TO SPIN IT FASTER."},
	"decoy": {"name": "CARDBOARD DECOY HAMSTER", "short": "DECOY", "cost": 20, "hp": 180.0, "range": 88.0,
		"desc": "GOOGLY-EYED CUTOUT. TAUNTS RATS."},
}
const MAX_TOWER_LEVEL := 3

# --- persistent between runs (title screen settings)
var num_players: int = 1
var player_devices: Array = ["kbm", "pad0"]
var p1_chassis: String = "brawler"
## Learning Mode level per player slot: 0 off, 1 counting (age 4-6), 2 add/sub to 10 (age 6),
## 3 add/sub to 20 (age 7-8). Gates card activation + tower upgrades behind a MathQuiz.
var learning_levels: Array = [0, 0]
## "kid" (tougher Silo, slower/weaker rats, more seeds) or "normal".
var difficulty: String = "normal"
const LEARNING_NAMES := ["OFF", "COUNTING", "MATHS TO 10", "MATHS TO 20"]

# --- run state
var wave: int = 0
var silo_hp: float = 1500.0
var silo_max_hp: float = 1500.0
var seeds: int = 0
var phase: String = "title"          # title | build | wave | draft | gameover
var run_active: bool = false
var kills: int = 0
var seeds_banked_total: int = 0
var run_time: float = 0.0
var gstats: StatBlock
var owned_cards: Dictionary = {}     # card id -> times taken (any player)
var math_stars: int = 0              # Learning Mode: correct answers this run
var math_asked: int = 0

# --- live references (set by MainArena)
var arena = null   # MainArena (untyped: accessed dynamically)
var players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gstats = _make_gstats()


## F11 / Alt+Enter: toggle fullscreen <-> 1280x720 window (works everywhere, even paused).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: InputEventKey = event
	if k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := Vector2i(1280, 720)
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.window_get_current_screen()
		var origin := DisplayServer.screen_get_position(screen) + (DisplayServer.screen_get_size(screen) - size) / 2
		DisplayServer.window_set_position(origin)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _make_gstats() -> StatBlock:
	return StatBlock.new({
		"tower_cost_mult": 1.0, "tower_damage_mult": 1.0, "tower_fire_rate_mult": 1.0,
		"tower_hp_mult": 1.0, "tower_damage_taken_mult": 1.0, "tower_range_mult": 1.0,
		"overdrive_duration": 10.0, "mortar_radius_mult": 1.0, "mortar_stun_bonus": 0.0,
		"tesla_chain_bonus": 0.0, "shell_slow_mult": 1.0, "shell_life_mult": 1.0,
		"decoy_hp_mult": 1.0, "tower_wave_repair": 0.0, "laser_beams": 1.0,
	})


func new_run() -> void:
	wave = 0
	silo_max_hp = 2200.0 if difficulty == "kid" else 1500.0
	silo_hp = silo_max_hp
	seeds = 130 if difficulty == "kid" else 90
	math_stars = 0
	math_asked = 0
	kills = 0
	seeds_banked_total = 0
	run_time = 0.0
	owned_cards.clear()
	gstats = _make_gstats()
	players.clear()
	run_active = true
	set_phase("build")
	seeds_changed.emit(seeds)
	silo_changed.emit(silo_hp, silo_max_hp)


func _process(delta: float) -> void:
	if run_active and phase != "draft" and phase != "gameover" and not get_tree().paused:
		run_time += delta


func set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)


func is_coop() -> bool:
	return num_players >= 2


## Learning Mode level (0 = off) for a MechPlayer.
func learning_level(player) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var i: int = player.player_id - 1
	return int(learning_levels[i]) if i >= 0 and i < learning_levels.size() else 0


## Enemy multipliers for the chosen difficulty.
func enemy_hp_mult() -> float:
	return 0.7 if difficulty == "kid" else 1.0


func enemy_speed_mult() -> float:
	return 0.8 if difficulty == "kid" else 1.0


# ------------------------------------------------------------------ economy

func tower_cost(kind: String, level: int = 1) -> int:
	var base: float = TOWER_INFO[kind]["cost"]
	var mult := gstats.g("tower_cost_mult", 1.0)
	if level <= 1:
		return maxi(1, int(roundf(base * mult)))
	return maxi(1, int(roundf(base * 0.75 * (level - 1) * mult)))


func add_seeds(n: int) -> void:
	seeds += n
	if n > 0:
		seeds_banked_total += n
	seeds_changed.emit(seeds)


func can_afford(n: int) -> bool:
	return seeds >= n


func spend(n: int) -> bool:
	if seeds < n:
		return false
	seeds -= n
	seeds_changed.emit(seeds)
	return true


# ------------------------------------------------------------------ silo

func damage_silo(amount: float) -> void:
	if phase == "gameover" or not run_active:
		return
	silo_hp = maxf(0.0, silo_hp - amount)
	silo_changed.emit(silo_hp, silo_max_hp)
	if silo_hp <= 0.0:
		trigger_game_over()


func heal_silo(amount: float) -> void:
	silo_hp = minf(silo_max_hp, silo_hp + amount)
	silo_changed.emit(silo_hp, silo_max_hp)


func trigger_game_over() -> void:
	if phase == "gameover":
		return
	run_active = false
	set_phase("gameover")
	game_over_triggered.emit()


func say(text: String, sub: String = "", color: Color = Color8(255, 214, 64)) -> void:
	announce.emit(text, sub, color)


# ------------------------------------------------------------------ helpers

func living_players() -> Array:
	var out: Array = []
	for p in players:
		if is_instance_valid(p) and not p.downed:
			out.append(p)
	return out


func nearest_player(pos: Vector2, max_dist: float = INF, include_downed: bool = false) -> Node2D:
	var best: Node2D = null
	var bd := max_dist
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.downed and not include_downed:
			continue
		var d: float = pos.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = p
	return best


static func tile_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))
