# ai_perception — what a guard sees, hears and believes

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Travis McIntosh, "Human Enemy AI in The Last of Us", in Steve Rabin (ed.), "Game AI Pro 2", CRC Press, 2015 ; https://www.gameaipro.com/
invalidated_if: the kit's VisionCone, Awareness, LineOfSight, Hearing, VisionShape or BeliefMap signatures change, or the demos that use them are renamed
teaches: perception
-->

> Português: [ai_perception.pt-BR.md](ai_perception.pt-BR.md). The words
> that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

What an agent knows of the world, before anything decides what to do about
it. Sight: `VisionCone` -- near enough, within the angle it faces, nothing
in the way -- on a grid with `LineOfSight`, or in the open with your own
line test; `VisionShape` for a body half-seen, as a certainty. Hearing:
`Hearing` through walls, `PathHearing` round them. Doubt: `Awareness`, a
number that rises while something is perceived and falls through every
phase in between -- calm, suspicious, alert -- when it is not. And belief:
`TargetMemory` keeps only what was perceived, `BeliefMap` spreads where the
target might be since. The sources: McIntosh, *Human Enemy AI in The Last
of Us*, in *Game AI Pro 2* (2015), and the others
[concepts/stealth-ai.md](../concepts/stealth-ai.md) lists.

## When not to use it {#when-not}

Hundreds of watchers on a large map: asking each cell is slow -- cast rays
outwards once per watcher, or use the engine's physics. A target that is
never half-seen -- a pickup, a door -- needs a cone's yes or no, not a
`VisionShape`. And perception that reads what the agent never perceived --
"knowing" where the player went for a few seconds after losing sight -- is
left out on purpose: players feel it as cheating.

## Where to watch it {#watch}

- `make demo-stealth` -- each guard's cone is drawn on the floor; **D**
  tints every cell by how watched it is (an `InfluenceMap` of the cones).
- `make demo-behaviour` -- the guard's senses are a `VisionCone` and
  `Hearing`, the same for its four brains; **space** plays a turn.
- `make demo-infiltration` -- guards with a `VisionShape`, an `Awareness`,
  `PathHearing` and a shared `BeliefMap` when they search. Over each guard
  is its detection bar, with its phases' thresholds as ticks; **1** swaps
  the belief, **Tab** watches the next guard.
- `make demo-botmatch` -- each bot sees with `VisionCone` in the open,
  against the arena's walls.
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/demos/behaviour/guard_senses.gd` is the smallest whole use: a cone
and hearing on a grid, feeding a suspicion. `godot/game3d/infiltration/`
uses the rest, each guard type a JSON row. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| reach and angle | `VisionCone.new(reach, half_angle_degrees)` | how far and how wide it sees; `all_round_within` adds a circle it feels whichever way it faces |
| what blocks sight | `VisionCone.new(..., opaque_from_cost)`, or your `line_is_clear` | on a grid, ground at least this dear is opaque; in the open, your raycast decides |
| the phases | an awareness row: `peak`, `decay`, `phases`, `caution` | where calm becomes suspicious becomes alert, how fast it falls, how long it stays wary after an alert |
| the rise | `Awareness.step(row, perceived, rate, seconds, now)` | how fast it grows aware while it perceives; computed by whatever reads the percept |
| a sound's reach | `Hearing.loudness_at(listener, source, radius)` | how far a noise carries; `PathHearing` measures it round the walls |

## In your own project {#your-project}

### What to copy {#copy}

Two folders: `godot/addons/ai_core/` (the grid, which the cone uses on a
grid board) and `godot/addons/ai_perception/`. Open the project once, or
run `godot --headless --import`, so Godot registers their classes.

### A minimal example {#example}

A guard of yours that sees in a cone in the open, off any grid, and grows
aware of what it sees by degrees. It faces along its own rotation and works
wherever it is placed; set `target` and read `phase()`. This file is run by
`watcher_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_perception/watcher_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_perception.md, run by
# watcher_example_test.gd. A guard of your own that sees in a cone, off any
# grid, and grows aware of what it sees by degrees: calm, then suspicious,
# then alert -- and back down through each when it loses sight.
extends Node2D

## How aware it is, as data: rising past each phase's share of the peak, and
## falling a fifth of the peak a second. Once alert, it stays at least
## suspicious for five seconds.
const AWARENESS: Dictionary = {
	"peak": 1.0,
	"decay": 0.2,
	"phases": [
		{"name": "calm", "at": 0.0},
		{"name": "suspicious", "at": 0.3},
		{"name": "alert", "at": 0.8},
	],
	"caution": {"floor": 0.3, "seconds": 5.0},
}

## How fast awareness rises while it sees, in shares of the peak a second.
const RISE: float = 0.5

## Who it is watching for. Set it from your game.
var target: Node2D

## 300 units of reach, 45 degrees either side of where the node faces.
var cone := VisionCone.new(300.0, 45.0)

var _awareness := Awareness.new()
var _seconds: float = 0.0


func _physics_process(delta: float) -> void:
	_seconds += delta
	_awareness.step(AWARENESS, sees_target(), RISE, delta, _seconds)


## True when the target is within reach, inside the cone this node faces
## along (its rotation), and nothing stands between.
func sees_target() -> bool:
	if target == null:
		return false
	return cone.sees_in_the_open(global_position, global_rotation, target.global_position, _line_is_clear)


## "calm", "suspicious" or "alert": what your game shows above the guard.
func phase() -> String:
	return Awareness.phase_name(_awareness.value, AWARENESS)


# Your walls go here: a raycast from the guard to the target, say. The
# open field of this example has none.
func _line_is_clear() -> bool:
	return true
```

### What you implement {#implement}

The line: `_line_is_clear` is where your walls go -- a
`PhysicsRayQueryParameters2D` from the guard to the target, say -- and a
`Callable` taking nothing and returning a `bool` is all `sees_in_the_open`
asks. On a grid instead, fill a `GridGraph` from your map and call
`cone.sees(graph, eye, facing, target)` with cells (`Vector2i`) and a
facing that is a step, such as `Vector2i.RIGHT`. Then what the phases mean:
the awareness says how sure the guard is, and your decision -- a tree, a
state machine, `ai_teamwork`'s utility -- says what it does about it. Check
a row once with `Awareness.problem(row)`: `""` means it is sound.

## Deeper {#deeper}

- What a guard perceives, and how suspicious that makes it:
  [concepts/stealth.md](../concepts/stealth.md).
- How shipped stealth games do it, source by source:
  [concepts/stealth-ai.md](../concepts/stealth-ai.md).
- The infiltration level, where every class here is used:
  [godot/infiltration.md](../godot/infiltration.md).
