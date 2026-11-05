extends Node
## CardDB — every roguelite upgrade card, its draft weight and modifier payload.
##
## Card fields:
##   id, name, tier ("mod" | "tower" | "synergy" | "cursed"), desc, downside (cursed only),
##   weight, max (stack cap), min_wave, coop (true = co-op only), chassis ("" or a Chassis id), not_chassis (an Array of Chassis ids that never see the card),
##   mods  -> applied to the picking player's StatBlock   {"add":{}, "mul":{}, "flags":[]}
##   gmods -> applied to GameManager.gstats (towers / whole team)
##   on_pick -> optional hook name handled in apply_card()
##
## Player stat keys (see the stats in scripts/mech/Chassis.gd): max_hp, move_speed, sprint_mult, damage_mult,
##   fire_rate_mult, pierce, extra_projectiles, pouch_capacity, pouch_slow, pickup_radius,
##   heat_rate, heat_decay, heat_weight, alt_damage_mult, alt_size_mult, spit_damage_mult, revive_speed,
##   lifesteal, seed_leak, damage_taken, vent_heal, spinout_bonus
##   (price is not a field: it comes from the card's arrows, see price())
## Player flags: no_overheat, forbidden_brie, warp_invert, rat_magnet
## Global flags: gatling_flaming, laser_split, decoy_confetti, jumper_cables, blood_brothers,
##   buddy_system, shared_cheeks

## What a card costs in seeds once the free pick is used (ADR-0002 item 5). The price follows the arrows on the
## card's face (CardFaces), so a child sees "more arrows, dearer". Cursed cards are cheap: they hurt as well.
const PRICE_BY_POWER := {1: 10, 2: 20, 3: 35}
const PRICE_CURSED := {1: 5, 2: 10, 3: 20}

const TIER_COLORS := {
	"mod": Color8(150, 220, 255),
	"tower": Color8(255, 150, 70),
	"synergy": Color8(255, 150, 180),
	"cursed": Color8(170, 255, 100),
}
const TIER_NAMES := {
	"mod": "MECH MOD",
	"tower": "TOWER BLUEPRINT",
	"synergy": "CO-OP SYNERGY",
	"cursed": "WARP-CHEESE CORRUPTION",
}

