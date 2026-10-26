# ai_core — the grid every addon stands on

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
invalidated_if: the kit's GridGraph or Pathfinder signatures change, or ADR 0021 moves what the kernel holds
teaches: none
-->

> Português: [ai_core.pt-BR.md](ai_core.pt-BR.md). The words that stay in
> English are in the [glossary](glossary.pt-BR.md).

`ai_core` is not a technique. It is the shared kernel: two types and no
algorithm, so that every addon can talk about the same board without
depending on another addon (invariant 2, ADR 0021).

## What it holds {#holds}

- `GridGraph` -- a square grid of costs: what it costs to **enter** each
  cell. One is open ground, more is harder ground, `GridGraph.BLOCKED` is a
  wall; nothing costs less than one. `neighbours(cell)` gives the four
  cardinal cells that may be entered, in a fixed order.
- `Pathfinder` -- the port: one abstract method, `find_path(graph, from,
  to)`, a route that leaves out `from` and includes `to`. `ai_search`'s
  `GridPathfinder` is one; your game asks for a `Pathfinder` and never names
  the addon that answers.

## When you need it {#when}

Copy `godot/addons/ai_core/` with any addon whose page says so -- today
`ai_search`, `ai_perception`, `ai_rts_core`. An addon that does not reason
about a grid (`ai_steering`, `ai_behaviour`) does not need it.

## When not to use it {#when-not}

A hex board, a navigation mesh, anything whose cell is not an integer
coordinate: `GridGraph` is a square grid and says so. The searches still
work there through their own port, `SearchGraph` -- see
[ai_search](ai_search.md).

## Deeper {#deeper}

- Why the kernel holds types and no logic:
  [ADR 0021](../adr/0021-the-board-is-the-examples-kernel.md).
- How an addon here is put together: [godot/addon-anatomy.md](../godot/addon-anatomy.md).
