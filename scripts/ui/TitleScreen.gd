extends Control
## Title + join screen. Any device presses its confirm button to join (max 2 pilots).
## P1 presses confirm again to start. With one pilot, left/right picks the chassis.
## TAB / H / F1 (keyboard) or (Y) / SELECT (gamepad) toggles the controls & how-to-play page.
## Each joined pilot cycles their LEARNING MODE with up/down; P1's vent button toggles KID mode.
## CONTRACT: before switching to MainArena set GameManager.num_players, player_devices, p1_chassis,
## learning_levels (per slot, 0..3) and difficulty ("normal" | "kid").
## Dev/test hook:  godot --path . -- --autostart[=2]

const ARENA := "res://scenes/MainArena.tscn"
const K := Color8(26, 16, 32)

const CONTROLS := [
	# [action, kb+mouse, arrows kb, gamepad]
	["MOVE", "WASD", "ARROWS", "L-STICK"],
	["AIM", "MOUSE", "AUTO", "R-STICK"],
	["FIRE", "LMB", "/", "RT"],
	["ALT ATTACK", "RMB/V", ".", "LT"],
	["JETPACK JUMP", "SPACE", ",", "L3"],
	["SPRINT", "SHIFT", "'", "LB"],
	["BANK / CRAM", "E", ";", "(A)"],
	["BUILD / UPGRADE", "F", "L", "(Y)"],
	["CYCLE TOWER", "TAB/WHEEL/1-5", "K", "RB"],
	["SPIT POUCH", "Q", "[", "(B)"],
	["VENT STEAM", "R", "]", "(X)"],
	["READY UP", "G/ENTER", "\\", "SELECT"],
	["PAUSE", "ESC/P", "BKSP", "START"],
]
const TIPS := [
	["RATS DROP SEEDS. YOUR MECH VACUUMS THEM INTO YOUR CHEEKS.", "c"],
	["FULL CHEEKS = BIG HEAD = UP TO 40% SLOWER.", "c"],
	["BANK SEEDS AT THE SILO, THEN BUILD TOWERS ON WOODEN PADS.", "y"],
	["CRAM 10+ SEEDS INTO A TOWER FOR A 10S SUGAR RUSH.", "p"],
	["SPIT YOUR WHOLE POUCH FOR A SCREEN-CLEARING SEED BLAST.", "r"],
	["SPRINTING HEATS YOUR HAMSTER WHEEL. VENT BEFORE IT TRIPS!", "i"],
	["AFTER EACH WAVE: PICK 1 OF 3 CARDS. CURSED ONES BITE BACK.", "Z"],
	["USE RAMPS TO REACH THE HIGH GROUND, OR GET THE JETPACK CARD.", "u"],
]
const ENEMIES := [
	["CLAN-SQUEAKERS", "PACKS OF 20 WITH BENT FORKS. TRIP OVER TAILS.", "m"],
	["WARP-GOUDA JEZZAIL", "SNIPER TEAM. DODGE THE GREEN LASER SIGHT!", "z"],
	["PLAGUE-STINK MONK", "TOXIC GAS CLOUDS CORRODE TOWERS.", "Z"],
	["DOOM-ROOMBA", "SPIKED VACUUM. BOUNCES OFF EVERYTHING.", "g"],
	["RAT-OGRE BRUISER", "EVERY 5TH WAVE. THROWS CLAN-SQUEAKERS.", "r"],
]
const RAT_LINES := ["YES-YES!", "SEEDS-SEEDS!", "MUNCH-GNAW!", "STEAL-TAKE!", "FOR THE GOUDA!"]

var slots: Array = []            # joined device ids
var inputs: Array = []           # PlayerInput per slot
var learn: Array = []            # learning level per slot (0 off .. 3)
var _prev_confirm: Dictionary = {}
var _prev_toggle := true
var _t := 0.0
var _join_cd := 0.0
var _show_controls := false
var _seeds: Array = []           # decorative seeds flying into the bucket
var _seed_t := 0.0
var _rat_bark := {"i": -1, "t": 0.0, "text": ""}
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.phase = "title"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart"):
			var n := 1
			if a.contains("="):
				n = int(a.get_slice("=", 1))
			slots = ["kbm", "kb2"].slice(0, n)
			learn = [0, 0].slice(0, n)
			inputs.clear()
			for dev in slots:
				inputs.append(PlayerInput.new(dev))
			_start.call_deferred()


