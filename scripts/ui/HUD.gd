extends Control
## Pixel HUD drawn entirely in _draw(): wave/phase, Silo HP, banked seeds, per-player panels
## (pilot head showing cheek inflation, HP, cheek pouch, wheel heat, selected tower, owned
## card pips, buffs), boss bar, centre announcements and a low-Silo danger vignette.
## CONTRACT: listens to GameManager.announce / silo_changed / seeds_changed; reads players
## and GameManager.arena (build_timer, enemies, spawner, boss) every frame.

const K := Color8(26, 16, 32)
const PANEL_W := 152.0
const PANEL_H := 34.0

var _announce_text := ""
var _announce_sub := ""
var _announce_col := Color.WHITE
var _announce_t := 0.0
var _silo_flash := 0.0
var _last_silo := 0.0
var _seed_bump := 0.0
var _last_seeds := 0
var _t := 0.0
var _dt := 0.016
var _bars: Dictionary = {}        # key -> {shown, ghost, hold, flash, gain, last}
var _disp_seeds := 0.0
var _disp_kills := 0.0
var _disp_stars := 0.0
var _boss_shake := 0.0
var _last_boss_hp := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# keep redrawing while the tree is paused so frozen-frame leftovers (announcements) clear
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.announce.connect(_on_announce)
	GameManager.silo_changed.connect(_on_silo_changed)
	GameManager.seeds_changed.connect(_on_seeds_changed)
	_last_silo = GameManager.silo_hp
	_last_seeds = GameManager.seeds
	_disp_seeds = GameManager.seeds
	_disp_kills = GameManager.kills


func _on_silo_changed(hp: float, _max_hp: float) -> void:
	if hp < _last_silo:
		_silo_flash = 1.0
	_last_silo = hp


func _on_seeds_changed(n: int) -> void:
	if n > _last_seeds:
		_seed_bump = 1.0
	_last_seeds = n


func _on_announce(text: String, sub: String, col: Color) -> void:
	_announce_text = text
	_announce_sub = sub
	_announce_col = col
	_announce_t = 2.8


func _process(delta: float) -> void:
	_dt = clampf(delta, 0.0, 0.05)
	if get_tree().paused:
		queue_redraw()
		return
	_t += delta
	# counters tick towards their real values
	_disp_seeds = _tick_to(_disp_seeds, float(GameManager.seeds), delta)
	_disp_kills = _tick_to(_disp_kills, float(GameManager.kills), delta)
	_disp_stars = _tick_to(_disp_stars, float(GameManager.math_stars), delta)
	_boss_shake = maxf(0.0, _boss_shake - delta * 6.0)
	_announce_t = maxf(0.0, _announce_t - delta)
	_silo_flash = maxf(0.0, _silo_flash - delta * 4.0)
	_seed_bump = maxf(0.0, _seed_bump - delta * 5.0)
	queue_redraw()


func _draw() -> void:
	_draw_danger_vignette()
	_draw_top_bar()
	var i := 0
	for p in GameManager.players:
		if is_instance_valid(p):
			_draw_player_panel(p, i)
		i += 1
	_draw_boss_bar()
	_draw_phase_hint()
	_draw_announcement()


func _tick_to(v: float, target: float, delta: float) -> float:
	if absf(target - v) < 0.5:
		return target
	return v + (target - v) * minf(1.0, delta * 9.0) + signf(target - v) * 0.5


# ------------------------------------------------------------------ animated bars

