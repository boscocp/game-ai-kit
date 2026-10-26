# ai_learning — using what Python learned

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 19, linear and logistic regression ; https://docs.godotengine.org/en/stable/classes/class_json.html
invalidated_if: the kit's LearnedModel, ModelFile, SoftmaxModel, CaseTable or ClonedPlayer signatures change, or the demos that use them are renamed
teaches: learning
-->

> Português: [ai_learning.pt-BR.md](ai_learning.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

Nothing by itself: it is the inference half of machine learning. Python
fits a model to data and publishes its numbers in a JSON file; this addon
reads them back and multiplies. `LearnedModel` is one number per feature
and a bias -- `w·x + b` -- answering a yes-or-no question as a probability
(`LOGISTIC`) or a how-much one as the number itself (`LINEAR`).
`SoftmaxModel` answers "which of these?" with a probability for each answer.
`CaseTable` is a ghost: what a recorded player did in each situation it met,
looked up rather than fitted. Nothing here changes a weight (invariant 6).
The book: Russell and Norvig, *AIMA*, chapter 19.

## When not to use it {#when-not}

A model that is not one number per feature: a tree, a hidden layer,
anything with structure -- these classes cannot hold one. Features that
matter only together ("a low kick when close, unless cornered"): these
models add, so the product has to be written in as a feature of its own.
And any learning during play: fitting is Python's, on a desk, reviewed --
the one exception is `ai_opponent`'s n-gram (ADR 0016).

## Where to watch it {#watch}

- `make demo-skirmish` -- blue is a learned policy: each unit asks a
  logistic model how likely an attack is to win, and the board shows the
  probability beside the attack it weighed.
- `make demo-tactical` -- **C** until the computer is "learned": the same
  models on the tactical board.
- `make demo-fighting` -- **M** cycles the dummy; "ghost: exact", "ghost:
  nearest" and "clone" are a `CaseTable` and a `SoftmaxModel` fitted to a
  recorded player (see [behaviour_cloning](behaviour_cloning.md)).
- `make run` (checkers) declares this addon in its manifest but uses none
  of its classes: its learned weights are read by its own
  `CheckersWeights` (see [learned_evaluation](learned_evaluation.md)).
- Which demo uses which technique, both ways: the catalogue (T76, coming).

## In this kit {#in-this-kit}

`godot/game/main.gd` (the skirmish) and `godot/game/tactical/learned_blue.gd`
load `weights.json` through `ModelFile.load_from` and hand it to
`LearnedPolicy` (`learned_policy.gd`), which takes the `combat` and
`capture` models from it and compares the combat model's probability
against a threshold.
`godot/game/fighting/fight_clone_opponent.gd` plays a `ClonedPlayer`. The
knobs that matter:

| knob | where | what it changes |
|---|---|---|
| the weights | the JSON file Python publishes | everything the model concludes; changed only by fitting again |
| the threshold | `LearnedPolicy.DEFAULT_THRESHOLD`, or your own comparison | how sure the model must be before the unit acts; braver below a half |
| the features | `LearnedModel.features` | read from the file, in the file's order; `predict_named` matches by name |
| exact or nearest | `CaseTable.exact` or `CaseTable.nearest` | what a ghost does in a situation the player never met |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_learning/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. The fitting is Python's: `python/gameaikit/`
(`training/` for the regressions, `cloning/` for a cloned player) -- copy
what you fit with, and keep it out of the game.

### A minimal example {#example}

A unit of yours that asks a model Python fitted how likely an attack is to
win. The model's entry is written in the file so the example runs alone;
yours comes from your JSON file. This file is run by
`chance_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_learning/chance_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_learning.md, run by
# chance_example_test.gd. A unit of your own that asks a model Python
# fitted how likely an attack is to win, and only multiplies -- it never
# changes a weight.
extends Node

## One model as Python publishes it. Your game reads this from the JSON file
## your Python side wrote; it is here so the example runs on its own.
const PUBLISHED: Dictionary = {
	"kind": "logistic",
	"features": ["my_health", "their_health", "distance"],
	"weights": [0.05, -0.05, -0.2],
	"bias": 0.5,
}

var _model: LearnedModel


func _ready() -> void:
	_model = model_from(PUBLISHED)


## A model from one published entry, or null when the entry is not one --
## refused whole, as the kit's `ModelFile` does, never filled in with a guess.
static func model_from(entry: Dictionary) -> LearnedModel:
	if not LearnedModel.KINDS.has(entry.get("kind")):
		return null
	if not (entry.get("bias") is float or entry.get("bias") is int):
		return null
	var features := PackedStringArray(entry.get("features", []))
	var weights := PackedFloat64Array(entry.get("weights", []))
	if features.is_empty() or features.size() != weights.size():
		return null
	return LearnedModel.new(entry["kind"], features, weights, float(entry["bias"]))


## How likely an attack is to win, 0 to 1, from the facts by name. A fact the
## model needs and was not given answers NAN, which no threshold passes.
func chance_to_win(facts: Dictionary) -> float:
	return _model.predict_named(facts)
```

### What you implement {#implement}

The features, measured from your game under the names the file uses, and
what to do with the answer -- usually one comparison against a threshold.
The weights apply to raw game numbers: the Python side folds its scaling
back in before publishing, so there is nothing to scale here. **A finding:**
`ModelFile`, the kit's loader, refuses any file without the tactical game's
four `feature_conventions` (`nearby_radius` and three more), so outside
that game build `LearnedModel` from your own entry, as the example does --
or publish those four. `ClonedPlayer.load_from(path)` has no such tie: it
loads any cloned player the Python side writes.

## Deeper {#deeper}

- The two regressions, fitted and read: [concepts/learning.md](../concepts/learning.md).
- The file's shape and the Godot side: [godot/learning.md](../godot/learning.md).
- A player cloned from recordings: [behaviour_cloning](behaviour_cloning.md).
