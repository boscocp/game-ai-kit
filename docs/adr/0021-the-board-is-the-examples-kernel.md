# 0021 — The board is the examples' kernel, not `ai_core`'s

Status: accepted · 2026-10-20 (T61; the owner's decision of 2026-10-20)

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
