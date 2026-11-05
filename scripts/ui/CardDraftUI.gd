extends Control
## End-of-wave Card Draft — "time freezes and a vending machine drops from the sky".
##
## CONTRACT (used by MainArena):
##   open(players: Array)  shows the draft (tree is paused; this node processes ALWAYS)
##   signal finished       emitted once every player has picked; CardDB.apply_card() has been
##                         called exactly once per pick before it fires.
##
## Each player gets their own hand of 3 cards (2P: P1 left, P2 right) and browses with
## left/right, confirms with confirm/fire/interact. The keyboard+mouse pilot can also hover
## and click cards. Sequence: DROP -> DISPENSE -> PICK -> FLOURISH -> LEAVE.
##
## LEARNING MODE: if GameManager.learning_level(player) > 0 and GameManager.arena.math_quiz
## exists, confirming a card does NOT apply it yet. The card shows "SOLVE TO ACTIVATE!" and
## math_quiz.ask(player, level, "card") runs; on math_quiz.solved(player, first_try) the card
## is applied. Requests are queued so only one quiz runs at a time; the other hand keeps working.

signal finished

const UIArtScript := preload("res://scripts/art/UIArt.gd")

enum S { IDLE, DROP, DISPENSE, PICK, FLOURISH, LEAVE }

const MACHINE_W := 88.0
const MACHINE_REST_Y := 4.0
const FLIGHT_TIME := 0.38
const TIER_SHORT := {"mod": "MECH MOD", "tower": "BLUEPRINT", "synergy": "SYNERGY", "cursed": "CURSED"}
const K := Color8(26, 16, 32)

var players: Array = []
var hands: Array = []            # per player: Array[Dictionary]
var cursor: Array = []           # per player: int
var picked: Array = []           # per player: bool
var pick_time: Array = []        # per player: seconds since picked (-1 = not yet)
var awaiting: Array = []         # per player: card chosen, waiting for the maths quiz

var _state := S.IDLE
var _t := 0.0                    # time in current state
var _age := 0.0                  # time since open
var _machine_y := -140.0
var _machine_vy := 0.0
var _impacts := 0
var _squash := 0.0
var _jiggle := 0.0
var _cards: Array = []           # visual card records (see _make_card_fx)
var _parts: Array = []           # UI-space particles
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _mouse_prev := Vector2(-999, -999)
var _lmb_prev := false
var _hover := -1                 # card index the mouse is over (kbm player's hand)
var _finished_emitted := true
var _freeze_flash := 0.0
var _shake_v := Vector2.ZERO
var _quiz_queue: Array = []      # player indices waiting for their quiz turn
var _quiz_for := -1              # player index the quiz is currently asking
var _ask_t := 0.0
var _star_pop: Array = []        # per player: "+1 STAR" flash timer
var _all_picked_t := 0.0
var _last_cur: Array = []        # per player: cursor last frame (for the hover wiggle)
const FLIP_TIME := 0.24


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


# ------------------------------------------------------------------ open

func open(pls: Array) -> void:
	players = []
	for p in pls:
		if is_instance_valid(p):
			players.append(p)
	hands.clear()
	cursor.clear()
	picked.clear()
	pick_time.clear()
	awaiting.clear()
	_star_pop.clear()
	_quiz_queue.clear()
	_quiz_for = -1
	_all_picked_t = 0.0
	_cards.clear()
	_parts.clear()
	_last_cur.clear()
	var offered: Array = []
	for p in players:
		var hand: Array = CardDB.roll_hand(p, 3, offered)
		for c in hand:
			offered.append(c["id"])
		hands.append(hand)
		cursor.append(clampi(1, 0, maxi(0, hand.size() - 1)))
		picked.append(hand.is_empty())
		pick_time.append(0.0 if hand.is_empty() else -1.0)
		awaiting.append(false)
		_star_pop.append(0.0)
		_last_cur.append(cursor[cursor.size() - 1])
		# swallow whatever is currently held so nothing auto-picks
		p.input.update(p)
		p.input.consume()
	# dispense order: interleave players, left card first
	var order := 0
	for k in 3:
		for i in players.size():
			if k < hands[i].size():
				_cards.append(_make_card_fx(i, k, order))
				order += 1
	_state = S.DROP
	_t = 0.0
	_age = 0.0
	_machine_y = -150.0
	_machine_vy = 60.0
	_impacts = 0
	_squash = 0.0
	_jiggle = 0.0
	_hover = -1
	_finished_emitted = false
	_freeze_flash = 1.0
	_prev_mouse_mode = Input.mouse_mode
	if _has_kbm():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_lmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_mouse_prev = get_global_mouse_position()
	visible = true
	var q = _quiz()
	if q != null and q.has_signal("solved") and not q.solved.is_connected(_on_quiz_solved):
		q.solved.connect(_on_quiz_solved)
	Sfx.play("throw", 0.5, -2.0)
	if players.is_empty():
		_state = S.LEAVE


func _has_kbm() -> bool:
	for p in players:
		if p.input.device == "kbm":
			return true
	return false


