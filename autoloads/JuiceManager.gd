extends Node
## JuiceManager — global hit-stop (Engine.time_scale), camera trauma shake,
## pooled floating speech-bubble barks, screen flashes.

const BarkBubbleScript := preload("res://scripts/ui/BarkBubble.gd")

const MAX_SHAKE_PX := 8.0
const TRAUMA_DECAY := 2.5          # short, punchy shakes
const HITSTOP_MAX := 0.11          # a chain of hit-stops never freezes longer than this
const HITSTOP_GRACE_MS := 70       # small hit-stops right after one ends are skipped
const POOL_SIZE := 14
const MAX_ACTIVE_RAT_BARKS := 3

var camera: Camera2D = null
var bark_layer: Node2D = null
var flash_rect: ColorRect = null

var trauma: float = 0.0
var shake_enabled: bool = true
var _hitstop_until_ms: int = 0
var _noise := FastNoiseLite.new()
var _noise_t: float = 0.0
var _pool: Array = []
var _last_global_rat_bark_ms: int = 0
var _flash_t: float = 0.0
var _flash_dur: float = 0.0
var _flash_color: Color = Color.WHITE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.seed = 1337
	_noise.frequency = 1.3
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX


## Called by MainArena when it enters the tree.
func register_world(cam: Camera2D, barks: Node2D, flash: ColorRect = null) -> void:
	camera = cam
	bark_layer = barks
	flash_rect = flash
	_pool.clear()
	trauma = 0.0
	Engine.time_scale = 1.0


func unregister_world() -> void:
	camera = null
	bark_layer = null
	flash_rect = null
	_pool.clear()
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	var real_dt := 1.0 / maxf(1.0, Engine.get_frames_per_second()) if Engine.get_frames_per_second() > 0 else 0.016
	real_dt = minf(real_dt, 0.05)
	# hit-stop restore
	if _hitstop_until_ms > 0 and Time.get_ticks_msec() >= _hitstop_until_ms:
		_hitstop_until_ms = 0
		_hitstop_end_ms = Time.get_ticks_msec()
		Engine.time_scale = 1.0
	# camera shake
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * real_dt)
	if is_instance_valid(camera):
		if trauma > 0.0 and shake_enabled:
			_noise_t += real_dt * 60.0
			var amt := trauma * trauma * MAX_SHAKE_PX
			camera.offset = Vector2(
				roundf(_noise.get_noise_2d(_noise_t, 0.0) * amt * 1.6),
				roundf(_noise.get_noise_2d(0.0, _noise_t) * amt * 1.6))
		else:
			camera.offset = Vector2.ZERO
	# screen flash
	if is_instance_valid(flash_rect):
		if _flash_t > 0.0:
			_flash_t = maxf(0.0, _flash_t - real_dt)
			var a := (_flash_t / maxf(_flash_dur, 0.001))
			flash_rect.color = Color(_flash_color, _flash_color.a * a)
			flash_rect.visible = true
		elif flash_rect.visible:
			flash_rect.visible = false


# ------------------------------------------------------------------ hit-stop & shake

## Freeze-frame: drops Engine.time_scale for `duration` real seconds.
var _hitstop_start_ms: int = 0
var _hitstop_end_ms: int = -100000


func hit_stop(duration: float = 0.05, scale: float = 0.05) -> void:
	var now := Time.get_ticks_msec()
	duration = minf(duration, HITSTOP_MAX)
	if _hitstop_until_ms == 0:
		# not frozen: skip tiny freezes that would land right after the last one (feels laggy)
		if now - _hitstop_end_ms < HITSTOP_GRACE_MS and duration < 0.08:
			return
		_hitstop_start_ms = now
	var until := mini(now + int(duration * 1000.0), _hitstop_start_ms + int(HITSTOP_MAX * 1000.0))
	if until > _hitstop_until_ms:
		_hitstop_until_ms = until
	Engine.time_scale = minf(Engine.time_scale, scale)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func screen_flash(color: Color = Color(1, 1, 1, 0.6), duration: float = 0.12) -> void:
	_flash_color = color
	_flash_dur = duration
	_flash_t = duration


# ------------------------------------------------------------------ barks

## Pops a pixel speech bubble above `target`.
## style: "hamster" | "rat" | "boss" | "system"
## Returns true if a bubble was shown (respects per-target cooldown unless force).
func bark(target: Node2D, text: String, style: String = "hamster", force: bool = false, cooldown: float = 2.5) -> bool:
	if not is_instance_valid(bark_layer) or not is_instance_valid(target):
		return false
	var now := Time.get_ticks_msec()
	if not force:
		var last: int = target.get_meta("_last_bark_ms", -100000)
		if now - last < int(cooldown * 1000.0):
			return false
		if style == "rat":
			if now - _last_global_rat_bark_ms < 900:
				return false
			if _count_active("rat") >= MAX_ACTIVE_RAT_BARKS:
				return false
	# a target only keeps one bubble
	for b in _pool:
		if is_instance_valid(b) and b.active and b.target == target:
			b.finish()
	var bubble = _get_bubble()
	if bubble == null:
		return false
	target.set_meta("_last_bark_ms", now)
	if style == "rat":
		_last_global_rat_bark_ms = now
	bubble.show_bark(target, text, style)
	return true


## Bark at a fixed world position (no follow).
func bark_at(pos: Vector2, text: String, style: String = "system") -> void:
	if not is_instance_valid(bark_layer):
		return
	var bubble = _get_bubble()
	if bubble:
		bubble.show_bark(null, text, style, pos)


func _count_active(style: String) -> int:
	var n := 0
	for b in _pool:
		if is_instance_valid(b) and b.active and b.style == style:
			n += 1
	return n


func _get_bubble():
	for b in _pool:
		if is_instance_valid(b) and not b.active:
			return b
	if _pool.size() < POOL_SIZE:
		var nb = BarkBubbleScript.new()
		bark_layer.add_child(nb)
		_pool.append(nb)
		return nb
	# steal the oldest
	var oldest = null
	for b in _pool:
		if is_instance_valid(b) and (oldest == null or b.age > oldest.age):
			oldest = b
	if oldest:
		oldest.finish()
	return oldest
