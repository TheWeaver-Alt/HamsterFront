# Project state

**Stage:** playable, building the mech roster · **Last updated:** 2026-11-05 · **Next:** Add the tank and the drone (roles confirmed in ADR-0003).

<!-- project-kit 1.0.0. This file owns status. /handoff rewrites Now and adds a session-log entry at the top. -->

## Now

- A full run plays end to end: a join screen (keyboard and mouse, P2 keyboard, gamepads), the ¾-view elevated Backyard with three canyon lanes, plateaus and ramps, build and wave phases, the vending-machine card draft after each wave, and game over when the Silo's structure gives out.
- The Silo is a steel grain silo with a seed-level window ([ADR-0002](adr/0002-silo-hp-and-seed-store.md)). Seeds are the one currency and live in its store, which holds 150 and can be upgraded to 250, 400 and 600 (60, 120 and 200 seeds). A full store stops banking and the rest stays in the cheeks. The HUD shows `seeds/capacity`, and an UPGRADE tag floats above the Silo when a pilot is in reach.
- Cards are pictures: each of the 37 has a big drawing of what it does, a short name and one to three arrows for how strong it is. Cursed cards stack the good picture over the bad one. The old sentences are a small grey line under the hand for a grown-up. The pause menu and the game-over screen list cards as strips of the same pictures (`scripts/core/CardFaces.gd`, `scripts/art/CardArt.gd`).
- Two mechs, BRAWLER-01 and WHEELER-X: cheek pouch (bank, cram, spit), wheel heat (sprint, redline, spin-out, vent), alt attacks, and the Soda-Bottle Jetpack card for hopping cliffs.
- The full enemy roster (Clan-Squeakers, Jezzails, Plague-Stink Monks, Doom-Roombas, the Rat-Ogre Bruiser), animated, with death animations and burrow crawl-outs.
- Five towers with three upgrade levels, a +15% high-ground range bonus and Sugar Rush overdrive.
- Learning Mode (Counting, Maths to 10, Maths to 20; per player) and KID MODE. About half of each level's puzzles are pictures with almost no words (patterns, odd one out, shapes and shadows, mirror, jigsaw piece, balance scale) and the rest are numbers. A wrong answer is never a penalty: a picture hint starts and the wrong buttons fade.
- Procedural chiptune music for the title, battle and build phases (ducking; M toggles it), gas, flame and scorch hazards, iris scene transitions, and polished FX, HUD and menus.
- Export presets for Windows, Linux and macOS. Fullscreen by default, F11 toggles, Esc on the title screen quits.
- `bash tools/check.sh` fuzzes the Learning Mode question generators (18,000 questions), then runs the two-bot playtest headless on Godot 4.7.2. It clears 5 waves and carries four regressions: a mortar shell outliving its tower (`--lob-free`), a mech wedged in a new tower (`--stuck`), the Silo store rules and the Learning Mode puzzle gate (`--economy`).

## In progress

- The polish pass (`2689be6` to `bf847bc` on `main`). Its first commit is marked "in progress". Whether more is planned is the owner's call.
- **Owner's brief of 2026-11-02** (the kid loves the game). Build order is economy, then chassis, then cards, then the Workshop. Done means each piece is playable and `bash tools/check.sh` passes.
  - Done and merged on 2026-11-05: **visual puzzles** (item 1), **Silo and economy** (item 2, [ADR-0002](adr/0002-silo-hp-and-seed-store.md); mech upgrades paying in seeds comes with the cards rework) and the fix for a **mech wedged in a freshly built tower**.
  3. **Four mechs** ([ADR-0003](adr/0003-chassis-roster-and-weight.md), Proposed): step one is done and checked. The chassis are data (`scripts/mech/Chassis.gd`) with a visual and a weapon script each, and each pilot picks a mech on the title screen. Still to do: the tank (HOWITZER-9) and the drone (WHIRLYBIRD-Z), with their art, weapons, weight behavior and bots that drive them.
  4. **Simpler cards**: done as picture-first cards (all 37 redrawn, none cut). Still open: cards that build and upgrade the mech, paid for in seeds (ADR-0002 item 5).
  5. **Workshop**: Vampire Survivors-style upgrades per mech between runs, saved in a file. The tank and drone unlock here. Needs its own ADR for the save file before any code.
  6. **Two gamepads**: `PlayerInput` and the title screen look like they already support `pad0` and `pad1`. Try it on real hardware.
  7. **Handbook** (an encyclopedia of rats, mechs, towers and cards, picture-first): requested by the owner on 2026-11-05, not started. Most of its data exists (the card pictures, the rat and tower stats, the mech roster). Remembering what a child has discovered needs the save file, so that part waits for the Workshop's ADR.

