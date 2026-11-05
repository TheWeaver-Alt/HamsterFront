extends Control
## Pause overlay.
## CONTRACT: MainArena toggles `visible` and calls open(); choosing RESUME calls
## GameManager.arena.toggle_pause(). Processes ALWAYS (the tree is paused while shown).
## Pause/back on any pilot's device also resumes. The keyboard+mouse pilot can hover/click.

const OPTIONS := ["RESUME", "RESTART RUN", "QUIT TO TITLE"]
const K := Color8(26, 16, 32)

var sel := 0
var _inputs: Array = []
var _t := 0.0
var _lmb_prev := false
var _mouse_prev := Vector2.ZERO
var _confirm_restart := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open() -> void:
	sel = 0
	_t = 0.0
	_confirm_restart = false
	_inputs.clear()
	for p in GameManager.players:
		if is_instance_valid(p):
			# mark everything currently held (the pause key itself) as already seen
			p.input.update(null)
			p.input.consume()
			_inputs.append(p.input)
	_lmb_prev = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_mouse_prev = get_global_mouse_position()
	Sfx.play("select", 0.7)


func _option_rect(i: int) -> Rect2:
	return Rect2(250, 168 + i * 18, 140, 14)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# mouse hover / click
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
		if inp.just("up"):
			sel = (sel + OPTIONS.size() - 1) % OPTIONS.size()
			Sfx.play("select")
		if inp.just("down"):
			sel = (sel + 1) % OPTIONS.size()
			Sfx.play("select")
		if inp.just("pause") or (inp.just("back") and not inp.just("confirm")):
			sel = 0
			_choose()
			return
		if inp.just("confirm") and not (inp.device == "kbm" and lmb):
			_choose()
			return
	queue_redraw()


func _choose() -> void:
	Sfx.play("card")
	match sel:
		0:
			GameManager.arena.toggle_pause()
		1:
			Transition.reload_scene()
		2:
			Transition.change_scene("res://scenes/TitleScreen.tscn")


