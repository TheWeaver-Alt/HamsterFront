---
name: handoff
description: End a session on HamsterFront - run the checks, then record what changed, the real results, open issues and the next step in docs/PROJECT-STATE.md. Use at the end of meaningful work, or when the Stop hook says the state is behind.
---

<!-- project-kit 1.0.0 -->

# Hand off

Write it so the next session can continue from the files alone, without this chat.

1. **Check.** Run `/verify`. Keep the real result lines. If anything fails, stop and say so: a
   handoff never records a green suite you didn't get.
2. **See what changed.** `git status --short` and `git diff --stat`. Read the diff, not your
   memory of it.
3. **Update the documents that own what changed:**

   | Changed | Update |
   |---|---|
   | setup or an entry point | `README.md` |
   | a structural change | `docs/ARCHITECTURE.md` |
   | storage, a trust boundary, a vendor, a contract | a new ADR (`/adr`) |
   | agent workflow or a guardrail | `AGENTS.md` |
   | product direction | `PRODUCT.md` |

4. **Update `docs/PROJECT-STATE.md`:**
   - the masthead: **Last updated** today; **Stage** and **Next** if they moved
   - **Now**: rewrite it as facts about the project after this session
   - **In progress**: anything started and not finished, and where it lives
   - **Next**: one to three steps, in order, each small enough for one session
   - **Known gaps and risks**: add new ones, remove fixed ones
   - **Decisions**: a row for each decision made, linking its ADR
   - **Session log**: a new entry at the top, `### YYYY-MM-DD · what changed`, with what changed,
     the commands and their real results, open issues and the next step
5. **Report in one line** what was recorded and anything left unresolved. If files are
   uncommitted, name them and suggest a commit message. Commit or push only when the owner asks.
