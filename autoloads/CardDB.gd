extends Node
## Roguelite card definitions, tier weights, offer rolling and modifier application.
##
## Every card is a Dictionary:
##   id, name, desc, tier ("mod" | "tower" | "coop" | "cursed"),
##   mech ("any" | "brawler" | "wheeler"), scope ("player" | "global"),
##   unique (bool), weight (float), mods (Dictionary), callback (method name, optional).
## Mod keys ending in "_mult" multiply, bools are set, other numbers add.

const TIER_WEIGHTS := {"mod": 50.0, "tower": 30.0, "coop": 16.0, "cursed": 11.0}
const TIER_LABEL := {"mod": "MECH MOD", "tower": "BLUEPRINT", "coop": "CO-OP SYNERGY", "cursed": "WARP-CORRUPTION"}

var cards: Array = []


func _ready() -> void:
	_define_cards()


func _card(id: String, title: String, desc: String, tier: String, mods: Dictionary, opts: Dictionary = {}) -> Dictionary:
	var c := {
		"id": id, "name": title, "desc": desc, "tier": tier, "mods": mods,
		"mech": "any", "scope": "player" if tier == "mod" else "global",
		"unique": tier != "mod", "weight": 1.0, "callback": "",
	}
	for k in opts:
		c[k] = opts[k]
	return c


