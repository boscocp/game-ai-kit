# Review: wave/190-unseen-shooter-news

Pull request: #148 (T127, an unseen shooter stays unseen in the news).
Reviewer: a fresh context that did not write the code (invariant 12).
Verdict: changes requested -- no blocker, two should-fix, three nits.

## What was reviewed

- `git diff origin/main...origin/wave/190-unseen-shooter-news` (12 files),
  against the task's Goal, Decisions, Acceptance and the owner's decision of
  2026-11-11: in the XCOM mode, a shot by a piece the person cannot see is
  worded from the person's fog, with no kind and no cell, and the rules and
  the kept line stay as they are.
- Every path that puts a shot's line on screen in `tactical.gd`:
  `_play_computer_decision` -> `_tell` / `_computer_news` ->
  `_with_computer_news` on the person's turn, `_status_text` (person's turn
  and `computer_status`), `announcement` (no news in it), `decision_overlay`
  (English, read by `demo_overlays.gd`, not drawn on screen), `undo` and
  `_act` (a walk does not replace the news). All of them go through
  `_news_said`, which now words each sentence through `view().news_said`
  with `_drawn_fog()`.
- Which fog is read. `_drawn_fog()` gives the computer's fog only while it
  is thinking with V on, and the person's fog otherwise. `_person_fog` is
  `person_side`'s fog, so it stays correct when the person switches sides.
  The scene has one person and one computer, so the "both human" case does
  not come up. `_look()` runs at the top of `_refresh()`, so the fog is
  never stale when the status is worded.
- Cases: red's turn (pt-BR and en, each shown in both), blue's turn with V
  off and V on, a seen shooter, kills (the outcome is about the person's own
  piece, which they know), and a person playing blue. There are no
  reaction shots: overwatch is left out of the mode on purpose
  (`squad_ruleset.gd`). A shot spends its piece, so a shooter cannot shoot
  unseen and then move. If red later walks to see (7, 4), the re-worded
  line names a mortar that is now drawn on the board, which is true.
- Advance Wars: `TacticalModeView.news_said` gives `TacticalStatus.said`
  as before, and its fog is null anyway. Unchanged.
- pt-BR row in `squad.csv` and the re-imported `.translation`.
  `check_translations_game.py` and `check_readability.py` both exit 0 on
  the branch.
- `docs/godot/squad.md` (XCOM source, decision, manual check), the task
  file and STATUS (`wip`).
- Tests: `make test-godot-some SUITES="test/squad"` in a throwaway worktree
  (after `make worktree-setup` and an import): 133 cases, 0 failures, no
  `SCRIPT ERROR`. Then seven mutations, each run on
  `test/squad/squad_unseen_news_test.gd`, restored with `git checkout` after
  each one, with no `SCRIPT ERROR` in any output:

  | mutation | result |
  |---|---|
  | `SquadStatus.news_said` words the whole line | caught (12 failures) |
  | `SquadView.news_said` bypasses `SquadStatus` | caught (12) |
  | `_news_said` always reads `_computer_fog` (wrong side) | caught (12) |
  | `_news_said` always reads `_person_fog` (V on ignored) | caught (1) |
  | `_news_said` hands no fog (null) | caught (12) |
  | `UNSEEN_SHOT` keeps the chance and cover ("10% (cover 40)") | **survives** |
  | `as_seen` recognises only `SHOT_TOLD`, not `FLANKED_SHOT_TOLD` | **survives**, on all of `test/squad` too (133/133 green) |

  The worktree was removed afterwards.

## Findings

1. **should-fix** -- A flanked shot by an unseen piece is not tested. Take
   `FLANKED_SHOT_TOLD` out of the list in `SquadStatus.as_seen`, and all
   133 cases in `test/squad` stay green. Then a flanked shot from the dark
   would name the shooter's kind and cell again, and nothing would notice.
   That is the exact leak this task closes, by its other key. Add a case
   where the unseen shooter flanks its target: a board on which `told`
   returns `FLANKED_SHOT_TOLD`, and the panel names neither the shooter nor
   its cell. Or call `as_seen` directly on a `FLANKED_SHOT_TOLD` sentence
   with a fog that hides the shooter's cell.
