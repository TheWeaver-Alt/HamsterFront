extends Control
## Game-over overlay. CONTRACT: MainArena calls open() after the Silo falls (tree is paused).

var _t := 0.0
var _inputs: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open() -> void:
	visible = true
	_t = 0.0
	_inputs.clear()
	for p in GameManager.players:
		if is_instance_valid(p):
			p.input.consume()
			_inputs.append(p.input)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t > 1.5:
		for inp in _inputs:
			inp.update(null)
			if inp.just("confirm"):
				get_tree().paused = false
				get_tree().reload_current_scene()
				return
			if inp.just("back"):
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
				return
	queue_redraw()


func _draw() -> void:
	var a := clampf(_t / 0.8, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.12, 0.04, 0.8 * a))
	PixelArt.draw_text_centered(self, Vector2(320, 90), "THE SILO HAS FALLEN", PixelArt.C["r"], true, 18)
	PixelArt.draw_text_centered(self, Vector2(320, 116), "THE GREAT HORNED GOUDA FEASTS TONIGHT", PixelArt.C["z"], true, 6)
	PixelArt.draw_text_centered(self, Vector2(320, 150), "WAVES SURVIVED: %d" % maxi(0, GameManager.wave - 1), PixelArt.C["w"], true, 12)
	PixelArt.draw_text_centered(self, Vector2(320, 170), "RATS SQUASHED: %d" % GameManager.kills, PixelArt.C["w"])
	PixelArt.draw_text_centered(self, Vector2(320, 180), "SEEDS BANKED: %d" % GameManager.seeds_banked_total, PixelArt.C["w"])
	if _t > 1.5:
		var g: String = "CONFIRM" if _inputs.is_empty() else _inputs[0].glyph("confirm")
		var b: String = "BACK" if _inputs.is_empty() else _inputs[0].glyph("back")
		PixelArt.draw_text_centered(self, Vector2(320, 220), "[%s] TRY AGAIN    [%s] TITLE" % [g, b], PixelArt.C["y"])
