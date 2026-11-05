extends Control
## Learning Mode quiz: a friendly, full-screen maths/thinking puzzle that "activates" an upgrade.
##
## CONTRACT
##   signal solved(player, first_try: bool)
##   var active: bool                 # true while a question (or a queued one) is showing
##   var player                       # the MechPlayer currently being asked
##   func ask(player, level: int, reason: String = "") -> void
## Lives at MainArena/OverlayLayer/MathQuiz (GameManager.arena.math_quiz). Processes ALWAYS:
## the caller usually pauses the tree. Polls only the asked player's PlayerInput
## (left/right + confirm/fire/interact); the keyboard+mouse pilot can also hover/click.
## If another player asks while one quiz is showing, the request is queued.
## Never punishes: a wrong answer wobbles, greys that button out (so the choices shrink) and
## starts a picture hint (counting along, a highlight, a guide line); after 2 misses the one
## button left is highlighted and pre-selected so even button-mashing finishes.
## Words are kept to a few: the prompt and the helper's bubble are short, the pictures do the talking.

signal solved(player, first_try: bool)

const PANEL := Rect2(36, 16, 568, 328)
const BTN_W := 124.0
const BTN_H := 80.0
const BTN_GAP := 14.0
const BTN_Y := 238.0
const PIC := Rect2(70, 62, 500, 168)          # picture-aid area
const INPUT_LOCK := 0.35
const CELEBRATE_TIME := 1.2
const COUNT_RATE := 1.8                       # hint numbers revealed per second
const COLOR_KEYS := {1: "r", 2: "A", 3: "y", 4: "Z", 5: "v"}
const ACTIONS := ["left", "right", "confirm", "fire", "interact"]
const CHEERS := ["YOU CAN DO IT!", "TAKE YOUR TIME!", "THINK, THINK, THINK...", "I BELIEVE IN YOU!"]
const PRAISE := ["YOU DID IT!", "SUPER SMART!", "AMAZING!", "WOW! GENIUS HAMSTER!", "BRILLIANT!"]

var active: bool = false
var player = null
var level: int = 1
var reason: String = ""
var q: Dictionary = {}
var sel: int = 1
var wrong_count: int = 0
var state: String = "ask"                     # ask | correct

var _queue: Array = []                        # [[player, level, reason], ...]
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _state_t := 0.0
var _lock_t := 0.0
var _hint_t := -1.0                           # >= 0 while the counting hint plays
var _hint_shown := 0
var _wobble := 0.0
var _wrong_choice := -1
var _tried: Array = [false, false, false]     # buttons already ruled out by a wrong answer
var _press_t := 0.0
var _first_try := true
var _bubble := ""
var _prev: Dictionary = {}
var _confetti: Array = []                     # [pos, vel, color, life]
var _last_us := 0
var _mouse_mode_before: int = Input.MOUSE_MODE_VISIBLE
var _uses_mouse := false
var _lmb_prev := false
var _mouse_prev := Vector2.ZERO
var _plus_t := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_rng.randomize()


# ------------------------------------------------------------------ API

func ask(p, lvl: int, why: String = "") -> void:
	if active:
		if p == player:
			return
		for item in _queue:
			if item[0] == p:
				return
		_queue.append([p, lvl, why])
		return
	_start(p, lvl, why)


func _start(p, lvl: int, why: String) -> void:
	player = p
	level = clampi(lvl, 1, 3)
	reason = why
	q = MathQuestions.make(level, _rng)
	sel = 1
	wrong_count = 0
	state = "ask"
	_t = 0.0
	_state_t = 0.0
	_lock_t = 0.0
	_hint_t = -1.0
	_hint_shown = 0
	_wobble = 0.0
	_wrong_choice = -1
	_tried = [false, false, false]
	_press_t = 0.0
	_first_try = true
	_plus_t = -1.0
	_confetti.clear()
	_bubble = CHEERS[_rng.randi() % CHEERS.size()]
	_last_us = Time.get_ticks_usec()
	GameManager.math_asked += 1
	# snapshot held buttons so a still-held confirm doesn't instantly answer
	_prev.clear()
	var inp = _pinput()
	if inp != null:
		inp.update(null)
		for a in ACTIONS:
			_prev[a] = inp.held(a)
	_uses_mouse = inp != null and inp.device == "kbm"
	if _uses_mouse:
		_mouse_mode_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_lmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_mouse_prev = get_global_mouse_position()
	active = true
	visible = true
	Sfx.play("upgrade", 1.25, -6.0)
	queue_redraw()


func _pinput():
	if player == null or not is_instance_valid(player):
		return null
	return player.get("input")


func _finish() -> void:
	var p = player
	var ft := _first_try
	visible = false
	if _uses_mouse:
		Input.mouse_mode = _mouse_mode_before
	_uses_mouse = false
	player = null
	active = false
	if not _queue.is_empty():
		var nxt: Array = _queue.pop_front()
		_start(nxt[0], int(nxt[1]), String(nxt[2]))
	solved.emit(p, ft)


# ------------------------------------------------------------------ loop

func _process(_delta: float) -> void:
	if not visible:
		return
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	_t += dt
	_state_t += dt
	_lock_t = maxf(0.0, _lock_t - dt)
	_wobble = maxf(0.0, _wobble - dt * 2.2)
	_press_t = maxf(0.0, _press_t - dt)
	if _plus_t >= 0.0:
		_plus_t += dt
	_tick_confetti(dt)
	if _hint_t >= 0.0:
		_hint_t += dt
		var shown := int(_hint_t * COUNT_RATE)
		if shown > _hint_shown:
			_hint_shown = shown
			if shown <= _hint_total():
				Sfx.play("blip_hamster", 1.0 + shown * 0.06, -10.0)
	if state == "correct":
		if _state_t >= CELEBRATE_TIME:
			_finish()
		queue_redraw()
		return
	if _pinput() == null:
		# the pilot vanished (scene change); don't leave the game stuck
		_first_try = false
		_finish()
		return
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	var inp = _pinput()
	inp.update(null)
	var held: Dictionary = {}
	for a in ACTIONS:
		held[a] = inp.held(a)
	var can_answer := _t >= INPUT_LOCK and _lock_t <= 0.0
	var lmb := false
	if _uses_mouse:
		var m := get_global_mouse_position()
		lmb = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var click := lmb and not _lmb_prev
		_lmb_prev = lmb
		var moved := m.distance_to(_mouse_prev) > 0.5
		_mouse_prev = m
		for i in 3:
			if _btn_rect(i).has_point(m) and not _tried[i]:
				if moved and sel != i:
					sel = i
					Sfx.play("select", 1.2, -8.0)
				if click and can_answer:
					sel = i
					_answer(i)
					_prev = held
					return
	if can_answer:
		if _edge(held, "left"):
			sel = _step_sel(-1)
			Sfx.play("select")
		if _edge(held, "right"):
			sel = _step_sel(1)
			Sfx.play("select")
		var confirm := _edge(held, "confirm") or _edge(held, "fire") or _edge(held, "interact")
		if confirm and not (_uses_mouse and lmb):
			_answer(sel)
	_prev = held


func _edge(held: Dictionary, a: String) -> bool:
	return bool(held.get(a, false)) and not bool(_prev.get(a, false))


## Next button in `dir` that hasn't been ruled out (stays put once the answer is showing).
func _step_sel(dir: int) -> int:
	if wrong_count >= 2:
		return sel
	var s := sel
	for k in 3:
		s = (s + dir + 3) % 3
		if not _tried[s]:
			return s
	return sel


