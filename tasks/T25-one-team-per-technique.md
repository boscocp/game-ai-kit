# T25 — One team per technique: a league, scored twice

Size: L · Prereqs: T11, T12, T15 · Files: `godot/game/league/`, `godot/addons/ai_core/`, `python/gameaikit/league/`, `docs/concepts/`

## Goal

Put every way this kit has of deciding on the same board, one team each, and
let them play each other. The board is the **turn-based** tactical scenario
from T10, which T11's planner already plays. It is cheaper, deterministic, and
ready long before an RTS exists. T20 brings the same league to real time,
where the measures that need a clock become possible. The league is an exercise, a lesson and a
comparison at once. The question it answers is not only *which is best* but
*which plays most like a person*, because in a game those are often different
questions, and the second is frequently the one the designer is asking.

**Two scores, never one.** A team is measured on:

- **strength**: how often it wins, over a fixed set of seeds, with sides
  swapped so that neither the map nor the first move decides it;
- **human-likeness**: how its play compares with recorded human play on the
  measures below, and, in the manual check, whether people can tell it from a
  person.

Two well-known efforts treat the second score as the one that matters. The
BotPrize contest built a Turing test for game bots, whose judges played
alongside bots and humans and had to say which was which (Hingston, *A Turing
Test for Computer Game Bots*, IEEE TCIAIG 1(3), 2009,
<https://ro.ecu.edu.au/ecuworks/594>). AlphaStar was given "restrictions on
its action rate to make it comparable with human players", capped at "22 agent
actions per 5 seconds" (DeepMind, 2019,
<https://deepmind.google/discover/blog/alphastar-grandmaster-level-in-starcraft-ii-using-multi-agent-reinforcement-learning/>).

**Never cheating, on either axis.** T12's rule holds here too: no team sees
more, earns more or acts sooner than a player could. A human-looking team is
one that is *limited* the way a person is, not one that is handed things.

## The teams

Each is a `DecisionPolicy`, so the league holds them all the same way. A team
must decide everything a side decides -- moves, fights *and* production -- or
say which part it delegates:

| team | technique | from |
|---|---|---|
| Rules | priority rules, the shipped-RTS baseline | this task |
| Machine | a finite state machine | T15 |
| Tree | a behaviour tree | T15 |
| GOAP | goal-oriented action planning | T15 |
| HTN | hierarchical task network | T15 |
| Planner | heuristic STRIPS, as ADR 0010 sets out | T11 |
| Learned | the trained regressions, for its units; production delegated to Rules, and labelled so | T6 |
| Cloned | behaviour cloning trained on this board's recordings (step 3), with T18's method once T18 exists | T18 |

A team joins when its task is done. A league with three teams is already a
lesson, so this task does not wait for all eight.

## Steps

1. **The league runner**: every team against every other, over a fixed seed
   set, both sides each, headless. A table of wins, losses and draws, and a
   rating computed from it, with the method named and its uncertainty shown.
   A rating with no error bar ranks noise.
2. **The cost of each decision**: milliseconds and, where the technique has
   one, worlds or nodes visited, beside the rating, held to T11's per-call
   budget on this board. Strength that costs too much to compute is not
   strength a game can ship.
3. **A recorder and the human reference.** The recorder writes one row per
   decision: the board as the side to move saw it, and the move it made. That
   is a new format, not T5's, whose rows are one per combat. T18 clones a
   fighting game from its own recordings; what the two share is the *shape* of
   a row -- what was seen, what was done -- not the data, and the Cloned team
   is trained on these files. The owner plays and records at least twenty matches
   against the Rules team, committed under `spec/recordings/`. Without them
   step 4 has no reference, and the task says so rather than inventing one.
4. **Human-likeness, measured, on the measures a turn-based board has.**
   For each team, against the recordings:
   - predictability: the entropy of its next move given its last few, from an
     n-gram count -- the idea T17 uses against a player, used here to measure
     a team;
   - attention: how many different units it moves per turn, and how often it
     leaves a threatened unit unanswered;
   - mistakes: how often it takes a move a stronger setting of itself would not
     have.

   Each comparison says how far the team sits from the recordings, and the
   task publishes the distances rather than collapsing them into one
   "humanness" number nobody can argue with. Actions per minute and reaction
   time need a clock, and are measured in T20.
5. **A human-likeness axis, separate from T12's strength axis.** These are
   limits that make a team play like a person and hand it nothing: a cap on
   how many units it attends to in a turn, occasional inattention to a unit,
   and mistakes of the kinds people make, drawn from the recordings. That is
   not T12's evaluation noise. T12's noise is uniform and exists to lower
   strength; this one is shaped like the errors in the recordings and exists
   to look human. Both cost strength, which is why the league re-asserts the
   ordering. T20 adds the clock's
   knobs, a reaction delay and a cap on actions per minute. Each is a named
   knob, documented where T12's knobs are. A level is then a point on two
   axes, and because these knobs cost strength as well, the league re-asserts
   T12's ordering with them on. *Easy and human* is as possible as *hard and
   inhuman*, and the menu offers both.
6. **A cost and efficiency meter on screen, per team, during the match.** The
   league table says who spent what after the fact. The meter shows it while
   the fight happens, which is invariant 13 applied to cost: watch the planner
   spike when it replans, and watch the rules team spend almost nothing. For
   each team, beside its units:
   - **cost**: milliseconds of this decision, a rolling average and the 95th
     percentile, drawn as a bar against the team's budget -- T11's per call
     here, T19's share of a frame once T20 brings the league to real time --
     turning red past it;
   - **work**: worlds, nodes or rules evaluated this decision, where the
     technique has such a count, and how often it replanned in the last thirty
     decisions;
   - **efficiency**: what the cost bought -- the team's material and income
     lead per millisecond spent, over a rolling window -- so that a strong
     team that is also expensive can be told apart from a cheap one that is
     nearly as strong;
   - a small history graph of the last thirty decisions, so a spike can be
     found after it has passed.

   One rule keeps the meter honest. It reads the **same counters** the league
   runner records, so the screen and the table cannot disagree. Measuring
   costs something too: the meter's own time is measured, and it is shown
   apart from the teams' costs, so it is never charged to any of them. A
   toggle hides it for the human-likeness clips in the manual check.
7. **The lesson, written down**: a `docs/concepts/` page reading the league's
   table. Which technique is strongest, which most human, what each costs,
   and when you would choose the one that is neither.

## Acceptance

```bash
make test-godot
make test-python
./scripts/godot --headless --path godot -s res://test/league_runner.gd
```

`league_runner.gd` plays the league over its fixed seeds and asserts what can
be asserted. Every match terminates. The same seeds give the same table twice.
Every team is credited the same number of matches on each side. No team
exceeds T11's per-call budget. T12's ordering holds with the human-likeness
knobs on. It
prints the table the docs page quotes, so every number there has a command
behind it.

```bash
./scripts/godot --headless --path godot -s res://test/league_meter.gd
```

That script plays one seeded match with the meter attached. It asserts that
every team's meter is populated after its first decision, and that the
meter's totals equal the counters the league runner logged for that match. It
also asserts that the meter's own cost is recorded apart from every team's,
so that showing the numbers never changes them. It cannot assert the bars are
legible; that is the manual check.

```bash
PYTHONPATH=python python3 -m gameaikit.league.likeness --check
```

That command computes the human-likeness distances from the recordings in
`spec/recordings/` and the league's logs, and exits 2 with a sentence if there
are none. It asserts that each human-likeness knob moves its measure in the
documented direction: lowering the attention cap must lower the units moved
per turn. A knob that changes nothing it claims to is the
defect this asserts against.

## Manual check

A blind test, in the spirit of BotPrize, whose judges played against hidden
opponents. Seat someone who did not build the teams for a set of matches
against opponents that are sometimes a person at the next seat, out of sight,
sometimes a team, and ask after each which it was. Report how often each
team was taken for a person. A team chosen
for being human-like that nobody mistakes for a human has failed this task,
whatever its distances say.

Watch one match between the cheapest and the most expensive team with the
meter on. You should be able to point at the moment the expensive team
replanned and say what made it, and to say from the efficiency line alone
whether its extra cost bought anything in that fight.

Then play against the team the league ranks most human, at a strength you can
beat. It should lose in ways you can recognise from your own mistakes.
