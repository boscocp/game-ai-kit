# Conformance vectors: the tactical game's feature conventions

<!-- doc-meta
half_life: structure
verified_on: 2026-10-26
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a convention is added, renamed or removed, or W6 or W7 changes meaning
teaches: none
-->

> Four numbers beside the weights, and two languages refusing the same ones.

The tactical game's `weights.json` carries a `feature_conventions` block
beside its models: `nearby_radius`, `reinforcement_distance_when_alone`,
`cheapest_ground` and `dearest_ground` (ADR 0007). `ModelFile` does not
read it -- a model file is anybody's -- so the tactical game checks it twice:
`gameaikit.tactical.report` before writing the file, `TacticalWeights`
after loading it.

`conventions.json` is a list of cases. Each carries a `conventions` block
(`null` for none) and claims either `loads`, or the code it is `refused`
with -- W6 for a block that is missing or a value that is not a positive
whole number, W7 for a terrain range the wrong way round -- and, for a W6 on
one value, the convention it names first (`about`). Both sides walk the
conventions in the order they are declared, so with two wrong the first is
named.

`python/tests/test_training.py` checks every case through the report, and
`godot/test/tactical/learning_test.gd` through `TacticalWeights`, with the
sound models of its own suite. Both plant a wrong claim of each kind and
watch it fail.

A whole number may be written `2.0`: Godot's JSON reader hands every number
over as a float and cannot tell the two apart, so both sides accept it.