func _make_card_fx(pi: int, k: int, order: int) -> Dictionary:
	return {
		"p": pi, "k": k,
		"spawn_at": 0.12 + order * 0.11,
		"flight": -1.0,          # <0 = still inside the machine, 0..1 flying, >=1 landed
		"pos": Vector2.ZERO,
		"rot": 0.0,
		"scale": 0.2,
		"exit": 0.0,             # flourish progress
		"flip": 0.0,             # 0 = back facing us .. 1 = revealed (starts when it lands)
		"wig": 0.0,              # hover wiggle energy
	}


# ------------------------------------------------------------------ layout

func _card_size() -> Vector2:
	return Vector2(86, 122) if players.size() <= 1 else Vector2(64, 108)


func _hand_center_x(pi: int) -> float:
	if players.size() <= 1:
		return 320.0
	return 158.0 if pi == 0 else 482.0


## Top-left of card k of player pi at rest.
func _card_rest(pi: int, k: int) -> Vector2:
	var sz := _card_size()
	var gap := 10.0 if players.size() <= 1 else 6.0
	var n: int = hands[pi].size()
	var total := n * sz.x + (n - 1) * gap
	var x := _hand_center_x(pi) - total / 2.0 + k * (sz.x + gap)
	var y := 146.0 if players.size() <= 1 else 150.0
	return Vector2(roundf(x), y)


func _machine_pos() -> Vector2:
	return Vector2(roundf(320.0 - MACHINE_W / 2.0), roundf(_machine_y))


func _slot_pos() -> Vector2:
	return _machine_pos() + UIArtScript.VEND_SLOT


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_age += delta
	_squash = maxf(0.0, _squash - delta * 5.0)
	_jiggle = maxf(0.0, _jiggle - delta * 6.0)
	_freeze_flash = maxf(0.0, _freeze_flash - delta * 3.0)
	_update_particles(delta)
	_update_card_anims(delta)
	match _state:
		S.DROP:
			_update_drop(delta)
		S.DISPENSE:
			_update_dispense(delta)
		S.PICK:
			_update_cards_idle(delta)
			_update_pick()
		S.FLOURISH:
			_update_flourish(delta)
		S.LEAVE:
			_update_leave(delta)
	queue_redraw()


## Flip-in reveal after landing, and a little wiggle when a cursor moves onto a card.
func _update_card_anims(delta: float) -> void:
	for c in _cards:
		if float(c["flight"]) >= 1.0 and float(c["flip"]) < 1.0:
			var before: float = c["flip"]
			c["flip"] = minf(1.0, before + delta / FLIP_TIME)
			if before < 0.5 and float(c["flip"]) >= 0.5:
				Sfx.play("tick", 1.4 + c["k"] * 0.1, -10.0)
		c["wig"] = maxf(0.0, float(c["wig"]) - delta * 3.5)
	for i in mini(cursor.size(), _last_cur.size()):
		if cursor[i] != _last_cur[i]:
			_last_cur[i] = cursor[i]
			for c in _cards:
				if c["p"] == i and c["k"] == cursor[i]:
					c["wig"] = 1.0


func _update_drop(delta: float) -> void:
	_machine_vy += 1500.0 * delta
	_machine_y += _machine_vy * delta
	if randf() < 0.6:
		_spark(_machine_pos() + Vector2(randf_range(0, MACHINE_W), -4), Vector2(0, -60), Color(1, 1, 1, 0.5), 0.2, 0.0)
	if _machine_y >= MACHINE_REST_Y and _machine_vy > 0.0:
		_machine_y = MACHINE_REST_Y
		_impacts += 1
		_squash = 1.0 if _impacts == 1 else 0.4
		if _impacts == 1:
			Sfx.play("vend_drop")
			JuiceManager.add_trauma(0.55)
			for i in 26:
				var p := _machine_pos() + Vector2(randf_range(0, MACHINE_W), 116)
				_spark(p, Vector2(randf_range(-90, 90), randf_range(-70, -10)), [PixelArt.C["T"], PixelArt.C["t"], PixelArt.C["h"], Color.WHITE][randi() % 4], randf_range(0.3, 0.7), 220.0)
		else:
			Sfx.play("vend_drop", 1.6, -10.0)
		_machine_vy = -_machine_vy * 0.22
		if _impacts >= 2 or absf(_machine_vy) < 50.0:
			_machine_y = MACHINE_REST_Y
			_machine_vy = 0.0
			_state = S.DISPENSE
			_t = 0.0


func _update_dispense(delta: float) -> void:
	var all_landed := true
	for c in _cards:
		var rest := _card_rest(c["p"], c["k"])
		var flight: float = c["flight"]
		if flight < 0.0:
			all_landed = false
			if _t >= c["spawn_at"]:
				c["flight"] = 0.0
				_jiggle = 1.0
				Sfx.play("pickup", 0.8 + c["k"] * 0.15, -4.0)
				var sp := _slot_pos()
				for i in 8:
					_spark(sp, Vector2(randf_range(-60, 60), randf_range(-80, -10)), [PixelArt.C["y"], PixelArt.C["w"], CardDB.tier_color(_card(c)["tier"])][randi() % 3], 0.35, 200.0)
			continue
		if flight < 1.0:
			all_landed = false
			flight = minf(1.0, flight + delta / FLIGHT_TIME)
			c["flight"] = flight
			if flight >= 1.0:
				Sfx.play("select", 0.9 + randf() * 0.2, -6.0)
		var e := 1.0 - pow(1.0 - flight, 3.0)
		var start := _slot_pos() - _card_size() * 0.1
		var p: Vector2 = start.lerp(rest, e)
		p.y -= sin(e * PI) * 40.0
		c["pos"] = p
		c["scale"] = lerpf(0.2, 1.0, e)
		c["rot"] = (1.0 - e) * (0.8 if c["k"] % 2 == 0 else -0.8)
	if all_landed and _t > 0.2:
		_state = S.PICK
		_t = 0.0


