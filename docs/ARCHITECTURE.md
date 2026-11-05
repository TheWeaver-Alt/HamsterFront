# Architecture

Godot 4.3+, GDScript, GL Compatibility renderer. Base viewport 640x360, `canvas_items` stretch with integer scaling to 1920x1080, nearest filtering, 2D transform snapping.

**No image or audio assets are stored in the repo.** All pixel art is painted procedurally into `Image`s at startup (`scripts/art/*`). All sound is synthesized into `AudioStreamWAV`s (`autoloads/Sfx.gd`). The pixel font is a 3x5 bitmap `FontFile` built in code.

## Autoloads (`/autoloads`)

| Singleton | Role |
|---|---|
| `PixelArt` | Palette `C`, raster helpers (`disk`, `rect`, `line`, `outline`, `from_ascii`, `stamp_text`), named-texture cache `tex(name)`, the pixel `font`, canvas helpers `draw_text*`, `draw_bar`, `draw_box`, `draw_disk`, `make_flash_material()` |
| `Sfx` | Procedural 8-bit sounds. `Sfx.play(name, pitch, db)`, `Sfx.play_var(name, pitch, variance, db)` |
| `GameManager` | Wave, Silo HP, the Silo's seed store (`seeds`, `silo_level`, `silo_capacity`; see Economy), phase (`title/build/wave/draft/gameover`), player devices, global `gstats` (`StatBlock`), `TOWER_INFO`, `arena` + `players` refs |
| `CardDB` | All upgrade cards, weighted `roll_hand()`, `apply_card()` |
| `JuiceManager` | Hit-stop (`Engine.time_scale`), camera trauma shake, pooled speech-bubble `bark()`s, screen flash |

## Scenes (`/scenes`)

- `TitleScreen.tscn` — join screen (any device presses confirm; P1 confirms again to start).
- `MainArena.tscn` — `TileMapLayer` ground, `World` (y-sorted entities), managers, camera, `HUDLayer`, `DraftLayer`, `OverlayLayer`.
- `MechPlayer.tscn` — `CharacterBody2D` + `CheekPouchComponent`, `WheelHeatComponent`, `WeaponMount`, `Visual`, `Overlay`.
- `RatEnemy.tscn` — `CharacterBody2D`; behaviour from a `RatBrain` in `scripts/enemies/brains/<Kind>Brain.gd`.
- `TowerBase.tscn` — `StaticBody2D` (solid 14x12 collider on `L_TOWERS`) + `Range` (`Area2D`) + `OverchargeTimer`; behaviour from a `TowerBrain` in `scripts/towers/brains/<Kind>Brain.gd`. A pilot builds from up to 14px away, inside that collider, so a new tower slides any overlapping mech sideways to clear ground (`TowerBase._clear_mechs`); otherwise a pad with a fence or cliff face just behind it leaves the mech wedged for good.

## Arena systems (`scripts/arena`, `scripts/systems`)

- `ArenaMap` — 40x22 cell grid from an ASCII `TERRAIN` layout (plateaus `H`, cliff faces `F`, ramps/stairs `r`, lanes `,`), pads, burrows, obstacles. Elevation + connected regions (`elev_at`, `same_level`, `is_high_ground`, `passable`). Dijkstra **flow field** to the Silo that never crosses cliffs and treats ramps as expensive (`flow_waypoint(pos)`, `dist_at(pos)`).
- `TerrainArt` — composes each cell's ¾-view tile from its neighbours (lit plateau rims, cliff strata with end caps, ramps/stairs, cast shadows); `MainArena` dedupes them into one `TileMapLayer` atlas. Cliff faces and plateau edges get colliders on `L_RAT_BLOCK | L_CLIFF`; a jetpacking mech drops `L_CLIFF` from its mask mid-hop.
- `MainArena` — enemy registry + 32px **spatial hash** (`enemies_in_radius`, `nearest_enemy`), tower building (`try_build`, `try_upgrade`, `free_pad_near`, `tower_near`, `taunting_decoy`), phase loop, co-op synergies, pause/game over.
- `ShotManager` — every projectile as plain data; `fire(pos, vel, dmg, opts)` and `lob(from, to, dur, height, kind, on_land, opts)`. Team 0 hits rats, team 1 hits mechs/towers/Silo.
- `SeedManager` — dropped seeds that pop, bounce and get vacuumed into cheek pouches.
- `HazardManager` — shell piles (slow), fire (burn rats), gas (hurt mechs, corrode towers), cosmetic decals.
- `FxManager` — batched pixel particles, muzzle flashes, rings, lightning bolts, beams, floating text.
- `WaveSpawner` — scaling rosters, burrow telegraphs, pack spawning.

