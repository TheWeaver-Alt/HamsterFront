extends Node2D
## Dev tool: shows the Learning Mode MathQuiz with fake pilots across levels / question types,
## saves screenshots to res://screenshots/quiz_*.png (ask, hint, highlight and correct states),
## fuzzes MathQuestions.validate() over every type, then runs a button-mashing bot that must finish
## every type at every level, and quits.
## Run: godot --path . res://tools/MathQuizPreview.tscn   (a window, not --headless: it takes screenshots)
## Options after `--`:  --only=odd,mirror   only screenshot these types
##                      --no-shots          skip the screenshots (fuzz + bot only)
##                      --no-mash           skip the bot
## Any error is pushed with push_error, so it shows up as an "ERROR:" line.

const QuizScript := preload("res://scripts/ui/MathQuiz.gd")
const FUZZ_COUNT := 400

class FakePlayer extends RefCounted:
	var player_id: int = 1
	var input: PlayerInput = PlayerInput.new("bot")
	var col: Color = Color8(255, 150, 70)

	func color() -> Color:
		return col

# [level, type, player, extras, want]
# extras: "hint" (wrong answer, then the hint), "highlight" (two misses), "correct" (celebration).
# want: visual fields the question must have (keeps asking until it does), so a shot shows each variant.
const SCENARIOS := [
	[1, "count", 1, ["hint", "correct"], {}],
	[1, "more", 2, ["hint"], {}],
	[1, "next", 1, ["hint"], {}],
	[1, "add", 1, ["hint"], {}],
	[1, "shape", 2, ["highlight"], {}],
	[1, "pattern", 1, ["hint"], {}],
	[1, "odd", 1, ["hint"], {}],
	[1, "odd", 2, [], {"attr": "icon"}],
	[1, "same", 2, ["hint"], {}],
	[1, "same", 1, [], {"shadow": true}],
	[1, "bigger", 1, ["hint"], {}],
	[1, "order", 2, ["hint"], {}],
	[1, "mirror", 1, ["hint"], {}],
	[1, "piece", 2, ["hint"], {}],
	[1, "scale", 1, ["hint", "correct"], {}],
	[2, "add", 1, ["hint", "correct"], {}],
	[2, "sub", 2, ["hint"], {}],
	[2, "missing", 1, ["hint"], {}],
	[2, "double", 1, [], {}],
	[2, "compare", 2, ["hint"], {}],
	[2, "shape", 1, [], {}],
	[2, "pattern", 2, ["hint"], {}],
	[2, "odd", 1, ["hint"], {"attr": "z"}],
	[2, "same", 2, ["hint"], {}],
	[2, "bigger", 1, ["hint"], {"mode": "bar"}],
	[2, "bigger", 2, [], {"mode": "tall"}],
	[2, "order", 1, ["hint"], {}],
	[2, "mirror", 2, ["hint"], {}],
	[2, "piece", 1, ["hint"], {}],
	[2, "scale", 2, ["hint"], {}],
	[2, "chain", 1, ["hint"], {"mode": "attr1"}],
	[2, "chain", 2, [], {"mode": "grow"}],
	[3, "add", 1, ["hint"], {}],
	[3, "sub", 2, ["hint"], {}],
	[3, "missing", 1, ["hint"], {}],
	[3, "skip", 2, ["hint"], {}],
	[3, "pattern", 1, ["hint", "correct"], {}],
	[3, "compare", 1, [], {}],
	[3, "odd", 2, ["hint"], {}],
	[3, "same", 1, ["hint"], {}],
	[3, "bigger", 2, ["hint"], {"mode": "bar"}],
	[3, "bigger", 1, [], {"mode": "tall"}],
	[3, "order", 2, ["hint"], {}],
	[3, "mirror", 1, ["hint"], {}],
	[3, "piece", 2, ["hint", "correct"], {}],
	[3, "scale", 1, ["hint"], {}],
	[3, "chain", 2, ["hint"], {"mode": "attr2"}],
	[3, "chain", 1, ["correct"], {"mode": "attr1"}],
]

