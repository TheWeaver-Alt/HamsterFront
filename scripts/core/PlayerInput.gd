class_name PlayerInput
extends RefCounted
## Device-agnostic per-player input reader.
##
## Devices:
##   "kbm"  keyboard (WASD) + mouse aim
##   "kb2"  shared-keyboard second player (arrow keys + right-hand cluster / numpad)
##   "padN" gamepad with device index N
##
## Call update(node) once per frame, then query held()/just(), `move` and `aim`.

const DEADZONE := 0.22

const KBM_KEYS := {
	"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
	"alt": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E], "spit": [KEY_Q],
	"vent": [KEY_R], "build": [KEY_F], "cycle": [KEY_TAB], "pause": [KEY_ESCAPE, KEY_P],
	"sel1": [KEY_1], "sel2": [KEY_2], "sel3": [KEY_3], "sel4": [KEY_4], "sel5": [KEY_5],
	"confirm": [KEY_E, KEY_ENTER, KEY_SPACE], "back": [KEY_Q, KEY_BACKSPACE], "ready": [KEY_G, KEY_ENTER],
}
const KB2_KEYS := {
	"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
	"fire": [KEY_SLASH, KEY_KP_0], "alt": [KEY_PERIOD, KEY_KP_PERIOD],
	"sprint": [KEY_APOSTROPHE, KEY_KP_ENTER], "interact": [KEY_SEMICOLON, KEY_KP_1],
	"spit": [KEY_BRACKETLEFT, KEY_KP_2], "vent": [KEY_BRACKETRIGHT, KEY_KP_3],
	"build": [KEY_L, KEY_KP_4], "cycle": [KEY_K, KEY_KP_5], "pause": [KEY_BACKSPACE],
	"confirm": [KEY_ENTER, KEY_SLASH, KEY_SEMICOLON, KEY_KP_0], "back": [KEY_BACKSPACE, KEY_BRACKETLEFT],
	"ready": [KEY_BACKSLASH, KEY_KP_ADD],
}
const PAD_BUTTONS := {
	"interact": [JOY_BUTTON_A], "spit": [JOY_BUTTON_B], "vent": [JOY_BUTTON_X],
	"build": [JOY_BUTTON_Y], "cycle": [JOY_BUTTON_RIGHT_SHOULDER],
	"sprint": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_LEFT_STICK], "pause": [JOY_BUTTON_START],
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"confirm": [JOY_BUTTON_A], "back": [JOY_BUTTON_B], "ready": [JOY_BUTTON_BACK],
}

# Human-readable glyphs for HUD prompts.
const GLYPH_KBM := {
	"fire": "LMB", "alt": "RMB", "sprint": "SHIFT", "interact": "E", "spit": "Q", "vent": "R",
	"build": "F", "cycle": "TAB", "pause": "ESC", "confirm": "E", "back": "Q", "ready": "G",
}
const GLYPH_KB2 := {
	"fire": "/", "alt": ".", "sprint": "'", "interact": ";", "spit": "[", "vent": "]",
	"build": "L", "cycle": "K", "pause": "BKSP", "confirm": "ENTER", "back": "BKSP", "ready": "\\",
}
const GLYPH_PAD := {
	"fire": "RT", "alt": "LT", "sprint": "LB", "interact": "(A)", "spit": "(B)", "vent": "(X)",
	"build": "(Y)", "cycle": "RB", "pause": "START", "confirm": "(A)", "back": "(B)", "ready": "SELECT",
}

var device: String = "kbm"
var pad: int = -1
var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var aim_explicit: bool = false
var wheel_steps: int = 0          # mouse-wheel ticks since last update (fed by arena)
# "bot" device: tests / attract mode write these and update() copies them in.
var bot_move: Vector2 = Vector2.ZERO
var bot_aim: Vector2 = Vector2.RIGHT
var bot_held: Dictionary = {}
var _held: Dictionary = {}
var _prev: Dictionary = {}


func _init(dev: String = "kbm") -> void:
	set_device(dev)


func set_device(dev: String) -> void:
	device = dev
	pad = -1
	if dev.begins_with("pad"):
		pad = int(dev.substr(3))


