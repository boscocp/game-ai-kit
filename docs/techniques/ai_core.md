# ai_core — the grid every addon stands on

<!-- doc-meta
half_life: practice
verified_on: 2026-11-04
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: the kit's GridGraph, Pathfinder or Xorshift signatures change, or ADR 0021 moves what the kernel holds
teaches: none
-->

> Português: [ai_core.pt-BR.md](ai_core.pt-BR.md). The words that stay in
> English are in the [glossary](glossary.pt-BR.md).

`ai_core` is not a technique. It is the shared kernel: two types, one
seeded generator and no algorithm, so that every addon can talk about the
same board, and draw the same numbers, without depending on another addon
(invariant 2, ADR 0021).

## What it holds {#holds}

- `GakGridGraph` -- a square grid of costs: what it costs to **enter** each
  cell. One is open ground, more is harder ground, `GakGridGraph.BLOCKED` is a
  wall; nothing costs less than one. `neighbours(cell)` gives the four
  cardinal cells that may be entered, in a fixed order.
- `GakPathfinder` -- the port: one abstract method, `find_path(graph, from,
  to)`, a route that leaves out `from` and includes `to`. `ai_search`'s
  `GridPathfinder` is one; your game asks for a `GakPathfinder` and never names
  the addon that answers.
- `Xorshift` -- Marsaglia's 32-bit xorshift (2003), seeded: `next()`,
  `index(count)` (a pick of one spends no draw) and `uniform()`. Written
  out again in Python as `gameaikit.core.Xorshift`, so that the same seed
  draws the same numbers in both languages -- which Godot's
  `RandomNumberGenerator` and Python's `random` cannot promise.
  `spec/vectors/core/` holds the two to one another. It decides nothing;
  Monte Carlo search, the particle filter, the bandit and the maze's ghosts
  each say what a draw means (T109).

## When you need it {#when}

Copy `godot/addons/ai_core/` with any addon whose page says so -- today
`ai_search`, `ai_perception`, `ai_rts_core`, and `ai_adversarial` and
`ai_bandit` for the generator. An addon that neither reasons about a grid
nor draws seeded numbers (`ai_steering`, `ai_behaviour`) does not need it.

## When not to use it {#when-not}

A hex board, a navigation mesh, anything whose cell is not an integer
coordinate: `GakGridGraph` is a square grid and says so. The searches still
work there through their own port, `GakSearchGraph` -- see
[ai_search](ai_search.md). And `Xorshift` for anything a player must not
predict: its period is 2^32 - 1 and its low bits are weak.

## Deeper {#deeper}

- Why the kernel holds types and no logic, and why a generator is not
  logic: [ADR 0021](../adr/0021-the-board-is-the-examples-kernel.md).
- How an addon here is put together: [godot/addon-anatomy.md](../godot/addon-anatomy.md).
