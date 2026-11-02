---
name: adr
description: Start a new architecture decision record in docs/adr/, numbered after the highest existing ADR, and add it to the index as Proposed. Use before changing a storage shape, a trust boundary, a vendor or a public contract.
argument-hint: <short decision title>
---

<!-- project-kit 1.0.0 -->

# New ADR

1. Find the highest `docs/adr/NNNN-*.md` number. The new one is that + 1, four digits.
   Never reuse or renumber a number.
2. Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-<kebab-title>.md`.
   Title it `ADR-NNNN: <title>`; set the status to proposed (spelled the way the other ADRs
   spell it), the date to today, and fill the other header fields.
3. Fill every section, from the conversation, in the style of the newest ADRs beside it. Where
   a section asks for options, give at least two. Unknowns are written as open questions, not
   guesses.
4. Add a row to the index, `docs/adr/README.md`.
5. If it supersedes an ADR, set the old one's status to `Superseded by ADR-NNNN` and link both
   ways. The old file stays.
6. Add the decision to the Decisions table in `docs/PROJECT-STATE.md`.

Only the owner moves an ADR from Proposed to Accepted.
