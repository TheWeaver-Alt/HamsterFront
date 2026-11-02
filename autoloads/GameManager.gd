extends Node
## Global game state: wave, Silo HP, banked seeds, pause state,
## joined players and the per-player / global stat-modifier dictionaries.

signal seeds_changed(amount: int)
signal silo_hp_changed(hp: float, max_hp: float)
signal silo_destroyed
signal wave_changed(wave: int)
signal state_changed(new_state: int)
signal player_joined(player_id: int)
signal pause_changed(paused: bool)

enum State { TITLE, PREP, WAVE, DRAFT, GAME_OVER }

const START_SEEDS := 60
const SILO_BASE_HP := 800.0
const FIRST_PREP_TIME := 20.0
const PREP_TIME := 12.0

var state: int = State.TITLE
var wave: int = 0
var seeds: int = START_SEEDS
var silo_hp: float = SILO_BASE_HP
var silo_max_hp: float = SILO_BASE_HP
var is_paused: bool = false
var prep_timer: float = 0.0
var arena: Node = null
var joined: Dictionary = {1: false, 2: false}
var player_mods: Dictionary = {}
var global_mods: Dictionary = {}
var taken_cards: Dictionary = {}
var kills: int = 0
var seeds_banked_total: int = 0
var low_silo_barked: bool = false
## Players to auto-join after a restart (skips the title screen).
var quick_restart_players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	reset()


func reset() -> void:
	state = State.TITLE
	wave = 0
	seeds = START_SEEDS
	silo_max_hp = SILO_BASE_HP
	silo_hp = silo_max_hp
	is_paused = false
	prep_timer = 0.0
	joined = {1: false, 2: false}
	player_mods = {1: default_player_mods(), 2: default_player_mods()}
	global_mods = default_global_mods()
	taken_cards = {0: [], 1: [], 2: []}
	kills = 0
	seeds_banked_total = 0
	low_silo_barked = false
	Engine.time_scale = 1.0


func default_player_mods() -> Dictionary:
	return {
		"damage_mult": 1.0,
		"fire_rate_mult": 1.0,
		"speed_mult": 1.0,
		"pierce_bonus": 0,
		"rail_damage_mult": 1.0,
		"pellet_bonus": 0,
		"fist_damage_mult": 1.0,
		"knock_mult": 1.0,
		"pouch_capacity_mult": 1.0,
		"magnet_mult": 1.0,
		"pouch_slow_mult": 1.0,
		"no_overheat": false,
		"heat_rate_mult": 1.0,
		"max_hp_bonus": 0.0,
		"trail_damage_mult": 1.0,
		"spit_damage_mult": 1.0,
		"spit_fire": false,
		"hallucinations": false,
	}


func default_global_mods() -> Dictionary:
	return {
		"flaming_hulls": false,
		"prism_lasers": false,
		"mortar_aoe_mult": 1.0,
		"mortar_double": false,
		"tesla_chain_bonus": 0,
		"decoy_hp_mult": 1.0,
		"decoy_explode": false,
		"tower_cost_mult": 1.0,
		"overdrive_duration": 10.0,
		"shell_slow": 0.3,
		"shell_damage": 0.0,
		"jumper_cables": false,
		"blood_brothers": false,
		"buddy_bounce": false,
		"cheek_share": false,
		"tower_fire_rate_mult": 1.0,
		"tower_damage_taken_mult": 1.0,
		"seed_value_mult": 1.0,
		"rat_speed_mult": 1.0,
		"wave_seed_bonus": 0,
	}


# --- Modifier access -------------------------------------------------------

func pmodf(pid: int, key: String) -> float:
	var d: Dictionary = player_mods.get(pid, {})
	return float(d.get(key, 1.0))


func pmodi(pid: int, key: String) -> int:
	var d: Dictionary = player_mods.get(pid, {})
	return int(d.get(key, 0))


func pmodb(pid: int, key: String) -> bool:
	var d: Dictionary = player_mods.get(pid, {})
	return bool(d.get(key, false))


func gmodf(key: String) -> float:
	return float(global_mods.get(key, 1.0))


func gmodi(key: String) -> int:
	return int(global_mods.get(key, 0))


func gmodb(key: String) -> bool:
	return bool(global_mods.get(key, false))


func any_player_mod(key: String) -> bool:
	for pid in joined_ids():
		if pmodb(pid, key):
			return true
	return false


# --- Economy & Silo ----------------------------------------------------------

func add_seeds(n: int) -> void:
	seeds += n
	seeds_changed.emit(seeds)


func spend_seeds(n: int) -> bool:
	if seeds < n:
		return false
	seeds -= n
	seeds_changed.emit(seeds)
	return true


func tower_cost(kind: int) -> int:
	var base: float = float(Defs.TOWER_DATA[kind]["cost"])
	return maxi(1, roundi(base * gmodf("tower_cost_mult")))


func damage_silo(amount: float) -> void:
	if state == State.GAME_OVER or state == State.TITLE:
		return
	silo_hp = maxf(0.0, silo_hp - amount)
	silo_hp_changed.emit(silo_hp, silo_max_hp)
	if silo_hp <= 0.0:
		silo_destroyed.emit()


func heal_silo(amount: float) -> void:
	silo_hp = minf(silo_max_hp, silo_hp + amount)
	silo_hp_changed.emit(silo_hp, silo_max_hp)


func silo_ratio() -> float:
	return silo_hp / maxf(1.0, silo_max_hp)


# --- Players & state ---------------------------------------------------------

func join_player(pid: int) -> void:
	if joined.get(pid, false):
		return
	joined[pid] = true
	player_joined.emit(pid)


func is_joined(pid: int) -> bool:
	return bool(joined.get(pid, false))