func _define_cards() -> void:
	cards = [
		# --- Mech Mods (standard) ---
		_card("toothpick_pierce", "+25% Toothpick Piercing",
			"Railguns skewer +1 extra rat and hit 25% harder.",
			"mod", {"pierce_bonus": 1, "rail_damage_mult": 1.25}, {"mech": "wheeler"}),
		_card("twin_feed", "Twin-Toothpick Feed",
			"Railguns fire 25% faster. Toothpicks everywhere.",
			"mod", {"fire_rate_mult": 1.25}, {"mech": "wheeler"}),
		_card("lighter_fluid", "Lighter-Fluid Rubber",
			"Burning rubber trails deal double damage.",
			"mod", {"trail_damage_mult": 2.0}, {"mech": "wheeler"}),
		_card("espresso", "Espresso Overclock",
			"Sawdust Shotgun pumps 30% faster. Double shot!",
			"mod", {"fire_rate_mult": 1.3}, {"mech": "brawler"}),
		_card("extra_sawdust", "Extra Sawdust",
			"+3 shotgun pellets per blast.",
			"mod", {"pellet_bonus": 3}, {"mech": "brawler"}),
		_card("fist_mk2", "Cardboard Fist Mk.II",
			"Tube Fist hits 60% harder and launches rats into orbit.",
			"mod", {"fist_damage_mult": 1.6, "knock_mult": 1.5}, {"mech": "brawler"}),
		_card("wd40", "WD-40 Bearings",
			"No Wheel Overheat. Sprint until the heat death of the yard.",
			"mod", {"no_overheat": true}, {"unique": true}),
		_card("titanium_cheeks", "Titanium Cheek Liners",
			"+50% Pouch Capacity.",
			"mod", {"pouch_capacity_mult": 1.5}),
		_card("spider_turbo", "Turbo Leg Grease",
			"+20% move speed.",
			"mod", {"speed_mult": 1.2}),
		_card("hoover", "Hoover Cheeks",
			"Seed vacuum range doubled.",
			"mod", {"magnet_mult": 2.0}, {"unique": true}),
		_card("duct_tape", "Duct Tape Plating",
			"+40 max HP and a full repair.",
			"mod", {"max_hp_bonus": 40.0}, {"callback": "_cb_full_heal"}),
		_card("prechewed", "Pre-Chewed Seeds",
			"Stuffed cheeks slow you 50% less.",
			"mod", {"pouch_slow_mult": 0.5}, {"unique": true}),
		_card("hot_sauce", "Hot Sauce Spit",
			"Pouch Spit deals double damage and sets rats ablaze.",
			"mod", {"spit_damage_mult": 2.0, "spit_fire": true}, {"unique": true}),
		_card("big_guns", "Bigger Bolts",
			"+20% mech damage. Bolts? Nails? Who cares.",
			"mod", {"damage_mult": 1.2}),

		# --- Tower Blueprints & Mutations ---
		_card("flaming_hulls", "Flaming Hulls",
			"Gatling Turrets now fire flaming hulls that set rats on fire.",
			"tower", {"flaming_hulls": true}),
		_card("prism", "Prism Bounce",
			"Water Lasers split into 3 beams when they hit a friendly Mech.",
			"tower", {"prism_lasers": true}),
		_card("double_bag", "Double-Bag Mortars",
			"Mortars lob 2 canisters with +30% blast radius.",
			"tower", {"mortar_double": true, "mortar_aoe_mult": 1.3}),
		_card("overclocked_coil", "Overclocked Coil",
			"Tesla lightning chains to +3 more rats.",
			"tower", {"tesla_chain_bonus": 3}, {"unique": false}),
		_card("corrugated", "Corrugated Decoys",
			"Decoys get double HP and explode into cardboard shrapnel when chewed apart.",
			"tower", {"decoy_hp_mult": 2.0, "decoy_explode": true}),
		_card("bulk", "Bulk Seed Discount",
			"All towers cost 25% less.",
			"tower", {"tower_cost_mult": 0.75}, {"unique": false}),
		_card("sugar_insurance", "Sugar Crash Insurance",
			"Sugar Rush Overdrive lasts 20 seconds instead of 10.",
			"tower", {"overdrive_duration": 10.0}),
		_card("shell_shock", "Shell Shock",
			"Gatling shell piles slow 60% and nibble rat toes.",
			"tower", {"shell_slow": 0.3, "shell_damage": 6.0}),
		_card("bubble_wrap", "Bubble-Wrap Armor",
			"Towers take 35% less damage.",
			"tower", {"tower_damage_taken_mult": 0.65}),

		# --- Co-op Synergy ---
		_card("jumper_cables", "Jumper Cables",
			"An electric tether connects P1 and P2, frying any rat that walks between them.",
			"coop", {"jumper_cables": true}),
		_card("blood_brothers", "Blood Brothers",
			"When one player vents wheel steam, the other gets +50% fire rate.",
			"coop", {"blood_brothers": true}),
		_card("buddy_system", "Buddy System",
			"Both mechs deal +25% damage while standing close together.",
			"coop", {"buddy_bounce": true}),
		_card("cheek_to_cheek", "Cheek-to-Cheek",
			"Banking seeds at the Silo also repairs both mechs.",
			"coop", {"cheek_share": true}),

		# --- Warp-Cheese Corruptions (cursed) ---
		_card("forbidden_brie", "Eat the Forbidden Brie",
			"+100% Mech Damage, but your hamster hallucinates giant shadowy cats prowling the screen edges.",
			"cursed", {"damage_mult": 2.0, "hallucinations": true}, {"scope": "player"}),
		_card("warp_fondue", "Warp-Cheese Fondue",
			"Towers fire 60% faster, but rats find them twice as chewable.",
			"cursed", {"tower_fire_rate_mult": 1.6, "tower_damage_taken_mult": 2.0}),
		_card("glowing_seeds", "Glowing Sunflower Seeds",
			"Rats drop double seeds, but they glow-run 25% faster.",
			"cursed", {"seed_value_mult": 2.0, "rat_speed_mult": 1.25}),
		_card("gouda_pact", "Pact of the Horned Gouda",
			"+80 seeds now and +25 every wave, but the Silo loses 25% max HP.",
			"cursed", {"wave_seed_bonus": 25}, {"callback": "_cb_gouda_pact"}),
		_card("caffeine_iv", "Caffeine IV Drip",
			"+40% speed and fire rate, but your wheel heats up 3x faster.",
			"cursed", {"speed_mult": 1.4, "fire_rate_mult": 1.4, "heat_rate_mult": 3.0}, {"scope": "player"}),
	]
	for c in cards:
		var d: Dictionary = c
		d["weight"] = float(TIER_WEIGHTS.get(d["tier"], 10.0))


func get_card(id: String) -> Dictionary:
	for c in cards:
		if c["id"] == id:
			return c
	return {}


func tier_label(tier: String) -> String:
	return String(TIER_LABEL.get(tier, "CARD"))


func mech_kind_for(pid: int) -> String:
	return "brawler" if pid == 1 else "wheeler"


