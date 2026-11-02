# Defence of Hamsterland: Mech-Pouch Protocol

A 2D top-down action tower defense roguelite for 1–2 players (local co-op), built in **Godot 4.3+** with GDScript.

At the centre of the Backyard sits **The Great Silo**, a plastic bucket overflowing with premium striped sunflower seeds. The **Under-Scurriers**, a glowing-eyed ratfolk cult, tunnel up from beneath the patio to steal the hoard for **The Great Horned Gouda**. Two hamsters climb into scrap-built mechs to stop them.

Everything you see and hear is generated at runtime: the pixel art is painted in code, the 3x5 pixel font is a bitmap built in code, and every 8-bit sound is synthesized. The repo contains no image or audio files.

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) or newer (standard build, not .NET).
2. Open the editor, choose **Import**, and select this folder's `project.godot`.
3. Press **F5**.

The first import builds Godot's class cache. If you run from the command line without opening the editor first, import once:

```bash
godot --headless --path . --editor --quit
```

```bash
godot --path .
```

## How to play

- Rats crawl out of burrows at the edge of the yard and follow the paths to the Silo. If the Silo's seed pile runs out, the run is over.
- Dead rats drop seeds. Your mech **vacuums them into the pilot's cheek pouch**. The fuller the pouch, the bigger the hamster's head and the slower the mech (up to -40%).
- Spend a full pouch in one of three ways:
  - **Bank** it at the Silo to earn seeds for building.
  - **Cram** it into a tower to start a 10-second **Sugar Rush Overdrive**: double fire rate, +50% damage and a repair.
  - **Spit** it as an emergency shrapnel blast that clears the screen. The seeds are lost.
- **Sprinting** heats the mech's internal exercise wheel. Above 80% it redlines. At 100% the hamster trips and spins out of control for 1.5 seconds. **Vent** steam to dump the heat. Venting also scalds nearby rats.
- **Build towers** on the wooden pads, and **upgrade** them up to level 3.
- After each wave, time freezes and a **vending machine** drops from the sky. Each player picks 1 of 3 upgrade cards.

### Controls

| Action | Keyboard + Mouse (P1) | Keyboard, right side (P2) | Gamepad |
|---|---|---|---|
| Move | WASD | Arrow keys | Left stick / D-pad |
| Aim | Mouse | Auto-aim | Right stick (auto-aim when idle) |
| Fire | Left mouse | `/` or Numpad 0 | RT |
| Alt (Fist / Dash) | Right mouse or Space | `.` | LT |
| Sprint | Shift | `'` or Numpad Enter | LB |
| Bank / Cram | E | `;` | A |
| Build / Upgrade | F | L | Y |
| Cycle tower | Tab, mouse wheel, 1–5 | K | RB |
| Spit blast | Q | `[` | B |
| Vent steam | R | `]` | X |
| Ready up (skip build timer) | G or Enter | `\` | Back / Select |
| Pause | Esc / P | Esc | Start |

On the title screen, every device presses its confirm button (E / Enter / A) to join. P1 presses confirm again to start. In 1-player mode, left/right on the title screen switches between the two mechs.

## The cast

**Mechs**
- **BRAWLER-01, "The Tin-Can Titan"**: an espresso machine held together with duct tape. Fires a short-range Sawdust Shotgun. Its alt attack is a hydraulic Cardboard-Tube Fist punch.
- **WHEELER-X, "The Turbo Ball"**: a glass hamster ball on spider legs. Fires dual piercing Toothpick Railguns. Sprinting leaves burning rubber trails, and its alt attack is a Burnout Dash.

**Under-Scurriers**
- **Clan-Squeakers**: swarm fodder armed with bent forks. They arrive in packs and trip over each other's tails.
- **Warp-Gouda Jezzails**: a two-rat sniper team that shows a long green laser sight before it fires.
- **Plague-Stink Monks**: leave toxic gas clouds that corrode tower armour.
- **Doom-Roombas**: spiked robot vacuums that bounce off walls and run over their own side.
- **Rat-Ogre Bruiser**: a mini-boss that throws Clan-Squeakers at you.

**Towers**: Sunflower Gatling, Water-Bottle Laser, Cedar-Shaving Mortar, Exercise-Wheel Tesla Coil and Cardboard Decoy Hamster.

**Cards**: Mech Mods, Tower Blueprints & Mutations, Co-op Synergies (*Jumper Cables*, *Blood Brothers*, …) and cursed **Warp-Cheese Corruptions** (*Eat the Forbidden Brie*, …).

## Project layout

```
autoloads/   GameManager, CardDB, JuiceManager, PixelArt, Sfx
scenes/      TitleScreen, MainArena, MechPlayer, RatEnemy, TowerBase
scripts/     arena/ core/ systems/ mech/ enemies/ towers/ ui/ art/
shaders/     hit_flash.gdshader
tools/       ArtPreview + SmokeTest (bot-driven automated playtest)
docs/        ARCHITECTURE.md
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the systems fit together.

### Automated playtest

```bash
godot --headless --path . res://tools/SmokeTest.tscn -- --waves=5 --speed=4 --spawn-all
```

This runs two bot pilots through several waves. They build towers, bank and cram seeds, overheat their wheels and draft cards, and the run ends with a printed summary.
