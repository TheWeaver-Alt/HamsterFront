"""PreToolUse guard (project-kit).

Agents never read credentials or the project's private paths, and browser or shell tools never
open the ports the project lists as never_open. Exit code 2 blocks the call; stderr tells the
agent why. Only paths, commands and tool arguments are inspected, never the content an agent
writes, so docs may name these files freely.

The project's own lists live in .claude/project-kit.json ("private" and "never_open"). The
defaults below always apply, even when that file is missing or broken. This file is the same in
every project; `kit.py check` compares it with the kit's copy.
"""

import json
import re
import sys
from pathlib import Path

KIT_HOOK = "guard_private 1.0.0"

SECRET = re.compile(
    r"client_secret[^/\\\s'\"]*\.json"
    r"|(?<![\w.-])credentials\.json"
    r"|(?<![\w.-])token\.json"
    r"|(?<![\w.-])oauth\.json"
    r"|(?<![\w.-])\.env(?!\.example)\b"
    r"|cookies?\.txt"
    r"|(?<![\w.-])id_(?:rsa|ed25519|ecdsa)\b"
    r"|\.(?:pem|p12|pfx)\b"
    r"|backup-passphrase",
    re.IGNORECASE,
)

# The owner's real archive (ExoCortex) is never opened from any project.
DEFAULT_NEVER_OPEN = (8765,)

# Which tool_input keys hold paths, per tool. Grep's `pattern` is a regex, not a path.
PATH_KEYS = {
    "Read": ("file_path",),
    "Edit": ("file_path",),
    "Write": ("file_path",),
    "NotebookEdit": ("notebook_path",),
    "Glob": ("pattern", "path"),
    "Grep": ("path", "glob"),
}


def load_manifest() -> dict:
    path = Path(__file__).resolve().parent.parent / "project-kit.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def private_patterns(manifest: dict) -> list:
    out = []
    for entry in manifest.get("private") or []:
        pattern = entry.get("pattern") if isinstance(entry, dict) else entry
        what = entry.get("what", "private material") if isinstance(entry, dict) else "private material"
        try:
            out.append((re.compile(str(pattern), re.IGNORECASE), what))
        except re.error:
            print(f"guard_private: skipped a bad pattern in project-kit.json: {pattern!r}", file=sys.stderr)
    return out


def port_pattern(manifest: dict):
    ports = set(DEFAULT_NEVER_OPEN)
    for entry in manifest.get("never_open") or []:
        port = entry.get("port") if isinstance(entry, dict) else entry
        try:
            ports.add(int(port))
        except (TypeError, ValueError):
            print(f"guard_private: skipped a bad never_open entry in project-kit.json: {entry!r}", file=sys.stderr)
    alternatives = "|".join(str(p) for p in sorted(ports))
    return re.compile(r"(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]):(?:" + alternatives + r")\b", re.IGNORECASE)


def block(reason: str) -> int:
    print(reason, file=sys.stderr)
    return 2


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return 0
    tool = data.get("tool_name", "")
    args = data.get("tool_input") or {}
    manifest = load_manifest()

    if tool.startswith("mcp__"):
        text = json.dumps(args)
        check_ports = True
    elif tool in ("Bash", "PowerShell"):
        text = str(args.get("command", ""))
        check_ports = True
    else:
        text = " ".join(str(args.get(k, "")) for k in PATH_KEYS.get(tool, ()))
        check_ports = False

    if SECRET.search(text):
        return block("That path holds credentials. Agents never read secrets; ask the owner if a value is needed.")
    for pattern, what in private_patterns(manifest):
        if pattern.search(text):
            return block(
                f"That is {what}, which agents never open (.claude/project-kit.json). "
                "Work against the fixtures instead, or ask the owner."
            )
    if check_ports and port_pattern(manifest).search(text):
        return block(
            "That port serves real data and is never opened by agent tools (never_open in "
            ".claude/project-kit.json). Use the fixture or demo ports instead."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
