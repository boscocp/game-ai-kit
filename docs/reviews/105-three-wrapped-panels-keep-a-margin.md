# Review: wave/105-three-wrapped-panels-keep-a-margin

T107: the three wrapped Labels that T102's check named in `NOT_YET_FITTED`
now end the gutter above the window's bottom, in English and in pt-BR. They
are the behaviour demo's status, the skirmish's status and the RTS card's
info. Each one is measured over states reached by playing, by a layout test
in its own module, and the list is left empty.

A fresh context reviewed PR #44 at head d8f5506.

**Verdict: no blockers.** Two should-fix findings and six nits. Everything
that called for a change was applied on the branch.

## What was reviewed

The diff against main:

- the behaviour demo's status font and its doc comment;
- the skirmish's status: its font, and the column move in `main.gd`;
- the RTS card's info, which widens when there are no buttons;
- the three new layout tests and `main_scene_test.gd`'s placement check;
- `NOT_YET_FITTED`, emptied, and its comment;
- the T107 section of `docs/godot/localisation.md`, and the STATUS row.

The reviewer probed the engine on its own, and ran its own planted strings
through the tests.

## What the reviewer found sound

- **Each fix holds a test.** Reverting any one of them alone turned its
  test red:
  - the behaviour font back to 16 px: y=711, 8 failures;
  - the skirmish's column move removed: 717 in pt-BR, and
    `main_scene_test.gd` red;
  - the RTS widening removed: 721 in English, 741 in pt-BR;
  - the RTS test's frame wait removed: 721 and 741 again.
- **Longer pt-BR strings are caught.** Planted ones failed the tests at 717
  and 721.
- **The behaviour status's zero-pixel margin is honest.**
  - The board ends at 624 and the status starts at 636.
  - The status is always three lines, in the default embedded font, and
    ends at exactly 696.
  - One line more ends at 717, and the test fails.
- **The skirmish test is deterministic.** The same game is played on every
  run.
- **The RTS card's `Why` at 695 is a structural maximum.** It is five
  reasons under one row of buttons, and a box over your units never gives
  two rows.
- **The RTS `Thinking` panel, outside the task, fits.** The reviewer probed
  it at 463 and 483.
- **`main_scene_test.gd` still means something.** It still finds the status
  and the legend inside the window, off the board and beside it.

## Findings

1. **The Godot note named the wrong mechanism** (should-fix). The docs and
   the RTS test's comment said a wrapped Label is reshaped a frame late.
   - The reviewer's probe on 4.7.2 (a wrapped 12 px Label) showed the Label
     is reshaped at once. What lags is Control's cached combined minimum
     size:
     - width 330 -> 748 in the same frame: `get_combined_minimum_size().y`
       217 (stale), `get_minimum_size().y` 97;
     - the next frame: both 97;
     - a font change from 12 to 16 px: stale for a frame too;
     - a text change: both right in the same frame.
2. **The column move was written twice** (should-fix).
   - `main.gd`'s `_give_the_status_its_column` copied the tactical match's;
     only the top differed.
   - These are the only two callers of `BoardLayout.lay_out`, and both
     overrode where it put the status.
   - `BoardLayout`'s own header still said everything sits level with the
     board, and that it exists because "a copy is two layouts that drift".
3. **The skirmish font could be larger** (nit). Invariant 1 says
   readability wins.
   - With the column move, the wave's own test passes at 16 px: 671 in
     pt-BR and 593 in English, 25 px spare.
   - 18 px fails (833 / 717).
   - 14 px without the move fails (717).
4. **Two width checks could not fail** (nit).
   - `rts_layout_test.gd` measured the info at mount only, and it ends at
     960 of 1280.
   - `skirmish_layout_test.gd` measured the same way.
5. **`INFO_WIDTH = 330` repeated the scene's `offset_right = 330`** (nit).
6. **`NOT_YET_FITTED`'s ceiling had no planted case** (nit). Once the list
   was empty, no plant reached the "a panel named here that gets lower
   still fails" path. The too-tall plant was also blunt: 200 lines past the
   window.
7. **Tests reach private members** (nit, noted only).
8. **Out of scope.** The RTS header (12 px, not wrapped) reaches y=38 on the
   opening screen, and the map starts at y=32. This is for the manual
   check, not this wave.

## What was done about them

1. **Measured, then reworded.** The 4.7 Control page says
   `get_combined_minimum_size()` combines `custom_minimum_size` with
   `get_minimum_size()`, and `update_minimum_size()` "invalidates the
   minimum size cache".
   - A probe of the wave's own reproduced the reviewer's pattern:
     - widened: combined 317, own 137, then both 137 a frame later;
     - 12 -> 16 px: combined 137, own 257, then both 257;
     - a text change: both right at once.
   - `docs/godot/localisation.md` now says so, with the Control page in its
     sources, and the RTS test's comment says the same. The frame wait
     stays.
2. **`BoardLayout.lay_out` takes the status column's top.**
   - The tactical match passes its header's top, and the skirmish passes
     the gutter.
   - Both private copies are gone.
   - `BoardLayout`'s header now describes the column and why: in both
     scenes, a status level with the board ran off the window over a
     played game.
   - The tactical suites pass unchanged.
3. **The skirmish status is 16 px.** Rerun: 671 in pt-BR, 593 in English.
   The docs and STATUS say the column move is what makes the room, and 16
   is the largest size that fits.
4. Both width checks are dropped.
5. The card reads the info's width from the scene in `_ready`.
6. **The plants are sharper, and one is new.**
   - The too-tall plant now ends 4 px past the gutter: its
     `custom_minimum_size` is a 40 px box placed to end there.
   - A new plant ends 2 px under a ceiling it is given as if
     `NOT_YET_FITTED` named it.
   - Two mutations were tried:
     - reading a named panel's ceiling as an exemption: the ceiling plant
       was caught;
     - letting words run 5 px past their limit: both plants were caught.
   - The check passes again on the restored file. The `locale_screen.gd`
     edits are kept small: one variable, one lookup and the plants.
7. No action.
8. Added to the PR's `## Manual check`, with the other things the reviewer
   asked a person to look at.

## The reviewer's runs

- `make test-godot-some` over the touched suites: 96 cases, 0 failures.
- `make test-locale-screen`: 15 examples, 0 failures.
- `make test-demo-overlays`: 14 examples in each language, 0 failures. The
  SCRIPT ERRORs were the planted `free` ones only.
- The lints, and the probes above.

## Open for the owner

Decided by the owner, 2026-10-29: as recommended. The skirmish's
status runs the whole left column at 16 px, the behaviour demo's at 13 px.

The skirmish's status no longer starts level with the board, where T8 put
it. It now runs the whole left column, as the tactical match's has since
T102, and that buys 144 px. The reviewer is in favour. The owner decides,
looking at it windowed in both languages.
