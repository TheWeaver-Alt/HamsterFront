extends CanvasLayer
## Transition — chunky pixel "iris" wipe between scenes.
## The screen closes in 4px blocks (dithered edge), a hamster pilot pops up in the dark and
## puffs its cheeks while the next scene loads, then the iris opens again.
## API (stable): Transition.change_scene(path: String), Transition.reload_scene(), is_busy().
## Works while the tree is paused; always unpauses and resets Engine.time_scale.

signal finished

enum St { IDLE, CLOSING, HOLD, OPENING }

const CLOSE_TIME := 0.34
const HOLD_TIME := 0.22
const OPEN_TIME := 0.42
const BLOCK := 4.0
const CENTER := Vector2(320, 180)
const MAX_R := 372.0
const INK := Color8(26, 16, 32)
const RIM := Color8(255, 214, 64)

var _state := St.IDLE
var _t := 0.0
var _target := ""
var _reload := false
var _switched := false
var _canvas: Control
var _last_ms := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.name = "Wipe"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas.draw.connect(_draw_wipe)
	add_child(_canvas)
	_last_ms = Time.get_ticks_msec()
	# open the iris on boot (not for dev tools that screenshot their first frames)
	var tool_run := false
	for a in OS.get_cmdline_args():
		if a.contains("res://tools/"):
			tool_run = true
	if not tool_run:
		_state = St.OPENING
		_t = 0.0


func is_busy() -> bool:
	return _state == St.CLOSING or _state == St.HOLD


func change_scene(path: String) -> void:
	_begin(path, false)


func reload_scene() -> void:
	_begin("", true)


func _begin(path: String, reload: bool) -> void:
	Engine.time_scale = 1.0
	if is_busy():
		return
	_target = path
	_reload = reload
	_switched = false
	_state = St.CLOSING
	_t = 0.0
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("throw", 0.6, -8.0)


func _process(_delta: float) -> void:
	# real time: unaffected by pause, hit-stop or slow-mo
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.05)
	_last_ms = now
	match _state:
		St.CLOSING:
			_t += dt
			if _t >= CLOSE_TIME:
				_state = St.HOLD
				_t = 0.0
				Sfx.play("squeak_hamster", 1.1, -6.0)
		St.HOLD:
			_t += dt
			if not _switched and _t >= HOLD_TIME * 0.5:
				_switch()
			elif _switched and _t >= HOLD_TIME:
				_state = St.OPENING
				_t = 0.0
		St.OPENING:
			_t += dt
			if _t >= OPEN_TIME:
				_state = St.IDLE
				_t = 0.0
				_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
				finished.emit()
	if _state != St.IDLE or _canvas.visible:
		_canvas.visible = _state != St.IDLE
		_canvas.queue_redraw()


func _switch() -> void:
	_switched = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _reload:
		get_tree().reload_current_scene()
	elif _target != "":
		get_tree().change_scene_to_file(_target)


func _radius() -> float:
	match _state:
		St.CLOSING:
			var x := clampf(_t / CLOSE_TIME, 0.0, 1.0)
			return MAX_R * (1.0 - x * x)   # ease-in
		St.HOLD:
			return 0.0
		St.OPENING:
			var x := clampf(_t / OPEN_TIME, 0.0, 1.0)
			# small hamster-sized hole first, then a quick ease-out
			var e := 1.0 - pow(1.0 - x, 3.0)
			return MAX_R * e
	return MAX_R


func _draw_wipe() -> void:
	if _state == St.IDLE:
		return
	var r := _radius()
	var rows := int(360.0 / BLOCK)
	for yb in rows:
		var y := yb * BLOCK
		var dy := y + BLOCK * 0.5 - CENTER.y
		if absf(dy) >= r:
			_canvas.draw_rect(Rect2(0, y, 640, BLOCK), INK)
			continue
		var half := sqrt(r * r - dy * dy)
		var hx := floorf(half / BLOCK) * BLOCK
		var left := CENTER.x - hx
		var right := CENTER.x + hx
		if left > 0.0:
			_canvas.draw_rect(Rect2(0, y, left, BLOCK), INK)
		if right < 640.0:
			_canvas.draw_rect(Rect2(right, y, 640.0 - right, BLOCK), INK)
		# dithered checker edge just inside the hole + a seed-yellow rim block now and then
		if hx > BLOCK * 2.0 and r < MAX_R - 4.0:
			var lb := int(left / BLOCK)
			var rb := int((right - BLOCK) / BLOCK)
			if (lb + yb) % 2 == 0:
				_canvas.draw_rect(Rect2(left, y, BLOCK, BLOCK), INK)
			if (rb + yb) % 2 == 0:
				_canvas.draw_rect(Rect2(right - BLOCK, y, BLOCK, BLOCK), INK)
			if (yb % 3) == 0:
				_canvas.draw_rect(Rect2(left - 1, y + 1, 1, BLOCK - 2), RIM)
				_canvas.draw_rect(Rect2(right, y + 1, 1, BLOCK - 2), RIM)
	# the pilot peeks out of the dark while the next scene loads
	var show := 0.0
	match _state:
		St.CLOSING:
			show = clampf((_t - CLOSE_TIME * 0.6) / (CLOSE_TIME * 0.4), 0.0, 1.0)
		St.HOLD:
			show = 1.0
		St.OPENING:
			show = clampf(1.0 - _t / (OPEN_TIME * 0.35), 0.0, 1.0)
	if show > 0.0:
		var hold_x := _t / HOLD_TIME if _state == St.HOLD else (1.0 if _state == St.OPENING else 0.0)
		var lvl := clampi(int(hold_x * 8.0), 0, 8)
		var tex := PixelArt.tex("ham_head_%d" % lvl)
		var sc := 3.0 * (0.4 + 0.6 * (1.0 - pow(1.0 - show, 3.0)))
		sc = roundf(sc * 2.0) / 2.0
		var sz := tex.get_size() * sc
		var hop := -roundf(absf(sin(_t * 14.0)) * 3.0) if _state == St.HOLD else 0.0
		_canvas.draw_texture_rect(tex, Rect2((CENTER - sz / 2.0 + Vector2(0, hop)).round(), sz), false, Color(1, 1, 1, show))
		if _state == St.HOLD:
			PixelArt.draw_text_centered(_canvas, CENTER + Vector2(0, 34), "SQUEAK!", Color(RIM, show), true, 6)
