# Conformance vectors: teamwork

<!-- doc-meta
half_life: structure
verified_on: 2026-10-22
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: a technique's rule changes -- a condition's order, a weight's meaning, the commander's tie, a threshold's gap -- or Vector2 becomes double precision
teaches: none
-->

> Eight techniques, two languages, and the files that say they gave the
> same answers.

`ai_teamwork` (GDScript) and `gameaikit.teamwork` (Python) implement the
same eight things T51's and T66's bot match and T70's guards decide with. Each vector is one `.json`
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
either way, so no vector can tell the two apart. T68's hiding query was
asked the same in the Python twin: its SEEN condition removed fails a
vector.

`ActionChoice` and `ErrandChoice` were vectors here until T101 moved them,
unchanged, to `ai_utility`: they are in
[`spec/vectors/utility/`](../utility/README.md) with the mutations they
were asked.

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
| `positions` | a bot, its candidates' facts, whether it knows a threat, whether claims are on; asked to hide, `cover_from_all` in the weights (T68) | each candidate's status and score, and the index chosen |
| `influence` | a map's shape, sources with their strength, points asked | the value at each point |
| `commander` | squads and objectives | each objective's priority, the commander's assignment, and nearest-first without it |
| `confidence` | facts over time, a squad's members, phases | each confidence, the states with and without retreat, the waves |
| `passage` | a blocked bot's facts, and requests to a teammate with its prices | each way's cost in seconds (null: impossible) and the way taken; each request's cost to the teammate and whether it is granted |
| `search` | spots (worth, searched), each searcher's walk to each, whether claims are on; the walks to the last known position and a cap (T70) | the spot each searcher is given (-1: none); who goes to the last known position |
| `roles` | requests (role, score, can shoot), whether the arbiter is on, the most flankers (T70) | the role each request is granted |
| `aim` | a spread, a target's zones (multiplier, aim point, rectangles, exposure), rolls | each zone's own chance and worth aimed at, the zone aimed at, the chances from it, where each roll lands |

## The thirty-nine

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
| `close-and-steady-aims-at-the-head` | a small spread: the head, worth twice the torso, wins |
| `far-aims-at-the-torso` | a large spread: the torso and its spill beat the head |
| `behind-low-cover-the-legs-are-gone` | hidden legs and a half-shown torso move the choice up to the head |
| `equal-worth-goes-to-the-first` | of two zones tied, the first is aimed at |
| `nothing-exposed-aims-at-nothing` | every zone hidden: nothing is aimed at, every roll misses |
| `a-roll-on-a-boundary-misses` | a roll exactly on a chance's end goes past it, with a strict `<` |
| `a-steady-hand-has-no-spread` | a spread of 0 is taken as a millimetre: no division by zero, no chance over 1 |
| `wait-for-one-walking-off` | a body leaving: waiting beats the way round |
| `round-one-who-holds` | a body holding: waiting is never done |
| `ask-a-teammate-when-round-is-long` | asking a teammate beats a long way round; an enemy, or a teammate that refused, is not asked |
| `another-spot-when-nothing-else` | no way round, an enemy in the way: the next spot |
| `nobody-leaving-and-no-gap-is-no-wait` | gap and leaving both 0: waiting is impossible, not free |
| `nothing-possible-waits` | every way impossible: the bot waits |
| `equal-ways-go-to-the-first` | of two ways tied, the first in the order |
| `a-teammate-weighs-the-request` | the teammate's cost, a fight's high price, a saving that must be larger, and the two limits |
| `hiding-drops-what-anyone-sees` | asked to hide (T68): a spot a second threat sees is dropped, and the nearest hidden one wins |
| `claims-divide-the-search` | with claims, the nearest guard takes the best spot and the other the next; searched and worthless spots go to no one; the cap sends the nearest |
| `without-claims-they-search-the-same-spot` | the same with claims off: both go to the best spot; of equal walks the earlier goes |
| `no-spot-left-no-search` | every spot searched or worthless: no one is given one, and a cap of zero sends no one |
| `one-flanker-and-the-rest-shoot` | three ask to flank: the best is granted, the others shoot |
| `someone-always-shoots` | the only one who can shoot asks to flank: refused, it shoots |
| `without-the-arbiter-everyone-shoots` | the arbiter off: everyone who can shoot does |

JSON has no infinity: in the passage vectors an impossible way, a detour
or a spot that does not exist, and a saving with no bound are `null`, and
both sides read and write them so.

The aim vectors' numbers are powers of two wherever a tie or a boundary is
pinned: GDScript's `Rect2` is 32-bit, and with 0.1 and 1.1 an exact tie in
Python was not one in GDScript, which aimed at the second zone. And the
spread in `far-aims-at-the-torso` is under 0.55 m on purpose: above it a
shot aimed at an arm covers the body exactly as one aimed at the torso, a
true tie that the 32-bit side may break the other way.
