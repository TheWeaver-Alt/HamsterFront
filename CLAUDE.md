@AGENTS.md

# Claude Code

<!-- project-kit 1.0.0 -->

Everything above comes from `AGENTS.md`, the rules for every agent. This part is only for
Claude Code. Start sessions in this folder: the hooks and the Playwright origins load from the
folder a session starts in.

## Skills

| Skill | Use |
|---|---|
| `/start` | Session start: reads the state, checks git, gives a brief |
| `/verify` | Runs the checks before a change is called done |
| `/handoff` | Session end: records what changed in `docs/PROJECT-STATE.md` |
| `/adr` | Starts a new decision record in `docs/adr/` |

## Hooks

- `.claude/hooks/guard_private.py` (PreToolUse) blocks credentials, the private paths in
  `.claude/project-kit.json`, and browser or shell access to its `never_open` ports.
- `.claude/hooks/state_sync.py` (Stop) asks for `docs/PROJECT-STATE.md` to be updated when source changed
  after it.

## Global plugins

- **project-kit:** `project-kit:align-project` checks this repo against the owner's standard.
- Design skills and browser tools never run on personal material.
