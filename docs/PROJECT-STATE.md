# Project state

**Stage:** playable, polishing · **Last updated:** 2026-11-02 · **Next:** Fix the intermittent freed-lambda error in `ShotManager` lob callbacks.

<!-- project-kit 1.0.0. This file owns status. /handoff rewrites Now and adds a session-log entry at the top. -->

## Now

- A full run plays end to end: a join screen (keyboard and mouse, P2 keyboard, gamepads), the ¾-view elevated Backyard with three canyon lanes, plateaus and ramps, build and wave phases, the vending-machine card draft after each wave, and game over when the Silo empties.
- Two mechs, BRAWLER-01 and WHEELER-X: cheek pouch (bank, cram, spit), wheel heat (sprint, redline, spin-out, vent), alt attacks, and the Soda-Bottle Jetpack card for hopping cliffs.
- The full enemy roster (Clan-Squeakers, Jezzails, Plague-Stink Monks, Doom-Roombas, the Rat-Ogre Bruiser), animated, with death animations and burrow crawl-outs.
- Five towers with three upgrade levels, a +15% high-ground range bonus and Sugar Rush overdrive.
- Learning Mode (Counting, Maths to 10, Maths to 20; per player) and KID MODE.
- Procedural chiptune music for the title, battle and build phases (ducking; M toggles it), gas, flame and scorch hazards, iris scene transitions, and polished FX, HUD and menus.
- Export presets for Windows, Linux and macOS. Fullscreen by default, F11 toggles, Esc on the title screen quits.
- `bash tools/check.sh` runs the two-bot playtest headless on Godot 4.7.2. It clears 5 waves, but it hit an engine error in one run out of three (see Known gaps).

## In progress

- The polish pass (`2689be6` to `bf847bc` on `main`). Its first commit is marked "in progress". Whether more is planned is the owner's call.

## Next

1. Fix `ERROR: Lambda capture at index 3 was freed`: a lobbed shot's `on_land` callback (`scripts/systems/ShotManager.gd:109`) runs after a node it captured was freed. Find the `lob()` caller that captures a node and guard it. A `--seed=` option for `tools/SmokeTest.gd` would make it reproducible.
2. Owner picks the next game work.

## Known gaps and risks

- The freed-lambda error above is intermittent (1 run in 3 on 2026-11-02), so `tools/check.sh` can fail on unchanged code until it is fixed.
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
| 2026-11-02 | Aligned to project-kit 1.0.0 | owner | `.claude/project-kit.json` |
| 2026-11-02 | Commit the `.uid` files Godot 4.4+ writes | owner | `AGENTS.md` (Project rules) |
| 2026-11-02 | GitHub's default branch is `main` | owner | GitHub repo settings |

## Session log

### 2026-11-02 · Cloned from GitHub and aligned to project-kit 1.0.0

- Cloned `TheWeaver-Alt/HamsterFront` on `main` (`bf847bc`) into `C:\HamsterFront`. GitHub's default branch was `claude/vibrant-mayer-30ahpn` (2 commits, unrelated history). With the owner's OK it is now `main`, and the old branch is kept.
- Aligned to project-kit 1.0.0, with every row approved by the owner. Created `AGENTS.md`, `CLAUDE.md`, `PRODUCT.md` (filled from the README), this file, and `docs/adr/` (index, template, and ADR-0001 recorded from the code as built). Created `.claude/` with the manifest, settings, guard and state hooks, and the `/start`, `/verify`, `/handoff` and `/adr` skills. Appended the secrets block to `.gitignore`. `README.md` and `docs/ARCHITECTURE.md` are untouched. No exceptions.
- Added `tools/check.sh`: import, then the smoke test. It fails on any `ERROR:` line or a missing `[smoke] DONE`, because the smoke test itself always exits 0. Its three failure paths were checked with fake Godot binaries. Added `.gitattributes` (`*.sh text eol=lf`), because `core.autocrlf=true` would otherwise check the script out with CRLF.
- Godot 4.7.2's import wrote 60 `.gd.uid` files. They are kept for git.
- Checks:
  - Baseline smoke, before any change: `[smoke] DONE phase=wave wave=6 max_wave=6 kills=203 silo=1500/1500 … towers=9`, with `ERROR: Lambda capture at index 3 was freed` at `ShotManager.gd:109`, which `tools/check.sh` would fail.
  - `bash tools/check.sh`, twice after the scaffold: `check: PASS` (kills=205, silo 1500/1500; kills=207, silo 1465/1500).
  - `kit.py check`: 3 OK with 8 required and 4 recommended missing before, 28 OK and 0 to fix after.
- Not committed.
- Next: fix the freed-lambda error in `ShotManager`.
