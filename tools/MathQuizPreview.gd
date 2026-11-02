extends Node2D
## Dev tool: shows the Learning Mode MathQuiz with fake pilots across levels / question types,
## saves screenshots to res://screenshots/quiz_*.png (ask, hint, highlight and correct states),
## then runs a button-mashing bot to prove every quiz can be finished, and quits.
## Run: godot --path . res://tools/MathQuizPreview.tscn

const QuizScript := preload("res://scripts/ui/MathQuiz.gd")

class FakePlayer extends RefCounted:
	var player_id: int = 1
	var input: PlayerInput = PlayerInput.new("bot")
	var col: Color = Color8(255, 150, 70)

	func color() -> Color:
		return col

# [level, type, player, extras] extras: "hint", "highlight", "correct"
const SCENARIOS := [
	[1, "count", 1, ["hint", "correct"]],
	[1, "more", 2, ["hint"]],
	[1, "next", 1, ["hint"]],
	[1, "add", 1, ["hint"]],
	[1, "shape", 2, ["highlight"]],
	[1, "pattern", 1, ["hint"]],
	[2, "add", 1, ["hint", "correct"]],
	[2, "sub", 2, ["hint"]],
	[2, "missing", 1, ["hint"]],
	[2, "double", 1, []],
	[2, "compare", 2, ["hint"]],
	[2, "shape", 1, []],
	[2, "pattern", 2, ["hint"]],
	[3, "add", 1, ["hint"]],
	[3, "sub", 2, ["hint"]],
	[3, "missing", 1, ["hint"]],
	[3, "skip", 2, ["hint"]],
	[3, "pattern", 1, ["hint", "correct"]],
	[3, "compare", 1, []],
]

var quiz
var p1 := FakePlayer.new()
var p2 := FakePlayer.new()
var rng := RandomNumberGenerator.new()
var frame := 0
var mash := false
var solved_log: Array = []


func _ready() -> void:
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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/quiz_%s.png" % name)
	print("[quiz] shot ", name)


func _run() -> void:
	for sc in SCENARIOS:
		var lvl: int = sc[0]
		var type: String = sc[1]
		var who = p1 if int(sc[2]) == 1 else p2
		var extras: Array = sc[3]
		quiz.ask(who, lvl, "ACTIVATE CARD: ESPRESSO DRIP FEED" if lvl != 2 else "UPGRADE TOWER")
		quiz.q = MathQuestions.make_type(lvl, type, rng)
		await _wait(0.6)
		var tag := "L%d_%s" % [lvl, type]
		await _shot(tag + "_ask")
		var correct: int = quiz._correct_index()
		var wrong := (correct + 1) % 3
		if extras.has("hint"):
			quiz._answer(wrong)
			await _wait(0.12)
			await _shot(tag + "_wrong")
			await _wait(3.0)
			await _shot(tag + "_hint")
		if extras.has("highlight"):
			for i in 3:
				quiz._answer(wrong)
				await _wait(0.1)
			await _wait(0.6)
			await _shot(tag + "_highlight")
		quiz._answer(correct)
		if extras.has("correct"):
			await _wait(0.3)
			await _shot(tag + "_correct")
		await _wait(1.4)
		if quiz.active:
			push_error("quiz still active after correct answer: " + tag)
	# queue test: two pilots ask at once
	solved_log.clear()
	quiz.ask(p1, 2, "QUEUE TEST")
	quiz.ask(p2, 1, "QUEUE TEST")
	quiz._answer(quiz._correct_index())
	await _wait(1.4)
	if quiz.player != p2:
		push_error("queue did not advance to P2")
	quiz._answer(quiz._correct_index())
	await _wait(1.4)
	print("[quiz] queue solved: ", solved_log.size(), " (expect 2), active=", quiz.active)
	# bot mash test: every level, several questions, must always finish
	mash = true
	var finished := 0
	for lvl in [1, 2, 3]:
		for n in 6:
			solved_log.clear()
			quiz.ask(p1 if n % 2 == 0 else p2, lvl, "MASH")
			var t0 := Time.get_ticks_msec()
			while solved_log.is_empty() and Time.get_ticks_msec() - t0 < 15000:
				await get_tree().process_frame
			if solved_log.is_empty():
				push_error("bot could not finish level %d question" % lvl)
			else:
				finished += 1
	print("[quiz] bot mash finished %d/18, stars=%d asked=%d seeds=%d" % [finished, GameManager.math_stars, GameManager.math_asked, GameManager.seeds])
	get_tree().quit()
