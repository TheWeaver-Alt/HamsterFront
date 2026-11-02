class_name HUD
extends Control
## Pixel-font HUD drawn entirely in _draw: title screen, Silo/seed/wave bar,
## per-player panels (HP, cheek pouch, wheel heat, blueprint), banners,
## pause & game-over overlays, and Forbidden-Brie hallucination cats.

const W := 640.0
const H := 360.0

var _banner_title := ""
var _banner_sub := ""
var _banner_t := 0.0
var _banner_max := 1.0
var _t := 0.0
var _cats: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 4:
		_cats.append({"edge": i, "pos": randf_range(0.2, 0.8), "speed": randf_range(0.015, 0.04), "dir": 1.0 if randf() < 0.5 else -1.0, "size": randf_range(26.0, 40.0)})


func show_banner(title: String, sub: String = "", dur: float = 2.5) -> void:
	_banner_title = title.to_upper()
	_banner_sub = sub.to_upper()
	_banner_t = dur
	_banner_max = dur


func _process(delta: float) -> void:
	_t += delta
	_banner_t = maxf(0.0, _banner_t - delta)
	for c in _cats:
		var d: Dictionary = c
		d["pos"] = float(d["pos"]) + float(d["speed"]) * float(d["dir"]) * delta
		if float(d["pos"]) > 0.9 or float(d["pos"]) < 0.1:
			d["dir"] = -float(d["dir"])
	queue_redraw()


func _blink(rate: float = 2.0) -> bool:
	return int(_t * rate * 2.0) % 2 == 0


func _draw() -> void:
	var st := GameManager.state
	if st == GameManager.State.TITLE:
		_draw_title()
		return
	if GameManager.any_player_mod("hallucinations"):
		_draw_cats()
	_draw_top_bar()
	_draw_panel(1, 4.0)
	_draw_panel(2, W - 154.0)
	if st == GameManager.State.PREP and GameManager.wave == 0:
		_draw_quick_help()
	_draw_banner()
	if GameManager.is_paused:
		_draw_pause()
	if st == GameManager.State.GAME_OVER:
		_draw_game_over()


func _bar(x: float, y: float, w: float, h: float, ratio: float, col: Color) -> void:
	draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), Pal.INK)
	draw_rect(Rect2(x, y, w, h), Pal.INK_SOFT)
	draw_rect(Rect2(x, y, roundf(w * clampf(ratio, 0.0, 1.0)), h), col)


func _draw_seed_icon(x: float, y: float) -> void:
	draw_rect(Rect2(x, y, 3, 5), Pal.SEED)
	draw_rect(Rect2(x + 1, y + 1, 1, 3), Pal.SEED_STRIPE)


func _draw_top_bar() -> void:
	draw_rect(Rect2(0, 0, W, 12), Color(Pal.INK, 0.88))
	draw_rect(Rect2(0, 12, W, 1), Pal.INK_SOFT)
	PixelFont.draw_text(self, "WAVE %d" % GameManager.wave, Vector2(5, 4), Pal.WHITE)
	var ratio := GameManager.silo_ratio()
	var col := Pal.HP_GREEN
	if ratio <= 0.5:
		col = Pal.SUNFLOWER
	if ratio <= 0.25:
		col = Pal.WHITE if _blink(3.0) else Pal.BLOOD_BAR
	PixelFont.draw_text(self, "SILO", Vector2(196, 4), Pal.SEED_GOLD)
	_bar(214, 4, 200, 5, ratio, col)
	PixelFont.draw_text(self, "%d" % ceili(GameManager.silo_hp), Vector2(420, 4), Pal.WHITE)
	_draw_seed_icon(574, 3)
	PixelFont.draw_text(self, "%d" % GameManager.seeds, Vector2(580, 4), Pal.SEED_GOLD)
	var info := ""
	var st := GameManager.state
	if st == GameManager.State.PREP:
		info = "NEXT WAVE IN %d  -  G / START: CALL IT NOW" % ceili(GameManager.prep_timer)
	elif st == GameManager.State.WAVE and GameManager.arena != null:
		var left: int = GameManager.arena.rats.size() + GameManager.arena.spawner.remaining()
		info = "RATS INCOMING: %d" % left
	if info != "":
		PixelFont.draw_centered(self, info, Vector2(W / 2.0, 16), Pal.WHITE, 1, Pal.INK)
	PixelFont.draw_text(self, "K:%d" % GameManager.kills, Vector2(60, 4), Pal.RAT_FUR_LIGHT)


