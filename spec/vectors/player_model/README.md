# Conformance vectors: the bot match's player model

<!-- doc-meta
half_life: structure
verified_on: 2026-11-04
tier: 1
source: https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf
invalidated_if: the difficulty table in godot/game3d/botmatch/rules.json changes, or when in a step a reading is taken
teaches: none
-->

> The person's events in, every interval's reading out: the files that say
> Python's player model and Godot's are one model.

T100 lets the bot match read how well the person plays while they play,
under ADR 0016's amendment: counts only, empty at the start of every match,
rebuilt from that match's events. The model is written twice,
`gameaikit.botmatch.player_model` and `godot/game3d/botmatch/player_model.gd`,
and held here, through the table both read from `rules.json`.

Each file is one match's worth of the person's events from an empty model:

- `last_step`, the last step the match ran (a step is `rules.json`'s
  `step`, 0.05 s), and `events`, each with the `step` it happened in, its
  `kind` (`shot`, `hit`, `hurt`, `kill`, `death`) and, for a hit or a hurt,
  its `points`;
- `readings`: one at every whole interval (`difficulty.interval`, ten
  seconds, 200 steps), taken at the start of that step, before its events
  -- the counts, the `share` of the damage the person dealt with the
  table's prior, the `hit_rate`, the `row` the share reaches and that row's
  `aim_error_degrees`.

## One worked by hand

`a-share-on-a-boundary-takes-that-row.json`, with `prior_points` 100:

| step | what happened | dealt | taken | share | row |
|---|---|---|---|---|---|
| 10 | hurt 50 | 0 | 50 | | |
| 200 | reading | 0 | 50 | (0 + 100) / (0 + 50 + 200) = 0.40 | 1, `from` 0.40 |
| 210 | shot, hit 80 | 80 | 50 | | |
| 220 | hurt 70 | 80 | 120 | | |
| 400 | reading | 80 | 120 | (80 + 100) / (80 + 120 + 200) = 0.45 | 2, `from` 0.45, the middle |

Both shares are exact in binary floating point's sense -- the nearest
double to 0.4 and to 0.45, the same ones the table's literals parse to --
so the case holds that a share exactly on a row's `from` takes that row,
and not the one below.

## Where the answers came from

From neither implementation: `derive.py`, beside the vectors, is a third
copy of the arithmetic, written from the difficulty table's "about" in
plain dictionaries, importing nothing from this repository. Independent of
the code, not of its author. It also checks that each case shows what its
name says -- nothing happening stays in the middle, dealing climbs to the
hard row through the one above the middle, taking falls to the easy one,
a boundary, an event on a reading's own step, counts that set nothing, and
a match won then lost -- because a vector named for a row it never reaches
holds nothing.

    python3 spec/vectors/player_model/derive.py spec/vectors/player_model

## What holds them

- `make test-player-model-vectors`: Godot's `PlayerModel.replay`, through
  `rules.json`'s table. `player_model_test.gd` runs the same vectors with
  the prior planted at 1 and must see them fail.
- `python3 -m unittest discover -s python/tests -t python -p "test_player_model*.py"`:
  the Python twin, and two planted models -- a boundary given to the row
  below, and a prior of 1 -- that must fail.
