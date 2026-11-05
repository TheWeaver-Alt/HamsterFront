# ADR-0003: Mechs as a data roster with per-chassis scripts; four mechs, each carrying seed weight differently

**Status:** Accepted (the owner confirmed the four mechs' roles on 2026-11-05)
**Date:** 2026-11-05
**Deciders:** owner

## Context

There are two mechs, BRAWLER-01 (a robot) and WHEELER-X (a spider-legged ball), and their names are hard-coded in about 115 places: stats, art, weapons, the title screen, the card filter. The owner wants two more, a tank (artillery) and a drone (copter), and wants the mechs to differ in how they cope with the weight of a full cheek pouch. The tank and drone unlock in the Workshop (see PROJECT-STATE).

## Decision

- **Roster as data.** `scripts/mech/Chassis.gd` lists every chassis once: id, display name, blurb, base stats, where the weapon and the steam vent sit, shadow size, and which unlock source it has. Anything that needs "the mechs" asks `Chassis`.
- **Behavior as a script per chassis.** `MechVisual` and `WeaponMount` stay as the shared bases (springs, flash, head, recoil, cooldowns) and expose overridable hooks. Each chassis adds `scripts/mech/chassis/<Name>Visual.gd` and `<Name>Weapon.gd`, which `MechPlayer.setup()` swaps onto the existing nodes. No `if chassis == "..."` outside `Chassis.gd`.
- **Choice per pilot.** `GameManager.player_chassis` holds one id per slot (it replaces `p1_chassis`). The title screen cycles each pilot's mech with left and right.
- **Unlock.** `Chassis.is_unlocked(id)` is true for every mech until the Workshop exists. The Workshop will own the real list and needs its own ADR for the save file.

### The four mechs (first-pass numbers; the roles are confirmed)

| Mech | Pouch | Slowdown when full | What else weight does | Fire | Alt |
|---|---|---|---|---|---|
| BRAWLER-01, robot | 50 | 40% | nothing extra (as today) | Sawdust Shotgun | Cardboard-Tube Fist |
| WHEELER-X, spider ball | 40 | 25% | the exercise wheel heats up to 80% faster when full | twin Toothpick Railguns | Burnout Dash |
| HOWITZER-9, tank | 90 | 12% | it is slow anyway, and barely notices the load | lobs a shell onto the nearest rat in the aim cone | Stomp: a shockwave that stuns |
| WHIRLYBIRD-Z, drone | 30 | 55% | it sags lower the fuller it gets | drops a seed bomb ahead of itself | Rotor Gust: blows rats back |

The drone flies: it ignores cliffs and towers (its collision mask leaves out `L_CLIFF` and `L_TOWERS`), so it never needs the Soda-Bottle Jetpack card, which is excluded for it.

## Options considered

### Option A: roster data plus a script per chassis (chosen)

**Pros:** a new mech is one data entry and two scripts. The existing code moves almost verbatim, so the refactor is checkable pixel for pixel. Same spirit as the tower and rat brains.
**Cons:** the shared bases carry a few hook methods that only some chassis use.

### Option B: keep the `if chassis ==` branches and add two more

**Pros:** no restructuring.
**Cons:** every new mech touches five files, and four branches in each of them is hard to read.

## Consequences

- Easier: adding or tuning a mech touches `Chassis.gd` and its own two scripts.
- Harder: the mech art is still one big file (`scripts/art/MechArt.gd`), and it grows with each mech.
- Revisit: if `MechArt.gd` gets unwieldy, split it per chassis.

## Action items

1. [x] `Chassis.gd` and `GameManager.player_chassis`; BRAWLER and WHEELER moved onto them with no visible change. Done 2026-11-05: 0 differing pixels between before and after captures in 6 states for both mechs, and the bots drove both through 5 waves.
2. [x] Per-pilot selection on the title screen (left and right on each joined pilot's slot).
3. [x] HOWITZER-9 (art, weapons, weight). Done 2026-11-05.
4. [x] WHIRLYBIRD-Z (art, flight, weapons, weight). Done 2026-11-05.
5. [x] Bots and checks that drive all four mechs: `--chassis=a,b` and `--mechs` in the smoke test, and a tank-and-drone run in `tools/check.sh`.
6. [ ] Lock the tank and the drone behind the Workshop (needs the Workshop's own ADR for the save file).