## Next

1. Add the tank (HOWITZER-9) and the drone (WHIRLYBIRD-Z): art, weapons, weight behavior, and bots that drive them.
2. Cards that build and upgrade the mech, bought with seeds (finishes ADR-0002 item 5), and the handbook.
3. Write the Workshop's ADR (the save file) before any Workshop code.

## Known gaps and risks

- The 39 card pictures are first-pass art. A few are abstract (salt, sticky shells, sugar, sneeze) and need a child's eye. They were checked on screenshots of the draft screen (one and two pilots), the pause menu and the game-over screen, not on the title screen. On cursed cards the pictures are drawn small (the card has two rows).
- The before/after mech comparison covers idle, cheeks, downed and walking. Firing and the alt attacks are not in it (random spread and particles), so the bots cover their logic and a person has to look at the rest. The capture and diff scripts were scratch work and are not in the repo.
- The economy numbers (capacity 150/250/400/600, upgrade costs 60/120/200, the wave bonus clamped to the store) are a first pass. No real player has tried them yet, and the bots start with 400 seeds, so the cap barely bites in `tools/check.sh`.
- The new picture puzzles were checked on screenshots for five types (pattern, odd, mirror, scale, piece) at one level. The other types need a look while playing.
- The two merged worktrees (`.claude/worktrees/visual-puzzles-6c3027` and `.claude/worktrees/magical-satoshi-a50127`) and their branches are still on disk.
- A wave bonus that doesn't fit in the store is lost. The float text says "SILO FULL", but a child may still find it unfair. Revisit after play.
- `tools/check.sh`'s import step doesn't parse every script. A script that only loads at runtime (the tower brains, say) is caught only if the smoke run uses it.
- The smoke test is unseeded, so a failure can't be replayed on demand.
- No unit tests: the bot playtest is the only automated check. Picking a test approach for GDScript needs an ADR.
- Smoke runs end with `WARNING: 4 ObjectDB instances were leaked at exit`.
- Exports haven't been built on this machine (Godot 4.7.2 export templates not checked).
- Doc drift: the README's project layout lists 5 of the 7 autoloads (`Music` and `Transition` are missing), and neither the README nor `docs/ARCHITECTURE.md` mentions `tools/check.sh` or `tools/MathQuizPreview.tscn`.
- `PRODUCT.md`: success criteria are undecided, and the principles are proposed, not confirmed.
- The old branch `claude/vibrant-mayer-30ahpn` (2 commits, history unrelated to `main`) is still on GitHub.

## Decisions