## Learning Mode

- `GameManager.learning_levels[player_slot]` (0 off .. 3), `GameManager.learning_level(player)`, `math_stars`, `math_asked`, `difficulty` (`"normal"`/`"kid"`).
- `MathQuestions.make(level, rng)` returns `{type, prompt, answer, choices[3], visual, hint}`. About half of each level is picture puzzles and the rest numbers: counting, adding, taking away, missing numbers. `prompt` and `hint` are a few words (at most 18 characters); the picture does the explaining.
  - Number types: `count`, `more`, `next`, `skip`, `add`, `double`, `sub`, `missing`, `compare`.
  - Picture types: `shape`, `pattern` (ABAB, AAB, ABC in colours or shapes), `odd` (odd one out), `same` (match, or match a shadow), `bigger` (biggest, smallest or middle of discs, bars, towers), `order` (which size fits the gap), `mirror` (symmetry), `piece` (jigsaw), `scale` (balance), `chain` (patterns with a gap in the middle, two changing things, growing dot cards).
  - `choices` are the numbers for number questions. For picture questions they are an index into `visual["options"]` (or a colour code for `mirror`) so the buttons can draw pictures; `scale` keeps its buttons in order (left heavier, level, right heavier).
  - `visual["kind"]` picks the picture and `visual["button"]` the button face; the full list and the glyph format are in the header of `scripts/core/MathQuestions.gd`, which owns them.
  - `MathQuestions.validate(q)` recomputes the answer from the picture and returns `""` when the question is sound. It is the unit test for the generators (see Dev tools).
- `MathQuiz` (Control on `MainArena/QuizLayer`, exposed as `arena.math_quiz`): `ask(player, level, reason)`, `signal solved(player, first_try)`. Used by `CardDraftUI` (card activation) and `MainArena.try_upgrade` (tower upgrades; the tree is paused while asking).
  - A wrong answer is never a penalty: the button is washed out (the choices shrink), the helper says "TRY AGAIN!", and a picture hint starts (counting along, a pulsing frame, a guide line, totals under the scale). After two misses the one button left is highlighted and pre-selected, so button-mashing always finishes.

## Stats & cards

**Card faces (picture-first).** CardDB owns the rules; `CardFaces` (`scripts/core/CardFaces.gd`) owns what a child sees, for every card id: `short` (a name of at most 13 characters), `icon` (a 16x16 picture, `PixelArt.tex("card_" + icon)`, painted in `scripts/art/CardArt.gd`), `power` (1 to 3 arrows) and, on cursed cards, `bad_icon` and `bad_power`. `CardFaces.validate()` is the unit test for the table. `CardDraftUI` draws the picture at 3x (4x for one pilot), the short name, the arrows (dim ghosts show the arrows not earned) and one pip per copy you can own. Cursed cards stack the good picture over the bad one. The long `desc` and `downside` in CardDB stay as the small grey line under the hand for a grown-up. The pause menu and the game-over screen list cards as strips of the same pictures.

