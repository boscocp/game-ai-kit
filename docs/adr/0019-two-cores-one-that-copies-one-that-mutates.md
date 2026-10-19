# 0019 — Two cores: one that copies, one that mutates

Status: accepted · 2026-10-19 (T19)

## Context

`ai_core`'s `BoardState.apply` answers every move with a new board, every
unit copied into it. That is what lets minimax, the STRIPS planner and the
tactical teams try a thousand moves and throw them away: a state nobody
shares cannot be spoiled by a search that forgot to undo.

An RTS asks something else of its state: two hundred units, each moving a
little, sixty times a second. T19 was told to try to prove itself
unnecessary first, so it measured that before writing anything
(`test/rts_core_budget.gd`, this machine, Godot 4.7.2):

| | per step / tick | share of a 16.7 ms frame |
|---|---|---|
| `BoardState`, 200 units each moving one cell | **~50 ms** | 4.0 ms (simulation) |
| `ai_rts_core`, 200 soldiers marching and fighting, simulation | 0.68 ms mean, 0.80 ms p95 | 4.0 ms |
| `ai_rts_core`, flow fields | 0.34 ms mean, 1.29 ms p95 | 1.5 ms |

The old core spends three whole frames on one step. It is not slow code: it
is a copy per move, which is its design.

## Decision

A second core, `godot/addons/ai_rts_core/`, beside `ai_core`, not in place
of it:

- **`RtsWorld` mutates.** One fixed tick at a time, continuous positions, a
  spatial hash for "who is near", flow fields shared by everyone going to
  one place, settled `FIELD_CELLS_PER_TICK` cells a tick.
- **`RtsSnapshot` is the frozen copy**, and the only thing a controller is
  ever shown: one side's view, through its fog, as read-only plain values
  -- its own units whole, an enemy's only as a player would see it, and a
  board with only the buildings in sight on it, since a blocked cell in fog
  would say where the enemy built. The rules hold the same line: an unseen
  unit and a dead one get one refusal, and nobody builds where they cannot
  see. The game mutates; the planner reads a snapshot.
- **`RtsCommand` is the one way in**, for a person and an AI alike, and
  `RtsRules` refuses what a side may not do before any of it is done.
- **`RtsMatch` records** the seed and every accepted command; a replay on a
  fresh world with no controller must reach the same digest, which is how
  a change made outside the interface shows.
- **The clock only measures.** `FrameBudget` holds the shares in
  milliseconds, but what a layer does within its share is counted in work,
  never cut off by time, because a match decided by the clock would not
  replay.

It depends on `ai_core` (the `GridGraph`) and on nothing else, as invariant
2 asks.

## Alternatives considered

- **Make `BoardState` mutable, with undo.** Every search in the kit is
  written against a state it may keep; undo would be a second contract each
  of them must honour, and a missed undo is the bug nobody sees. Teaching
  material loses most there.
- **Copy-on-write units inside `BoardState`.** Cheaper copies, the same
  shape: still a new board a move, and the measured cost is in the
  dictionary and array copies as much as in the units.
- **Use Godot's physics and navigation servers.** Fast, and not
  deterministic across machines nor headless-replayable from a seed, which
  T20's league and T25's recordings need first.

## Consequences

- Two `Unit` types, `Unit` and `RtsUnit`, and two ways a board changes. The
  addon headers each say when not to use them, pointing at the other.
- Something that searches over an RTS position (T20's planner) builds its
  own small state from a snapshot, as `ai_planning` does from a board.
- The numbers are one machine's. `make test-rts-budget` re-measures; the
  flow-field p95 is the closest to its share and is the first to watch on a
  slower machine.
