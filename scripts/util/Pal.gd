class_name Pal
extends RefCounted
## Funky 16-bit palette shared by every procedural sprite.

const INK := Color("1a1423")
const INK_SOFT := Color("2e2538")
const WHITE := Color("f4f1de")
const SHADOW := Color(0.0, 0.0, 0.0, 0.32)

const GRASS_A := Color("4f8a3c")
const GRASS_B := Color("5c9a45")
const GRASS_DARK := Color("3b6e2e")
const GRASS_LIGHT := Color("7cb85a")
const STONE := Color("8e8a99")
const STONE_DARK := Color("6a6677")
const STONE_LIGHT := Color("aaa6b5")
const DIRT := Color("7a5236")
const DIRT_DARK := Color("5a3a26")
const WOOD := Color("a0683a")
const WOOD_DARK := Color("6e4224")
const WOOD_LIGHT := Color("c48a52")
const HEDGE := Color("2f5e2a")
const HEDGE_DARK := Color("1f4220")
const HEDGE_LIGHT := Color("4f8a3c")

const SEED := Color("2b2d42")
const SEED_STRIPE := Color("e8e8f0")
const SEED_GOLD := Color("ffd23f")

const WARP := Color("7cff4f")
const WARP_DARK := Color("2f8f2a")
const WARP_GLOW := Color(0.49, 1.0, 0.31, 0.5)

const RAT_FUR := Color("6b5b4f")
const RAT_FUR_DARK := Color("4a3d35")
const RAT_FUR_LIGHT := Color("8d7b6c")
const RAT_PINK := Color("e08a9a")
const RUST := Color("9b5a2e")
const METAL := Color("8a8f9c")
const METAL_DARK := Color("4f5360")
const METAL_LIGHT := Color("c5cad6")

const HAMSTER := Color("e0a060")
const HAMSTER_LIGHT := Color("f2c890")
const HAMSTER_PINK := Color("f08ca0")
const GLASS := Color(0.62, 0.86, 0.95, 0.42)
const GLASS_EDGE := Color(0.85, 0.96, 1.0, 0.85)

const ESPRESSO_RED := Color("b0303c")
const ESPRESSO_DARK := Color("6e1c26")
const CARDBOARD := Color("c49a62")
const CARDBOARD_DARK := Color("8e6a3e")
const TAPE := Color("b8b8c0")
const TOOTHPICK := Color("f0d9a0")
const COPPER := Color("d08040")

const SUNFLOWER := Color("ffc93c")
const SUNFLOWER_DARK := Color("d48a1a")
const WATER := Color(0.45, 0.75, 1.0, 0.75)
const BEAM := Color("bff4ff")
const CEDAR := Color("d9b07a")
const SNEEZE := Color("f0dca8")
const TESLA := Color("9fd8ff")
const SUGAR := Color("ff7ac8")
const FIRE := Color("ff8a2a")
const FIRE_HOT := Color("ffe14f")
const GAS := Color(0.45, 0.8, 0.2, 0.35)
const BLOOD_BAR := Color("d63c4a")
const HP_GREEN := Color("6ee06a")
const HEAT := Color("ff6a3a")
const STEAM := Color(0.92, 0.94, 1.0, 0.8)

const P1 := Color("ff6b5a")
const P2 := Color("4fc8ff")

const TIER_MOD := Color("8fb3ff")
const TIER_TOWER := Color("ffaa44")
const TIER_COOP := Color("ff7ac8")
const TIER_CURSED := Color("7cff4f")


static func player_color(pid: int) -> Color:
	return P1 if pid == 1 else P2


static func tier_color(tier: String) -> Color:
	match tier:
		"tower":
			return TIER_TOWER
		"coop":
			return TIER_COOP
		"cursed":
			return TIER_CURSED
	return TIER_MOD