2. **should-fix** -- The test does not hold the chance and the cover out.
   The decision as built (task file, `squad.md`, PR body) says the unseen
   line drops them too, because "a mortar's 10% tells you its aim". Put
   "10% (cover 40)" back into the unseen line and the suite stays green.
   `_assert_names_no_unseen_piece` should also check that the status has
   neither the chance (`"10%"`, or the `%` beside the shot) nor the cover
   word, in both languages.
3. **nit** -- `as_seen` tells a shot line apart from other lines by
   comparing its key with two constants. If a third shot wording is added
   to `SquadCombat.told` later, it leaks with no warning. One line on
   `SHOT_TOLD` / `FLANKED_SHOT_TOLD` saying "a new shot key must be added to
   `SquadStatus.as_seen`" would make the coupling visible to a reader. A
   test that runs every key `told` can return through `as_seen` would make
   it fail loudly.
4. **nit** -- The fog is read when the line is shown, not when the shot was
   taken. The PR body explains this well ("Open", second item): a shooter
   red saw at the shot and lost when its target died is worded unseen.
   Nobody will read the PR body later. Put that sentence in `squad.md`
   beside the T127 paragraph, or in the doc comment on `as_seen`.
5. **nit** -- When V is on, a line is worded through the computer's fog,
   and the computer's side cannot see the shooter, the text reads "a piece
   *you* cannot see". There, "you" is the computer's view, not the person.
   As the code stands, this cannot happen: `_hand_to_computer` replaces
   `_last_event` with the opening news, and blue's own shots are always
   seen by blue. So it is a wording note for whoever widens the news later.
   No change is needed now.

Nothing else was found. The fog chosen is the right one in every case
above. Advance Wars is unchanged. The readability rules hold: functions
are short, every new function has a doc comment saying what and why, and
types are static, including the typed lambda in `_news_said`. The
pt-BR row matches the existing shot rows' word order.


## What was done about them

All five were applied on the branch in one commit and one push, on top of
the reviewed head 51abe3e.

- **1.** `SquadCombat.SHOT_KEYS` now lists every key `told` may return,
  and `SquadStatus.as_seen` reads that list instead of its own copy. New
  test `test_every_key_a_shot_is_told_by_hides_an_unseen_shooter` runs
  each key through `as_seen` and `news_said` with the review's shot's
  values and red's fog, in pt-BR and in en. It checks that the result is
  `UNSEEN_SHOT` and names neither the mortar nor (7, 4). The planted
  mutation, `as_seen` recognising only `SHOT_TOLD`, now goes red: 9
  failures.
- **2.** `_assert_names_no_unseen_piece` now finds the unseen shot's line
  in the status and refuses `%`, `cover` and `cobertura` in it. The new
  test applies the same check in both languages. The planted mutation,
  `UNSEEN_SHOT` keeping "{chance}% (cover {cover})" with its pt-BR row
  and the table re-imported, now goes red: 6 failures, with "the unseen
  shot says "%"" and "... "cover"". It was restored and re-imported
  afterwards.
- **3.** A doc comment on `SHOT_KEYS` says a new wording of a shot must
  join the list or it names the shooter again. The test in 1 runs every
  key in the list, and also asserts that the key `told` returns on the
  review's board is one of them.
- **4.** `as_seen`'s doc comment and `docs/godot/squad.md`'s T127
  paragraph now say that the fog is read when the line is shown, not
  when the shot was fired, and what that means for a shooter lost when
  its target died.
- **5.** `news_said`'s doc comment says that "you" is whoever's fog is
  drawn: with V on, the computer's fog, which today never hides a
  shooter.

Re-run after the changes: `make test-godot-some SUITES="test/squad"`
(134 cases, 0 failures, no SCRIPT ERROR), `make lint-translations-game`
and `check_readability.py`, both green. Both mutations were planted,
seen red and restored, and Python's caches were cleared afterwards.
