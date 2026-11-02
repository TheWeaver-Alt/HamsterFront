# Defence of HamsterFront: Mech-Pouch Protocol

A 2D top-down action tower-defense roguelite for 1–2 players on one screen, built in **Godot 4.4** with GDScript.

At the center of the Backyard sits **The Great Silo**, a plastic bucket full of striped sunflower seeds. The **Under-Scurriers**, a cult of glowing-eyed ratfolk, have dug tunnels under the patio to steal it for **The Great Horned Gouda**. Two hamsters pilot junkyard mechs to stop them.

The project ships with **zero art or audio assets**. All of it is generated in code:

- sprites are drawn with `_draw()` as chunky pixel art
- the ground tiles are painted into an `Image` at startup and loaded into a `TileSet`
- text uses a custom 3×5 pixel font
- every sound effect is synthesised into an `AudioStreamWAV` buffer at startup

## Running

1. Install Godot **4.3 or newer**. The project targets 4.4 and uses `TileMapLayer` and `Image.create_empty`, which need 4.3+.
2. Open `project.godot` in the editor and press **F5**. From the command line:
   ```bash
   godot --path .
   ```
3. The game renders at 640×360 and is scaled up 3× (integer scaling) to 1920×1080. It uses the GL Compatibility renderer.

## Controls

| Action | P1 BRAWLER-01 (keyboard + mouse) | P2 WHEELER-X (gamepad 0) | P2 keyboard fallback |
|---|---|---|---|
| Move | WASD | Left stick | Arrow keys |
| Aim | Mouse | Right stick (auto-aims when the stick is idle) | Auto-aim |
| Primary | LMB: Sawdust Shotgun | RT / RB: Toothpick Railguns | `/` |
| Alt | RMB: Cardboard-Tube Fist | LT: Turbo Dash | `.` |
| Sprint | Shift | LB / L3 | `'` |
| Vent steam | Space | B | `;` |
| Bank seeds at Silo / cram into tower | E | A | Enter |
| Pouch Spit (emergency blast) | F | Y | `\` |
| Pick blueprint | 1–5, or Q / Z to cycle | D-pad ← → | `[` `]` |
| Place tower | R | X | P |
| Cancel blueprint | C | D-pad ↓ | O |
| Join / start | E or click | Start or A | Enter |
| Call next wave early | G | Start | G |
| Pause | Esc | Back | Esc |

If a second gamepad is connected, it controls P1 (device 1). Either player can start a run from the title screen. The other player can drop in at any time.

## How to play

- **Cheek pouch.** Your mech vacuums up seeds that rats drop. As the pouch fills, the pilot's head inflates and the mech slows down, by up to 40% when full.
  - **Bank** the seeds at the Silo (**E**) to add them to the shared economy. Towers are paid for from the bank.
  - **Cram** 5 or more seeds into a tower for a 10-second **Sugar Rush Overdrive**: ×2.5 fire rate and ×1.5 damage.
  - **Spit** 5 or more seeds out as a radial shrapnel blast with hit-stop. Damage scales with how many seeds you spat.
- **Hamster wheel heat.** Sprinting heats the wheel. Past redline you have a moment to vent steam. If you don't, the pilot trips and spins out for 1.5 seconds.
- **Towers** are built on wooden pads around the Silo:

  | Tower | Cost | What it does |
  |---|---|---|
  | Sunflower Gatling | 25 | Rapid fire. Leaves piles of shells that slow rats. |
  | Water-Bottle Laser | 40 | Continuous beam whose damage ramps up the longer it holds a target. |
  | Cedar-Shaving Mortar | 45 | Lobbed area attack that stuns rats with sneezing powder. |
  | Exercise-Wheel Tesla | 50 | Chain lightning. Fires twice as fast while a mech runs alongside it. |
  | Cardboard Decoy | 15 | Taunts nearby rats until they chew it apart. |

- **Card draft.** After each wave, time freezes and a vending machine drops in. Each player picks 1 of 3 cards. There are four tiers:
  - Mech Mods
  - Tower Blueprints / Mutations
  - Co-op Synergy (offered only with 2 players)
  - Warp-Cheese Corruptions (cursed)
- **Revive.** A downed mech is revived by standing next to it for 2 seconds. If nobody does, it reboots on its own after a timer.
- **Game over.** The run ends when the Silo's HP reaches 0. Press E, click, Enter or Start to retry with the same players.

## Enemies: the Under-Scurriers

| Unit | Behaviour |
|---|---|
| Clan-Squeaker | Arrives in packs of up to 20 and chases mechs that get close. A packed crowd can trip over each other's tails (10% roll). |
| Warp-Gouda Jezzail | A two-rat sniper. Shows a green laser sight for 1.2 s, then fires a dodgeable shot. |
| Plague-Stink Monk | Drops toxic gas clouds that corrode tower armor (towers take more damage) and hurt mechs. Prefers to attack towers. |
| Doom-Roomba | Bounces erratically off walls. Damages anything it touches, other rats included, and zaps nearby targets with warp lightning. |
| Rat-Ogre Bruiser | Mini-boss every 5th wave. Throws Clan-Squeakers at you as projectiles. |

Rats follow a Dijkstra **flow field** toward the Silo. Tower cells cost more to cross, so rats route around towers. If a tower blocks the cheapest path, they chew through it.

## Project layout

```
project.godot              640x360, canvas_items stretch, integer scale, Nearest filter, 2D pixel snap
autoloads/
  GameManager.gd           wave, Silo HP, banked seeds, pause, joined players, stat-modifier dicts, input map
  CardDB.gd                card definitions, tier weights, offer rolling, modifier application + callbacks
  JuiceManager.gd          hit-stop (Engine.time_scale), camera trauma shake, pooled speech-bubble barks, FX wrappers
  SFX.gd                   procedural 8-bit sound synthesis + voice pool
