# Project state

**Stage:** playable, polishing · **Last updated:** 2026-11-02 · **Next:** Rework the Silo and seed economy (ADR-0002).

<!-- project-kit 1.0.0. This file owns status. /handoff rewrites Now and adds a session-log entry at the top. -->

## Now

- A full run plays end to end: a join screen (keyboard and mouse, P2 keyboard, gamepads), the ¾-view elevated Backyard with three canyon lanes, plateaus and ramps, build and wave phases, the vending-machine card draft after each wave, and game over when the Silo empties.
- Two mechs, BRAWLER-01 and WHEELER-X: cheek pouch (bank, cram, spit), wheel heat (sprint, redline, spin-out, vent), alt attacks, and the Soda-Bottle Jetpack card for hopping cliffs.
- The full enemy roster (Clan-Squeakers, Jezzails, Plague-Stink Monks, Doom-Roombas, the Rat-Ogre Bruiser), animated, with death animations and burrow crawl-outs.
- Five towers with three upgrade levels, a +15% high-ground range bonus and Sugar Rush overdrive.
- Learning Mode (Counting, Maths to 10, Maths to 20; per player) and KID MODE.
- Procedural chiptune music for the title, battle and build phases (ducking; M toggles it), gas, flame and scorch hazards, iris scene transitions, and polished FX, HUD and menus.
- Export presets for Windows, Linux and macOS. Fullscreen by default, F11 toggles, Esc on the title screen quits.
- `bash tools/check.sh` runs the two-bot playtest headless on Godot 4.7.2. It clears 5 waves and includes a deterministic mortar-shell regression (`--lob-free`).

## In progress

- The polish pass (`2689be6` to `bf847bc` on `main`). Its first commit is marked "in progress". Whether more is planned is the owner's call.
- **Owner's brief of 2026-11-02** (the kid loves the game). Build order is economy, then chassis, then cards, then the Workshop. Done means each piece is playable and `bash tools/check.sh` passes.
  1. **Visual puzzles** (independent of the rest, so it can run in its own session; not started yet): more pattern and shape puzzles, less text, in `scripts/core/MathQuestions.gd` and `scripts/ui/MathQuiz.gd`.
  2. **Silo and economy** ([ADR-0002](adr/0002-silo-hp-and-seed-store.md)): a real silo with a fill gauge, a seed store with capacity, seeds as the universal currency for towers and mech upgrades.
  3. **Four mechs**: make the chassis data-driven (today `"brawler"` and `"wheeler"` are hard-coded in about 115 places), then add the tank (artillery, reusing `ShotManager.lob`) and the drone (flies over cliffs). Weight handling becomes per chassis instead of the one global `pouch_slow`.
  4. **Simpler cards**: icon-first cards that build and upgrade the mech, bought with seeds.
  5. **Workshop**: Vampire Survivors-style upgrades per mech between runs, saved in a file. The tank and drone unlock here. Needs its own ADR for the save file before any code.
  6. **Two gamepads**: `PlayerInput` and the title screen look like they already support `pad0` and `pad1`. Try it on real hardware.

## Next

1. Silo and economy per ADR-0002: `silo_capacity`, the fill gauge, the HUD, the capacity upgrade.
2. Make the chassis data-driven, then add the tank and drone.

## Known gaps and risks

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
| 2026-11-02 | Robot and octopus from the start; tank and drone unlock in the Workshop (to go into the Workshop's ADR) | owner | this file |
| 2026-11-02 | Build order: economy, chassis, cards, Workshop; visual puzzles in parallel | owner | this file |
| 2026-11-02 | The game is called HamsterFront (was "Defence of Hamsterland: Mech-Pouch Protocol"). The title screen keeps "MECH-POUCH PROTOCOL" as its subtitle. | owner | `project.godot`, `README.md` |
| 2026-11-02 | Aligned to project-kit 1.0.0 | owner | `.claude/project-kit.json` |
| 2026-11-02 | Commit the `.uid` files Godot 4.4+ writes | owner | `AGENTS.md` (Project rules) |
| 2026-11-02 | GitHub's default branch is `main` | owner | GitHub repo settings |

## Session log

### 2026-11-02 · Renamed to HamsterFront

- The old name is gone from `project.godot` (name and header, so the window title too), `README.md`, `PRODUCT.md`, `AGENTS.md`, `.claude/project-kit.json`, the three export presets (product name, file description, company) and `tools/ArtPreview.gd`. The export paths and bundle id already said HamsterFront.
- Title screen (`scripts/ui/TitleScreen.gd`): the per-letter logo now spells HAMSTERFRONT and the small "DEFENCE OF" line above it is removed. "MECH-POUCH PROTOCOL" stays as the subtitle. Checked on a rendered screenshot: it fits and the shine and drop-in still work.
- Done before any save file exists, because Godot derives the `user://` folder from the project name and the Workshop will write there.
- Checks: `bash tools/check.sh`: `check: PASS` (kills=204, silo 1352/1500). `kit.py check`: 28 OK, 0 to fix.
- Committed on `main`, not pushed.

### 2026-11-02 · Freed-lambda error fixed

- Cause: `MortarBrain._fire` captured the tower node in the shell's landing lambda. When rats destroyed the tower while the shell was in flight, Godot logged `ERROR: Lambda capture at index 3 was freed` on the call (`ShotManager.gd:109`). Play was unaffected, since `_land` already coped with a null owner, but `tools/check.sh` failed on the log line.
- Fix: the lambda captures a `WeakRef` of the tower instead (`scripts/towers/brains/MortarBrain.gd`).
- Regression: `tools/SmokeTest.gd --lob-free` builds a mortar, fires it at a rat and destroys the tower mid-flight. It is in `tools/check.sh`'s default arguments, and `docs/ARCHITECTURE.md` lists the flag.
- Checks:
  - Regression on the unfixed code: `ERROR: Lambda capture at index 3 was freed` at `ShotManager.gd:109`, 2 runs of 2.
  - A first version of the fix failed to parse (`weakref()` returns a Variant, and the project treats that as an error). The check caught it, and the fix was retyped as `WeakRef`.
  - Regression on the fix: clean, 3 runs of 3 (`--waves=1`).
  - `bash tools/check.sh`: `check: PASS` (kills=204, silo 1342/1500, `lob-free: mortar shell landed after its tower was destroyed`).
- Committed on `main`, not pushed.
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
- Committed as `9b8a1e5` (not pushed).
- Next: fix the freed-lambda error in `ShotManager`.
