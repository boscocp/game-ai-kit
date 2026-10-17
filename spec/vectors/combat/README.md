# Conformance vectors: combat

<!-- doc-meta
half_life: structure
verified_on: 2026-10-17
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: spec/combat/rules.json changes a number, or a fight gains an input
teaches: none
-->

> The same rolls, the same fight -- in Python, which makes the dataset, and in
> GDScript, which plays it (T26, ADR 0008).

The two languages draw dice from different generators (Godot's PCG32,
Python's Mersenne Twister), so "the same seed" means nothing across them. A
fight is therefore written as a pure function of the rolls it is handed, and
each vector hands both sides the same list.

Each `.json` file is one fight:

- `fight`: the inputs -- both healths, `numeric_advantage`,
  `defender_terrain`, `reinforcement_distance`, `counter` (+1 the attacker's
  type is strong against the defender's, -1 the other way) and
  `defender_hits_back` (false for a building that cannot attack);
- `rolls`: the dice, in the order they are thrown -- attacker, then defender,
  round after round;
- `expect`: who won, what each side had left, and how many rolls were used.

The expected numbers were produced by `combat.fight` and then **checked by
hand, blow by blow**, against `spec/combat/rules.json` -- each `about` line
says what the fight is for. A vector the implementation wrote and nobody
checked would confirm a mistake both languages share.

Run: `make test-combat-vectors`.