func _draw_panel(pid: int, x: float) -> void:
	var y := H - 33.0
	var pcol := Pal.player_color(pid)
	draw_rect(Rect2(x, y, 150, 31), Color(Pal.INK, 0.82))
	draw_rect(Rect2(x, y, 150, 1), pcol)
	if not GameManager.is_joined(pid):
		var msg := "P1: CLICK OR PRESS E" if pid == 1 else "P2: PRESS START / ENTER"
		if _blink(1.5):
			PixelFont.draw_centered(self, msg, Vector2(x + 75, y + 8), pcol)
		PixelFont.draw_centered(self, "TO DROP IN!", Vector2(x + 75, y + 17), Pal.WHITE)
		return
	var arena = GameManager.arena
	if arena == null:
		return
	var m = arena.get_mech(pid)
	if m == null:
		return
	PixelFont.draw_text(self, "P%d %s" % [pid, m.display_name()], Vector2(x + 3, y + 3), pcol)
	var hp_ratio: float = m.hp / maxf(1.0, m.max_hp)
	PixelFont.draw_text(self, "HP", Vector2(x + 3, y + 10), Pal.WHITE)
	_bar(x + 16, y + 11, 60, 3, hp_ratio, Pal.HP_GREEN if hp_ratio > 0.3 else Pal.BLOOD_BAR)
	var fill: float = m.pouch.fill()
	PixelFont.draw_text(self, "CHK", Vector2(x + 3, y + 17), Pal.WHITE)
	var pouch_col := Pal.SEED_GOLD
	if fill >= 1.0 and _blink(3.0):
		pouch_col = Pal.WHITE
	_bar(x + 16, y + 18, 60, 3, fill, pouch_col)
	PixelFont.draw_text(self, "%d/%d" % [m.pouch.held, m.pouch.capacity()], Vector2(x + 79, y + 17), Pal.SEED_GOLD)
	var heat: float = m.wheel.ratio()
	PixelFont.draw_text(self, "WHL", Vector2(x + 3, y + 24), Pal.WHITE)
	var heat_col := Pal.HEAT if m.wheel.is_redline() else Pal.SUNFLOWER
	if GameManager.pmodb(pid, "no_overheat"):
		heat_col = Pal.TESLA
	_bar(x + 16, y + 25, 60, 3, heat, heat_col)
	draw_rect(Rect2(x + 16 + 60 * (WheelHeatComponent.REDLINE / WheelHeatComponent.MAX_HEAT), y + 24, 1, 5), Pal.BLOOD_BAR)
	# Right column: build selection & status.
	var rx := x + 100.0
	var kind: int = m.selected_tower_kind()
	if kind >= 0:
		var cost := GameManager.tower_cost(kind)
		var ok := GameManager.seeds >= cost
		PixelFont.draw_text(self, Defs.tower_short(kind), Vector2(rx, y + 10), Pal.SUNFLOWER)
		PixelFont.draw_text(self, "COST %d" % cost, Vector2(rx, y + 17), Pal.HP_GREEN if ok else Pal.BLOOD_BAR)
		PixelFont.draw_text(self, "R:PLACE" if pid == 1 else "X:PLACE", Vector2(rx, y + 24), Pal.WHITE)
	else:
		PixelFont.draw_text(self, "1-5:BUILD" if pid == 1 else "DPAD:BUILD", Vector2(rx - 6, y + 10), Color(Pal.WHITE, 0.6))
	var status := ""
	var scol := Pal.WHITE
	if m.downed:
		status = "DOWNED!"
		scol = Pal.BLOOD_BAR
	elif m.spin_t > 0.0:
		status = "SPINOUT!"
		scol = Pal.HEAT
	elif m.wheel.is_venting():
		status = "VENTING"
		scol = Pal.STEAM
	elif m.fire_boost_t > 0.0:
		status = "BROS +50%"
		scol = Pal.TIER_COOP
	elif m.wheel.is_redline():
		status = "VENT NOW!"
		scol = Pal.HEAT
	if status != "" and (kind < 0 or m.downed) and _blink(2.5):
		PixelFont.draw_text(self, status, Vector2(rx - 6, y + 18), scol)