func joined_ids() -> Array:
	var out: Array = []
	for pid in [1, 2]:
		if joined.get(pid, false):
			out.append(pid)
	return out


func player_count() -> int:
	return joined_ids().size()


func set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


func in_combat_state() -> bool:
	return state == State.PREP or state == State.WAVE


func set_paused(p: bool) -> void:
	if state == State.DRAFT:
		return
	is_paused = p
	get_tree().paused = p
	pause_changed.emit(p)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if in_combat_state():
			set_paused(not is_paused)


# --- Input map (built in code so P1/P2 bindings stay readable) ---------------

func _setup_input() -> void:
	# Player 1: keyboard + mouse (and gamepad device 1 if present).
	var p1_keys := {
		"p1_up": [KEY_W], "p1_down": [KEY_S], "p1_left": [KEY_A], "p1_right": [KEY_D],
		"p1_sprint": [KEY_SHIFT], "p1_vent": [KEY_SPACE], "p1_interact": [KEY_E],
		"p1_spit": [KEY_F], "p1_build_next": [KEY_Q], "p1_build_prev": [KEY_Z],
		"p1_build_place": [KEY_R], "p1_build_cancel": [KEY_C], "p1_start": [KEY_E],
		"p1_select_1": [KEY_1], "p1_select_2": [KEY_2], "p1_select_3": [KEY_3],
		"p1_select_4": [KEY_4], "p1_select_5": [KEY_5],
		"p1_aim_left": [], "p1_aim_right": [], "p1_aim_up": [], "p1_aim_down": [],
		"p1_fire": [], "p1_alt": [],
	}
	for action in p1_keys:
		_ensure_action(action)
		for k in p1_keys[action]:
			_bind_key(action, k)
	_bind_mouse("p1_fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("p1_alt", MOUSE_BUTTON_RIGHT)
	_bind_pad("p1_", 1)

	# Player 2: gamepad device 0, with a right-hand keyboard fallback.
	var p2_keys := {
		"p2_up": [KEY_UP], "p2_down": [KEY_DOWN], "p2_left": [KEY_LEFT], "p2_right": [KEY_RIGHT],
		"p2_fire": [KEY_SLASH], "p2_alt": [KEY_PERIOD], "p2_sprint": [KEY_APOSTROPHE],
		"p2_vent": [KEY_SEMICOLON], "p2_interact": [KEY_ENTER, KEY_KP_ENTER],
		"p2_spit": [KEY_BACKSLASH], "p2_build_next": [KEY_BRACKETRIGHT],
		"p2_build_prev": [KEY_BRACKETLEFT], "p2_build_place": [KEY_P],
		"p2_build_cancel": [KEY_O], "p2_start": [KEY_ENTER, KEY_KP_ENTER],
		"p2_aim_left": [], "p2_aim_right": [], "p2_aim_up": [], "p2_aim_down": [],
	}
	for action in p2_keys:
		_ensure_action(action)
		for k in p2_keys[action]:
			_bind_key(action, k)
	_bind_pad("p2_", 0)

	_ensure_action("pause")
	_bind_key("pause", KEY_ESCAPE)
	_ensure_action("call_wave")
	_bind_key("call_wave", KEY_G)
	for dev in [0, 1]:
		_bind_joy_button("pause", dev, JOY_BUTTON_BACK)
		_bind_joy_button("call_wave", dev, JOY_BUTTON_START)


func _bind_pad(prefix: String, device: int) -> void:
	_bind_joy_axis(prefix + "left", device, JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_axis(prefix + "right", device, JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_axis(prefix + "up", device, JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_axis(prefix + "down", device, JOY_AXIS_LEFT_Y, 1.0)
	_bind_joy_axis(prefix + "aim_left", device, JOY_AXIS_RIGHT_X, -1.0)
	_bind_joy_axis(prefix + "aim_right", device, JOY_AXIS_RIGHT_X, 1.0)
	_bind_joy_axis(prefix + "aim_up", device, JOY_AXIS_RIGHT_Y, -1.0)
	_bind_joy_axis(prefix + "aim_down", device, JOY_AXIS_RIGHT_Y, 1.0)
	_bind_joy_axis(prefix + "fire", device, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_joy_button(prefix + "fire", device, JOY_BUTTON_RIGHT_SHOULDER)
	_bind_joy_axis(prefix + "alt", device, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind_joy_button(prefix + "sprint", device, JOY_BUTTON_LEFT_SHOULDER)
	_bind_joy_button(prefix + "sprint", device, JOY_BUTTON_LEFT_STICK)
	_bind_joy_button(prefix + "vent", device, JOY_BUTTON_B)
	_bind_joy_button(prefix + "interact", device, JOY_BUTTON_A)
	_bind_joy_button(prefix + "spit", device, JOY_BUTTON_Y)
	_bind_joy_button(prefix + "build_place", device, JOY_BUTTON_X)
	_bind_joy_button(prefix + "build_next", device, JOY_BUTTON_DPAD_RIGHT)
	_bind_joy_button(prefix + "build_prev", device, JOY_BUTTON_DPAD_LEFT)
	_bind_joy_button(prefix + "build_cancel", device, JOY_BUTTON_DPAD_DOWN)
	_bind_joy_button(prefix + "start", device, JOY_BUTTON_START)


func _ensure_action(action: String, deadzone: float = 0.3) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _bind_key(action: String, keycode: Key) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


func _bind_joy_button(action: String, device: int, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = device
	InputMap.action_add_event(action, ev)


func _bind_joy_axis(action: String, device: int, axis: JoyAxis, dir: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	ev.device = device
	InputMap.action_add_event(action, ev)