func _bar_state(key: String, frac: float) -> Dictionary:
	if not _bars.has(key):
		_bars[key] = {"shown": frac, "ghost": frac, "hold": 0.0, "flash": 0.0, "gain": 0.0, "last": frac}
	var b: Dictionary = _bars[key]
	var last: float = b["last"]
	if frac < last - 0.0005:
		b["hold"] = 0.4
		b["flash"] = 1.0
	elif frac > last + 0.0005:
		b["gain"] = 1.0
	b["last"] = frac
	var shown: float = b["shown"]
	b["shown"] = shown + (frac - shown) * minf(1.0, _dt * 16.0)
	var ghost: float = b["ghost"]
	if frac >= ghost:
		b["ghost"] = frac
	elif float(b["hold"]) > 0.0:
		b["hold"] = float(b["hold"]) - _dt
	else:
		b["ghost"] = move_toward(ghost, frac, _dt * 0.7)
	b["flash"] = maxf(0.0, float(b["flash"]) - _dt * 5.0)
	b["gain"] = maxf(0.0, float(b["gain"]) - _dt * 3.0)
	return b


## Chunky pixel bar: dark frame, trough, trailing ghost, bevelled fill, notches, hit flash.
func _fancy_bar(key: String, r: Rect2, frac: float, col: Color, notch: int = 0) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var b := _bar_state(key, frac)
	r = Rect2(r.position.round(), r.size.round())
	draw_rect(r.grow(1), K)
	draw_rect(r, Color8(44, 30, 54))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color8(30, 20, 38))
	var ghost_w := roundf(r.size.x * clampf(float(b["ghost"]), 0.0, 1.0))
	var fill_w := roundf(r.size.x * clampf(float(b["shown"]), 0.0, 1.0))
	if ghost_w > fill_w:
		var gc := Color8(255, 248, 231) if int(_t * 20.0) % 2 == 0 and float(b["hold"]) > 0.0 else col.lightened(0.55)
		draw_rect(Rect2(r.position + Vector2(fill_w, 0), Vector2(ghost_w - fill_w, r.size.y)), gc)
	if fill_w > 0.0:
		draw_rect(Rect2(r.position, Vector2(fill_w, r.size.y)), col)
		draw_rect(Rect2(r.position, Vector2(fill_w, 1)), col.lightened(0.4))
		if r.size.y >= 3:
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(fill_w, 1)), col.darkened(0.3))
		if float(b["gain"]) > 0.0:
			draw_rect(Rect2(r.position, Vector2(fill_w, r.size.y)), Color(1, 1, 1, 0.35 * float(b["gain"])))
	if notch > 0:
		var x := r.position.x + notch
		while x < r.end.x - 1:
			draw_rect(Rect2(x, r.position.y, 1, r.size.y), Color(0, 0, 0, 0.25))
			x += notch
	if float(b["flash"]) > 0.0:
		draw_rect(r.grow(1), Color(1, 1, 1, 0.45 * float(b["flash"])))


## Bevelled pixel panel used for every HUD frame.
func _panel(r: Rect2, fill: Color, border: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0.05, 0.03, 0.07, 0.45))
	PixelArt.draw_box(self, r, fill, border)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 1, r.size.x - 4, 1), Color(border.lightened(0.4), 0.35))
	draw_rect(Rect2(r.position.x + 2, r.end.y - 2, r.size.x - 4, 1), Color(0, 0, 0, 0.25))
	for c in [r.position + Vector2(2, 2), Vector2(r.end.x - 3, r.position.y + 2)]:
		draw_rect(Rect2(c, Vector2(1, 1)), Color(border.lightened(0.5), 0.6))


func _silo_frac() -> float:
	return GameManager.silo_hp / maxf(1.0, GameManager.silo_max_hp)