func _update_cards_idle(_delta: float) -> void:
	for c in _cards:
		c["pos"] = _card_rest(c["p"], c["k"])
		c["scale"] = 1.0
		c["rot"] = 0.0


func _update_pick() -> void:
	# mouse (kbm pilot only)
	var mpos := get_global_mouse_position()
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var lmb_edge := lmb and not _lmb_prev
	_lmb_prev = lmb
	var mouse_moved := mpos.distance_to(_mouse_prev) > 0.5
	_mouse_prev = mpos
	_hover = -1
	_update_quiz_queue()
	for i in players.size():
		_star_pop[i] = maxf(0.0, _star_pop[i] - get_process_delta_time())
		if picked[i] or awaiting[i]:
			continue
		var inp: PlayerInput = players[i].input
		inp.update(players[i])
		var n: int = hands[i].size()
		if n == 0:
			continue
		var over := -1
		if inp.device == "kbm":
			for k in n:
				var r := Rect2(_card_rest(i, k) + Vector2(0, -8), _card_size() + Vector2(0, 8))
				if r.has_point(mpos):
					over = k
			if over >= 0:
				_hover = over
				if mouse_moved and cursor[i] != over:
					cursor[i] = over
					Sfx.play("select", 1.2, -8.0)
		if inp.just("left"):
			cursor[i] = (cursor[i] + n - 1) % n
			Sfx.play("select")
		if inp.just("right"):
			cursor[i] = (cursor[i] + 1) % n
			Sfx.play("select")
		var want := inp.just("confirm") or inp.just("fire") or inp.just("interact")
		if want and inp.device == "kbm" and lmb and over < 0:
			want = false   # clicked empty space: ignore
		if lmb_edge and inp.device == "kbm" and over >= 0:
			cursor[i] = over
			want = true
		if want:
			_request_pick(i)
	var all := true
	for b in picked:
		if not b:
			all = false
	if all:
		_all_picked_t += get_process_delta_time()
	if all and _all_picked_t > 0.45:
		_state = S.FLOURISH
		_t = 0.0
		Sfx.play("upgrade", 1.2)
		for c in _cards:
			if _is_chosen(c):
				var center: Vector2 = c["pos"] + _card_size() / 2.0
				for i in 18:
					_spark(center, Vector2.from_angle(randf() * TAU) * randf_range(40, 140),
						[PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["Z"]][randi() % 5], randf_range(0.4, 0.9), 160.0)


func _quiz():
	if GameManager.arena and GameManager.arena.get("math_quiz") != null:
		return GameManager.arena.math_quiz
	return null


## Confirm pressed: apply now, or (Learning Mode) queue the maths quiz first.
func _request_pick(i: int) -> void:
	var lvl := GameManager.learning_level(players[i])
	if lvl > 0 and _quiz() != null:
		awaiting[i] = true
		_quiz_queue.append(i)
		Sfx.play("select", 0.8)
		var r := Rect2(_card_rest(i, cursor[i]), _card_size())
		for k in 10:
			_spark(r.get_center(), Vector2.from_angle(randf() * TAU) * randf_range(30, 90), PixelArt.C["y"], 0.4, 60.0)
	else:
		_pick(i)


func _update_quiz_queue() -> void:
	var q = _quiz()
	if q == null:
		# quiz vanished: don't strand anyone
		for i in awaiting.size():
			if awaiting[i]:
				awaiting[i] = false
				_pick(i)
		_quiz_queue.clear()
		_quiz_for = -1
		return
	_ask_t += get_process_delta_time()
	if _quiz_for >= 0:
		# safety net: quiz closed without telling us -> activate anyway
		if not q.active and _ask_t > 0.6:
			var i := _quiz_for
			_quiz_for = -1
			if awaiting[i]:
				awaiting[i] = false
				_pick(i)
		return
	if not _quiz_queue.is_empty() and not q.active:
		_quiz_for = _quiz_queue.pop_front()
		_ask_t = 0.0
		q.ask(players[_quiz_for], GameManager.learning_level(players[_quiz_for]), "card")


func _on_quiz_solved(player, first_try: bool) -> void:
	if not visible:
		return
	var i := players.find(player)
	if i < 0 or not awaiting[i]:
		return
	if i == _quiz_for:
		_quiz_for = -1
	_quiz_queue.erase(i)
	awaiting[i] = false
	if first_try:
		_star_pop[i] = 1.4
	_pick(i)