| Date | Decision | By | Recorded in |
|---|---|---|---|
| 2026-11-02 | Godot 4 + GDScript, every asset generated in code (recorded from the code as built) | owner | [ADR-0001](adr/0001-godot-4-and-procedural-assets.md) |
| 2026-11-02 | Silo keeps its HP and gains a seed store with capacity; seeds are the universal currency | owner | [ADR-0002](adr/0002-silo-hp-and-seed-store.md) |
| 2026-11-05 | Mechs are a data roster with a script per chassis. The four mechs' roles and numbers are confirmed (the numbers are a first pass). | owner | [ADR-0003](adr/0003-chassis-roster-and-weight.md) |
| 2026-11-05 | Cards are picture-first and all 37 are redrawn (none cut); no percentages on the card | owner | this file, `PRODUCT.md` principle 4 |
| 2026-11-05 | A handbook of rats, mechs, towers and cards is wanted; discovery tracking waits for the save file | owner | this file |
| 2026-11-02 | Robot and octopus from the start; tank and drone unlock in the Workshop (to go into the Workshop's ADR) | owner | this file |
| 2026-11-02 | Build order: economy, chassis, cards, Workshop; visual puzzles in parallel | owner | this file |
| 2026-11-02 | The game is called HamsterFront (was "Defence of Hamsterland: Mech-Pouch Protocol"). The title screen keeps "MECH-POUCH PROTOCOL" as its subtitle. | owner | `project.godot`, `README.md` |
| 2026-11-02 | Aligned to project-kit 1.0.0 | owner | `.claude/project-kit.json` |
| 2026-11-02 | Commit the `.uid` files Godot 4.4+ writes | owner | `AGENTS.md` (Project rules) |
| 2026-11-02 | GitHub's default branch is `main` | owner | GitHub repo settings |

## Session log

### 2026-11-05 · Picture-first cards

- The owner: kids do not get "20% more", so cards must be illustration-driven. The card art used to be one small icon per kind (wrench, tower, hearts, cheese), with everything else in the name and wrapped sentences.
- New `CardFaces` (`scripts/core/CardFaces.gd`): per card a short name (13 characters at most), a picture, 1 to 3 arrows, and on cursed cards a bad picture and bad arrows. `CardArt` (`scripts/art/CardArt.gd`) paints the 39 pictures, 16x16 each, from shared parts (hearts, rats, seeds, flames, bolts, hamster faces). They were rendered to a contact sheet headlessly and 8 weak ones redrawn (pierce, chain, brothers, leak, invert, radiator, sneeze, weight_down).
- `CardDraftUI`: the picture is the card (3x, or 4x for one pilot), then the short name, arrows with dim ghosts for the ones not earned, and a pip per copy you can own. Cursed cards stack the good over the bad. The grown-up sentence sits small and grey under the hand (below the prompt when there is one hand). The pause menu and game-over screen show strips of the same pictures with repeat counts.
- `PRODUCT.md` gains principle 4, "pictures before words" (proposed). ADR-0003 is now Accepted: the owner confirmed the tank and drone roles.
- The owner also asked for a handbook (encyclopedia) of rats, mechs, towers and cards. Added to the roadmap as item 7; discovery tracking needs the save file.
- Checks:
  - `tools/SmokeTest.gd --cards` asserts every card has a face, a short name of 13 characters or fewer, a real picture, 1 to 3 arrows, and a bad picture on cursed cards. Mutation test: a 18-character name and a misspelled picture name gave 2 `ERROR: cards:` lines; restored.
  - `bash tools/check.sh`: `check: PASS` (`cards: ok (37 ...)`, quiz fuzz 18000 questions 0 bad, `economy: ok`, `economy gate: ok`, `lob-free` landed, `stuck: cases=154 wedged=0 embedded_frames=0`).
  - Looked at on screenshots from short windowed runs: the real draft screen for two pilots and for one, the pause menu and the game-over screen.
- Committed on `main` together with the mech roster work below, not pushed.
- Next: the tank and the drone.

### 2026-11-05 · Mechs become a data roster (ADR-0003, step one)

- New `scripts/mech/Chassis.gd`: the roster (name, blurb, base stats, weapon hardpoint, shadow, unlock source) plus `apply()`, which puts a chassis's own scripts on a mech. `GameManager.player_chassis` (one id per pilot) replaces `p1_chassis`.
- `MechVisual` and `WeaponMount` are now shared bases with overridable hooks. BRAWLER-01 and WHEELER-X moved, function by function and verbatim, into `scripts/mech/chassis/{Brawler,Wheeler}{Visual,Weapon}.gd`. No `if chassis ==` is left outside `Chassis.gd`. `MechPlayer`'s hard-coded stats, names, hardpoint offsets, vent position, sprint trail and shadow now come from the roster.
- Title screen: each joined pilot picks their own mech with left and right (before, only a lone pilot could), with the name and blurb read from the roster.
- Proved behavior-preserving: a deterministic capture (fixed frame rate, random and real-time layers hidden, two runs of the baseline identical) of both mechs in 6 states before and after the change gave 0 differing pixels in all 12 images. The bots drove both mechs through 5 waves with no engine errors.
- Caught on the way: `visual` had to be typed `MechVisual` (not `Node2D`) for `visual.vent_offset()` to parse, and the builder script missed one dedent in `BrawlerWeapon.gd`. The check caught both at once.
- ADR-0003 records the roster architecture and proposes the tank (HOWITZER-9: artillery, stomp, barely slowed by weight) and the drone (WHIRLYBIRD-Z: flies over cliffs, seed bombs, rotor gust, slowed most by weight) for the owner to confirm.
- Checks: `bash tools/check.sh`: `check: PASS` (quiz fuzz 18000 questions 0 bad, `economy: ok`, `economy gate: ok`, `lob-free` landed, `stuck: cases=154 wedged=0 embedded_frames=0`).
- Committed on `main` together with the picture cards above, not pushed.
- Next: the tank and the drone.

### 2026-11-05 · Merged the puzzles and mech-stuck branches

- Merged `claude/magical-satoshi-a50127` (`ecfe698`, mech wedged inside a freshly built tower, with a `--stuck` regression) and `claude/visual-puzzles-6c3027`. The puzzles work had been left uncommitted in its worktree, so it was committed on its branch first (`130ffb8`). The conflicts were additive (`tools/SmokeTest.gd`, `tools/check.sh`, `docs/ARCHITECTURE.md`): both sides' flags and text were kept.
- The puzzles branch adds picture types (pattern, odd, same/shadow, bigger, order, mirror, piece, scale, chain), a validator that recomputes each answer from its picture, picture hints, and a fuzz that `tools/check.sh` runs. Its report mentioned a handover file that does not exist; the diff and the checks were reviewed instead.
- Gap found: the bots never reach a tower-upgrade puzzle in a normal run (the 6 puzzles asked in 3 waves were all card picks), so the `_solve_gate` refactor and the Silo upgrade puzzle were untested with Learning Mode on. Added the `--economy` gate check: with Learning Mode on, upgrading the Silo and a tower must each ask exactly one puzzle, and the tree must be unpaused afterwards.
- Checked on screenshots in a short windowed run of `MathQuizPreview`: pattern, odd one out, mirror, balance scale, jigsaw piece and the wrong-answer hint state.
- Checks:
  - `bash tools/check.sh`: `check: PASS` (quiz validator 0 of 11 corruptions slipped through, fuzz 18000 questions 0 bad, `economy: ok`, `economy gate: ok`, `lob-free` landed, `stuck: cases=154 wedged=0`, `banked_total=260`).
  - Learning Mode on, `--waves=3 --learning=1` and `--learning=3` with `--economy`: `check: PASS`, 6 puzzles asked and solved each time.
  - Mutation test: with `_solve_gate` made to skip the puzzle, the gate check reported 2 `ERROR: economy:` lines ("should ask exactly one puzzle (asked 0, then 0)"); restored.
- Committed on `main`; pushed to GitHub on 2026-11-05.
- Next: make the chassis data-driven, then add the tank and drone.

### 2026-11-05 · Silo and seed economy (ADR-0002)

- `GameManager`: `silo_level`, `silo_capacity`, `store_space()`, `store_fill()`, a capped `add_seeds` that returns how many fit, `silo_upgrade_cost()` and `upgrade_silo()`. A new run starts at level 1 with 150 capacity.
- `MechPlayer`: banking goes through `_bank_seeds`, which moves only what fits; a full store shows "SILO FULL" and leaves the seeds in the cheeks. Prompts near the Silo: bank, upgrade, or "SILO FULL! UPGRADE n".
- `MainArena`: `try_upgrade_silo`, plus `_solve_gate`, the Learning Mode puzzle gate pulled out of `try_upgrade` so towers and the Silo share it. The wave bonus is clamped to the store.
- Art: the bucket is gone. `MiscArt.silo(level)` paints a corrugated steel silo that stands taller at each level (yellow rim at 2, chimney at 3, gold roof with a sunflower weathervane at 4). `Silo.gd` fills its window live, draws rat damage (bites, cracks, a leaking hole) and the UPGRADE tag. The title screen shows the level-1 silo with a filling window. HUD shows `seeds/capacity` with a fill bar, red when full.
- Flavor text: the rats' "Bucket-bucket" barks now say "Silo-silo". `tools/ArtPreview.gd` lists `silo_1` to `silo_4`.
- Docs: README, `docs/ARCHITECTURE.md` (new Economy section), ADR-0002.
- Checked on rendered screenshots, in short windowed runs (headless can't draw): all four levels, half, full and empty window, the damaged silo, the HUD readout in three states, the UPGRADE tag, and the title screen.
- Checks:
  - `tools/SmokeTest.gd --economy` asserts the cap, capped banking, each upgrade and the top-level refusal. Mutation test: with the cap removed it reported 2 `ERROR: economy:` lines (`add_seeds` returned 30 instead of 10), then passed again once restored.
  - `bash tools/check.sh`: `check: PASS` (`economy: ok`, `lob-free` landed, kills=204, silo 1449/1500, `banked_total=290`).
- Found along the way: the pilots spawn 53.8 px from the Silo's center, just outside the 52 px use range, so the UPGRADE tag and prompts appear only once a pilot steps closer. That matches banking and is left as is.
- Committed on `main`; pushed to GitHub on 2026-11-05.
- Next: merge the two side branches (see In progress).

### 2026-11-02 · Renamed to HamsterFront

- The old name is gone from `project.godot` (name and header, so the window title too), `README.md`, `PRODUCT.md`, `AGENTS.md`, `.claude/project-kit.json`, the three export presets (product name, file description, company) and `tools/ArtPreview.gd`. The export paths and bundle id already said HamsterFront.
- Title screen (`scripts/ui/TitleScreen.gd`): the per-letter logo now spells HAMSTERFRONT and the small "DEFENCE OF" line above it is removed. "MECH-POUCH PROTOCOL" stays as the subtitle. Checked on a rendered screenshot: it fits and the shine and drop-in still work.
- Done before any save file exists, because Godot derives the `user://` folder from the project name and the Workshop will write there.
- Checks: `bash tools/check.sh`: `check: PASS` (kills=204, silo 1352/1500). `kit.py check`: 28 OK, 0 to fix.
- Committed on `main`; pushed to GitHub on 2026-11-05.

### 2026-11-02 · Freed-lambda error fixed

- Cause: `MortarBrain._fire` captured the tower node in the shell's landing lambda. When rats destroyed the tower while the shell was in flight, Godot logged `ERROR: Lambda capture at index 3 was freed` on the call (`ShotManager.gd:109`). Play was unaffected, since `_land` already coped with a null owner, but `tools/check.sh` failed on the log line.
- Fix: the lambda captures a `WeakRef` of the tower instead (`scripts/towers/brains/MortarBrain.gd`).
- Regression: `tools/SmokeTest.gd --lob-free` builds a mortar, fires it at a rat and destroys the tower mid-flight. It is in `tools/check.sh`'s default arguments, and `docs/ARCHITECTURE.md` lists the flag.
- Checks:
  - Regression on the unfixed code: `ERROR: Lambda capture at index 3 was freed` at `ShotManager.gd:109`, 2 runs of 2.
  - A first version of the fix failed to parse (`weakref()` returns a Variant, and the project treats that as an error). The check caught it, and the fix was retyped as `WeakRef`.
  - Regression on the fix: clean, 3 runs of 3 (`--waves=1`).
  - `bash tools/check.sh`: `check: PASS` (kills=204, silo 1342/1500, `lob-free: mortar shell landed after its tower was destroyed`).
- Committed on `main`; pushed to GitHub on 2026-11-05.
- Next: Silo and economy per ADR-0002.

### 2026-11-02 · Owner's design brief turned into a roadmap

- The owner's feedback (mech roster, seed economy, Silo, simpler cards, Workshop, visual puzzles, two pads) was checked against the code. The roadmap is under In progress.
- Decided with the owner: HP plus a seed store ([ADR-0002](adr/0002-silo-hp-and-seed-store.md)), tank and drone unlocked in the Workshop, and economy first with the visual puzzles in parallel.
- Findings that shaped the plan: the Silo's pile is its HP today and banked seeds are a separate counter; the chassis names are hard-coded in about 115 places; nothing is saved between runs.
- The `visual-puzzles` session was meant to run in its own worktree but did not start: the owner has to trust the repository in Claude Desktop first. Visual puzzles are still to do.

### 2026-11-02 · Cloned from GitHub and aligned to project-kit 1.0.0

- Cloned `TheWeaver-Alt/HamsterFront` on `main` (`bf847bc`) into `C:\HamsterFront`. GitHub's default branch was `claude/vibrant-mayer-30ahpn` (2 commits, unrelated history). With the owner's OK it is now `main`, and the old branch is kept.
- Aligned to project-kit 1.0.0, with every row approved by the owner. Created `AGENTS.md`, `CLAUDE.md`, `PRODUCT.md` (filled from the README), this file, and `docs/adr/` (index, template, and ADR-0001 recorded from the code as built). Created `.claude/` with the manifest, settings, guard and state hooks, and the `/start`, `/verify`, `/handoff` and `/adr` skills. Appended the secrets block to `.gitignore`. `README.md` and `docs/ARCHITECTURE.md` are untouched. No exceptions.
- Added `tools/check.sh`: import, then the smoke test. It fails on any `ERROR:` line or a missing `[smoke] DONE`, because the smoke test itself always exits 0. Its three failure paths were checked with fake Godot binaries. Added `.gitattributes` (`*.sh text eol=lf`), because `core.autocrlf=true` would otherwise check the script out with CRLF.
- Godot 4.7.2's import wrote 60 `.gd.uid` files. They are kept for git.
- Checks:
  - Baseline smoke, before any change: `[smoke] DONE phase=wave wave=6 max_wave=6 kills=203 silo=1500/1500 … towers=9`, with `ERROR: Lambda capture at index 3 was freed` at `ShotManager.gd:109`, which `tools/check.sh` would fail.
  - `bash tools/check.sh`, twice after the scaffold: `check: PASS` (kills=205, silo 1500/1500; kills=207, silo 1465/1500).
  - `kit.py check`: 3 OK with 8 required and 4 recommended missing before, 28 OK and 0 to fix after.
- Committed as `9b8a1e5`; pushed to GitHub on 2026-11-05.
- Next: fix the freed-lambda error in `ShotManager`.