## Low-Silo alarm: pulsing corner brackets + a thin dithered edge. Readable, not obnoxious.
func _draw_danger_vignette() -> void:
	var frac := _silo_frac()
	if frac >= 0.3 or GameManager.phase == "title":
		return
	var urgency := 1.0 - frac / 0.3
	var pulse := 0.5 + 0.5 * sin(_t * (5.0 + urgency * 4.0))
	var c := Color(1.0, 0.2, 0.12, (0.35 + 0.35 * pulse) * (0.5 + 0.5 * urgency))
	var top := 15.0
	var arm := 14.0 + roundf(pulse * 3.0)
	for cv in [Vector2(2, top), Vector2(638, top), Vector2(2, 358), Vector2(638, 358)]:
		var corner: Vector2 = cv
		var sx := 1.0 if corner.x < 320.0 else -1.0
		var sy := 1.0 if corner.y < 180.0 else -1.0
		var ox := corner.x if sx > 0.0 else corner.x - arm
		var oy := corner.y if sy > 0.0 else corner.y - 2.0
		draw_rect(Rect2(ox, oy, arm, 2), c)
		var vx := corner.x if sx > 0.0 else corner.x - 2.0
		var vy := corner.y if sy > 0.0 else corner.y - arm
		draw_rect(Rect2(vx, vy, 2, arm), c)
	var e := Color(c, c.a * 0.4)
	var off := int(_t * 12.0) % 2
	for x in range(off, 640, 2):
		draw_rect(Rect2(x, top, 1, 1), e)
		draw_rect(Rect2(x, 359, 1, 1), e)
	for y in range(int(top) + off, 360, 2):
		draw_rect(Rect2(0, y, 1, 1), e)
		draw_rect(Rect2(639, y, 1, 1), e)


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, 640, 13), Color(K, 0.9))
	draw_rect(Rect2(0, 0, 640, 1), Color(PixelArt.C["K"].lightened(0.25), 0.6))
	draw_rect(Rect2(0, 13, 640, 1), PixelArt.C["K"])
	draw_rect(Rect2(0, 14, 640, 1), Color(0, 0, 0, 0.25))
	# wave + phase
	PixelArt.draw_text_outlined(self, Vector2(6, 4), "WAVE %d" % maxi(GameManager.wave, 0), PixelArt.C["Z"])
	var arena = GameManager.arena
	var phase_txt := ""
	var phase_col := PixelArt.C["W"]
	match GameManager.phase:
		"build":
			if arena:
				var left := int(ceil(arena.build_timer))
				phase_txt = "BUILD PHASE  %d" % left
				if left <= 5 and int(_t * 4.0) % 2 == 0:
					phase_col = PixelArt.C["y"]
		"wave":
			if arena:
				var n: int = arena.enemies.size() + arena.spawner.remaining_to_spawn()
				phase_txt = "RATS LEFT %d" % n
				phase_col = PixelArt.C["z"]
		"draft":
			phase_txt = "VENDING..."
		"gameover":
			phase_txt = "THE SILO FELL"
			phase_col = PixelArt.C["r"]
	PixelArt.draw_text(self, Vector2(52, 4), phase_txt, phase_col)
	# silo bar
	var frac := _silo_frac()
	var col := PixelArt.C["Z"]
	if frac < 0.6:
		col = PixelArt.C["y"]
	if frac < 0.3:
		col = PixelArt.C["r"] if int(_t * 6.0) % 2 == 0 else PixelArt.C["i"]
	if _silo_flash > 0.5:
		col = Color.WHITE
	PixelArt.draw_text_centered(self, Vector2(320, 1), "THE GREAT SILO", PixelArt.C["w"], false)
	_fancy_bar("silo", Rect2(250, 8, 140, 3), frac, col, 14)
	PixelArt.draw_text(self, Vector2(394, 7), "%d%%" % int(ceil(frac * 100.0)), col.lightened(0.2) if frac < 0.3 else PixelArt.C["g"])
	# kills + seeds
	var seed_x := 560.0
	var sb := roundf(sin(_seed_bump * PI) * 3.0)
	draw_texture(PixelArt.tex("seed_icon"), Vector2(seed_x, 2 - sb))
	var seed_col := PixelArt.C["y"] if _seed_bump < 0.5 else PixelArt.C["w"]
	PixelArt.draw_text_outlined(self, Vector2(seed_x + 11, 4 - sb), str(int(roundf(_disp_seeds))), seed_col)
	if _seed_bump > 0.6:
		var sp := Vector2(seed_x + 1, 1 - sb)
		draw_rect(Rect2(sp + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 0.8, _seed_bump))
		draw_rect(Rect2(sp + Vector2(0, -1), Vector2(1, 3)), Color(1, 1, 0.8, _seed_bump))
	var kt := "KILLS %d" % int(roundf(_disp_kills))
	var kx := seed_x - 8 - PixelArt.text_width(kt)
	PixelArt.draw_text(self, Vector2(kx, 4), kt, PixelArt.C["g"])
	# Learning Mode star counter
	var learning := false
	for lv in GameManager.learning_levels:
		if int(lv) > 0:
			learning = true
	if learning:
		var st := str(int(roundf(_disp_stars)))
		var sx := kx - 14 - PixelArt.text_width(st)
		draw_texture(PixelArt.tex("star"), Vector2(sx, 1))
		PixelArt.draw_text_outlined(self, Vector2(sx + 11, 4), st, PixelArt.C["y"])


