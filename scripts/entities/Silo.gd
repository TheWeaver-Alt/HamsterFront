class_name Silo
extends StaticBody2D
## The Great Silo: a legendary plastic bucket overflowing with striped seeds.
## HP lives in GameManager; this node handles collision, hits and drawing.

const SIZE := Vector2(56, 44)

var bubble_height := 46.0
var _flash := 0.0
var _wobble := 0.0
var _t := 0.0
var _seed_specks: Array = []


func _ready() -> void:
	collision_layer = Defs.L_SILO
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = SIZE
	cs.shape = sh
	add_child(cs)
	add_to_group("silo")
	material = Defs.flash_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var x := rng.randf_range(-26.0, 26.0)
		var mound := 1.0 - absf(x) / 28.0
		var y := -22.0 - rng.randf_range(0.0, 12.0) * mound
		_seed_specks.append(Vector3(roundf(x), roundf(y), rng.randi_range(0, 2)))


func rect() -> Rect2:
	return Rect2(global_position - SIZE / 2.0, SIZE)


func distance_to_edge(p: Vector2) -> float:
	var r := rect()
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func closest_point(p: Vector2) -> Vector2:
	var r := rect()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


func contains_point(p: Vector2) -> bool:
	return rect().has_point(p)


func is_alive() -> bool:
	return GameManager.silo_hp > 0.0


func take_damage(amount: float, _source = null) -> void:
	GameManager.damage_silo(amount)
	_flash = 0.12
	_wobble = minf(_wobble + 0.25, 1.0)
	if randf() < 0.35:
		JuiceManager.burst(global_position + Vector2(randf_range(-20, 20), -26), Pal.SEED, 3, 50.0, 0.5, 2.0, 140.0)
	SFX.play("hurt", randf_range(1.6, 1.9), -12.0, 120)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_wobble = maxf(0.0, _wobble - delta * 2.0)
	(material as ShaderMaterial).set_shader_parameter("flash", 1.0 if _flash > 0.0 else 0.0)
	queue_redraw()


func _draw() -> void:
	var wob := roundf(sin(_t * 40.0) * 2.0 * _wobble)
	var o := Vector2(wob, 0)
	# Shadow.
	draw_rect(Rect2(o.x - 30, 18, 60, 6), Pal.SHADOW)
	# Bucket body (tapered plastic): stacked rects.
	var body := Color("3a7bd5")
	var body_dark := Color("2a5aa0")
	var body_light := Color("6aa6ff")
	for row in 38:
		var y := -18 + row
		var half := 29 - int(row / 6.0)
		draw_rect(Rect2(o.x - half, y, half * 2, 1), body)
		draw_rect(Rect2(o.x - half, y, 3, 1), body_dark)
		draw_rect(Rect2(o.x + half - 3, y, 3, 1), body_dark)
		draw_rect(Rect2(o.x - half + 5, y, 2, 1), body_light)
	# Ribs.
	for ry in [-6, 6]:
		draw_rect(Rect2(o.x - 28, float(ry), 56, 2), body_dark)
	# Rim.
	draw_rect(Rect2(o.x - 31, -21, 62, 4), body_light)
	draw_rect(Rect2(o.x - 31, -18, 62, 1), body_dark)
	# Handle.
	draw_arc(Vector2(o.x, -18), 26.0, PI, TAU, 18, Pal.METAL_DARK, 1.0)
	# Label.
	draw_rect(Rect2(o.x - 16, -10, 32, 12), Pal.WHITE)
	PixelFont.draw_centered(self, "SEEDS", Vector2(o.x, -7), Pal.ESPRESSO_RED)
	# Seed mound scales with silo health.
	var ratio := GameManager.silo_ratio()
	for s in _seed_specks:
		var v: Vector3 = s
		var y := -21.0 + (v.y + 21.0) * ratio
		if y > -21.0:
			continue
		var c := Pal.SEED if v.z < 2 else Pal.SEED_GOLD
		draw_rect(Rect2(o.x + v.x - 1, y, 2, 3), c)
		draw_rect(Rect2(o.x + v.x - 1, y + 1, 1, 1), Pal.SEED_STRIPE)
	if ratio > 0.0:
		draw_rect(Rect2(o.x - 28, -23, 56, 2), Pal.SEED)
	# Cracks when damaged.
	if ratio < 0.6:
		draw_line(Vector2(o.x - 10, -16), Vector2(o.x - 4, -4), Pal.INK, 1.0)
		draw_line(Vector2(o.x - 4, -4), Vector2(o.x - 8, 8), Pal.INK, 1.0)
	if ratio < 0.3:
		draw_line(Vector2(o.x + 14, -14), Vector2(o.x + 9, 0), Pal.INK, 1.0)
		draw_line(Vector2(o.x + 9, 0), Vector2(o.x + 16, 12), Pal.INK, 1.0)
