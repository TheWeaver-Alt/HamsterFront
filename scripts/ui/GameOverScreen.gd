extends Control
## Game-over overlay: the Silo has fallen and The Great Horned Gouda rises.
## CONTRACT: MainArena calls open() after the Silo falls (tree is paused; processes ALWAYS).
## Confirm = try again (reload arena), back = title. Keyboard+mouse pilot can click the buttons.

const OPTIONS := ["TRY AGAIN", "TITLE"]
const K := Color8(26, 16, 32)
const CHANTS := ["GOUDA-GOUDA!", "SEEDS-SEEDS! ALL OURS!", "FAT-CHEEKS LOSE-LOSE!", "PRAISE THE HORNED ONE!"]

var sel := 0
var _t := 0.0
var _inputs: Array = []
var _embers: Array = []
var _lmb_prev := false
var _mouse_prev := Vector2.ZERO
var _stats: Array = []      # [label, value(int), suffix or ""] tallied up over time


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open() -> void:
	visible = true
	_t = 0.0
	sel = 0
	_embers.clear()
	_inputs.clear()
	for p in GameManager.players:
		if is_instance_valid(p):
			p.input.update(null)
			p.input.consume()
			_inputs.append(p.input)
	var cards := 0
	for id in GameManager.owned_cards.keys():
		cards += int(GameManager.owned_cards[id])
	_stats = [
		["WAVES SURVIVED", maxi(0, GameManager.wave - 1)],
		["RATS SQUASHED", GameManager.kills],
		["SEEDS BANKED", GameManager.seeds_banked_total],
		["CARDS TAKEN", cards],
		["TIME", int(GameManager.run_time)],
	]
	var learning := false
	for lv in GameManager.learning_levels:
		if int(lv) > 0:
			learning = true
	if learning:
		_stats.append(["MATH STARS", GameManager.math_stars])
	_lmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_mouse_prev = get_global_mouse_position()


func _option_rect(i: int) -> Rect2:
	return Rect2(236 + i * 92, 318, 80, 16)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# rising warp embers
	if randf() < 0.6:
		_embers.append({"p": Vector2(randf_range(0, 640), 370), "v": Vector2(randf_range(-8, 8), randf_range(-60, -25)), "life": randf_range(2.0, 5.0)})
	var k := _embers.size() - 1
	while k >= 0:
		var e: Dictionary = _embers[k]
		e["life"] -= delta
		e["p"] += (e["v"] as Vector2) * delta
		if e["life"] <= 0.0:
			_embers.remove_at(k)
		k -= 1
	if _t > 1.6:
		var m := get_global_mouse_position()
		var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var click := lmb and not _lmb_prev
		_lmb_prev = lmb
		var moved := m.distance_to(_mouse_prev) > 0.5
		_mouse_prev = m
		for i in OPTIONS.size():
			if _option_rect(i).has_point(m):
				if moved and sel != i:
					sel = i
					Sfx.play("select", 1.2, -6.0)
				if click:
					sel = i
					_choose()
					return
		for inp in _inputs:
			inp.update(null)
			if inp.just("left") or inp.just("up"):
				sel = (sel + OPTIONS.size() - 1) % OPTIONS.size()
				Sfx.play("select")
			if inp.just("right") or inp.just("down"):
				sel = (sel + 1) % OPTIONS.size()
				Sfx.play("select")
			if inp.just("back"):
				sel = 1
				_choose()
				return
			if inp.just("confirm") and not (inp.device == "kbm" and lmb):
				_choose()
				return
	queue_redraw()


func _choose() -> void:
	Sfx.play("card")
	Engine.time_scale = 1.0
	if sel == 0:
		Transition.reload_scene()
	else:
		Transition.change_scene("res://scenes/TitleScreen.tscn")