func _answer(i: int) -> void:
	if _tried[i]:
		return
	var choices: Array = q["choices"]
	var choice: int = int(choices[i])
	_press_t = 0.12
	if choice == int(q["answer"]):
		state = "correct"
		_state_t = 0.0
		_plus_t = 0.0
		_bubble = PRAISE[_rng.randi() % PRAISE.size()]
		GameManager.math_stars += 1
		GameManager.add_seeds(5)
		Sfx.play("card", 1.0, -2.0)
		Sfx.play("squeak_hamster", 1.5, -6.0)
		var r := _btn_rect(i)
		_burst(r.get_center(), 70)
		_burst(Vector2(320, 120), 40)
	else:
		wrong_count += 1
		_first_try = false
		_tried[i] = true
		_wrong_choice = i
		_wobble = 1.0
		_lock_t = 0.35
		Sfx.play("deny", 1.2, -14.0)
		_bubble = "TRY AGAIN! " + String(q.get("hint", ""))
		if _hint_t < 0.0:
			_hint_t = 0.0
		sel = i
		sel = _step_sel(1)
		if wrong_count >= 2:
			sel = _correct_index()
			_bubble = "THIS ONE!"


func _correct_index() -> int:
	var choices: Array = q["choices"]
	for i in choices.size():
		if int(choices[i]) == int(q["answer"]):
			return i
	return 0


func _hint_total() -> int:
	var v: Dictionary = q.get("visual", {})
	match String(v.get("kind", "")):
		"count":
			return int(v["n"])
		"add":
			return int(v["a"]) + int(v["b"])
		"sub":
			return int(v["a"]) - int(v["b"])
		"missing":
			return int(v["total"]) - int(v["known"])
		"sequence":
			return 3
		"pattern":
			return (v["items"] as Array).size()
		"scale":
			return 2
	return 3


# ------------------------------------------------------------------ confetti

func _burst(at: Vector2, n: int) -> void:
	var cols := ["r", "y", "u", "p", "Z", "v", "o"]
	for k in n:
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var v := Vector2.from_angle(a) * _rng.randf_range(80.0, 260.0)
		_confetti.append([at, v, PixelArt.C[cols[_rng.randi() % cols.size()]], _rng.randf_range(0.7, 1.4)])


func _tick_confetti(dt: float) -> void:
	var k := _confetti.size() - 1
	while k >= 0:
		var c: Array = _confetti[k]
		c[3] = float(c[3]) - dt
		if float(c[3]) <= 0.0:
			_confetti.remove_at(k)
		else:
			var v: Vector2 = c[1]
			v.y += 420.0 * dt
			v.x *= 1.0 - 1.5 * dt
			c[1] = v
			c[0] = (c[0] as Vector2) + v * dt
		k -= 1


# ------------------------------------------------------------------ layout helpers

func _btn_rect(i: int) -> Rect2:
	var total := BTN_W * 3.0 + BTN_GAP * 2.0
	return Rect2(roundf(320.0 - total / 2.0 + i * (BTN_W + BTN_GAP)), BTN_Y, BTN_W, BTN_H)


func _pcolor() -> Color:
	if player != null and is_instance_valid(player) and player.has_method("color"):
		return player.color()
	return PixelArt.C["o"]


func _pid() -> int:
	if player != null and is_instance_valid(player):
		var v = player.get("player_id")
		if v != null:
			return int(v)
	return 1


func _icon_tex(icon: String) -> Texture2D:
	match icon:
		"rat":
			return PixelArt.tex("rat_squeaker_0")
		"ham":
			return PixelArt.tex("ham_head_0")
		"heart":
			return PixelArt.tex("icon_heart")
	return PixelArt.tex("seed_icon")


## Lays out `slots` (each {"t": "item"|"empty"|"bonk", "label": int}) in rows of 5 inside `area`,
## choosing the biggest integer scale that fits. Labels appear when hint counting reaches them.
func _draw_slots(area: Rect2, slots: Array, icon: String, max_scale: int = 4, per_row: int = 5) -> void:
	var n := slots.size()
	if n == 0:
		return
	var tex := _icon_tex(icon)
	var sz := tex.get_size()
	var cols := mini(n, per_row)
	var rows := int(ceil(n / float(per_row)))
	var mid := cols > 5          # rows of ten get a "5 | 5" gap, like a ten-frame
	var scale := 1
	var label_h := 0.0
	var any_label := false
	for sl in slots:
		if int((sl as Dictionary).get("label", 0)) > 0:
			any_label = true
	for s in range(max_scale, 0, -1):
		var gx := 4.0 * s
		var lh := 0.0
		if _hint_t >= 0.0 and any_label:
			lh = 14.0 if s >= 2 else 9.0
		var w := cols * (sz.x * s + gx) - gx + (gx * 2.0 if mid else 0.0)
		var h := rows * (sz.y * s + 3.0 * s + lh) - 3.0 * s
		if w <= area.size.x and h <= area.size.y:
			scale = s
			label_h = lh
			break
	var gap := 4.0 * scale
	var cw := sz.x * scale + gap
	var ch := sz.y * scale + 3.0 * scale + label_h
	var mid_gap := gap * 2.0 if mid else 0.0
	var block := Vector2(cols * cw - gap + mid_gap, rows * ch - 3.0 * scale)
	var origin := (area.get_center() - block / 2.0).round()
	for i in n:
		var slot: Dictionary = slots[i]
		var cx := i % per_row
		var cy := int(i / per_row)
		var pos := origin + Vector2(cx * cw + (mid_gap if cx >= 5 else 0.0), cy * ch)
		var r := Rect2(pos, sz * scale)
		match String(slot["t"]):
			"empty":
				var dash: Color = PixelArt.C["g"]
				PixelArt.draw_ring(self, r.get_center(), minf(r.size.x, r.size.y) * 0.45, dash, 16)
				PixelArt.draw_ring(self, r.get_center(), minf(r.size.x, r.size.y) * 0.45 - 1.0, Color(dash, 0.5), 16)
			"bonk":
				draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.45))
				var red: Color = PixelArt.C["r"]
				var th := maxf(2.0, scale)
				draw_line(r.position, r.end, red, th)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), red, th)
				if scale >= 2:
					PixelArt.draw_text(self, r.position + Vector2(r.size.x - 6, -6), "*", PixelArt.C["y"])
			_:
				var bob := 0.0
				if state == "correct":
					bob = -absf(sin(_t * 10.0 + i * 0.6)) * 2.0
				draw_texture_rect(tex, Rect2(r.position + Vector2(0, bob), r.size), false)
		var label: int = int(slot.get("label", 0))
		if label > 0 and _hint_t >= 0.0 and label <= _hint_shown:
			var lp := Vector2(r.get_center().x, r.end.y + 2.0)
			PixelArt.draw_text_centered(self, lp, str(label), PixelArt.C["n"], false, 12 if scale >= 2 else 6)