func _devices() -> Array:
	var d: Array = ["kbm", "kb2"]
	for j in Input.get_connected_joypads():
		d.append("pad%d" % j)
	return d


func _toggle_held() -> bool:
	if Input.is_physical_key_pressed(KEY_TAB) or Input.is_physical_key_pressed(KEY_H) or Input.is_physical_key_pressed(KEY_F1):
		return true
	for j in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(j, JOY_BUTTON_Y) or Input.is_joy_button_pressed(j, JOY_BUTTON_BACK):
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	_join_cd = maxf(0.0, _join_cd - delta)
	_flash = maxf(0.0, _flash - delta * 3.0)
	_update_seeds(delta)
	for inp in inputs:
		inp.update(null)
	# controls page toggle
	var tog := _toggle_held()
	if tog and not _prev_toggle:
		_show_controls = not _show_controls
		Sfx.play("select", 0.8 if _show_controls else 1.1)
	_prev_toggle = tog
	if _show_controls:
		# any confirm/back closes the page (and does not join/start)
		for dev in _devices():
			var held := PlayerInput.device_confirm_held(dev)
			var was: bool = _prev_confirm.get(dev, true)
			_prev_confirm[dev] = held
			if held and not was:
				_show_controls = false
				Sfx.play("select", 1.1)
		for inp in inputs:
			inp.consume()
		queue_redraw()
		return
	# P1 controls
	if inputs.size() > 0:
		var p1: PlayerInput = inputs[0]
		if slots.size() == 1 and (p1.just("left") or p1.just("right")):
			GameManager.p1_chassis = "wheeler" if GameManager.p1_chassis == "brawler" else "brawler"
			Sfx.play("select")
			_flash = 0.6
		if p1.just("vent"):
			GameManager.difficulty = "normal" if GameManager.difficulty == "kid" else "kid"
			Sfx.play("upgrade" if GameManager.difficulty == "kid" else "select", 1.2)
			_flash = 0.8
		if p1.just("confirm") and _join_cd <= 0.0:
			_start()
			return
	# learning mode per pilot
	for i in inputs.size():
		var li: PlayerInput = inputs[i]
		if li.just("up"):
			learn[i] = (int(learn[i]) + 1) % GameManager.LEARNING_NAMES.size()
			Sfx.play("pickup", 1.0 + learn[i] * 0.2)
		elif li.just("down"):
			learn[i] = (int(learn[i]) + GameManager.LEARNING_NAMES.size() - 1) % GameManager.LEARNING_NAMES.size()
			Sfx.play("pickup", 1.0 + learn[i] * 0.2)
	for i in range(inputs.size() - 1, -1, -1):
		var inp: PlayerInput = inputs[i]
		if inp.just("back"):
			slots.remove_at(i)
			inputs.remove_at(i)
			learn.remove_at(i)
			Sfx.play("deny")
			break
	# joining
	for dev in _devices():
		var held := PlayerInput.device_confirm_held(dev)
		var was: bool = _prev_confirm.get(dev, true)
		_prev_confirm[dev] = held
		if held and not was and not slots.has(dev) and slots.size() < 2:
			slots.append(dev)
			var prev_level := 0
			if slots.size() - 1 < GameManager.learning_levels.size():
				prev_level = int(GameManager.learning_levels[slots.size() - 1])
			learn.append(prev_level)
			var pi := PlayerInput.new(dev)
			pi.update(null)
			pi.consume()
			inputs.append(pi)
			_join_cd = 0.35
			_flash = 1.0
			Sfx.play("squeak_hamster", 1.0 + slots.size() * 0.2)
	queue_redraw()


func _start() -> void:
	if slots.is_empty():
		return
	GameManager.num_players = slots.size()
	GameManager.player_devices = slots.duplicate()
	var levels: Array = [0, 0]
	for i in mini(learn.size(), 2):
		levels[i] = int(learn[i])
	GameManager.learning_levels = levels
	if slots.size() == 1:
		GameManager.player_devices.append("pad0")
	Sfx.play("wave_start")
	Transition.change_scene(ARENA)