func _pick(i: int) -> void:
	if picked[i]:
		return
	picked[i] = true
	pick_time[i] = 0.0
	var card: Dictionary = hands[i][cursor[i]]
	CardDB.apply_card(card, players[i])
	Sfx.play("card")
	Sfx.play("bank", 1.3, -6.0)
	var r := Rect2(_card_rest(i, cursor[i]), _card_size())
	for k in 14:
		_spark(r.get_center(), Vector2.from_angle(randf() * TAU) * randf_range(40, 120), CardDB.tier_color(card["tier"]), 0.5, 80.0)
	if card["tier"] == "cursed":
		JuiceManager.add_trauma(0.3)
		Sfx.play("ogre_roar", 1.8, -12.0)


func _is_chosen(c: Dictionary) -> bool:
	return picked[c["p"]] and cursor[c["p"]] == c["k"]


func _update_flourish(delta: float) -> void:
	for i in pick_time.size():
		if pick_time[i] >= 0.0:
			pick_time[i] += delta
	var dur := 0.75
	var e := clampf(_t / dur, 0.0, 1.0)
	for c in _cards:
		var rest := _card_rest(c["p"], c["k"])
		if _is_chosen(c):
			# hold, then fly to the player's HUD corner and shrink
			var hold := clampf((e - 0.3) / 0.7, 0.0, 1.0)
			var ee := hold * hold
			var corner := Vector2(40, 330) if c["p"] == 0 else Vector2(600, 330)
			if players.size() == 1:
				corner = Vector2(40, 330)
			c["pos"] = rest.lerp(corner - _card_size() * 0.1, ee)
			c["scale"] = lerpf(1.0, 0.15, ee)
			c["rot"] = ee * 0.6
		else:
			# slide back into the machine
			var ee := clampf(e * 1.6, 0.0, 1.0)
			c["pos"] = rest.lerp(_slot_pos() - _card_size() * 0.1, ee * ee)
			c["scale"] = lerpf(1.0, 0.2, ee)
			c["rot"] = ee * -0.5
	if _t >= dur:
		_state = S.LEAVE
		_t = 0.0
		_machine_vy = -40.0
		Sfx.play("throw", 0.8, -4.0)


func _update_leave(delta: float) -> void:
	_machine_vy -= 900.0 * delta
	_machine_y += _machine_vy * delta
	if _machine_y < -170.0 or players.is_empty():
		_finish()


func _finish() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	visible = false
	_state = S.IDLE
	Input.mouse_mode = _prev_mouse_mode
	for p in players:
		if is_instance_valid(p):
			p.input.update(p)
			p.input.consume()
	finished.emit()


# ------------------------------------------------------------------ particles

func _spark(pos: Vector2, vel: Vector2, col: Color, life: float, grav: float) -> void:
	if _parts.size() > 400:
		return
	_parts.append({"pos": pos, "vel": vel, "life": life, "max": life, "col": col, "grav": grav})


func _update_particles(delta: float) -> void:
	var k := _parts.size() - 1
	while k >= 0:
		var p: Dictionary = _parts[k]
		p["life"] -= delta
		if p["life"] <= 0.0:
			_parts.remove_at(k)
		else:
			var v: Vector2 = p["vel"]
			v.y += p["grav"] * delta
			v *= maxf(0.0, 1.0 - 1.5 * delta)
			p["vel"] = v
			p["pos"] += v * delta
		k -= 1


# ------------------------------------------------------------------ draw

func _card(c: Dictionary) -> Dictionary:
	return hands[c["p"]][c["k"]]


func _draw() -> void:
	_shake_v = _shake_off()
	# frozen-time backdrop
	var fade := clampf(_age / 0.25, 0.0, 1.0)
	if _state == S.LEAVE:
		fade = clampf(1.0 - _t / 0.45, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.05, 0.04, 0.12, 0.72 * fade))
	for y in range(0, 360, 4):
		draw_rect(Rect2(0, y, 640, 1), Color(0.6, 0.8, 1.0, 0.035 * fade))
	if _freeze_flash > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.8, 0.9, 1.0, 0.35 * _freeze_flash))
	_draw_machine()
	if _state == S.PICK:
		var title := "PICK ONE CARD" if players.size() <= 1 else "PICK ONE CARD EACH"
		PixelArt.draw_text_centered(self, Vector2(320, 300), title, PixelArt.C["y"] if int(_age * 2.0) % 2 == 0 else PixelArt.C["w"], true, 6)
	elif _state == S.DROP or _state == S.DISPENSE:
		var a := clampf(_age / 0.3, 0.0, 1.0)
		UiText.outlined_centered(self, Vector2(320, 126), "TIME FREEZES...", Color(0.75, 0.9, 1.0, a), 12)
	if _state == S.LEAVE:
		return
	# cards: non-cursor first, then cursor cards, then chosen
	var order: Array = []
	for c in _cards:
		if c["flight"] >= 0.0:
			order.append(c)
	order.sort_custom(func(a, b): return _draw_rank(a) < _draw_rank(b))
	for c in order:
		_draw_card_fx(c)
	_draw_hand_labels()
	for p in _parts:
		var col: Color = p["col"]
		col.a *= clampf(p["life"] / p["max"] * 2.0, 0.0, 1.0)
		draw_rect(Rect2((p["pos"] as Vector2).round(), Vector2(1, 1) if p["max"] < 0.5 else Vector2(2, 2)), col)


