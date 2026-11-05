extends Node
## PixelArt — procedural pixel-art factory.
##
## * Holds the shared 16-bit palette (`C`).
## * Raster helpers that paint into `Image`s (disks, rects, lines, auto-outline).
## * Builds and caches textures by name. Sprite painters live in scripts/art/*.gd,
##   each exposing `static func make(name: String) -> Image` (return null if unknown).
## * Builds the 3x5 bitmap pixel font used everywhere (`font`, size 6).
## * Canvas drawing helpers for crisp pixel text, disks and bars.

const FONT_SIZE := 6

const C := {
	"k": Color8(26, 16, 32),      # outline / near-black
	"K": Color8(52, 36, 60),      # shadow purple
	"w": Color8(255, 248, 231),   # cream white
	"W": Color8(214, 222, 230),   # light grey / chrome
	"g": Color8(140, 152, 170),   # grey
	"G": Color8(84, 92, 112),     # dark grey
	"r": Color8(226, 64, 64),     # red
	"R": Color8(150, 32, 48),     # dark red
	"o": Color8(244, 150, 70),    # hamster orange
	"O": Color8(184, 96, 44),     # dark orange
	"c": Color8(255, 222, 170),   # cream fur
	"p": Color8(255, 150, 180),   # pink
	"P": Color8(200, 90, 130),    # dark pink
	"y": Color8(255, 214, 64),    # yellow
	"Y": Color8(214, 150, 30),    # dark yellow
	"t": Color8(210, 168, 110),   # cardboard
	"T": Color8(150, 110, 64),    # dark cardboard
	"b": Color8(120, 72, 40),     # wood
	"B": Color8(76, 44, 28),      # dark wood
	"a": Color8(150, 220, 255),   # glass light
	"A": Color8(70, 140, 210),    # blue
	"n": Color8(36, 70, 140),     # navy
	"e": Color8(120, 200, 90),    # grass light
	"E": Color8(72, 152, 64),     # grass
	"f": Color8(44, 104, 56),     # grass dark
	"z": Color8(170, 255, 100),   # warp green bright
	"Z": Color8(70, 210, 60),     # warp green
	"x": Color8(24, 110, 50),     # warp dark
	"m": Color8(132, 112, 134),   # rat fur
	"M": Color8(86, 70, 98),      # rat fur dark
	"q": Color8(230, 140, 160),   # rat tail pink
	"s": Color8(46, 42, 48),      # seed dark
	"S": Color8(236, 232, 214),   # seed stripe
	"v": Color8(180, 110, 230),   # corruption purple
	"V": Color8(100, 50, 150),    # dark purple
	"h": Color8(160, 152, 140),   # stone
	"H": Color8(112, 106, 100),   # stone dark
	"l": Color8(200, 192, 178),   # stone light
	"u": Color8(90, 200, 230),    # cyan
	"i": Color8(255, 120, 40),    # fire orange
	"I": Color8(255, 240, 120),   # fire hot
}

# 5-row glyphs, rows top->bottom, "1" = ink. Width = len/5 (3 by default; M/N/W are wider).
const GLYPHS := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011",
	"D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
	"G": "011100101101011", "H": "101101111101101", "I": "111010010010111",
	"J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "1000111011101011000110001", "N": "10011101101110011001", "O": "010101101101010",
	"P": "110101110100100", "Q": "010101101110011", "R": "110101110101101",
	"S": "011100010001110", "T": "111010010010010", "U": "101101101101111",
	"V": "101101101101010", "W": "1000110001101011101110001", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111",
	"0": "111101101101111", "1": "010110010010111", "2": "110001010100111",
	"3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
	"6": "011100111101111", "7": "111001010010010", "8": "111101111101111",
	"9": "111101111001110",
	"!": "010010010000010", "?": "110001010000010", ".": "000000000000010",
	",": "000000000010100", "'": "010010000000000", "\"": "101101000000000",
	"-": "000000111000000", "+": "000010111010000", ":": "000010000010000",
	";": "000010000010100", "/": "001001010100100", "\\": "100100010001001",
	"%": "101001010100101", "(": "010100100100010", ")": "010001001001010",
	"[": "110100100100110", "]": "011001001001011", "#": "101111101111101",
	"@": "111101111100011", "&": "010101010101011", "*": "000101010101000",
	"=": "000111000111000", "<": "001010100010001", ">": "100010001010100",
	"_": "000000000000111", "$": "011110010011110", "^": "010101000000000",
	"~": "000000011110000", "|": "010010010010010", " ": "000000000000000",
	"{": "010111111111010", "}": "010111010111010",
}

var font: FontFile
var theme: Theme
var _cache: Dictionary = {}
var _painters: Array = []
var _hit_flash_shader: Shader


func _ready() -> void:
	_build_font()
	_build_theme()
	_painters = [
		load("res://scripts/art/TileArt.gd"),
		load("res://scripts/art/MechArt.gd"),
		load("res://scripts/art/RatArt.gd"),
		load("res://scripts/art/TowerArt.gd"),
		load("res://scripts/art/MiscArt.gd"),
		load("res://scripts/art/UIArt.gd"),
		load("res://scripts/art/CardArt.gd"),
	]
	_hit_flash_shader = load("res://shaders/hit_flash.gdshader")


