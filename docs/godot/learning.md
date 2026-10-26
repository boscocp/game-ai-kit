# Wiring ai_learning into a game

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html ; https://docs.godotengine.org/en/stable/classes/class_json.html
invalidated_if: Godot changes how class_name registers a class or how JSON reports a parse error, or the weights.json layout changes
teaches: learning
-->

> How to load the published weights, hand the policy a board and read what it
> decided and why. Every snippet was run on the pinned Godot 4.7.2 on
> 2026-10-13, and the outputs shown are what it printed. Where the weights come
> from is [the concept page](../concepts/learning.md).

## What to copy

`addons/ai_core/` and `addons/ai_learning/`: the model, its file and a case
table, and nothing about any board. From a release, unzip both zips into
`res://addons/`. The addon only reads a weights file; it has no training code,
and `make lint-no-training` keeps it that way.

The rest of this page is the tactical board's **adapter**, which lives with
the game in `godot/game/tactical/` since T60: `BoardFeatures` turns a board
into a feature row, `LearnedPolicy` and `LearnedDecision` turn a probability
into a move, and `weights.json` is that board's fit. Your game writes its own
adapter the same way; it copies these only as an example.

## Load the weights, and refuse a bad file

```gdscript
var file: ModelFile = ModelFile.load_from("res://my_game/weights.json")
if not file.is_loaded():
	push_error(file.error)
var chance: LearnedModel = file.model("chance")
```

That is the whole of the addon's side, for any game: a JSON object whose
`models` maps a name to `kind`, `features`, `weights` and `bias`, which is
what `gameaikit.training.model_file` writes. A missing or malformed file loads
**no** models rather than half of one, and `error` says why in a sentence with
a code in front:

```
M1 no model file at res://nowhere.json
```

Anything else in the file -- the numbers a game needs that are not weights --
is handed over unread in `file.extra`, and checking it is the game's job. The
tactical board does it in `TacticalWeights`, over a loaded `ModelFile`: its
four `feature_conventions`, refused with `W6` and `W7` as
`gameaikit.tactical.report` refuses them. Since wave 99 (T106); before it the
addon refused every file without the tactical board's conventions.

```gdscript
var weights: TacticalWeights = TacticalWeights.load_from(LearnedPolicy.WEIGHTS_PATH)
```

The file is read with `JSON.new().parse()` rather than the static
`JSON.parse_string`, because only the first lets the addon write that sentence
instead of an engine error -- see [reading JSON in Godot](reading-json-in-godot.md).

## A decision, with its reason

```gdscript
var units: Array[Unit] = [
	Unit.new(1, 0, Vector2i(5, 3), 10, 4),   # id, faction, cell, health, points
	Unit.new(2, 1, Vector2i(6, 3), 4, 4),
]
var state := BoardState.new(GridGraph.new(12, 8), units, 0)
var policy := LearnedPolicy.new(weights, [Vector2i(10, 1)] as Array[Vector2i],
	LearnedPolicy.DEFAULT_THRESHOLD, AStarSearch.new())

var decision: LearnedDecision = policy.decide(state, 1)
print(decision.action, " ", decision.reason)
# attack unit 1 attacks unit 2: p(win) 0.95 at or above 0.50
```

`decide` returns the whole decision: `action` (attack, retreat, contest,
advance or hold), the `move`, the `win_probability` or `predicted_turns` it
rests on, and `reason`, a sentence carrying the number. `contest` is the one
that carries none: a unit with no fight in reach walks at a node an enemy
stands on before the capture model is asked, and its reason says it is a
rule, not the model (T41). Show the reason on screen. A unit
stepping backwards looks the same whether a model gave it a 3% chance or it
had nowhere to go, and only the number tells them apart. `make run` prints
every blue unit's reason under the status line for that reason.

`choose(state, unit_id)` is the `DecisionPolicy` contract and returns only the
`Move`, which is always legal on `state` or empty, meaning "hold".

## The three arguments after the weights

* **nodes** -- the cells worth taking. The capture model ranks them; with one
  node there is nothing to choose.
* **threshold** -- the probability at which *retreat* becomes *attack*.
  `DEFAULT_THRESHOLD` is 0.5, the same threshold the training scores accuracy
  at. Lower is a braver opponent, higher a more cautious one.
* **router** -- a `Pathfinder`, to walk routes rather than single steps. It is
  passed in rather than built inside because a route is a search, and no addon
  may depend on another. `null` is allowed: the unit then walks greedily,
  each step the neighbour nearest the target, and a wall a search would go
  round can stop it.

## When the models are asked about something they never saw

The weights were fitted on boards with terrain from 1 to 3 and on fights
between two units. `weights.json` publishes the ranges it saw and the
conventions both languages must share; the game reads them rather than keeping
a copy, because a number two languages must agree on, kept in two files, will
one day differ. A row the model cannot read comes back as `NAN`, and the
policy holds rather than acting on it as a low probability.