func _draw_rank(c: Dictionary) -> int:
	if _is_chosen(c):
		return 3
	if _state == S.PICK and cursor[c["p"]] == c["k"]:
		return 2
	return 1


func _draw_machine() -> void:
	if _machine_y < -140.0:
		return
	var mp := _machine_pos()
	var sq := 1.0 + _squash * 0.08
	var jig := Vector2(sin(_age * 70.0) * _jiggle, 0).round()
	var tex := PixelArt.tex("vending_machine")
	# squash anchored at the feet
	var h := tex.get_height()
	draw_set_transform(mp + jig + Vector2(MACHINE_W / 2.0, h) + _shake_v, 0.0, Vector2(sq, 1.0 / sq))
	draw_texture(tex, Vector2(-MACHINE_W / 2.0, -h))
	# flickering sign
	var sign_r: Rect2 = UIArtScript.VEND_SIGN
	var sign_pos := Vector2(-MACHINE_W / 2.0, -h) + sign_r.position + Vector2(1, 1)
	var text := "SNAX OF DESTINY"
	var flick := randf() < 0.06
	var col := PixelArt.C["y"] if not flick else PixelArt.C["Y"].darkened(0.5)
	if flick:
		# a dead letter or two
		text = text.substr(0, 5) + " " + text.substr(6)
	var tw := PixelArt.text_width(text)
	PixelArt.draw_text(self, sign_pos + Vector2(roundf((sign_r.size.x - tw) / 2.0), 3), text, col)
	if not flick:
		draw_rect(Rect2(sign_pos + Vector2(2, 1), Vector2(sign_r.size.x - 4, 1)), Color(1, 0.9, 0.4, 0.15))
	# glow from the slot while dispensing
	if _state == S.DISPENSE:
		var sp := Vector2(-MACHINE_W / 2.0, -h) + UIArtScript.VEND_SLOT
		draw_rect(Rect2(sp + Vector2(-26, -3), Vector2(52, 6)), Color(1, 0.9, 0.5, 0.25 + 0.15 * sin(_age * 20.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shake_off() -> Vector2:
	var tr: float = JuiceManager.trauma
	if tr <= 0.0:
		return Vector2.ZERO
	return (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * tr * tr * 6.0).round()


func _draw_card_fx(c: Dictionary) -> void:
	var pi: int = c["p"]
	var k: int = c["k"]
	var card := _card(c)
	var sz := _card_size()
	var s: float = c["scale"]
	var pos: Vector2 = c["pos"]
	var lift := 0.0
	var is_cursor: bool = _state == S.PICK and cursor[pi] == k and not picked[pi]
	var is_waiting: bool = _state == S.PICK and cursor[pi] == k and awaiting[pi]
	if is_cursor:
		lift = -8.0 + sin(_age * 5.0) * 1.0
	var chosen := _is_chosen(c)
	var dim: bool = picked[pi] and not chosen and _state == S.PICK
	var wob := Vector2.ZERO
	if card["tier"] == "cursed" and _state == S.PICK and not picked[pi]:
		wob = Vector2(roundf(sin(_age * 9.0 + k) * 1.0), 0)
	var center := pos + sz * s / 2.0 + Vector2(0, lift) + wob
	# flip-in: back face while flying / first half of the flip, then the front
	var flip: float = c["flip"]
	var landed := float(c["flight"]) >= 1.0
	var sx := 1.0
	var show_back := not landed or flip < 0.5
	if landed and flip < 1.0:
		sx = maxf(0.08, absf(cos(flip * PI)))
	var rot: float = c["rot"] + sin(_age * 38.0) * 0.07 * float(c["wig"])
	var squash := 1.0 + 0.06 * float(c["wig"]) * sin(_age * 30.0)
	draw_set_transform(center.round() + _shake_v, rot, Vector2(s * sx * squash, s / squash))
	var r := Rect2(-sz / 2.0, sz).abs()
	r.position = r.position.round()
	if show_back:
		_draw_card_back(r, CardDB.tier_color(card["tier"]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_draw_card_body(card, r, players[pi], is_cursor, chosen, dim)
	if is_cursor:
		var pc: Color = MechPlayer.PLAYER_COLORS[clampi(pi, 0, 1)]
		var g := r.grow(2)
		draw_rect(Rect2(g.position, Vector2(g.size.x, 2)), pc)
		draw_rect(Rect2(g.position + Vector2(0, g.size.y - 2), Vector2(g.size.x, 2)), pc)
		draw_rect(Rect2(g.position, Vector2(2, g.size.y)), pc)
		draw_rect(Rect2(g.position + Vector2(g.size.x - 2, 0), Vector2(2, g.size.y)), pc)
		# bouncing pointer + player tag
		var by := r.position.y - 12.0 + roundf(sin(_age * 8.0) * 1.5)
		PixelArt.draw_text_centered(self, Vector2(0, by), "P%d" % players[pi].player_id, pc, true)
		draw_rect(Rect2(-2, by + 7, 5, 1), pc)
		draw_rect(Rect2(-1, by + 8, 3, 1), pc)
		draw_rect(Rect2(0, by + 9, 1, 1), pc)
	if is_waiting:
		var stamp_w := Rect2(r.position.x + 3, r.position.y + 13, r.size.x - 6, 20)
		var flash_on := int(_age * 4.0) % 2 == 0
		PixelArt.draw_box(self, stamp_w, PixelArt.C["y"] if flash_on else PixelArt.C["Y"], K)
		PixelArt.draw_text_centered(self, Vector2(0, stamp_w.position.y + 3), "SOLVE TO", K, false)
		PixelArt.draw_text_centered(self, Vector2(0, stamp_w.position.y + 11), "ACTIVATE!", K, false)
		draw_texture(PixelArt.tex("star"), Vector2(r.position.x + 1, stamp_w.position.y - 4))
		draw_texture(PixelArt.tex("star"), Vector2(r.end.x - 10, stamp_w.position.y - 4))
	if chosen and _state == S.PICK:
		var pc2: Color = MechPlayer.PLAYER_COLORS[clampi(pi, 0, 1)]
		var stamp := Rect2(r.position.x + 6, r.position.y + 15, r.size.x - 12, 14)
		PixelArt.draw_box(self, stamp, pc2.darkened(0.2), K)
		PixelArt.draw_text_centered(self, Vector2(0, stamp.position.y + 4), "TAKEN!", Color8(255, 248, 231), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card_body(card: Dictionary, r: Rect2, player, is_cursor: bool, chosen: bool, dim: bool) -> void:
	var tier: String = card["tier"]
	var tc := CardDB.tier_color(tier)
	var cursed := tier == "cursed"
	var fill := Color8(255, 248, 231)
	if cursed:
		fill = Color8(228, 244, 206)
	if dim:
		fill = fill.darkened(0.45)
		tc = tc.darkened(0.45)
	# warp glow behind cursed cards
	if cursed and not dim:
		var gl := 0.25 + 0.2 * sin(_age * 6.0)
		draw_rect(r.grow(4), Color(0.6, 1.0, 0.35, gl * 0.4))
		draw_rect(r.grow(2), Color(0.6, 1.0, 0.35, gl))
	# drop shadow
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	PixelArt.draw_box(self, r, fill, tc.darkened(0.35) if not is_cursor else K)
	# header band
	var hb := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 9))
	draw_rect(hb, tc)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x, 1)), tc.lightened(0.4))
	PixelArt.draw_text(self, hb.position + Vector2(2, 2), TIER_SHORT.get(tier, tier.to_upper()), K)
	# the picture is the card (CardFaces): a big drawing of what it does, arrows for how strong it is, a short name
	var face := CardFaces.of(card)
	var single := players.size() <= 1
	# cursed cards have no arrow row of their own, so their picture window gets that room
	var art_h := (72.0 if single else 52.0) + (12.0 if cursed else 0.0)
	var art := Rect2(r.position + Vector2(4, 13), Vector2(r.size.x - 8, art_h))
	draw_rect(art, tc.darkened(0.55))
	for i in range(0, int(art.size.x), 6):
		draw_rect(Rect2(art.position + Vector2(i, art.size.y - 3), Vector2(3, 3)), tc.darkened(0.4))
	var bob := roundf(sin(_age * 3.0 + r.position.x * 0.1) * 1.0) if not dim else 0.0
	var tint := Color(1, 1, 1, 1) if not dim else Color(0.5, 0.5, 0.5, 1)
	if cursed:
		_draw_cursed_pair(art, face, single, tint, dim)
	else:
		var pic := PixelArt.tex("card_" + String(face["icon"]))
		var psz := pic.get_size() * (4.0 if single else 3.0)
		draw_texture_rect(pic, Rect2((art.get_center() - psz / 2.0 + Vector2(0, bob)).round(), psz), false, tint)
	if cursed and not dim and int(_age * 6.0) % 4 == 0:
		draw_rect(Rect2(art.position + Vector2(randi_range(2, int(art.size.x) - 4), randi_range(2, 14)), Vector2(1, 1)), PixelArt.C["z"])
	# name: one or two words and nothing else
	var tx := r.position.x + 4.0
	var tw := r.size.x - 8.0
	var ink := K if not dim else Color8(60, 50, 60)
	var y := _wrap_text(Vector2(tx, art.end.y + 3), face["short"], tw, ink, true)
	draw_rect(Rect2(tx, y + 1, tw, 1), tc.darkened(0.2))
	# how strong: arrows (cursed cards show theirs beside each picture)
	if not cursed:
		_draw_arrows(Vector2(r.position.x + r.size.x / 2.0, y + 5), int(face["power"]), dim)
	# stack counter: one pip per copy you can own
	var owned := CardDB.times_owned(card, player)
	var mx := int(card.get("max", 99))
	if mx > 1 and mx < 99:
		_draw_pips(Vector2(r.end.x - 4, r.end.y - 7), owned, mini(mx, 5), tc)
	if card.get("coop", false):
		PixelArt.draw_text(self, Vector2(r.position.x + 4, r.end.y - 8), "TEAM", tc.darkened(0.3))
	elif card.has("gmods") and not card.has("mods"):
		PixelArt.draw_text(self, Vector2(r.position.x + 4, r.end.y - 8), "ALL", tc.darkened(0.3))
	# shine sweep on rare (synergy / blueprint) and cursed cards
	if not dim and (tier == "synergy" or tier == "cursed" or tier == "tower"):
		_draw_shine(r, 0.45 if tier != "tower" else 0.25, Color(0.85, 1.0, 0.7) if cursed else Color(1, 1, 1))


## Cursed cards: the good picture on top with up arrows, the bad one below with down arrows.
func _draw_cursed_pair(art: Rect2, face: Dictionary, single: bool, tint: Color, dim: bool) -> void:
	var row_h := (art.size.y - 2.0) / 2.0
	var scale := 2.0 if single else 1.0
	for k in 2:
		var good := k == 0
		var panel := Rect2(art.position + Vector2(1, 1 + k * row_h), Vector2(art.size.x - 2, row_h - 1.0))
		var base := Color8(24, 70, 30) if good else Color8(84, 26, 32)
		draw_rect(panel, base if not dim else Color8(40, 40, 40))
		var pic := PixelArt.tex("card_" + String(face["icon" if good else "bad_icon"]))
		var psz := pic.get_size() * scale
		var at := (panel.position + Vector2(3, (panel.size.y - psz.y) / 2.0)).round()
		draw_texture_rect(pic, Rect2(at, psz), false, tint)
		var n := int(face["power" if good else "bad_power"])
		var arrows_at := Vector2(at.x + psz.x + 4.0, panel.position.y + (panel.size.y - 7.0) / 2.0).round()
		for i in n:
			_draw_arrow(arrows_at + Vector2(i * 9.0, 0), good, dim)


## Up to three arrows centred on `center`; the ones past `n` are drawn as dim ghosts, so "2 of 3" reads at a glance.
func _draw_arrows(center: Vector2, n: int, dim: bool) -> void:
	var x0 := roundf(center.x - 12.0)
	for i in 3:
		var p := Vector2(x0 + i * 9.0, roundf(center.y))
		if i < n:
			_draw_arrow(p, true, dim)
		else:
			_arrow_shape(p, true, Color8(150, 140, 150) if not dim else Color8(90, 90, 90))


func _draw_arrow(p: Vector2, up: bool, dim: bool) -> void:
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_arrow_shape(p + d, up, K)
	var col: Color = PixelArt.C["Z"] if up else PixelArt.C["r"]
	_arrow_shape(p, up, col if not dim else col.darkened(0.5))


## A 7x7 arrow, up or down.
func _arrow_shape(p: Vector2, up: bool, col: Color) -> void:
	var rows := [[3, 1], [2, 3], [1, 5], [0, 7], [2, 3], [2, 3], [2, 3]]
	for i in rows.size():
		var yy := i if up else rows.size() - 1 - i
		draw_rect(Rect2(p + Vector2(rows[i][0], yy), Vector2(rows[i][1], 1)), col)


## One square per copy you can own; filled for the copies you already have. `right_bottom` is the pips' right edge.
func _draw_pips(right_bottom: Vector2, owned: int, count: int, tc: Color) -> void:
	for i in count:
		var p := right_bottom + Vector2(-(count - i) * 5.0, 0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(5, 5)), K)
		draw_rect(Rect2(p, Vector2(3, 3)), tc.lightened(0.2) if i < owned else Color8(210, 200, 190))