## Big pixel shape for shape puzzles and shape patterns.
func _draw_shape(code: int, c: Vector2, r: float, col: Color) -> void:
	var k: Color = PixelArt.C["k"]
	c = c.round()
	match code:
		1:
			PixelArt.draw_disk(self, c, r + 1.0, k)
			PixelArt.draw_disk(self, c, r, col)
		2:
			draw_rect(Rect2(c - Vector2(r, r) - Vector2(1, 1), Vector2(r, r) * 2.0 + Vector2(2, 2)), k)
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), col)
		3:
			var pts := PackedVector2Array([c + Vector2(0, -r * 1.05), c + Vector2(r * 1.1, r * 0.85), c + Vector2(-r * 1.1, r * 0.85)])
			_poly_outlined(pts, col, k)
		4:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + PI * i / 5.0
				var rr := r * 1.1 if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2.from_angle(a) * rr)
			_poly_outlined(pts, col, k)
		5:
			var hr := r * 0.55
			PixelArt.draw_disk(self, c + Vector2(-hr, -hr * 0.5), hr + 1.0, k)
			PixelArt.draw_disk(self, c + Vector2(hr, -hr * 0.5), hr + 1.0, k)
			var tri := PackedVector2Array([c + Vector2(-r * 1.08, -hr * 0.2), c + Vector2(r * 1.08, -hr * 0.2), c + Vector2(0, r * 1.05)])
			_poly_outlined(tri, col, k)
			PixelArt.draw_disk(self, c + Vector2(-hr, -hr * 0.5), hr, col)
			PixelArt.draw_disk(self, c + Vector2(hr, -hr * 0.5), hr, col)
		6:
			var pts := PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 0.85, 0), c + Vector2(0, r * 1.15), c + Vector2(-r * 0.85, 0)])
			_poly_outlined(pts, col, k)
		_:
			PixelArt.draw_text_centered(self, c - Vector2(0, 8), "?", k, false, 18)


## Big text with a crisp 1px outline (the shared helper scales its outline with the font).
func _text_o1(pos: Vector2, text: String, col: Color, size: int, centered: bool = false,
		outline: Color = Color8(26, 16, 32)) -> void:
	if centered:
		pos.x -= roundf(PixelArt.text_width(text, size) / 2.0)
	pos = pos.round()
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		PixelArt.draw_text(self, pos + o, text, outline, size)
	PixelArt.draw_text(self, pos, text, col, size)


## Opaque light tint of a colour over the cream panel (so text in that colour stays readable).
func _tint(c: Color) -> Color:
	return PixelArt.C["w"].lerp(c, 0.22)


func _poly_outlined(pts: PackedVector2Array, col: Color, outline: Color) -> void:
	draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, outline, 2.0)


func _draw_code(style: String, code: int, c: Vector2, r: float) -> void:
	if style == "color":
		var key: String = COLOR_KEYS.get(code, "w")
		PixelArt.draw_disk(self, c, r + 1.0, PixelArt.C["k"])
		PixelArt.draw_disk(self, c, r, PixelArt.C[key])
		PixelArt.draw_disk(self, c + Vector2(-r * 0.35, -r * 0.35), maxf(1.0, r * 0.25), Color(1, 1, 1, 0.6))
	else:
		_draw_shape(code, c, r, PixelArt.C["o"])


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


func _wrap(text: String, max_chars: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for word in text.split(" ", false):
		if cur == "":
			cur = word
		elif cur.length() + 1 + word.length() <= max_chars:
			cur += " " + word
		else:
			out.append(cur)
			cur = word
	if cur != "":
		out.append(cur)
	return out


# ------------------------------------------------------------------ draw

func _draw() -> void:
	if not visible or q.is_empty():
		return
	var pc := _pcolor()
	var k: Color = PixelArt.C["k"]
	var cream: Color = PixelArt.C["w"]
	var pop := clampf(_t / 0.18, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.03, 0.08, 0.72 * pop))
	# panel with a thick player-coloured frame
	var panel := PANEL
	panel.position.y += roundf((1.0 - pop) * 30.0)
	draw_rect(Rect2(panel.position + Vector2(3, 4), panel.size), Color(0, 0, 0, 0.35))
	PixelArt.draw_box(self, panel.grow(3), pc, k)
	PixelArt.draw_box(self, panel, cream, k)
	# polka dots on the panel background (playful, very faint)
	for i in 18:
		var dp := Vector2(panel.position.x + 20 + (i * 97) % int(panel.size.x - 40), panel.position.y + 30 + (i * 53) % int(panel.size.y - 60))
		PixelArt.draw_disk(self, dp, 3.0, Color(pc, 0.08))
	# header strip
	var head := Rect2(panel.position.x + 2, panel.position.y + 2, panel.size.x - 4, 13)
	draw_rect(head, pc)
	PixelArt.draw_text(self, head.position + Vector2(5, 4), "P%d" % _pid(), k, 6)
	var lvl_name := ""
	var names: Array = GameManager.LEARNING_NAMES
	if level < names.size():
		lvl_name = String(names[level])
	if lvl_name != "":
		var lw := PixelArt.text_width(lvl_name)
		PixelArt.draw_text(self, Vector2(head.end.x - lw - 6, head.position.y + 4), lvl_name, k)
	if reason != "":
		PixelArt.draw_text_centered(self, Vector2(320, head.position.y + 4), reason.to_upper(), k, false)
	var dy := panel.position.y - PANEL.position.y
	# prompt
	PixelArt.draw_text_centered(self, Vector2(320, 38 + dy), String(q["prompt"]), k, false, 18)
	# picture aid
	_draw_picture(dy)
	# answer buttons
	for i in 3:
		_draw_button(i, dy)
	# helper hamster + speech bubble (bottom-left)
	_draw_helper(dy)
	# star counter (bottom-right)
	var sc := Vector2(560, 300 + dy)
	_draw_star(sc, 9.0, PixelArt.C["Y"])
	_draw_star(sc, 7.0, PixelArt.C["y"])
	PixelArt.draw_text_centered(self, sc + Vector2(0, 12), "X%d" % GameManager.math_stars, k, false, 12)
	if _plus_t >= 0.0:
		var pa := clampf(1.0 - (_plus_t - 0.6) / 0.6, 0.0, 1.0)
		var pp := sc + Vector2(-2, -18 - _plus_t * 24.0)
		var col: Color = PixelArt.C["Y"]
		col.a = pa
		draw_texture(PixelArt.tex("seed_icon"), pp + Vector2(-14, 2), Color(1, 1, 1, pa))
		PixelArt.draw_text(self, pp + Vector2(-4, 0), "+5", col, 12)
	# celebration headline
	if state == "correct":
		draw_rect(Rect2(PIC.position + Vector2(0, dy + 40), Vector2(PIC.size.x, 52)), Color(1.0, 0.97, 0.9, 0.75))
		var s := 1.0 + 0.25 * maxf(0.0, 1.0 - _state_t * 5.0)
		var size := 30 if s < 1.1 else 36
		PixelArt.draw_text_centered(self, Vector2(320, 120 + dy - (size - 30)), _bubble, PixelArt.C["Z"], true, size)
	# confetti on top
	for c in _confetti:
		var p: Vector2 = c[0]
		var col2: Color = c[2]
		col2.a = clampf(float(c[3]) * 2.0, 0.0, 1.0)
		draw_rect(Rect2(p.round(), Vector2(2, 2)), col2)