func _draw_player_panel(p, i: int) -> void:
	var x := 4.0 if i == 0 else 640.0 - PANEL_W - 4.0
	var y := 360.0 - PANEL_H - 4.0
	var col: Color = p.color()
	var border := col.darkened(0.3)
	if p.downed and int(_t * 4.0) % 2 == 0:
		border = PixelArt.C["r"]
	_panel(Rect2(x, y, PANEL_W, PANEL_H), Color(K, 0.86), border)
	# pilot head (cheeks inflate with the pouch) in a little porthole
	var head: Texture2D
	if p.downed or p.wheel.is_spinning():
		head = PixelArt.tex("ham_head_dizzy")
	else:
		head = PixelArt.tex("ham_head_%d" % p.pouch.head_level())
	var hb := roundf(sin(_t * 2.5 + i) * 1.0) if not p.downed else 0.0
	if p.wheel.is_spinning():
		hb = roundf(sin(_t * 30.0) * 1.0)
	PixelArt.draw_disk(self, Vector2(x + 15, y + 21), 10.0, Color(col.darkened(0.6), 0.6))
	draw_texture(head, Vector2(x + 2, y + 10 + hb))
	# name + card pips
	PixelArt.draw_text(self, Vector2(x + 4, y + 3), "P%d %s" % [p.player_id, p.display_name()], col)
	_draw_card_pips(p, Vector2(x + PANEL_W - 4, y + 3))
	if p.downed:
		var dt := "DOWN!"
		if p.revive_progress > 0.0:
			dt = "REVIVING"
		PixelArt.draw_text_outlined(self, Vector2(x + 4, y + 26), dt, PixelArt.C["r"])
	var x0 := x + 30.0
	# HP
	var hp_frac: float = clampf(p.hp / p.max_hp(), 0.0, 1.0)
	var hp_col := PixelArt.C["r"] if hp_frac > 0.3 or int(_t * 6.0) % 2 == 0 else PixelArt.C["I"]
	PixelArt.draw_text(self, Vector2(x0, y + 11), "HP", PixelArt.C["W"])
	_fancy_bar("hp%d" % i, Rect2(x0 + 16, y + 12, 40, 3), hp_frac, hp_col, 10)
	PixelArt.draw_text(self, Vector2(x0 + 59, y + 11), str(int(ceil(p.hp))), PixelArt.C["g"])
	# pouch
	var pf: float = p.pouch.fill()
	var full: bool = p.pouch.is_full()
	var pouch_col := PixelArt.C["c"]
	if full:
		pouch_col = PixelArt.C["y"] if int(_t * 5.0) % 2 == 0 else PixelArt.C["o"]
	PixelArt.draw_text(self, Vector2(x0, y + 18), "PCH", PixelArt.C["W"])
	_fancy_bar("pouch%d" % i, Rect2(x0 + 16, y + 19, 40, 3), pf, pouch_col)
	PixelArt.draw_text(self, Vector2(x0 + 59, y + 18), "FULL" if full else str(p.pouch.amount), pouch_col)
	# heat
	var heat: float = clampf(p.wheel.heat / 100.0, 0.0, 1.0)
	var heat_col := PixelArt.C["i"]
	var heat_label := "HT"
	if p.wheel.is_redline():
		heat_col = PixelArt.C["r"] if int(_t * 8.0) % 2 == 0 else PixelArt.C["I"]
	if p.stats.has_flag("no_overheat"):
		heat_col = PixelArt.C["u"]
	PixelArt.draw_text(self, Vector2(x0, y + 25), heat_label, PixelArt.C["W"])
	_fancy_bar("heat%d" % i, Rect2(x0 + 16, y + 26, 40, 3), heat, heat_col)
	draw_rect(Rect2(x0 + 16 + 40 * 0.8, y + 25, 1, 5), PixelArt.C["w"])
	var heat_tag := ""
	if p.wheel.is_spinning():
		heat_tag = "SPIN"
	elif p.wheel.is_venting():
		heat_tag = "VENT"
	elif p.wheel.is_redline():
		heat_tag = "HOT!"
	elif p.stats.has_flag("no_overheat"):
		heat_tag = "WD40"
	if heat_tag != "":
		PixelArt.draw_text(self, Vector2(x0 + 59, y + 25), heat_tag, heat_col)
	# right column: selected tower + buffs
	var rx := x + 113.0
	draw_rect(Rect2(rx - 3, y + 10, 1, 21), PixelArt.C["K"])
	var kind: String = GameManager.TOWER_TYPES[p.selected_tower]
	var cost := GameManager.tower_cost(kind)
	var afford := GameManager.can_afford(cost)
	PixelArt.draw_text(self, Vector2(rx, y + 11), GameManager.TOWER_INFO[kind]["short"], PixelArt.C["w"] if afford else PixelArt.C["g"])
	draw_texture(PixelArt.tex("seed_icon"), Vector2(rx - 1, y + 16))
	PixelArt.draw_text(self, Vector2(rx + 9, y + 18), str(cost), PixelArt.C["y"] if afford else PixelArt.C["r"])
	var buff := ""
	var bcol := PixelArt.C["w"]
	if p.invert_t > 0.0:
		buff = "INVERT"
		bcol = PixelArt.C["z"]
	elif p.blood_brothers_t > 0.0:
		buff = "BLOOD"
		bcol = PixelArt.C["r"]
	elif p.buddy_active:
		buff = "BUDDY"
		bcol = PixelArt.C["p"]
	if buff != "":
		PixelArt.draw_text(self, Vector2(rx, y + 25), buff, bcol)


