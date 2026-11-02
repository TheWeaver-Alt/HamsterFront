extends Control
## Title + join screen. Any device presses its confirm button to join (max 2 pilots).
## P1 presses confirm again to start. With one pilot, left/right picks the chassis.
## CONTRACT: before switching to MainArena set GameManager.num_players, player_devices, p1_chassis.

const ARENA := "res://scenes/MainArena.tscn"

var slots: Array = []            # joined device ids
var inputs: Array = []           # PlayerInput per slot
var _prev_confirm: Dictionary = {}
var _t := 0.0
var _join_cd := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.phase = "title"
	# dev/test hook:  godot --path . -- --autostart[=2]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart"):
			var n := 1
			if a.contains("="):
				n = int(a.get_slice("=", 1))
			slots = ["kbm", "kb2"].slice(0, n)
			_start.call_deferred()


func _devices() -> Array:
	var d: Array = ["kbm", "kb2"]
	for j in Input.get_connected_joypads():
		d.append("pad%d" % j)
	return d


func _process(delta: float) -> void:
	_t += delta
	_join_cd = maxf(0.0, _join_cd - delta)
	for inp in inputs:
		inp.update(null)
	# P1 controls
	if inputs.size() > 0:
		var p1: PlayerInput = inputs[0]
		if slots.size() == 1 and (p1.just("left") or p1.just("right")):
			GameManager.p1_chassis = "wheeler" if GameManager.p1_chassis == "brawler" else "brawler"
			Sfx.play("select")
		if p1.just("confirm") and _join_cd <= 0.0:
			_start()
			return
		if p1.just("back") and slots.size() > 0:
			slots.pop_back()
			inputs.pop_back()
			Sfx.play("deny")
	# joining
	for dev in _devices():
		var held := PlayerInput.device_confirm_held(dev)
		var was: bool = _prev_confirm.get(dev, true)
		_prev_confirm[dev] = held
		if held and not was and not slots.has(dev) and slots.size() < 2:
			slots.append(dev)
			var pi := PlayerInput.new(dev)
			pi.update(null)
			pi.consume()
			inputs.append(pi)
			_join_cd = 0.35
			Sfx.play("squeak_hamster", 1.0 + slots.size() * 0.2)
	queue_redraw()


func _start() -> void:
	if slots.is_empty():
		return
	GameManager.num_players = slots.size()
	GameManager.player_devices = slots.duplicate()
	if slots.size() == 1:
		GameManager.player_devices.append("pad0")
	Sfx.play("wave_start")
	get_tree().change_scene_to_file(ARENA)


func _draw() -> void:
	# backyard backdrop
	for y in 23:
		for x in 40:
			var n := (x * 7 + y * 13) % 4
			draw_texture(PixelArt.tex("tile_grass_%d" % n), Vector2(x * 16, y * 16), Color(0.55, 0.55, 0.65))
	draw_rect(Rect2(0, 0, 640, 360), Color(0.1, 0.06, 0.12, 0.45))
	var bob := sin(_t * 2.0) * 2.0
	PixelArt.draw_text_centered(self, Vector2(320, 40 + bob), "DEFENCE OF", PixelArt.C["y"], true, 12)
	PixelArt.draw_text_centered(self, Vector2(320, 58 + bob), "HAMSTERLAND", PixelArt.C["o"], true, 30)
	PixelArt.draw_text_centered(self, Vector2(320, 94), "MECH-POUCH PROTOCOL", PixelArt.C["Z"], true, 12)
	# silo + heads
	draw_texture(PixelArt.tex("silo_bucket"), Vector2(292, 118))
	var lvl := int(fmod(_t * 3.0, 9.0))
	draw_texture(PixelArt.tex("ham_head_%d" % lvl), Vector2(240, 130))
	draw_texture(PixelArt.tex("ham_head_%d" % (8 - lvl)), Vector2(374, 130))
	# rat parade
	for i in 7:
		var x := fmod(_t * 30.0 + i * 92.0, 720.0) - 40.0
		draw_texture(PixelArt.tex("rat_squeaker_%d" % (int(_t * 8.0 + i) % 2)), Vector2(x, 170))
	# join slots
	for i in 2:
		var x := 170.0 + i * 160.0
		var r := Rect2(x, 196, 140, 70)
		var col: Color = MechPlayer.PLAYER_COLORS[i]
		PixelArt.draw_box(self, r, Color(0.1, 0.06, 0.12, 0.9), col if i < slots.size() else PixelArt.C["G"])
		if i < slots.size():
			var chassis := "brawler" if i == 0 else "wheeler"
			if slots.size() == 1:
				chassis = GameManager.p1_chassis
			PixelArt.draw_text_centered(self, Vector2(x + 70, 202), "P%d READY" % (i + 1), col)
			PixelArt.draw_text_centered(self, Vector2(x + 70, 212), MechPlayer.NAMES[chassis], PixelArt.C["w"])
			PixelArt.draw_text_centered(self, Vector2(x + 70, 222), PlayerInput.device_label(slots[i]), PixelArt.C["g"])
			if slots.size() == 1:
				PixelArt.draw_text_centered(self, Vector2(x + 70, 250), "< LEFT/RIGHT: CHASSIS >", PixelArt.C["g"])
		else:
			var blink := int(_t * 2.0) % 2 == 0
			if blink:
				PixelArt.draw_text_centered(self, Vector2(x + 70, 220), "P%d PRESS TO JOIN" % (i + 1), PixelArt.C["w"])
			PixelArt.draw_text_centered(self, Vector2(x + 70, 234), "E / ENTER / (A)", PixelArt.C["g"])
	if slots.size() > 0:
		PixelArt.draw_text_centered(self, Vector2(320, 278), "P1: PRESS [%s] AGAIN TO START" % inputs[0].glyph("confirm"), PixelArt.C["y"])
	PixelArt.draw_text_centered(self, Vector2(320, 300), "KB+MOUSE: WASD MOVE  LMB FIRE  RMB ALT  SHIFT SPRINT  E BANK/CRAM  F BUILD  TAB CYCLE  Q SPIT  R VENT", PixelArt.C["g"])
	PixelArt.draw_text_centered(self, Vector2(320, 310), "ARROWS P2: / FIRE  . ALT  ' SPRINT  ; BANK  L BUILD  K CYCLE  [ SPIT  ] VENT", PixelArt.C["g"])
	PixelArt.draw_text_centered(self, Vector2(320, 320), "GAMEPAD: LS MOVE  RS AIM  RT FIRE  LT ALT  LB SPRINT  A BANK  Y BUILD  RB CYCLE  B SPIT  X VENT", PixelArt.C["g"])
	PixelArt.draw_text_centered(self, Vector2(320, 340), "THE UNDER-SCURRIERS WANT THE STRIPED ONES. STOP THEM.", PixelArt.C["z"])
