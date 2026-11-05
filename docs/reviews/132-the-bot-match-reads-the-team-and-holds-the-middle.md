# Review: wave/132-bot-match-reads-the-team

T123: the bot match's difficulty reads the team's share of the damage,
holds the row read last while that share is inside a band (0.45 short of
0.55), and empties the counts when the person takes a bot on the other
team. The seat is a logged event, so the replay does the same. The PR also
updates the Python twin, `derive.py` and the vectors (4 new, 7 updated),
the V panel and its pt-BR rows, the measurement script and the doc page.

A fresh context reviewed PR #77 at head 726d8ee. It only read the code and
ran narrow checks in a throwaway worktree. It made no commit, push or PR
comment.

**Verdict: changes requested, no blocker.** Three should-fix findings and
two nits. The model still meets ADR 0016's three conditions and N14:
nothing new is saved, and the team change is in the log. The twins agree
on the band and on the reset, and the vectors bind both. The gaps are two
plants the suite does not catch, and a sentence on the doc page that the
table beside it does not support.

## What was reviewed

- The whole diff: `player_model.gd`, `match_difficulty.gd`,
  `bot_match.gd` (`seat_person`, `note`), `match_event_log.gd`,
  `botmatch_lines.gd`, `rules.json` and the pt-BR rows.
- The Python twin, `derive.py`, the 11 vectors and their README, and both
  Python test files.
- `player_model_test.gd`, `botmatch_restart_test.gd`,
  `model_conformance.gd` and `player_model_measure.gd`.
- The doc section and the STATUS row, read against the task file, T100's
  review (`121-the-bot-match-reads-the-player.md`) and ADR 0016's N14.

## What was run (green at 726d8ee unless stated)

- `make test-player-model-vectors` (the runner, called directly): 11
  files, 54 readings, 0 failures.
- `make test-godot-some SUITES="test/botmatch"`: 106 cases, 0 failures,
  no `SCRIPT ERROR` (run under plants P4 and P5 below, which it did not
  catch).
- The `test_player_model*.py` discover: 17 tests, OK.
- `derive.py` re-run into an empty folder: all 11 vectors byte-identical
  to the committed ones.
- `check_readability.py` and `check_no_training.py`: exit 0.
- The 7 updated vectors, compared with `origin/main` by script. Six have
  the same events and the same rows; they only gain `team_dealt` and
  `team_taken` (equal to `dealt` and `taken`, as no mate event is in
  them), `restarts: 0` and `held`. The seventh, the boundary case, gains a
  third interval, and its 0.45 reading moves from row 2 to row 1. That
  follows from the rule: 0.45 is the band's `from`, inside it, so the row
  read before (1) is held. None was regenerated to make a test pass.
- `make measure-player-model` was **not** re-run (6 min, lean routine).
  The findings on the measurement are read from the PR's own table.

## Mutation round

Each was one line, run against the narrow test, then restored
(`__pycache__` cleared after each Python one).

| | plant | where | caught by |
|---|---|---|---|
| P1 | GDScript `_seat` never empties the counts (the Python-only plant, in GDScript) | `player_model.gd:101` | vectors runner (`a-change-of-team-starts-from-empty`, step 600); `player_model_test.gd` via `test_a_model_with_another_prior_fails_the_vectors`, which also checks the real model against every vector |
| P2 | GDScript `replay` does not put the row back on a restart | `player_model.gd:185` | vectors runner (row 4, the vector 2) |
| P3 | `MatchDifficulty._catch_up` does not put the row back live | `match_difficulty.gd:83` | `test_changing_sides_empties_the_counts_...` and the live-vs-replay test |
| P4 | seat stamped `steps_done`, not `steps_done - 1` (decision 4 undone) | `bot_match.gd:159` | **nothing in the PR** (106 cases green); probe `test_a_seat_on_a_reading_step_rebuilds_as_read_live` fails |
| P5 | `note` takes the other team's hits as `mate_` (`==` to `!=`) | `bot_match.gd:177` | **nothing in the PR**; probe `test_mate_events_come_only_from_the_persons_team` fails |
| P6 | Python `replay` does not put the row back on a restart | `player_model.py:173` | `test_every_reading_is_the_vectors` |
| P7 | Python `_seat` never empties | `player_model.py:101` | the vectors test and `test_a_seat_on_the_other_team_empties_...` |

The two probes are in `scratchpad/review-77/review_probe_test.gd`. Both
pass on the PR and each fails its plant.

## Findings

1. **Should-fix: decision 4 has no test** (`bot_match.gd:159`). The seat
   is stamped `steps_done - 1` so that a seat taken between steps is
   counted by the next reading, live and replayed alike. That only
   matters when the seat falls exactly on a reading's step
   (`steps_done % interval_steps == 0`), and every seat in the suite is
   at 30.5 s or 41.0 s. Plant P4 (stamp `steps_done`) leaves all 106
   cases green. Live, the seat empties the counts before the reading at
   that step; replayed, the seat is counted one interval later, so
   condition 3 (rebuildable from the log) silently breaks for exactly
   the case the decision exists for. *Proved by:* probe
   `test_a_seat_on_a_reading_step_rebuilds_as_read_live` (play to 30.0
   s, seat on red, play to 60 s, `_rebuilt_as_read`), green on the PR,
   red under P4. *Fix:* add it to `player_model_test.gd`, in its own
   test.
