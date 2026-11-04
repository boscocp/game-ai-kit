# ai_perception — what a guard sees, hears and believes

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: book:Travis McIntosh, "Human Enemy AI in The Last of Us", in Steve Rabin (ed.), "Game AI Pro 2", CRC Press, 2015 ; https://www.gameaipro.com/
invalidated_if: the kit's VisionCone, Awareness, LineOfSight, Hearing, VisionShape, BeliefMap or ParticleBelief signatures change, or the demos that use them are renamed
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
target might be since, and `ParticleBelief` answers the same question with
a cloud of guesses that walk like a person and thin where a guard looked
and listened. The sources: McIntosh, *Human Enemy AI in The Last
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
  `PathHearing` and a `BeliefMap` or a `ParticleBelief` when they search.
  Over each guard is its detection bar, with its phases' thresholds as
  ticks; **1** cycles the belief -- off, the grid, the particles -- **H**
  shows the reasoning, **Tab** watches the next guard. With the particles
  on, the watched guard's cloud is drawn as dots, a white square flashes on
  each cell its sight just emptied, and a purple cross marks the spot it
  chose to search from the cloud.
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
| the particles' models | `ParticleBelief`'s `walk_on` (0.7), `turn` (0.2), `unheard` (0.3), and its count | how a guessed target moves, and how much "heard nothing" counts against a guess |

## A particle filter {#particles}

AIMA's chapter 14 tracks a hidden state over time with two models: how it
moves (transition) and what a sensor says given where it is (sensor).
Filtering keeps a belief and updates it each step with both. Exactly, over
a graph, that is `BeliefMap` with a better transition -- but "a guard heard
nothing from here" and "a person keeps walking the way they were going" are
awkward to write as one table. Section 14.5.3 ("Approximate inference in
DBNs") does it by sampling: keep a few hundred guesses, move each by the
transition, weigh each by the sensor, resample by weight. Robotics made it
the standard way to track something you cannot see [Thrun 2002].

`ParticleBelief` does that over the same neighbour list as `BeliefMap`:

- **transition**: a guess walks on to a neighbour that is not where it came
  from with `walk_on`, turns to any neighbour with `turn`, else stays. On a
  graph with no geometry, "keeps its heading" can only mean "does not turn
  back"; that is what it means here.
- **sensor**: a guess on a cell a guard sees, when it saw no one, weighs 0;
  one on a cell from which the guard would have heard a footstep, when it
  heard nothing, weighs `unheard`; any other, 1. Not 0 for silence: a
  player lying prone makes no sound.
- **resampling**: systematic, every step. If every weight is 0, the cloud
  is reseeded evenly over the cells no guard sees, and `reseeded` says so.

A sighting or a report collapses the cloud onto one cell. `shares` is the
cloud counted per cell, the same shape as `BeliefMap.shares`, so a search
reads either. Every draw comes from `ai_core`'s `Xorshift`, a seeded
generator written out in both languages (`gameaikit.core` in Python), so a
cloud is held to its Python twin (`gameaikit.perception.particles`) draw for draw by
`spec/vectors/perception/particles-*.json`.

**This is not training (invariant 6).** Every probability above is a
constant written before the game starts, and nothing a game does changes
one. The weights are rebuilt from those constants each step, never
accumulated from one step to the next, which is inference -- filtering --
not a fit. `check_no_training.py` agrees for the
right reason: its N3 rule looks for writes into a model's `weights` or a
compound update of them (`weights[i] /= total`), and the code never does
either -- each step builds a fresh array of weights from the constants,
since the old ones mean nothing once the cloud has moved.

**Does it find you sooner?** Measured in the infiltration level
(`make test-infiltration-tracking`): no difference worth the name -- the
numbers are on [godot/infiltration.md](../godot/infiltration.md#particles-against-the-grid).
In 35 of 41 paired runs the guards found the player at the same moment
with either belief, because a glimpse on the way collapses both alike; the
few that differ go both ways by a second or two. The scenarios measured
have little power to tell the two apart, and the page says why.

**Give it enough particles.** Fewer particles than nodes leaves most nodes
with no share at all after a reseed, and one particle can weigh more than
a node's even share; the infiltration level gives two a cell. That costs:
a belief step of 1784 particles measured 1.5 ms there.

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_core-<version>.zip` and
`ai_perception-<version>.zip` into your project's `res://addons/` -- [using
the library](using-the-library.md) has every step, the Python wheel too. Or
copy them from a checkout:

Two folders: `godot/addons/ai_core/` (the grid, which the cone uses on a
grid board) and `godot/addons/ai_perception/` -- for a particle belief
alone, `particle_belief.gd` and `ai_core`'s `xorshift.gd` are enough. Open the project once, or
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


func _ready() -> void:
	# A row with phases out of order, or a caution floor above alert, is
	# refused here rather than found out in play.
	if Awareness.problem(AWARENESS) != "":
		push_error(Awareness.problem(AWARENESS))


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
asks. On a grid instead, fill a `GakGridGraph` from your map and call
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
- The particle filter's sources, opened on 2026-10-26: AIMA 4th ed., ch. 14,
  section 14.5.3 "Approximate inference in DBNs"
  (<https://aima.cs.berkeley.edu/contents.html>); Thrun, S. "Particle Filters
  in Robotics", UAI 2002 (<https://arxiv.org/abs/1301.0607>).
