# Learned evaluation — scoring a position by weights fitted to results

<!-- doc-meta
half_life: practice
verified_on: 2026-10-26
tier: 2
source: book:Arthur L. Samuel, "Some Studies in Machine Learning Using the Game of Checkers", IBM Journal of Research and Development 3(3), July 1959
invalidated_if: CheckersEvaluation, CheckersWeights, the weights file's shape or gameaikit.checkers's report change, or make run stops opening checkers
teaches: learned-evaluation
-->

> Português: [learned_evaluation.pt-BR.md](learned_evaluation.pt-BR.md). The
> words that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

How good a position looks, when the search must stop before the game ends.
The evaluation counts a few things -- in checkers, men, kings and rows
advanced, each the player's minus the opponent's -- and adds each count
times its weight. Written by hand, the weights are a guess: a man 1, a king
1.5. Learned, they are fitted in Python to who won the games each position
came from: logistic regression over self-play, so each weight says how much
its count moves the odds of winning. The search (`ai_adversarial`) does not
change; only the numbers it is handed do. After Samuel's 1959 checkers
program, which tuned its coefficients by play -- here the fit happens once,
offline, and the game only multiplies.

## When not to use it {#when-not}

When nobody can say which counts matter: a fit only weighs the features it
is given, and three good counts fitted beat thirty guessed ones. Counts
that move together (men and advancement here, r = 0.89, measured in the
wave 33 review -- see
[concepts/learned-evaluation.md](../concepts/learned-evaluation.md)) share their credit
unpredictably, so a weight alone is not a lesson about the game. And
weights that change during play: that is training at game time, which
invariant 6 forbids.

## Where to watch it {#watch}

- `make run` -- checkers against minimax. **E** switches white between the
  hand-written weights and the learned ones; the panel shows, for the
  position at the end of the line it expects, what each count adds to the
  score under both. **1-6** set the depth, **space** plays its move.
- Which demo uses which technique, both ways: [the catalogue](catalogue.md#learned_evaluation).

## In this kit {#in-this-kit}

The fitting is `python/gameaikit/checkers/`: `selfplay.py` plays the games,
`train.py` fits the three weights with the kit's trainer
(`gameaikit.training`), and `report.py` publishes them with the hand ones
and the match between the two to `godot/game/checkers/checkers_weights.json`
(`make train-checkers`). In Godot, `checkers_weights.gd` reads the file and
refuses one whose features are not the evaluation's, in order;
`checkers_evaluation.gd` multiplies. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| the features | `CheckersEvaluation.FEATURES`, and Python's `FEATURES` | what the evaluation can see; the two lists must match, and the vectors hold them to it |
| which weights | **E** in the game, `CheckersGame.weights` in code | hand-written or learned; the search is the same |
| the games fitted on | `python/gameaikit/checkers/selfplay.py` | what positions the weights have seen |
| the seed | `report.py` | the fit is deterministic: `make lint-no-training` fits again and compares (N7) |

## In your own project {#your-project}

### What to copy {#copy}

The library has the Godot half, `ai_adversarial-<version>.zip` and
`ai_learning-<version>.zip`, and the wheel installs `gameaikit.training`
([using the library](using-the-library.md)). The checkers case is the
example's and is copied:

The Python side fits: `python/gameaikit/checkers/` is the worked case --
its `evaluation.py` and `selfplay.py` are what you rewrite for your game --
with `python/gameaikit/training/` for the regression, standard library
only. The Godot side only multiplies: `godot/addons/ai_adversarial/` for
the search and `godot/addons/ai_learning/` for `LearnedModel`, which is
the same multiply over any features you name.

### A minimal example {#example}

The evaluation a game of yours hands its search, reading weights Python
published. Given the kit's own checkers file, it scores every position
exactly as the checkers game does. This file is run by
`evaluation_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/checkers/evaluation_example.gd -->
```gdscript
# The minimal example on docs/techniques/learned_evaluation.md, run by
# evaluation_example_test.gd. The evaluation a game of your own hands its
# search: counts your game takes of a position, each times a weight Python
# fitted to results. Here it only multiplies.
extends RefCounted

var _model: LearnedModel


## The weights in the file Python wrote at `path`: its `features`, and the
## `weights` under `learned`, one per feature, in that order. `is_ready()` is
## false when the file is not one.
func _init(path: String) -> void:
	var reader := JSON.new()
	if reader.parse(FileAccess.get_file_as_string(path)) != OK or not reader.data is Dictionary:
		return
	var published: Dictionary = reader.data
	if not published.get("learned") is Dictionary:
		return
	var features := PackedStringArray(published.get("features", []))
	var weights := PackedFloat64Array(published["learned"].get("weights", []))
	if not features.is_empty() and features.size() == weights.size():
		_model = LearnedModel.new(LearnedModel.LINEAR, features, weights, 0.0)


## True when the weights were read.
func is_ready() -> bool:
	return _model != null


## How good a position is for one player: `counts` by feature name, each
## that player's minus the opponent's. Your `GakAdversarialGame.evaluate`
## returns this for a game that is not over.
func score(counts: Dictionary) -> float:
	return _model.predict_named(counts)
```

### What you implement {#implement}

In Python: your game's rules, a way to play it against itself, the counts
(the same function the game will compute), and a label per position --
who won. Fit, and publish the features with the weights so the order is
never assumed. In Godot: the same counts, by the same names, from your
`GakAdversarialGame.evaluate` for a game that is not over; a finished game
still returns its true outcome. The bias is published but not used: a
search only compares positions for one player, and a constant added to
every leaf changes no choice.

## Deeper {#deeper}

- Samuel's program, and what this fit does differently:
  [concepts/learned-evaluation.md](../concepts/learned-evaluation.md).
- The search that uses the score: [ai_adversarial](ai_adversarial.md).
- The regression itself: [concepts/learning.md](../concepts/learning.md).
