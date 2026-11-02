class_name SpeechBubble
extends Node2D
## Pooled floating pixel-font speech bubble with typewriter reveal
## and pitch-shifted 8-bit blips. Owned by JuiceManager.

const MAX_W := 104
const CHAR_TIME := 0.022

var active := false
var target: Node2D = null
var text := ""
var lines := PackedStringArray()
var shown := 0
var is_rat := false
var life := 0.0
var _char_t := 0.0
var _anchor := Vector2.ZERO
var _height := 20.0
var _pop := 0.0
var _pitch := 1.0


func _ready() -> void:
	visible = false
	z_index = 100


func pop(t: Node2D, txt: String, rat: bool) -> void:
	target = t
	text = txt.to_upper()
	is_rat = rat
	active = true
	visible = true
	shown = 0
	_char_t = 0.0
	_pop = 0.0
	lines = PixelFont.wrap_text(text, MAX_W)
	life = 1.5 + text.length() * 0.04
	_pitch = randf_range(1.35, 1.75) if rat else randf_range(0.85, 1.15)
	_height = 20.0
	if is_instance_valid(t):
		var h = t.get("bubble_height")
		if h != null:
			_height = float(h)
		_anchor = t.global_position
	_place()


func _place() -> void:
	var w := _box_w()
	var x := clampf(_anchor.x, w / 2.0 + 3.0, 637.0 - w / 2.0)
	var y := maxf(_anchor.y - _height, float(_box_h()) + 16.0)
	position = Vector2(roundf(x), roundf(y))


func _box_w() -> int:
	var w := 0
	for l in lines:
		w = maxi(w, PixelFont.text_width(l))
	return w + 6


func _box_h() -> int:
	return lines.size() * PixelFont.LINE_H + 3


func _process(delta: float) -> void:
	if not active:
		return
	life -= delta
	_pop = minf(1.0, _pop + delta * 8.0)
	if is_instance_valid(target):
		_anchor = target.global_position
	else:
		target = null
	_place()
	if shown < text.length():
		_char_t += delta
		while _char_t >= CHAR_TIME and shown < text.length():
			_char_t -= CHAR_TIME
			shown += 1
			if shown % 3 == 1 and text[shown - 1] != " ":
				SFX.play("blip_rat" if is_rat else "blip", _pitch * randf_range(0.92, 1.08), -8.0, 0)
	if life <= 0.0:
		active = false
		visible = false
		target = null
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var w := _box_w()
	var h := _box_h()
	var bounce := roundf((1.0 - _pop) * 3.0)
	var top := -h - 5 - bounce
	var left := -w / 2
	var bg := Color("1f1a14") if is_rat else Pal.WHITE
	var fg := Pal.WARP if is_rat else Pal.INK
	var border := Pal.WARP_DARK if is_rat else Pal.INK
	# Border + body.
	draw_rect(Rect2(left - 1, top - 1, w + 2, h + 2), border)
	draw_rect(Rect2(left, top, w, h), bg)
	# Tail.
	draw_rect(Rect2(-2, top + h, 4, 1), bg)
	draw_rect(Rect2(-1, top + h + 1, 2, 1), bg)
	draw_rect(Rect2(-3, top + h, 1, 1), border)
	draw_rect(Rect2(2, top + h, 1, 1), border)
	draw_rect(Rect2(-2, top + h + 1, 1, 1), border)
	draw_rect(Rect2(1, top + h + 1, 1, 1), border)
	draw_rect(Rect2(-1, top + h + 2, 2, 1), border)
	# Typewriter text.
	var remaining := shown
	var y := top + 2
	for l in lines:
		if remaining <= 0:
			break
		var part: String = l.substr(0, remaining)
		remaining -= l.length() + 1
		var lw := PixelFont.text_width(l)
		PixelFont.draw_text(self, part, Vector2(-lw / 2.0, y), fg)
		y += PixelFont.LINE_H