## Tiny tier-coloured pips, one per owned card copy, right-aligned at `right_top`.
func _draw_card_pips(p, right_top: Vector2) -> void:
	var pips: Array = []
	for id in p.owned_cards.keys():
		var card: Dictionary = CardDB.get_card(id)
		if card.is_empty():
			continue
		for n in int(p.owned_cards[id]):
			pips.append(CardDB.tier_color(card["tier"]))
	if pips.is_empty():
		return
	var shown := mini(pips.size(), 10)
	var x := right_top.x - shown * 3
	for k in shown:
		var c: Color = pips[k]
		draw_rect(Rect2(x + k * 3, right_top.y, 2, 5), c)
		draw_rect(Rect2(x + k * 3, right_top.y, 2, 1), c.lightened(0.4))
	if pips.size() > shown:
		PixelArt.draw_text(self, Vector2(x - 6, right_top.y), "+", PixelArt.C["w"])


func _draw_boss_bar() -> void:
	var arena = GameManager.arena
	if arena == null or arena.boss == null or not is_instance_valid(arena.boss):
		return
	var b = arena.boss
	var frac: float = clampf(b.hp / b.max_hp, 0.0, 1.0)
	if _last_boss_hp >= 0.0 and b.hp < _last_boss_hp - 0.5:
		_boss_shake = 1.0
	_last_boss_hp = b.hp
	var sh := Vector2(randi_range(-1, 1), 0) * roundf(_boss_shake) if _boss_shake > 0.2 else Vector2.ZERO
	_panel(Rect2(Vector2(212, 15) + sh, Vector2(216, 17)), Color(K, 0.82), PixelArt.C["R"])
	draw_texture(PixelArt.tex("icon_skull"), Vector2(216, 17) + sh)
	draw_texture(PixelArt.tex("icon_skull"), Vector2(417, 17) + sh)
	PixelArt.draw_text_centered(self, Vector2(320, 17) + sh, "RAT-OGRE BRUISER", PixelArt.C["r"], true)
	_fancy_bar("boss", Rect2(Vector2(222, 26) + sh, Vector2(196, 3)), frac,
		PixelArt.C["r"] if int(_t * 3.0) % 4 != 0 or frac > 0.3 else PixelArt.C["I"], 14)


