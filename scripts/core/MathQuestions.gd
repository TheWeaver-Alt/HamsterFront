class_name MathQuestions
extends RefCounted
## Kid-friendly question generator for Learning Mode.
##
##   MathQuestions.make(level, rng) -> Dictionary
##     {"type": String, "prompt": String (a few words), "answer": int,
##      "choices": Array[int] (3 distinct, >= 0, contains answer), "visual": Dictionary,
##      "hint": String (a few words; the real hint is drawn by MathQuiz)}
##
## Levels: 1 COUNTING (age 4-6), 2 MATHS TO 10 (age 6), 3 MATHS TO 20 (age 7-8).
## About half of every level is picture puzzles (patterns, odd one out, matching, sizes, mirror,
## jigsaw, balance scales); the rest is numbers (counting, adding, taking away, missing numbers).
##
## `choices` are what the 3 answer buttons stand for. For number questions they are the numbers.
## For picture questions they are an *index* into visual["options"] (shuffled), or a colour
## code (mirror), so the buttons can show pictures. The `scale` question keeps its buttons in
## fixed order (left heavier, same, right heavier) because the button position is the answer.
##
## visual["kind"] tells MathQuiz what picture to draw above the buttons:
##   count    {n, icon}                          a row-of-5 picture to count
##   piles    {icon}                             each answer button shows a pile of `choice` items
##   sequence {items: Array[int], step}          number boxes then a "?" box
##   add      {a, b, icon, double}               two groups + "a + b = ?"
##   sub      {a, b, icon}                       a items, last b bonked + "a - b = ?"
##   missing  {known, total, unknown_first, icon} "? + known = total" (or "known + ? = total")
##   numbers  {ask: "biggest"|"smallest"}        just big number buttons
##   shape    {target}                           buttons show shapes (codes in SHAPES)
##   pattern  {items: Array[int], style: "color"|"shape", unit}   repeating row then "?"
##   odd      {attr, items: Array[glyph], odd: int}              tap the one that is different
##   same     {target: glyph, shadow: bool}                      find the identical one
##   sizes    {ask: "biggest"|"smallest"|"middle", mode: "disk"|"bar"|"tall"}
##   order    {items: Array[glyph], hole: int, dir: "grow"|"shrink"}   which size fits the gap
##   mirror   {w, h, cells: Array[Array[colour]], hole: [row, col]}    the other half of a picture
##   piece    {pic, rows: Array[String], hole: [x, y], ps}      jigsaw: which piece fits the hole
##   scale    {mode: "count"|"blocks", left: Array[int], right: Array[int], icon}   which is heavier
##   chain    {mode: "attr1"|"attr2"|"grow", items: Array[glyph], hole: int, unit, step}
## visual["options"] (odd, same, sizes, order, piece, chain): the 3 things the buttons draw.
## visual["button"]: "number" | "pile" | "shape" | "color" | "glyph" | "patch" | "scale" — how
## MathQuiz draws the 3 answers.
##
## A glyph is a Dictionary: {s: shape code, c: colour code, z: radius px} for a shape, {icon}
## for a sprite, {bar: length px, c, v: vertical} for a bar, {n: how many dots, c} for a dot card.
##
## MathQuestions.validate(q) recomputes the answer from the picture data and returns "" when a
## question is well formed (or a message). tools/MathQuizPreview.gd fuzzes it for every type.

const SHAPES := {1: "CIRCLE", 2: "SQUARE", 3: "TRIANGLE", 4: "STAR", 5: "HEART", 6: "DIAMOND"}
const SHAPE_HINTS := {
	1: "ROUND!",
	2: "4 CORNERS!",
	3: "3 CORNERS!",
	4: "5 POINTS!",
	5: "FOR MUM!",
	6: "TIPPED SQUARE!",
}
const COLORS := {1: "RED", 2: "BLUE", 3: "YELLOW", 4: "GREEN", 5: "PURPLE"}
const ICONS := ["seed", "rat", "ham", "heart"]
const SZ := [9, 14, 19]                       # small / middle / big glyph radius
const MAX_PROMPT := 18
const MAX_HINT := 18
const BUTTONS := ["number", "pile", "shape", "color", "glyph", "patch", "scale"]
const PIC_W := 12
const PIC_H := 10

# Tiny pictures for the jigsaw puzzle. One char per pixel, chars are PixelArt.C keys, "." is sky.
const PICTURES := {
	"house": [
		"............",
		".....RR.....",
		"....RRRR....",
		"...RrrrrR...",
		"..RrrrrrrR..",
		".RrrrrrrrrR.",
		".tttttttttt.",
		".ttAAttbbtt.",
		".ttAAttbbtt.",
		"eeeeeeebbeee",
	],
	"heart": [
		"............",
		"..rrr..rrr..",
		".rwrrrrrrrr.",
		".rwrrrrrrrr.",
		".rrrrrrrrrR.",
		"..rrrrrrrR..",
		"...rrrrrR...",
		"....rrrR....",
		".....rR.....",
		"............",
	],
	"flower": [
		"....pppp....",
		"..pppppppp..",
		".ppyyyyyypp.",
		".ppyyYYyypp.",
		".ppyyyyyypp.",
		"..pppppppp..",
		"....pppp....",
		".....ZZ.....",
		"..eeeZZeee..",
		"eeeeeZZeeeee",
	],
	"mushroom": [
		"............",
		"....rrrr....",
		"..rrrwwrrr..",
		".rrwwrrrwwr.",
		".rrwwrrrwwr.",
		".rrrrrrrrrr.",
		"..RRRRRRRR..",
		"....cccc....",
		"....cccc....",
		"eeeecccceeee",
	],
	"hamster": [
		"..oo....oo..",
		".opo....opo.",
		".oooooooooo.",
		"oooooooooooo",
		"ooookooookoo",
		"occcccccccco",
		"occccppcccco",
		".occcccccco.",
		"..oooooooo..",
		"............",
	],
}

