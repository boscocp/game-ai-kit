# Conformance vectors: teamwork

<!-- doc-meta
half_life: structure
verified_on: 2026-10-21
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a technique's rule changes -- a condition's order, a weight's meaning, the commander's tie, a threshold's gap -- or Vector2 becomes double precision
teaches: none
-->

> Four techniques, two languages, and the files that say they gave the
> same answers.

`ai_teamwork` (GDScript) and `gameaikit.teamwork` (Python) implement the
same four things T51's bot match decides with. Each vector is one `.json`
file: a query and the answer it must get. Both sides answer it and check
every value against the file, never against each other: `make test-vectors`
on the GDScript side, `make test-python` on the Python side.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the rules in plain dictionaries that imports nothing from this
repository. Independent of the code, not of its author: it makes the same
choices -- the first of equal scores wins, the cheapest squad first --
so it catches a slip in transcribing them, not a choice that is wrong.

Every comparison in the four techniques was flipped once (`<` for `<=`
and back), in both languages, and each flip fails a vector -- but one: the
influence radius, where a cell exactly at `radius` takes `strength x 0`
either way, so no vector can tell the two apart.

    python3 spec/vectors/teamwork/derive.py spec/vectors/teamwork

## The tolerance

1e-4 on every number. The GDScript side holds positions in 32-bit
`Vector2`s ([`docs/godot/vector2-is-single-precision.md`](../../../docs/godot/vector2-is-single-precision.md)),
and the scores, influences and confidences in 64-bit floats. A status, an
id or a state must be equal.

What the vectors cannot catch, said so: both sides break a tie with a
strict `<`, and the vectors pin only exact ties. A near tie -- two costs
that differ only in the last bits of a float -- may fall the other way in
GDScript's 32-bit `Vector2` than in Python's 64-bit tuples. The game never
compares the two languages' answers, so it costs nothing there; a twin
that must agree bit for bit would need rounded costs.

## The kinds

| kind | query | answer |
|---|---|---|
| `positions` | a bot, its candidates' facts, whether it knows a threat, whether claims are on | each candidate's status and score, and the index chosen |
| `influence` | a map's shape, sources with their strength, points asked | the value at each point |
| `commander` | squads and objectives | each objective's priority, the commander's assignment, and nearest-first without it |
| `confidence` | facts over time, a squad's members, phases | each confidence, the states with and without retreat, the waves |

## The seventeen

| file | what it pins |
|---|---|
| `claims-spread-the-squad` | the best spot is claimed by a teammate, so the bot takes the next best |
| `without-claims-they-bunch` | the same query with claims off: the bot takes the claimed spot |
| `every-condition-once` | one candidate per condition, in their order; a bot's own claim does not stop it |
| `open-fire-loses-to-partial-cover` | line of fire from the open is 20, from partial cover 40 |
| `no-threat-nearest-wins` | nobody known: nothing is exposed, and the nearest wins |
| `friends-add-enemies-subtract` | sources add, an enemy subtracts, off the map is zero |
| `an-offset-corner` | a map whose corner is not the origin, a source clipped by the edge |
| `take-before-hold` | points to take are worth more than ours; rooms fill cheapest first |
| `attack-where-they-are-not` | a point to take is worth less where the enemy is strong |
| `defend-a-point-under-pressure` | our point with the enemy on it outweighs one to take |
| `more-squads-than-room` | squads beyond every room go where the priority is highest |
| `two-squads-tie-for-one-room` | of two squads tied for the one room, the first listed gets it |
| `equal-costs-go-to-the-first` | one squad tied between two points goes to the first |
| `equal-scores-go-to-the-first` | of two candidates tied, the first is chosen |
| `retreat-recover-attack` | every transition, the gaps between them, and the toggle |
| `on-every-threshold` | a value exactly on each threshold, so each comparison's side is pinned |
| `a-lone-survivor` | one member moves in both phases |
