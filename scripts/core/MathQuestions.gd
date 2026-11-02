class_name MathQuestions
extends RefCounted
## Kid-friendly question generator for Learning Mode.
##
##   MathQuestions.make(level, rng) -> Dictionary
##     {"type": String, "prompt": String, "answer": int, "choices": Array[int] (3 distinct, >= 0,
##      shuffled, contains answer), "visual": Dictionary, "hint": String}
##
## Levels: 1 COUNTING (age 4-6), 2 MATHS TO 10 (age 6), 3 MATHS TO 20 (age 7-8).
## Every level also mixes in "and whatnot" puzzles: shapes and colour/shape patterns.
##
## visual["kind"] tells MathQuiz what picture aid to draw:
##   count    {n, icon}                          a row-of-5 picture to count
##   piles    {icon}                             each answer button shows a pile of `choice` items
##   sequence {items: Array[int], step}          number boxes then a "?" box
##   add      {a, b, icon, double}               two groups + "a + b = ?"
##   sub      {a, b, icon}                       a items, last b bonked + "a - b = ?"
##   missing  {known, total, unknown_first, icon} "? + known = total" (or "known + ? = total")
##   numbers  {ask: "biggest"|"smallest"}        just big number buttons
##   shape    {target}                           buttons show shapes (codes in SHAPES)
##   pattern  {items: Array[int], style: "color"|"shape"}  repeating row then "?"
## visual["button"]: "number" | "pile" | "shape" | "color" — how MathQuiz draws the 3 answers.

const SHAPES := {1: "CIRCLE", 2: "SQUARE", 3: "TRIANGLE", 4: "STAR", 5: "HEART", 6: "DIAMOND"}
const SHAPE_HINTS := {
	1: "A CIRCLE IS ROUND. NO CORNERS!",
	2: "A SQUARE HAS 4 CORNERS AND 4 SAME SIDES!",
	3: "A TRIANGLE HAS 3 CORNERS!",
	4: "A STAR HAS 5 POINTY TIPS!",
	5: "A HEART IS WHAT HAMSTERS DRAW FOR MUM!",
	6: "A DIAMOND IS A SQUARE STANDING ON ITS TIP!",
}
const COLORS := {1: "RED", 2: "BLUE", 3: "YELLOW", 4: "GREEN", 5: "PURPLE"}
const ICONS := ["seed", "rat", "ham", "heart"]

const WEIGHTS := {
	1: {"count": 30, "more": 15, "next": 15, "add": 20, "shape": 10, "pattern": 10},
	2: {"add": 24, "sub": 24, "missing": 12, "double": 8, "compare": 8, "count": 5, "shape": 9, "pattern": 10},
	3: {"add": 22, "sub": 22, "missing": 14, "skip": 14, "compare": 6, "double": 5, "shape": 5, "pattern": 12},
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
	return _count(level, rng)


static func types_for(level: int) -> Array:
	return (WEIGHTS[clampi(level, 1, 3)] as Dictionary).keys()


# ------------------------------------------------------------------ builders

static func _count(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var n := rng.randi_range(1 if level == 1 else 3, 10)
	var icon: String = ICONS[rng.randi() % ICONS.size()]
	return _q("count", "HOW MANY?", n, _num_choices(n, rng),
		{"kind": "count", "n": n, "icon": icon, "button": "number"}, "TOUCH EACH ONE AND COUNT!")


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
	return _q("next", "WHAT COMES NEXT?", answer, _num_choices(answer, rng),
		{"kind": "sequence", "items": items, "step": 1, "button": "number"}, "COUNT UP BY 1!")


static func _skip(_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randi() % 4
	var step := 2
	var start := 0
	var hint := "COUNT BY 2S!"
	match roll:
		0:
			step = 2
			start = rng.randi_range(0, 6) * 2
			hint = "COUNT BY 2S! 2, 4, 6..."
		1:
			step = 5
			start = rng.randi_range(0, 3) * 5
			hint = "COUNT BY 5S! 5, 10, 15..."
		2:
			step = 10
			start = rng.randi_range(1, 4) * 10
			hint = "COUNT BY 10S! 10, 20, 30..."
		_:
			step = -1
			start = rng.randi_range(6, 20)
			hint = "COUNT DOWN, LIKE A ROCKET!"
	var items: Array[int] = [start, start + step, start + step * 2]
	var answer := start + step * 3
	var deltas: Array = [1, -1, absi(step), -absi(step)] if absi(step) > 1 else [1, -1, 2, -2]
	return _q("skip", "WHAT COMES NEXT?", answer, _num_choices(answer, rng, deltas),
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
	var prompt := "DOUBLE IT!" if double else "HOW MANY IN ALL?"
	var hint := "THE SAME NUMBER, TWO TIMES!" if double else "COUNT ALL OF THEM TOGETHER!"
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
	var hint := "COUNT THE RATS THAT ARE NOT BONKED!" if icon == "rat" else "COUNT THE SEEDS THAT ARE LEFT!"
	return _q("sub", "HOW MANY LEFT?", answer, _num_choices(answer, rng),
		{"kind": "sub", "a": a, "b": b, "icon": icon, "button": "number"}, hint)


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
	return _q("missing", "WHAT IS MISSING?", answer, _num_choices(answer, rng),
		{"kind": "missing", "known": known, "total": total, "unknown_first": unknown_first,
			"icon": "seed", "button": "number"}, "COUNT THE EMPTY SPOTS!")


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
	var prompt := "WHICH IS BIGGEST?" if biggest else "WHICH IS SMALLEST?"
	var hint := "BIG NUMBERS COME LATER WHEN YOU COUNT!" if biggest else "SMALL NUMBERS COME FIRST WHEN YOU COUNT!"
	return _q("compare", prompt, answer, choices,
		{"kind": "numbers", "ask": "biggest" if biggest else "smallest", "button": "number"}, hint)


static func _shape(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var top := 3
	if level == 2:
		top = 5
	elif level >= 3:
		top = 6
	var pool: Array = []
	for v in range(1, top + 1):
		pool.append(v)
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
	var hint := "SAY THE COLOURS OUT LOUD!" if style == "color" else "SAY THE SHAPES OUT LOUD!"
	return _q("pattern", "WHAT COMES NEXT?", answer, choices,
		{"kind": "pattern", "items": items, "style": style, "unit": unit.size(), "button": style}, hint)


# ------------------------------------------------------------------ helpers

static func _q(type: String, prompt: String, answer: int, choices: Array[int], visual: Dictionary, hint: String) -> Dictionary:
	return {"type": type, "prompt": prompt, "answer": answer, "choices": choices, "visual": visual, "hint": hint}


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
