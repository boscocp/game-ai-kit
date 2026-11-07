# Review: wave/160-a-hit-chance-does-not-cover-the-piece-s-number

T137 moves the squad mode's hover hit chance out of the corner where the
piece's id sits. The chance is now written "55%" in the top-right corner.
The Advance Wars count stays where it was. A new test,
`godot/test/squad/squad_corners_test.gd`, checks that each number's box is
clear of the others.

A fresh context reviewed PR #114 at head c29fd99. **Verdict: approve after
finding 1: one should and two nits, plus one finding that needed nothing.**

## What was reviewed

- The PR title and body, and the task file with its decisions.
- `UnitView`: the named corners `HEALTH_AT` and `ID_AT` (same pixels as
  before) and `text_box`.
- `TacticalModeView.tint_is_a_chance` and `SquadView`'s override.
- `IntentView`: `show_threat`, `tint_label`, `chance_at`, and the
  `_draw_threat` and `_draw_weighed` drawing code.
- The two call sites in `tactical.gd` (lines 190 and 779).
- The new suite and its planted case. Mutants were run against it.

## Findings

1. **Should.** The Advance Wars test called `show_threat` directly and never
   went through `tactical.gd`'s two call sites. A mutant passing `true` at
   both sites survived all 470 cases.
2. **Nit.** `text_box` ignores the 4-pixel outline both numbers are drawn
   with. The current table still passes with 1 pixel to spare, but the
   comparison should include the outline.
3. **Nit.** During the computer's turn with T on, a weighed option's score
   label (top centre) can meet the new top-right chance on the computer
   piece's own cell. This is not a regression, because at the bottom the
   chance could meet the option's own chance label. Note it in the task
   file.
4. A fourth finding needed nothing.

## What was done about them

1. The test now runs the scene's real path in Advance Wars mode: with
   `_showing_threat` on, it calls `_refresh()` and then `point_at`. After
   each call it checks that the tint is not a chance, and that every
   threatened cell's label is its count, with no "%", at the hard-coded old
   place `corner + (side - 12, side - 4)`. Each call site was mutated to
   `true` separately: line 779 failed the suite (exit 2), and so did
   line 190 (exit 2). Both were restored.
2. `_assert_apart` grows both boxes by 2 pixels (`OUTLINE`, half the
   outline) before it compares them. The planted old corner is still
   caught.
3. The task file's manual check now says to watch an enemy turn with T on
   and the cursor on one of its pieces. Its Notes record the possible
   clash.
4. Nothing.
