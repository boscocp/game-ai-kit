# 0006 — Turn-based before real-time

Status: accepted · 2026-10-13 (T7; the decision was taken when milestones 2 and
3 were written, and lived only in the task files until now)

## Context

`BoardState.apply` returns a **new** state and copies the unit list into it.
That is what lets a search, a planner or a training run try a thousand moves
without the board remembering any of them: there is no undo to get wrong,
because there is nothing to undo.

It is also the wrong shape for two hundred units at sixty frames a second. A
copy of the unit list per move, per search node, per frame, is the cost a
real-time game cannot pay, and the fix -- mutate in place, keep an undo stack
-- is a different core with a different lesson.

## Decision

The strategy game is turn-based first, shaped like Advance Wars rather than
StarCraft (T10), and reuses `ai_core` exactly as it is. The RTS comes last,
after all three games, in its own milestone, with the core it needs (T19).

## Alternatives considered

- **Real-time from the start.** The more impressive demo. Rejected: every
  technique here would have been taught against a mutable board, and the
  first lesson would have been undo stacks rather than search.
- **One core that does both.** A state that copies for search and mutates for
  play. Rejected for now: two behaviours behind one type is the kind of
  cleverness invariant 1 exists to refuse, and nothing yet needs it.

## Consequences

- Every technique so far is taught on a value it may copy freely, which is
  why the search, the planner and the learned policy all take a `BoardState`
  and none of them can corrupt it.
- The copy is a known cost with a named limit, written in `board_state.gd`'s
  header: when copying the unit list per node matters, this core is the
  wrong one.
- T19 must not be started by bending `BoardState`. It gets its own core.
