# HamsterFront

A 2D top-down action tower defense roguelite for 1–2 players (local co-op), built in **Godot 4.3+** with GDScript.

At the centre of the Backyard sits **The Great Silo**, a corrugated steel grain silo full of premium striped sunflower seeds. The **Under-Scurriers**, a glowing-eyed ratfolk cult, tunnel up from beneath the patio to steal the hoard for **The Great Horned Gouda**. Two hamsters climb into scrap-built mechs to stop them.

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

- The Backyard is a ¾-view garden with height. **Plateaus** with cliff faces separate **three canyon lanes**. Rats crawl out of burrows on the west side and funnel down the lanes to the Silo on the patio courtyard. Later waves open burrows in the courtyard itself. Rats gnaw the Silo's walls, and if its structure gives out the run is over.
- Most tower pads are up on the plateaus, where forks can't reach them but snipers, gas and thrown rats still can. Towers on high ground get **+15% range**. Mechs reach the plateaus by **ramps and stairs**, or with the **Soda-Bottle Jetpack** card: sprint into a cliff (or press jump) to rocket up or down it.
- Dead rats drop seeds. Your mech **vacuums them into the pilot's cheek pouch**. The fuller the pouch, the bigger the hamster's head and the slower the mech (up to -40%).
- Spend a full pouch in one of three ways:
  - **Bank** it at the Silo. Banked seeds fill the Silo's store, and the window on its front shows how full it is. Seeds are the currency for everything you build and upgrade. When the store is full, banking stops and the rest stays in your cheeks, so spend seeds or upgrade the Silo.
  - **Cram** it into a tower to start a 10-second **Sugar Rush Overdrive**: double fire rate, +50% damage and a repair.
  - **Spit** it as an emergency shrapnel blast that clears the screen. The seeds are lost.
- **Sprinting** heats the mech's internal exercise wheel. Above 80% it redlines. At 100% the hamster trips and spins out of control for 1.5 seconds. **Vent** steam to dump the heat. Venting also scalds nearby rats.
- **Build towers** on the wooden pads, and **upgrade** them up to level 3.
- **Upgrade the Silo** by standing next to it and pressing build (Y on a gamepad). Each level raises the store's capacity (150, 250, 400, then 600 seeds) and the silo stands taller.
- After each wave, time freezes and a **vending machine** drops from the sky. Each player picks 1 of 3 upgrade cards.

### Learning Mode (for young pilots)

Each player can turn on **Learning Mode** on the title screen (up/down on their slot):

| Level | For | Puzzles |
|---|---|---|
| Counting | ages 4–6 | count objects, which group has more, what number comes next, add within 5 |
| Maths to 10 | age 6 | add and take away within 10 with pictures, missing number, doubles |
| Maths to 20 | ages 7–8 | add and take away within 20, missing addend, counting in 2s and 5s, patterns |

About half the puzzles at every level are pictures with hardly any words: continue a pattern, odd one out, find the same shape or its shadow, biggest and smallest, which size fits the gap, mirror a picture, fit a jigsaw piece, which side of a balance is heavier. With Learning Mode on, that player's **card picks and tower upgrades activate by solving a puzzle**. Time freezes while they think, and there are big numbers, pictures to count and three answer bubbles. A wrong answer only brings a gentle "try again" and a picture hint (counting along, a flashing frame, a guide line), and the wrong bubble fades so the choices shrink. Correct answers earn **math stars** and +5 seeds. Learning Mode is set per player, so a parent and child can play co-op with it on for just one of them.

**KID MODE** (P1 toggles it on the title screen with the vent button) gives a tougher Silo, slower and weaker rats, and more starting seeds.

### Controls

| Action | Keyboard + Mouse (P1) | Keyboard, right side (P2) | Gamepad |
|---|---|---|---|
| Move | WASD | Arrow keys | Left stick / D-pad |
| Aim | Mouse | Auto-aim | Right stick (auto-aim when idle) |
| Fire | Left mouse | `/` or Numpad 0 | RT |
| Alt (Fist / Dash) | Right mouse or V | `.` | LT |
| Jetpack jump (with the card) | Space | `,` | L3 |
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
