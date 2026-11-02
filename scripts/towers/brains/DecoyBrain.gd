extends TowerBrain
## Cardboard Decoy Hamster: a crudely painted cutout with googly eyes. Every rat inside its taunt
## radius drops what it's doing to chew on it (handled by arena.taunting_decoy). No attack.
## Mutation "decoy_confetti": bursts into confetti shrapnel when chewed apart.
## Sugar Rush: self-repairs, taunts from further away and the eyes spin like mad.

const EYE_L := Vector2(-2.5, -15.5)
const EYE_R := Vector2(3.5, -15.5)
const BARKS := [
	"I AM DEFINITELY A REAL HAMSTER.",
	"Squeak. Squeak. (cardboard noises)",
	"Come chew these totally real cheeks!",
	"Ow. That is my real fur. Ow.",
]

var _off := [Vector2.ZERO, Vector2.ZERO]
var _vel := [Vector2.ZERO, Vector2.ZERO]
var _wob := 0.0
var _wob_v := 0.0
var _t := 0.0
var _bark_cd := 6.0


func draws_base() -> bool:
	return false


func taunt_radius() -> float:
	return tower.range_radius() * (1.4 if tower.is_overdrive() else 1.0)


func physics(delta: float) -> void:
	_t += delta
	_bark_cd = maxf(0.0, _bark_cd - delta)
	# look at the nearest rat
	var look := Vector2.ZERO
	var near = GameManager.arena.nearest_enemy(tower.global_position, taunt_radius())
	if near != null:
		look = (near.global_position - tower.global_position).normalized() * 1.1
	for i in 2:
		var target: Vector2 = look + Vector2(0, 0.5)
		if tower.is_overdrive():
			target = Vector2.from_angle(_t * 14.0 + i * PI) * 1.3
		var v: Vector2 = _vel[i]
		var o: Vector2 = _off[i]
		v += (target - o) * 55.0 * delta
		v *= maxf(0.0, 1.0 - 5.0 * delta)
		o += v * delta
		if o.length() > 1.4:
			o = o.normalized() * 1.4
			v = v.bounce(o.normalized()) * 0.6
		_vel[i] = v
		_off[i] = o
	# body wobble spring
	_wob_v += -_wob * 140.0 * delta
	_wob_v *= maxf(0.0, 1.0 - 6.0 * delta)
	_wob += _wob_v * delta
	if tower.is_overdrive():
		tower.repair(0.05 * delta)
	# taunting chatter while being chewed
	if _bark_cd <= 0.0 and near != null and near.global_position.distance_to(tower.global_position) < 18.0:
		_bark_cd = randf_range(14.0, 22.0)
		JuiceManager.bark(tower, BARKS[randi() % BARKS.size()], "hamster", false, 8.0)


func on_damaged(_amount: float) -> void:
	_wob_v += randf_range(-7.0, 7.0)
	for i in 2:
		_vel[i] = _vel[i] + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 45.0)


func on_overdrive() -> void:
	JuiceManager.bark(tower, "LOOK AT ME! LOOK AT ME!", "hamster", true)


func on_destroyed() -> void:
	var arena = GameManager.arena
	if arena == null:
		return
	var pos := tower.global_position
	# the cutout falls flat on its back
	var flat := Sprite2D.new()
	flat.texture = PixelArt.tex("tower_decoy_%d" % tower.level)
	flat.centered = false
	flat.offset = Vector2(-10, -25)
	flat.position = pos + Vector2(0, 2)
	arena.hazards.add_child(flat)
	var tw := flat.create_tween()
	tw.tween_property(flat, "scale", Vector2(1.1, 0.22), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(flat, "scale", Vector2(1.0, 0.3), 0.08)
	tw.tween_interval(5.0)
	tw.tween_property(flat, "modulate:a", 0.0, 1.5)
	tw.tween_callback(flat.queue_free)
	arena.fx.dust(pos, 10)
	arena.fx.float_text(pos + Vector2(0, -20), "THWAP!", PixelArt.C["t"], 0.9, 10.0)
	Sfx.play("build", 0.6, -2.0)
	if GameManager.gstats.has_flag("decoy_confetti"):
		var cols := [PixelArt.C["r"], PixelArt.C["y"], PixelArt.C["u"], PixelArt.C["p"], PixelArt.C["Z"], PixelArt.C["v"]]
		var n := 20
		for i in n:
			var dir := Vector2.from_angle(TAU * i / n + randf_range(-0.08, 0.08))
			arena.shots.fire(pos + Vector2(0, -10), dir * randf_range(170.0, 240.0), 8.0 * tower.damage_mult(), {
				"kind": "confetti", "life": 0.5, "radius": 3.0, "pierce": 1, "knockback": 50.0,
				"color": cols[i % cols.size()]})
		arena.fx.confetti(pos + Vector2(0, -10), 40)
		arena.fx.ring(pos + Vector2(0, -8), 40.0, PixelArt.C["p"], 0.3)
		JuiceManager.add_trauma(0.3)
		Sfx.play("spit", 1.5, -4.0)


func draw(ci: Node2D) -> void:
	# cardboard prop-stand behind the cutout
	ci.draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(9, 1), Vector2(3, -12)]), PixelArt.C["T"])
	ci.draw_line(Vector2(1, 1), Vector2(3, -12), PixelArt.C["B"], 1.0)
	ci.draw_rect(Rect2(-8, 0, 17, 2), Color(0, 0, 0, 0.25))
	# the cutout (wobbles around its feet)
	ci.draw_set_transform(Vector2(0, 1), _wob * 0.08, Vector2.ONE)
	ci.draw_texture(PixelArt.tex("tower_decoy_%d" % tower.level), Vector2(-10, -25))
	for i in 2:
		var c := (EYE_L if i == 0 else EYE_R) + Vector2(0, -1)
		PixelArt.draw_disk(ci, c, 3.0, PixelArt.C["k"])
		PixelArt.draw_disk(ci, c, 2.3, Color.WHITE)
		var o: Vector2 = _off[i]
		ci.draw_rect(Rect2((c + o - Vector2(1, 1)).round(), Vector2(2, 2)), PixelArt.C["k"])
		ci.draw_rect(Rect2((c + Vector2(-1, -2)).round(), Vector2(1, 1)), Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# taunt pulse
	var pulse := fmod(_t * 0.8, 1.0)
	if tower.is_overdrive() or pulse < 0.5:
		var r := taunt_radius() * (0.3 + 0.7 * pulse) if not tower.is_overdrive() else taunt_radius() * pulse
		var col := Color(1.0, 0.59, 0.71, 0.35 * (1.0 - pulse))
		PixelArt.draw_ring(ci, Vector2(0, -6), r, col, maxi(24, int(r * 1.2)))
