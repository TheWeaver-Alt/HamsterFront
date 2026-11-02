# HamsterFront

Defence of Hamsterland: Mech-Pouch Protocol. A 2D top-down action tower defense roguelite for 1-2 players (local co-op), built in Godot 4 with GDScript.

<!-- project-kit 1.0.0: the rules for every coding agent (Claude Code, Codex, Copilot). CLAUDE.md imports this file. Rules only this project has go under "Project rules". -->

## Read first

| File | Owns |
|---|---|
| `PRODUCT.md` | Who it's for, what it does, constraints, principles |
| `docs/PROJECT-STATE.md` | **Status**: what works, what's in progress, what's next, known gaps, the session log |
| `docs/ARCHITECTURE.md` | The system map as built: parts, data, boundaries, ports |
| `docs/adr/` | Decisions, one per file; `docs/adr/README.md` is the index |

## Commands

| Task | Command |
|---|---|
| smoke | `bash tools/check.sh` |

Run commands from the repository root. Pinned tools run through their pinned form (`npx -y pkg@x.y.z`, the project's own venv), never a global install.

## Working rules

- **Personal stays personal.** Never read or print credentials (`.env`, `client_secret*.json`, `token.json`, keys) or the owner's real data. Tests, screenshots, design work and browser tools only ever see synthetic fixtures with fictional names. Private here: nothing beyond credentials yet. `.claude/hooks/guard_private.py` enforces the list in `.claude/project-kit.json`.
- **Exact pins, no vendoring.** Exact versions only (`saveExact`, `==`). Third-party code comes from its package manager, never copied into the repo.
- **No global installs.** No `npm -g`, `uv tool install` or `pip install --user`.
- **No outside requests** unless an ADR names the destination: no CDNs, remote fonts or telemetry.
- **Tests come with the code.** Logic gets unit tests; a bug fix gets a test that failed before it. Never weaken an assertion or skip a test to make a suite pass.
- **Decisions get an ADR** before changing a storage shape, a trust boundary, a vendor or a public contract. Routine work inside an agreed contract doesn't need one. ADRs are never renumbered; a superseded one stays and links to its successor.
- **Docs move with the code.** One owner per fact: link to the document that owns it instead of copying it. Mark what is proposed versus what is built.
- **The owner decides** scope, real-data imports, deployment, anything destructive or outward-facing, commits and pushes.

## Session start

1. Read this file, then `docs/PROJECT-STATE.md`: the masthead, Now, In progress, Next, and the newest session-log entry.
2. Run `git status --short` and `git log --oneline -5`. Say so if the tree holds changes the state doesn't mention.
3. Give a short brief and confirm the task before starting.

## Handoff

At the end of meaningful work, record it in `docs/PROJECT-STATE.md`, not in chat:

1. Run the checks and keep the real result lines.
2. Rewrite Now; update In progress, Next and Known gaps; add a session-log entry at the top (`### YYYY-MM-DD · what changed`) with what changed, the commands and their results, open issues and the next step.
3. Update every other document whose facts changed (see Read first).

## Definition of done

- The checks pass, and their result lines are in the session log.
- No private data or credentials entered code, fixtures, logs or git.
- Remaining work is visible in `docs/PROJECT-STATE.md`. A partial fix isn't marked done.

## Project rules

- **No image or audio files in the repo.** Pixel art is painted in code (`scripts/art/`, `PixelArt`), sound and music are synthesized (`Sfx`, `Music`), and the font is built in code ([ADR-0001](docs/adr/0001-godot-4-and-procedural-assets.md)). Adding a file-based asset needs a new ADR first.
- **Godot 4.3+.** `project.godot` declares 4.3, and the owner's local editor is 4.7.2. Don't use API newer than 4.3 without an ADR. Commit the `.uid` files that newer editors write next to scripts.
- **The check is the bot playtest.** `bash tools/check.sh` imports the project, runs `tools/SmokeTest.tscn` and fails on any `ERROR:` line. Waves and cards are random, so one green run doesn't prove an intermittent bug is gone. When a new system should be exercised, give the bots a way to use it and a counter in the summary, as jetpack hops have.
- **Dev-only scenes live in `tools/`.** All three export presets exclude `tools/*`, `docs/*`, `screenshots/*` and `builds/*`.

## Code map

[README.md](README.md#project-layout) owns the folder layout and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) the system map: autoloads, scenes, arena systems, Learning Mode, stats and cards, damage interfaces, dev tools.