func _draw_picture(dy: float) -> void:
	var v: Dictionary = q["visual"]
	var area := PIC
	area.position.y += dy
	var pc := _pcolor()
	var qmark := "?" if state != "correct" else str(q["answer"])
	var qcol := pc if state != "correct" else PixelArt.C["Z"]
	if state != "correct" and int(_t * 2.5) % 2 == 0:
		qcol = qcol.darkened(0.25)
	match String(v.get("kind", "")):
		"count":
			var slots: Array = []
			for i in int(v["n"]):
				slots.append({"t": "item", "label": i + 1})
			_draw_slots(Rect2(area.position + Vector2(0, 4), area.size - Vector2(0, 8)), slots, String(v["icon"]), 4, 10 if slots.size() > 10 else 5)
		"add":
			var a := int(v["a"])
			var b := int(v["b"])
			var top := Rect2(area.position, Vector2(area.size.x, 112))
			var left: Array = []
			var right: Array = []
			for i in a:
				left.append({"t": "item", "label": i + 1})
			for i in b:
				right.append({"t": "item", "label": a + i + 1})
			var ms := 4 if maxi(a, b) <= 5 else 3
			_draw_slots(Rect2(top.position, Vector2(top.size.x / 2.0 - 20, top.size.y)), left, String(v["icon"]), ms)
			_draw_slots(Rect2(top.position + Vector2(top.size.x / 2.0 + 20, 0), Vector2(top.size.x / 2.0 - 20, top.size.y)), right, String(v["icon"]), ms)
			PixelArt.draw_text_centered(self, Vector2(320, top.get_center().y - 12), "+", PixelArt.C["n"], false, 30)
			_draw_equation(["%d" % a, "+", "%d" % b, "=", qmark], area.position.y + 118, qcol)
		"sub":
			var a2 := int(v["a"])
			var b2 := int(v["b"])
			var slots2: Array = []
			for i in a2:
				var bonked := i >= a2 - b2
				slots2.append({"t": "bonk" if bonked else "item", "label": 0 if bonked else i + 1})
			_draw_slots(Rect2(area.position, Vector2(area.size.x, 112)), slots2, String(v["icon"]), 3, 10 if a2 > 10 else 5)
			_draw_equation(["%d" % a2, "-", "%d" % b2, "=", qmark], area.position.y + 118, qcol)
		"missing":
			var known := int(v["known"])
			var total := int(v["total"])
			var unknown_first: bool = v.get("unknown_first", true)
			var miss := total - known
			var slots3: Array = []
			if unknown_first:
				for i in miss:
					slots3.append({"t": "item" if state == "correct" else "empty", "label": i + 1})
				for i in known:
					slots3.append({"t": "item", "label": 0})
			else:
				for i in known:
					slots3.append({"t": "item", "label": 0})
				for i in miss:
					slots3.append({"t": "item" if state == "correct" else "empty", "label": i + 1})
			_draw_slots(Rect2(area.position, Vector2(area.size.x, 112)), slots3, String(v["icon"]), 3, 10 if total > 10 else 5)
			if unknown_first:
				_draw_equation([qmark, "+", "%d" % known, "=", "%d" % total], area.position.y + 118, qcol, 0)
			else:
				_draw_equation(["%d" % known, "+", qmark, "=", "%d" % total], area.position.y + 118, qcol, 2)
		"sequence":
			_draw_sequence(v, area, qmark, qcol)
		"pattern":
			_draw_pattern(v, area, qcol)
		"odd":
			_draw_odd(v, area)
		"same":
			_draw_same(v, area)
		"sizes":
			_draw_sizes(v, area)
		"order":
			_draw_order(v, area, qcol)
		"mirror":
			_draw_mirror(v, area, qcol)
		"piece":
			_draw_piece(v, area, qcol)
		"scale":
			_draw_scale(v, area)
		"chain":
			_draw_chain(v, area, qcol)
		_:
			# piles / numbers / shape: a big thinking hamster fills the picture area
			var hz := PixelArt.tex("ham_head_%d" % (6 if state == "correct" else 1))
			var bob := roundf(sin(_t * 3.0) * 2.0)
			var hp := Vector2(320, area.get_center().y - 6 + bob)
			draw_set_transform(hp, 0.0, Vector2(4, 4))
			draw_texture(hz, -hz.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if state != "correct":
				for i in 3:
					var on := int(_t * 3.0) % 4 > i
					if on:
						PixelArt.draw_disk(self, hp + Vector2(56 + i * 10, -34 - i * 6), 2.0 + i, PixelArt.C["g"])


## Draws tokens like ["3", "+", "4", "=", "?"] big and centred; token `q_index` (default last) is
## the unknown and gets the pulsing player colour.
func _draw_equation(tokens: Array, y: float, qcol: Color, q_index: int = -1) -> void:
	if q_index < 0:
		q_index = tokens.size() - 1
	var size := 30
	var gap := 12.0
	var widths: Array = []
	var total := 0.0
	for t in tokens:
		var w := float(PixelArt.text_width(String(t), size))
		widths.append(w)
		total += w
	total += gap * (tokens.size() - 1)
	var x := 320.0 - total / 2.0
	for i in tokens.size():
		var col: Color = PixelArt.C["k"]
		if i == q_index:
			col = qcol
			# box behind the unknown
			var br := Rect2(x - 4, y - 3, float(widths[i]) + 8, 31)
			PixelArt.draw_box(self, br.grow(1), qcol, PixelArt.C["k"])
			PixelArt.draw_box(self, br, _tint(qcol), qcol)
		elif String(tokens[i]) == "+" or String(tokens[i]) == "-" or String(tokens[i]) == "=":
			col = PixelArt.C["n"]
		if i == q_index:
			_text_o1(Vector2(roundf(x), y), String(tokens[i]), col, size)
		else:
			PixelArt.draw_text(self, Vector2(roundf(x), y), String(tokens[i]), col, size)
		x += float(widths[i]) + gap


func _draw_sequence(v: Dictionary, area: Rect2, qmark: String, qcol: Color) -> void:
	var items: Array = v["items"]
	var step := int(v.get("step", 1))
	var n := items.size() + 1
	var bw := 64.0
	var gap := 22.0
	var total := n * bw + (n - 1) * gap
	var x0 := 320.0 - total / 2.0
	var y := area.position.y + 40
	for i in n:
		var r := Rect2(roundf(x0 + i * (bw + gap)), y, bw, 52)
		var is_q := i == items.size()
		var fill: Color = PixelArt.C["c"] if not is_q else _tint(qcol)
		var bcol: Color = qcol if is_q else PixelArt.C["k"]
		PixelArt.draw_box(self, r, fill, bcol)
		var txt: String = qmark if is_q else str(items[i])
		var col: Color = qcol if is_q else PixelArt.C["k"]
		if is_q:
			_text_o1(Vector2(r.get_center().x, r.position.y + 13), txt, col, 30, true)
		else:
			PixelArt.draw_text_centered(self, Vector2(r.get_center().x, r.position.y + 13), txt, col, false, 30)
		# hint: hop arrows "+1" between boxes
		if i < n - 1 and _hint_t >= 0.0 and _hint_shown > i:
			var ax := r.end.x + gap / 2.0
			var lbl := ("+%d" % step) if step > 0 else ("%d" % step)
			PixelArt.draw_text_centered(self, Vector2(ax, y - 16), lbl, PixelArt.C["n"], false, 12)
			draw_arc(Vector2(ax, y - 2), gap * 0.9, PI * 1.15, PI * 1.85, 8, PixelArt.C["n"], 1.0)


func _draw_pattern(v: Dictionary, area: Rect2, qcol: Color) -> void:
	var items: Array = v["items"]
	var style := String(v.get("style", "color"))
	var unit := int(v.get("unit", 2))
	var n := items.size() + 1
	var bw := 40.0
	var gap := 8.0
	var total := n * bw + (n - 1) * gap
	var x0 := 320.0 - total / 2.0
	var y := area.position.y + 46
	for i in n:
		var r := Rect2(roundf(x0 + i * (bw + gap)), y, bw, bw)
		var is_q := i == items.size()
		if is_q:
			if state == "correct":
				PixelArt.draw_box(self, r, _tint(PixelArt.C["Z"]), PixelArt.C["Z"])
				_draw_code(style, int(q["answer"]), r.get_center(), 13.0)
			else:
				PixelArt.draw_box(self, r, _tint(qcol), qcol)
				_text_o1(Vector2(r.get_center().x, r.position.y + 8), "?", qcol, 30, true)
		else:
			_draw_code(style, int(items[i]), r.get_center(), 13.0)
	# hint: brackets under each repeat of the unit
	if _hint_t >= 0.0:
		var groups := int(ceil(items.size() / float(unit)))
		for g in groups:
			if g >= _hint_shown:
				break
			var a := x0 + g * unit * (bw + gap)
			var b := minf(a + unit * (bw + gap) - gap, x0 + n * (bw + gap) - gap)
			var by := y + bw + 6
			var col: Color = PixelArt.C["n"] if g % 2 == 0 else PixelArt.C["P"]
			draw_rect(Rect2(roundf(a), by, roundf(b - a), 2), col)
			draw_rect(Rect2(roundf(a), by - 3, 2, 3), col)
			draw_rect(Rect2(roundf(b) - 2, by - 3, 2, 3), col)


# ------------------------------------------------------------------ picture puzzles
# Every picture is drawn from the question's `visual` data (see MathQuestions). `area` is PIC with
# the pop-in offset already applied; a pulsing frame / guide line / totals appear once `_hint_t` >= 0.

func _col(code: int) -> Color:
	var key: String = COLOR_KEYS.get(code, "w")
	return PixelArt.C[key]


func _pulse(col: Color) -> Color:
	return col.lerp(Color.WHITE, 0.4 * (0.5 + 0.5 * sin(_t * 8.0)))


func _frame(r: Rect2, col: Color, th: float = 2.0) -> void:
	r = Rect2(r.position.round(), r.size.round())
	draw_rect(Rect2(r.position, Vector2(r.size.x, th)), col)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - th), Vector2(r.size.x, th)), col)
	draw_rect(Rect2(r.position, Vector2(th, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(r.size.x - th, 0), Vector2(th, r.size.y)), col)


## Pulsing yellow frame with a dark edge on both sides, so it shows on any colour.
func _hl(r: Rect2) -> void:
	_frame(r.grow(3), PixelArt.C["k"], 1.0)
	_frame(r.grow(2), _pulse(PixelArt.C["y"]), 2.0)
	_frame(r, PixelArt.C["k"], 1.0)


func _arrow_down(at: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(at.x - 7, at.y), Vector2(at.x + 7, at.y), Vector2(at.x, at.y + 8)])
	_poly_outlined(pts, col, PixelArt.C["k"])