var cards: Array = [
	# ---------------------------------------------------------------- MECH MODS
	{"id": "toothpick_pierce", "tier": "mod", "name": "+25% TOOTHPICK PIERCING", "weight": 10, "max": 3,
		"desc": "SHOTS PIERCE +1 RAT AND HIT 25% HARDER.",
		"mods": {"add": {"pierce": 1}, "mul": {"damage_mult": 1.25}}},
	{"id": "wd40", "tier": "mod", "name": "WD-40 BEARINGS", "weight": 8, "max": 1,
		"desc": "NO WHEEL OVERHEAT. SPRINT FOREVER.",
		"mods": {"flags": ["no_overheat"]}},
	{"id": "titanium_cheeks", "tier": "mod", "name": "TITANIUM CHEEK LINERS", "weight": 10, "max": 3,
		"desc": "+50% POUCH CAPACITY.",
		"mods": {"mul": {"pouch_capacity": 1.5}}},
	{"id": "espresso", "tier": "mod", "name": "ESPRESSO DRIP FEED", "weight": 10, "max": 4,
		"desc": "+20% FIRE RATE. JITTERY PAWS.",
		"mods": {"mul": {"fire_rate_mult": 1.2}}},
	{"id": "duct_tape", "tier": "mod", "name": "EXTRA DUCT TAPE", "weight": 10, "max": 4,
		"desc": "+40 MAX HP AND A FULL REPAIR.",
		"mods": {"add": {"max_hp": 40}}, "on_pick": "heal_full"},
	{"id": "big_fist", "tier": "mod", "name": "HYDRAULIC TUBE UPGRADE", "weight": 8, "max": 3,
		"desc": "+60% ALT-ATTACK DAMAGE, 30% BIGGER.",
		"mods": {"mul": {"alt_damage_mult": 1.6, "alt_size_mult": 1.3}}},
	{"id": "fridge_magnet", "tier": "mod", "name": "FRIDGE MAGNET", "weight": 9, "max": 2,
		"desc": "+100% SEED VACUUM RADIUS.",
		"mods": {"mul": {"pickup_radius": 2.0}}},
	{"id": "turbo_treads", "tier": "mod", "name": "TURBO TREADS", "weight": 10, "max": 3,
		"desc": "+15% MOVE SPEED.",
		"mods": {"mul": {"move_speed": 1.15}}},
	{"id": "extra_barrel", "tier": "mod", "name": "EXTRA BARREL", "weight": 7, "max": 3,
		"desc": "+2 PROJECTILES PER SHOT.",
		"mods": {"add": {"extra_projectiles": 2}}},
	{"id": "cheek_hydraulics", "tier": "mod", "name": "CHEEK HYDRAULICS", "weight": 8, "max": 2,
		"desc": "FULL-POUCH SLOWDOWN HALVED.",
		"mods": {"mul": {"pouch_slow": 0.5}}},
	{"id": "overclocked_wheel", "tier": "mod", "name": "OVERCLOCKED WHEEL", "weight": 8, "max": 2,
		"desc": "+35% SPRINT SPEED. WHEEL HEATS 20% FASTER.",
		"mods": {"add": {"sprint_mult": 0.35}, "mul": {"heat_rate": 1.2}}},
	{"id": "spit_polish", "tier": "mod", "name": "SPIT POLISH", "weight": 7, "max": 3,
		"desc": "POUCH SPIT BLAST DEALS +100% DAMAGE.",
		"mods": {"mul": {"spit_damage_mult": 2.0}}},
	{"id": "vampire_sunflower", "tier": "mod", "name": "VAMPIRE SUNFLOWER", "weight": 7, "max": 3,
		"desc": "EVERY KILL HEALS 1 HP.",
		"mods": {"add": {"lifesteal": 1}}},
	{"id": "radiator_fins", "tier": "mod", "name": "RADIATOR FINS", "weight": 8, "max": 2,
		"desc": "WHEEL COOLS 60% FASTER. VENTING HEALS 10 HP.",
		"mods": {"mul": {"heat_decay": 1.6}, "add": {"vent_heal": 10}}},
	{"id": "jetpack", "tier": "mod", "name": "SODA-BOTTLE JETPACK", "weight": 11, "max": 1, "not_chassis": ["drone"],
		"desc": "SPRINT INTO A CLIFF (OR PRESS JUMP) TO ROCKET UP OR DOWN IT.",
		"mods": {"flags": ["jetpack"]}},
	{"id": "bubble_wrap", "tier": "mod", "name": "BUBBLE WRAP ARMOR", "weight": 8, "max": 3,
		"desc": "TAKE 20% LESS DAMAGE. POP POP.",
		"mods": {"mul": {"damage_taken": 0.8}}},

	# ---------------------------------------------------------------- TOWER BLUEPRINTS & MUTATIONS
	{"id": "flaming_hulls", "tier": "tower", "name": "FLAMING HULLS", "weight": 7, "max": 1,
		"desc": "GATLING TURRETS NOW FIRE FLAMING HULLS THAT SET RATS ABLAZE.",
		"gmods": {"flags": ["gatling_flaming"]}},
	{"id": "prismatic", "tier": "tower", "name": "PRISMATIC REFRACTION", "weight": 7, "max": 1,
		"desc": "WATER LASERS SPLIT INTO 3 BEAMS WHEN HITTING A FRIENDLY MECH.",
		"gmods": {"flags": ["laser_split"]}},
	{"id": "sneezy", "tier": "tower", "name": "EXTRA-SNEEZY SHAVINGS", "weight": 7, "max": 2,
		"desc": "MORTAR BLASTS +50% RADIUS AND STUN +0.5S LONGER.",
		"gmods": {"mul": {"mortar_radius_mult": 1.5}, "add": {"mortar_stun_bonus": 0.5}}},
	{"id": "static_cling", "tier": "tower", "name": "STATIC CLING", "weight": 7, "max": 2,
		"desc": "TESLA LIGHTNING CHAINS TO +2 MORE RATS.",
		"gmods": {"add": {"tesla_chain_bonus": 2}}},
	{"id": "googly", "tier": "tower", "name": "GOOGLIER EYES", "weight": 6, "max": 1,
		"desc": "DECOYS +100% HP AND BURST INTO CONFETTI SHRAPNEL WHEN CHEWED APART.",
		"gmods": {"mul": {"decoy_hp_mult": 2.0}, "flags": ["decoy_confetti"]}},
	{"id": "bulk_discount", "tier": "tower", "name": "BULK DISCOUNT COUPON", "weight": 7, "max": 2,
		"desc": "ALL TOWERS AND UPGRADES COST 20% LESS.",
		"gmods": {"mul": {"tower_cost_mult": 0.8}}},
	{"id": "sugar_insurance", "tier": "tower", "name": "SUGAR CRASH INSURANCE", "weight": 6, "max": 2,
		"desc": "SUGAR RUSH OVERDRIVE LASTS +5 SECONDS.",
		"gmods": {"add": {"overdrive_duration": 5.0}}},
	{"id": "hull_avalanche", "tier": "tower", "name": "HULL AVALANCHE", "weight": 6, "max": 2,
		"desc": "SHELL PILES SLOW TWICE AS HARD AND LAST 50% LONGER.",
		"gmods": {"mul": {"shell_slow_mult": 2.0, "shell_life_mult": 1.5}}},
	{"id": "reinforced", "tier": "tower", "name": "REINFORCED CARDBOARD", "weight": 7, "max": 2,
		"desc": "TOWERS +50% HP AND REPAIR 25% AFTER EACH WAVE.",
		"gmods": {"mul": {"tower_hp_mult": 1.5}, "add": {"tower_wave_repair": 0.25}}},
	{"id": "magnifier", "tier": "tower", "name": "MAGNIFYING GLASS", "weight": 7, "max": 2,
		"desc": "+20% RANGE FOR ALL TOWERS.",
		"gmods": {"mul": {"tower_range_mult": 1.2}}},
	{"id": "salted_seeds", "tier": "tower", "name": "SALTED SEEDS", "weight": 7, "max": 3,
		"desc": "+25% DAMAGE FOR ALL TOWERS.",
		"gmods": {"mul": {"tower_damage_mult": 1.25}}},

	# ---------------------------------------------------------------- CO-OP SYNERGY
	{"id": "jumper_cables", "tier": "synergy", "name": "JUMPER CABLES", "weight": 8, "max": 1, "coop": true,
		"desc": "AN ELECTRIC TETHER CONNECTS P1 AND P2, FRYING ANY RAT THAT WALKS BETWEEN THEM.",
		"gmods": {"flags": ["jumper_cables"]}},
	{"id": "blood_brothers", "tier": "synergy", "name": "BLOOD BROTHERS", "weight": 8, "max": 1, "coop": true,
		"desc": "WHEN ONE PLAYER VENTS WHEEL STEAM, THE OTHER GETS +50% FIRE RATE FOR 6S.",
		"gmods": {"flags": ["blood_brothers"]}},
	{"id": "buddy_system", "tier": "synergy", "name": "BUDDY SYSTEM", "weight": 8, "max": 1, "coop": true,
		"desc": "STAY CLOSE: +25% DAMAGE AND 2 HP/S REGEN WHILE NEAR YOUR PARTNER.",
		"gmods": {"flags": ["buddy_system"]}},
	{"id": "communal_cheeks", "tier": "synergy", "name": "COMMUNAL CHEEKS", "weight": 7, "max": 1, "coop": true,
		"desc": "SEEDS YOU VACUUM ALSO TRICKLE INTO YOUR PARTNER'S POUCH. REVIVES 2X FASTER.",
		"gmods": {"flags": ["shared_cheeks"]}},

	# ---------------------------------------------------------------- WARP-CHEESE CORRUPTIONS
	{"id": "forbidden_brie", "tier": "cursed", "name": "EAT THE FORBIDDEN BRIE", "weight": 4, "max": 1, "min_wave": 2,
		"desc": "+100% MECH DAMAGE.",
		"downside": "YOUR HAMSTER HALLUCINATES GIANT SHADOWY CATS PROWLING THE SCREEN EDGES.",
		"mods": {"mul": {"damage_mult": 2.0}, "flags": ["forbidden_brie"]}},
	{"id": "warp_gouda", "tier": "cursed", "name": "HUFF THE WARP-GOUDA", "weight": 4, "max": 1, "min_wave": 2,
		"desc": "+50% MOVE SPEED.",
		"downside": "EVERY SO OFTEN YOUR CONTROLS INVERT FOR 2 SECONDS.",
		"mods": {"mul": {"move_speed": 1.5}, "flags": ["warp_invert"]}},
	{"id": "gorgonzola", "tier": "cursed", "name": "GORGONZOLA OVERCLOCK", "weight": 4, "max": 1, "min_wave": 3,
		"desc": "+100% TOWER FIRE RATE.",
		"downside": "TOWERS TAKE DOUBLE DAMAGE.",
		"gmods": {"mul": {"tower_fire_rate_mult": 2.0, "tower_damage_taken_mult": 2.0}}},
	{"id": "moldy_muenster", "tier": "cursed", "name": "MOLDY MUENSTER", "weight": 4, "max": 1, "min_wave": 2,
		"desc": "+80 MAX HP AND +30% DAMAGE.",
		"downside": "YOUR CHEEKS LEAK 1 SEED PER SECOND.",
		"mods": {"add": {"max_hp": 80, "seed_leak": 1}, "mul": {"damage_mult": 1.3}}, "on_pick": "heal_full"},
	{"id": "wheel_of_unreason", "tier": "cursed", "name": "WHEEL OF UNREASON", "weight": 4, "max": 1, "min_wave": 3,
		"desc": "+60% FIRE RATE.",
		"downside": "WHEEL OVERHEATS 2X FASTER AND SPINOUTS LAST LONGER.",
		"mods": {"mul": {"fire_rate_mult": 1.6, "heat_rate": 2.0}, "add": {"spinout_bonus": 1.0}}},
	{"id": "squeaky_breath", "tier": "cursed", "name": "SQUEAKY BRIE BREATH", "weight": 4, "max": 1, "min_wave": 2,
		"desc": "RATS DROP +50% SEEDS.",
		"downside": "NEARBY RATS SMELL YOU AND CHASE YOU INSTEAD OF THE SILO.",
		"mods": {"flags": ["rat_magnet"]}, "gmods": {"mul": {"seed_drop_mult": 1.5}}},
]

