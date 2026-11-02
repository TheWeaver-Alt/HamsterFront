class_name PixelFont
extends RefCounted
## A tiny 3x5 procedural pixel font rendered with draw_rect.
## No font assets needed; scales by integer factors to stay crisp.

const GLYPH_W := 3
const GLYPH_H := 5
const ADVANCE := 4
const LINE_H := 7

# Each glyph: five rows of three pixels, '#' = ink.
const SRC := {
	"A": ".#. #.# ### #.# #.#",
	"B": "##. #.# ##. #.# ##.",
	"C": ".## #.. #.. #.. .##",
	"D": "##. #.# #.# #.# ##.",
	"E": "### #.. ##. #.. ###",
	"F": "### #.. ##. #.. #..",
	"G": ".## #.. #.# #.# .##",
	"H": "#.# #.# ### #.# #.#",
	"I": "### .#. .#. .#. ###",
	"J": "..# ..# ..# #.# .#.",
	"K": "#.# #.# ##. #.# #.#",
	"L": "#.. #.. #.. #.. ###",
	"M": "#.# ### ### #.# #.#",
	"N": "##. #.# #.# #.# #.#",
	"O": ".#. #.# #.# #.# .#.",
	"P": "##. #.# ##. #.. #..",
	"Q": ".#. #.# #.# ### .##",
	"R": "##. #.# ##. #.# #.#",
	"S": ".## #.. .#. ..# ##.",
	"T": "### .#. .#. .#. .#.",
	"U": "#.# #.# #.# #.# ###",
	"V": "#.# #.# #.# .#. .#.",
	"W": "#.# #.# ### ### #.#",
	"X": "#.# #.# .#. #.# #.#",
	"Y": "#.# #.# .#. .#. .#.",
	"Z": "### ..# .#. #.. ###",
	"0": "### #.# #.# #.# ###",
	"1": ".#. ##. .#. .#. ###",
	"2": "##. ..# .#. #.. ###",
	"3": "##. ..# .#. ..# ##.",
	"4": "#.# #.# ### ..# ..#",
	"5": "### #.. ##. ..# ##.",
	"6": ".## #.. ### #.# ###",
	"7": "### ..# .#. .#. .#.",
	"8": "### #.# ### #.# ###",
	"9": "### #.# ### ..# ##.",
	"!": ".#. .#. .#. ... .#.",
	"?": "##. ..# .#. ... .#.",
	".": "... ... ... ... .#.",
	",": "... ... ... .#. #..",
	"'": ".#. .#. ... ... ...",
	"\"": "#.# #.# ... ... ...",
	"-": "... ... ### ... ...",
	"+": "... .#. ### .#. ...",
	":": "... .#. ... .#. ...",
	";": "... .#. ... .#. #..",
	"/": "..# ..# .#. #.. #..",
	"(": ".#. #.. #.. #.. .#.",
	")": ".#. ..# ..# ..# .#.",
	"[": "##. #.. #.. #.. ##.",
	"]": ".## ..# ..# ..# .##",
	"%": "#.# ..# .#. #.. #.#",
	"=": "... ### ... ### ...",
	">": "#.. .#. ..# .#. #..",
	"<": "..# .#. #.. .#. ..#",
	"*": "... #.# .#. #.# ...",
	"#": "#.# ### #.# ### #.#",
	"_": "... ... ... ... ###",
	"@": "### #.# ##. #.. .##",
	"&": ".#. #.# .#. #.# .##",
	"$": ".## ##. .#. .## ##.",
	"^": ".#. #.# ... ... ...",
}

static var _cache: Dictionary = {}


## Returns an Array of Rect2i runs for a character (upper-cased).
static func _glyph(ch: String) -> Array:
	if _cache.has(ch):
		return _cache[ch]
	var runs: Array = []
	var key := ch.to_upper()
	if SRC.has(key):
		var bits: String = String(SRC[key]).replace(" ", "")
		for row in GLYPH_H:
			var start := -1
			for col in GLYPH_W + 1:
				var on := false
				if col < GLYPH_W:
					on = bits[row * GLYPH_W + col] == "#"
				if on and start < 0:
					start = col
				elif not on and start >= 0:
					runs.append(Rect2i(start, row, col - start, 1))
					start = -1
	_cache[ch] = runs
	return runs


static func text_width(text: String, s: int = 1) -> int:
	if text.is_empty():
		return 0
	return (text.length() * ADVANCE - 1) * s


static func draw_text(ci: CanvasItem, text: String, pos: Vector2, color: Color, s: int = 1, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var origin := Vector2(floorf(pos.x), floorf(pos.y))
	if shadow.a > 0.0:
		_draw_raw(ci, text, origin + Vector2(s, s), shadow, s)
	_draw_raw(ci, text, origin, color, s)


static func _draw_raw(ci: CanvasItem, text: String, origin: Vector2, color: Color, s: int) -> void:
	var x := origin.x
	for i in text.length():
		var ch := text[i]
		if ch != " ":
			for r in _glyph(ch):
				var rr: Rect2i = r
				ci.draw_rect(Rect2(x + rr.position.x * s, origin.y + rr.position.y * s, rr.size.x * s, rr.size.y * s), color)
		x += ADVANCE * s


## Draws text horizontally centred on pos.x, with pos.y as the top.
static func draw_centered(ci: CanvasItem, text: String, pos: Vector2, color: Color, s: int = 1, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var w := text_width(text, s)
	draw_text(ci, text, Vector2(pos.x - w / 2.0, pos.y), color, s, shadow)


## Greedy word wrap into lines no wider than max_w pixels.
static func wrap_text(text: String, max_w: int, s: int = 1) -> PackedStringArray:
	var lines := PackedStringArray()
	var max_chars := maxi(1, int((max_w + s) / float(ADVANCE * s)))
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var w: String = word
			while w.length() > max_chars:
				if not line.is_empty():
					lines.append(line)
					line = ""
				lines.append(w.substr(0, max_chars))
				w = w.substr(max_chars)
			if line.is_empty():
				line = w
			elif line.length() + 1 + w.length() <= max_chars:
				line += " " + w
			else:
				lines.append(line)
				line = w
		lines.append(line)
	return lines


static func draw_lines(ci: CanvasItem, lines: PackedStringArray, pos: Vector2, color: Color, s: int = 1, centered: bool = false, shadow: Color = Color(0, 0, 0, 0)) -> void:
	var y := pos.y
	for line in lines:
		if centered:
			draw_centered(ci, line, Vector2(pos.x, y), color, s, shadow)
		else:
			draw_text(ci, line, Vector2(pos.x, y), color, s, shadow)
		y += LINE_H * s
