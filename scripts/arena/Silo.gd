extends StaticBody2D
## The Great Silo: a plastic bucket overflowing with premium striped sunflower seeds.
## The seed mound visibly shrinks as the Silo's HP drops.

const MOUND_SEEDS := 190
const MOUND_R := 25.0

var _mound: Array = []     # [Vector2 pos, bool horizontal]
var _flash := 0.0
var _bump := 0.0
var _shake := 0.0


func _ready() -> void:
	collision_layer = GameManager.L_WORLD
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ArenaMap.SILO_RADIUS - 2.0
	cs.shape = shape
	cs.position = ArenaMap.SILO_CENTER - position
	add_child(cs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in MOUND_SEEDS:
		var a := rng.randf_range(PI, TAU)
		var r := sqrt(rng.randf()) * MOUND_R
		var p := Vector2(cos(a) * r, sin(a) * r * 0.75)
		_mound.append([p, rng.randf() < 0.5])
	# bottom-most seeds first so the mound drains from the top
	_mound.sort_custom(func(x, y): return x[0].y > y[0].y)


func hit() -> void:
	_flash = 1.0
	_shake = 0.2


func bump() -> void:
	_bump = 1.0


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 6.0)
	_bump = maxf(0.0, _bump - delta * 4.0)
	_shake = maxf(0.0, _shake - delta)
	queue_redraw()


func _draw() -> void:
	var frac := GameManager.silo_hp / maxf(1.0, GameManager.silo_max_hp)
	var sh := Vector2.ZERO
	if _shake > 0.0:
		sh = Vector2(randi_range(-1, 1), 0)
	var squash := 1.0 + sin(_bump * PI) * 0.06
	draw_set_transform(sh, 0.0, Vector2(1.0 / squash, squash))
	# shadow
	draw_rect(Rect2(-26, -3, 52, 5), Color(0, 0, 0, 0.3))
	# seed mound
	var rim := Vector2(0, -40)
	var shown := int(MOUND_SEEDS * clampf(frac, 0.0, 1.0))
	var dark := PixelArt.C["s"]
	var light := PixelArt.C["S"]
	if shown > 0:
		draw_rect(Rect2(-22, -42, 44, 4), dark)
	for i in shown:
		var p: Vector2 = rim + _mound[i][0]
		p = p.round()
		if _mound[i][1]:
			draw_rect(Rect2(p, Vector2(3, 2)), dark)
			draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), light)
		else:
			draw_rect(Rect2(p, Vector2(2, 3)), dark)
			draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), light)
	# bucket
	var tint := Color.WHITE.lerp(Color(1, 0.5, 0.5), _flash)
	draw_texture(PixelArt.tex("silo_bucket"), Vector2(-28, -44), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# danger glow when low
	if frac < 0.3 and int(Time.get_ticks_msec() / 250) % 2 == 0:
		PixelArt.draw_ring(self, Vector2(0, -22), 34.0, Color(1, 0.25, 0.2, 0.7))