var _by_id: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for c in cards:
		_by_id[c["id"]] = c


func get_card(id: String) -> Dictionary:
	return _by_id.get(id, {})


func tier_color(tier: String) -> Color:
	return TIER_COLORS.get(tier, Color.WHITE)


## Seeds this card costs at the vending machine after a pilot's free pick.
func price(card: Dictionary) -> int:
	var power := clampi(int(CardFaces.of(card).get("power", 1)), 1, 3)
	return int(PRICE_CURSED[power] if card.get("tier", "") == "cursed" else PRICE_BY_POWER[power])


func _is_global(card: Dictionary) -> bool:
	return not card.has("mods")


## How many times this card is held: per-player for player-scoped cards, team-wide otherwise.
func times_owned(card: Dictionary, player) -> int:
	if _is_global(card) or player == null:
		return int(GameManager.owned_cards.get(card["id"], 0))
	return int(player.owned_cards.get(card["id"], 0))


func is_eligible(card: Dictionary, player) -> bool:
	if card.get("coop", false) and not GameManager.is_coop():
		return false
	if GameManager.wave < int(card.get("min_wave", 0)):
		return false
	var ch: String = card.get("chassis", "")
	if ch != "" and player != null and player.chassis != ch:
		return false
	var banned: Array = card.get("not_chassis", [])
	if player != null and banned.has(player.chassis):
		return false
	if times_owned(card, player) >= int(card.get("max", 99)):
		return false
	return true