func _update_seeds(delta: float) -> void:
	_seed_t -= delta
	if _seed_t <= 0.0:
		_seed_t = randf_range(0.05, 0.18)
		var from_left := randf() < 0.5
		var start := Vector2(236, 150) if from_left else Vector2(404, 150)
		_seeds.append({"p": start, "v": Vector2((1 if from_left else -1) * randf_range(40, 70), randf_range(-110, -70)), "life": 1.4})
	var k := _seeds.size() - 1
	while k >= 0:
		var s: Dictionary = _seeds[k]
		var v: Vector2 = s["v"]
		v.y += 240.0 * delta
		s["v"] = v
		s["p"] += v * delta
		s["life"] -= delta
		var p: Vector2 = s["p"]
		if s["life"] <= 0.0 or (p.y > 146.0 and absf(p.x - 320.0) < 22.0 and v.y > 0.0):
			_seeds.remove_at(k)
		k -= 1


# ------------------------------------------------------------------ draw

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if _show_controls:
			_show_controls = false
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	_draw_backdrop()
	_draw_logo()
	_draw_scene()
	if _show_controls:
		_draw_controls_page()
		return
	_draw_slots()
	_draw_footer()


## Parallax backyard: slow-scrolling lawn, drifting cloud shadows, a hedge row (with rats
## peeking out of it) and fast foreground grass blades.
func _draw_backdrop() -> void:
	var scroll := fmod(_t * 6.0, 16.0)
	for y in 23:
		for x in 41:
			var wx := x + int(_t * 6.0 / 16.0)
			var n := (wx * 7 + y * 13) % 4
			var tile := "tile_grass_%d" % n
			if (wx * 3 + y * 5) % 17 == 0:
				tile = "tile_flowers_%d" % ((wx + y) % 3)
			draw_texture(PixelArt.tex(tile), Vector2(x * 16 - scroll, y * 16), Color(0.5, 0.5, 0.62))
	# drifting cloud shadows
	for i in 3:
		var cx := fmod(_t * (5.0 + i * 2.0) + i * 260.0, 900.0) - 130.0
		var cy := 60.0 + i * 110.0 + sin(_t * 0.3 + i) * 10.0
		_cloud_shadow(Vector2(cx, cy), 46.0 + i * 12.0)
	# fence top and bottom
	var fscroll := fmod(_t * 10.0, 16.0)
	for x in 41:
		draw_texture(PixelArt.tex("tile_fence"), Vector2(x * 16 - fscroll, -6), Color(0.6, 0.6, 0.7))
		draw_texture(PixelArt.tex("tile_fence"), Vector2(x * 16 - fscroll, 350), Color(0.6, 0.6, 0.7))
	# vignette
	for i in 8:
		var a := 0.06 * (8 - i)
		draw_rect(Rect2(0, i * 4, 640, 4), Color(0.1, 0.06, 0.12, a))
		draw_rect(Rect2(0, 356 - i * 4, 640, 4), Color(0.1, 0.06, 0.12, a))
	draw_rect(Rect2(0, 0, 640, 360), Color(0.1, 0.06, 0.12, 0.3))
	_draw_hedge()
	# foreground blades rushing past along the bottom edge
	for i in 40:
		var bx := 660.0 - fmod(_t * 34.0 + i * 37.0, 700.0)
		var h := 3.0 + float((i * 5) % 4)
		var c := PixelArt.C["f"] if i % 3 else PixelArt.C["E"]
		draw_rect(Rect2(roundf(bx), 350 - h, 1, h), c)
		draw_rect(Rect2(roundf(bx) + 1, 351 - h, 1, 1), c.lightened(0.2))


func _cloud_shadow(c: Vector2, r: float) -> void:
	var col := Color(0.05, 0.03, 0.12, 0.13)
	for dy in range(-int(r * 0.45), int(r * 0.45) + 1, 2):
		var f := float(dy) / (r * 0.45)
		var hw := roundf(r * sqrt(maxf(0.0, 1.0 - f * f)))
		var wob := roundf(sin(dy * 0.4 + c.x * 0.02) * 3.0)
		draw_rect(Rect2(roundf(c.x - hw + wob), roundf(c.y + dy), hw * 2.0, 2), col)


