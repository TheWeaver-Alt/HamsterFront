---
name: start
description: Start a session on HamsterFront - read where the project stands and check the working tree before touching code. Use at the start of a session, or when picking up work another session left.
---

<!-- project-kit 1.0.0 -->

# Start a session

Before editing anything:

1. Read `AGENTS.md`, then `docs/PROJECT-STATE.md`: the masthead, **Now**, **In progress**, **Next**,
   **Known gaps and risks** and the newest **Session log** entry (or the project's own names
   for them).
2. Run `git status --short` and `git log --oneline -5`. If the tree holds changes the state
   doesn't mention, say so before going further.
3. If the state's **Last updated** is older than the newest commit, say that the last session may
   not have handed off.
4. Reply with a short brief, then wait for the task:
   - where the project stands (two or three lines from **Now**)
   - what was in progress, and the next step recorded
   - anything inconsistent: uncommitted changes, stale state, checks known to fail

Don't start the next step on your own; confirm the task with the owner.