## Diagonal light band sweeping across a card every couple of seconds.
func _draw_shine(r: Rect2, strength: float, col: Color) -> void:
	var span := r.size.x + r.size.y * 0.5 + 16.0
	var ph := fmod(_age * 0.55 + r.position.x * 0.003, 1.6)
	if ph > 1.0:
		return
	var head := r.position.x - 8.0 + ph * span
	for yy in range(int(r.position.y) + 2, int(r.end.y) - 2):
		var x0 := head - (yy - r.position.y) * 0.5
		for k in 3:
			var x := roundf(x0 + k * 2.0)
			if x > r.position.x + 1.0 and x < r.end.x - 2.0:
				draw_rect(Rect2(x, yy, 1 if k != 1 else 2, 1), Color(col, strength * (0.6 if k != 1 else 1.0)))


## The back of a card: purple foil, diagonal stripes and a big striped seed emblem.
func _draw_card_back(r: Rect2, tier_col: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
	PixelArt.draw_box(self, r, Color8(72, 40, 96), K)
	var inner := r.grow(-3)
	draw_rect(inner, Color8(92, 52, 124))
	for yy in range(int(inner.position.y), int(inner.end.y), 2):
		var off := int(yy) % 8
		for xx in range(int(inner.position.x) + off, int(inner.end.x), 8):
			draw_rect(Rect2(xx, yy, 2, 1), Color8(110, 66, 146))
	var fr := inner.grow(-3)
	var oc := tier_col.darkened(0.2)
	draw_rect(Rect2(fr.position, Vector2(fr.size.x, 1)), oc)
	draw_rect(Rect2(fr.position + Vector2(0, fr.size.y - 1), Vector2(fr.size.x, 1)), oc)
	draw_rect(Rect2(fr.position, Vector2(1, fr.size.y)), oc)
	draw_rect(Rect2(fr.position + Vector2(fr.size.x - 1, 0), Vector2(1, fr.size.y)), oc)
	var c := r.get_center().round()
	PixelArt.draw_disk(self, c, 10.0, Color8(46, 28, 64))
	# seed emblem
	draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 12)), PixelArt.C["s"])
	draw_rect(Rect2(c + Vector2(-2, -7), Vector2(4, 14)), PixelArt.C["s"])
	draw_rect(Rect2(c + Vector2(-1, -5), Vector2(2, 10)), PixelArt.C["S"])
	draw_rect(Rect2(c + Vector2(-3, -6), Vector2(1, 1)), PixelArt.C["y"])
	PixelArt.draw_text_centered(self, Vector2(c.x, r.end.y - 12), "SNAX", PixelArt.C["y"], false)