## A hedge band between the logo and the stage, scrolling a little faster than the lawn.
## Now and then a rat pokes its head out, glowing eyes first.
func _draw_hedge() -> void:
	var y0 := 100.0
	var hs := fmod(_t * 12.0, 24.0)
	var dark := PixelArt.C["f"].darkened(0.5)
	var mid := PixelArt.C["f"].darkened(0.22)
	var lite := PixelArt.C["E"].darkened(0.28)
	var speck := PixelArt.C["e"].darkened(0.3)
	# soft shadow the hedge casts on the lawn
	draw_rect(Rect2(0, y0 + 17, 640, 2), Color(0.05, 0.03, 0.08, 0.35))
	draw_rect(Rect2(0, y0 + 19, 640, 1), Color(0.05, 0.03, 0.08, 0.18))
	for i in 30:
		var x := i * 24.0 - hs
		var wx := i + int(_t * 12.0 / 24.0)
		var cy := y0 + 10.0
		# three overlapping leafy clumps per bush, lit from the top-left
		for b in 3:
			var h := (wx * 7 + b * 13) % 5
			var c := Vector2(x + 4.0 + b * 8.0 + float(h % 3) - 1.0, cy + float((h + b) % 3) - 1.0 - (2.0 if b == 1 else 0.0))
			var r := 6.0 + float(h % 3)
			PixelArt.draw_disk(self, c + Vector2(1, 2), r, dark)
			PixelArt.draw_disk(self, c, r - 1.0, mid)
			PixelArt.draw_disk(self, c - Vector2(1, 2), r - 3.5, lite)
			draw_rect(Rect2((c + Vector2(-2, -3)).round(), Vector2(1, 1)), speck)
			draw_rect(Rect2((c + Vector2(2, -1)).round(), Vector2(1, 1)), speck)
		if (wx * 5) % 7 == 0:
			draw_rect(Rect2(x + 12, cy - 6, 1, 1), PixelArt.C["p"].darkened(0.2))
			draw_rect(Rect2(x + 18, cy - 2, 1, 1), PixelArt.C["w"].darkened(0.3))
		# a sneaky rat in this bush?
		var cycle := fmod(_t + wx * 1.7, 9.0)
		if wx % 5 == 2 and cycle < 2.2:
			var up := clampf(cycle / 0.3, 0.0, 1.0) * clampf((2.2 - cycle) / 0.3, 0.0, 1.0)
			var hx := x + 12.0
			var hy := cy - 4.0 - roundf(up * 6.0)
			draw_rect(Rect2(hx - 3, hy, 6, 4), PixelArt.C["m"])
			draw_rect(Rect2(hx - 2, hy - 1, 4, 1), PixelArt.C["m"])
			draw_rect(Rect2(hx - 4, hy - 2, 2, 2), PixelArt.C["q"])
			draw_rect(Rect2(hx + 2, hy - 2, 2, 2), PixelArt.C["q"])
			var blink := fmod(_t * 3.0 + wx, 4.0) < 0.15
			if not blink:
				draw_rect(Rect2(hx - 2, hy + 1, 1, 1), PixelArt.C["z"])
				draw_rect(Rect2(hx + 1, hy + 1, 1, 1), PixelArt.C["z"])
			draw_rect(Rect2(hx - 1, hy + 3, 2, 1), PixelArt.C["p"])
			# whiskers twitch
			if int(_t * 6.0) % 2 == 0:
				draw_rect(Rect2(hx - 5, hy + 2, 2, 1), PixelArt.C["W"])
				draw_rect(Rect2(hx + 3, hy + 2, 2, 1), PixelArt.C["W"])
			# foliage in front of the rat
			PixelArt.draw_disk(self, Vector2(hx, cy + 2), 5.5, mid)
			PixelArt.draw_disk(self, Vector2(hx - 1, cy + 1), 3.0, lite)
		elif wx % 5 == 2 and cycle < 3.0:
			# eyes glinting in the dark before it pops up
			draw_rect(Rect2(x + 10, cy, 1, 1), PixelArt.C["z"])
			draw_rect(Rect2(x + 13, cy, 1, 1), PixelArt.C["z"])


