# Product

<!-- impeccable:product-schema 1 -->

## Platform

Desktop: Windows, Linux and macOS (export presets in `export_presets.cfg`). Fullscreen by default, F11 toggles. Keyboard and mouse, a second keyboard layout for P2, and gamepads.

## Stack

Godot 4.3+, GDScript, GL Compatibility renderer. All art and sound generated at runtime. See [ADR-0001](docs/adr/0001-godot-4-and-procedural-assets.md).

## Users

One or two players at the same screen (local co-op). That includes a parent playing alongside a young child: Learning Mode is set per player, for ages 4 to 8.

## Product Purpose

**Defence of Hamsterland: Mech-Pouch Protocol.** A 2D top-down action tower defense roguelite. Two hamsters in scrap-built mechs defend The Great Silo from the Under-Scurriers. The core loop is collecting seeds in a cheek pouch, then banking, cramming or spitting them, building and upgrading towers, and drafting upgrade cards after each wave. With Learning Mode on, a player's card picks and tower upgrades activate by solving a maths puzzle.

Undecided: what success means.

## Positioning

Couch co-op arcade tower defense with comic tabletop-parody flavour, where a child's maths practice is part of the game rather than a gate in front of it.

## Operating Context

Played at home on one machine, offline, in short runs that end when the Silo's seed pile runs out.

## Capabilities and Constraints

- The app makes no outside requests.
- No image or audio files: pixel art, the 3x5 font, 8-bit sound and chiptune music are all generated in code.
- 640x360 base viewport, integer-scaled with nearest filtering.
- Learning Mode: three levels (Counting, Maths to 10, Maths to 20). Shapes and patterns appear at every level. Time freezes while a player thinks.
- KID MODE gives a tougher Silo, slower and weaker rats, and more starting seeds.

## Evidence on Hand

- `tools/SmokeTest.tscn`: a two-bot playtest through several waves, run by `bash tools/check.sh`.
- `tools/ArtPreview.tscn`: renders every sprite and font sample to `screenshots/`.
- `tools/MathQuizPreview.tscn`: shows every quiz type and proves each one can be finished.

No playtest notes from real players are in the repo yet.

## Product Principles

Proposed from the README, not yet confirmed by the owner:

1. A wrong answer is never punished: a gentle "try again" and a counting hint, never a loss.
2. Every system is readable at a glance in chunky pixel art: telegraphs before danger (burrows, laser sights).
3. Co-op is the default: synergies reward playing together, and either player can have Learning Mode on alone.