## Draws word-wrapped text, returns the y below the last line.
func _wrap_text(pos: Vector2, text: String, width: float, col: Color, centered: bool, max_y: float = 99999.0) -> float:
	var lines: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		var test := word if line == "" else line + " " + word
		if PixelArt.text_width(test) > width and line != "":
			lines.append(line)
			line = word
		else:
			line = test
	if line != "":
		lines.append(line)
	var y := pos.y
	# long texts tighten their line spacing so they stay inside the card
	var step := 7.0
	if lines.size() > 1 and pos.y + lines.size() * 7.0 > max_y:
		step = maxf(6.0, floorf((max_y - pos.y) / lines.size()))
	for l in lines:
		if centered:
			var lw := PixelArt.text_width(l)
			PixelArt.draw_text(self, Vector2(roundf(pos.x + (width - lw) / 2.0), y), l, col)
		else:
			PixelArt.draw_text(self, Vector2(pos.x, y), l, col)
		y += step
	return y


func _draw_hand_labels() -> void:
	if _state != S.PICK and _state != S.DISPENSE:
		return
	var sz := _card_size()
	for i in players.size():
		var p = players[i]
		var cx := _hand_center_x(i)
		var y := _card_rest(i, 0).y + sz.y + 8.0
		var pc: Color = p.color()
		PixelArt.draw_text_centered(self, Vector2(cx, y), "P%d %s" % [p.player_id, p.display_name()], pc, true)
		var status := ""
		var scol := PixelArt.C["w"]
		if hands[i].is_empty():
			status = "SOLD OUT! NOTHING LEFT FOR YOU"
			scol = PixelArt.C["g"]
		elif awaiting[i]:
			status = "SOLVE THE PUZZLE TO ACTIVATE!" if _quiz_for == i else "PUZZLE COMING UP NEXT..."
			scol = PixelArt.C["y"] if int(_age * 3.0) % 2 == 0 else PixelArt.C["w"]
		elif picked[i]:
			var other_waiting := false
			for j in players.size():
				if j != i and not picked[j]:
					other_waiting = true
			var cname: String = CardFaces.of(hands[i][cursor[i]])["short"]
			status = ("WAITING FOR P%d..." % (2 if i == 0 else 1)) if other_waiting else "GOT: " + cname
			scol = PixelArt.C["Z"]
		elif _state == S.PICK:
			var inp: PlayerInput = p.input
			status = "%s/%s BROWSE   [%s] TAKE" % [_glyph_lr(inp, true), _glyph_lr(inp, false), inp.glyph("confirm")]
			if inp.device == "kbm":
				status = "A/D OR MOUSE   [E]/CLICK TAKE"
			scol = PixelArt.C["y"] if int(_age * 2.0) % 2 == 0 else PixelArt.C["w"]
		PixelArt.draw_text_centered(self, Vector2(cx, y + 10), status, scol, true)
		# the old sentences, small and grey, for the grown-up reading along
		if _state == S.PICK and not picked[i] and not awaiting[i] and not hands[i].is_empty():
			var cur: Dictionary = hands[i][cursor[i]]
			var detail := String(cur["desc"])
			if cur.has("downside"):
				detail += "  BUT: " + String(cur["downside"])
			var hand_w := sz.x * 3.0 + 12.0
			# one hand is centred under the "PICK ONE CARD" prompt, so its line goes below that
			_wrap_text(Vector2(cx - hand_w / 2.0, y + (36.0 if players.size() <= 1 else 22.0)), detail, hand_w, Color8(150, 152, 170), true)
		if _star_pop[i] > 0.0:
			var sy: float = y - 30.0 - (1.4 - _star_pop[i]) * 14.0
			draw_texture(PixelArt.tex("star"), Vector2(cx - 30, sy - 1))
			PixelArt.draw_text_outlined(self, Vector2(cx - 18, sy), "+1 MATH STAR!", PixelArt.C["y"])


func _glyph_lr(inp: PlayerInput, left: bool) -> String:
	match inp.device:
		"kbm":
			return "A" if left else "D"
		"kb2":
			return "<" if left else ">"
	return "<" if left else ">"