func _pix(ch: String) -> Color:
	if ch == ".":
		return PixelArt.C["a"].lightened(0.3)
	var c: Color = PixelArt.C.get(ch, PixelArt.C["w"])
	return c


## Dots laid out like a dice face, rows centred.
func _draw_dots(n: int, c: Vector2, sp: float, r: float, col: Color) -> void:
	var per := 2 if n == 4 else 3
	var rows := int(ceil(n / float(per)))
	for i in n:
		var row := int(i / per)
		var in_row := mini(per, n - row * per)
		var x := c.x + (i % per - (in_row - 1) / 2.0) * sp
		var y := c.y + (row - (rows - 1) / 2.0) * sp
		PixelArt.draw_disk(self, Vector2(x, y), r + 1.0, PixelArt.C["k"])
		PixelArt.draw_disk(self, Vector2(x, y), r, col)


## One thing from a puzzle: a coloured shape, a sprite, a bar or a dot card (see MathQuestions).
## `shadow` paints it as a dark silhouette.
func _draw_glyph(g: Dictionary, c: Vector2, shadow: bool = false, zoom: float = 1.0) -> void:
	c = c.round()
	var k: Color = PixelArt.C["k"]
	var dark := Color8(70, 56, 86)
	if g.has("icon"):
		var tex := _icon_tex(String(g["icon"]))
		var sz := tex.get_size()
		var sc := maxi(1, roundi(30.0 * zoom / sz.y))
		while sc > 1 and sz.x * sc > 64.0 * zoom:
			sc -= 1
		draw_texture_rect(tex, Rect2((c - sz * float(sc) / 2.0).round(), sz * float(sc)), false,
			Color(0.28, 0.22, 0.34) if shadow else Color.WHITE)
	elif g.has("bar"):
		var vertical := bool(g.get("v", false))
		var size := Vector2(14.0, float(g["bar"])) if vertical else Vector2(float(g["bar"]), 14.0)
		var br := Rect2((c - size / 2.0).round(), size)
		var col: Color = dark if shadow else _col(int(g.get("c", 1)))
		PixelArt.draw_box(self, br, col, k)
		var shine := Vector2(2, br.size.y - 4) if vertical else Vector2(br.size.x - 4, 2)
		draw_rect(Rect2(br.position + Vector2(2, 2), shine), col.lightened(0.4))
	elif g.has("n"):
		_draw_dots(int(g["n"]), c, 11.0 * zoom, 3.0 * zoom, _col(int(g.get("c", 1))))
	else:
		var col2: Color = dark if shadow else _col(int(g.get("c", 1)))
		_draw_shape(int(g.get("s", 1)), c, float(g.get("z", 14)), col2)


## A hole in a row: a pulsing "?" box in the player's colour (or the answer once it is solved).
func _draw_hole(r: Rect2, qcol: Color, size: int = 30) -> void:
	if state == "correct":
		PixelArt.draw_box(self, r, _tint(PixelArt.C["Z"]), PixelArt.C["Z"])
		return
	PixelArt.draw_box(self, r, _tint(qcol), qcol)
	_text_o1(Vector2(r.get_center().x, r.position.y + r.size.y / 2.0 - size * 5.0 / 12.0), "?", qcol, size, true)


## Odd one out: tap the picture that is different. Hint: a pulsing frame and an arrow on it.
func _draw_odd(v: Dictionary, area: Rect2) -> void:
	var items: Array = v["items"]
	var oi := int(v["odd"])
	var n := items.size()
	var tw := 66.0
	var gap := 12.0
	var x0 := 320.0 - (n * tw + (n - 1) * gap) / 2.0
	var y := area.position.y + 47.0
	for i in n:
		var r := Rect2(roundf(x0 + i * (tw + gap)), y, tw, tw)
		var is_odd := i == oi
		if state == "correct" and is_odd:
			r.position.y -= roundf(absf(sin(_state_t * 11.0)) * 6.0 * maxf(0.0, 1.0 - _state_t))
		PixelArt.draw_box(self, r, Color8(255, 240, 200), PixelArt.C["k"])
		_draw_glyph(items[i], r.get_center())
		if is_odd and state == "correct":
			_frame(r.grow(3), PixelArt.C["Z"], 3.0)
		elif is_odd and _hint_t >= 0.0:
			_hl(r.grow(1))
			_arrow_down(Vector2(r.get_center().x, r.position.y - 16.0 + roundf(sin(_t * 8.0) * 2.0)), _pcolor())


