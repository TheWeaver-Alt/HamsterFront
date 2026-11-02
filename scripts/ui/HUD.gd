extends Control
## Pixel HUD drawn entirely in _draw(): wave/phase, Silo HP, banked seeds, per-player panels
## (HP, cheek pouch, wheel heat, selected tower), boss bar and centre announcements.

const K := Color8(26, 16, 32)

var _announce_text := ""
var _announce_sub := ""
var _announce_col := Color.WHITE
var _announce_t := 0.0
var _silo_flash := 0.0
var _last_silo := 0.0
var _seed_bump := 0.0
var _last_seeds := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.announce.connect(_on_announce)
	GameManager.silo_changed.connect(func(hp, _m):
		if hp < _last_silo:
			_silo_flash = 1.0
		_last_silo = hp)
	GameManager.seeds_changed.connect(func(n):
		if n > _last_seeds:
			_seed_bump = 1.0
		_last_seeds = n)
	_last_silo = GameManager.silo_hp
	_last_seeds = GameManager.seeds


func _on_announce(text: String, sub: String, col: Color) -> void:
	_announce_text = text
	_announce_sub = sub
	_announce_col = col
	_announce_t = 2.8


func _process(delta: float) -> void:
	_announce_t = maxf(0.0, _announce_t - delta)
	_silo_flash = maxf(0.0, _silo_flash - delta * 4.0)
	_seed_bump = maxf(0.0, _seed_bump - delta * 5.0)
	queue_redraw()


func _draw() -> void:
	_draw_top_bar()
	var i := 0
	for p in GameManager.players:
		if is_instance_valid(p):
			_draw_player_panel(p, i)
		i += 1
	_draw_boss_bar()
	_draw_phase_hint()
	_draw_announcement()


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, 640, 13), Color(K, 0.88))
	draw_rect(Rect2(0, 13, 640, 1), PixelArt.C["K"])
	# wave + phase
	var wave_txt := "WAVE %d" % maxi(GameManager.wave, 0)
	PixelArt.draw_text_outlined(self, Vector2(6, 4), wave_txt, PixelArt.C["Z"])
	var arena = GameManager.arena
	var phase_txt := ""
	match GameManager.phase:
		"build":
			if arena:
				phase_txt = "BUILD  %d" % int(ceil(arena.build_timer))
		"wave":
			if arena:
				var left: int = arena.enemies.size() + arena.spawner.remaining_to_spawn()
				phase_txt = "RATS LEFT %d" % left
		"draft":
			phase_txt = "VENDING..."
	PixelArt.draw_text(self, Vector2(52, 4), phase_txt, PixelArt.C["W"])
	# silo bar
	var frac := GameManager.silo_hp / maxf(1.0, GameManager.silo_max_hp)
	var col := PixelArt.C["Z"]
	if frac < 0.6:
		col = PixelArt.C["y"]
	if frac < 0.3:
		col = PixelArt.C["r"]
	if _silo_flash > 0.5:
		col = Color.WHITE
	PixelArt.draw_text_centered(self, Vector2(320, 1), "THE GREAT SILO", PixelArt.C["w"], false)
	PixelArt.draw_bar(self, Rect2(250, 8, 140, 3), frac, col)
	# seeds
	var seed_x := 560.0
	draw_texture(PixelArt.tex("seed_icon"), Vector2(seed_x, 2 - _seed_bump * 2.0))
	PixelArt.draw_text_outlined(self, Vector2(seed_x + 11, 4 - _seed_bump * 2.0), str(GameManager.seeds), PixelArt.C["y"])
	PixelArt.draw_text(self, Vector2(seed_x - 46, 4), "KILLS %d" % GameManager.kills, PixelArt.C["g"])


