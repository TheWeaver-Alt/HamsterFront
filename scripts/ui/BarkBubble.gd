extends Node2D
## Floating pixel-font speech bubble (pooled by JuiceManager).
## Types its text out letter by letter with pitch-shifted squeak blips.

const MAX_LINE_CHARS := 18
const CHARS_PER_SEC := 38.0

var active: bool = false
var target = null
var style: String = "hamster"
var age: float = 0.0

var _lines: PackedStringArray = []
var _total_chars: int = 0
var _shown: float = 0.0
var _life: float = 0.0
var _fixed_pos: Vector2 = Vector2.ZERO
var _pop: float = 0.0
var _last_blip_char: int = 0
var _offset_y: float = -26.0


func _ready() -> void:
	z_index = 200
	z_as_relative = false
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_bark(t, text: String, s: String, fixed_pos: Vector2 = Vector2.ZERO) -> void:
	target = t
	style = s
	_fixed_pos = fixed_pos
	_lines = _wrap(text.to_upper())
	_total_chars = 0
	for l in _lines:
		_total_chars += l.length()
	_shown = 0.0
	_last_blip_char = 0
	age = 0.0
	_pop = 0.0
	_life = 1.6 + _total_chars * 0.045
	_offset_y = -26.0
	if is_instance_valid(t) and t.has_method("get_bark_offset"):
		_offset_y = t.call("get_bark_offset")
	active = true
	visible = true
	_update_pos()
	queue_redraw()


func finish() -> void:
	active = false
	visible = false
	target = null


func _wrap(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for word in text.split(" ", false):
		if cur.length() == 0:
			cur = word
		elif cur.length() + 1 + word.length() <= MAX_LINE_CHARS:
			cur += " " + word
		else:
			out.append(cur)
			cur = word
	if cur.length() > 0:
		out.append(cur)
	return out


func _process(delta: float) -> void:
	if not active:
		return
	if get_tree().paused and style != "system":
		return
	age += delta
	_pop = minf(1.0, _pop + delta * 9.0)
	var prev := int(_shown)
	_shown = minf(float(_total_chars), _shown + delta * CHARS_PER_SEC)
	var now := int(_shown)
	if now != prev and now - _last_blip_char >= 2:
		_last_blip_char = now
		_blip()
	if target != null and not is_instance_valid(target):
		target = null
		_life = minf(_life, age + 0.4)
	if age >= _life:
		finish()
		return
	_update_pos()
	queue_redraw()


func _blip() -> void:
	match style:
		"rat":
			Sfx.play("blip_rat", randf_range(1.1, 1.5), -14.0)
		"boss":
			Sfx.play("blip_rat", randf_range(0.55, 0.7), -10.0)
		"system":
			pass
		_:
			Sfx.play("blip_hamster", randf_range(1.3, 1.8), -14.0)


func _update_pos() -> void:
	var p := _fixed_pos
	if is_instance_valid(target):
		p = target.global_position + Vector2(0, _offset_y)
	global_position = Vector2(roundf(p.x), roundf(p.y))


func _draw() -> void:
	if not active or _lines.is_empty():
		return
	var fade := clampf((_life - age) / 0.3, 0.0, 1.0)
	var widest := 0
	for l in _lines:
		widest = maxi(widest, PixelArt.text_width(l))
	var w := widest + 6
	var h := _lines.size() * 7 + 4
	var s := 0.6 + 0.4 * _pop
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var fill: Color
	var border: Color
	var ink: Color
	match style:
		"rat":
			fill = Color8(34, 52, 30)
			border = Color8(150, 255, 90)
			ink = Color8(170, 255, 100)
		"boss":
			fill = Color8(60, 20, 30)
			border = Color8(255, 90, 60)
			ink = Color8(255, 220, 160)
		"system":
			fill = Color8(26, 16, 32)
			border = Color8(255, 214, 64)
			ink = Color8(255, 214, 64)
		_:
			fill = Color8(255, 248, 231)
			border = Color8(26, 16, 32)
			ink = Color8(26, 16, 32)
	fill.a *= fade
	border.a *= fade
	ink.a *= fade
	var r := Rect2(-w / 2, -h, w, h)
	PixelArt.draw_box(self, r, fill, border)
	# tail
	if style == "rat":
		draw_rect(Rect2(-1, 0, 2, 1), border)
		draw_rect(Rect2(1, 1, 2, 1), border)
		draw_rect(Rect2(-1, 2, 2, 1), border)
	else:
		draw_rect(Rect2(-2, 0, 4, 1), border)
		draw_rect(Rect2(-1, 0, 2, 1), fill)
		draw_rect(Rect2(-1, 1, 2, 1), border)
		draw_rect(Rect2(0, 2, 1, 1), border)
	var remaining := int(_shown)
	var y := -h + 3
	for l in _lines:
		if remaining <= 0:
			break
		var part := l.substr(0, mini(remaining, l.length()))
		remaining -= l.length()
		var lw := PixelArt.text_width(l) - 1
		var x := -lw / 2
		# shake rat text for manic energy
		var jitter := Vector2.ZERO
		if style == "rat" or style == "boss":
			jitter = Vector2(randi_range(-1, 0), 0) if randf() < 0.15 else Vector2.ZERO
		PixelArt.draw_text(self, Vector2(x, y) + jitter, part, ink)
		y += 7
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