## Find the same: one big picture in the middle, the buttons hold the candidates.
func _draw_same(v: Dictionary, area: Rect2) -> void:
	var r := Rect2(268.0, area.position.y + 26.0, 104.0, 104.0)
	PixelArt.draw_box(self, r.grow(3), _pcolor(), PixelArt.C["k"])
	PixelArt.draw_box(self, r, Color8(255, 240, 200), PixelArt.C["k"])
	var bob := 0.0
	if state == "correct":
		bob = -absf(sin(_state_t * 11.0)) * 5.0
	_draw_glyph(v["target"], r.get_center() + Vector2(0, bob))
	if _hint_t >= 0.0 and state != "correct":
		_hl(r.grow(5))


## Biggest / smallest / middle. Before a miss: three grey ghosts and an arrow showing which one we
## want (no words needed). After a miss: the real three lined up with guide lines.
func _draw_sizes(v: Dictionary, area: Rect2) -> void:
	var options: Array = v["options"]
	var mode := String(v["mode"])
	var ask := String(v["ask"])
	var k: Color = PixelArt.C["k"]
	var pc := _pcolor()
	if _hint_t < 0.0 and state != "correct":
		var want := 2 if ask == "biggest" else (0 if ask == "smallest" else 1)
		var base := area.position.y + 108.0
		for i in 3:
			var cx := 320.0 + (i - 1) * 120.0
			var s: float = [0.45, 0.72, 1.0][i]
			var top := base
			match mode:
				"disk":
					var rr := 24.0 * s
					PixelArt.draw_disk(self, Vector2(cx, base - rr), rr + 1.0, PixelArt.C["g"])
					PixelArt.draw_disk(self, Vector2(cx, base - rr), rr, PixelArt.C["W"])
					top = base - rr * 2.0
				"bar":
					var ln := roundf(100.0 * s)
					PixelArt.draw_box(self, Rect2(roundf(cx - ln / 2.0), base - 14.0, ln, 14.0), PixelArt.C["W"], PixelArt.C["g"])
					top = base - 14.0
				_:
					var ht := roundf(62.0 * s)
					PixelArt.draw_box(self, Rect2(roundf(cx - 7.0), base - ht, 14.0, ht), PixelArt.C["W"], PixelArt.C["g"])
					top = base - ht
			if i == want:
				_arrow_down(Vector2(cx, top - 20.0 + roundf(sin(_t * 8.0) * 2.0)), pc)
		return
	var choices: Array = q["choices"]
	var vals: Array = []
	for i in 3:
		var g: Dictionary = options[int(choices[i])]
		vals.append(float(g["bar"]) if g.has("bar") else float(g["z"]))
	var guide := Color(pc, 0.85)
	if mode == "bar":
		var x0 := 270.0
		for i in 3:
			var g: Dictionary = options[int(choices[i])]
			var cy := area.position.y + 56.0 + i * 38.0
			_draw_glyph(g, Vector2(x0 + float(vals[i]) / 2.0, cy))
			draw_dashed_line(Vector2(x0 + float(vals[i]), cy - 22.0), Vector2(x0 + float(vals[i]), cy + 22.0), guide, 2.0, 3.0)
		draw_rect(Rect2(x0 - 2.0, area.position.y + 30.0, 2, 120), k)
	else:
		var base := area.position.y + 122.0
		for i in 3:
			var g: Dictionary = options[int(choices[i])]
			var cx := 320.0 + (i - 1) * 130.0
			var h := float(vals[i]) * (2.0 if mode == "disk" else 1.0)
			_draw_glyph(g, Vector2(cx, base - h / 2.0))
			draw_dashed_line(Vector2(110.0, base - h), Vector2(530.0, base - h), guide, 1.0, 3.0)
		draw_rect(Rect2(110, base, 420, 2), k)


## Sizes in even steps with one gap. Hint: a dashed slope along the tops shows where the gap's top is.
func _draw_order(v: Dictionary, area: Rect2, qcol: Color) -> void:
	var items: Array = v["items"]
	var hole := int(v["hole"])
	var n := items.size()
	var tw := 56.0
	var gap := 8.0
	var th := 84.0
	var x0 := 320.0 - (n * tw + (n - 1) * gap) / 2.0
	var y := area.position.y + 34.0
	var tops: Array = []
	for i in n:
		var r := Rect2(roundf(x0 + i * (tw + gap)), y, tw, th)
		var g: Dictionary = items[i]
		var rad := float(g["z"])
		var cy := r.end.y - 8.0 - rad
		if i == hole and state != "correct":
			_draw_hole(r, qcol)
		else:
			PixelArt.draw_box(self, r, Color8(255, 240, 200), PixelArt.C["k"])
			_draw_glyph(g, Vector2(r.get_center().x, cy))
		tops.append(Vector2(r.get_center().x, cy - rad - 3.0))
	if _hint_t >= 0.0 and state != "correct":
		draw_dashed_line(tops[0] as Vector2, tops[n - 1] as Vector2, _pulse(_pcolor()), 2.0, 4.0)
		var hp: Vector2 = tops[hole]
		draw_rect(Rect2(hp.x - 3.0, hp.y - 1.0, 6, 3), _pulse(PixelArt.C["y"]))


## Mirror: the right half repeats the left half flipped. Hint: the matching square flashes and a
## dashed line hops over the mirror to the gap.
func _draw_mirror(v: Dictionary, area: Rect2, qcol: Color) -> void:
	var w := int(v["w"])
	var h := int(v["h"])
	var cells: Array = v["cells"]
	var hole: Array = v["hole"]
	var hr := int(hole[0])
	var hc := int(hole[1])
	var cs := 46.0 if w * h <= 4 else (38.0 if w == 2 else 32.0)
	var gap := 30.0
	var y0 := roundf(area.position.y + (area.size.y - h * cs) / 2.0 - 4.0)
	var xl := roundf(320.0 - gap / 2.0 - w * cs)
	var xr := roundf(320.0 + gap / 2.0)
	draw_dashed_line(Vector2(320, y0 - 12.0), Vector2(320, y0 + h * cs + 12.0), PixelArt.C["A"], 2.0, 4.0)
	for r in h:
		for c in w:
			_cell(Rect2(xl + c * cs, y0 + r * cs, cs, cs), int((cells[r] as Array)[c]))
			var rr := Rect2(xr + c * cs, y0 + r * cs, cs, cs)
			if r == hr and c == hc and state != "correct":
				_draw_hole(rr, qcol, 18 if cs < 36.0 else 30)
			else:
				_cell(rr, int((cells[r] as Array)[w - 1 - c]))
	if _hint_t >= 0.0 and state != "correct":
		var partner := Rect2(xl + (w - 1 - hc) * cs, y0 + hr * cs, cs, cs)
		var target := Rect2(xr + hc * cs, y0 + hr * cs, cs, cs)
		_hl(partner)
		draw_dashed_line(partner.get_center(), target.get_center(), PixelArt.C["k"], 3.0, 4.0)
		draw_dashed_line(partner.get_center(), target.get_center(), _pulse(PixelArt.C["y"]), 1.0, 4.0)


func _cell(r: Rect2, code: int) -> void:
	var col := _col(code)
	draw_rect(r, PixelArt.C["k"])
	draw_rect(r.grow(-1), col)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(maxf(r.size.x - 6.0, 2.0), 2)), col.lightened(0.4))


