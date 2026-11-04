# Review: wave/124-the-tactical-news-keeps-its-words-as-keys

T110: the tactical game's news of what was played becomes a `Sentence`
and is worded where it is shown. That covers `TacticalCombat.told`,
`TurnStart.open`, `ControlPoints.pay`, the scene's `_last_event` and
`_computer_news`, and the XCOM-style shot (`SquadCombat.told`).

A fresh context reviewed PR #65 at head 805eb0a. It read the code and
planted faults in a throwaway worktree. Nothing was pushed or committed.

**Verdict: approve, with two should-fix findings.** There is no blocker.
The two should-fix findings are tests that do not hold what they claim.
There are three nits and three items for the owner. One owner item is a
fog hole. This PR did not open it and does not widen it, but it is still
open.

## What was reviewed

The diff against main: `squad_combat.gd`, `squad_ruleset.gd`,
`advance_wars_ruleset.gd`, `control_points.gd`, `tactical.gd`,
`tactical_combat.gd`, `tactical_ruleset.gd`, `tactical_status.gd`,
`turn_start.gd`, the new `tactical_news_test.gd`, the four suites that
now read `news_in_english()` / `Sentence.english`, `localisation.md`, and
the task file. The review also read `sentence.gd`,
`TacticalStatus.said`/`word`, `TacticalRefusal.words`, `SquadStatus.computer_text`,
`tactical.gd`'s `_drawn_fog`/`_status_text`, and T85's record
(`docs/reviews/119-xcom-style-mode-you-can-play.md`).

What holds:

- **No `tr()` or `TranslationServer.translate` is left on a news path.**
  The remaining calls in `tactical.gd`, `tactical_combat.gd`,
  `control_points.gd` and `squad/` are refusals (`_last_refusal`,
  `why_refused`), legends, titles and `ControlPoints.line`. None of them
  is news. Only `turn_start.gd` and `tactical_recording.gd:112` call
  `TurnStart.open` and `towers_fire`, and the recording keeps `[0]`. The
  skirmish (`main.gd`) calls neither. `rts.gd`'s `told` is a different
  function.
- **Nested values reword.** A side is its key (`side_word`). A piece's
  bare name is a String value that goes through `TacticalStatus.word`.
  "the piece" / "a piece" are nested sentences, and the squad outcome is
  one too. `cells = ", ".join(where)` is a String. It goes through `word`
  and comes back unchanged because it is not a key, which is correct.
- **Keys exist in both languages.** Every key the PR now keeps has a
  pt_BR row in `tactical.csv` / `squad.csv`: the three `told` shapes,
  `{side} {piece} at {cell}`, `red`, `blue`, `{side}'s attacks:`, the
  payment, the build, the wait, the forge, `taken back`, the reveal, the
  two shot shapes and the three outcomes. `check_translations_game.py`
  exits 0, and so does `check_readability.py`.
- **Types.** `Array[Array]` is used throughout. `[] as Array[Array]` is in
  the squad's `open_turn`. `_last_event.assign(opened[1])` is right for a
  typed array. Every public function the PR adds (`side_word`,
  `news_in_english`) has a doc comment. `_tell` is private and has one too.

## Mutation round

Each fault below was planted alone in the worktree, followed by one run
of the suite named and then a `git checkout`. The five "old behaviour"
plants each word one event at the moment it happens, which is the
behaviour before this PR.

| plant | where | caught by |
|---|---|---|
| attack worded when told (`_tell(Sentence.of(said(told)))`) | `tactical.gd:265` | `test_an_attack_s_news…` |
| build's piece pre-worded (`a_piece`, not `a_piece_sentence`) | `tactical.gd:292` | `test_a_build_s_news…` |
| whole build line `tr().format()` at event time | `tactical.gd:292` | `test_a_build_s_news…` |
| wait worded when told | `tactical.gd:309` | `test_a_wait_s_news…` |
| forge `Sentence.of(tr(…))` | `tactical.gd:324` | `test_a_purchase_s_news…` |
| tower lines worded in `_open_turn` | `tactical.gd:641` | `test_a_tower_s_shot…` |
| `_news_said` maps `Sentence.english` | `tactical.gd:672` | `test_an_attack_s_news…` |
| `_side_piece` side pre-worded (`side_name`) | `tactical_combat.gd:187` | attack scene test; **not** `test_a_kept_news_line…` alone |
| `_side_piece` piece pre-worded (`TacticalStatus.piece`) | `tactical_combat.gd:187` | attack scene test; **not** `test_a_kept_news_line…` alone |
| squad side pre-worded (`side_name`) | `squad_combat.gd:153` | **nothing**: all of `test/squad` green |
| squad outcome pre-worded (`translate("missed")`) | `squad_combat.gd:145` | `test_the_shot_s_news…` |

The task's claim holds: the mid-turn switch test fails on the old
behaviour for each of its five events. The PR's own plant (in `_tell`)
covers four of them. The tower path does not go through `_tell`, and the
tower row above shows that path is held too.

## Findings

1. **Should-fix: `test_a_kept_news_line_nests_its_pieces_and_sides` does
   not hold what its name says.** The test is at
   `godot/test/tactical/tactical_news_test.gd:77-91`. It builds the
   sentence in the suite's starting locale (English), then reads it in
   pt_BR. A side or piece worded at event time in English is "red" or
   "runner", which is exactly the key. `word` then translates it anyway.
   So pre-wording is invisible in this direction: both mutants above pass
   this test alone. Only the attack scene test, in its pt_BR-first
   iteration, catches them.
   *Reproduce:* in `tactical_combat.gd:187` put
   `side = TacticalStatus.side_name(unit.faction)`. Then run only this
   test (rename the others) with
   `make test-godot-some SUITES=test/tactical/tactical_news_test.gd`.
   It stays green.
   *Fix:* build `told` with the locale at pt_BR, then assert that
   `Sentence.english(told)` contains "red runner at" and "blue mortar".
   That is the direction that tells a value from a word chosen too early.