const WEIGHTS := {
	1: {"count": 16, "more": 10, "next": 8, "add": 10,
		"shape": 5, "pattern": 8, "odd": 9, "same": 9, "bigger": 7, "order": 4, "piece": 5, "mirror": 4, "scale": 4},
	2: {"add": 16, "sub": 16, "missing": 8, "double": 5, "compare": 5, "count": 3,
		"shape": 3, "pattern": 7, "chain": 7, "odd": 8, "same": 6, "bigger": 6, "order": 6, "piece": 7, "mirror": 7, "scale": 7},
	3: {"add": 16, "sub": 16, "missing": 10, "skip": 10, "compare": 4, "double": 4,
		"shape": 2, "pattern": 6, "chain": 9, "odd": 7, "same": 5, "bigger": 5, "order": 6, "piece": 8, "mirror": 8, "scale": 8},
}

static var _last_sig: String = ""


static func make(level: int, rng: RandomNumberGenerator) -> Dictionary:
	level = clampi(level, 1, 3)
	var q: Dictionary = {}
	for attempt in 8:
		var type := _pick_type(level, rng)
		q = make_type(level, type, rng)
		if _sig(q) != _last_sig:
			break
	_last_sig = _sig(q)
	return q


## Builds one question of a specific type (used by make() and the preview tool).
static func make_type(level: int, type: String, rng: RandomNumberGenerator) -> Dictionary:
	level = clampi(level, 1, 3)
	match type:
		"count":
			return _count(level, rng)
		"more":
			return _more(level, rng)
		"next":
			return _next(level, rng)
		"skip":
			return _skip(level, rng)
		"add":
			return _add(level, rng, false)
		"double":
			return _add(level, rng, true)
		"sub":
			return _sub(level, rng)
		"missing":
			return _missing(level, rng)
		"compare":
			return _compare(level, rng)
		"shape":
			return _shape(level, rng)
		"pattern":
			return _pattern(level, rng)
		"odd":
			return _odd(level, rng)
		"same":
			return _same(level, rng)
		"bigger":
			return _bigger(level, rng)
		"order":
			return _order(level, rng)
		"mirror":
			return _mirror(level, rng)
		"piece":
			return _piece(level, rng)
		"scale":
			return _scale(level, rng)
		"chain":
			return _chain(level, rng)
	return _count(level, rng)


static func types_for(level: int) -> Array:
	return (WEIGHTS[clampi(level, 1, 3)] as Dictionary).keys()


# ------------------------------------------------------------------ number builders

