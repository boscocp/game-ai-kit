# Review: wave/121-bot-match-reads-the-player

T100: the bot match reads how well the person plays during one match.
`PlayerModel` counts the played bot's events. `MatchDifficulty` reads the
damage share every 10 s through a fixed table in `rules.json` and sets the
other team's `aim_error`. The PR also adds a Python twin and seven vectors,
an event log kept only under `-- --record`, N14 in `check_no_training.py`,
the `CLAUDE.md` row 6 and invariant 6 edit, the V panel lines and the
measurement in `docs/godot/botmatch.md`.

A fresh context reviewed PR #62 at head 2fc63b4. It only read the code and
ran checks in a throwaway worktree. It made no commit, push or PR comment.

**Verdict: changes requested, no blocker.** Four should-fix findings, five
nits and six items for the owner. The model meets ADR 0016's three
conditions, and the tests hold them; I planted a fault against each one.
The gaps are in N14's reach, a 10-second window in which the knob is left
on the wrong team, and two sentences on the doc page that claim more than
the code does.

## What was reviewed

- The whole diff: `player_model.gd`, `match_difficulty.gd`,
  `match_event_log.gd`, and the hooks in `bot_match.gd`, `botmatch.gd`,
  `match_actions.gd`, `match_aim.gd`, `match_bot.gd`, `match_rules.gd` and
  `rules.json`.
- The panel lines and the pt-BR rows.
- N14 and its self-test.
- The Python twin, `derive.py`, the vectors and their README, and both
  test files.
- The measurement script, the doc section, the literature row, the
  manifest, the Makefile targets, `CLAUDE.md` and the STATUS row.
- Read against the task file and ADR 0016's amendment.

## What was run (all green at 2fc63b4 unless stated)

- `python3 scripts/check_no_training.py`: exit 0. `--self-test`: ok.
- `make test-godot-some SUITES="test/botmatch"`: 99 cases, 0 failures,
  no `SCRIPT ERROR`.
- `make test-player-model-vectors`: 7 files, 33 readings, 0 failures.
- The `test_player_model*.py` suite: OK.
- `derive.py` re-run into an empty folder: byte-identical to the
  committed vectors.
- `check_readability.py`, `lint-modules`, `lint-tasks` and `lint-status`:
  ok.
- `make measure-player-model`: reproduces the PR's table exactly, every
  cell of all six rows (6 min 09 s).
- The runtime pt-BR lookup of the new keys, including the one with
  leading spaces: all translated.

## Findings

1. **Should-fix -- N14 does not reach the scripts that really hold the
   model.**
   - Where: `scripts/check_no_training.py:201`. `PLAYER_MODEL_HOLDERS_RE`
     is `\bPlayerModel\b` alone.
   - The model is held through `MatchDifficulty`:
     `bot_match.gd` (`var difficulty: MatchDifficulty`) and `botmatch.gd`
     (`world.difficulty.model`) never name `PlayerModel`, so N14 does not
     read either of them.
   - `botmatch.gd` is the scene that already writes a file
     (`_keep_the_log`) and already carries state from one match to the
     next (`_new_match` keeps each team's switches). That makes it the
     likeliest place for someone to add "remember the player".
   - N13 avoided this gap by also naming the wrapper
     (`Bandit|FightBanditOpponent`).
   - The self-test's "saved by a script that holds one" plant names
     `PlayerModel` explicitly, so it does not cover this case.
   - Reproduce: the reviewer's planting script (`plant.py`, kept beside
     the review, not committed). Plants P1 (`botmatch.gd` writes
     `world.difficulty.model.counts()` to `user://skill.json`), P2
     (`botmatch.gd` sets `world.difficulty.model.dealt` from
     `user://skill.txt`) and P10 (an Elo `+= 32.0 * (won - expected)` in
     `bot_match.gd`) all exit 3, the same code as an untouched tree, with
     no N14 line.
   - Fix: add `MatchDifficulty` to the holder pattern, plus a planted
     case of a save from a script that names only `MatchDifficulty`. Then
     check what this flags in `botmatch.gd`: it calls
     `MatchEventLog.save`, and it may `load`/`preload`.
   - Test carry-over between matches is already caught:
     `test_n_in_the_scene_seats_an_empty_model` checks that one is
     refused. A file written from the scene is not caught by anything.

