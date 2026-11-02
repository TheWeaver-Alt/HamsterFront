---
name: verify
description: Run HamsterFront's checks before calling a change done. Use after editing code, and before /handoff.
---

<!-- project-kit 1.0.0 -->

# Verify a change

Run what applies, report what ran, quote failures. Never call a change done on a red check.

**Checks.** The same list is in `.claude/project-kit.json` (`checks`); keep the two in step.

- **smoke:** `bash tools/check.sh`

**Record.** Keep the real result lines ("110 passed in 4.2s", not "tests pass") for the session
log at `/handoff`.