func _draw_quick_help() -> void:
	var lines := PackedStringArray([
		"STUFF SEEDS IN YOUR CHEEKS, BANK THEM AT THE SILO, SPEND THEM ON TOWERS.",
		"FULL CHEEKS = SLOW MECH.  CRAM 5+ SEEDS INTO A TOWER FOR A SUGAR RUSH.",
		"SPRINTING HEATS THE WHEEL - VENT STEAM OR SPIN OUT!",
	])
	var y := 26.0
	draw_rect(Rect2(W / 2.0 - 150, y - 3, 300, lines.size() * 8 + 4), Color(Pal.INK, 0.7))
	for l in lines:
		PixelFont.draw_centered(self, l, Vector2(W / 2.0, y), Pal.WHITE)
		y += 8.0


func _draw_banner() -> void:
	if _banner_t <= 0.0 or _banner_title == "":
		return
	var a := clampf(_banner_t / 0.4, 0.0, 1.0)
	var intro := clampf((_banner_max - _banner_t) / 0.15, 0.0, 1.0)
	var y := 62.0 - (1.0 - intro) * 10.0
	PixelFont.draw_centered(self, _banner_title, Vector2(W / 2.0, y), Color(Pal.SUNFLOWER, a), 2, Color(Pal.INK, a))
	if _banner_sub != "":
		PixelFont.draw_centered(self, _banner_sub, Vector2(W / 2.0, y + 16), Color(Pal.WHITE, a), 1, Color(Pal.INK, a))


func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	PixelFont.draw_centered(self, "PAUSED", Vector2(W / 2.0, 140), Pal.WHITE, 4, Pal.INK)
	PixelFont.draw_centered(self, "ESC / BACK TO RESUME", Vector2(W / 2.0, 172), Pal.SUNFLOWER, 1, Pal.INK)


func _draw_game_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	PixelFont.draw_centered(self, "THE STRIPED SEEDS ARE LOST!", Vector2(W / 2.0, 110), Pal.WARP, 3, Pal.INK)
	PixelFont.draw_centered(self, "THE UNDER-SCURRIERS FEAST IN THE NAME OF THE GREAT HORNED GOUDA", Vector2(W / 2.0, 136), Pal.WHITE, 1, Pal.INK)
	var survived := maxi(0, GameManager.wave - 1)
	PixelFont.draw_centered(self, "WAVES SURVIVED: %d" % survived, Vector2(W / 2.0, 156), Pal.SUNFLOWER, 2, Pal.INK)
	PixelFont.draw_centered(self, "RATS SQUASHED: %d    SEEDS BANKED: %d" % [GameManager.kills, GameManager.seeds_banked_total], Vector2(W / 2.0, 176), Pal.WHITE, 1, Pal.INK)
	if _blink(1.5):
		PixelFont.draw_centered(self, "PRESS E / CLICK / ENTER / START TO RETRY", Vector2(W / 2.0, 200), Pal.SEED_GOLD, 1, Pal.INK)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(Pal.INK, 0.72))
	var bob := roundf(sin(_t * 2.0) * 2.0)
	PixelFont.draw_centered(self, "DEFENCE OF", Vector2(W / 2.0, 30 + bob), Pal.WHITE, 2, Pal.INK)
	PixelFont.draw_centered(self, "HAMSTERFRONT", Vector2(W / 2.0, 48 + bob), Pal.HAMSTER, 5, Pal.WARP_DARK)
	PixelFont.draw_centered(self, "MECH-POUCH PROTOCOL", Vector2(W / 2.0, 82), Pal.SUGAR, 2, Pal.INK)
	PixelFont.draw_centered(self, "THE UNDER-SCURRIERS WANT THE GREAT SILO. SHOW THEM THE CHEEK.", Vector2(W / 2.0, 102), Pal.WHITE)
	var p1 := PackedStringArray([
		"P1  BRAWLER-01  (KEYBOARD + MOUSE)",
		"WASD MOVE      MOUSE AIM",
		"LMB SHOTGUN    RMB TUBE FIST",
		"SHIFT SPRINT   SPACE VENT STEAM",
		"E BANK / CRAM  F SPIT CHEEKS",
		"1-5 / Q / Z BLUEPRINT  R PLACE",
	])
	var p2 := PackedStringArray([
		"P2  WHEELER-X  (GAMEPAD)",
		"L-STICK MOVE   R-STICK AIM",
		"RT RAILGUNS    LT TURBO DASH",
		"LB SPRINT      B VENT STEAM",
		"A BANK / CRAM  Y SPIT CHEEKS",
		"DPAD BLUEPRINT X PLACE",
		"KEYS: ARROWS / . ' ; ENTER \\ [ ] P",
	])
	_draw_block(p1, 40.0, 124.0, Pal.P1)
	_draw_block(p2, 340.0, 124.0, Pal.P2)
	if _blink(1.2):
		PixelFont.draw_centered(self, "P1: CLICK OR PRESS E TO START", Vector2(W / 2.0 - 150, 210), Pal.P1, 1, Pal.INK)
		PixelFont.draw_centered(self, "P2: PRESS START OR ENTER", Vector2(W / 2.0 + 150, 210), Pal.P2, 1, Pal.INK)
	PixelFont.draw_centered(self, "THE OTHER HAMSTER CAN DROP IN ANY TIME", Vector2(W / 2.0, 224), Pal.WHITE)
	PixelFont.draw_centered(self, "G / START: CALL NEXT WAVE EARLY     ESC / BACK: PAUSE", Vector2(W / 2.0, 340), Color(Pal.WHITE, 0.7))