# ------------------------------------------------------------------ textures

## Returns a cached ImageTexture for a named procedural sprite.
func tex(sprite_name: String) -> Texture2D:
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var img: Image = null
	for p in _painters:
		if p == null:
			continue
		img = p.make(sprite_name)
		if img != null:
			break
	if img == null:
		push_warning("PixelArt: unknown sprite '%s'" % sprite_name)
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	var t := ImageTexture.create_from_image(img)
	_cache[sprite_name] = t
	return t


## Register an externally-built image under a name (e.g. tile atlas).
func put(sprite_name: String, img: Image) -> Texture2D:
	var t := ImageTexture.create_from_image(img)
	_cache[sprite_name] = t
	return t


func has_tex(sprite_name: String) -> bool:
	return _cache.has(sprite_name)


## A fresh ShaderMaterial using the hit-flash shader (one per entity).
func make_flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _hit_flash_shader
	m.set_shader_parameter("flash", 0.0)
	m.set_shader_parameter("flash_color", Color(1, 1, 1, 1))
	return m


# ------------------------------------------------------------------ raster helpers (static)

static func col(key: String) -> Color:
	return C.get(key, Color.MAGENTA)


static func new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(img, xx, yy, c)


static func disk(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	var r2 := r * r
	for yy in range(int(floorf(cy - r - 1)), int(ceilf(cy + r + 1)) + 1):
		for xx in range(int(floorf(cx - r - 1)), int(ceilf(cx + r + 1)) + 1):
			var dx := xx + 0.5 - cx
			var dy := yy + 0.5 - cy
			if dx * dx + dy * dy <= r2:
				px(img, xx, yy, c)


static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(floorf(cy - ry - 1)), int(ceilf(cy + ry + 1)) + 1):
		for xx in range(int(floorf(cx - rx - 1)), int(ceilf(cx + rx + 1)) + 1):
			var dx := (xx + 0.5 - cx) / maxf(rx, 0.01)
			var dy := (yy + 0.5 - cy) / maxf(ry, 0.01)
			if dx * dx + dy * dy <= 1.0:
				px(img, xx, yy, c)


static func ring(img: Image, cx: float, cy: float, r: float, thickness: float, c: Color) -> void:
	var ro := r * r
	var ri := maxf(r - thickness, 0.0)
	ri *= ri
	for yy in range(int(floorf(cy - r - 1)), int(ceilf(cy + r + 1)) + 1):
		for xx in range(int(floorf(cx - r - 1)), int(ceilf(cx + r + 1)) + 1):
			var dx := xx + 0.5 - cx
			var dy := yy + 0.5 - cy
			var d := dx * dx + dy * dy
			if d <= ro and d >= ri:
				px(img, xx, yy, c)


static func line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		px(img, x, y, c)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## Adds a 1px outline (4-neighbour) around all opaque pixels.
static func outline(img: Image, c: Color = Color8(26, 16, 32)) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			var hit := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.1:
					hit = true
					break
			if hit:
				img.set_pixel(x, y, c)
	return img


## Darkens opaque pixels whose lower-right neighbour is transparent (cheap form shading).
static func shade_edges(img: Image, amount: float = 0.25) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			var p := src.get_pixel(x, y)
			if p.a < 0.1:
				continue
			var edge := false
			if x + 1 >= w or src.get_pixel(x + 1, y).a < 0.1:
				edge = true
			elif y + 1 >= h or src.get_pixel(x, y + 1).a < 0.1:
				edge = true
			if edge:
				img.set_pixel(x, y, p.darkened(amount))
	return img


## Builds an image from rows of palette characters ('.' or ' ' = transparent).
static func from_ascii(rows: Array, pad: int = 0, extra: Dictionary = {}) -> Image:
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := new_img(w + pad * 2, h + pad * 2)
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == " ":
				continue
			var c: Color
			if extra.has(ch):
				c = extra[ch]
			else:
				c = C.get(ch, Color.MAGENTA)
			img.set_pixel(x + pad, y + pad, c)
	return img


## Stamps 3x5 glyph text directly into an image (for labels painted on sprites).
static func stamp_text(img: Image, x: int, y: int, text: String, c: Color) -> void:
	var cx := x
	for i in text.length():
		var ch := text[i].to_upper()
		if GLYPHS.has(ch):
			var bits: String = GLYPHS[ch]
			var gw := int(bits.length() / 5)
			for b in bits.length():
				if bits[b] == "1":
					px(img, cx + (b % gw), y + int(b / gw), c)
			cx += gw + 1
		else:
			cx += 4


static func flip_h(img: Image) -> Image:
	var out: Image = img.duplicate()
	out.flip_x()
	return out


## Copies src onto dst at (x, y) with alpha blending.
static func blit(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))


# ------------------------------------------------------------------ font

