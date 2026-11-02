extends Node2D
## Dev tool: renders every procedural sprite + font sample, saves a screenshot, quits.
## Run: godot --path . res://tools/ArtPreview.tscn

const SPRITES := [
	"ham_head_0", "ham_head_2", "ham_head_4", "ham_head_6", "ham_head_8", "ham_head_dizzy",
	"brawler_body_0", "brawler_body_1", "brawler_dome", "brawler_gun", "brawler_fist",
	"wheeler_ball", "wheeler_ham_0", "wheeler_ham_1", "wheeler_rails",
	"rat_squeaker_0", "rat_squeaker_1", "rat_squeaker_trip", "rat_squeaker_ball",
	"tower_base", "tower_gatling", "tower_rubble", "shell",
	"seed", "seed_h", "seed_icon", "silo_bucket", "obstacle_pot", "obstacle_rock", "obstacle_gnome", "obstacle_can",
	"icon_heart", "icon_heat", "icon_skull",
	"tile_grass_0", "tile_grass_1", "tile_grass_2", "tile_grass_3", "tile_flowers_0", "tile_flowers_1",
	"tile_path_0", "tile_path_1", "tile_path_2", "tile_pad", "tile_burrow", "tile_fence", "tile_dirt",
]
var frame := 0
var extra: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		extra.append(a)

func _process(_d: float) -> void:
	frame += 1
	queue_redraw()
	if frame == 6:
		var img := get_viewport().get_texture().get_image()
		var out := "res://screenshots/art_preview.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
		img.save_png(out)
		print("saved ", out, " ", img.get_size())
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color8(40, 30, 50))
	var x := 4.0
	var y := 4.0
	var row_h := 0.0
	for s in SPRITES:
		var t := PixelArt.tex(s)
		var sz := t.get_size()
		if x + sz.x > 636:
			x = 4
			y += row_h + 4
			row_h = 0
		draw_texture(t, Vector2(x, y))
		x += sz.x + 4
		row_h = maxf(row_h, sz.y)
	y += row_h + 8
	PixelArt.draw_text(self, Vector2(4, y), "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 !?.,'-+:/%()[]#@&*=<>_$", Color.WHITE)
	PixelArt.draw_text_outlined(self, Vector2(4, y + 10), "Mmphf! Caffn't... ffit... mmore... sfeeds!", Color8(255, 214, 64))
	PixelArt.draw_text(self, Vector2(4, y + 22), "WITNESS MY FLUFFY WRATH!", Color8(255, 150, 70), 12)
	PixelArt.draw_text_centered(self, Vector2(320, y + 40), "DEFENCE OF HAMSTERLAND", Color8(255, 248, 231), true, 18)
	PixelArt.draw_bar(self, Rect2(4, y + 64, 80, 4), 0.6, Color8(226, 64, 64))
	PixelArt.draw_disk(self, Vector2(120, y + 70), 6, Color8(70, 210, 60))
	PixelArt.draw_box(self, Rect2(140, y + 60, 60, 16), Color8(255, 248, 231))
