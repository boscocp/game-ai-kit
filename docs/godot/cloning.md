# Wiring a cloned player into a game

<!-- doc-meta
half_life: practice
verified_on: 2026-10-15
tier: 2
source: https://docs.godotengine.org/en/stable/classes/class_json.html
invalidated_if: the clone_weights.json layout, CaseTable's key, or the refusal codes change
teaches: behaviour-cloning
-->

> How to load a published player, ask it what it would do, and refuse a
> bad file. Why the player is cloned at all, and what it bought, is
> [the concept page](../concepts/behaviour-cloning.md).

## What to copy

`addons/ai_learning/`, and a published player: this kit's is the fighting
game's, `godot/game/fighting/clone_weights.json`. Three classes read it, and none of them knows what game it is in:

- `ClonedPlayer` -- the file, loaded and checked, or refused with a code;
- `SoftmaxModel` -- the model: a probability for each answer;
- `CaseTable` -- the ghost: what the player did in each situation met.

A situation is a `Dictionary` of feature to word. Which features, and how a
game reads them off its own state, is the game's business -- the fighting
game's is `FightSituation`; the file names the features it was cut with.

## Load it, and refuse a bad file

```gdscript
var player: ClonedPlayer = ClonedPlayer.load_from("res://game/fighting/clone_weights.json")
if not player.is_loaded():
	push_error(player.error)  # "C1 no cloned player at ...", C2 to C7
```

Never half built: a refused file has no model and no table. The codes:
C1 no file, C2 not JSON, C3 a field missing, C4 a list that is not words,
C5 sizes that do not agree, C6 a number that is not one, C7 a case whose key
or counts are wrong. Check the file's `cases.features` against your own
features too -- the addon cannot know them, and a file cut with others loads
and then matches nothing. `FightCloneOpponent` refuses it on screen.

## Ask it

```gdscript
var situation: Dictionary = {"last": "step in", "other": "crouch", "me": "free",
		"distance": "close", "health": "even", "corner": "no"}
player.model.probabilities(situation)  # step in 0.33, mid 0.19, step out 0.16, ...
player.cases.exact(situation)          # {} -- the owner never met exactly this
player.cases.nearest(situation)        # {"distance": 1, "keys": [3 cases], "counts": {"step in": 3, "high": 1, "mid": 1}}
```

What it printed on 2026-10-15, on the owner's published player: never met
this exact situation, so the exact ghost falls back to all its play; three
situations one word away, pooled, say step in.

A word the model never saw adds nothing to any answer, and is not an error.
`exact` hands back a copy: editing the answer does not edit the table, and
nothing in the game may write into `cases` (N12 in `check_no_training.py`).
