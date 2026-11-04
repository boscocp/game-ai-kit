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
- `make run` (checkers) declares this module for its Python half: the
  trainer fits with `gameaikit.training`. The game uses none of the addon's
  classes -- its learned weights are read by its own `CheckersWeights` (see
  [learned_evaluation](learned_evaluation.md)).
- Which demo uses which technique, both ways: [the catalogue](catalogue.md#ai_learning).

## In this kit {#in-this-kit}

`godot/game/main.gd` (the skirmish) and `godot/game/tactical/learned_blue.gd`
load `weights.json` through `TacticalWeights.load_from` -- `ModelFile`, and
the tactical game's own check of the conventions it publishes beside the
models -- and hand it to
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

From the library: unzip `ai_learning-<version>.zip` into your project's
`res://addons/` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

One folder: `godot/addons/ai_learning/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. The fitting is Python's: `python/gameaikit/`
(`training/` for the regressions and `training/model_file.py` to write the
file, `cloning/` for a cloned player) -- copy what you fit with, and keep it
out of the game.

### A minimal example {#example}

A unit of yours that asks a model Python fitted how likely an attack is to
win. It loads `chance_model.json`, written by hand beside it: one model
and nothing else, which is all a model file needs. Yours is the file your
Python side wrote. This file is run by `chance_example_test.gd`, and the
gate holds the page equal to it.

<!-- example: godot/test/ai_learning/chance_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_learning.md, run by
# chance_example_test.gd. A unit of your own that asks a model Python
# fitted how likely an attack is to win, and only multiplies -- it never
# changes a weight.
extends Node

## Where your Python side wrote the model file. This one is the kit's,
## written by hand beside this example: one model, nothing else.
const MODEL_PATH: String = "res://test/ai_learning/chance_model.json"

var _model: LearnedModel


func _ready() -> void:
	_model = model_from(MODEL_PATH)


## The `chance` model in the file at `path`, or null when the file is
## refused -- whole, with the reason in one sentence, never filled in with a
## guess.
static func model_from(path: String) -> LearnedModel:
	var published: ModelFile = ModelFile.load_from(path)
	if not published.is_loaded():
		push_warning(published.error)
		return null
	return published.model("chance")


## How likely an attack is to win, 0 to 1, from the facts by name. With no
## model, or a fact the model needs and was not given, the answer is NAN,
## which no threshold passes.
func chance_to_win(facts: Dictionary) -> float:
	if _model == null:
		return NAN
	return _model.predict_named(facts)
```

### What you implement {#implement}

The features, measured from your game under the names the file uses, and
what to do with the answer -- usually one comparison against a threshold.
The weights apply to raw game numbers: the Python side folds its scaling
back in before publishing, so there is nothing to scale here. The file is
`models`, each with `kind`, `features`, `weights` and `bias`; anything else
in it is yours, handed over unread in `ModelFile.extra`. If your features
need numbers that are not weights -- a radius, what "alone" reads as --
publish them there and check them yourself on top of `ModelFile`, as the
tactical game's `TacticalWeights` does with its four `feature_conventions`.
`ClonedPlayer.load_from(path)` loads any cloned player the Python side
writes.

## Deeper {#deeper}

- The two regressions, fitted and read: [concepts/learning.md](../concepts/learning.md).
- The file's shape and the Godot side: [godot/learning.md](../godot/learning.md).
- A player cloned from recordings: [behaviour_cloning](behaviour_cloning.md).
