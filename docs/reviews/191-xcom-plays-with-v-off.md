# Review: wave/191-xcom-plays-with-v-off

Pull request: #149 (T124, the XCOM mode plays with V off, and teaches with it on)

## What was reviewed

The whole diff of `origin/main...origin/wave/191-xcom-plays-with-v-off`, read
against T124's Acceptance and the owner's decision of 2026-11-11 (the teaching
view is the launch option `make demo-tactical MODE=squad VIEW=teach`; XCOM
starts with V off in play; V still toggles; Advance Wars keeps V on; invariant
13 still held in the teaching view; the card's watch line says how to get
there).

Read: `tactical.gd` (`teaching`, `teaching_asked`, the default set in `_ready`
and in `swap_mode`, `_weighing_drawn` for the board and the overlay),
`TacticalModeView.shows_the_computer_at_start` and `SquadView`'s answer, the
Makefile recipe, `check_demos.py` (the `MODE_RECIPE` group, `offers_a_view`,
`view_findings`, C10 and its three planted cases), `demo_overlays.gd`, the
changed and new scene tests, `squad.md`, the catalogue line and its pt-BR row.
Also read, unchanged by the wave: `SquadStatus.computer_text` (what the status
says on the computer's turn with each fog), `MctsSquad.search_lines`, the
squad controllers' `plan_marks` (none), the menu's argument parsing (ignores
`--view`), `locale_screen.gd`'s XCOM walk.

What the screen shows in play with V off, on the computer's turn: the person's
fog; the next decision clipped to it (`TacticalFog.clipped`); no weighed
options; no plan marks (the squad controllers draw none); the status says
"{side} is thinking with {controller}", the next decision as far as the fog
shows it, and nothing of the search -- the "searched N of" lines, the visit
bars and "the line it expects" are gated on `its_own_view` in
`SquadStatus.computer_text` (that gate predates this wave). Hiding the search
in play is right: `search_lines` names each option by `answer_said`, i.e. by
cells and targets, and the expected line names the pieces' next cells, so it
would place hidden pieces as surely as V on did. In the teaching view the
board opens on the computer's fog with its weighing and search drawn, nothing
pressed (`test_in_the_teaching_view_the_computers_turn_shows_its_view`).

Run in a throwaway worktree of the branch (removed at the end):
`make test-godot-some SUITES="test/squad test/tactical"` 494 cases, 0
failures, no SCRIPT ERROR; `check_demos.py --self-test` 62 cases, 0 failures;
`check_demos.py` ok; `make test-demo-overlays` 0 failures in en and pt_BR, the
only SCRIPT ERRORs the planted `demo_overlays_planted_crash`.

Plants, each restored with `git checkout` after its run:

| plant | caught by |
|---|---|
| `SquadView` answers true (V on in play) | `test_with_v_off_an_unseen_piece_acts_unseen`, `squad_unseen_news_test` (6 failures) |
| `teaching_asked` ignores `--view=teach` | `test_the_teaching_view_is_the_launch_option_view_teach` |
| `_ready` does not set the default | the same two as the first plant |
| `swap_mode` does not reset the default | `test_each_mode_starts_with_its_own_default_for_v` |
| Advance Wars' default follows `teaching` | `mode_view_test`, `test_each_mode_starts_with_its_own_default_for_v` |
| overlay keeps `weighed` without `_weighing_drawn` | `test_in_play_the_computers_turn_shows_the_persons_fog_until_v` |
| board draws weighed over the person's fog | `test_the_enemys_weighing_is_drawn_before_it_acts_and_v_hides_it` |
| `demo_overlays.gd` does not set `teaching` | `test-demo-overlays`: "squad: the overlay carries no score / no chance" |
| C10's call removed, or `offers_a_view` always false | self-test: "a VIEW the card's watch line does not name: expected C10, got 0" |
| the watch line loses `VIEW=teach` (real repo) | `check_demos.py`: C10 demo-tactical |
| the recipe passes `--view=teaching` (real repo) | `check_demos.py`: D3, D9 |
| status shows the search lines with V off | **not caught** (finding 1) |

No SCRIPT ERROR in any planted run except the expected planted crash.

## Findings

1. **should-fix** -- Nothing holds that the search stays off the status in
   play. Planted: `SquadStatus.computer_text` showing `_searched` whatever
   the fog (`if controller is SearchingSquad:`), and
   `make test-godot-some SUITES="test/squad"` stays green (138 cases). With
   V off now the default, that plant puts every searched option's cell and
   "the line it expects" on the status on each computer turn with MCTS or
   expectiminimax -- the same leak the task exists to close, by the status
   instead of the board. The gate predates the wave, but the wave makes
   play-with-V-off the path every person takes. A scene test like
   `test_in_play_the_computers_turn_shows_the_persons_fog_until_v` with C
   (the searcher): in play the status does not contain "searched" (nor
   "the line it expects"), and after V it does.

2. **nit** -- An unknown `VIEW` is silently play. `make demo-tactical
   MODE=squad VIEW=teaching` (or `VIEW=TEACH`) passes `--view=teaching`,
   `teaching_asked` answers false and the person gets V off with no word
   why. Either the scene says so (a printed line naming the one view it
   knows) or the Makefile help says the value is `teach` only. Likewise C10
   checks only that the watch line contains `VIEW=`, not that the value it
   names is one the scene reads; a watch line saying `VIEW=teaching` passes.
   Acceptable as is, worth one line in the docstring of C10 saying so.

3. **nit** -- The Makefile help line says "VIEW=teach opens XCOM with V on",
   but `VIEW` without `MODE` is dropped (`make demo-tactical VIEW=teach`
   opens Advance Wars, V on as always). "with MODE=squad, VIEW=teach opens
   XCOM with V on" says what the recipe does.

4. **nit** -- The teaching view is a property of the process: opened with
   `VIEW=teach`, going back to the menu and opening the tactical card again
   is still the teaching view, and there is no way to reach it from the
   menu without relaunching (the watch line names a terminal command a
   person in the menu may not have). Within the owner's decision; worth a
   sentence in `squad.md` so it is not read as a bug later.

Readability: the new functions are short, typed and each has a doc comment
saying what and why; `_opened(chosen, teaching)` reads well; the three
assert lines per test are plain. pt-BR: "visão de ensino", "desligado
enquanto você joga, para que o turno dele mantenha a sua névoa" read
naturally and match the English; code and the make command left untranslated
as the glossary rule says. Tests moved from V on to the teaching view kept
what they held: the search tests and the weighing-then-V test still assert
the weighed options and the computer's fog, now with no key pressed, and the
unseen-news test lost only the V press that the default now does for it,
with `test_with_v_off_an_unseen_piece_acts_unseen` asserting the default
itself.

Verdict: approve after finding 1; the nits at the implementer's discretion.

## What was done about them

1. **Applied.** `test_in_play_the_status_keeps_the_search_to_itself_until_v`
   (`godot/test/squad/squad_scene_test.gd`): with MCTS (C once) and with
   expectiminimax (C twice), in play the status holds no "searched", no
   bar ("█") and no "the line it expects"; after V it holds "searched".
   The review's plant -- `SquadStatus.computer_text` showing the search
   whatever the fog (`if controller is SearchingSquad:`) -- turns it red
   (`make test-godot-some SUITES="test/squad/squad_scene_test.gd"`: 16
   cases, 4 failures, all in that test); the plant was then restored.
2. **Applied, half each way.** The scene refuses an unknown view aloud:
   `TacticalGame.unknown_view` names a `--view=` that is not
   `TEACHING_VIEW`, and `_ready` `push_error`s it, saying the only view is
   `--view=teach` and that it opened in play; a scene test holds
   `unknown_view`. C10 still checks only that the watch line names
   `VIEW=`: holding its value against what the scene reads would make the
   gate parse GDScript for a constant, out of proportion for one view.
   `check_demos.py`'s docstring now says so.
3. **Applied.** The Makefile's help line reads "with MODE=squad, VIEW=teach
   opens XCOM with V on".
4. **Applied.** `docs/godot/squad.md`: the teaching view lasts the process,
   returning to the menu keeps it, the menu has no way to it, relaunch to
   leave or reach it; and an unknown view opens in play with an error.

Rerun after the fixes: `make test-godot-some SUITES="test/squad
test/tactical"`, `check_demos.py` and `--self-test`, `make
test-demo-overlays`, `check_readability.py`, `make lint-tasks lint-status`.
