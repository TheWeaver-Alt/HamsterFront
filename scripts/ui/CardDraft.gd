class_name CardDraft
extends Control
## End-of-wave Card Draft. Time freezes (tree paused), a vending machine drops from
## the sky with a screen-shaking thud, and each player picks 1 of 3 cards.

signal finished

enum Phase { HIDDEN, DROP, CHOOSE, CLOSE }

const W := 640.0
const H := 360.0
const MACHINE_W := 96.0
const MACHINE_H := 112.0
const MACHINE_REST_Y := 8.0

var phase: int = Phase.HIDDEN
var t := 0.0
var machine_y := -200.0
var machine_vy := 0.0
var pids: Array = []
var offers: Dictionary = {}
var sel: Dictionary = {}
var confirmed: Dictionary = {}
var _reveal := 0.0
var _bounced := false
var _last_mouse := Vector2.ZERO
var _wrap_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func open(player_ids: Array) -> void:
	pids = player_ids.duplicate()
	offers.clear()
	sel.clear()
	confirmed.clear()
	_wrap_cache.clear()
	for pid in pids:
		offers[pid] = CardDB.roll_offers(int(pid), 3)
		sel[pid] = 1 if offers[pid].size() > 1 else 0
		confirmed[pid] = offers[pid].is_empty()
	phase = Phase.DROP
	t = 0.0
	machine_y = -MACHINE_H - 20.0
	machine_vy = 0.0
	_reveal = 0.0
	_bounced = false
	_last_mouse = get_local_mouse_position()
	visible = true
	SFX.play("vend", 1.0, 0.0, 0)


func _process(delta: float) -> void:
	if phase == Phase.HIDDEN:
		return
	t += delta
	match phase:
		Phase.DROP:
			machine_vy += 1400.0 * delta
			machine_y += machine_vy * delta
			if machine_y >= MACHINE_REST_Y:
				machine_y = MACHINE_REST_Y
				if not _bounced:
					_bounced = true
					machine_vy = -machine_vy * 0.3
					JuiceManager.add_trauma(0.55)
					SFX.play("boom", 0.8, 0.0, 0)
					SFX.play("vend", 1.4, -4.0, 0)
				else:
					machine_vy = 0.0
					phase = Phase.CHOOSE
					t = 0.0
		Phase.CHOOSE:
			_reveal = minf(1.0, _reveal + delta * 3.0)
			if t > 0.35:
				_handle_input()
		Phase.CLOSE:
			machine_y -= 500.0 * delta
			_reveal = maxf(0.0, _reveal - delta * 4.0)
			if t > 0.5:
				phase = Phase.HIDDEN
				visible = false
				finished.emit()
	queue_redraw()


func _handle_input() -> void:
	for pid in pids:
		if confirmed[pid]:
			continue
		var list: Array = offers[pid]
		var n := list.size()
		var pre := "p%d_" % int(pid)
		var cur: int = sel[pid]
		if Input.is_action_just_pressed(pre + "left") or Input.is_action_just_pressed(pre + "build_prev"):
			cur = (cur - 1 + n) % n
		if Input.is_action_just_pressed(pre + "right") or Input.is_action_just_pressed(pre + "build_next"):
			cur = (cur + 1) % n
		var do_confirm := false
		if int(pid) == 1:
			var mp := get_local_mouse_position()
			if mp.distance_to(_last_mouse) > 0.5:
				_last_mouse = mp
				for i in n:
					if _card_rect(1, i).has_point(mp):
						cur = i
			for i in n:
				if Input.is_action_just_pressed("p1_select_%d" % (i + 1)):
					cur = i
					do_confirm = true
			if Input.is_action_just_pressed("p1_fire") or Input.is_action_just_pressed("p1_interact"):
				do_confirm = true
		else:
			if Input.is_action_just_pressed("p2_interact") or Input.is_action_just_pressed("p2_fire") or Input.is_action_just_pressed("p2_build_place"):
				do_confirm = true
		if cur != sel[pid]:
			sel[pid] = cur
			SFX.play("card", 1.0, -6.0, 0)
		if do_confirm:
			confirmed[pid] = true
			var card: Dictionary = list[cur]
			SFX.play("card", 1.6, 0.0, 0)
			if card["tier"] == "cursed":
				SFX.play("zap", 0.6, -4.0, 0)
	var all_done := true
	for pid in pids:
		if not confirmed[pid]:
			all_done = false
	if all_done:
		for pid in pids:
			var list: Array = offers[pid]
			if not list.is_empty():
				CardDB.apply_card(list[sel[pid]], int(pid))
		phase = Phase.CLOSE
		t = 0.0
		SFX.play("vend", 0.8, -4.0, 0)


