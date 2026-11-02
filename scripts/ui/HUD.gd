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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# keep redrawing while the tree is paused so frozen-frame leftovers (announcements) clear
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.announce.connect(_on_announce)
	GameManager.silo_changed.connect(_on_silo_changed)
	GameManager.seeds_changed.connect(_on_seeds_changed)
	_last_silo = GameManager.silo_hp
	_last_seeds = GameManager.seeds


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
	if get_tree().paused:
		queue_redraw()
		return
	_t += delta
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


func _silo_frac() -> float:
	return GameManager.silo_hp / maxf(1.0, GameManager.silo_max_hp)


func _draw_danger_vignette() -> void:
	var frac := _silo_frac()
	if frac >= 0.3 or GameManager.phase == "title":
		return
	var pulse := (0.5 + 0.5 * sin(_t * 6.0)) * (1.0 - frac / 0.3)
	for i in 5:
		var c := Color(1.0, 0.15, 0.1, 0.12 * pulse * (1.0 - i / 5.0))
		draw_rect(Rect2(0, 14 + i * 2, 640, 2), c)
		draw_rect(Rect2(0, 358 - i * 2, 640, 2), c)
		draw_rect(Rect2(i * 2, 14, 2, 346), c)
		draw_rect(Rect2(638 - i * 2, 14, 2, 346), c)


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, 640, 13), Color(K, 0.9))
	draw_rect(Rect2(0, 13, 640, 1), PixelArt.C["K"])
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
	PixelArt.draw_bar(self, Rect2(250, 8, 140, 3), frac, col)
	PixelArt.draw_text(self, Vector2(394, 7), "%d%%" % int(ceil(frac * 100.0)), col.lightened(0.2) if frac < 0.3 else PixelArt.C["g"])
	# kills + seeds
	var seed_x := 560.0
	var sb := roundf(_seed_bump * 2.0)
	draw_texture(PixelArt.tex("seed_icon"), Vector2(seed_x, 2 - sb))
	PixelArt.draw_text_outlined(self, Vector2(seed_x + 11, 4 - sb), str(GameManager.seeds), PixelArt.C["y"])
	var kt := "KILLS %d" % GameManager.kills
	var kx := seed_x - 8 - PixelArt.text_width(kt)
	PixelArt.draw_text(self, Vector2(kx, 4), kt, PixelArt.C["g"])
	# Learning Mode star counter
	var learning := false
	for lv in GameManager.learning_levels:
		if int(lv) > 0:
			learning = true
	if learning:
		var st := str(GameManager.math_stars)
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
	PixelArt.draw_box(self, Rect2(x, y, PANEL_W, PANEL_H), Color(K, 0.86), border)
	# pilot head (cheeks inflate with the pouch)
	var head: Texture2D
	if p.downed or p.wheel.is_spinning():
		head = PixelArt.tex("ham_head_dizzy")
	else:
		head = PixelArt.tex("ham_head_%d" % p.pouch.head_level())
	draw_texture(head, Vector2(x + 2, y + 10))
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
	PixelArt.draw_bar(self, Rect2(x0 + 16, y + 12, 40, 3), hp_frac, hp_col)
	PixelArt.draw_text(self, Vector2(x0 + 59, y + 11), str(int(ceil(p.hp))), PixelArt.C["g"])
	# pouch
	var pf: float = p.pouch.fill()
	var full: bool = p.pouch.is_full()
	var pouch_col := PixelArt.C["c"]
	if full:
		pouch_col = PixelArt.C["y"] if int(_t * 5.0) % 2 == 0 else PixelArt.C["o"]
	PixelArt.draw_text(self, Vector2(x0, y + 18), "PCH", PixelArt.C["W"])
	PixelArt.draw_bar(self, Rect2(x0 + 16, y + 19, 40, 3), pf, pouch_col)
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
	PixelArt.draw_bar(self, Rect2(x0 + 16, y + 26, 40, 3), heat, heat_col)
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
	draw_rect(Rect2(214, 15, 212, 15), Color(K, 0.75))
	PixelArt.draw_text_centered(self, Vector2(320, 17), "RAT-OGRE BRUISER", PixelArt.C["r"], true)
	PixelArt.draw_bar(self, Rect2(220, 25, 200, 3), frac, PixelArt.C["r"] if int(_t * 3.0) % 4 != 0 or frac > 0.3 else PixelArt.C["I"])


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


func _draw_announcement() -> void:
	if _announce_t <= 0.0 or GameManager.phase == "draft" or get_tree().paused:
		return
	var a := clampf(_announce_t / 0.4, 0.0, 1.0)
	var intro := clampf((2.8 - _announce_t) / 0.15, 0.0, 1.0)
	var slide := (1.0 - intro) * 20.0
	# backing band for readability
	var band_h := 44.0 if _announce_sub != "" else 30.0
	draw_rect(Rect2(0, 114, 640 * intro, band_h), Color(K, 0.45 * a))
	draw_rect(Rect2(0, 114, 640 * intro, 1), Color(_announce_col, 0.5 * a))
	draw_rect(Rect2(0, 114 + band_h - 1, 640 * intro, 1), Color(_announce_col, 0.5 * a))
	var col := _announce_col
	col.a = a
	PixelArt.draw_text_centered(self, Vector2(320 + slide, 120), _announce_text, col, true, 18)
	if _announce_sub != "":
		var sc := PixelArt.C["w"]
		sc.a = a
		PixelArt.draw_text_centered(self, Vector2(320 - slide, 144), _announce_sub, sc, true)
