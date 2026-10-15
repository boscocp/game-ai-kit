# Review: wave/42-behaviour-cloning

One fresh context reviewed it, in its own git worktree, at 296e9ae.

What it read: CLAUDE.md, T18, ADR 0016 and 0017, the behaviour-cloning
concept page, the Shadows and ghosts in the fighting-game survey, the wave
41 record, the cloning vectors and their README, the diff, and the
fighting files around it (`fight_opponent.gd`, `fight_model_opponent.gd`,
`fighting.gd`).

What it ran: `make check` (exit 0: 768 gdUnit cases, 278 Python tests,
every vector family, the rows matching all 33 recordings, the inference
budget, the report); `compare.py --report` (exit 0, the concept page's
table to the decimal); the scores on the four-fight rows of 3f09899 and on
the stand-ins (both as the page says); each held-out fight scored on its
own, and the n-gram over all nine; a probe seating each of the three
imitators against the fixed medium opponent, 20 fights each, comparing the
`last` it was asked with against what `FightRecording.rows_of` would have
written for the same fight; `check_no_training.py` with the published file
removed; 25 mutations.

## What was reviewed

Commit 296e9ae: `gameaikit.cloning` (rows, softmax, ghost, measure,
publish, compare), `SoftmaxModel`, `CaseTable` and `ClonedPlayer` in
`ai_learning`, `clone_weights.json`, `FightSituation`, `FightAction`,
`FightRecording`, `FightCloneOpponent`, the changes to `FightOpponent`,
`FightModelOpponent`, `fighting.gd` and the panel, the six new test
scripts and the two suites, the stand-ins, the vectors and `derive.py`,
N10 in `check_no_training.py`, ADR 0017, the concept page, the README row,
the Makefile and T18.

## Checked and true

- `compare.py --report` refuses with exit 1 and says why when the player
  has no held-out rows; the test plants one recording and holds it. It
  also refuses win rates measured on another `clone_weights.json`.
- The split is by whole recording; nothing in the published file was
  fitted on the three held-out fights; `trained_on` names both lists.
  A leak in `measure.every_score` (the model fitted on the held-out rows
  too) is caught by N10, because `publish` goes through the same function.
- Every number in the comparison table, the four-fight paragraph, the
  stand-in table and the inference paragraph is what the commands print
  today.
- The n-gram is scored exactly as the game's learner counts: a new action
  each time the reading changes to something other than "", order 2, decay
  0.8, prior 1, empty at every fight.
- The features are computed in GDScript only; Python sees rows. The rows
  are what the recordings cut today (`make test-clone-rows`), and a deleted
  recording, an edited row or a moved distance threshold makes that fail.
- N10 catches an edited weight and an edited case count. The softmax and
  the case table agree across the two languages on the vectors; dropping
  the bias or pooling only the first nearest case fails them.
- `ai_learning` names no game class; `check_addon_deps.py` agrees.
- Nothing is recorded without `-- --record`, and the screen says so.

## Findings

### Must fix