var quiz
var p1 := FakePlayer.new()
var p2 := FakePlayer.new()
var rng := RandomNumberGenerator.new()
var frame := 0
var mash := false
var solved_log: Array = []
var only: Array = []
var shots := true
var do_mash := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1).split(",")
		elif a == "--no-shots":
			shots = false
		elif a == "--no-mash":
			do_mash = false
	p2.player_id = 2
	p2.col = Color8(90, 200, 230)
	rng.seed = 7
	var bg := ColorRect.new()
	bg.color = Color8(72, 152, 64)
	bg.size = Vector2(640, 360)
	add_child(bg)
	quiz = QuizScript.new()
	quiz.size = Vector2(640, 360)
	add_child(quiz)
	quiz.solved.connect(func(p, ft): solved_log.append([p, ft]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	_run.call_deferred()


func _process(_d: float) -> void:
	frame += 1
	if mash:
		for p in [p1, p2]:
			p.input.bot_held = {"confirm": frame % 6 < 3, "right": frame % 40 == 0}


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Waits until `solved` has fired `count` times (the quiz clamps its frame time, so a slow first
## frame, like a sound being synthesised, makes it run late against the wall clock).
func _wait_solved(count: int, timeout_ms: int = 8000) -> void:
	var t0 := Time.get_ticks_msec()
	while solved_log.size() < count and Time.get_ticks_msec() - t0 < timeout_ms:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/quiz_%s.png" % name)
	print("[quiz] shot ", name)


## Every type at every level: generate FUZZ_COUNT questions and check the answer follows from the picture.
func _fuzz() -> int:
	var bad := 0
	var total := 0
	var frng := RandomNumberGenerator.new()
	frng.seed = 12345
	for lvl in [1, 2, 3]:
		for type in MathQuestions.types_for(lvl):
			var errors := 0
			for i in FUZZ_COUNT:
				var q := MathQuestions.make_type(lvl, String(type), frng)
				var err := MathQuestions.validate(q)
				total += 1
				if err != "":
					errors += 1
					if errors <= 3:
						push_error("quiz fuzz L%d %s: %s" % [lvl, type, err])
			bad += errors
			if errors > 0:
				print("[quiz] fuzz L%d %s: %d/%d BAD" % [lvl, type, errors, FUZZ_COUNT])
	# make() must only hand out the types its level lists
	for lvl in [1, 2, 3]:
		for i in FUZZ_COUNT:
			var q := MathQuestions.make(lvl, frng)
			if not MathQuestions.types_for(lvl).has(q["type"]):
				push_error("quiz make() L%d gave a type outside its list: %s" % [lvl, q["type"]])
				bad += 1
	print("[quiz] fuzz: %d questions checked, %d bad" % [total, bad])
	return bad


## The validator must reject a question whose picture no longer matches its answer.
## Each type gets one targeted corruption; a validator that says "" to it is broken.
func _selftest_validator() -> int:
	var srng := RandomNumberGenerator.new()
	srng.seed = 99
	var bad := 0
	for type in ["odd", "same", "bigger", "order", "mirror", "piece", "scale", "chain", "count", "add", "pattern"]:
		var q := MathQuestions.make_type(3, type, srng)
		var v: Dictionary = q["visual"]
		match type:
			"odd":
				v["odd"] = (int(v["odd"]) + 1) % (v["items"] as Array).size()
			"same":
				v["options"][1] = (v["options"][0] as Dictionary).duplicate()
			"bigger":
				q["answer"] = (int(q["answer"]) + 1) % 3
			"order":
				(v["items"][int(v["hole"])] as Dictionary)["z"] = int(v["items"][int(v["hole"])]["z"]) + 1
			"mirror":
				q["answer"] = (q["choices"] as Array).filter(func(c): return c != q["answer"])[0]
			"piece":
				v["hole"] = [(int(v["hole"][0]) + 1) % 8, int(v["hole"][1])]
			"scale":
				q["answer"] = (int(q["answer"]) + 1) % 3
			"chain":
				v["hole"] = int(v["hole"]) - 1
			"count":
				v["n"] = int(v["n"]) + 1
			"add":
				v["a"] = int(v["a"]) + 1
			"pattern":
				(v["items"] as Array)[0] = int(v["items"][0]) + 100
		if MathQuestions.validate(q) == "":
			push_error("quiz validator accepted a corrupted %s question" % type)
			bad += 1
	print("[quiz] validator self-test: %d of 11 corruptions slipped through" % bad)
	return bad


func _matches(q: Dictionary, want: Dictionary) -> bool:
	for k in want.keys():
		if q["visual"].get(k) != want[k]:
			return false
	return true


func _make(lvl: int, type: String, want: Dictionary) -> Dictionary:
	for i in 200:
		var q := MathQuestions.make_type(lvl, type, rng)
		if _matches(q, want):
			return q
	push_error("could not build L%d %s with %s" % [lvl, type, str(want)])
	return MathQuestions.make_type(lvl, type, rng)


func _run() -> void:
	_selftest_validator()
	_fuzz()
	if shots:
		for sc in SCENARIOS:
			var lvl: int = sc[0]
			var type: String = sc[1]
			if not only.is_empty() and not only.has(type):
				continue
			var who = p1 if int(sc[2]) == 1 else p2
			var extras: Array = sc[3]
			var want: Dictionary = sc[4]
			quiz.ask(who, lvl, "ACTIVATE CARD: ESPRESSO DRIP FEED" if lvl != 2 else "UPGRADE TOWER")
			quiz.q = _make(lvl, type, want)
			var err := MathQuestions.validate(quiz.q)
			if err != "":
				push_error("scenario question invalid: " + err)
			await _wait(0.6)
			var tag := "L%d_%s" % [lvl, type]
			for k in want.keys():
				tag += "_" + str(want[k])
			await _shot(tag + "_ask")
			var correct: int = quiz._correct_index()
			var wrong := (correct + 1) % 3
			if extras.has("hint"):
				quiz._answer(wrong)
				await _wait(0.12)
				await _shot(tag + "_wrong")
				await _wait(2.2)
				await _shot(tag + "_hint")
			if extras.has("highlight"):
				quiz._answer(wrong)
				await _wait(0.5)
				quiz._answer((correct + 2) % 3)
				await _wait(0.6)
				await _shot(tag + "_highlight")
			solved_log.clear()
			quiz._answer(correct)
			if extras.has("correct"):
				await _wait(0.3)
				await _shot(tag + "_correct")
			await _wait_solved(1)
			if solved_log.is_empty() or quiz.active:
				push_error("quiz did not close after the correct answer: " + tag)
	# queue test: two pilots ask at once
	solved_log.clear()
	quiz.ask(p1, 2, "QUEUE TEST")
	quiz.ask(p2, 1, "QUEUE TEST")
	quiz._answer(quiz._correct_index())
	await _wait_solved(1)
	if quiz.player != p2:
		push_error("queue did not advance to P2")
	quiz._answer(quiz._correct_index())
	await _wait_solved(2)
	print("[quiz] queue solved: ", solved_log.size(), " (expect 2), active=", quiz.active)
	if not do_mash:
		get_tree().quit()
		return
	# bot mash test: the bot only presses confirm and "right" now and then. Every type at every
	# level must finish, plus a few random questions per level through the real make().
	mash = true
	var finished := 0
	var asked := 0
	for lvl in [1, 2, 3]:
		var plan: Array = []
		for type in MathQuestions.types_for(lvl):
			plan.append(String(type))
		for n in 6:
			plan.append("")
		for n in plan.size():
			var type: String = plan[n]
			solved_log.clear()
			quiz.ask(p1 if n % 2 == 0 else p2, lvl, "MASH")
			if type != "":
				quiz.q = MathQuestions.make_type(lvl, type, rng)
			asked += 1
			var t0 := Time.get_ticks_msec()
			while solved_log.is_empty() and Time.get_ticks_msec() - t0 < 15000:
				await get_tree().process_frame
			if solved_log.is_empty():
				push_error("bot could not finish level %d question (%s)" % [lvl, type if type != "" else str(quiz.q.get("type"))])
			else:
				finished += 1
	print("[quiz] bot mash finished %d/%d, stars=%d asked=%d seeds=%d" % [finished, asked, GameManager.math_stars, GameManager.math_asked, GameManager.seeds])
	get_tree().quit()
