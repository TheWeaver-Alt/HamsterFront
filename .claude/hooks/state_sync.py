"""Stop hook (project-kit): keep the project state in step with the code.

If any file in the project's source folders changed after the state file, ask once for the state
to be updated (or for a one-line reason it doesn't need it). `stop_hook_active` stops it asking
twice in a row. The state path and source folders come from .claude/project-kit.json. This file
is the same in every project; `kit.py check` compares it with the kit's copy.
"""

import json
import os
import sys
from pathlib import Path

KIT_HOOK = "state_sync 1.0.0"

SKIP_PARTS = {"node_modules", ".venv", "__pycache__", "dist", "build", ".git", ".pytest_cache"}
SKIP_NAMES = {"settings.local.json"}


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    if data.get("stop_hook_active"):
        return 0

    root = Path(__file__).resolve().parents[2]
    try:
        manifest = json.loads((root / ".claude" / "project-kit.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        manifest = {}
    if not isinstance(manifest, dict):
        manifest = {}
    state_rel = (manifest.get("docs") or {}).get("state", "docs/PROJECT-STATE.md")
    state = root / state_rel
    if not state.exists():
        return 0

    newest = 0.0
    for folder in manifest.get("source_dirs") or ["src", ".claude"]:
        base = root / folder
        if not base.is_dir():
            continue
        for current, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in SKIP_PARTS]
            for name in files:
                if name not in SKIP_NAMES:
                    newest = max(newest, os.stat(os.path.join(current, name)).st_mtime)

    if newest > state.stat().st_mtime + 1:
        print(
            json.dumps(
                {
                    "decision": "block",
                    "reason": (
                        f"Source changed after {state_rel}. Update it (/handoff: Now, Next and a "
                        "session-log entry), or say in one line why it doesn't need it."
                    ),
                }
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