2. **Should-fix -- "no line that loads its state" misses the plain ways
   to read a file.**
   - Where: `scripts/check_no_training.py:205-206`. The loading net is
     `user://`, `get_user_data_dir`, `ConfigFile`, `ResourceLoader` and
     `load(`. It does not include `FileAccess.get_file_as_string`,
     `FileAccess.open(..., READ)`, `JSON.parse_string` on a file, or
     `preload(`.
   - Reproduce, with the same script:
     - P3: `PlayerModel._init` sets `dealt` from
       `FileAccess.get_file_as_string("res://profile.txt")`.
     - P4: `FileAccess.open(PROFILE, FileAccess.READ)` with a `const`
       path.
     - P5: `preload("res://profile.tres")`.
     - P11: `MatchDifficulty` restores `model.dealt` from
       `JSON.parse_string(FileAccess.get_file_as_string(path))`.
     - All four pass. The task says the planted case is "a model loaded
       at start". The four committed load plants all spell the path
       `user://` or use a loader class, so they test only the spellings
       the net already has.
   - `player_model_test.gd:18` and `:133`, a script N14 reads, use
     `preload` and `FileAccess.get_file_as_string`. Its comment
     ("Preloaded: ... never state read back (N14)") shows the regex was
     fitted around the test file.
   - Fix: widen the net to these reads, and either exempt `godot/test/`
     for the load half by name (saying so in the docstring) or move the
     vector reading out of the suite that names `PlayerModel`.

3. **Should-fix -- after the person gives a bot back or changes team, the
   knob stays on the wrong team for up to 10 s.**
   - Where: `match_difficulty.gd:67` (`_apply`) runs only from
     `before_step` (`:51`), on a whole interval.
     `botmatch.gd:290` and `:295` set `world.person` without calling it.
   - Reproduce (a throwaway `-s` script, seed 4, bot 0 with
     `own_aim_error` 0.5 degrees, the model on):
     - Playing blue at 10.25 s, row 5: red aims 1.50 degrees.
     - Bot given back at 10.30 s, nobody playing: red still 1.50.
     - Taking over red bot 6 and stepping to 17.80 s, before the next
       reading: red, now the person's own team, still aims 1.50, and
       blue aims 3.00.
   - So "nobody playing, nobody's aim is changed" and "never your own
     aim" (`docs/godot/botmatch.md:487`) are each false for up to one
     interval.
   - `test_nobody_playing_changes_nobodys_aim` passes only because it
     steps 20 s past the give-back.
   - Fix: re-apply (or reset) when `world.person` changes. For example,
     give `MatchDifficulty` a `seat(world)` method that `botmatch.gd`
     calls on T. Then make the test assert right after the change.

4. **Should-fix -- the doc page claims more than the gate holds.**
   `docs/godot/botmatch.md:502` says N14 holds the model's file and its
   holders "to writing nothing, loading nothing and stepping nothing".
   - Measured, it is a net: findings 1 and 2 above.
   - Also missed:
     - P6, an exponential moving average
       `skill = skill * 0.9 + won * 0.1` in the model's own file. That is
       the same step as `skill += 0.1 * (won - skill)`, and the ADR
       refuses it by name.
     - P13, an expanded Elo `rating = rating + 32.0 * won - 32.0 * expected`.
     - P9, a difference named first in a holder (by design: own file
       only).
   - The gate's docstring and `CLAUDE.md` ("half held ... a net for the
     common spellings") are honest. The page should say the same: "a net
     for the common spellings, not a proof".
   - Adding the EMA spelling (`x = x * a + y * b`, with `x` read back) to
     the net would be cheap.

5. **Nit -- "settles where it should" and "the model sees the right
   person"** (`docs/godot/botmatch.md:538-541`). The overshoot is reported
   honestly two bullets down. But "where it should" reads as a success
   claim for a difficulty adjuster whose measured effect is to flip the
   match both ways (-121 to +259, and +224 to -218). "Settles in the
   direction expected" says what was measured. Nowhere does the page claim
   the match "adapts to the player" or is balanced.

6. **Nit -- damage counts include overkill.** `match_actions.gd:101` notes
   the zone's full damage even when the target had less health left.
   `player_model.gd:39` says "health points the person's shots took off
   enemies". Either count `mini(damage, health_before)` or reword the doc
   comment. The effect is small (at most one shot per kill), and the Beta
   mean is unaffected in kind.

