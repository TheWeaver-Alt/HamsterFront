extends Node2D
## A tall sunflower planted along the garden fence. Sways with AmbientLayer's wind and lives in
## the y-sorted World, so mechs walk in front of / behind it naturally. Redraws only when its
## lean changes.

var ambient = null
var phase := 0.0
var _lean := 0


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if ambient == null:
		return
	var w: float = ambient.wind_at(global_position + Vector2(0, -24), phase)
	var l := 0
	if w > 0.5:
		l = 1
	elif w < -0.5:
		l = -1
	if l != _lean:
		_lean = l
		queue_redraw()


func _draw() -> void:
	var tex := PixelArt.tex("amb_sunflower_" + ["l", "c", "r"][_lean + 1])
	draw_rect(Rect2(-5, -1, 10, 2), Color(0.05, 0.03, 0.08, 0.22))
	draw_texture(tex, Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + 1))
