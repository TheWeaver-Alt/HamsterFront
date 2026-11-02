extends Control
## End-of-wave Card Draft. Time freezes (tree paused, this UI processes ALWAYS).
## Each player gets their own hand of 3 cards, navigates with left/right and confirms.
## CONTRACT (used by MainArena): open(players: Array) shows the draft; emit `finished`
## once every player has picked and CardDB.apply_card() has been called for each pick.

signal finished

var players: Array = []
var hands: Array = []        # per player: Array of card dicts
var cursor: Array = []       # per player: int
var picked: Array = []       # per player: bool
var _t := 0.0
var _closing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(pls: Array) -> void:
	players = []
	for p in pls:
		if is_instance_valid(p):
			players.append(p)
	hands.clear()
	cursor.clear()
	picked.clear()
	var offered: Array = []
	for p in players:
		var hand: Array = CardDB.roll_hand(p, 3, offered)
		for c in hand:
			offered.append(c["id"])
		hands.append(hand)
		cursor.append(1)
		picked.append(hand.is_empty())
		p.input.consume()
	_t = 0.0
	_closing = false
	visible = true
	Sfx.play("vend_drop")
	JuiceManager.add_trauma(0.5)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t > 0.6 and not _closing:
		for i in players.size():
			if picked[i]:
				continue
			var inp: PlayerInput = players[i].input
			inp.update(players[i])
			if inp.just("left"):
				cursor[i] = (cursor[i] + hands[i].size() - 1) % hands[i].size()
				Sfx.play("select")
			if inp.just("right"):
				cursor[i] = (cursor[i] + 1) % hands[i].size()
				Sfx.play("select")
			if inp.just("confirm") or inp.just("fire") or inp.just("interact"):
				picked[i] = true
				CardDB.apply_card(hands[i][cursor[i]], players[i])
				Sfx.play("card")
		var all := true
		for b in picked:
			if not b:
				all = false
		if all:
			_closing = true
			_close_soon()
	queue_redraw()


func _close_soon() -> void:
	await get_tree().create_timer(0.5, true, false, true).timeout
	visible = false
	for p in players:
		if is_instance_valid(p):
			p.input.consume()
	finished.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.03, 0.08, 0.75))
	PixelArt.draw_text_centered(self, Vector2(320, 20), "VENDING MACHINE OF DESTINY", PixelArt.C["y"], true, 12)
	PixelArt.draw_text_centered(self, Vector2(320, 38), "PICK 1 CARD", PixelArt.C["w"])
	var n := players.size()
	for i in n:
		var cx := 320.0 if n == 1 else (165.0 if i == 0 else 475.0)
		var p = players[i]
		PixelArt.draw_text_centered(self, Vector2(cx, 56), "P%d %s" % [p.player_id, p.display_name()], p.color())
		var hand: Array = hands[i]
		for k in hand.size():
			var card: Dictionary = hand[k]
			var w := 92.0
			var h := 120.0
			var x := cx + (k - 1) * (w + 6) - w / 2.0
			var y := 70.0
			if k == cursor[i] and not picked[i]:
				y -= 6
			var tier_col := CardDB.tier_color(card["tier"])
			var dim: bool = picked[i] and k != cursor[i]
			var fill := Color8(255, 248, 231) if not dim else Color8(120, 110, 110)
			PixelArt.draw_box(self, Rect2(x, y, w, h), fill, tier_col if k == cursor[i] else PixelArt.C["k"])
			draw_rect(Rect2(x + 2, y + 2, w - 4, 10), tier_col)
			PixelArt.draw_text(self, Vector2(x + 4, y + 4), CardDB.TIER_NAMES[card["tier"]], PixelArt.C["k"])
			_wrap(Vector2(x + 4, y + 16), card["name"], w - 8, PixelArt.C["k"])
			_wrap(Vector2(x + 4, y + 44), card["desc"], w - 8, PixelArt.C["K"])
			if card.has("downside"):
				_wrap(Vector2(x + 4, y + 82), "BUT: " + card["downside"], w - 8, PixelArt.C["x"])
		if picked[i]:
			PixelArt.draw_text_centered(self, Vector2(cx, 200), "PICKED!", PixelArt.C["Z"], true, 12)


func _wrap(pos: Vector2, text: String, width: float, col: Color) -> void:
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