func _card_size() -> Vector2:
	if pids.size() >= 2:
		return Vector2(96, 150)
	return Vector2(132, 150)


func _card_rect(pid: int, i: int) -> Rect2:
	var sz := _card_size()
	var gap := 6.0 if pids.size() >= 2 else 10.0
	var total := sz.x * 3.0 + gap * 2.0
	var x0 := (W - total) / 2.0
	if pids.size() >= 2:
		x0 = 14.0 if pid == pids[0] else W - 14.0 - total
	var y := 172.0
	return Rect2(x0 + i * (sz.x + gap), y, sz.x, sz.y)


func _wrapped(text: String, width: int) -> PackedStringArray:
	var key := "%s|%d" % [text, width]
	if not _wrap_cache.has(key):
		_wrap_cache[key] = PixelFont.wrap_text(text.to_upper(), width)
	return _wrap_cache[key]


func _draw() -> void:
	if phase == Phase.HIDDEN:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
	_draw_machine()
	if _reveal <= 0.0:
		return
	PixelFont.draw_centered(self, "VENDING MACHINE OF FATE", Vector2(W / 2.0, 130), Pal.SUNFLOWER, 2, Pal.INK)
	PixelFont.draw_centered(self, "WAVE %d CLEARED - PICK ONE UPGRADE EACH" % GameManager.wave, Vector2(W / 2.0, 148), Pal.WHITE, 1, Pal.INK)
	var slot := Vector2(W / 2.0, machine_y + MACHINE_H - 18.0)
	for pid in pids:
		var list: Array = offers[pid]
		if pids.size() >= 2:
			var r0 := _card_rect(int(pid), 0)
			var label := "P1 BRAWLER-01" if int(pid) == 1 else "P2 WHEELER-X"
			PixelFont.draw_text(self, label, Vector2(r0.position.x, r0.position.y - 10), Pal.player_color(int(pid)), 1, Pal.INK)
		for i in list.size():
			var r := _card_rect(int(pid), i)
			var target := r.position
			var start := slot - r.size / 2.0
			var e := 1.0 - pow(1.0 - _reveal, 3.0)
			var pos := start.lerp(target, e)
			var selected: bool = sel[pid] == i
			if selected and not confirmed[pid]:
				pos.y -= 6.0
			_draw_card(list[i], Rect2(pos.round(), r.size), int(pid), selected, bool(confirmed[pid]))
	var hint := "P1: A/D OR MOUSE, CLICK / E TO TAKE (OR 1-3)"
	if pids.size() >= 2:
		hint += "      P2: STICK / ARROWS, A / ENTER TO TAKE"
	elif int(pids[0]) == 2:
		hint = "P2: STICK / ARROWS, A / ENTER TO TAKE"
	PixelFont.draw_centered(self, hint, Vector2(W / 2.0, 344), Pal.WHITE, 1, Pal.INK)