2. **Should-fix: the XCOM shot's side has no test at all.** The test is
   at `godot/test/squad/squad_rules_test.gd:126-140`. It has the same
   direction problem, and the squad has no scene-level switch test to
   back it up. With `side = TacticalStatus.side_name(shooter.faction)` at
   `squad_combat.gd:153`, `make test-godot-some SUITES=test/squad` is
   green. The same holds for `target_side`, `piece` and `target` by the
   same reasoning.
   *Fix:* build the shot's sentence in pt_BR and assert that its English
   contains "red runner" / "blue shield". Alternatively, add one
   `squad_scene_test` case that shoots, switches the locale and reads the
   panel, as `tactical_news_test` does.
3. **Nit: three news lines have no switch test.** They are
   `"{side}'s attacks:"` (`tactical.gd:650`), `"taken back"` (`:347`) and
   `"an enemy came into sight…"` (`:573`). All three use `_tell` or the
   same `Sentence.of` pattern, so the risk is low. The header is the only
   one that carries a nested value (`side_word`), and only
   `tactical_combat_test.gd:248` reads it, in English only.
4. **Nit: `_status_of` uses `status.atr(status.text)`**
   (`tactical_news_test.gd:111-113`). The panel's text is never a whole
   key, so `atr` returns it unchanged. Reading `status.text` says the
   same thing more directly. If `atr` is there because the Label
   auto-translates, a comment should say so.
5. **Nit: `squad_rules_test.gd:140`, `not_contains("missed")`.** It only
   bites if this die roll missed, so the assertion depends on the seeded
   roll. Asserting on `told[1]["outcome"][0]` and its pt_BR wording would
   pin it regardless of the roll.

## For the owner

1. **A fog hole in the news. This PR did not open it and does not widen
   it.** In XCOM mode, a blue piece the person cannot see can shoot, and
   the news names its type and cell. Measured at head 805eb0a:
   `_facing(Vector2i(1, 4), Vector2i(7, 4), SHIELD, MORTAR)` with BLUE to
   move. The red shield sees 5 and the blue mortar sees 6 with a reach
   of 7, so the shot is not refused and
   `SideView.is_seen(state, rows, RED, (7, 4))` is false. The news reads
   "blue mortar at (7, 4) shot red shield at (1, 4): 10% (cover 40),
   missed". `_with_computer_news` (`tactical.gd:645-654`) and
   `computer_status` pass the news through with no fog. T85 made "next"
   say "a piece you cannot see acts" (`squad_status.gd:96`), and the shot
   it then reports tells the person what that piece was and where it
   stood. The line's content is byte-for-byte what main's `told` produced
   before this PR, so the hole is not reopened. A `Sentence` now makes it
   cheap to close: word an unseen shooter as "a piece you cannot see
   shot …" from the person's fog when the line is shown. *Recommended:*
   a follow-up task in `squad`, or the decision that a shot reveals its
   shooter, which would make the line honest.
2. **One sentence a line** (PR body item 1). The reviewer agrees: a join
   key would be a shape-only key with no translation.
3. **The XCOM shot included, and the two new names** (`side_word`,
   `news_in_english`) (PR body items 2 and 3). The reviewer agrees on
   both, with finding 2 applied.

## What was run

- Baseline: `make test-godot-some SUITES=test/tactical/tactical_news_test.gd`,
  6 cases, 0 failures.
- The eleven plants above, each against `tactical_news_test.gd`, against
  one test of it, against `test/squad/squad_rules_test.gd`, or against
  `test/squad`. After each plant, the worktree's `git status` was clean.
- A throwaway case appended to `squad_rules_test.gd` for owner item 1,
  then removed.
- `python3 scripts/check_translations_game.py` and
  `python3 scripts/check_readability.py` both exit 0.
- Whole suites the author already ran were not rerun.

## What was done about them

All five findings were applied on the branch. Owner item 1, the fog hole,
was left alone as the coordinator asked: it is older than this PR.

1. **S1, applied.** `test_a_kept_news_line_nests_its_pieces_and_sides`
   now keeps the line with the locale at pt-BR. It asserts that the
   English contains "the red runner at" and "the blue mortar at", and that
   the pt-BR wording contains none of them. Checked: with `side_name` at
   `tactical_combat.gd`'s `_side_piece`, this test fails when it runs
   alone (the other tests in a scratch copy renamed away).
2. **S2, applied both ways.** `squad_rules_test.gd`'s shot test keeps the
   sentence in pt-BR and asserts the English "red runner at (5, 4) shot
   blue shield at (1, 4)". `squad_scene_test.gd` gains a scene case that
   shoots, switches the locale and reads the panel, both ways. Checked:
   with `side_name` at `squad_combat.gd`'s `side`, both fail.
3. **Nit 3, applied.** There are new switch tests, both ways, for
   "taken back" (a wait, then Z) and for the computer's attacks under
   "{side}'s attacks:" (`tactical_news_test.gd`), and for the line a
   revealing walk leaves (`squad_scene_test.gd`, since a reveal needs the
   XCOM fog). Checked: with `tr()` inside the reveal's `Sentence.of`, the
   reveal case fails.
4. **Nit 4, applied.** `_status_of` reads `Label.text` directly. The
   `atr` was copied from `tactical_reasons_test.gd` and did nothing here.
5. **Nit 5, applied.** The squad test asserts the outcome by its own
   sentence (`told[1]["outcome"]`): its key is one of the three outcomes,
   and its pt-BR wording differs from its English, whatever the die did.