func _draw_logo() -> void:
	# per-letter HAMSTERFRONT: letters drop in one by one, then bob; a shine sweeps across
	var word := "HAMSTERFRONT"
	var size := 30
	var total := PixelArt.text_width(word, size)
	var x := 320.0 - total / 2.0
	var shine_x := fmod(_t * 220.0, 1400.0) - 300.0
	for i in word.length():
		var ch := word[i]
		var w := PixelArt.text_width(ch, size)
		var d := clampf((_t - 0.25 - i * 0.07) / 0.4, 0.0, 1.0)
		if d <= 0.0:
			x += w
			continue
		var fall := (1.0 - _bounce(d)) * -70.0
		var hop := 0.0
		# a ripple hop runs along the word every few seconds
		var rp := fmod(_t, 5.0) - 2.0 - i * 0.06
		if rp > 0.0 and rp < 0.3:
			hop = -sin(rp / 0.3 * PI) * 4.0
		var y := 32.0 + roundf(sin(_t * 3.0 + i * 0.55) * 2.0 + fall + hop)
		PixelArt.draw_text(self, Vector2(x + 2, y + 4), ch, PixelArt.C["K"], size)
		var col := PixelArt.C["o"].lerp(PixelArt.C["y"], 0.5 + 0.5 * sin(_t * 2.0 + i * 0.4))
		var sd := absf((x + w * 0.5) - shine_x)
		if sd < 18.0:
			col = col.lerp(Color.WHITE, 1.0 - sd / 18.0)
		PixelArt.draw_text_outlined(self, Vector2(x, y), ch, col, K, size)
		x += w
	var sub_a := clampf((_t - 1.1) / 0.35, 0.0, 1.0)
	if sub_a > 0.0:
		# subtitle slides up into place (outline only once fully in, so no dark ghosting)
		var sy := roundf((1.0 - sub_a) * 8.0)
		var sub_col := PixelArt.C["Z"] if int(_t * 5.0) % 23 != 0 else PixelArt.C["z"]
		PixelArt.draw_text_centered(self, Vector2(320, 70 + sy), "MECH-POUCH PROTOCOL", Color(sub_col, sub_a), sub_a >= 1.0, 12)
		PixelArt.draw_text_centered(self, Vector2(320, 86 + sy), "1-2 PLAYER LOCAL CO-OP TOWER DEFENSE", Color(PixelArt.C["W"], sub_a), sub_a >= 1.0)


static func _ease_back(x: float) -> float:
	var u := x - 1.0
	return 1.0 + 2.7 * u * u * u + 1.7 * u * u


static func _bounce(x: float) -> float:
	if x < 0.55:
		return (x / 0.55) * (x / 0.55)
	var u := (x - 0.8) / 0.25
	return 1.0 - 0.18 * maxf(0.0, 1.0 - u * u)


func _title_flash(p: Vector2, s: float) -> void:
	PixelArt.draw_disk(self, p, s * 0.5, PixelArt.C["y"])
	draw_rect(Rect2(p.x, p.y - 1, s * 1.6, 2), PixelArt.C["y"])
	draw_rect(Rect2(p.x - 1, p.y - s * 0.6, 2, s * 1.2), PixelArt.C["y"])
	PixelArt.draw_disk(self, p, s * 0.3, Color.WHITE)