## Weighted draw of `count` distinct cards for a player. `exclude` = ids already offered elsewhere.
func roll_hand(player, count: int = 3, exclude: Array = []) -> Array:
	var pool: Array = []
	for c in cards:
		if exclude.has(c["id"]) and (c["tier"] == "synergy" or _is_global(c)):
			continue
		if is_eligible(c, player):
			pool.append(c)
	var hand: Array = []
	while hand.size() < count and pool.size() > 0:
		var total := 0.0
		for c in pool:
			total += _weight(c)
		var r := _rng.randf() * total
		var pick: Dictionary = pool[0]
		for c in pool:
			r -= _weight(c)
			if r <= 0.0:
				pick = c
				break
		hand.append(pick)
		pool.erase(pick)
	return hand


func _weight(card: Dictionary) -> float:
	var w := float(card.get("weight", 5))
	# corruptions get more common as the siege drags on
	if card["tier"] == "cursed":
		w *= 1.0 + 0.08 * GameManager.wave
	# the jetpack opens up the high ground: offer it often early on
	if card["id"] == "jetpack" and GameManager.wave <= 3:
		w *= 3.0
	return w


## Applies a card to `player` (and/or the team) and records ownership.
func apply_card(card: Dictionary, player) -> void:
	if card.has("mods") and player != null:
		player.stats.apply_mods(card["mods"])
	if card.has("gmods"):
		GameManager.gstats.apply_mods(card["gmods"])
	GameManager.owned_cards[card["id"]] = int(GameManager.owned_cards.get(card["id"], 0)) + 1
	if player != null:
		player.owned_cards[card["id"]] = int(player.owned_cards.get(card["id"], 0)) + 1
		match String(card.get("on_pick", "")):
			"heal_full":
				player.heal(9999.0)
		if player.has_method("on_card_applied"):
			player.on_card_applied(card)
	if is_instance_valid(GameManager.arena) and GameManager.arena.has_method("on_card_applied"):
		GameManager.arena.on_card_applied(card, player)