func _draw() -> void:
	var a := clampf(_t / 0.8, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.03, 0.08, 0.03, 0.82 * a))
	# warp-green god rays behind the idol
	var center := Vector2(320, 104)
	for i in 10:
		var ang := _t * 0.25 + i * TAU / 10.0
		var pts := PackedVector2Array([center, center + Vector2.from_angle(ang - 0.08) * 420.0, center + Vector2.from_angle(ang + 0.08) * 420.0])
		draw_colored_polygon(pts, Color(0.55, 1.0, 0.3, 0.05 * a))
	for e in _embers:
		var c := PixelArt.C["z"]
		c.a = clampf(float(e["life"]) / 2.0, 0.0, 1.0) * a
		draw_rect(Rect2((e["p"] as Vector2).round(), Vector2(1, 1)), c)
	_draw_rats(a, false)
	# The Great Horned Gouda rises
	var rise := clampf((_t - 0.3) / 1.2, 0.0, 1.0)
	rise = 1.0 - pow(1.0 - rise, 3.0)
	var gouda := PixelArt.tex("horned_gouda")
	var gsz := gouda.get_size() * 2.0
	var gy := lerpf(380.0, 34.0, rise) + roundf(sin(_t * 1.5) * 2.0)
	draw_texture_rect(gouda, Rect2(Vector2(320 - gsz.x / 2.0, gy), gsz), false)
	# eye glow pulse
	if rise > 0.9:
		var pulse := 0.4 + 0.3 * sin(_t * 5.0)
		for side in [-1.0, 1.0]:
			PixelArt.draw_disk(self, Vector2(320 + side * 18.0, gy + 64), 9.0, Color(0.7, 1.0, 0.4, pulse * 0.35))
	_draw_rats(a, true)
	# chant bubble
	if _t > 1.5:
		var ci := int(_t / 2.2) % 8
		var ang := _t * 0.8 + ci * TAU / 8.0
		var rp := Vector2(320 + cos(ang) * 150.0, 150 + sin(ang) * 26.0)
		var line: String = CHANTS[int(_t / 2.2) % CHANTS.size()]
		var w := PixelArt.text_width(line) + 6
		var br := Rect2(rp.x - w / 2.0, rp.y - 32, w, 10)
		PixelArt.draw_box(self, br, Color8(34, 52, 30), PixelArt.C["z"])
		PixelArt.draw_text(self, br.position + Vector2(3, 3), line, PixelArt.C["z"])
	# titles
	var ta := clampf((_t - 0.2) / 0.5, 0.0, 1.0)
	var shake := Vector2(randi_range(-1, 1), randi_range(-1, 1)) if _t < 0.8 else Vector2.ZERO
	UiText.outlined_centered(self, Vector2(320, 14) + shake, "THE SILO HAS FALLEN", Color(PixelArt.C["r"], ta), 18)
	UiText.outlined_centered(self, Vector2(320, 180), "THE GREAT HORNED GOUDA FEASTS TONIGHT", Color(PixelArt.C["z"], ta), 12)
	# stats tally
	var panel := Rect2(190, 196, 260, 114)
	if _t > 1.0:
		PixelArt.draw_box(self, panel, Color(0.06, 0.04, 0.08, 0.92), PixelArt.C["x"])
		for i in _stats.size():
			var appear := 1.0 + i * 0.3
			if _t < appear:
				break
			var label: String = _stats[i][0]
			var target: int = _stats[i][1]
			var frac := clampf((_t - appear) / 0.6, 0.0, 1.0)
			var v := int(roundf(target * frac))
			var val := str(v)
			if label == "TIME":
				val = "%02d:%02d" % [int(v / 60), v % 60]
			var y := panel.position.y + 6 + i * 12
			if label == "MATH STARS":
				draw_texture(PixelArt.tex("star"), Vector2(panel.position.x + 1, y - 2))
			PixelArt.draw_text(self, Vector2(panel.position.x + 10, y), label, PixelArt.C["y"] if label == "MATH STARS" else PixelArt.C["W"])
			var vw := PixelArt.text_width(val, 12)
			PixelArt.draw_text_outlined(self, Vector2(panel.end.x - 10 - vw, y - 3), val, PixelArt.C["y"], K, 12)
		if _t > 2.8:
			_draw_card_list(panel)
	# buttons
	if _t > 1.6:
		for i in OPTIONS.size():
			var r := _option_rect(i)
			var on := i == sel
			PixelArt.draw_box(self, r, PixelArt.C["Z"].darkened(0.6) if on else Color(0.06, 0.04, 0.08, 0.9), PixelArt.C["z"] if on else PixelArt.C["G"])
			var glyph := ""
			if not _inputs.is_empty():
				glyph = "[%s] " % _inputs[0].glyph("confirm" if i == 0 else "back")
			PixelArt.draw_text_centered(self, Vector2(r.get_center().x, r.position.y + 5), glyph + OPTIONS[i], PixelArt.C["w"] if on else PixelArt.C["g"], on)


## Rats dancing in a ring around the idol; back half drawn behind it, front half in front.
func _draw_rats(a: float, front: bool) -> void:
	for i in 8:
		var ang := _t * 0.8 + i * TAU / 8.0
		if (sin(ang) > 0.0) != front:
			continue
		var rp := Vector2(320 + cos(ang) * 150.0, 150 + sin(ang) * 26.0)
		var hop := -absf(sin(_t * 7.0 + i)) * 5.0
		var tex := PixelArt.tex("rat_squeaker_%d" % (int(_t * 8.0 + i) % 2))
		var face := -1.0 if sin(ang) > 0.0 else 1.0
		draw_set_transform(rp + Vector2(0, hop), 0.0, Vector2(face, 1))
		draw_texture(tex, Vector2(-10, -tex.get_height()), Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card_list(panel: Rect2) -> void:
	# one line per pilot: their card names, clipped to the panel
	var y := panel.position.y + 10 + _stats.size() * 12
	for p in GameManager.players:
		if not is_instance_valid(p):
			continue
		var names: Array = []
		for id in p.owned_cards.keys():
			var c: Dictionary = CardDB.get_card(id)
			if not c.is_empty():
				names.append(c["name"])
		var line := "P%d: " % p.player_id + (", ".join(PackedStringArray(names)) if not names.is_empty() else "NO CARDS")
		while PixelArt.text_width(line) > panel.size.x - 20 and line.length() > 4:
			line = line.substr(0, line.length() - 4) + ".."
		PixelArt.draw_text(self, Vector2(panel.position.x + 10, y), line, p.color())
		y += 9
