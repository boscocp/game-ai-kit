# T6 — `ai_learning`: inference, and the decision it drives

Size: M · Prereqs: T5 · Files: `godot/addons/ai_learning/`, `godot/game/`

## Goal

The addon loads `weights.json` and does nothing but infer. The AI attacks when
the predicted win probability clears a threshold and retreats below it, and
chooses between two targets by predicted turns-to-capture.

No training at game time — invariant 6. Python trains, GDScript infers. That is
the real industry pipeline and it is what keeps this addon small enough to read
in one sitting.

## Steps

1. Load the weights as a resource; fail loudly on a missing or malformed file
   rather than silently predicting from zeros.
2. Logistic inference and linear inference, each a few lines, each beside a
   comment relating them to the training code in Python.
3. Wire the decision into the game's AI turn.
4. A conformance vector proving the two implementations agree.

## Acceptance

```bash
make test-godot
make test-vectors
python3 scripts/check_readability.py
python3 scripts/check_no_training.py
```

The decision itself, asserted on two scripted games rather than watched:

```bash
./scripts/godot --headless --path godot -s res://test/ai_learning/decision_scenarios.gd
```

That script plays a game the AI should attack and a game it should retreat
from, and fails if either goes the other way.

## Manual check

Play against it. The retreat should feel like a decision rather than a bug, and
the debug overlay should show the probability that produced it.
