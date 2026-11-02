extends Control
## Pause overlay. CONTRACT: MainArena toggles `visible` and calls open().

const OPTIONS := ["RESUME", "RESTART RUN", "QUIT TO TITLE"]

var sel := 0
var _inputs: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open() -> void:
	sel = 0
	_inputs.clear()
	for p in GameManager.players:
		if is_instance_valid(p):
			p.input.consume()
			_inputs.append(p.input)


func _process(_delta: float) -> void:
	if not visible:
		return
	for inp in _inputs:
		inp.update(null)
		if inp.just("up"):
			sel = (sel + OPTIONS.size() - 1) % OPTIONS.size()
			Sfx.play("select")
		if inp.just("down"):
			sel = (sel + 1) % OPTIONS.size()
			Sfx.play("select")
		if inp.just("confirm"):
			_choose()
			return
	queue_redraw()


func _choose() -> void:
	Sfx.play("card")
	match sel:
		0:
			GameManager.arena.toggle_pause()
		1:
			get_tree().paused = false
			get_tree().reload_current_scene()
		2:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.03, 0.08, 0.7))
	PixelArt.draw_text_centered(self, Vector2(320, 110), "PAUSED", PixelArt.C["y"], true, 18)
	PixelArt.draw_text_centered(self, Vector2(320, 136), "THE RATS ARE ALSO TAKING A BREATHER", PixelArt.C["g"])
	for i in OPTIONS.size():
		var c := PixelArt.C["w"] if i == sel else PixelArt.C["g"]
		var t: String = ("> " + OPTIONS[i] + " <") if i == sel else OPTIONS[i]
		PixelArt.draw_text_centered(self, Vector2(320, 160 + i * 14), t, c, true, 12 if i == sel else 6)
