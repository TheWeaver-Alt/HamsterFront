extends Node
## Global "juice": hit-stop frames (Engine.time_scale), camera trauma shake,
## pooled speech-bubble barks and convenience wrappers for FX bursts.

const MAX_SHAKE := 8.0
const BUBBLE_POOL := 12

var camera: Camera2D = null
var fx: FXLayer = null
var glow: FXLayer = null
var overlay: Node2D = null
var trauma := 0.0
var base_time_scale := 1.0

var _bubbles: Array = []
var _bark_cd: Dictionary = {}
var _hitstop_until := 0
var _hitstop_on := false
var _last_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ms = Time.get_ticks_msec()


## Called by MainArena once its scene tree is ready.
func register(cam: Camera2D, fx_layer: FXLayer, glow_layer: FXLayer, overlay_node: Node2D) -> void:
	camera = cam
	fx = fx_layer
	glow = glow_layer
	overlay = overlay_node
	_bubbles.clear()
	for i in BUBBLE_POOL:
		var b := SpeechBubble.new()
		overlay.add_child(b)
		_bubbles.append(b)
	trauma = 0.0
	_bark_cd.clear()
	_hitstop_on = false
	set_base_time_scale(1.0)


func set_base_time_scale(s: float) -> void:
	base_time_scale = s
	if not _hitstop_on:
		Engine.time_scale = s


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	if _hitstop_on and now >= _hitstop_until:
		_hitstop_on = false
		Engine.time_scale = base_time_scale
	trauma = maxf(0.0, trauma - real_dt * 1.5)
	if is_instance_valid(camera):
		var amt := trauma * trauma
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * MAX_SHAKE * amt
		camera.offset = off.round()


# --- Shake & hit-stop ----------------------------------------------------------

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func hitstop(duration: float, scale: float = 0.05) -> void:
	if GameManager.state == GameManager.State.GAME_OVER:
		return
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(duration * 1000.0))
	_hitstop_on = true
	Engine.time_scale = scale


# --- Barks ---------------------------------------------------------------------

## Pops a speech bubble over `target`. A non-empty category rate-limits barks.
func bark(target: Node2D, text: String, is_rat: bool = false, category: String = "", cooldown: float = 0.0) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(overlay):
		return false
	var now := Time.get_ticks_msec()
	if category != "":
		if int(_bark_cd.get(category, 0)) > now:
			return false
	for b in _bubbles:
		if is_instance_valid(b) and not b.active:
			b.pop(target, text, is_rat)
			if category != "":
				_bark_cd[category] = now + int(cooldown * 1000.0)
			return true
	return false


# --- FX wrappers -----------------------------------------------------------------

func _layer(use_glow: bool) -> FXLayer:
	if use_glow and is_instance_valid(glow):
		return glow
	if is_instance_valid(fx):
		return fx
	return null


func burst(pos: Vector2, color: Color, count: int = 8, speed: float = 60.0, life: float = 0.4,
		size: float = 2.0, grav: float = 0.0, use_glow: bool = false, dir: Vector2 = Vector2.ZERO, spread: float = TAU) -> void:
	var l := _layer(use_glow)
	if l != null:
		l.burst(pos, color, count, speed, life, size, grav, dir, spread)


func particle(pos: Vector2, vel: Vector2, color: Color, life: float, size: float = 2.0, grav: float = 0.0, use_glow: bool = false) -> void:
	var l := _layer(use_glow)
	if l != null:
		l.particle(pos, vel, color, life, size, grav)


func ring(pos: Vector2, radius: float, color: Color, life: float = 0.3, use_glow: bool = false) -> void:
	var l := _layer(use_glow)
	if l != null:
		l.ring(pos, radius, color, life)


func flash(pos: Vector2, radius: float, color: Color, life: float = 0.06) -> void:
	var l := _layer(true)
	if l != null:
		l.flash(pos, radius, color, life)


func beam(a: Vector2, b: Vector2, color: Color, width: float = 1.0, life: float = 0.08, use_glow: bool = true) -> void:
	var l := _layer(use_glow)
	if l != null:
		l.line(PackedVector2Array([a, b]), color, width, life)


## Jagged lightning bolt between two points.
func bolt(a: Vector2, b: Vector2, color: Color, life: float = 0.12, jag: float = 4.0) -> void:
	var l := _layer(true)
	if l == null:
		return
	var pts := PackedVector2Array()
	var segs := maxi(2, int(a.distance_to(b) / 7.0))
	var n := (b - a).orthogonal().normalized()
	for i in segs + 1:
		var t := float(i) / segs
		var p := a.lerp(b, t)
		if i > 0 and i < segs:
			p += n * randf_range(-jag, jag)
		pts.append(p.round())
	l.line(pts, color, 1.0, life)


func popup(pos: Vector2, text: String, color: Color, life: float = 0.9) -> void:
	if is_instance_valid(fx):
		fx.text(pos, text, color, life)
