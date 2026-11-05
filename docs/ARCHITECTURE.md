# Architecture

Godot 4.3+, GDScript, GL Compatibility renderer. Base viewport 640x360, `canvas_items` stretch with integer scaling to 1920x1080, nearest filtering, 2D transform snapping.

**No image or audio assets are stored in the repo.** All pixel art is painted procedurally into `Image`s at startup (`scripts/art/*`). All sound is synthesized into `AudioStreamWAV`s (`autoloads/Sfx.gd`). The pixel font is a 3x5 bitmap `FontFile` built in code.

## Autoloads (`/autoloads`)

| Singleton | Role |
|---|---|
| `PixelArt` | Palette `C`, raster helpers (`disk`, `rect`, `line`, `outline`, `from_ascii`, `stamp_text`), named-texture cache `tex(name)`, the pixel `font`, canvas helpers `draw_text*`, `draw_bar`, `draw_box`, `draw_disk`, `make_flash_material()` |
| `Sfx` | Procedural 8-bit sounds. `Sfx.play(name, pitch, db)`, `Sfx.play_var(name, pitch, variance, db)` |
| `GameManager` | Wave, Silo HP, banked seeds, phase (`title/build/wave/draft/gameover`), player devices, global `gstats` (`StatBlock`), `TOWER_INFO`, `arena` + `players` refs |
| `CardDB` | All upgrade cards, weighted `roll_hand()`, `apply_card()` |
| `JuiceManager` | Hit-stop (`Engine.time_scale`), camera trauma shake, pooled speech-bubble `bark()`s, screen flash |

## Scenes (`/scenes`)

- `TitleScreen.tscn` — join screen (any device presses confirm; P1 confirms again to start).
- `MainArena.tscn` — `TileMapLayer` ground, `World` (y-sorted entities), managers, camera, `HUDLayer`, `DraftLayer`, `OverlayLayer`.
- `MechPlayer.tscn` — `CharacterBody2D` + `CheekPouchComponent`, `WheelHeatComponent`, `WeaponMount`, `Visual`, `Overlay`.
- `RatEnemy.tscn` — `CharacterBody2D`; behaviour from a `RatBrain` in `scripts/enemies/brains/<Kind>Brain.gd`.
- `TowerBase.tscn` — `StaticBody2D` + `Range` (`Area2D`) + `OverchargeTimer`; behaviour from a `TowerBrain` in `scripts/towers/brains/<Kind>Brain.gd`.

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

`StatBlock`: `final = (base + Σadd) × Πmul`, plus flags. Each mech has `stats`; the team/towers share `GameManager.gstats`. A card's `mods` go to the picking player, `gmods` to `gstats`. See the header of `autoloads/CardDB.gd` for every key.

## Damage interfaces

- Rat: `take_damage(amount, from_pos, knockback, info)` — `info` keys: `owner`, `kind`, `burn`, `stun`, `melt`, `quiet`, `friendly`.
- Mech: `take_damage(amount, from_pos, quiet := false)`.
- Tower: `take_damage(amount, source)`, `corrode(dt)`, `overcharge(seeds, by)`.
- Silo: `GameManager.damage_silo(amount)` + `arena.on_silo_hit(pos)`.

## Dev tools (`/tools`)

- `ArtPreview.tscn` — renders every sprite + font sample to `screenshots/art_preview.png`.
- `MathQuizPreview.tscn` — `godot --path . res://tools/MathQuizPreview.tscn` (a window, not `--headless`, since it takes screenshots). It checks `MathQuestions.validate` against corrupted questions and fuzzes it over 400 questions of every type at every level, saves `screenshots/quiz_L<level>_<type>_{ask,wrong,hint,highlight,correct}.png`, then runs a button-mashing bot that must finish every type at every level. Options: `-- --only=odd,mirror`, `--no-shots`, `--no-mash`.
- `SmokeTest.tscn` — two bot pilots play N waves: `godot --path . res://tools/SmokeTest.tscn -- --waves=4 --speed=3 [--shots] [--spawn-all] [--lob-free]`. `--lob-free` fires a mortar shell and destroys its tower mid-flight (regression for a freed lambda capture). `bash tools/check.sh` wraps the import, the Learning Mode question fuzz (`MathQuizPreview.tscn -- --no-shots --no-mash`, headless, a few seconds) and this run, and fails on any `ERROR:` line.
