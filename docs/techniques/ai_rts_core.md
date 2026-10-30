# ai_rts_core — many units, one frame

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://ojs.aaai.org/index.php/AIIDE/article/view/12435/12294 ; book:Elijah Emerson, "Crowd Pathfinding and Steering Using Flow Field Tiles", in Steve Rabin (ed.), "Game AI Pro", CRC Press, 2013
invalidated_if: the kit's FlowField, SpatialHash, FrameBudget, RtsWorld or RtsController signatures change, or the demos that use them are renamed
teaches: strategy-ai
-->

> Português: [ai_rts_core.pt-BR.md](ai_rts_core.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

How hundreds of units move and look around inside a sixtieth of a second.
A **flow field** (`FlowField`) answers "how do I get to that cell?" once
for everyone going there: a Dijkstra flood from the goal gives each cell an
arrow, and a unit reads the arrow under its feet -- built a slice per frame
so it never takes a whole one. A **spatial hash** (`SpatialHash`) answers
"who is near this point?" by reading only the buckets a circle touches. A
**frame budget** (`FrameBudget`) says how the frame is shared out and
measures each layer against its share. Around them, `RtsWorld` is a whole
deterministic match -- one seed and one list of commands always end the
same -- that an AI sees only through a frozen `RtsSnapshot` and changes
only through `RtsCommand`s it may refuse.

## When not to use it {#when-not}

A few units with many different goals: each field is then built for one
reader, and A\* from `ai_search`, which stops when it arrives, is cheaper.
Units of wildly different sizes, or questions that cover most of the map:
a quadtree or a plain scan beats the hash. And anything turn-based or
searched over moves: `RtsWorld` changes in place, so a search cannot try a
move and take it back -- the examples' board does that (ADR 0019).

## Where to watch it {#watch}

- `make demo-rts` -- every unit you order walks a shared flow field;
  **drag** selects, **right click** orders. **V** watches two computers
  play, **I** shows the influence the commander reads, **F** toggles the
  fog that `RtsWorld.visible_to` computes.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/game/rts/` is the RTS built on this core: `rts.gd` steps an
`RtsWorld` at 60 ticks a second, the world settles at most
`RtsWorld.FIELD_CELLS_PER_TICK` cells of flow field a tick, and
`rts_commander.gd` is an `RtsController` that plans. The knobs that
matter:

| knob | where | what it changes |
|---|---|---|
| flood steps per tick | `FlowField.settle(budget)`; the world's `FIELD_CELLS_PER_TICK` | how soon a new field is ready, against how much of the frame it takes; a budget counts steps of the flood (`FlowField.work`), not cells settled |
| cell costs | `GakGridGraph.set_cost`, `GakGridGraph.block` | where the arrows lead; a field already built does not see a change |
| bucket size | `SpatialHash.new(size)` | about the radius most questions ask; smaller reads more buckets, larger turns more away |
| the shares | `FrameBudget.SHARES` | milliseconds each layer may take of the 16.7 |
| how often the AI decides | `RtsMatch.decide_every` | ticks between decisions; half a second by default |

## In your own project {#your-project}

### What to copy {#copy}

Two folders: `godot/addons/ai_core/` (the grid the field floods) and
`godot/addons/ai_rts_core/`. Open the project once, or run
`godot --headless --import`, so Godot registers their classes. `FlowField`,
`SpatialHash` and `FrameBudget` are generic. **A finding:** `RtsWorld`,
`RtsRules`, `RtsOrders` and `RtsKinds` are the kit's own RTS -- its unit
kinds, costs and orders written in -- and cannot be wired into another
game in a few lines; take the three generic classes, or the whole RTS as
it is.

### A minimal example {#example}

A map of yours where any number of units are sent to one cell. The field
is built a slice a frame; then each unit asks `step_from(cell)` and steps
that way, round a wall, through its gap. This file is run by
`flow_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_rts_core/flow_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_rts_core.md, run by
# flow_example_test.gd. A map of your own where any number of units are
# sent to one cell, and the way there is worked out once for all of them,
# a slice every frame.
extends Node

## How many steps the flood may take in one frame -- each step takes one
## cell off its queue, a stale copy or an empty bucket included, so a few
## settle nothing: the share of the frame you give it. More, and the field
## is ready sooner.
const STEPS_PER_FRAME: int = 64

## Your map: 1 is open ground, dearer cells are slower, blocked is a wall.
## Change it before you send anyone; a field already built does not see it.
var map := GakGridGraph.new(24, 16)

var _field: FlowField


func _physics_process(_delta: float) -> void:
	if _field != null:
		_field.settle(STEPS_PER_FRAME)


## Send everybody to `goal`. The field is built over the next frames.
func send_everyone_to(goal: Vector2i) -> void:
	_field = FlowField.new(map, goal)


## Which way a unit standing on `cell` steps now: one of the four
## directions, or zero when it has arrived, when nothing reaches the goal
## from there, or while the field is still being built.
func step_from(cell: Vector2i) -> Vector2i:
	if _field == null or not _field.complete:
		return Vector2i.ZERO
	return _field.direction_at(cell)
```

### What you implement {#implement}

The units and the moving. A unit of yours turns its position into a cell,
asks `step_from`, and moves towards the centre of the next cell at its own
speed -- smoothly, with its own steering or `CharacterBody2D`; the field
only says which way. Fill `map` from your `TileMapLayer` (`set_cost`,
`block`) and build a new field when it changes. A field for every place
anyone is going is one `FlowField` each; keep the ones in use and drop the
rest, as `RtsWorld` does after a second unasked. To find who is near, file
each unit with `SpatialHash.place(id, position)` every time it moves and
ask `near(centre, radius)`.

## Deeper {#deeper}

- The RTS: a commander that plans, against a clock:
  [concepts/rts-ai.md](../concepts/rts-ai.md).
- Why the RTS core mutates and the board copies:
  [ADR 0019](../adr/0019-two-cores-one-that-copies-one-that-mutates.md).
- The grid itself: [ai_core](ai_core.md).