static func _count(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var n := rng.randi_range(1 if level == 1 else 3, 10)
	var icon: String = ICONS[rng.randi() % ICONS.size()]
	return _q("count", "HOW MANY?", n, _num_choices(n, rng),
		{"kind": "count", "n": n, "icon": icon, "button": "number"}, "COUNT ALONG!")


static func _more(_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var answer := rng.randi_range(4, 9)
	var pool: Array = []
	for v in range(1, answer - 1):
		pool.append(v)
	pool.shuffle()
	var choices: Array[int] = [answer, int(pool[0]), int(pool[1])]
	choices.shuffle()
	var icon: String = ["seed", "heart", "seed"][rng.randi() % 3]
	return _q("more", "WHICH HAS MORE?", answer, choices,
		{"kind": "piles", "icon": icon, "button": "pile"}, "COUNT EACH PILE!")


static func _next(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var start := rng.randi_range(1, 6 if level == 1 else 12)
	var items: Array[int] = [start, start + 1, start + 2]
	var answer := start + 3
	return _q("next", "WHAT'S NEXT?", answer, _num_choices(answer, rng),
		{"kind": "sequence", "items": items, "step": 1, "button": "number"}, "UP BY 1!")


static func _skip(_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randi() % 4
	var step := 2
	var start := 0
	var hint := "BY 2S!"
	match roll:
		0:
			step = 2
			start = rng.randi_range(0, 6) * 2
			hint = "BY 2S!"
		1:
			step = 5
			start = rng.randi_range(0, 3) * 5
			hint = "BY 5S!"
		2:
			step = 10
			start = rng.randi_range(1, 4) * 10
			hint = "BY 10S!"
		_:
			step = -1
			start = rng.randi_range(6, 20)
			hint = "COUNT DOWN!"
	var items: Array[int] = [start, start + step, start + step * 2]
	var answer := start + step * 3
	var deltas: Array = [1, -1, absi(step), -absi(step)] if absi(step) > 1 else [1, -1, 2, -2]
	return _q("skip", "WHAT'S NEXT?", answer, _num_choices(answer, rng, deltas),
		{"kind": "sequence", "items": items, "step": step, "button": "number"}, hint)


static func _add(level: int, rng: RandomNumberGenerator, double: bool) -> Dictionary:
	var a := 1
	var b := 1
	if double:
		a = rng.randi_range(1, 5) if level <= 2 else rng.randi_range(3, 10)
		b = a
	else:
		match level:
			1:
				a = rng.randi_range(1, 4)
				b = rng.randi_range(1, 5 - a)
			2:
				a = rng.randi_range(1, 8)
				b = rng.randi_range(1, 10 - a)
			_:
				a = rng.randi_range(3, 15)
				b = rng.randi_range(2, 20 - a)
	var icon := "seed"
	if level == 1:
		icon = ICONS[rng.randi() % ICONS.size()]
	elif a + b <= 10 and rng.randf() < 0.4:
		icon = "heart"
	var answer := a + b
	var prompt := "DOUBLE IT!" if double else "IN ALL?"
	var hint := "TWICE!" if double else "COUNT THEM ALL!"
	return _q("double" if double else "add", prompt, answer, _num_choices(answer, rng),
		{"kind": "add", "a": a, "b": b, "icon": icon, "double": double, "button": "number"}, hint)


static func _sub(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var a := 2
	var b := 1
	if level <= 2:
		a = rng.randi_range(2, 10)
		b = rng.randi_range(1, a - 1)
	else:
		a = rng.randi_range(8, 20)
		b = rng.randi_range(2, a - 1)
	var answer := a - b
	var icon := "rat" if (level <= 2 or rng.randf() < 0.5) else "seed"
	return _q("sub", "HOW MANY LEFT?", answer, _num_choices(answer, rng),
		{"kind": "sub", "a": a, "b": b, "icon": icon, "button": "number"}, "COUNT WHAT'S LEFT!")


static func _missing(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var total := 3
	var known := 1
	var unknown_first := true
	if level <= 2:
		total = rng.randi_range(3, 10)
		known = rng.randi_range(1, total - 1)
	else:
		total = rng.randi_range(6, 20)
		known = rng.randi_range(1, total - 1)
		unknown_first = rng.randf() < 0.5
	var answer := total - known
	return _q("missing", "MISSING?", answer, _num_choices(answer, rng),
		{"kind": "missing", "known": known, "total": total, "unknown_first": unknown_first,
			"icon": "seed", "button": "number"}, "COUNT THE GAPS!")


static func _compare(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var top := 10 if level <= 2 else 20
	var pool: Array = []
	for v in range(0, top + 1):
		pool.append(v)
	pool.shuffle()
	var choices: Array[int] = [int(pool[0]), int(pool[1]), int(pool[2])]
	var biggest := rng.randf() < 0.65
	var answer := choices[0]
	for c in choices:
		if (biggest and c > answer) or (not biggest and c < answer):
			answer = c
	var prompt := "BIGGEST?" if biggest else "SMALLEST?"
	var hint := "COUNT THE SEEDS!"
	return _q("compare", prompt, answer, choices,
		{"kind": "numbers", "ask": "biggest" if biggest else "smallest", "button": "number"}, hint)


static func _shape(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = _range(1, _shape_top(level, 3, 5, 6))
	pool.shuffle()
	var target: int = pool[0]
	var choices: Array[int] = [int(pool[0]), int(pool[1]), int(pool[2])]
	choices.shuffle()
	return _q("shape", "FIND THE %s!" % SHAPES[target], target, choices,
		{"kind": "shape", "target": target, "button": "shape"}, SHAPE_HINTS[target])


static func _pattern(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var style := "color"
	if level >= 2 and rng.randf() < 0.45:
		style = "shape"
	var units: Array
	match level:
		1:
			units = [[0, 1]]
		2:
			units = [[0, 1], [0, 0, 1], [0, 1, 1]]
		_:
			units = [[0, 1, 2], [0, 0, 1, 1], [0, 1, 1], [0, 0, 1], [0, 1, 2, 1]]
	var unit: Array = units[rng.randi() % units.size()]
	var pool: Array = []
	var top := 5 if style == "color" else (3 if level == 1 else 6)
	for v in range(1, top + 1):
		pool.append(v)
	pool.shuffle()
	# map unit letters (0,1,2) -> concrete codes
	var codes: Array = [pool[0], pool[1], pool[2]]
	var n := mini(unit.size() * 2 + rng.randi_range(0, unit.size() - 1), 8)
	var items: Array[int] = []
	for i in n:
		items.append(int(codes[unit[i % unit.size()]]))
	var answer: int = int(codes[unit[n % unit.size()]])
	# choices: the answer + two other codes (prefer ones that appear in the pattern)
	var others: Array = []
	for c in codes:
		if int(c) != answer and items.has(int(c)) and not others.has(int(c)):
			others.append(int(c))
	for c in pool:
		if others.size() >= 2:
			break
		if int(c) != answer and not others.has(int(c)):
			others.append(int(c))
	var choices: Array[int] = [answer, int(others[0]), int(others[1])]
	choices.shuffle()
	return _q("pattern", "WHAT'S NEXT?", answer, choices,
		{"kind": "pattern", "items": items, "style": style, "unit": unit.size(), "button": style}, "SAY IT!")


# ------------------------------------------------------------------ picture builders

## Odd one out: a row of pictures where one is different. The buttons show what the odd one is.
static func _odd(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var attrs: Array = ["c", "s", "icon"]
	if level == 2:
		attrs = ["c", "s", "z", "icon"]
	elif level >= 3:
		attrs = ["c", "s", "z"]
	var attr: String = attrs[rng.randi() % attrs.size()]
	var n := 5 if level >= 3 else 4
	var oi := rng.randi() % n
	var items: Array = []
	var options: Array = []
	if attr == "icon":
		var ic: Array = _shuf(ICONS, rng)
		for i in n:
			items.append({"icon": ic[1] if i == oi else ic[0]})
		options = [{"icon": ic[1]}, {"icon": ic[0]}, {"icon": ic[2]}]
	else:
		var shps: Array = _shuf(_range(1, _shape_top(level)), rng)
		var cols: Array = _shuf(_range(1, 5), rng)
		var vals := {"s": [shps[0], shps[1], shps[2]], "c": [cols[0], cols[1], cols[2]],
			"z": [SZ[0], SZ[2], SZ[1]] if rng.randf() < 0.5 else [SZ[2], SZ[0], SZ[1]]}
		# level 3: the other attribute wobbles too (each of its 2 values at least twice), so the
		# kid has to ignore it
		var noise: Array = []
		if level >= 3:
			noise = _shuf([0, 0, 0, 1, 1], rng)
		var rule: Array = vals[attr]
		for i in n:
			var g := {"s": shps[0], "c": cols[0], "z": SZ[1]}
			g[attr] = rule[1] if i == oi else rule[0]
			if not noise.is_empty():
				if attr == "c":
					g["s"] = shps[int(noise[i])]
				else:
					g["c"] = cols[int(noise[i])]
			items.append(g)
		var ans: Dictionary = (items[oi] as Dictionary).duplicate()
		var common: Dictionary = (items[(oi + 1) % n] as Dictionary).duplicate()
		var other: Dictionary = ans.duplicate()
		other[attr] = rule[2]
		options = [ans, common, other]
	return _q("odd", "ODD ONE OUT!", 0, _perm3(rng),
		{"kind": "odd", "attr": attr, "items": items, "odd": oi, "options": options, "button": "glyph"}, "LOOK CLOSE!")


## Find the picture that is exactly the same as the big one (or the one that fits a shadow).
static func _same(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var shadow := (level == 1 and rng.randf() < 0.4) or (level == 2 and rng.randf() < 0.2)
	var shps: Array = _shuf(_range(1, _shape_top(level)), rng)
	var cols: Array = _shuf(_range(1, 5), rng)
	var z: int = SZ[1] if level == 1 else SZ[rng.randi() % 3]
	var sizes: Array = []
	for s in SZ:
		if int(s) != z:
			sizes.append(s)
	var target := _g(shps[0], cols[0], z)
	var options: Array = [target.duplicate()]
	var attrs: Array = ["s", "c", "z"]
	if shadow:
		options.append(_g(shps[1], cols[0], z))
		options.append(_g(shps[2], cols[0], z))
	elif level == 1:
		attrs = ["s", "c"]
		var one: String = attrs[rng.randi() % 2]
		for k in 2:
			options.append(_alt(target, one, shps, cols, sizes, k))
	elif level == 2:
		var one: String = attrs[rng.randi() % 3]
		for k in 2:
			options.append(_alt(target, one, shps, cols, sizes, k))
	else:
		var two: Array = _shuf(attrs, rng)
		options.append(_alt(target, String(two[0]), shps, cols, sizes, 0))
		options.append(_alt(target, String(two[1]), shps, cols, sizes, 0))
	return _q("same", "SHADOW MATCH!" if shadow else "FIND THE SAME!", 0, _perm3(rng),
		{"kind": "same", "target": target, "shadow": shadow, "options": options, "button": "glyph"},
		"SAME OUTLINE!" if shadow else "LOOK CLOSE!")


## Biggest / smallest / middle of three (discs, bars or towers).
static func _bigger(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var mode := "disk"
	if level == 2:
		mode = ["disk", "disk", "bar", "tall"][rng.randi() % 4]
	elif level >= 3:
		mode = "bar" if rng.randf() < 0.5 else "tall"
	var asks: Array = ["biggest", "smallest"] if level == 1 else ["biggest", "smallest", "middle"]
	var ask: String = asks[rng.randi() % asks.size()]
	var pool: Array
	match mode:
		"disk":
			pool = [8, 15, 22] if level == 1 else [8, 12, 16, 20, 24]
		"bar":
			pool = [28, 46, 64, 82, 100] if level == 2 else [52, 60, 68, 76, 84, 92, 100]
		_:
			pool = [20, 32, 44, 56] if level == 2 else [32, 38, 44, 50, 56, 62]
	var vals: Array = _shuf(pool, rng).slice(0, 3)
	var shp := rng.randi_range(1, 2)
	var col := rng.randi_range(1, 5)
	var options: Array = []
	for v in vals:
		match mode:
			"disk":
				options.append(_g(shp, col, int(v)))
			"bar":
				options.append({"bar": int(v), "c": col, "v": false})
			_:
				options.append({"bar": int(v), "c": col, "v": true})
	var order: Array = [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return int(vals[a]) < int(vals[b]))
	var answer: int = order[2] if ask == "biggest" else (order[0] if ask == "smallest" else order[1])
	var words := {"disk": ["BIGGEST?", "SMALLEST?", "MIDDLE SIZE?"], "bar": ["LONGEST?", "SHORTEST?", "MIDDLE ONE?"],
		"tall": ["TALLEST?", "SHORTEST?", "MIDDLE ONE?"]}
	var prompt: String = (words[mode] as Array)[["biggest", "smallest", "middle"].find(ask)]
	var choices: Array[int] = [0, 1, 2]
	return _q("bigger", prompt, answer, choices,
		{"kind": "sizes", "ask": ask, "mode": mode, "options": options, "button": "glyph"}, "LINE THEM UP!")


## Sizes that grow (or shrink) in even steps with one gap: which size fits?
static func _order(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var n := 4 if level == 1 else (5 if level == 2 else rng.randi_range(5, 6))
	var d := 4 if level <= 2 else 3
	var r_lo := 6
	var r_hi := 24 - (n - 1) * d
	if level == 1:
		r_lo = 7
	var r0 := rng.randi_range(r_lo, maxi(r_lo, r_hi))
	var grow := level == 1 or rng.randf() < 0.5
	var sizes: Array = []
	for k in n:
		sizes.append(r0 + k * d)
	if not grow:
		sizes.reverse()
	var hole := n - 1
	if level == 2:
		hole = rng.randi_range(1, n - 1)
	elif level >= 3:
		hole = rng.randi_range(1, n - 2)
	var shp := rng.randi_range(1, _shape_top(level))
	var col := rng.randi_range(1, 5)
	var items: Array = []
	for r in sizes:
		items.append(_g(shp, col, int(r)))
	var cv: int = sizes[hole]
	var below := cv - d if cv - d >= 4 else cv + 2 * d
	var above := cv + d if cv + d <= 27 else cv - 2 * d
	var options: Array = [_g(shp, col, cv), _g(shp, col, below), _g(shp, col, above)]
	return _q("order", "WHAT FITS?", 0, _perm3(rng),
		{"kind": "order", "items": items, "hole": hole, "dir": "grow" if grow else "shrink",
			"options": options, "button": "glyph"}, "SMALL TO BIG!" if grow else "BIG TO SMALL!")


## Symmetry: the right half is the mirror image of the left half, with one square missing.
static func _mirror(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var w := 2
	var h := 2
	var pal := 3
	match level:
		2:
			h = 3
		3:
			w = 3
			h = 3
			pal = 4
	var cols: Array = _shuf(_range(1, 5), rng).slice(0, pal)
	# a shuffled bag that cycles through the palette, so every colour shows up (no one colour wins)
	var bag: Array = []
	for i in w * h:
		bag.append(cols[i % pal])
	bag = _shuf(bag, rng)
	var cells: Array = []
	for r in h:
		var row: Array = []
		for c in w:
			row.append(bag[r * w + c])
		cells.append(row)
	var hr := rng.randi() % h
	var hc := rng.randi() % w
	var answer: int = (cells[hr] as Array)[w - 1 - hc]
	var others: Array = []
	for c in _shuf(cols, rng):
		if int(c) != answer:
			others.append(int(c))
	for c in _shuf(_range(1, 5), rng):
		if others.size() >= 2:
			break
		if int(c) != answer and not others.has(int(c)):
			others.append(int(c))
	var choices: Array[int] = [answer, int(others[0]), int(others[1])]
	choices.shuffle()
	return _q("mirror", "MIRROR IT!", answer, choices,
		{"kind": "mirror", "w": w, "h": h, "cells": cells, "hole": [hr, hc], "button": "color"}, "FLIP IT OVER!")


## Jigsaw: a little picture with a piece missing. Which piece fits?
static func _piece(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var names: Array = PICTURES.keys()
	var pic: String = names[rng.randi() % names.size()]
	var rows: Array = PICTURES[pic]
	var ps := 2 if level == 1 else 3
	var cands: Array = []
	for y in range(0, PIC_H - ps + 1):
		for x in range(0, PIC_W - ps + 1):
			if _distinct(_patch(rows, x, y, ps)) >= (2 if ps == 2 else 3):
				cands.append(Vector2i(x, y))
	var hole: Vector2i = cands[rng.randi() % cands.size()]
	var good := _patch(rows, hole.x, hole.y, ps)
	var good_key := "".join(good)
	var pool: Array = []
	var seen: Array = [good_key]
	for y in range(0, PIC_H - ps + 1):
		for x in range(0, PIC_W - ps + 1):
			var p := _patch(rows, x, y, ps)
			var key := "".join(p)
			if seen.has(key) or _distinct(p) < 2:
				continue
			var dist := maxi(absi(x - hole.x), absi(y - hole.y))
			if level >= 3 and dist > 4:
				continue
			seen.append(key)
			pool.append(p)
	pool = _shuf(pool, rng)
	var options: Array = [good, pool[0], pool[1]]
	return _q("piece", "FIT THE PIECE!", 0, _perm3(rng),
		{"kind": "piece", "pic": pic, "rows": rows, "hole": [hole.x, hole.y], "ps": ps,
			"options": options, "button": "patch"}, "MATCH THE EDGES!")


## Balance scale: which side is heavier? Buttons are fixed: left down, level, right down.
static func _scale(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var left: Array = []
	var right: Array = []
	var mode := "count"
	var icon: String = ["seed", "heart"][rng.randi() % 2]
	if level == 1:
		var a := rng.randi_range(1, 6)
		var b := rng.randi_range(1, 6)
		while b == a:
			b = rng.randi_range(1, 6)
		for i in a:
			left.append(1)
		for i in b:
			right.append(1)
	else:
		mode = "blocks"
		var top := 10 if level == 2 else 20
		var max_w := 6 if level == 2 else 10
		var pmax := 2 if level == 2 else 3
		var ta := rng.randi_range(2, top)
		var tb := ta
		if rng.randf() >= (0.15 if level == 2 else 0.2):
			while tb == ta:
				tb = rng.randi_range(2, top)
		left = _split(ta, max_w, pmax, rng)
		right = _split(tb, max_w, pmax, rng)
	var sl := 0
	for w in left:
		sl += int(w)
	var sr := 0
	for w in right:
		sr += int(w)
	var answer := 0 if sl > sr else (2 if sr > sl else 1)
	var choices: Array[int] = [0, 1, 2]
	return _q("scale", "HEAVIER SIDE?", answer, choices,
		{"kind": "scale", "mode": mode, "left": left, "right": right, "icon": icon, "button": "scale"},
		"COUNT BOTH!" if level == 1 else "ADD THEM UP!")


## Patterns made of pictures: one thing changing, two things changing, or growing dot cards.
## The gap can be in the middle, so the kid has to see the whole rhythm.
static func _chain(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var mode := "attr1"
	if level == 2:
		mode = "grow" if roll < 0.3 else "attr1"
	else:
		mode = "grow" if roll < 0.2 else ("attr2" if roll < 0.6 else "attr1")
	var items: Array = []
	var options: Array = []
	var hole := 0
	var unit_len := 0
	var step := 0
	var shps: Array = _shuf(_range(1, _shape_top(level)), rng)
	var cols: Array = _shuf(_range(1, 5), rng)
	match mode:
		"grow":
			step = [1, 1, 2][rng.randi() % 3] * (1 if rng.randf() < 0.75 else -1)
			var n := 4 if level == 2 else 5
			var first := 1
			if step > 0:
				first = rng.randi_range(1, 9 - (n - 1) * step)
			else:
				first = rng.randi_range(1 + (n - 1) * -step, 9)
			var col: int = cols[0]
			for k in n:
				items.append({"n": first + k * step, "c": col})
			hole = n - 1 if (level == 2 or rng.randf() < 0.4) else rng.randi_range(1, n - 2)
			var cv: int = (items[hole] as Dictionary)["n"]
			var near: Array = [cv - 1, cv + 1, cv - 2, cv + 2]
			var pick: Array = []
			for v in near:
				if int(v) >= 1 and int(v) <= 9 and pick.size() < 2:
					pick.append(int(v))
			options = [{"n": cv, "c": col}, {"n": pick[0], "c": col}, {"n": pick[1], "c": col}]
		"attr2":
			var pair: Array = [_g(shps[0], cols[0], SZ[1]), _g(shps[1], cols[1], SZ[1])]
			var n := rng.randi_range(6, 7)
			for k in n:
				items.append((pair[k % 2] as Dictionary).duplicate())
			unit_len = 2
			hole = rng.randi_range(2, n - 1)
			var ans: Dictionary = (items[hole] as Dictionary).duplicate()
			var other: Dictionary = pair[(hole + 1) % 2]
			var d1: Dictionary = ans.duplicate()
			d1["s"] = other["s"]
			var d2: Dictionary = ans.duplicate()
			d2["c"] = other["c"]
			options = [ans, d1, d2]
		_:
			var attrs: Array = ["c", "s"] if level == 2 else ["c", "s", "z"]
			var attr: String = attrs[rng.randi() % attrs.size()]
			var units: Array = [[0, 1], [0, 0, 1], [0, 1, 1]]
			if level >= 3:
				units = [[0, 1, 2], [0, 0, 1, 1], [0, 1, 2, 1], [0, 1, 1], [0, 0, 1]]
			var unit: Array = units[rng.randi() % units.size()]
			unit_len = unit.size()
			var letters := 0
			for u in unit:
				letters = maxi(letters, int(u) + 1)
			var pool: Array
			match attr:
				"c":
					pool = cols
				"s":
					pool = shps
				_:
					pool = _shuf(SZ, rng)
			var n := mini(unit.size() * 2 + rng.randi_range(1, 2), 9)
			for k in n:
				var g := _g(shps[0], cols[0], SZ[1])
				g[attr] = pool[int(unit[k % unit.size()])]
				items.append(g)
			hole = rng.randi_range(unit.size(), n - 1)
			if level == 2 and rng.randf() < 0.5:
				hole = n - 1
			var ans: Dictionary = (items[hole] as Dictionary).duplicate()
			var used: Array = []
			for k in letters:
				used.append(pool[k])
			var rest: Array = []
			for v in pool:
				if not used.has(v):
					rest.append(v)
			var cand: Array = []
			for v in used:
				if v != ans[attr]:
					cand.append(v)
			cand.append_array(rest)
			var o1: Dictionary = ans.duplicate()
			o1[attr] = cand[0]
			var o2: Dictionary = ans.duplicate()
			o2[attr] = cand[1]
			options = [ans, o1, o2]
	return _q("chain", "WHAT'S NEXT?" if hole == items.size() - 1 else "FILL THE GAP!", 0, _perm3(rng),
		{"kind": "chain", "mode": mode, "items": items, "hole": hole, "unit": unit_len, "step": step,
			"options": options, "button": "glyph"}, "SAY IT!")


# ------------------------------------------------------------------ helpers

static func _q(type: String, prompt: String, answer: int, choices: Array[int], visual: Dictionary, hint: String) -> Dictionary:
	return {"type": type, "prompt": prompt, "answer": answer, "choices": choices, "visual": visual, "hint": hint}


static func _g(s: int, c: int, z: int) -> Dictionary:
	return {"s": s, "c": c, "z": z}


static func _gkey(g: Dictionary) -> String:
	return JSON.stringify(g, "", true)


## A copy of `g` with one attribute swapped for another value (k picks which spare value).
static func _alt(g: Dictionary, attr: String, shps: Array, cols: Array, sizes: Array, k: int) -> Dictionary:
	var out := g.duplicate()
	match attr:
		"s":
			out["s"] = shps[1 + k]
		"c":
			out["c"] = cols[1 + k]
		_:
			out["z"] = sizes[k % sizes.size()]
	return out


static func _shape_top(level: int, l1: int = 4, l2: int = 5, l3: int = 6) -> int:
	return l1 if level == 1 else (l2 if level == 2 else l3)


static func _range(lo: int, hi: int) -> Array:
	var out: Array = []
	for v in range(lo, hi + 1):
		out.append(v)
	return out


## Fisher-Yates with the caller's rng (so the preview tool is reproducible).
static func _shuf(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a


static func _perm3(rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = [0, 1, 2]
	for i in range(2, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## `total` as a few positive weights, each <= max_w, at most `pmax` of them.
static func _split(total: int, max_w: int, pmax: int, rng: RandomNumberGenerator) -> Array:
	var pmin := int(ceil(total / float(max_w)))
	var parts := rng.randi_range(pmin, mini(pmax, total))
	var out: Array = []
	for i in parts:
		out.append(1)
	var left := total - parts
	while left > 0:
		var i := rng.randi() % parts
		if int(out[i]) < max_w:
			out[i] = int(out[i]) + 1
			left -= 1
	return out


static func _patch(rows: Array, x: int, y: int, ps: int) -> Array:
	var out: Array = []
	for j in ps:
		out.append(String(rows[y + j]).substr(x, ps))
	return out


static func _distinct(patch: Array) -> int:
	var seen: Array = []
	for row in patch:
		for i in String(row).length():
			var ch := String(row)[i]
			if not seen.has(ch):
				seen.append(ch)
	return seen.size()


## Three distinct non-negative choices: the answer plus two plausible neighbours.
static func _num_choices(answer: int, rng: RandomNumberGenerator, deltas: Array = [1, -1, 2, -2]) -> Array[int]:
	var near: Array = []
	var far: Array = []
	for d in deltas:
		var v: int = answer + int(d)
		if v < 0 or v == answer or near.has(v) or far.has(v):
			continue
		if absi(int(d)) == 1:
			near.append(v)
		else:
			far.append(v)
	near.shuffle()
	far.shuffle()
	var picks: Array = []
	if near.size() > 0:
		picks.append(near.pop_back())
	var rest: Array = near + far
	rest.shuffle()
	while picks.size() < 2 and rest.size() > 0:
		picks.append(rest.pop_back())
	var extra := answer + 3
	while picks.size() < 2:
		if not picks.has(extra) and extra != answer:
			picks.append(extra)
		extra += 1
	var out: Array[int] = [answer, int(picks[0]), int(picks[1])]
	out.shuffle()
	return out


static func _pick_type(level: int, rng: RandomNumberGenerator) -> String:
	var w: Dictionary = WEIGHTS[level]
	var total := 0
	for k in w.keys():
		total += int(w[k])
	var r := rng.randi_range(1, total)
	for k in w.keys():
		r -= int(w[k])
		if r <= 0:
			return String(k)
	return "count"


static func _sig(q: Dictionary) -> String:
	return "%s|%d|%s" % [q.get("type", ""), int(q.get("answer", 0)), str(q.get("visual", {}))]


# ------------------------------------------------------------------ validation

## "" when the question is well formed and its answer follows from its picture, else a message.
## Recomputes the answer from the visual data instead of trusting the builder.
static func validate(q: Dictionary) -> String:
	for key in ["type", "prompt", "answer", "choices", "visual", "hint"]:
		if not q.has(key):
			return "missing key " + key
	var choices: Array = q["choices"]
	var answer: int = int(q["answer"])
	if choices.size() != 3:
		return "choices must be 3"
	if choices[0] == choices[1] or choices[0] == choices[2] or choices[1] == choices[2]:
		return "choices not distinct: " + str(choices)
	if not choices.has(answer):
		return "answer %d not in choices %s" % [answer, str(choices)]
	for c in choices:
		if int(c) < 0:
			return "negative choice"
	if String(q["prompt"]).length() > MAX_PROMPT or String(q["prompt"]).is_empty():
		return "prompt too long or empty: " + String(q["prompt"])
	if String(q["hint"]).length() > MAX_HINT:
		return "hint too long: " + String(q["hint"])
	var v: Dictionary = q["visual"]
	var kind := String(v.get("kind", ""))
	if not BUTTONS.has(String(v.get("button", ""))):
		return "unknown button kind"
	match kind:
		"count":
			if answer != int(v["n"]):
				return "count answer"
		"piles":
			if answer != maxi(maxi(int(choices[0]), int(choices[1])), int(choices[2])):
				return "more: answer is not the biggest pile"
		"sequence":
			var items: Array = v["items"]
			var step := int(v["step"])
			for i in items.size() - 1:
				if int(items[i + 1]) - int(items[i]) != step:
					return "sequence step"
			if answer != int(items[items.size() - 1]) + step:
				return "sequence answer"
		"add":
			if answer != int(v["a"]) + int(v["b"]):
				return "add answer"
		"sub":
			if answer != int(v["a"]) - int(v["b"]) or int(v["b"]) >= int(v["a"]):
				return "sub answer"
		"missing":
			if answer != int(v["total"]) - int(v["known"]) or answer < 1:
				return "missing answer"
		"numbers":
			var best := int(choices[0])
			for c in choices:
				best = maxi(best, int(c)) if v["ask"] == "biggest" else mini(best, int(c))
			if answer != best:
				return "compare answer"
		"shape":
			if answer != int(v["target"]):
				return "shape answer"
		"pattern":
			var items: Array = v["items"]
			var unit := int(v["unit"])
			for i in range(unit, items.size()):
				if int(items[i]) != int(items[i - unit]):
					return "pattern is not periodic"
			if answer != int(items[items.size() - unit]):
				return "pattern answer"
		"odd":
			return _check_odd(q, v)
		"same":
			return _check_same(q, v)
		"sizes":
			return _check_sizes(q, v)
		"order":
			return _check_order(q, v)
		"mirror":
			return _check_mirror(q, v)
		"piece":
			return _check_piece(q, v)
		"scale":
			return _check_scale(q, v)
		"chain":
			return _check_chain(q, v)
		_:
			return "unknown visual kind '%s'" % kind
	return ""


## For glyph/patch buttons: choices are a permutation of option indices and the answer's option
## is the one the picture asks for. Returns "" when options are 3 distinct things.
static func _check_options(q: Dictionary, v: Dictionary) -> String:
	var options: Array = v.get("options", [])
	if options.size() != 3:
		return "options must be 3"
	var keys: Array = []
	for o in options:
		var key := JSON.stringify(o, "", true)
		if keys.has(key):
			return "two options look the same"
		keys.append(key)
	if not _is_perm3(q["choices"]):
		return "choices must be option indices 0..2"
	return ""


static func _is_perm3(choices: Array) -> bool:
	for want in 3:
		if not choices.has(want):
			return false
	return choices.size() == 3


static func _check_odd(q: Dictionary, v: Dictionary) -> String:
	var err := _check_options(q, v)
	if err != "":
		return err
	var items: Array = v["items"]
	var oi := int(v["odd"])
	var attr := String(v["attr"])
	var options: Array = v["options"]
	var odd_item: Dictionary = items[oi]
	var matches := 0
	for o in options:
		if _gkey(o) == _gkey(odd_item):
			matches += 1
	if matches != 1 or _gkey(options[int(q["answer"])]) != _gkey(odd_item):
		return "odd: answer option is not the odd item"
	var common_val = null
	for i in items.size():
		var val = (items[i] as Dictionary).get(attr)
		if i == oi:
			continue
		if val == odd_item.get(attr):
			return "odd: item %d is as odd as the odd one" % i
		if common_val == null:
			common_val = val
		elif val != common_val:
			return "odd: two different odd items"
	return ""


static func _check_same(q: Dictionary, v: Dictionary) -> String:
	var err := _check_options(q, v)
	if err != "":
		return err
	var options: Array = v["options"]
	var tk := _gkey(v["target"])
	var hits := 0
	for o in options:
		if bool(v["shadow"]):
			# shadows: the shape must match, nothing else is visible
			if (o as Dictionary)["s"] == (v["target"] as Dictionary)["s"]:
				hits += 1
		elif _gkey(o) == tk:
			hits += 1
	if hits != 1:
		return "same: %d options match the target" % hits
	var a: Dictionary = options[int(q["answer"])]
	if a["s"] != (v["target"] as Dictionary)["s"]:
		return "same: answer option has another shape"
	return ""


static func _check_sizes(q: Dictionary, v: Dictionary) -> String:
	var options: Array = v["options"]
	if options.size() != 3:
		return "sizes: options must be 3"
	var vals: Array = []
	for o in options:
		var g: Dictionary = o
		vals.append(int(g["bar"]) if g.has("bar") else int(g["z"]))
	var sorted: Array = vals.duplicate()
	sorted.sort()
	if sorted[0] == sorted[1] or sorted[1] == sorted[2]:
		return "sizes: two options are the same size"
	var want: int = sorted[2] if v["ask"] == "biggest" else (sorted[0] if v["ask"] == "smallest" else sorted[1])
	if int(vals[int(q["answer"])]) != want:
		return "sizes: wrong answer"
	return ""


static func _check_order(q: Dictionary, v: Dictionary) -> String:
	var err := _check_options(q, v)
	if err != "":
		return err
	var items: Array = v["items"]
	var hole := int(v["hole"])
	var d := int((items[1] as Dictionary)["z"]) - int((items[0] as Dictionary)["z"])
	for i in items.size() - 1:
		if int((items[i + 1] as Dictionary)["z"]) - int((items[i] as Dictionary)["z"]) != d:
			return "order: sizes are not evenly spaced"
	if hole < 1 or hole > items.size() - 1:
		return "order: hole out of range"
	var a: Dictionary = (v["options"] as Array)[int(q["answer"])]
	if int(a["z"]) != int((items[hole] as Dictionary)["z"]):
		return "order: wrong answer"
	for o in v["options"]:
		if int((o as Dictionary)["z"]) < 3 or int((o as Dictionary)["z"]) > 30:
			return "order: option size out of range"
	return ""


static func _check_mirror(q: Dictionary, v: Dictionary) -> String:
	var w := int(v["w"])
	var h := int(v["h"])
	var cells: Array = v["cells"]
	var hole: Array = v["hole"]
	if cells.size() != h:
		return "mirror: rows"
	var seen: Array = []
	for r in h:
		if (cells[r] as Array).size() != w:
			return "mirror: columns"
		for c in w:
			if not seen.has(cells[r][c]):
				seen.append(cells[r][c])
	if seen.size() < 2:
		return "mirror: all one colour"
	if int(cells[int(hole[0])][w - 1 - int(hole[1])]) != int(q["answer"]):
		return "mirror: wrong answer"
	return ""


static func _check_piece(q: Dictionary, v: Dictionary) -> String:
	var err := _check_options(q, v)
	if err != "":
		return err
	var rows: Array = v["rows"]
	if rows.size() != PIC_H:
		return "piece: picture height"
	for r in rows:
		if String(r).length() != PIC_W:
			return "piece: picture width"
	var hole: Array = v["hole"]
	var ps := int(v["ps"])
	var good := _patch(rows, int(hole[0]), int(hole[1]), ps)
	var options: Array = v["options"]
	if "".join(options[int(q["answer"])]) != "".join(good):
		return "piece: answer is not the missing piece"
	for i in 3:
		if i != int(q["answer"]) and "".join(options[i]) == "".join(good):
			return "piece: a wrong option also fits"
	for o in options:
		if (o as Array).size() != ps:
			return "piece: option size"
	return ""


static func _check_scale(q: Dictionary, v: Dictionary) -> String:
	var cs: Array = q["choices"]
	if int(cs[0]) != 0 or int(cs[1]) != 1 or int(cs[2]) != 2:
		return "scale: buttons must stay in order"
	var sl := 0
	for w in v["left"]:
		sl += int(w)
	var sr := 0
	for w in v["right"]:
		sr += int(w)
	if sl < 1 or sr < 1:
		return "scale: empty pan"
	var want := 0 if sl > sr else (2 if sr > sl else 1)
	if int(q["answer"]) != want:
		return "scale: wrong answer"
	return ""


static func _check_chain(q: Dictionary, v: Dictionary) -> String:
	var err := _check_options(q, v)
	if err != "":
		return err
	var items: Array = v["items"]
	var hole := int(v["hole"])
	var unit := int(v["unit"])
	if hole < 1 or hole > items.size() - 1:
		return "chain: hole out of range"
	var a: Dictionary = (v["options"] as Array)[int(q["answer"])]
	if _gkey(a) != _gkey(items[hole]):
		return "chain: answer is not the missing item"
	if unit > 0:
		if hole < unit:
			return "chain: hole inside the first repeat"
		if items.size() < unit * 2 + 1:
			return "chain: too short to show the rhythm"
		for i in range(unit, items.size()):
			if _gkey(items[i]) != _gkey(items[i - unit]):
				return "chain: not periodic"
	else:
		var step := int(v["step"])
		for i in items.size() - 1:
			if int((items[i + 1] as Dictionary)["n"]) - int((items[i] as Dictionary)["n"]) != step:
				return "chain: dots step"
		for o in v["options"]:
			if int((o as Dictionary)["n"]) < 1 or int((o as Dictionary)["n"]) > 9:
				return "chain: dot count out of range"
	return ""
