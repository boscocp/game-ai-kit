# 0007 — Numbers two languages share live in one file

Status: accepted · 2026-10-13 (decided in T5 and T6, written down in T7)

## Context

Python trains and GDScript infers (invariant 6). Between them sits more than
the weights. Two of the four combat features cannot be computed from a board
without a rule of the simulator: how near counts as *near*, and what a unit
with no living friends reports as the distance to its nearest one. The second
is the **training** board's width -- a sentinel, not a distance -- and a game
helpfully reporting its own, smaller width would be telling the model "far"
where the data said "nobody is coming".

The first version kept those numbers as constants on both sides. A number two
languages must agree on, kept in two files, is a number that will one day
differ, and nothing would say so: the model would simply be shown a feature
that is not the one it was fitted to.

## Decision

`weights.json` publishes, beside the weights and biases, every convention the
game needs to build a feature row: `nearby_radius`,
`reinforcement_distance_when_alone`, and the range of terrain the data covered
(`cheapest_ground`, `dearest_ground`). The game refuses a file missing any
of them, and reads them from the file rather than keeping a copy. (Amended
in wave 99, T106: the refusal was `ModelFile`'s, which made the addon
unusable by any other game; it is now the tactical game's own
`TacticalWeights`, on top of a `ModelFile` that checks only what every model
file has. The decision is unchanged.)

Weights are published rounded to six decimals, so that both languages compute
with the same numbers rather than with two renderings of one double. The
conformance vectors in `spec/vectors/learning/` hold the two halves to the
same rows and to the same arithmetic.

## Alternatives considered

- **Document the conventions.** Rejected: documentation is the second file
  that will differ.
- **Compute the sentinel from the game's own board.** Rejected: on the
  game's 12-wide board a unit alone would report 12, which the model reads as
  a friend twelve cells off rather than as nobody coming. (The bug this
  feature actually had was a different one, and it is the reason a value
  shared is not the same as a value used correctly: `_nearest_friend` seeded
  its minimum with the sentinel, so a friend seventeen away and no friend at
  all became the same number.)
- **Publish full-precision weights.** Rejected: the vectors compare to `1e-9`,
  and printing a double in one language and parsing it in another is a
  rounding question nobody needs to have.

## Consequences

- Retraining can change a convention and the game follows without a code
  change; a game that cannot honour one (a board with walls, terrain outside
  the range) can see it and say so.
- `make lint-no-training` fails if the committed `weights.json` is not what
  the pipeline produces, so the file cannot be edited by hand to "fix" a
  number.
- A conformance vector only tests the range its board can reach. The sentinel
  bug passed every vector until one was built on a board twenty wide.
