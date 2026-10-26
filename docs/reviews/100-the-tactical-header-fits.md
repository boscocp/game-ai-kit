# Review: wave/100-the-tactical-header-fits

A fresh context reviewed T102 and the difficulty levels' words at
fa7a8c8 + 5c627e3 (PR #37). That head had:
- the tactical header wrapping at 13 px over the whole width;
- the status at 13 px, with the controllers' line moved to `Interface/Keys`;
- `test-locale-screen` measuring a wrapped Label whole;
- `DifficultyWords`;
- T105, renumbered T107 before the review.

**Verdict: one blocker, one should-fix and three nits, applied before the
merge.**

## Findings

1. **The status fits only on the opening screen** (blocker, invariant 13).
   - `tactical_layout_test.gd` measured round 1 with no decision played.
   - The reviewer's probe played whole games per controller with
     `step_decision()`, picking up the person's units. It recorded the
     lowest status word, against a limit of y=696.
   - The computer's turn, planner, round 3: y=771 in English, 834 in
     pt-BR. That turn shows a strike's news, a long "stays: no walk this
     turn..." reason, "4 decision(s) played" and six plan steps. Plan
     steps 5-6 and the legend line for the board's numbers ran off the
     window.
   - The person's turn, a unit in hand under "blue's attacks": y=708 in
     English; 708 and 750 in pt-BR.
2. **The header's width check could never fail** (should-fix).
   - `_right_of` returned `get_global_rect().end.x`, which is always 1256.
   - With the old header (16 px, no wrap) put back, the whole file passed.
3. **Two checks compared constants** (nit). "Status ends left of the
   buttons" was 280 against 464, and "header above the buttons" was as
   loose.
4. **`NOT_YET_FITTED` had no ceiling** (nit). An exempted panel could get
   worse without a sound. The RTS card cuts a line in pt-BR (741) and is
   1 px out in English (721), so T107 should come soon.
5. **Out of scope, to note** (nit).
   - In pt-BR the plan shows its steps in English (`buy_the_forge`).
   - All three difficulty presets say "plans 0 actions ahead": is that the
     data, or a fault of `describe()`?

Sound, by the reviewer's reading:
- No line of decision information was dropped. The keys line only moved,
  and the plan, the reason and the news are still in the status.
- The header was 34 px clear of the board at that head.
- The keys line ends inside the window, under the buttons.
- A missing node is an error: `test-locale-screen` requires
  `Interface/Keys`.
- The wrapped-Label check's mutations were killed: each branch disabled,
  and the old header put back.
- `DifficultyWords`' mutations were killed: a planted field, and a
  reworded `describe()`.
- L8 holds. "easy", "normal" and "hard" say the same in every table.
- The behaviour is unchanged: `test-decisions` and the tactical suites
  play the same.

## What was done about them

1. **The test plays games, and the status has the whole left column.**
   - **The test.** `tactical_layout_test.gd` plays ten rounds of a seeded
     game under every controller, in both languages, twice:
     - the person waiting;
     - the person sending each unit at the nearest enemy (a strike, or a
       refusal).

     It keeps the lowest the status's words go at every computer decision
     and with each of the person's units in hand. The controller is built
     with seed 0, not C's `randi()`, so the game is the same every run.
     With the first layout it found the reviewer's numbers: 771 and 834
     for the planner, and 708 for rules in pt-BR.
   - **The layout.** The header moved over the board and the legend only
     (x=304..1256, 12 px). The status now runs the whole left column, from
     y=8 to the gutter. That gives it 136 px, without hiding anything and
     without a scroll. The current plan step and the ones after it stay in
     view at a glance, as the reviewer preferred.
   - **Considered and not taken:**
     - Collapsing done steps changes `plan_lines()`, which the console and
       the overlay share.
     - A plan panel under the legend has about 100 px; the plan needs 230.
     - A ScrollContainer hides what comes next.
   - **Blank lines.** On the computer's turn one blank line is kept, before
     the decision. The news and the plan lost theirs.
   - **Worst now:** y=656 (planner, round 3, pt-BR) and 593 in English,
     against 696. The header ends at y=125 at worst (learned policy, pt-BR),
     19 px above the board. The keys line ends at 689.
   - **Mutations.** With the status put back level with the board, the
     test fails at 729 and 792. Old header: x=2309.
   - `docs/godot/localisation.md` and the STATUS row now say what is
     measured: ten rounds, two ways of playing, every controller. Longer
     games, or a person who walks, are not measured.
2. **`_right_of` is the words' width.** It is the position plus
   `maxf(size.x, minimum width)`. With the old header (16 px, no wrap) put
   back, the test fails at x=2309.
3. **The constant comparisons are gone.**
   - The buttons test was dropped. The header is above the board, which is
     above the buttons, and the keys line's test already holds its place
     under them.
   - The header now must start right of the status column, which it shares
     the top of the window with. Widening it fails.
4. **`NOT_YET_FITTED` is "scene:node" to the y measured.** That y is a
   ceiling: lowering the RTS card's to 740 fails the check at 741. T107
   now says that the RTS card cuts a line and should be done soon.
5. **Noted in `docs/godot/localisation.md`:**
   - **The step names.** The glossary
     (`docs/techniques/glossary.pt-BR.md`) lists plan steps
     (`build_ram`, `cross_the_river_ram`) as kept with the code's name.
     They stay English by design.
   - **"plans 0 actions ahead".** That is the data: every preset's
     `plan_horizon` is 0, no plan at all, because a plan was measured to
     make a side weaker on this board (`Difficulty.presets()`). It is not
     a fault of `describe()`.

Re-run after the fixes, under `LANG=en_US.UTF-8` and `LANG=pt_BR.UTF-8`:

| Command | Result |
|---|---|
| `make test-godot-some SUITES="test/tactical test/locale test/ai_planning"` | 411 cases, 0 failures, no SCRIPT ERROR; the game-playing layout test included |
| `make test-locale-screen` | 15 examples, 0 failures |
| `make test-demo-overlays` | 14 examples in en and in pt_BR, 0 failures; the 6 `free` SCRIPT ERRORs are the planted crash |
| `make test-decisions` | 3 played, 0 failures |
| `check_translations_game.py`, `--self-test` | 0, ok |
| `check_readability.py`, `make lint-modules lint-tasks lint-status`, `catalogue.py --check` | green |
