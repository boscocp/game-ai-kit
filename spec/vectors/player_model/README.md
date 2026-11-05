# Conformance vectors: the bot match's player model

<!-- doc-meta
half_life: structure
verified_on: 2026-11-05
tier: 1
source: https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf
invalidated_if: the difficulty table in godot/game3d/botmatch/rules.json changes (its band included), or when in a step a reading or a seat is taken
teaches: none
-->

> The person's events in, every interval's reading out: the files that say
> Python's player model and Godot's are one model.

T100 lets the bot match read how well the person plays while they play,
under ADR 0016's amendment: counts only, empty at the start of every match,
rebuilt from that match's events. T123 reads the team's share instead of
the bot's, holds the row while the share is inside a band, and empties the
counts when the person takes a bot on the other team. The model is written twice,
`gameaikit.botmatch.player_model` and `godot/game3d/botmatch/player_model.gd`,
and held here, through the table both read from `rules.json`.

Each file is one match's worth of the person's events from an empty model:

- `last_step`, the last step the match ran (a step is `rules.json`'s
  `step`, 0.05 s), and `events`, each with the `step` it happened in, its
  `kind` and, for a hit or a hurt, its `points`. The person's bot's kinds
  are `shot`, `hit`, `hurt`, `kill` and `death`; a team-mate's are
  `mate_hit` and `mate_hurt`; and `seat`, with its `team`, is the person
  taking a bot. A seat falls between two steps and is stamped with the one
  before it (-1 before the first), so the next reading counts it;
- `readings`: one at every whole interval (`difficulty.interval`, ten
  seconds, 200 steps), taken at the start of that step, before its events
  -- the counts (the bot's, the team's `team_dealt` and `team_taken`, and
  `restarts`, how often a seat on the other team emptied them), the
  `share` of the damage the team dealt with the table's prior, the
  `hit_rate`, the `row` and that row's `aim_error_degrees`, and `held`,
  whether the share was inside the band (`difficulty.band`, from 0.45
  short of 0.55), which keeps the row read before.

## One worked by hand

`a-share-on-a-boundary-takes-that-row.json`, with `prior_points` 100:

| step | what happened | dealt | taken | share | row |
|---|---|---|---|---|---|
| 10 | hurt 50 | 0 | 50 | | |
| 200 | reading | 0 | 50 | (0 + 100) / (0 + 50 + 200) = 0.40 | 1, `from` 0.40, outside the band |
| 210 | shot, hit 80 | 80 | 50 | | |
| 220 | hurt 70 | 80 | 120 | | |
| 400 | reading | 80 | 120 | (80 + 100) / (80 + 120 + 200) = 0.45 | 1: on the band's `from`, inside it, held |
| 410 | shot, hit 150 | 230 | 120 | | |
| 420 | hurt 50 | 230 | 170 | | |
| 600 | reading | 230 | 170 | (230 + 100) / (230 + 170 + 200) = 0.55 | 3: on the band's `to`, outside it, the row whose `from` is 0.55 |

The three shares are exact in binary floating point's sense -- the
nearest double to 0.4, 0.45 and 0.55, the same ones the table's literals
parse to -- so the case holds that a share exactly on a row's `from` takes
that row and not the one below, that the band includes its `from`, and
that it stops short of its `to`.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the arithmetic, written from the difficulty table's "about" in
plain dictionaries, importing nothing from this repository. Independent of
the code, not of its author. It also checks that each case shows what its
name says -- nothing happening stays in the middle, dealing climbs to the
hard row through the one above the middle, taking falls to the easy one,
a boundary, an event on a reading's own step, counts that set nothing, a
match won then lost, a share inside the band that moves nothing, a
team-mate's damage moving the share, a change of team starting from empty
and a seat on the same team keeping the counts -- because a vector named
for a row it never reaches holds nothing.

    python3 spec/vectors/player_model/derive.py spec/vectors/player_model

## What holds them

- `make test-player-model-vectors`: Godot's `PlayerModel.replay`, through
  `rules.json`'s table. `player_model_test.gd` runs the same vectors with
  the prior planted at 1, and again with no band, and must see them fail.
- `python3 -m unittest discover -s python/tests -t python -p "test_player_model*.py"`:
  the Python twin, and four planted models -- a boundary given to the row
  below, a prior of 1, no band, and counts kept across a change of team --
  that must fail.
