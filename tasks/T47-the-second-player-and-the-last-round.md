# T47 — The side moving second, and a last round that decides

Size: M · Prereqs: T45 · Files: `godot/game/tactical/`, `spec/combat/rules.json`, `godot/test/`, `README.md`

## Goal

Rules against rules, the side moving first won 58 of 60 games in T26 and 20
of 20 with the points in T44. Every game in the genre has met this, and
they answer it with a small, stated counter for the second player
([docs/design/tactical-references.md](../docs/design/tactical-references.md),
§1.5): Wargroove's half-turn advantage, extra starting gold equal to the
income going second costs, a pre-recruited unit, or more health on the
second player's building; Advance Wars By Web's "predeployed infantry for
the second player is the tried-and-true way".

And a game that reaches round 40 is a draw, which T44's learned blue reached
in 17 of 20 games. Advance Wars By Web's day limit gives it to the side with
the most properties, and Polytopia's Perfection mode to the higher score
(§1.4). The reference's own caveat stands: on its own that only turns a
stalemate into a win, so it comes after T45 and T46, which give the game a
reason to end sooner.

## Steps

1. Sweep the counters as data, in the rules file: blue's starting funds
   (+1.5 rounded, +3), a blue shield placed at the start, more health on
   blue's workshop. Keep the smallest that lands red's mirror win rate in
   40-60%, and write the sweep down.
2. At the round limit the higher score wins: the workshop's health, then the
   rounds spent holding points, then the cost of what is left standing. A
   draw only on an equal score -- and a test plants an equal position and
   must get one.
3. The screen states both rules before the first move, and the README's
   tactical line follows.

## Acceptance

```bash
make test-godot
make tactical-win-rates GAMES=100 LIMITS="--at-least rr:red:40 --at-most rr:red:60 --at-most rr:draw:5"
```

## Manual check

Play red three times against the rules: the owner says whether blue's
counter is visible and whether a game that runs long still feels decided.

## What was done (2026-10-18, wave 51) -- done, manual check still the owner's

Taken out of table order on the owner's word: carry on with the design
study's proposals in their order.

- **Step 1, the counter, swept as data.** In `TacticalRules`, not in
  `spec/combat/rules.json` as the file list suggested: that file is the
  combat rules the Python dataset shares byte for byte (ADR 0007), and the
  dataset has no second player. Rules against rules, 100 games each, the
  same seeds, with T45's and T46's controllers:

  | counter for blue | red | blue | draws |
  |---|---|---|---|
  | none | 70 | 30 | 0 |
  | +2 starting funds (+1.5 rounded) | 70 | 30 | 0 |
  | +3 starting funds | 70 | 30 | 0 |
  | **a shield diagonal to its workshop** | **59** | **41** | **0** |
  | +2 workshop health (Wargroove's 10%) | 65 | 35 | 0 |

  The funds changed nothing, game for game: since T45 the rules build every
  turn and every piece but the forge is affordable from blue's first turn,
  so money does not bind them. The shield -- Advance Wars By Web's
  "predeployed infantry for the second player" -- is the only one in
  40-60%, so it is the rule (`SECOND_PLAYER_SHIELD`, at (11, 0)). T26 and
  T44 measured the first mover at 58 of 60 and 20 of 20; T45's spending had
  already brought it to 70 of 100 before any counter.
- **Step 2, the last round decides.** At the round limit the higher score
  wins: workshop health, then point-turns held -- each point, each turn it
  was held; the task said rounds, and point-turns keep a second point worth
  holding (`ControlPoints` counts
  them in a new `BoardState.tally`, which `ai_core` carries and never
  reads), then the cost of what is left standing. A draw only on an equal
  score; `tactical_last_round_test.gd` plants the opening mirrored and must
  get one, and holds each step of the comparison.
- **Step 3.** The header states both rules before the first move, the end
  of a game says which score decided it, and the README follows.

**Acceptance** (`make tactical-win-rates GAMES=100 LIMITS="--at-least rr:red:40
--at-most rr:red:60 --at-most rr:draw:5"`): rules' mirror red 59, blue 41,
draws 0 -- exit 0. The script now also counts the games settled at the round
limit, as the reference's caveat asked (§4, item 2: "report decided before
round 40 separately"):

| pairing, 100 games | red | blue | draws | settled at the round limit |
|---|---|---|---|---|
| rules v rules | 59 | 41 | 0 | 23 |
| rules v learned | 0 | 100 | 0 | 61 |
| learned v rules | 100 | 0 | 0 | 61 |
| rules v planner | 33 | 67 | 0 | 13 |
| planner v rules | 28 | 72 | 0 | 58 |

Read the learned side's 100 of 100 with that last column: 39 workshops
destroyed and 61 games won on score -- it holds the points and keeps its
pieces, and the score rewards both. That is the caveat the reference gave,
and why it asked for this rule to come after T45 and T46 rather than alone.

**Since wave 52 -- wip again.** T48's fords opened a rush lane beside each
workshop, and the rules' mirror went from 59-41 to 17-83 with the shield
(100-0 without). No ford cost or place swept, and no other counter tried,
lands it in 40-60; the sweep is in T48's record and the choice is the
owner's. The last-round rule is unaffected: still no draws.
