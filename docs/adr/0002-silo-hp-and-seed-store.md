# ADR-0002: The Silo keeps its HP and gains a seed store; seeds are the universal currency

**Status:** Accepted
**Date:** 2026-11-02
**Deciders:** owner

## Context

Today the Silo's seed pile *is* its HP: rats chew it down, the bucket cracks, and the run ends at zero (`GameManager.silo_hp`). Banked seeds are a separate counter (`GameManager.seeds`) that only buys towers. The owner wants a Silo that looks like a silo, shows how many seeds it can hold, and a single seed economy that also pays for mech upgrades. Collecting seeds in the cheeks and carrying them home should be the fun loop. The main pilot is a young child.

## Decision

- The Silo keeps **structure HP** as it is now: rats bite it, cracks show, and the run ends at zero.
- The Silo gains a **seed store** with a **capacity** and a visible fill gauge. Banked seeds go into the store, and `GameManager.seeds` is the store's content.
- **Seeds are the universal currency**: towers, tower upgrades, in-run mech upgrades, and Silo capacity upgrades.
- Spending seeds never lowers the Silo's HP.
- The Silo's look changes from a bucket to a silo with fill markings.
- When the store is full, banking stops and the rest stays in the cheeks. Nothing is lost. This default is to be reviewed once it can be played.

## Options considered

### Option A: HP plus storage (chosen)

**Pros:** spending is never punished, which suits a young pilot. HP and storage are two readable things. The existing damage visuals stay.
**Cons:** two numbers on the Silo instead of one.

### Option B: one pool

Stored seeds are both the currency and the life. Rats steal from the pile, and the run ends when it is empty.

**Pros:** one number, and tense.
**Cons:** buying a tower makes you easier to lose, which punishes the thing the game wants you to do.

## Consequences

- Easier: the economy has one currency and one place to read it.
- Harder: capacity and the cost of upgrades need balancing, because the store limits how much can be saved up.
- Revisit: rats stealing stored seeds (a carried-off sack that drops again when the rat dies) as a later pressure.

## Action items

1. [ ] Add `silo_capacity` to `GameManager`, with a cap on `add_seeds` and banking.
2. [ ] Redraw the Silo as a silo with a fill gauge (`scripts/arena/Silo.gd`).
3. [ ] Show store fill and capacity in the HUD.
4. [ ] Add a Silo capacity upgrade.
5. [ ] Make mech upgrades cost seeds (with the cards rework).
