extends Node2D
## Dev tool: renders every procedural sprite + font sample, saves a screenshot, quits.
## Run: godot --path . res://tools/ArtPreview.tscn

const SPRITES := [
	"ham_head_0", "ham_head_2", "ham_head_4", "ham_head_6", "ham_head_8", "ham_head_dizzy",
	"brawler_body_0", "brawler_body_1", "brawler_dome", "brawler_gun", "brawler_fist",
	"brawler_torso", "brawler_legs_idle", "brawler_legs_0", "brawler_legs_1", "brawler_legs_2",
	"brawler_legs_3", "brawler_legs_4", "brawler_legs_5", "brawler_legs_down", "brawler_dome_crack",
	"brawler_gun_body", "brawler_fist_smear", "porthole_wheel_0", "porthole_wheel_1", "porthole_wheel_2",
	"porthole_wheel_3", "jetpack_bottle", "jet_flame_0", "jet_flame_1", "jet_flame_2",
	"wheeler_ball", "wheeler_ham_0", "wheeler_ham_1", "wheeler_rails",
	"wheeler_ball_crack", "wheeler_hub", "wheeler_wheel_0", "wheeler_wheel_1", "wheeler_wheel_2",
	"wheeler_wheel_3", "wheeler_ham_2", "wheeler_ham_3", "wheeler_ham_idle", "wheeler_rail_housing",
	"wheeler_rail_barrel",
	"rat_squeaker_0", "rat_squeaker_1", "rat_squeaker_trip", "rat_squeaker_ball",
	"rat_sq_0_walk_0", "rat_sq_0_walk_1", "rat_sq_0_walk_2", "rat_sq_0_walk_3", "rat_sq_1_idle_1",
	"rat_sq_2_bite_0", "rat_sq_2_bite_1", "rat_sq_3_hit_0", "rat_sq_0_sneeze_1", "rat_sq_1_trip_0",
	"rat_sq_2_dead_0", "rat_sq_3_zap_0", "rat_sq_ghost_0",
	"rat_jez_walk_1", "rat_jez_aim_0", "rat_jez_fumble_0", "rat_jez_dead_0", "rat_jez_rifle_0",
	"rat_monk_walk_1", "rat_monk_chant_0", "rat_monk_dead_0", "rat_monk_ghost_0",
	"rat_roomba_1", "rat_roomba_wreck", "rat_ogre_walk_0", "rat_ogre_windup_0", "rat_ogre_smash_0",
	"rat_ogre_throw_0", "rat_ogre_dead_0", "rat_fx_flame_0",
	"tower_base_1", "tower_base_2", "tower_base_3", "tower_cracks_1", "tower_cracks_2",
	"tower_gatling_stem_1", "tower_gatling_stem_3", "tower_gatling_petals_1_0", "tower_gatling_petals_2_1",
	"tower_gatling_petals_3_2", "tower_gatling_barrels_1_0", "tower_gatling_barrels_3_1", "tower_gatling_2",
	"tower_laser_1_0", "tower_laser_2_1", "tower_laser_3_2", "tower_mortar_1", "tower_mortar_2", "tower_mortar_3",
	"tower_tesla_coil_1", "tower_tesla_coil_2", "tower_tesla_coil_3", "tesla_intern_0", "tesla_intern_1",
	"tesla_intern_2", "tesla_intern_3", "tower_decoy_1", "tower_decoy_2", "tower_decoy_3", "tower_decoy_1_d1",
	"tower_decoy_3_d2", "tower_debris_0", "tower_debris_1", "tower_debris_2", "tower_debris_3",
	"tower_rubble", "shell",
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
	PixelArt.draw_text_centered(self, Vector2(320, y + 40), "HAMSTERFRONT", Color8(255, 248, 231), true, 18)
	PixelArt.draw_bar(self, Rect2(4, y + 64, 80, 4), 0.6, Color8(226, 64, 64))
	PixelArt.draw_disk(self, Vector2(120, y + 70), 6, Color8(70, 210, 60))
	PixelArt.draw_box(self, Rect2(140, y + 60, 60, 16), Color8(255, 248, 231))