2. **Should-fix: the doc page says the chosen band "had the smallest
   leads on all three", and its own table says otherwise**
   (`docs/godot/botmatch.md:636-637`; the PR body repeats it). Even: no
   band gives +4, the chosen band +7. Sharp: 0.40-0.60 gives +8 and
   0.47-0.53 +28, the chosen band -47. The chosen band is smallest only
   for the poor stand-in. What the table does support: the smallest
   *sum* of |lead| (66, against 96 for 0.47-0.53, 153 and 163), and the
   fewest changes of the three narrower settings. By the worst case,
   0.47-0.53 (40) edges 0.45-0.55 (47), and both are within the
   tens-of-points spread of five seeds the page already names. *Fix:*
   say "the smallest leads in sum" and that 0.47-0.53 is as good within
   the noise; see owner item 1.
3. **Should-fix (test gap, small): nothing holds that a `mate_` event
   comes from the person's own team** (`bot_match.gd:177`). Plant P5
   (`!=`) turns the other team's hits into the person's team's. The
   share then reads the opponents' damage, and
   `test_the_share_is_the_teams_the_persons_bot_and_its_mates` still
   passes (it only asks for some mate events and `team_dealt > dealt`).
   *Proved by:* probe `test_mate_events_come_only_from_the_persons_team`
   (a red hit and hurt note nothing; a blue team-mate's hit notes one, a
   shot none). *Fix:* add a test like it.
4. **Nit: "between rows 2 and 4"** (`docs/godot/botmatch.md:643`). True
   of the poor and even stand-ins. The sharp one also reads row 5 (from
   0.6) at its first reading on every seed, and once later on seed 3,
   per the page's own row strings. "Either side of the middle, and the
   hard row early for a sharp player" is what the table shows.
5. **Nit: "tips a little past even"** (`docs/godot/botmatch.md:634`).
   -47 is the largest |lead| of the chosen band, about a fifth of the
   +224 it corrects. "Tips past even" is enough; "a little" undersells it
   beside the +7.

Nothing found against the readability rules: `check_readability.py`
passes, the new functions are short, and every public one says what and
why. The new GDScript and Python doc comments are not paraphrases.

## Invariant 6 and N14

- **Nothing survives the match or is saved.** The model is still made
  new by `MatchDifficulty._init`. Its new fields (`team_dealt`,
  `team_taken`, `restarts`) are sums and counts that start at 0, and
  `team` starts at -1. The only thing written to disk is the event log,
  as before, under `-- --record` and the tests' folder. It now carries
  the seat's `team`, which `MatchEventLog.read` keeps.
- **Rebuildable, team change included.** The seat is an event, the
  replay counts it at the same place, and P1, P2, P3, P6 and P7 are each
  caught. The disk round trip is held by
  `test_the_log_read_back_from_disk_rebuilds_the_readings_by_itself`,
  which now seats through `seat_person` and so has a seat in its log.
  P4 is the one gap (finding 1).
- **`team` is a label, not a count.** It is the value of the last seat
  event, so the log holds it, and a replay rebuilds it. That stays inside
  N14's intent. See decision 3 below.

## The PR's decisions

1. **Band 0.45-0.55.** Sound as a choice. The reason given for it is
   overstated (finding 2).
2. **The same prior (100) on the team's share.** Sound; it is what was
   measured.
3. **`PlayerModel.team`, an int.** Sound. It is rebuilt from the log at
   every seat, starts at -1 with each model, and the alternative (the
   replay tracking the side outside the model) only moves the same int
   elsewhere. The count test now says "counts, and the team they are
   of", which is honest.
4. **Seat stamped with the last step.** Correct, and the only way the
   live reading and the replay agree on a seat at a reading's step. It
   needs a test (finding 1).
5. **The row snaps to the middle on a change of team.** Sound, and held
   live (P3) and in the replay (P2, P6). Without it the share's 0.5 is
   inside the band and the old side's row would be held indefinitely,
   as P2 shows (row 4 kept).
6. **Only seats of a bot are logged.** Sound: a give-back leaves the
   model's `team` as it was, so a later seat on the other side still
   compares against the side the counts are of.
7. The manual check stays the person's.

## For the owner

1. **The band's width.** 0.45-0.55 and 0.47-0.53 are not separated by
   five seeds: one is better in sum, the other in the worst case.
   *Recommended:* keep 0.45-0.55, but word the page as finding 2 says.
2. **The knob cannot return to the middle row.** The band is the middle
   row's own range, so after the first change the middle row is reached
   only by a change of team. The page says this plainly. A step of one
   row at a time, already named on the page, would remove it.
   *Recommended:* a follow-up task, if the alternation shows in play.
3. The manual check (play poorly, then well, then take a red bot, with V
   open) is the only place the "settles without flipping" claim can be
   seen; the measurement says it alternates instead.

## What was done about them

Applied on the branch:

1. **The seat on a reading's step is tested.**
   `test_a_seat_on_a_reading_step_rebuilds_as_read_live` is in
   `player_model_test.gd`, using that suite's helpers. With the seat
   planted as stamped `steps_done` (not `steps_done - 1`), it fails, and
   was the suite's only failure under that plant.
2. **Mate events come only from the person's team.**
   `test_mate_events_come_only_from_the_persons_team` is in the same suite.
   It also checks the noted event's kind. With `==` planted as `!=` in
   `BotMatch.note`, it fails. Both plants were undone, and the suite was
   rerun green.
3. **The page no longer says "smallest on all three".** It now says the
   band is smallest in sum, 66 against 96 for 0.47 to 0.53. It also names
   the columns where another band was nearer even, and says that 0.47 to
   0.53 has the smaller worst case (-40 against -47). Five seeds do not
   separate the two bands. The PR body says the same.

Nits:

- The alternation line now says the sharp stand-in reads row 5 at its
  first reading on every seed. It also says that only a change of team
  brings the knob back to the middle row.
- "Tips a little past even" now reads that -47 is the largest lead with
  this band.

The owner's three items are in the PR body's decisions.
