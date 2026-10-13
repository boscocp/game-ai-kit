# T25 — One team per technique: a league, scored twice

Size: L · Prereqs: T11, T12, T15 · Files: `godot/game/league/`, `godot/addons/ai_core/`, `python/gameaikit/league/`, `docs/concepts/`

## Goal

Put every way this kit has of deciding on the same board, one team each, and
let them play each other. The league is an exercise, a lesson and a
comparison at once. The question it answers is not only *which is best* but
*which plays most like a person*, because in a game those are often different
questions, and the second is frequently the one the designer is asking.

**Two scores, never one.** A team is measured on:

- **strength**: how often it wins, over a fixed set of seeds, with sides
  swapped so that neither the map nor the first move decides it;
- **human-likeness**: how its play compares with recorded human play on the
  measures below, and, in the manual check, whether people can tell it from a
  person.

The kit's own sources say why the second score matters. The BotPrize contest
built a Turing test for game bots on behaviour alone (Hingston, *A Turing Test
for Computer Game Bots*, IEEE TCIAIG 1(3), 2009,
<https://ro.ecu.edu.au/ecuworks/594>). AlphaStar was given "restrictions on
its action rate to make it comparable with human players", capped at "22 agent
actions per 5 seconds" (DeepMind, 2019,
<https://deepmind.google/discover/blog/alphastar-grandmaster-level-in-starcraft-ii-using-multi-agent-reinforcement-learning/>).
Strength without those limits was not the number anybody wanted.

**Never cheating, on either axis.** T12's rule holds here too: no team sees
more, earns more or acts sooner than a player could. A human-looking team is
one that is *limited* the way a person is, not one that is handed things.

## The teams

Each is a `DecisionPolicy`, so the league holds them all the same way:

| team | technique | from |
|---|---|---|
| Rules | priority rules, the shipped-RTS baseline | this task |
| Machine | a finite state machine | T15 |
| Tree | a behaviour tree | T15 |
| GOAP | goal-oriented action planning | T15 |
| HTN | hierarchical task network | T15 |
| Planner | heuristic STRIPS, as ADR 0010 sets out | T11 |
| Learned | the trained regressions | T6 |
| Cloned | behaviour cloning, once it exists | T18 |

A team joins when its task is done. A league with three teams is already a
lesson, so this task does not wait for all eight.

## Steps

1. **The league runner**: every team against every other, over a fixed seed
   set, both sides each, headless. A table of wins, losses and draws, and a
   rating computed from it, with the method named and its uncertainty shown.
   A rating with no error bar ranks noise.
2. **The cost of each decision**: milliseconds and, where the technique has
   one, worlds or nodes visited, beside the rating. Strength that costs a frame
   is not strength a game can ship.
3. **Human-likeness, measured.** Recorded human matches on this board are the
   reference. The recorder writes T5's row format, so that T18 can later train
   on the same files. For each team, compare:
   - actions per minute, and how it varies, not only its mean;
   - reaction time to a new threat, as a distribution;
   - predictability: the entropy of its next action given its last few, from
     an n-gram count -- the same idea T17 uses against a player, used here to
     measure a team;
   - mistakes: how often it takes a move a stronger setting of itself would not
     have.

   Each comparison says how far the team sits from the human recordings, and
   the task publishes the distances rather than collapsing them into one
   "humanness" number nobody can argue with.
4. **A human-likeness axis, separate from T12's strength axis.** These are
   limits that make a team play like a person and hand it nothing: a reaction
   delay drawn from the human distribution, a cap on actions per minute, a
   limit on how many units it attends to at once, and occasional
   inattention. Each is a named knob, documented where T12's knobs are.
   A level is then a point on two axes. *Easy and human* is as possible as
   *hard and inhuman*, and the menu offers both.
5. **The lesson, written down**: a `docs/concepts/` page reading the league's
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
exceeds the per-decision budget from T19, or T11's on a turn-based board. It
prints the table the docs page quotes, so every number there has a command
behind it.

```bash
PYTHONPATH=python python3 -m gameaikit.league.likeness --check
```

That command computes the human-likeness distances from the recorded matches
and the league's logs. It asserts that each human-likeness knob moves its
measure in the documented direction: raising the reaction delay must raise
the measured reaction time. A knob that changes nothing it claims to is the
defect this asserts against.

## Manual check

A blind test, after BotPrize. Record short clips of each team and of people
playing, mix them, and ask someone who did not build the teams to say which
are human. Report how often each team was taken for a person. A team chosen
for being human-like that nobody mistakes for a human has failed this task,
whatever its distances say.

Then play against the team the league ranks most human, at a strength you can
beat. It should lose in ways you can recognise from your own mistakes.