func _draw_block(lines: PackedStringArray, x: float, y: float, col: Color) -> void:
	draw_rect(Rect2(x - 6, y - 5, 272, lines.size() * 9 + 8), Color(Pal.INK, 0.8))
	draw_rect(Rect2(x - 6, y - 5, 272, 1), col)
	var yy := y
	for i in lines.size():
		PixelFont.draw_text(self, lines[i], Vector2(x, yy), col if i == 0 else Pal.WHITE)
		yy += 9.0


func _draw_cats() -> void:
	for c in _cats:
		var d: Dictionary = c
		var edge: int = d["edge"]
		var t: float = d["pos"]
		var s: float = d["size"]
		var center := Vector2.ZERO
		var rot := 0.0
		match edge:
			0:
				center = Vector2(t * W, 6.0)
				rot = PI
			1:
				center = Vector2(W - 6.0, t * H)
				rot = -PI * 0.5
			2:
				center = Vector2(t * W, H - 6.0)
				rot = 0.0
			_:
				center = Vector2(6.0, t * H)
				rot = PI * 0.5
		var pulse := 0.4 + 0.15 * sin(_t * 1.3 + edge)
		draw_set_transform(center, rot, Vector2.ONE)
		var shade := Color(0.02, 0.0, 0.05, pulse)
		draw_circle(Vector2(0, -s * 0.2), s * 0.6, shade)
		draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.55, -s * 0.45), Vector2(-s * 0.2, -s * 0.75), Vector2(-s * 0.5, -s * 1.05)]), shade)
		draw_colored_polygon(PackedVector2Array([Vector2(s * 0.55, -s * 0.45), Vector2(s * 0.2, -s * 0.75), Vector2(s * 0.5, -s * 1.05)]), shade)
		var blink := fmod(_t + edge * 1.7, 4.0) < 0.15
		if not blink:
			var eye := Color(1.0, 0.85, 0.2, pulse + 0.35)
			draw_rect(Rect2(-s * 0.3, -s * 0.35, 4, 2), eye)
			draw_rect(Rect2(s * 0.3 - 4, -s * 0.35, 4, 2), eye)
			draw_rect(Rect2(-s * 0.3 + 1, -s * 0.35, 1, 2), Pal.INK)
			draw_rect(Rect2(s * 0.3 - 3, -s * 0.35, 1, 2), Pal.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