func _draw_phase_hint() -> void:
	if GameManager.phase != "build" or GameManager.arena == null:
		return
	var p = GameManager.players[0] if GameManager.players.size() > 0 else null
	var glyph: String = p.input.glyph("ready") if p else "G"
	var cyc: String = p.input.glyph("cycle") if p else "TAB"
	var t := "WAVE %d IN %d  -  [%s] READY UP   [%s] CYCLE TOWER" % [GameManager.wave + 1, int(ceil(GameManager.arena.build_timer)), glyph, cyc]
	var w := PixelArt.text_width(t) + 10
	draw_rect(Rect2(320 - w / 2.0, 360 - 17, w, 11), Color(K, 0.7))
	PixelArt.draw_text_centered(self, Vector2(320, 360 - 15), t, PixelArt.C["y"])


## Wave banner: slides in with a springy overshoot, holds, then whooshes off to the right.
func _draw_announcement() -> void:
	if _announce_t <= 0.0 or GameManager.phase == "draft" or get_tree().paused:
		return
	var el := 2.8 - _announce_t
	var intro := clampf(el / 0.3, 0.0, 1.0)
	var outro := clampf((0.4 - _announce_t) / 0.4, 0.0, 1.0)
	var u := intro - 1.0
	var e_in := 1.0 + 3.2 * u * u * u + 2.2 * u * u    # easeOutBack
	var slide := (1.0 - e_in) * -360.0 + outro * outro * 420.0
	var sub_slide := (1.0 - clampf((el - 0.08) / 0.3, 0.0, 1.0)) * 360.0 - outro * outro * 420.0
	var a := 1.0 - outro
	var band_h := 46.0 if _announce_sub != "" else 32.0
	var band_y := 112.0
	var band_w := 640.0 * minf(1.0, intro * 1.6)
	var bx := (640.0 - band_w) / 2.0
	draw_rect(Rect2(bx, band_y, band_w, band_h), Color(K, 0.55 * a))
	# hazard-tape stripes along the band edges
	var acc := Color(_announce_col, 0.55 * a)
	var scroll := int(_t * 30.0) % 8
	for x in range(int(bx) - 8 + scroll, int(bx + band_w), 8):
		draw_rect(Rect2(maxf(bx, x), band_y, 4, 2), acc)
		draw_rect(Rect2(maxf(bx, x + 4), band_y + band_h - 2, 4, 2), acc)
	var col := _announce_col
	col.a = a
	var tp := Vector2(320 + slide, band_y + 6)
	# chunky drop shadow, then the outlined headline
	PixelArt.draw_text_centered(self, (tp + Vector2(2, 3)).round(), _announce_text, Color(0.05, 0.03, 0.07, 0.7 * a), false, 18)
	UiText.outlined_centered(self, tp.round(), _announce_text, col, 18)
	if _announce_sub != "":
		var sc := PixelArt.C["w"]
		sc.a = a
		UiText.outlined_centered(self, Vector2(320 + sub_slide, band_y + 31).round(), _announce_sub, sc)