7. **Nit -- no test replays a log read back from disk.**
   `event_log_test.gd` checks that a file reads back equal to the events,
   and `player_model_test.gd` replays the in-memory events. Together they
   imply the full path from file to replay, but neither does it. They are
   split because of N14 (correct as N14 stands). Also, the log carries
   neither the last step nor the table, so a log alone cannot say how many
   readings the match took after its last event, nor which table it read
   through. Adding `last_step` and the `difficulty` table to
   `MatchEventLog.of` would make condition 3 hold from the file by itself.

8. **Nit -- "no prior" is prior 1.**
   `python/tests/test_player_model_vectors.py:62` is named "without its
   prior" but plants `prior_points=1`. The PR body lists "no prior in
   Python, and prior 1 in Godot" as two plants, and they are the same one.
   Rename it.

9. **Nit -- pt-BR**, `godot/locale/botmatch.csv:81`: "a partir de uma
   parte de {from}" reads awkwardly. A suggestion: "linha {row} de
   {rows}, que começa numa parte de {from}". The other new rows read well.
   The panel's counts only change at each reading, up to 10 s late. That
   is correct, because they are what the row was read from, but the line
   could say "na última leitura" / "at the last reading".

## Checked and found sound

- **Counts only (condition 1).** Every `PlayerModel` field is an `int`,
  and the test proves it by reflection. The share and the hit rate are
  computed when read. Planted `-=` Elo (P8), the incremental mean in a
  second spelling (P7), a write with a `const` path (P12) and
  `ResourceLoader.load` (P14) are all caught.
- **Empty at the start (condition 2).** I planted a `static var` that
  carried `dealt` into each new `PlayerModel`. The replay test caught it:
  9 failures in `player_model_test.gd`.
- **Rebuildable (condition 3).** Live readings equal the replay of the
  person's events, twice, field by field.
- **Event log.** It is written only when `OS.get_cmdline_user_args()` has
  `--record`, once per match, and nothing is written when there are no
  events. It goes to `user://botmatch-logs`, which `scripts/godot` maps
  to the checkout's ignored `.user-data/` (ADR 0022). The suite writes
  under `user://tmp`, which gdUnit4 clears. Nothing is committed, and
  nothing is read back at start.
- **The knob.** It changes `MatchTeam.aim_error` of the other team only,
  bounded by the table. When nobody has played, every reading restores
  each team's own aim (`_own_aim`). `before_step` draws no random number,
  so a match nobody plays is unchanged.
- **The stand-in hook.** `own_aim_error` defaults to -1, and the
  `match_aim.gd` expression then reduces to the old one exactly. The 99
  botmatch cases, digests included, pass. `difficulty` is null outside the
  scene and the measurement, so the effects gate never calls it.
- **Vectors.** `derive.py` imports nothing from the repository, uses a
  windowed sum rather than the implementations' queue, regenerates the
  vectors byte for byte, and checks that each case does what its name
  says. Both twins pass. Both boundary shares (100/250 and 180/400) are
  correctly rounded divisions equal to the literals.
- **`CLAUDE.md`.** It changes exactly what the task asks for: row 6 reads
  "N9, N13 and N14", and invariant 6 names the difficulty model. The row
  still says "half held" and claims no more than that.
- **Invariant 13.** V while playing shows the counts, the share worked
  out with its prior, the hit rate, and the aim with its row and its
  `from`, with `<< changed at N s`. `decision_overlay()` gains
  `difficulty` with the same fields.
- **The measurement's honesty.** The PR body and the page both report
  the overshoot and the chatter, and that the table was not tuned. I
  reproduced the numbers exactly.

## What was done about them

The reviewer's `tools/plant.py` was not committed. Its fourteen plants were
run against the fixed branch: all fourteen are refused now. Before the fix,
P1-P5, P6, P9, P11 and P13 passed.

1. **N14 now reads the scripts that hold `MatchDifficulty`.**
   - `PLAYER_MODEL_HOLDERS_RE` is now `\b(?:PlayerModel|MatchDifficulty)\b`,
     as N13 names `FightBanditOpponent`. `bot_match.gd`, `botmatch.gd`,
     the measurement and the suites are all read now.
   - Three planted cases were added, one for each of the reviewer's: the
     scene saving the counts to `user://`, the scene loading them back,
     and an Elo update in `bot_match.gd`. Each one is refused.
   - The only thing it then flagged in `botmatch.gd` was the
     recording line, which spelled `user://botmatch-logs/` inside a
     `tr()`. That line now formats `MatchEventLog.FOLDER` in. The scene
     reads and writes no file itself: `MatchEventLog` does.
   - Whether N14 should name `MatchDifficulty` at all, or take the ADR's
     "names the component's class" literally, stays on the owner's list.