scenes/
  MainArena.tscn           TileMapLayer ground, y-sorted Entities, FX layers, Camera2D, UI CanvasLayer (HUD + CardDraft)
  MechPlayer.tscn          CharacterBody2D + CheekPouchComponent + WheelHeatComponent + WeaponMount
  RatEnemy.tscn            CharacterBody2D (all five rat types)
  TowerBase.tscn           StaticBody2D + DetectionRange (Area2D) + OverchargeTimer
scripts/
  arena/                   MainArena (grid, tiles, spatial hash, run state), FlowField, WaveSpawner
  components/              CheekPouchComponent, WheelHeatComponent, WeaponMount
  entities/                MechPlayer, RatEnemy, TowerBase, Silo, Projectile, MortarShell, SeedPickup, GroundEffect
  fx/                      FXLayer (batched pixel particles, beams, rings, popups), SpeechBubble
  ui/                      HUD, CardDraft
  util/                    PixelFont (3x5 procedural font), Pal (palette)
  data/                    Defs (enums, physics layers, tower/rat tuning tables)
shaders/hit_flash.gdshader canvas_item hit-flash
```

### Stat modifiers

Card effects live in `CardDB.gd` as plain dictionaries, for example `{"damage_mult": 2.0, "hallucinations": true}`. `CardDB.apply_mods()` merges them into `GameManager.player_mods[pid]` or `GameManager.global_mods` using three rules:

- keys ending in `_mult` multiply
- booleans are set
- other numbers add

Gameplay code reads the values through `GameManager.pmodf/pmodb/pmodi` and `gmodf/gmodb/gmodi`. Cards with one-off effects, such as a full repair or bonus seeds, name a callback method.

To add a card, append one `_card(...)` entry to `_define_cards()`. If the effect needs a new modifier key, also add it to `default_player_mods()` or `default_global_mods()` and read it where it matters.

## Milestones

- [x] **Phase 1, greybox core:** 2-player movement and shooting, cheek-pouch pickup / spit / speed penalty, rat pathfinding to the Silo
- [x] **Phase 2, tower grid and economy:** pad snapping for 5 tower types, seed banking at the Silo, tower overcharge
- [x] **Phase 3, roguelite loop:** scaling wave spawner, end-of-wave card draft overlay, stat-modifier dictionaries
- [x] **Phase 4, juice and procedural pixel art:** bark speech bubbles with blip audio, screen shake, hit-stop, particle bursts (seed shells, warp sparks), hit-flash shader
