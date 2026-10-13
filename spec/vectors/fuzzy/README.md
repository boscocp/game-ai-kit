# Conformance vectors: fuzzy

<!-- doc-meta
half_life: structure
verified_on: 2026-10-13
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the controller shape changes, or the centroid stops sampling at evenly spaced points
teaches: none
-->

> One controller, two languages, and the file that says they reached the same
> number.

`ai_fuzzy` (GDScript) and `gameaikit.fuzzy` (Python) implement the same three
steps: membership, a rule base, and the centroid. Each vector is one `.json`
file, and both sides check every claim in it against the file and never
against each other: `make test-vectors` on the GDScript side, and
`make test-python` on the Python side.

## The case T13 asks for

A rule base with overlapping rules has to produce a value **strictly between**
the outputs of its two rules. That one number is the whole of fuzzy logic, and
it is exactly what a broken defuzzifier gets wrong. A case carrying
`"between": [a, b]` claims this against two earlier cases, and both runners
check that the inequality is strict. There are three such claims:
`two-rules-overlap.json` has `both` and `leaning-calm`, and `the-guard.json`
has `between-near-and-medium`.

A defuzzifier that keeps only the strongest rule's term was planted on the
Python side. It fails five cases here and the slope test in `test_fuzzy.py`.

## Where the numbers came from

They did not come from either implementation. A throwaway script that
imported nothing from this repository computed them in exact fractions
(`fractions.Fraction`) and rounded only at the end. The two small vectors can
be checked by hand. In `two-rules-overlap.json` the output is sampled at
0, 10, ... 100:

- **only-calm** (noise 1): calm is fully true. At 0, 10, 20, 30, 40 and 50 its
  heights are 1, 1, 1, 2/3, 1/3 and 0. The weighted sum is
  0 + 10 + 20 + 20 + 40/3 = 190/3, the total height is 4, so the answer is
  **95/6 ≈ 15.833**.
- **only-alarmed** (noise 9) is the mirror image: **505/6 ≈ 84.167**.
- **both** (noise 5): quiet and loud are each 1/4. Both terms are cut at 1/4,
  which leaves height 1/4 at every sample except 50. The answer is
  (0 + 10 + … + 40 + 60 + … + 100) / 10 = **50**, strictly between the two.

## The shape

```json
{
  "name": "a label for a reader; failures quote the file name",
  "why": "what this vector is for",
  "controller": {
    "inputs":  [{"name": "noise", "minimum": 0, "maximum": 10,
                 "sets": {"quiet": [0, 0, 2, 6], "loud": [4, 8, 10]}}],
    "outputs": [{"name": "alertness", "minimum": 0, "maximum": 100, "samples": 11,
                 "sets": {"calm": [0, 0, 20, 50]}}],
    "rules":   [{"if": [["noise", "quiet"]], "connective": "and",
                 "then": ["alertness", "calm"]}]
  },
  "cases": [
    {"kind": "membership", "variable": "noise", "set": "quiet", "value": 4, "degree": 0.5},
    {"kind": "fuzzify", "variable": "noise", "value": 5, "degrees": {"quiet": 0.25, "loud": 0.25}},
    {"kind": "evaluate", "name": "both", "inputs": {"noise": 5},
     "activations": {"alertness": {"calm": 0.25}}, "outputs": {"alertness": 50.0},
     "between": ["only-calm", "only-alarmed"]}
  ]
}
```

- A set is **three points (a triangle) or four (a trapezoid)**, as in the
  library this one was rewritten from (ADR 0011).
- `membership` asks one set about a raw value, **without clamping**.
  `fuzzify` asks a whole input, which clamps into its range first. One case
  in `the-shapes.json` asks both about the same value, 10.5, and they answer
  differently on purpose.
- `evaluate` pins the **activations** (each output term's strength) apart
  from the **outputs** (the centroid). When a run fails, this shows whether
  inference or defuzzification moved.
- An output of `null` means no rule fired, and both sides answer NaN. A rule
  base with a hole in it is a defect, and a number in that place would hide
  it.
- `connective` defaults to `and`. A rule with one condition does not need it.
- `samples` belongs to the output. It decides where the centroid measures,
  and if each language kept its own copy, the two copies could drift apart
  (ADR 0007).

`the-guard.fcl` sits beside `the-guard.json` and describes the same
controller in the text format. `make test-python` reads both and checks that
they are equal, the same way the planning vectors keep a PDDL file beside
their JSON.

## What they deliberately do not pin

- **Refusals.** Each side refuses a broken controller with the same code
  (`F1`–`F8`), but GDScript reports it from `problem()` and Python raises.
  Unit tests hold the refusals on each side, in `godot/test/fuzzy_test.gd`
  and `python/tests/test_fuzzy.py`.
- **The text reader.** It exists only in Python, so there is nothing to
  disagree with. Its refusals are in `python/tests/test_fcl_reader.py`.

## Tolerance

`1e-9`, scaled by the size of the expected answer, which is the same as every
other family here. Both sides compute the sample points with the same
expression, `minimum + span * index / (samples - 1)`, in the same order, so
the margin catches a different formula and never a different maths library.