func _draw_scene() -> void:
	var ground_y := 186.0
	# silo bucket with seed mound
	var bx := 292.0
	var by := ground_y - 44.0
	draw_rect(Rect2(bx + 2, ground_y - 2, 52, 4), Color(0, 0, 0, 0.3))
	for i in 60:
		var a := PI + float(i) / 60.0 * PI
		var r := 6.0 + float((i * 7) % 17)
		var p := Vector2(320 + cos(a) * r, by + 4 + sin(a) * r * 0.7).round()
		draw_rect(Rect2(p, Vector2(2, 3) if i % 2 == 0 else Vector2(3, 2)), PixelArt.C["s"])
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), PixelArt.C["S"])
	draw_texture(PixelArt.tex("silo_bucket"), Vector2(bx, by))
	for s in _seeds:
		var sp: Vector2 = (s["p"] as Vector2).round()
		draw_rect(Rect2(sp, Vector2(2, 3)), PixelArt.C["s"])
		draw_rect(Rect2(sp + Vector2(0, 1), Vector2(1, 1)), PixelArt.C["S"])
	# BRAWLER-01 (left), cheeks cycling
	var lvl := int(fmod(_t * 2.5, 16.0))
	if lvl > 8:
		lvl = 16 - lvl
	var walk := int(_t * 4.0) % 2
	var b := Vector2(232, ground_y)
	draw_rect(Rect2(b.x - 9, b.y - 2, 18, 3), Color(0, 0, 0, 0.3))
	var bob := -1.0 if walk == 1 else 0.0
	draw_texture(PixelArt.tex("brawler_body_%d" % walk), b + Vector2(-13, -22 + bob))
	draw_texture(PixelArt.tex("ham_head_%d" % lvl), b + Vector2(-13, -30 + bob))
	draw_texture(PixelArt.tex("brawler_dome"), b + Vector2(-9, -30 + bob))
	# every few seconds the brawler test-fires its sawdust shotgun
	var shot_t := fmod(_t, 3.4)
	var recoil := 2.0 if shot_t < 0.08 else 0.0
	draw_texture(PixelArt.tex("brawler_gun"), b + Vector2(-2 - recoil, -17 + bob))
	if shot_t < 0.1:
		var mz := b + Vector2(16 - recoil, -13 + bob)
		_title_flash(mz, 7.0 if shot_t < 0.05 else 4.0)
	elif shot_t < 0.45:
		for k in 5:
			var pp := b + Vector2(17 + shot_t * (80.0 + k * 25.0), -13 + bob + (k - 2) * shot_t * 18.0)
			draw_rect(Rect2(pp.round(), Vector2(1, 1)), Color(PixelArt.C["c"], 1.0 - shot_t / 0.45))
	# WHEELER-X (right), facing left; does a little jetpack hop now and then
	var hop_t := fmod(_t + 1.3, 4.2)
	var hop := 0.0
	if hop_t < 0.5:
		hop = -sin(hop_t / 0.5 * PI) * 10.0
	var wpos := Vector2(408, ground_y + roundf(hop))
	if hop_t < 0.5:
		for k in 3:
			var fy := wpos.y + 2.0 + k * 2.0 + randf() * 2.0
			draw_rect(Rect2(wpos.x - 1 + randi_range(-1, 1), fy, 2, 2), [PixelArt.C["I"], PixelArt.C["y"], PixelArt.C["i"]][k])
	draw_rect(Rect2(wpos.x - 11 + roundf(-hop * 0.2), ground_y - 2, 22 + roundf(hop * 0.4), 3), Color(0, 0, 0, 0.3))
	var c := wpos + Vector2(0, -14)
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var j := i % 3
		var phase := _t * 9.0 + i * 2.1
		var anchor := c + Vector2(side * 5.0, 1.0 + (j - 1) * 2.0)
		var foot := c + Vector2(side * (7.0 + j * 3.5) + sin(phase) * 1.5, 12.0 - maxf(0.0, cos(phase)) * 1.5)
		var knee := anchor + Vector2(side * (5.0 + j * 1.5), -6.0 + j * 1.5)
		draw_line(anchor.round(), knee.round(), PixelArt.C["G"], 1.0)
		draw_line(knee.round(), foot.round(), PixelArt.C["g"], 1.0)
	var wf := int(_t * 10.0) % 2
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture(PixelArt.tex("wheeler_ham_%d" % wf), Vector2(-c.x - 7, c.y - 5))
	draw_texture(PixelArt.tex("ham_head_%d" % (8 - lvl)), Vector2(-c.x - 13, c.y - 17))
	draw_texture(PixelArt.tex("wheeler_rails"), Vector2(-c.x - 4, c.y - 16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture(PixelArt.tex("wheeler_ball"), c + Vector2(-12, -14))
	# rat parade marching left along the bottom of the scene
	var rat_y := ground_y + 12.0
	for i in 9:
		var x := 700.0 - fmod(_t * 26.0 + i * 78.0, 780.0)
		var tripped := (int(_t * 0.7) + i) % 11 == 0
		var tex: Texture2D
		if tripped:
			tex = PixelArt.tex("rat_squeaker_trip")
		else:
			tex = PixelArt.tex("rat_squeaker_%d" % (int(_t * 8.0 + i) % 2))
		draw_set_transform(Vector2(x, rat_y), 0.0, Vector2(-1, 1))
		draw_texture(tex, Vector2(-10, -tex.get_height()))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# a rat barks now and then
		if i == int(_t / 3.0) % 9 and fmod(_t, 3.0) < 1.6 and x > 40.0 and x < 600.0:
			var line: String = RAT_LINES[int(_t / 3.0) % RAT_LINES.size()]
			var w := PixelArt.text_width(line) + 6
			var r := Rect2(x - w / 2.0, rat_y - 26, w, 10)
			PixelArt.draw_box(self, r, Color8(34, 52, 30), PixelArt.C["z"])
			PixelArt.draw_text(self, r.position + Vector2(3, 3), line, PixelArt.C["z"])


const LEARN_COLORS := ["g", "Z", "y", "o"]


func _ud_glyph(dev: String) -> String:
	match dev:
		"kbm":
			return "W/S"
		"kb2":
			return "UP/DOWN"
	return "D-PAD"


func _draw_slots() -> void:
	for i in 2:
		var x := 172.0 + i * 156.0
		var r := Rect2(x, 204, 140, 82)
		var col: Color = MechPlayer.PLAYER_COLORS[i]
		var joined := i < slots.size()
		var fill := Color(0.1, 0.06, 0.12, 0.92)
		if joined and _flash > 0.0 and i == slots.size() - 1:
			fill = fill.lerp(col, _flash * 0.4)
		PixelArt.draw_box(self, r, fill, col if joined else PixelArt.C["G"])
		var cx := x + 70.0
		var y := r.position.y
		if joined:
			var chassis := "brawler" if i == 0 else "wheeler"
			if slots.size() == 1:
				chassis = GameManager.p1_chassis
			PixelArt.draw_text_centered(self, Vector2(cx, y + 4), "P%d READY!" % (i + 1), col, true)
			draw_texture(PixelArt.tex("ham_head_%d" % (2 if i == 0 else 4)), Vector2(x + 4, y + 12))
			PixelArt.draw_text(self, Vector2(x + 34, y + 14), MechPlayer.NAMES[chassis], PixelArt.C["w"])
			var blurb := "ESPRESSO + DUCT TAPE" if chassis == "brawler" else "BALL ON SPIDER LEGS"
			PixelArt.draw_text(self, Vector2(x + 34, y + 22), blurb, PixelArt.C["g"])
			PixelArt.draw_text(self, Vector2(x + 34, y + 30), PlayerInput.device_label(slots[i]), PixelArt.C["W"])
			# learning mode: big friendly label with stars
			var lv := int(learn[i]) if i < learn.size() else 0
			var lcol: Color = PixelArt.C[LEARN_COLORS[lv]]
			draw_rect(Rect2(x + 3, y + 40, 134, 25), Color(lcol, 0.14 if lv > 0 else 0.05))
			PixelArt.draw_text(self, Vector2(x + 6, y + 42), "LEARNING MODE", PixelArt.C["W"] if lv > 0 else PixelArt.C["g"])
			for st in 3:
				var on := st < lv
				var bob := roundf(sin(_t * 4.0 + st) * 1.0) if on else 0.0
				draw_texture(PixelArt.tex("star"), Vector2(x + 106 + st * 10, y + 40 + bob), Color(1, 1, 1, 1) if on else Color(0.3, 0.3, 0.35, 0.8))
			PixelArt.draw_text_centered(self, Vector2(cx, y + 51), GameManager.LEARNING_NAMES[lv], lcol, true, 12)
			var hint := "%s: LEARNING" % _ud_glyph(slots[i])
			if slots.size() == 1:
				hint += "   < >: MECH"
			else:
				hint += "   [%s] LEAVE" % inputs[i].glyph("back")
			PixelArt.draw_text_centered(self, Vector2(cx, y + 70), hint, PixelArt.C["g"], false)
		else:
			var blink := int(_t * 2.0) % 2 == 0
			if blink:
				PixelArt.draw_text_centered(self, Vector2(cx, y + 22), "P%d PRESS TO JOIN" % (i + 1), PixelArt.C["w"], true)
			PixelArt.draw_text_centered(self, Vector2(cx, y + 38), "KEYBOARD: E  /  ARROWS: ENTER", PixelArt.C["g"], false)
			PixelArt.draw_text_centered(self, Vector2(cx, y + 48), "GAMEPAD: (A)", PixelArt.C["g"], false)


func _draw_footer() -> void:
	if slots.size() > 0:
		# difficulty badge (P1 toggles)
		var kid := GameManager.difficulty == "kid"
		var vent: String = inputs[0].glyph("vent")
		if kid:
			var bob := roundf(sin(_t * 5.0) * 1.0)
			PixelArt.draw_text_centered(self, Vector2(320, 291 + bob), "KID MODE!", PixelArt.C["p"], true, 12)
			PixelArt.draw_text_centered(self, Vector2(320, 305), "TOUGHER SILO - SLOWER RATS - MORE SEEDS   [%s] NORMAL" % vent, PixelArt.C["w"], true)
		else:
			PixelArt.draw_text_centered(self, Vector2(320, 291), "NORMAL MODE", PixelArt.C["W"], true, 12)
			PixelArt.draw_text_centered(self, Vector2(320, 305), "P1: [%s] SWITCH TO KID MODE" % vent, PixelArt.C["g"], true)
		var g: String = inputs[0].glyph("confirm")
		var c := PixelArt.C["y"] if int(_t * 3.0) % 2 == 0 else PixelArt.C["w"]
		PixelArt.draw_text_centered(self, Vector2(320, 317), "P1: PRESS [%s] AGAIN TO DEFEND THE SILO" % g, c, true)
	else:
		PixelArt.draw_text_centered(self, Vector2(320, 296), "JOIN WITH ANY DEVICE. TWO PILOTS? SHARE THE KEYBOARD OR GRAB PADS.", PixelArt.C["W"], true)
	PixelArt.draw_text_centered(self, Vector2(320, 329), "[TAB] / (Y)  CONTROLS & HOW TO PLAY", PixelArt.C["u"], true)
	PixelArt.draw_text_centered(self, Vector2(320, 340), "THE UNDER-SCURRIERS WANT THE STRIPED ONES. STOP THEM.", PixelArt.C["z"], true)
	PixelArt.draw_text(self, Vector2(6, 351), "ESC: QUIT", PixelArt.C["G"].lightened(0.3))
	var fs := "F11: WINDOW" if GameManager.is_fullscreen() else "F11: FULLSCREEN"
	PixelArt.draw_text(self, Vector2(634 - PixelArt.text_width(fs), 351), fs, PixelArt.C["G"].lightened(0.3))


func _draw_controls_page() -> void:
	var r := Rect2(16, 96, 608, 252)
	PixelArt.draw_box(self, r, Color(0.08, 0.05, 0.1, 0.96), PixelArt.C["u"])
	PixelArt.draw_text_centered(self, Vector2(320, r.position.y + 5), "CONTROLS", PixelArt.C["u"], true, 12)
	var cols := [r.position.x + 8, r.position.x + 128, r.position.x + 232, r.position.x + 300]
	var heads := ["", "KEYBOARD+MOUSE", "ARROWS (P2)", "GAMEPAD"]
	var y := r.position.y + 22
	for i in 4:
		PixelArt.draw_text(self, Vector2(cols[i], y), heads[i], PixelArt.C["y"])
	y += 9
	for row in CONTROLS:
		for i in 4:
			var col := PixelArt.C["w"] if i == 0 else PixelArt.C["W"]
			PixelArt.draw_text(self, Vector2(cols[i], y), row[i], col)
		y += 8
	# tower legend
	y += 6
	PixelArt.draw_text(self, Vector2(cols[0], y), "TOWERS  (BUILD ON WOODEN PADS WITH BANKED SEEDS)", PixelArt.C["y"])
	y += 9
	for kind in GameManager.TOWER_TYPES:
		var info: Dictionary = GameManager.TOWER_INFO[kind]
		PixelArt.draw_text(self, Vector2(cols[0], y), info["short"], PixelArt.C["o"])
		PixelArt.draw_text(self, Vector2(cols[0] + 44, y), str(info["cost"]), PixelArt.C["y"])
		PixelArt.draw_text(self, Vector2(cols[0] + 60, y), info["desc"], PixelArt.C["W"])
		y += 8
	# how to play column
	var hx := r.position.x + 372
	var hy := r.position.y + 22
	PixelArt.draw_text(self, Vector2(hx, hy), "HOW TO PLAY", PixelArt.C["y"])
	hy += 9
	for tip in TIPS:
		hy = _wrap(Vector2(hx, hy), tip[0], 224.0, PixelArt.C[tip[1]]) + 3
	hy += 5
	PixelArt.draw_text(self, Vector2(hx, hy), "THE UNDER-SCURRIERS", PixelArt.C["y"])
	hy += 9
	for e in ENEMIES:
		PixelArt.draw_text(self, Vector2(hx, hy), e[0], PixelArt.C[e[2]].lightened(0.2))
		hy = _wrap(Vector2(hx + 6, hy + 7), e[1], 218.0, PixelArt.C["g"]) + 2
	draw_rect(Rect2(hx - 8, r.position.y + 22, 1, 214), PixelArt.C["G"])
	PixelArt.draw_text_centered(self, Vector2(320, r.end.y - 10), "PRESS [TAB] / (Y) OR CONFIRM TO GO BACK", PixelArt.C["g"], false)


func _wrap(pos: Vector2, text: String, width: float, col: Color) -> float:
	var line := ""
	var y := pos.y
	for word in text.split(" ", false):
		var test := word if line == "" else line + " " + word
		if PixelArt.text_width(test) > width and line != "":
			PixelArt.draw_text(self, Vector2(pos.x, y), line, col)
			y += 7
			line = word
		else:
			line = test
	if line != "":
		PixelArt.draw_text(self, Vector2(pos.x, y), line, col)
		y += 7
	return y