2. **The "loads state" net now covers any file read.**
   - In every target, N14 now refuses `FileAccess` at all, `JSON`,
     `ConfigFile`, `ResourceLoader`, `load(` and `preload(`, as well as
     `user://` and the user data folder.
   - Four planted cases were added: `FileAccess.get_file_as_string`,
     `FileAccess.open(PROFILE, FileAccess.READ)`, `preload(` and
     `JSON.parse_string`.
   - Nothing is whitelisted. The test code was reorganised instead, so
     each piece holds a model or reads a file, never both:
     - the vectors are read by `ModelVectorFiles`, which names neither
       class and holds no model;
     - they are checked by `ModelConformance`, which reads no file;
     - the runner and the suite are handed dictionaries;
     - the scene test moved to `botmatch_restart_test.gd`, which loads
       the scene and reaches the model only through `world.difficulty`;
     - each of these files says why in its header.
   - The table was already read outside the holders, by `MatchRules`.
3. **The knob moves at once when the person changes.**
   - `BotMatch.seat_person(id)` sets the person and calls
     `MatchDifficulty.seat`. That re-applies the row read last: both teams
     get their own aim when nobody plays, and the change moves to the new
     other team when the person changes side. Nothing is counted or read.
   - `botmatch.gd`'s T now goes through it.
   - New tests:
     - `test_giving_the_bot_back_restores_both_aims_at_once`;
     - `test_changing_sides_moves_the_aim_to_the_new_other_team_at_once`;
     - `test_a_match_nobody_plays_changes_nobodys_aim`, which replaces the
       one that waited 20 s.
   - Each new test checks the aim after one step taken half a second past
     a reading. The first cut stepped exactly onto a reading, which
     re-applied the knob, and a planted `seat` that did nothing passed.
     With the half-second offset, that same plant fails.
4. **The page calls N14 a net.**
   - `docs/godot/botmatch.md` says what N14 reads and refuses, calls it
     "a net for the common spellings, not a proof" as `CLAUDE.md` does,
     and names what passes it: a step through a helper function, a moving
     average with a temporary, and a file read by a non-holder and handed
     in. It also says that "starts empty" is held by the tests, not the
     gate.
   - The cheap spellings were added to the net. Beside the model, a value
     read back into itself through a product is refused (P6's moving
     average, either way round). In the model's two files
     (`player_model.gd`, `match_difficulty.gd`), any read-back with a `*`
     or `/` is refused (P13's expanded Elo), and so is any scaled `+=`
     (P9's difference named first).
   - The gate's docstring was rewritten to match.

Nits:

5. The page now says "settles in the direction expected", and that this
   does not mean the match is balanced. "Sees the right person" is gone.
6. The doc comment was reworded rather than the count capped. A killing
   hit counts its whole damage, at most one hit's overshoot a kill. The
   measured numbers stay as they were measured.
7. `MatchEventLog.of(world, seed, arena)` now writes `last_step` and the
   `difficulty` table beside the events.
   `test_the_log_read_back_from_disk_rebuilds_the_readings_by_itself`
   saves a played match's log, reads it back and replays it from the
   file's own table and last step. The rows and counts it gets are the
   ones the match read live. Writing and reading go through
   `MatchEventLog` (under `MatchEventLog.TESTS`, `user://tmp`); the suite
   spells no file access itself. The README and the page say so.
8. The Python plant is now `test_a_model_with_a_prior_of_one_is_refused`.
   The README and the PR body say "a boundary to the row below and a prior
   of 1 in Python, a prior of 1 in Godot".
9. pt-BR: "linha {row} de {rows}, que começa numa parte de {from}". The
   counts line now says it is the last reading's: "at the last reading,
   the match had counted of you: ..." / "na última leitura, a partida
   tinha contado de você: ...".

## For the owner

1. Whether the model should read one bot's share (now) or the team's
   share or the score lead. Measured, one bot's share swings six bots'
   aim, and the match flips both ways.
2. The table, the 10 s interval, and whether to add a band of no change
   round the middle for the even player's chatter.
3. Whether the counts carry across a takeover of a bot on the other team,
   as they do now, or reset. This interacts with finding 3.
4. Keeping the log in `user://` (ADR 0022) rather than `data/` (ADR
   0017's pattern for the fighting game).
5. Whether N14's holders should include `MatchDifficulty` (finding 1), or
   whether the ADR's "names the component's class" is meant literally.
6. The manual check in the task: play badly, then well, with V on; then
   N.
