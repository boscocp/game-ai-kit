# 0021 — The board is the examples' kernel, not `ai_core`'s

Status: accepted, amended · 2026-10-20 (T61; the owner's decision of
2026-10-20; amended by T109 on the owner's decision of 2026-10-29 -- see the
amendment at the end)

## Context

`ai_core` was described as "types and interfaces, no logic", the one
folder every addon may depend on (invariant 2). By wave 63 it also held the
tactical board's whole domain: `BoardState` (funds, upgrades, production,
`apply`, `why_refused`), `Unit`, `UnitType`, `Attack`, `Upgrade`,
`ProductionOrder` -- and `Move` and `DecisionPolicy`, whose one method is
`choose(state: BoardState, unit_id: int) -> Move`.

Measured on `e0f5589`, after T60 took the learned policy's adapter out of
`ai_learning`: no addon used any of those eight classes in code. Their
users were the examples -- the tactical board, the league, the skirmish,
the behaviour demo, the stealth room, the shared views. But because
`ai_core` was the kernel, a change to `BoardState` selected 19 modules,
among them `ai_rts_core`, `rts`, `ai_search` and `demo_racing`, none of
which uses the board (T58, `affected.py`).

## Decision

`ai_core` keeps what more than one technique truly shares: `GridGraph` and
`Pathfinder`. The eight board classes move to **`godot/game/board/`**, a
module of kind `kernel` named `board`: the examples' shared kernel, in
DDD's sense, kept apart from the techniques' one.

This overrides T58's sketch, which kept `Move` and `DecisionPolicy` in
`ai_core`. Both are typed on the board and are used only by its games.

## Alternatives

- **An addon, `ai_board`.** An addon is something a reader copies into
  their own game, and it ships as a zip with LICENSE and NOTICE. Nobody
  wants this board without these examples, and a zip of it would be a
  promise to keep it general. Rejected on that ground, and as the owner
  decided.
- **Leave it in `ai_core`.** The cost is measured, not guessed: every board
  change selects the whole kit, and a reader copying `ai_core` for A*
  gets a strategy game's state with it.

## Consequences

- Invariant 2 reads as it always meant to: an addon depends on `ai_core`,
  the grid and one interface. `check_addon_deps.py` needs no change,
  because no addon uses the board in code.
- A change to the board selects the turn-based examples and not the
  techniques, the RTS or the racing demo.
- Addon comments no longer name board classes a reader of one addon does
  not have. They may still say what the addon is not for.
- `godot/game/board/` is not released as an addon zip. The release's
  `ai_core` zip gets smaller.

## Amended (2026-10-29, T109): one seeded generator

**What was decided.** The owner, on 2026-10-29, as `docs/godot/maze.md`
recommended: one seeded generator in `ai_core`, `Xorshift`, with its
Python twin `gameaikit.core.Xorshift`, drawing exactly what each copy drew
from the same seeds.

**Why.** When the owner decided, the kit held Marsaglia's 32-bit xorshift
three times: `ai_adversarial`'s `Xorshift` (T86), the maze's `MazeDice`
(T97) and `ai_perception`'s `ParticleDraws` (T91), each with a Python twin.
T99 (wave 115) then added a fourth, `ai_bandit`'s `BanditDraws`, and T109
folds it in on the same ground -- that one is T109's reading of the
decision, put to the owner in its pull request. Each copy said why it was
one: an addon may depend on no other addon (invariant
2), and there was no shared place to put it. A generator is what more than
one technique truly shares, which is the line this record draws.

**Why a generator is not "logic" in the sense this record refuses.** What
left `ai_core` in T61 was a game's domain: funds, production, what a move
is and why it is refused. A generator decides nothing about any game. It
has no rule and no domain word: it turns a seed into a stream of numbers,
and which draw means what -- a move to expand, a particle's step, an arm
to try, a ghost's way at a fork -- stays in the technique that draws. It
is a building block in the sense `GakGridGraph` is one: every user of it
could have written it, and each one did.

**What does not follow from it.** `ai_core` is not now a home for helpers.
Nothing else enters it on the strength of this amendment: another utility
comes in only with the same argument written down here -- that more than
one technique already shares it, that each copied it for want of a place,
and that it decides nothing about any game -- and the owner's decision.

**Consequences.**

- `ai_adversarial` and `ai_bandit` now depend on `ai_core`, as
  `ai_perception` already did; their pages say to copy two folders. The
  maze lists `ai_core` instead of carrying its own dice.
- `spec/vectors/core/` holds the generator in both languages (`make
  test-core-vectors`, and `make test-python`). The vectors of the four
  users -- `spec/vectors/adversarial/`, `bandit/`, `perception/`, `maze/`
  -- did not change, and pass read through the shared generator: that is
  the proof that no draw moved.
- The wheel ships `gameaikit.core`, the kernel's package, beside the
  techniques'.
- `Xorshift` keeps its name without the `Gak` prefix (ADR 0024): it is an
  algorithm's name, like `AStarSearch`, not a port a game extends.