## Jigsaw: a pixel picture with a square cut out. Hint: the hole pulses.
func _draw_piece(v: Dictionary, area: Rect2, qcol: Color) -> void:
	var rows: Array = v["rows"]
	var hole: Array = v["hole"]
	var ps := int(v["ps"])
	var px := 12.0
	var w := String(rows[0]).length()
	var h := rows.size()
	var o := Vector2(roundf(320.0 - w * px / 2.0), roundf(area.position.y + 22.0))
	PixelArt.draw_box(self, Rect2(o - Vector2(4, 4), Vector2(w * px + 8.0, h * px + 8.0)), PixelArt.C["b"], PixelArt.C["k"])
	for y in h:
		var row := String(rows[y])
		for x in w:
			draw_rect(Rect2(o + Vector2(x * px, y * px), Vector2(px, px)), _pix(row[x]))
	var hr := Rect2(o + Vector2(int(hole[0]) * px, int(hole[1]) * px), Vector2(ps * px, ps * px))
	if state != "correct":
		draw_rect(hr, Color8(36, 28, 52))
		draw_rect(hr.grow(-2), Color8(52, 40, 72))
		var qs := 12 if ps == 2 else 18
		_text_o1(Vector2(hr.get_center().x, hr.get_center().y - qs * 5.0 / 12.0), "?", qcol, qs, true)
		if _hint_t >= 0.0:
			_hl(hr.grow(1))


func _draw_patch(patch: Array, r: Rect2) -> void:
	var n := patch.size()
	var cs := floorf(minf(r.size.x - 24.0, r.size.y - 18.0) / n)
	var side := cs * n
	var o := (r.get_center() - Vector2(side, side) / 2.0).round()
	draw_rect(Rect2(o - Vector2(2, 2), Vector2(side + 4.0, side + 4.0)), PixelArt.C["k"])
	for y in n:
		var row := String(patch[y])
		for x in n:
			draw_rect(Rect2(o + Vector2(x * cs, y * cs), Vector2(cs, cs)), _pix(row[x]))


## Balance scale. It wobbles while you think and tips the right way once it is solved.
## Hint: the totals appear under the pans, left then right.
func _draw_scale(v: Dictionary, area: Rect2) -> void:
	var left: Array = v["left"]
	var right: Array = v["right"]
	var k: Color = PixelArt.C["k"]
	var tilt := sin(_t * 1.8) * 0.12
	if state == "correct":
		var want := 1.0 if int(q["answer"]) == 0 else (-1.0 if int(q["answer"]) == 2 else 0.0)
		tilt = lerpf(tilt, want, clampf(_state_t / 0.4, 0.0, 1.0))
	var cy := area.position.y + 22.0
	var lp := Vector2(190.0, roundf(cy + tilt * 16.0))
	var rp := Vector2(450.0, roundf(cy - tilt * 16.0))
	PixelArt.draw_box(self, Rect2(317, cy, 6, area.end.y - 22.0 - cy), PixelArt.C["T"], k)
	PixelArt.draw_box(self, Rect2(288, area.end.y - 30.0, 64, 10), PixelArt.C["b"], k)
	draw_line(lp, rp, k, 6.0)
	draw_line(lp, rp, PixelArt.C["t"], 3.0)
	PixelArt.draw_disk(self, Vector2(320, cy), 7.0, k)
	PixelArt.draw_disk(self, Vector2(320, cy), 5.0, PixelArt.C["y"])
	for side in 2:
		var e := lp if side == 0 else rp
		var weights: Array = left if side == 0 else right
		var py := roundf(e.y + 58.0)
		draw_line(e, Vector2(e.x - 52.0, py), PixelArt.C["G"], 1.0)
		draw_line(e, Vector2(e.x + 52.0, py), PixelArt.C["G"], 1.0)
		PixelArt.draw_box(self, Rect2(e.x - 56.0, py, 112, 7), PixelArt.C["W"], k)
		_draw_pan_items(weights, Vector2(e.x, py), String(v["mode"]), String(v.get("icon", "seed")))
		if _hint_t >= 0.0 and _hint_shown >= side + 1:
			var total := 0
			for wv in weights:
				total += int(wv)
			var tb := Rect2(e.x - 16.0, py + 11.0, 32, 17)
			PixelArt.draw_box(self, tb, _tint(_pcolor()), _pcolor())
			PixelArt.draw_text_centered(self, Vector2(e.x, tb.position.y + 3.0), str(total), k, false, 12)


func _draw_pan_items(weights: Array, base: Vector2, mode: String, icon: String) -> void:
	var n := weights.size()
	if mode == "count":
		var tex := _icon_tex(icon)
		var sz := tex.get_size() * (3.0 if n <= 3 else 2.0)
		var per := 3
		for i in n:
			var row := int(i / per)
			var in_row := mini(per, n - row * per)
			var x := base.x + (i % per - (in_row - 1) / 2.0) * (sz.x + 6.0)
			var y := base.y - (row + 1) * (sz.y + 3.0) + 2.0
			draw_texture_rect(tex, Rect2((Vector2(x, y) - Vector2(sz.x / 2.0, 0.0)).round(), sz), false)
		return
	var keys := ["r", "A", "y", "Z", "v", "o", "u", "p", "e", "t"]
	var bw := 30.0
	var total_w := n * bw + (n - 1) * 3.0
	for i in n:
		var wv := int(weights[i])
		var ht := 10.0 + wv * 3.0
		var r := Rect2(roundf(base.x - total_w / 2.0 + i * (bw + 3.0)), base.y - ht, bw, ht)
		var key: String = keys[clampi(wv - 1, 0, keys.size() - 1)]
		PixelArt.draw_box(self, r, PixelArt.C[key], PixelArt.C["k"])
		PixelArt.draw_text_centered(self, Vector2(r.get_center().x, r.position.y + 3.0), str(wv), PixelArt.C["w"], true, 12)


## The answer button of a balance question: a little scale tipped one way (or level).
func _draw_mini_scale(choice: int, c: Vector2) -> void:
	var k: Color = PixelArt.C["k"]
	var t := 1.0 if choice == 0 else (-1.0 if choice == 2 else 0.0)
	var lp := Vector2(c.x - 34.0, c.y - 8.0 + t * 9.0)
	var rp := Vector2(c.x + 34.0, c.y - 8.0 - t * 9.0)
	draw_rect(Rect2(c.x - 2.0, c.y - 8.0, 4, 30), PixelArt.C["T"])
	draw_rect(Rect2(c.x - 14.0, c.y + 20.0, 28, 4), PixelArt.C["b"])
	draw_line(lp, rp, k, 4.0)
	draw_line(lp, rp, PixelArt.C["t"], 2.0)
	for side in 2:
		var e := lp if side == 0 else rp
		var lower := (side == 0 and choice == 0) or (side == 1 and choice == 2)
		var level := choice == 1
		var py := roundf(e.y + 16.0)
		draw_line(e, Vector2(e.x - 12.0, py), PixelArt.C["G"], 1.0)
		draw_line(e, Vector2(e.x + 12.0, py), PixelArt.C["G"], 1.0)
		draw_rect(Rect2(e.x - 14.0, py, 28, 4), k)
		draw_rect(Rect2(e.x - 13.0, py, 26, 3), PixelArt.C["W"])
		var bs := Vector2(14, 10) if lower else (Vector2(10, 7) if level else Vector2(8, 5))
		PixelArt.draw_box(self, Rect2(roundf(e.x - bs.x / 2.0), py - bs.y, bs.x, bs.y), PixelArt.C["r"], k)


