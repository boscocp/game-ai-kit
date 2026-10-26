# T100 — The bot match reads how well you play, during one match

Size: M · Prereqs: T99, T66 · Files: `godot/game3d/botmatch/`, `godot/test/botmatch/`, `python/gameaikit/botmatch/`, `modules/botmatch.json`, `spec/vectors/`, `python/tests/`, `scripts/check_no_training.py`, `docs/godot/botmatch.md`, `docs/concepts/`, `Makefile`

## Goal

The owner, 2026-10-26, answering T73's question 4 -- player modelling for
difficulty is learning at game time; leave it out, allow only a model
fitted in Python and shipped fixed, or extend ADR 0016? -- **option 3**:
extend ADR 0016 to it on the same three conditions. ADR 0016's amendment
of 2026-10-26 records it: counts only; empty at the start of every match;
rebuildable from that match's log.

It teaches estimating skill from play (Y&T ch. 10-12) and adjusting the
game to it. Hamlet, a dynamic difficulty system built on Valve's Half-Life
engine, models the damage a player takes as a distribution and adjusts
"the supply and demand of game inventory" to it [Hunicke & Chapman]; Ocio Barriales' chapter
balances difficulty through the enemies' accuracy [GAP3 ch. 33].

## Decisions written down first (the owner confirms in review)

- **Home: the bot match**, when the person takes over a bot (T51's T key,
  the owner's choice for that game). Its teams already have an accuracy
  knob, `aim_error` (`match_aim.gd` spreads each shot by the distance
  times its tangent), so the model can act through a number that exists.
  The fighting game is the named alternative; it already has two learners.
- **The model: counts.** The person's shots and hits, kills and deaths,
  damage dealt and taken, during this match. The estimate is a ratio of
  counts with a fixed prior (hits + 1 over shots + 2, and the like) -- a
  Beta mean, not a step. No Elo, no TrueSkill: each moves a value a step
  towards a result, which the amendment refuses.
- **What it changes**: the opposing team's `aim_error`, from a fixed table
  in `godot/game3d/botmatch/rules.json` keyed by the estimate, re-read
  every fixed interval; never the person's own aim, never the bots'
  knowledge (T67's bot still reads only its percepts). Bounded: never
  easier than the easy level nor harder than the hard one.
- **Condition 3 needs a log the bot match does not have yet.** This task
  writes one: the events the model counts, in order, with the match's
  seed -- kept only when the match is opened with `-- --record`, as ADR
  0017 requires. A test replays a log through a fresh model twice and
  compares the counts and the knob's history.
- **The gate**: **N14** in `check_no_training.py`, as the amendment
  specifies. Its targets, found as N9's are: the player model's file in
  `godot/game3d/botmatch/` and any GDScript naming its class. In them, the
  same refusals as N13, and no line that loads its state at start.
  Planted: a model saved to `user://`, a model loaded at start, an
  Elo-style update, an incremental mean. **The event log is not an N14
  finding**: it holds events, not counts, is written only under
  `-- --record`, and its writer is neither the model nor a script that
  holds one -- which is why it sits in its own file.

## Steps

1. Read the amendment, `match_aim.gd`, `match_stats.gd`, and how the
   person takes over a bot.
2. Python first: the model and the knob table in
   `python/gameaikit/botmatch/`, owned by the `botmatch` manifest -- the
   model is the bot match's, not `ai_teamwork`'s, whose twin
   `python/gameaikit/teamwork/` is; vectors -- an event list in, the estimate and the knob after
   each interval out.
3. `PlayerModel` in `godot/game3d/botmatch/`, held to the vectors; the
   event log and its replay test.
4. N14 and its planted cases.
5. Measured, in `docs/godot/botmatch.md`: with T66's scripted stand-ins at
   three skills playing the taken-over bot, the knob each settles on and
   the score difference with the model on and off; whether it oscillates.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_player_model*.py"
make test-player-model-vectors
make test-godot-some SUITES="test/botmatch"
python3 scripts/check_no_training.py
python3 scripts/check_no_training.py --self-test
make lint-modules
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Take over a bot (T) and play badly on purpose for two minutes, then well:
does the other team's aim ease and then tighten, and is it ever obvious
in a way that feels unfair? Start a new match: does it start from the
middle again?

How invariant 13 is met: on the HUD (with V), the counts, the estimate
with its prior, and the opposing team's current `aim_error` against the
table row it came from, with a mark each time it changes -- what the game
believes about you and what it did about it.

References, opened on 2026-10-26: Hunicke, R., Chapman, V. "AI for
Dynamic Difficulty Adjustment in Games", abstract and introduction
<https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf>; Ocio
Barriales, GAP3 ch. 33, as cited by T73; Y&T contents, as cited by T73.