## Rolls `count` distinct cards for a player.
func roll_offers(pid: int, count: int) -> Array:
	var coop_ok := GameManager.player_count() >= 2
	var offers: Array = []
	var attempts := 0
	while offers.size() < count and attempts < 80:
		attempts += 1
		var tier := _roll_tier(coop_ok)
		var pool := _eligible(pid, coop_ok, tier, offers)
		if pool.is_empty():
			pool = _eligible(pid, coop_ok, "", offers)
		if pool.is_empty():
			break
		offers.append(_weighted_pick(pool))
	return offers


func _roll_tier(coop_ok: bool) -> String:
	var total := 0.0
	for t in TIER_WEIGHTS:
		if t == "coop" and not coop_ok:
			continue
		total += float(TIER_WEIGHTS[t])
	var r := randf() * total
	for t in TIER_WEIGHTS:
		if t == "coop" and not coop_ok:
			continue
		r -= float(TIER_WEIGHTS[t])
		if r <= 0.0:
			return t
	return "mod"


func _is_taken(card: Dictionary, pid: int) -> bool:
	var id: String = card["id"]
	if card["scope"] == "global":
		for k in GameManager.taken_cards:
			if id in GameManager.taken_cards[k]:
				return true
		return false
	return id in GameManager.taken_cards.get(pid, [])


func _eligible(pid: int, coop_ok: bool, tier: String, exclude: Array) -> Array:
	var kind := mech_kind_for(pid)
	var out: Array = []
	for c in cards:
		var card: Dictionary = c
		if tier != "" and card["tier"] != tier:
			continue
		if card["tier"] == "coop" and not coop_ok:
			continue
		if card["mech"] != "any" and card["mech"] != kind:
			continue
		if card["unique"] and _is_taken(card, pid):
			continue
		var dup := false
		for e in exclude:
			if e["id"] == card["id"]:
				dup = true
				break
		if dup:
			continue
		out.append(card)
	return out


func _weighted_pick(pool: Array) -> Dictionary:
	var total := 0.0
	for c in pool:
		total += float(c["weight"])
	var r := randf() * total
	for c in pool:
		r -= float(c["weight"])
		if r <= 0.0:
			return c
	return pool[pool.size() - 1]


## Applies a card's modifier dictionary (and optional callback) for a player.
func apply_card(card: Dictionary, pid: int) -> void:
	if card.is_empty():
		return
	if card["unique"] and _is_taken(card, pid):
		# Both players grabbed the same global card in one draft; second copy fizzles.
		return
	var key := 0 if card["scope"] == "global" else pid
	if not GameManager.taken_cards.has(key):
		GameManager.taken_cards[key] = []
	GameManager.taken_cards[key].append(card["id"])
	if card["scope"] == "global":
		apply_mods(GameManager.global_mods, card["mods"])
	else:
		apply_mods(GameManager.player_mods[pid], card["mods"])
	var cb: String = card.get("callback", "")
	if cb != "" and has_method(cb):
		call(cb, pid)
	if GameManager.arena != null:
		GameManager.arena.on_card_applied(card, pid)


func apply_mods(target: Dictionary, mods: Dictionary) -> void:
	for key in mods:
		var v = mods[key]
		if not target.has(key):
			target[key] = v
			continue
		var cur = target[key]
		if typeof(cur) == TYPE_BOOL:
			target[key] = bool(v)
		elif String(key).ends_with("_mult"):
			target[key] = float(cur) * float(v)
		elif typeof(cur) == TYPE_INT and typeof(v) == TYPE_INT:
			target[key] = int(cur) + int(v)
		else:
			target[key] = float(cur) + float(v)


# --- Callbacks -----------------------------------------------------------------

func _cb_full_heal(pid: int) -> void:
	if GameManager.arena == null:
		return
	var m = GameManager.arena.get_mech(pid)
	if m != null:
		m.recalc_stats(true)


func _cb_gouda_pact(_pid: int) -> void:
	GameManager.add_seeds(80)
	GameManager.silo_max_hp *= 0.75
	GameManager.silo_hp = minf(GameManager.silo_hp, GameManager.silo_max_hp)
	GameManager.silo_hp_changed.emit(GameManager.silo_hp, GameManager.silo_max_hp)