func _draw_machine() -> void:
	var x := W / 2.0 - MACHINE_W / 2.0
	var y := roundf(machine_y)
	draw_rect(Rect2(x + 4, y + MACHINE_H, MACHINE_W - 8, 4), Pal.SHADOW)
	draw_rect(Rect2(x - 1, y - 1, MACHINE_W + 2, MACHINE_H + 2), Pal.INK)
	draw_rect(Rect2(x, y, MACHINE_W, MACHINE_H), Color("c2393f"))
	draw_rect(Rect2(x, y, MACHINE_W, 14), Color("8e2430"))
	PixelFont.draw_centered(self, "SNAX OF FATE", Vector2(W / 2.0, y + 4), Pal.SUNFLOWER)
	# Glass window with spiral rows of snack-cards.
	var gx := x + 6
	var gy := y + 18
	draw_rect(Rect2(gx, gy, 62, 72), Color("1d2b40"))
	var tier_cols := [Pal.TIER_MOD, Pal.TIER_TOWER, Pal.TIER_COOP, Pal.TIER_CURSED]
	for row in 4:
		for col in 4:
			var c: Color = tier_cols[(row + col) % 4]
			draw_rect(Rect2(gx + 4 + col * 15, gy + 4 + row * 17, 10, 12), c)
			draw_rect(Rect2(gx + 3 + col * 15, gy + 15 + row * 17, 12, 1), Pal.METAL_LIGHT)
	draw_rect(Rect2(gx, gy, 62, 2), Color(1, 1, 1, 0.25))
	draw_rect(Rect2(gx + 2, gy + 2, 2, 60), Color(1, 1, 1, 0.15))
	# Keypad + coin slot.
	var kx := x + 74
	for row in 4:
		for col in 2:
			draw_rect(Rect2(kx + col * 8, gy + 4 + row * 8, 6, 6), Pal.METAL_LIGHT)
	draw_rect(Rect2(kx + 2, gy + 42, 10, 3), Pal.INK)
	draw_rect(Rect2(kx, gy + 52, 14, 18), Pal.METAL_DARK)
	# Delivery slot.
	draw_rect(Rect2(x + 10, y + MACHINE_H - 16, MACHINE_W - 20, 8), Pal.INK)
	if phase == Phase.DROP:
		for i in 3:
			draw_rect(Rect2(x + 8 + i * 34, y - 12 - i * 6, 1, 8), Color(1, 1, 1, 0.4))


func _draw_card(card: Dictionary, r: Rect2, pid: int, selected: bool, locked: bool) -> void:
	var tier: String = card["tier"]
	var tcol := Pal.tier_color(tier)
	var bg := Pal.WHITE
	if tier == "cursed":
		bg = Color("1e2a1a")
	var fg := Pal.INK if tier != "cursed" else Pal.WARP
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Pal.SHADOW)
	draw_rect(r.grow(1.0), Pal.INK)
	draw_rect(r, tcol)
	draw_rect(r.grow(-2.0), bg)
	if tier == "cursed":
		for i in 6:
			var gx := r.position.x + 4 + fmod(t * 20.0 + i * 17.0, r.size.x - 8)
			draw_rect(Rect2(gx, r.position.y + r.size.y - 6 - (i % 3) * 3, 1, 1), Pal.WARP)
	# Tier header.
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 9), tcol)
	PixelFont.draw_centered(self, CardDB.tier_label(tier), Vector2(r.position.x + r.size.x / 2.0, r.position.y + 4), Pal.INK)
	var inner := int(r.size.x) - 10
	var name_lines := _wrapped(String(card["name"]), inner)
	var y := r.position.y + 15
	for l in name_lines:
		PixelFont.draw_centered(self, l, Vector2(r.position.x + r.size.x / 2.0, y), tcol if tier == "cursed" else Pal.ESPRESSO_RED, 1)
		y += 7
	y += 3
	draw_rect(Rect2(r.position.x + 6, y - 2, r.size.x - 12, 1), Color(fg, 0.3))
	for l in _wrapped(String(card["desc"]), inner):
		PixelFont.draw_text(self, l, Vector2(r.position.x + 5, y + 1), fg)
		y += 7
	if card["mech"] != "any":
		PixelFont.draw_centered(self, String(card["mech"]).to_upper() + " ONLY", Vector2(r.position.x + r.size.x / 2.0, r.position.y + r.size.y - 10), Color(fg, 0.6))
	if selected:
		var pcol := Pal.player_color(pid)
		if locked or int(t * 4.0) % 2 == 0:
			draw_rect(r.grow(3.0), pcol, false, 2.0)
		PixelFont.draw_centered(self, "P%d" % pid, Vector2(r.position.x + r.size.x / 2.0, r.position.y + r.size.y + 5), pcol, 1, Pal.INK)
	if locked and selected:
		var c := r.get_center()
		draw_rect(Rect2(c.x - 22, c.y - 9, 44, 18), Color(Pal.INK, 0.85))
		PixelFont.draw_centered(self, "TAKEN!", Vector2(c.x, c.y - 5), Pal.HP_GREEN, 2)