func _draw() -> void:
	var a := clampf(_t / 0.15, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.03, 0.08, 0.72 * a))
	# panels drop in with a springy settle
	var e := clampf(_t / 0.28, 0.0, 1.0)
	var u := e - 1.0
	var settle := 1.0 + 2.6 * u * u * u + 1.6 * u * u
	draw_set_transform(Vector2(0, roundf((1.0 - settle) * -40.0)), 0.0, Vector2.ONE)
	# central panel
	var panel := Rect2(210, 70, 220, 190)
	PixelArt.draw_box(self, panel, Color(0.1, 0.06, 0.13, 0.96), PixelArt.C["y"])
	PixelArt.draw_text_centered(self, Vector2(320, 80), "PAUSED", PixelArt.C["y"], true, 18)
	# sleeping hamster + floating Zs
	var hz := PixelArt.tex("zzz_hamster")
	draw_texture(hz, Vector2(307, 112 + roundf(sin(_t * 1.5))))
	for i in 3:
		var zt := fmod(_t * 0.8 + i * 0.33, 1.0)
		var zp := Vector2(334 + zt * 14.0 + i * 2, 118 - zt * 18.0).round()
		var zc := PixelArt.C["w"]
		zc.a = 1.0 - zt
		PixelArt.draw_text(self, zp, "Z", zc, 6 if i < 2 else 12)
	PixelArt.draw_text_centered(self, Vector2(320, 140), "THE RATS ARE ALSO TAKING A BREATHER", PixelArt.C["g"], false)
	PixelArt.draw_text_centered(self, Vector2(320, 150), "WAVE %d   %s   SEEDS %d/%d" % [GameManager.wave, _fmt_time(GameManager.run_time), GameManager.seeds, GameManager.silo_capacity], PixelArt.C["W"], false)
	for i in OPTIONS.size():
		var r := _option_rect(i)
		var on := i == sel
		if on:
			PixelArt.draw_box(self, r, PixelArt.C["y"].darkened(0.55), PixelArt.C["y"])
			var bob := roundf(sin(_t * 8.0))
			PixelArt.draw_text(self, Vector2(r.position.x + 6 + bob, r.position.y + 4), ">", PixelArt.C["y"])
		PixelArt.draw_text_centered(self, Vector2(320, r.position.y + 4), OPTIONS[i], PixelArt.C["w"] if on else PixelArt.C["g"], on)
	var hint := "UP/DOWN + CONFIRM   PAUSE/BACK: RESUME"
	PixelArt.draw_text_centered(self, Vector2(320, panel.end.y - 12), hint, PixelArt.C["G"].lightened(0.3), false)
	# card loadouts on the sides
	var pi := 0
	for p in GameManager.players:
		if is_instance_valid(p):
			_draw_loadout(p, pi)
		pi += 1
	_draw_team_cards()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_loadout(p, idx: int) -> void:
	var x := 14.0 if idx == 0 else 440.0
	var r := Rect2(x, 70, 186, 190)
	var col: Color = p.color()
	PixelArt.draw_box(self, r, Color(0.08, 0.05, 0.1, 0.9), col.darkened(0.3))
	PixelArt.draw_text(self, r.position + Vector2(6, 5), "P%d %s" % [p.player_id, p.display_name()], col)
	PixelArt.draw_text(self, r.position + Vector2(6, 14), "HP %d/%d   POUCH %d/%d" % [int(p.hp), int(p.max_hp()), p.pouch.amount, p.pouch.capacity()], PixelArt.C["W"])
	var y := r.position.y + 26
	var owned: Dictionary = p.owned_cards
	if owned.is_empty():
		PixelArt.draw_text(self, Vector2(x + 6, y), "NO CARDS YET", PixelArt.C["G"].lightened(0.3))
		return
	# one small picture per card (the picture is the card); a number marks repeats
	var ix := x + 6.0
	var iy := y
	for id in owned.keys():
		var card: Dictionary = CardDB.get_card(id)
		if card.is_empty():
			continue
		if ix + 17.0 > r.end.x - 4.0:
			ix = x + 6.0
			iy += 20.0
		if iy > r.end.y - 18.0:
			PixelArt.draw_text(self, Vector2(ix, iy + 5), "...", PixelArt.C["g"])
			break
		draw_texture(PixelArt.tex("card_" + String(CardFaces.of(card)["icon"])), Vector2(ix, iy))
		draw_rect(Rect2(ix, iy + 17, 16, 2), CardDB.tier_color(card["tier"]))
		var n: int = owned[id]
		if n > 1:
			PixelArt.draw_text_outlined(self, Vector2(ix + 9, iy + 9), str(n), PixelArt.C["y"])
		ix += 19.0


func _draw_team_cards() -> void:
	# team-wide cards (towers / synergy) bought by anyone, as pictures
	var team: Array = []
	for id in GameManager.owned_cards.keys():
		var card: Dictionary = CardDB.get_card(id)
		if card.is_empty() or card.has("mods"):
			continue
		team.append(card)
	if team.is_empty():
		return
	var per_row := 30
	var r := Rect2(14, 268, 612, 8 + ceili(team.size() / float(per_row)) * 20)
	PixelArt.draw_box(self, r, Color(0.08, 0.05, 0.1, 0.9), PixelArt.C["o"].darkened(0.3))
	PixelArt.draw_text(self, r.position + Vector2(6, 8), "TEAM:", PixelArt.C["o"])
	var i := 0
	for card in team:
		var ix := r.position.x + 40.0 + (i % per_row) * 19.0
		var iy := r.position.y + 4.0 + int(i / per_row) * 20.0
		draw_texture(PixelArt.tex("card_" + String(CardFaces.of(card)["icon"])), Vector2(ix, iy))
		draw_rect(Rect2(ix, iy + 17, 16, 2), CardDB.tier_color(card["tier"]))
		var n: int = GameManager.owned_cards[card["id"]]
		if n > 1:
			PixelArt.draw_text_outlined(self, Vector2(ix + 9, iy + 9), str(n), PixelArt.C["y"])
		i += 1


func _clip(text: String, width: float) -> String:
	if PixelArt.text_width(text) <= width:
		return text
	var t := text
	while t.length() > 1 and PixelArt.text_width(t + "..") > width:
		t = t.substr(0, t.length() - 1)
	return t + ".."


static func _fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [int(s / 60), s % 60]
