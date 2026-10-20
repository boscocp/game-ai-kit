# Conformance vectors: learning

<!-- doc-meta
half_life: structure
verified_on: 2026-10-12
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a feature is renamed, or the published weights file changes shape
teaches: none
-->

> Python fitted it, GDScript runs it, and this is the file that says they got
> the same answer.

Invariant 6 splits the work in two: Python trains and emits weights, GDScript
only infers. That split is worth exactly as much as the agreement between the
two halves, and nothing in either language can check it alone.

Each vector is one `.json` file, and both languages check the same two claims
about every case in it:

- **the board produces this row** — `make test-vectors` on the GDScript side
  through `BoardFeatures`, `make test-python` on the Python side through
  `gameaikit.dataset.simulate`;
- **the model turns this row into this number** — `LearnedModel.predict_named`
  against `gameaikit.training.descent`.

The two claims are checked separately and against the *file*, never against
each other. A run that fed the produced row into the model would still pass
with both halves wrong in the same direction, and a failure would not say
which half moved.

## Where the numbers came from

Not from either implementation. The boards are small enough to count on, and
every feature row in these files was written by hand off the board beside it.
The predictions were then filled in by a throwaway script holding a dot
product and `math.exp` and importing nothing from this repository — so a
vector cannot confirm a mistake that the two sides happen to share.

## The shape

```json
{
  "name": "a short label for a reader; the file name is what failures quote",
  "why": "what this vector is for -- the sentence a reader needs",
  "feature_conventions": { "nearby_radius": 2, "...": 0 },
  "models": { "combat": { "kind": "logistic", "features": [], "weights": [], "bias": 0.0 } },
  "board": {
    "width": 5, "height": 4,
    "costs": [[1, 1, 1, 1, 1]],
    "units": [{"id": 1, "faction": 0, "x": 1, "y": 2, "health": 14}]
  },
  "cases": [
    {"kind": "combat", "attacker": 1, "defender": 2, "why": "...",
     "features": {"health_difference": 5}, "prediction": 0.939891263816}
  ]
}
```

- `kind` is `row`, `combat` or `capture`. A `row` case hands its features
  straight to the model it names and needs no board; the other two are read
  off the board and name the units or the side and node they are about.
- **Each vector carries its own `models` block**, rather than reading the
  published `weights.json`. Retraining must not change what a conformance
  vector claims: what these pin is the arithmetic, not the model.
- `feature_conventions` is required and must match what
  `gameaikit.training.report` publishes. A vector carrying a stale radius
  would hold both languages to a feature the data was never gathered with,
  and agree with itself perfectly while doing so.

## What they deliberately do not pin

- **The clamp.** `BoardFeatures` clamps terrain into the range the data
  covered and reads a wall as the dearest ground, because the simulator never
  generated either. That rule exists only on the GDScript side -- there is no
  Python half to disagree with -- so it is held by unit tests in
  `godot/test/ai_learning/learning_test.gd`, not here. Every board in these vectors stays
  inside the trained range, which is what makes the two sides comparable at
  all.
- **`enemy_units` on a board with three sides** — and `a-fight-in-cover.json`
  does put a faction-2 unit on a board, so this needs saying rather than
  assuming: the *combat* features are defined for any number of sides, and
  the *capture* features are defined for two. Python counts
  `living(1 - faction)` — *the other side*, which has no meaning with three of
  them — and GDScript counts everyone who is not mine. On two factions they
  are the same number, and every board here has two. A vector on a
  three-faction board could not be written without encoding a disagreement,
  because neither spelling is right there: this is a limit of the feature the
  model was fitted on, not of the board, and it is named in `capture_row`'s
  own doc comment rather than quietly left for somebody to find. Review found
  it by changing each side to the other's rule and watching both suites stay
  green.

- **The tie-break** when two of a faction's units are the same distance from a
  node. Both sides happen to take the first in board order; no vector depends
  on it, because a correct implementation that chose the other would be failed
  for something that is not about correctness.
- **Anything about the decision.** Which probability means attack, and what a
  unit then does, is the policy's business and is asserted by
  `test/ai_learning/decision_scenarios.gd`. A vector here is about numbers, not about
  nerve.

## Tolerance

`1e-9`, scaled by the size of the expected answer. Two doubles running the
same formula agree to about `1e-16` relative, so this catches a different
formula and never a different maths library. One consequence is honest and
worth knowing: the deliberately extreme row, whose answer saturates to zero,
is pinned only to within `1e-9` of zero.

What that row is really there for is **asymmetric, and this file used to claim
otherwise**. On the Python side `1 / (1 + exp(-x))` raises `OverflowError`
around -710, which kills a training run because one row was unusual. On the
GDScript side it does not: measured on the pinned engine, `exp` saturates to
`inf` and `1 / (1 + inf)` is `0.0`, which is the correct answer at every logit
— replacing the two-branch sigmoid with the naive one leaves every vector and
every test green. The branches are kept there so the two files read alike, not
because the engine needs them, and the row pins that neither side crashes.