func _build_font() -> void:
	var count := 128
	var cell := 6
	var atlas := Image.create(count * cell, 6, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for key in GLYPHS.keys():
		var code: int = (key as String).unicode_at(0)
		if code >= count:
			continue
		var bits: String = GLYPHS[key]
		var gw := int(bits.length() / 5)
		for i in bits.length():
			if bits[i] == "1":
				atlas.set_pixel(code * cell + (i % gw), int(i / gw), Color.WHITE)
	font = FontFile.new()
	font.fixed_size = FONT_SIZE
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.hinting = TextServer.HINTING_NONE
	var sz := Vector2i(FONT_SIZE, 0)
	font.set_texture_image(0, sz, 0, atlas)
	font.set_cache_ascent(0, FONT_SIZE, 5)
	font.set_cache_descent(0, FONT_SIZE, 1)
	for code in range(32, count):
		var src_code := code
		# lowercase -> uppercase glyphs
		if code >= 97 and code <= 122:
			src_code = code - 32
		var ch := char(src_code)
		if not GLYPHS.has(ch):
			continue
		var gw := int((GLYPHS[ch] as String).length() / 5)
		font.set_glyph_advance(0, FONT_SIZE, code, Vector2(gw + 1, 0))
		font.set_glyph_offset(0, sz, code, Vector2(0, -5))
		font.set_glyph_size(0, sz, code, Vector2(gw, 5))
		font.set_glyph_uv_rect(0, sz, code, Rect2(src_code * cell, 0, gw, 5))
		font.set_glyph_texture_idx(0, sz, code, 0)
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = FONT_SIZE


func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = FONT_SIZE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(C["K"], 0.92)
	panel.border_color = C["k"]
	panel.set_border_width_all(1)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_color("font_color", "Label", C["w"])
	if get_tree() and get_tree().root:
		get_tree().root.theme = theme


# ------------------------------------------------------------------ canvas helpers

func text_width(text: String, size: int = FONT_SIZE) -> int:
	return int(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)


## Draws pixel text with its top-left at `pos`.
func draw_text(ci: CanvasItem, pos: Vector2, text: String, color: Color = Color.WHITE, size: int = FONT_SIZE) -> void:
	var scale := int(size / FONT_SIZE)
	var p := Vector2(roundf(pos.x), roundf(pos.y) + 5 * scale)
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Pixel text with a 1px dark outline (8-way) — readable over anything.
func draw_text_outlined(ci: CanvasItem, pos: Vector2, text: String, color: Color = Color.WHITE,
		outline_color: Color = Color8(26, 16, 32), size: int = FONT_SIZE) -> void:
	var s := maxi(1, int(size / FONT_SIZE))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		draw_text(ci, pos + o * s, text, outline_color, size)
	draw_text(ci, pos, text, color, size)


## Centered variant (pos = center-top).
func draw_text_centered(ci: CanvasItem, center_top: Vector2, text: String, color: Color = Color.WHITE,
		outlined: bool = true, size: int = FONT_SIZE) -> void:
	var w := text_width(text, size)
	var p := Vector2(roundf(center_top.x - w / 2.0), roundf(center_top.y))
	if outlined:
		draw_text_outlined(ci, p, text, color, Color8(26, 16, 32), size)
	else:
		draw_text(ci, p, text, color, size)


## Crisp pixel disk made of horizontal spans.
func draw_disk(ci: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var cx := roundf(center.x)
	var cy := roundf(center.y)
	var ri := int(ceilf(r))
	for dy in range(-ri, ri + 1):
		var fy := dy + 0.5
		var span := r * r - fy * fy
		if span < 0.0:
			continue
		var hw := floorf(sqrt(span) + 0.5)
		if hw <= 0:
			continue
		ci.draw_rect(Rect2(cx - hw, cy + dy, hw * 2.0, 1), color)


## Pixel ring outline.
func draw_ring(ci: CanvasItem, center: Vector2, r: float, color: Color, segments: int = 0) -> void:
	var n := segments if segments > 0 else maxi(12, int(r * 3.0))
	for i in n:
		var a := TAU * i / n
		ci.draw_rect(Rect2(roundf(center.x + cos(a) * r), roundf(center.y + sin(a) * r), 1, 1), color)


## Segmented pixel bar: background, fill, outline.
func draw_bar(ci: CanvasItem, r: Rect2, frac: float, fill: Color, back: Color = Color8(26, 16, 32), border: bool = true) -> void:
	r = Rect2(roundf(r.position.x), roundf(r.position.y), roundf(r.size.x), roundf(r.size.y))
	if border:
		ci.draw_rect(r.grow(1), Color8(26, 16, 32))
	ci.draw_rect(r, back)
	var w := roundf(r.size.x * clampf(frac, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), fill)
		ci.draw_rect(Rect2(r.position, Vector2(w, 1)), fill.lightened(0.35))


## Pixel speech-bubble / panel box.
func draw_box(ci: CanvasItem, r: Rect2, fill: Color, border: Color = Color8(26, 16, 32)) -> void:
	r = Rect2(roundf(r.position.x), roundf(r.position.y), roundf(r.size.x), roundf(r.size.y))
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), border)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), border)
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), fill)