1. **The clone is asked with a `last` its rows never meant.**
   `godot/game/fighting/fight_clone_opponent.gd:69-71` sets `_last` to the
   *option drawn*; `godot/game/fighting/fight_recording.gd:74-77` writes
   `last` as `FightAction.of` *read off the fighter*. They differ whenever
   the option is not what the fighter visibly does: a strike chosen out of
   reach steps in (`fight_opponent.gd`, "out of reach: steps in"); a
   "guard standing" with nothing to block reads as "step out" -- in the
   rows "guard standing" only ever means a hit was actually blocked; a
   jump re-decided mid-air still reads "jump". Measured, 60 fights against
   the fixed medium: of 8,266 decisions, **2,341 (28.3%)** were asked with
   a `last` that `rows_of` would not have written for that same fight --
   mid -> step in 489, throw -> step in 386, high -> step in 241, guard
   standing -> step out 220. The cadence differs too: the rows are one per
   *change* of action (only 25 of the owner's 450 rows have
   `last == action`), but the clone re-decides every 10-12 frames during a
   walk or a guard -- 8,266 decisions against 5,874 action changes -- so
   after "step in" it is asked a question whose training answer is almost
   never "step in". This contradicts the headers of `fight_situation.gd:16-19`
   and `fight_recording.gd:13-16` ("what it learns from and what it is
   later asked about are the same"), and it puts the win-rate column --
   "the model beats the ghosts at guessing, and loses to them at fighting"
   -- in doubt, because `last` is the feature the model leans on most
   (33.8% from `last` alone). Nothing tests it: `_last` never set, `_last`
   kept across `new_fight`, the situation read from the other fighter's
   seat, the exact ghost falling back to nothing, and the clone drawing
   uniformly all survived `make check`.
   *Fix:* keep `_last` the way `rows_of` keeps it -- read the clone's own
   fighter with `FightAction.of` each frame it is handed and update on a
   change to a non-empty reading -- and ask for a new decision only when
   that reading changes or the plan runs out on a "" reading. Then a test
   that cuts rows from a fight the clone played (clone as player 0) and
   asserts every decision's `last` equals the row's; and a test per source
   that a one-case player is imitated (a 1-case table plays only its
   answer; a softmax with one dominant answer draws it most of the time).
   Re-run `make test-clone-fights` and replace the win-rate column.

### Should fix

2. **Three new gates are born with no planted case (invariant 4).**
   `godot/test/export_clone_rows.gd:42-47` has no run that hands `--check`
   a stale file and requires exit 1; `godot/test/cloning_vectors_runner.gd`
   has no planted vector (wave 41 added one per n-gram claim for exactly
   this); `godot/test/clone_fights.gd` has only its reference row. And N10
   at `scripts/check_no_training.py:469-471` exits 0 with the published
   file deleted -- "N10 inspected nothing" while returning ran=True --
   where N7 at `:434-435` makes a missing file inside an existing folder a
   finding. `cloning_test.gd` happens to catch the deletion; the gate does
   not. *Fix:* a planted stale rows file in a suite or a `--self-test`
   flag; a planted vector the runner must refuse; N10 a finding when
   `ai_learning/` exists and the file does not.

3. **The net has two new holes, and one in-repo example of the N9 dodge.**
   Planted in `fight_clone_opponent.gd`, both passed `check_no_training.py`
   (exit 0): `FileAccess.open(ClonedPlayer.DEFAULT_PATH, FileAccess.WRITE)`
   -- the game overwriting the published player; N2 only matches the
   literal "weights.json", and there is no N8 for this file as there is
   for the checkers weights -- and counting the fight into the ghost's
   table, `player.cases.cases[key] = counts` after `counts[x] += 1`-style
   code. The second is a Shadow trained at game time, and since
   `fighting.gd` loads `ClonedPlayer` once, it would also outlive the
   fight. Separately, `godot/test/win_rate_file.gd` exists so that
   `clone_fights.gd`, which seats a learner, can write a file without
   tripping N9 -- harmless here, but it is the indirection wave 41's
   finding 3 warned of: a script holding a learner may now hand any
   dictionary to a class that does not name one. *Fix:* N8's shape for
   `clone_weights.json` (the file name, `ClonedPlayer.DEFAULT_PATH`,
   `ai_learning/` + a name); a rule that no GDScript outside the addon
   assigns into a `CaseTable`'s `cases`, or make `CaseTable` copy on load
   and hand out copies; and N9 extended to classes called from a
   table-holding script, or `WinRateFile` taking typed ints only.

4. **"The n-gram guesses best, by seven points" rests on one held-out
   fight.** `docs/concepts/behaviour-cloning.md:85-90`. Per held-out fight,
   n-gram against the six-feature model: 20.0 vs 24.0% (17-32-38, the
   model ahead), 55.0 vs 27.5% (17-55-48), 51.2 vs 46.5% (17-57-06).
   Without 17-55-48 the two tie at 32 of 93. Three fights, 133 rows, no
   interval anywhere in the report. The page does say "the numbers below
   carry it", but then states a ranking. *Fix:* `compare.py` prints each
   held-out fight's line under the pooled one; better, score every method
   leaving one recording out at a time (nine folds -- the n-gram needs no
   fold at all and scores 45.3% over all nine), and word the conclusion to
   what survives that.

5. **Doc and report text that the data contradicts.**
   - `docs/concepts/behaviour-cloning.md:17-19`: "three against the fixed
     opponent at medium, one at hard, five against the learner at medium
     and hard". The recordings say four `opponent: medium`, one
     `opponent: hard`, four `learner: hard`, none at learner medium (see
     8).
   - Same lines, "about eight minutes of play": the nine logs are 10,685
     frames, 2 min 58 s at 60 frames a second.
   - `:172` "One person, four fights" -- nine since 4a25eae.
   - `:162` and `publish.py:8-10` say N10 runs `publish --check`; it
     refits and compares with a 1e-6 tolerance, while `--check` compares
     text exactly -- and `clone_weights.json` is published at full double
     precision, not rounded to six places as `TOLERANCE`'s comment says
     published weights are, so `--check` may differ across machines where
     N10 would not.
   - `python/gameaikit/cloning/compare.py:87` prints "told apart by a
     person: not yet asked" on every run; the owner's manual check is done
     and in the README. The acceptance command prints a false line.
   *Fix:* correct each; have the report read the manual-check result from
   somewhere it is recorded, or drop the line.

6. **`ClonedPlayer` accepts files the game then crashes on, or silently
   misreads.** `godot/addons/ai_learning/cloned_player.gd:66-91`.
   Removing the row-size check (`:87`) survived every gate -- the test
   plants only a bias of the wrong length. Not checked at all: `columns`
   is a list of strings, `bias` entries are numbers, each case's counts
   are numbers, and each case key has `features.size()` words -- a key
   with fewer makes `CaseTable._differing` (`case_table.gd:94-98`) index
   past the end on the first nearest lookup. And nothing checks the file's
   `features` against `FightSituation.FEATURES`: a file from an older
   feature set loads, every exact lookup misses, and the clone plays
   biases with nothing on screen saying why. *Fix:* the missing checks
   with codes and planted cases; the feature check in
   `FightCloneOpponent` (the addon must not know the game's features),
   reported in `found`.

7. **Python's copy of the learner's settings is held by nothing.**
   `python/gameaikit/cloning/measure.py:29-31` repeats order 2, decay 0.8,
   prior 1 from `FightModelOpponent`'s defaults; `NGRAM_DECAY = 1.0`
   survived every gate, and so would the game's default changing. And
   `compare.py` refits its own split rather than reading `trained_on.held_out`
   from the published file: publishing a fit that includes the held-out
   fights is caught today only because the win rates then name another
   sha256 -- re-run `make test-clone-fights` and the report is green while
   scoring the published model on rows it was fitted on. *Fix:* the
   n-gram settings in the rows header (Godot writes them, as it writes
   `reaction`) or a test that reads both; `compare.py` failing when its
   split differs from the published file's `trained_on`.

8. **`facing` records the mode at the moment of saving, not the fight.**
   `godot/game/fighting/fighting.gd:171` passes `dummy_mode`, but M
   (`:111-112`) changes `dummy_mode` without reseating the opponent, so a
   fight finished after M is saved under the next mode's name. That is
   one plausible source of finding 5's mismatch. Also: a fight against a
   scripted dummy ("stand", "jab") is recorded as `person` and fitted
   with no filter. *Fix:* save the mode the seat was built with; either
   refuse to keep dummy-mode fights or have `publish` take a `--facing`
   filter and print what it fitted.

### Notes

9. Ties are untested in both languages: `>=` in `SoftmaxModel.likeliest`
   and in Python's `Softmax.likeliest` both survived. A tie vector would
   pin "the first in `classes`".
10. `test_a_recording_is_cut_at_each_new_action_from_what_was_seen_a_reaction_before`
    passes with no reaction delay at all (the fighter is still "far" at
    frame 31); only `make test-clone-rows` caught that mutation. Assert a
    feature that differs between frame 16 and frame 31.
11. The budget times the lookup only, over situations all in the table:
    not `FightSituation.of`, not the draw, not `everything()` on a miss.
    The header says "timed the way the game makes one". It is measured
    headless, not in the demo T18 names, and on a fast desktop -- which
    the page admits.
12. The win rates are fought in lancer and dancer mirrors; every recorded
    fight was lancer against dancer, so half the column is a matchup the
    player never played. The page says the rates go stale with the rules
    and only the weights' sha256 is checked; a hash of the frame data and
    of the opponent scripts in `win_rates.json` would close that.
13. `CaseTable.exact` returns its own dictionary in both languages; a
    caller that edits the answer edits the table.
14. Stale outside the wave's files: T18 is still `todo` in
    `tasks/STATUS.md:53`, the "Next" line still names it, the CLAUDE.md
    row for invariant 6 names N9 but not N10, and there is no
    `docs/godot/` page for the three new addon classes (the README row
    links only the concept page). `spec/vectors/cloning/derive.py` uses
    one-letter names and no types, as `ngram/derive.py` does; outside the
    readability gate, but still read by people.

### The mutations

25. Killed, 12: an edited weight, an edited case count, an edited
held-out row, a deleted recording, `CLOSE` 50 -> 60, the published file
deleted (by `cloning_test.gd`, not N10), nearest pooling one key, the bias
dropped, the corner read off the wrong wall, rows cut with no reaction
delay (only by `test-clone-rows`), the model fitted on the held-out rows,
holding out every third. Killed only because the win rates then name
another file, 2: the published fit including the held-out fights, the
penalty off. Survived, 11: `_last` never set; `_last` kept across
`new_fight`; the situation read from the other seat; the exact ghost
falling back to nothing; the clone drawing uniformly; the loader's
row-size check removed; the game writing `ClonedPlayer.DEFAULT_PATH`; the
ghost counting during the fight; Python's n-gram decay 1.0; ties to the
last, in GDScript and in Python.

## What was done about them

All fourteen, by the author, on the branch, before the merge.

1. **Fixed, and it changed the answer.** The clone reads its own fighter
   off every frame it is handed and keeps the last action seen; the rows
   write `last` the same way, as of the frame the situation is read from
   (`FightRecording.last_seen`), so both are as late as the game. A test
   plays the clone through a fight and checks every decision's `last`
   against the rows'; with the old code reinstated it fails 59 times. The
   cadence is left and written in the clone's header: the rows have no
   durations to match it with. The n-gram is now scored as late too -- each
   row carries the frame it began on, and the n-gram guesses from actions
   begun at least 15 frames before -- since the old scoring gave it the
   present while the models saw the past. Re-measured: nothing fitted beats
   the floor over all nine fights, the n-gram beats it by four points, the
   ghosts beat medium 78 and 86 times in 100 and the clone 64. The page
   says the earlier reading was wrong, and why.
2. A stale rows file and a fresh one, in `cloning_test.gd`; a planted wrong
   likeliest and a wrong distance the vector runner must catch before it
   trusts itself; N10 a finding when `ai_learning/` exists without its
   player, with a self-test. `clone_fights.gd` keeps its reference row as
   its planted case.
3. N11 refuses a GDScript write where the cloned player lives, by name or
   by `ClonedPlayer.DEFAULT_PATH`; N12 refuses a write into a ghost's
   `.cases` outside the addon; both with planted cases, and one that a read
   is not a write. `CaseTable` copies what it is given and `exact` hands
   back a copy, in both languages. `WinRateFile.write` takes a `String` and
   typed `int`s only.
4. The report prints each held-out fight alone, and every recording held
   out once (nine folds). The page reads the latter.
5. Each corrected: four medium, one hard, four learner hard; 10,685 frames,
   about three minutes; nine fights; what N10 and `--check` each compare.
   Weights are rounded to six places. The report names the manual check's
   record instead of a stale line.
6. C4 for words, C5 for sizes (with a planted row of the wrong length), C6
   for a bias, C7 for a case's key and counts; the clone refuses, on
   screen, a player cut with other features.
7. A Python test holds the report's order, decay and prior to the
   learner's own defaults; `compare.py` fails when the published file was
   fitted on another split than the one it scores.
8. A change of mode while recording keeps the fight so far under the mode
   it was fought against and begins another; a fight against a scripted
   dummy is not kept. The nine recordings already made are as they are.
9. A tie in the softmax vector: high and low at 0, the first wins.
10. The test asserts `last` before and after the reaction delay.
11. The budget times the whole decision through `FightCloneOpponent` on
    every frame of a recorded fight: 0.038 ms the clone, 0.12 ms a ghost.
    Still headless, and the header says why.
12. The win rates name the frame data's sha256 and the report checks it.
    The mirrors and the opponents' scripts are written down as not covered.
13. Done with 3.
14. STATUS, the CLAUDE.md row (N10-N12) and `docs/godot/cloning.md` are
    written. `derive.py` keeps its short names, as the n-gram's does: it is
    a script that writes numbers, outside the gate, and says so.

## Not checked

- The stand-ins' win rates (87-92 against 72): they need a stand-in
  published and fought; the held-out accuracies were checked.
- Whether the win-rate column moves once finding 1 is fixed -- it should
  be measured, not assumed.
- The demo itself, opened and played: the panel was read as code, not
  watched.
- `make record-fights` end to end, and the close-window save
  (`NOTIFICATION_WM_CLOSE_REQUEST`).
- A second machine: the full-precision weights against `publish --check`.