func _draw_player_panel(p, i: int) -> void:
	var w := 132.0
	var h := 34.0
	var x := 4.0 if i == 0 else 640.0 - w - 4.0
	var y := 360.0 - h - 4.0
	var col: Color = p.color()
	PixelArt.draw_box(self, Rect2(x, y, w, h), Color(K, 0.85), col.darkened(0.3))
	var name_txt: String = "P%d %s" % [p.player_id, p.display_name()]
	PixelArt.draw_text(self, Vector2(x + 4, y + 3), name_txt, col)
	if p.downed:
		PixelArt.draw_text(self, Vector2(x + w - 30, y + 3), "DOWN", PixelArt.C["r"])
	# HP
	var hp_frac: float = p.hp / p.max_hp()
	PixelArt.draw_text(self, Vector2(x + 4, y + 11), "HP", PixelArt.C["W"])
	PixelArt.draw_bar(self, Rect2(x + 16, y + 12, 50, 3), hp_frac, PixelArt.C["r"])
	# pouch
	var pf: float = p.pouch.fill()
	var pouch_col := PixelArt.C["c"] if pf < 1.0 else PixelArt.C["y"]
	PixelArt.draw_text(self, Vector2(x + 70, y + 11), "PCH", PixelArt.C["W"])
	PixelArt.draw_bar(self, Rect2(x + 86, y + 12, 32, 3), pf, pouch_col)
	PixelArt.draw_text(self, Vector2(x + 120, y + 11), str(p.pouch.amount), pouch_col)
	# heat
	var heat: float = p.wheel.heat / 100.0
	var heat_col := PixelArt.C["i"]
	var heat_label := "HEAT"
	if p.wheel.is_redline():
		heat_col = PixelArt.C["r"] if int(Time.get_ticks_msec() / 120) % 2 == 0 else PixelArt.C["I"]
		heat_label = "REDLN"
	if p.wheel.is_spinning():
		heat_label = "SPIN!"
	if p.stats.has_flag("no_overheat"):
		heat_label = "WD40"
		heat_col = PixelArt.C["u"]
	PixelArt.draw_text(self, Vector2(x + 4, y + 19), heat_label, PixelArt.C["W"])
	PixelArt.draw_bar(self, Rect2(x + 26, y + 20, 40, 3), heat, heat_col)
	draw_rect(Rect2(x + 26 + 40 * 0.8, y + 19, 1, 5), PixelArt.C["w"])
	# selected tower
	var kind: String = GameManager.TOWER_TYPES[p.selected_tower]
	var cost := GameManager.tower_cost(kind)
	var tcol := PixelArt.C["w"] if GameManager.can_afford(cost) else PixelArt.C["g"]
	PixelArt.draw_text(self, Vector2(x + 70, y + 19), "%s %d" % [GameManager.TOWER_INFO[kind]["short"], cost], tcol)
	# buffs
	var bx := x + 4.0
	var buffs: Array = []
	if p.buddy_active:
		buffs.append(["BUDDY", PixelArt.C["p"]])
	if p.blood_brothers_t > 0.0:
		buffs.append(["BLOOD", PixelArt.C["r"]])
	if p.invert_t > 0.0:
		buffs.append(["INVERTED", PixelArt.C["z"]])
	for b in buffs:
		PixelArt.draw_text(self, Vector2(bx, y + 27), b[0], b[1])
		bx += PixelArt.text_width(b[0]) + 4


func _draw_boss_bar() -> void:
	var arena = GameManager.arena
	if arena == null or arena.boss == null or not is_instance_valid(arena.boss):
		return
	var b = arena.boss
	var frac: float = b.hp / b.max_hp
	PixelArt.draw_text_centered(self, Vector2(320, 17), "RAT-OGRE BRUISER", PixelArt.C["r"])
	PixelArt.draw_bar(self, Rect2(220, 24, 200, 3), frac, PixelArt.C["r"])


func _draw_phase_hint() -> void:
	if GameManager.phase != "build" or GameManager.arena == null:
		return
	var p = GameManager.players[0] if GameManager.players.size() > 0 else null
	var glyph: String = p.input.glyph("ready") if p else "G"
	var t := "WAVE %d IN %d  -  [%s] READY UP" % [GameManager.wave + 1, int(ceil(GameManager.arena.build_timer)), glyph]
	PixelArt.draw_text_centered(self, Vector2(320, 360 - 14), t, PixelArt.C["y"])


func _draw_announcement() -> void:
	if _announce_t <= 0.0:
		return
	var a := clampf(_announce_t / 0.4, 0.0, 1.0)
	var slide := (1.0 - clampf((2.8 - _announce_t) / 0.15, 0.0, 1.0)) * 20.0
	var col := _announce_col
	col.a = a
	PixelArt.draw_text_centered(self, Vector2(320 + slide, 120), _announce_text, col, true, 18)
	if _announce_sub != "":
		var sc := PixelArt.C["w"]
		sc.a = a
		PixelArt.draw_text_centered(self, Vector2(320 - slide, 144), _announce_sub, sc, true)
