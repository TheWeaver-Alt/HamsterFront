# ADR-0001: Godot 4 with GDScript, and every asset generated in code

**Status:** Accepted
**Date:** 2026-11-02
**Deciders:** owner

Recorded on 2026-11-02 from the code as built (first commit `a9cfc0b`), when the project was aligned to project-kit 1.0.0.

## Context

A 2D pixel-art action tower defense for 1–2 local players on desktop, with gamepad support and native exports. It is built mostly by coding agents working in text, so it helps when every change can be read and reviewed as a diff.

## Decision

- **Engine:** Godot 4.3+ (standard build, not .NET), GDScript, GL Compatibility renderer.
- **Assets:** none on disk. Sprites and tiles are painted into `Image`s at startup (`scripts/art/`, `PixelArt`), sound effects and music are synthesized into `AudioStreamWAV`s (`Sfx`, `Music`), and the 3x5 font is a bitmap `FontFile` built in code. The only file asset is `icon.svg`.

## Options considered

### Option A: Godot 4 + GDScript, procedural assets (chosen)

**Pros:** one text-only repo that agents can read and change end to end. Art and sound change through ordinary diffs. Small exports. No asset pipeline or licences to track.
**Cons:** art quality depends on code-drawn detail. Iterating on a sprite means editing code and checking it with `tools/ArtPreview.tscn`.

### Option B: Godot 4 with imported sprite sheets and audio files

**Pros:** hand-drawn art, and standard editor workflows.
**Cons:** binary files in git, an import pipeline, and assets that agents can't author or review.

## Consequences

- Easier: every visual and sound is reproducible from source, and the repo stays small.
- Harder: art direction lives in `scripts/art/` code, so polish passes are code changes.
- Revisit: if hand-made art or recorded audio becomes a goal, write a new ADR that supersedes this one.