func is_pad() -> bool:
	return pad >= 0


func update(node: Node2D = null) -> void:
	_prev = _held
	_held = {}
	move = Vector2.ZERO
	match device:
		"kbm":
			_read_keys(KBM_KEYS)
			_held["fire"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_held["alt"] = true
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_held["confirm"] = true
			move = _dir_from_held()
			if node != null and node.is_inside_tree():
				var to := node.get_global_mouse_position() - node.global_position
				if to.length() > 2.0:
					aim = to.normalized()
				aim_explicit = true
		"bot":
			_held = bot_held.duplicate()
			move = bot_move
			aim = bot_aim
			aim_explicit = true
		"kb2":
			_read_keys(KB2_KEYS)
			move = _dir_from_held()
			aim_explicit = false
			if move.length() > 0.1:
				aim = move.normalized()
		_:
			_read_pad()
	if wheel_steps != 0:
		if wheel_steps > 0:
			_held["cycle"] = true
		wheel_steps = 0


func _read_keys(map: Dictionary) -> void:
	for action in map.keys():
		for k in map[action]:
			if Input.is_physical_key_pressed(k):
				_held[action] = true
				break


func _dir_from_held() -> Vector2:
	var v := Vector2.ZERO
	if _held.get("left", false): v.x -= 1
	if _held.get("right", false): v.x += 1
	if _held.get("up", false): v.y -= 1
	if _held.get("down", false): v.y += 1
	return v.normalized() if v.length() > 0 else v


func _read_pad() -> void:
	if pad < 0 or not Input.get_connected_joypads().has(pad):
		aim_explicit = false
		return
	for action in PAD_BUTTONS.keys():
		for b in PAD_BUTTONS[action]:
			if Input.is_joy_button_pressed(pad, b):
				_held[action] = true
				break
	var lx := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
	var stick := Vector2(lx, ly)
	if stick.length() < DEADZONE:
		stick = Vector2.ZERO
	var dpad := _dir_from_held()
	move = stick if stick.length() > 0 else dpad
	if move.length() > 1.0:
		move = move.normalized()
	# stick also drives UI nav
	if lx < -0.55: _held["left"] = true
	if lx > 0.55: _held["right"] = true
	if ly < -0.55: _held["up"] = true
	if ly > 0.55: _held["down"] = true
	var r := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	if r.length() > 0.3:
		aim = r.normalized()
		aim_explicit = true
	else:
		aim_explicit = false
		if move.length() > 0.2:
			aim = move.normalized()
	if Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.4:
		_held["fire"] = true
	if Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.4:
		_held["alt"] = true


func held(action: String) -> bool:
	return _held.get(action, false)


func just(action: String) -> bool:
	return _held.get(action, false) and not _prev.get(action, false)


func released(action: String) -> bool:
	return _prev.get(action, false) and not _held.get(action, false)


## Forget current state so a held button doesn't register as a fresh press later.
func consume() -> void:
	_prev = _held.duplicate()


func glyph(action: String) -> String:
	match device:
		"kbm":
			return GLYPH_KBM.get(action, action.to_upper())
		"kb2":
			return GLYPH_KB2.get(action, action.to_upper())
		_:
			return GLYPH_PAD.get(action, action.to_upper())


static func device_label(dev: String) -> String:
	match dev:
		"kbm":
			return "KEYBOARD+MOUSE"
		"kb2":
			return "KEYBOARD (ARROWS)"
		_:
			if dev.begins_with("pad"):
				return "GAMEPAD %d" % (int(dev.substr(3)) + 1)
	return dev.to_upper()


## True if the given device is pressing its "join/confirm" input right now.
static func device_confirm_held(dev: String) -> bool:
	match dev:
		"kbm":
			return Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE) \
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		"kb2":
			return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER) \
				or Input.is_physical_key_pressed(KEY_SLASH)
		_:
			var p := int(dev.substr(3))
			return Input.get_connected_joypads().has(p) and \
				(Input.is_joy_button_pressed(p, JOY_BUTTON_A) or Input.is_joy_button_pressed(p, JOY_BUTTON_START))