## Patterns made of pictures, with the gap anywhere. Hint: brackets round each repeat (or "+n" hops
## for growing dots).
func _draw_chain(v: Dictionary, area: Rect2, qcol: Color) -> void:
	var items: Array = v["items"]
	var hole := int(v["hole"])
	var unit := int(v["unit"])
	var step := int(v["step"])
	var n := items.size()
	var bw := 48.0
	var gap := 6.0
	var x0 := 320.0 - (n * bw + (n - 1) * gap) / 2.0
	var y := area.position.y + 46.0
	for i in n:
		var r := Rect2(roundf(x0 + i * (bw + gap)), y, bw, bw)
		if i == hole and state != "correct":
			_draw_hole(r, qcol)
		else:
			if i == hole:
				PixelArt.draw_box(self, r, _tint(PixelArt.C["Z"]), PixelArt.C["Z"])
			else:
				PixelArt.draw_box(self, r, Color8(255, 240, 200), PixelArt.C["k"])
			_draw_glyph(items[i], r.get_center())
	if _hint_t < 0.0 or state == "correct":
		return
	var by := y + bw + 7.0
	if unit > 0:
		var groups := int(ceil(n / float(unit)))
		for g in groups:
			if g >= _hint_shown:
				break
			var a := x0 + g * unit * (bw + gap)
			var b := minf(a + unit * (bw + gap) - gap, x0 + n * (bw + gap) - gap)
			var col: Color = PixelArt.C["n"] if g % 2 == 0 else PixelArt.C["P"]
			draw_rect(Rect2(roundf(a), by, roundf(b - a), 2), col)
			draw_rect(Rect2(roundf(a), by - 3, 2, 3), col)
			draw_rect(Rect2(roundf(b) - 2, by - 3, 2, 3), col)
	else:
		for i in n - 1:
			if _hint_shown > i:
				var ax := x0 + (i + 1) * (bw + gap) - gap / 2.0
				var lbl := ("+%d" % step) if step > 0 else ("%d" % step)
				PixelArt.draw_text_centered(self, Vector2(ax, y - 14.0), lbl, PixelArt.C["n"], false, 12)


func _draw_button(i: int, dy: float) -> void:
	var r := _btn_rect(i)
	r.position.y += dy
	var pc := _pcolor()
	var k: Color = PixelArt.C["k"]
	var choice: int = int((q["choices"] as Array)[i])
	var is_sel := i == sel
	var is_correct := choice == int(q["answer"])
	var show_answer := is_correct and (wrong_count >= 2 or state == "correct")
	var lift := 0.0
	if is_sel and state != "correct":
		lift = -4.0 + roundf(sin(_t * 6.0))
	if is_sel and _press_t > 0.0:
		lift = 2.0
	if state == "correct" and is_correct:
		# happy bounce on the right answer
		lift = -roundf(absf(sin(_state_t * 11.0)) * 6.0 * maxf(0.0, 1.0 - _state_t))
	var wob := 0.0
	if i == _wrong_choice and _wobble > 0.0:
		wob = roundf(sin(_t * 55.0) * 4.0 * _wobble)
	r.position += Vector2(wob, lift)
	# shadow
	draw_rect(Rect2(r.position + Vector2(3, 4 - lift), r.size), Color(0, 0, 0, 0.25))
	var fill := Color8(255, 240, 200)
	var border: Color = k
	if is_sel:
		fill = Color8(255, 226, 120)
		border = pc
	if i == _wrong_choice and _wobble > 0.0:
		fill = Color8(255, 180, 170)
	if show_answer:
		var pulse := 0.5 + 0.5 * sin(_t * 8.0)
		fill = Color8(200, 255, 170).lerp(Color8(150, 240, 120), pulse)
		border = PixelArt.C["Z"]
	if state == "correct" and not is_correct:
		fill = fill.darkened(0.25)
	PixelArt.draw_box(self, r.grow(2), border, k)
	PixelArt.draw_box(self, r, fill, k)
	var c := r.get_center()
	var v: Dictionary = q["visual"]
	match String(v.get("button", "number")):
		"pile":
			var slots: Array = []
			for j in choice:
				slots.append({"t": "item", "label": 0})
			_draw_slots(Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 12)), slots, String(v.get("icon", "seed")), 2)
			if _hint_t >= 0.0 and _hint_shown > i:
				_text_o1(Vector2(r.end.x - 12, r.end.y - 14), str(choice), PixelArt.C["n"], 12, false, PixelArt.C["w"])
		"shape":
			_draw_shape(choice, c, 22.0, PixelArt.C["o"])
		"color":
			_draw_code("color", choice, c, 22.0)
		"glyph":
			var opts: Array = v["options"]
			_draw_glyph(opts[choice], c, bool(v.get("shadow", false)), 1.45)
		"patch":
			_draw_patch((v["options"] as Array)[choice], r)
		"scale":
			_draw_mini_scale(choice, c)
		_:
			PixelArt.draw_text_centered(self, Vector2(c.x, c.y - 12), str(choice), k, false, 30)
			# hint for "which is biggest": tiny seed tally under each number
			if String(v.get("kind", "")) == "numbers" and _hint_t >= 0.0 and choice <= 20:
				var seed := PixelArt.tex("seed")
				var tx := c.x - 39.0
				for j in choice:
					var col_i := j % 10
					var sx := tx + col_i * 8 + (4 if col_i >= 5 else 0)
					draw_texture_rect(seed, Rect2(sx, r.end.y - 25 + int(j / 10) * 12, 6, 10), false)
	# a wrong pick is washed out so the choices shrink (never a penalty, just a clue)
	if _tried[i] and state != "correct":
		draw_rect(r, Color(1.0, 0.96, 0.86, 0.62))
	# pointer arrow over the selected button
	if is_sel and state != "correct":
		var ay := r.position.y - 14 + roundf(sin(_t * 8.0) * 2.0)
		var pts := PackedVector2Array([Vector2(c.x - 7, ay), Vector2(c.x + 7, ay), Vector2(c.x, ay + 8)])
		_poly_outlined(pts, pc, k)
	if show_answer and state != "correct":
		PixelArt.draw_text_centered(self, Vector2(c.x, r.end.y + 5), "THIS ONE!", PixelArt.C["x"], false)


func _draw_helper(dy: float) -> void:
	var k: Color = PixelArt.C["k"]
	var lvl := 1
	if state == "correct":
		lvl = 6
	elif wrong_count > 0:
		lvl = 3
	var hz := PixelArt.tex("ham_head_%d" % lvl)
	var bob := roundf(sin(_t * 4.0) * 1.5)
	if state == "correct":
		bob = -absf(sin(_state_t * 14.0)) * 6.0
	var hp := Vector2(77, 310 + dy + bob)
	draw_set_transform(hp, 0.0, Vector2(3, 3))
	draw_texture(hz, -hz.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# speech bubble above the hamster
	var lines := _wrap(_bubble, 16)
	if lines.is_empty():
		return
	var w := 0
	for l in lines:
		w = maxi(w, PixelArt.text_width(l))
	var bh := lines.size() * 7 + 5
	var br := Rect2(44, 278 + dy - bh - 6, maxf(float(w) + 8.0, 40.0), bh)
	br.position.x = minf(br.position.x, 116.0 - br.size.x)
	br.position.x = maxf(br.position.x, 40.0)
	PixelArt.draw_box(self, br, Color8(255, 255, 255), k)
	draw_rect(Rect2(70, br.end.y - 1, 6, 1), Color8(255, 255, 255))
	draw_rect(Rect2(71, br.end.y, 4, 2), k)
	draw_rect(Rect2(72, br.end.y, 2, 1), Color8(255, 255, 255))
	var yy := br.position.y + 3
	for l in lines:
		PixelArt.draw_text(self, Vector2(br.position.x + 4, yy), l, k)
		yy += 7