**Buying cards (ADR-0002 item 5).** A pilot's first pick from the vending machine is free; the rest of their hand is for sale. `CardDB.price(card)` is the price in seeds, taken from the card's arrows (`PRICE_BY_POWER` 10, 20, 35; `PRICE_CURSED` 5, 10, 20), so it is not a field on the card. `CardDraftUI` keeps `taken` (the hand slots a pilot has, free pick first) and `done` per pilot. `_request_take(i)` charges `GameManager.buy_card(price)` at once (so the other pilot cannot spend the same seeds while a puzzle is open), then either applies the card or, with Learning Mode on, queues one puzzle and applies it when `math_quiz.solved` fires (the puzzle's reason line is "BUY <card>"). A pilot is done on back (or the DONE button), when their hand is empty, or when nothing left in it is affordable. The draft's `finished` signal fires once every pilot is done. The Silo's seeds are shared by both pilots; `GameManager.card_purchases` and `card_seeds_spent` count the run's purchases.

`StatBlock`: `final = (base + Σadd) × Πmul`, plus flags. Each mech has `stats`; the team/towers share `GameManager.gstats`. A card's `mods` go to the picking player, `gmods` to `gstats`. See the header of `autoloads/CardDB.gd` for every key.

## Mechs (ADR-0003)

- `Chassis` (`scripts/mech/Chassis.gd`) is the roster: `IDS` (title-screen order), `DEFS` (name, blurb, base stats, weapon hardpoint, shadow size, unlock source), `def()`, `base_stats()`, `available()`, `is_unlocked()` (true for every mech until the Workshop exists) and `apply()`.
- `MechPlayer.setup(id, chassis, device)` calls `Chassis.apply`, which puts the chassis's own scripts on its `Visual` and `WeaponMount` nodes before the mech enters the tree. Nothing outside `Chassis.gd` branches on a chassis id.
- `MechVisual` and `WeaponMount` hold the shared machinery (squash and stretch, flash, pilot head, cooldowns, recoil, aim). `scripts/mech/chassis/<Name>Visual.gd` and `<Name>Weapon.gd` extend them and override the hooks: `_draw_mech`, `_tick_extra`, `_spin_wobble`, `vent_offset`, `sprint_trail` on the visual; `_fire`, `_alt`, `_tick_extra`, `_draw_weapon`, `muzzle_pos` on the weapon.
- `GameManager.player_chassis` holds one id per pilot slot. On the title screen each pilot cycles theirs with left and right, and the slot shows `mech_icon_<id>` (`scripts/art/MechIconArt.gd`, composed from the real sprite parts).
- The four mechs: BRAWLER-01 and WHEELER-X, and HOWITZER-9 (`tank`) and WHIRLYBIRD-Z (`drone`). Their art is in `scripts/art/TankArt.gd` and `DroneArt.gd`. The tank lobs shells with `ShotManager.lob` and stomps; the drone tosses `seed_bomb` lobs and blows a gust. Both weapons' landing code is `static` and captures only a `WeakRef` and a script constant, because a lambda that captured a freed node logs an engine error.
- Seed weight is a per-mech rule: `pouch_slow` (speed lost when full), `heat_weight` (`WheelHeatComponent` heats the wheel faster when full), and `MechVisual.hover_height()` (the drone sags lower when full). `Chassis.flies` marks a hovering mech: `MechPlayer._ground_mask()` leaves cliffs and towers out of its collision mask, `TowerBase._clear_mechs` skips it, and `CardDB` cards can list `not_chassis` (the jetpack is closed to the drone).
- Adding a mech: an entry in `Chassis.DEFS` and `Chassis.IDS`, the two scripts, and its art in `scripts/art/MechArt.gd`.

## Economy (ADR-0002)

Seeds are the one currency: towers, tower upgrades, Silo upgrades and the cards bought at the vending machine (see Stats & cards). They live in the Silo's store, which has a capacity. The Silo's structure HP is separate and is what ends the run.

- `GameManager`: `seeds` (the store's content), `silo_level` 1..4, `silo_capacity`, `SILO_CAPACITY` [150, 250, 400, 600], `SILO_UPGRADE_COST` [0, 60, 120, 200], `store_space()`, `store_fill()`, `add_seeds(n)` (returns how many fit), `spend(n)`, `silo_upgrade_cost()`, `upgrade_silo()`, signal `silo_upgraded`.
- Banking: `MechPlayer._bank_seeds(n)` moves only what fits, so a full store leaves the rest in the cheeks. The wave bonus and the quiz reward go through `add_seeds` and are clamped too.
- Upgrading: stand near the Silo and press build (`MainArena.try_upgrade_silo`). Learning Mode gates it with a puzzle through `MainArena._solve_gate`, which tower upgrades use as well.
- Drawing: `MiscArt.silo(level)` paints the sprite, taller with each level, and leaves its window empty. `Silo.gd` fills the window from `MiscArt.silo_gauge(level)`, draws rat damage and the UPGRADE tag. `HUD` shows `seeds/capacity` and a fill bar.
- Check: `tools/SmokeTest.tscn --economy` asserts the capacity, banking and upgrade rules, then the Learning Mode puzzle gate for Silo and tower upgrades.

## Damage interfaces

- Rat: `take_damage(amount, from_pos, knockback, info)` — `info` keys: `owner`, `kind`, `burn`, `stun`, `melt`, `quiet`, `friendly`.
- Mech: `take_damage(amount, from_pos, quiet := false)`.
- Tower: `take_damage(amount, source)`, `corrode(dt)`, `overcharge(seeds, by)`.
- Silo: `GameManager.damage_silo(amount)` + `arena.on_silo_hit(pos)`.

## Dev tools (`/tools`)

- `ArtPreview.tscn` — renders every sprite + font sample to `screenshots/art_preview.png`.
- `MathQuizPreview.tscn` — `godot --path . res://tools/MathQuizPreview.tscn` (a window, not `--headless`, since it takes screenshots). It checks `MathQuestions.validate` against corrupted questions and fuzzes it over 400 questions of every type at every level, saves `screenshots/quiz_L<level>_<type>_{ask,wrong,hint,highlight,correct}.png`, then runs a button-mashing bot that must finish every type at every level. Options: `-- --only=odd,mirror`, `--no-shots`, `--no-mash`.
- `SmokeTest.tscn` — two bot pilots play N waves: `godot --path . res://tools/SmokeTest.tscn -- --waves=4 --speed=3 [--shots] [--spawn-all] [--lob-free] [--stuck] [--economy]`. `--lob-free` fires a mortar shell and destroys its tower mid-flight (regression for a freed lambda capture). `--stuck` builds a tower on every pad with a pilot standing at several spots within build range and fails if the mech is left sunk in the tower or unable to walk away (regression for a mech wedged between a new tower and a fence or cliff); the summary line `stuck: cases=N wedged=N embedded_frames=N episodes=N` also counts any frame a mech overlaps a tower during normal bot play. `--chassis=tank,drone` picks the pilots' mechs, and `--mechs` (with that option) asserts the weight order, flight, the hover sag, the jetpack filter, the heat-weight rule and that each new weapon and alt attack hurts a rat. `bash tools/check.sh` runs the bots a second time as the tank and the drone. `--cards` asserts that every card has a sound face (see Stats & cards). `--shop` asserts the card prices, that the first card is free and the next ones cost seeds from the one shared store, that a card you cannot afford is refused, that pilots finish on their own when nothing is affordable and, with a stand-in quiz, that every card asks one puzzle and a bought card is paid when chosen. The bots also buy cards in every draft, and the summary prints `vending machine: cards bought=N seeds spent=N`. `--economy` asserts the Silo store rules and, with Learning Mode on, that upgrading the Silo and a tower each ask exactly one puzzle (see Economy). `bash tools/check.sh` wraps the import, the Learning Mode question fuzz (`MathQuizPreview.tscn -- --no-shots --no-mash`, headless, a few seconds) and this run, and fails on any `ERROR:` line.
