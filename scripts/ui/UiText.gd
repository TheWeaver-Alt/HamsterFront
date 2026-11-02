class_name UiText
extends RefCounted
## Pixel text helpers whose 1px outline fades together with the text
## (PixelArt.draw_text_outlined always uses an opaque outline, which leaves dark
## letter-shaped smudges while text fades out).

const INK := Color8(26, 16, 32)


## Outlined text with its top-left at `pos`; outline alpha follows `col.a`.
static func outlined(ci: CanvasItem, pos: Vector2, text: String, col: Color, size: int = 6,
		outline: Color = INK) -> void:
	if col.a <= 0.01:
		return
	var s := maxi(1, int(size / 6))
	var oc := Color(outline, outline.a * col.a * col.a)
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		PixelArt.draw_text(ci, pos + o * s, text, oc, size)
	PixelArt.draw_text(ci, pos, text, col, size)


## Centered variant (pos = centre-top).
static func outlined_centered(ci: CanvasItem, center_top: Vector2, text: String, col: Color,
		size: int = 6, outline: Color = INK) -> void:
	var w := PixelArt.text_width(text, size)
	outlined(ci, Vector2(roundf(center_top.x - w / 2.0), roundf(center_top.y)), text, col, size, outline)
