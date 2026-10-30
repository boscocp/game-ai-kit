# Review: wave/117-the-pad-legend-keeps-its-height

T108: with a pad, a legend's lines ran past the window or over the panel
beside them, and no gate measured how far down a legend goes. The wave adds
that measure to `test-demo-overlays`, with planted cases, and lays out the
five examples it failed, keeping every pad line.

A fresh context reviewed PR #53 at head 6315858. It did not write the code.

**Verdict: changes requested, no blockers.** Two should-fix findings and
five nits. The should-fix findings and three nits were applied on the
branch. Two nits are recorded below as follow-ups.

## What was reviewed

- The diff against main:
  - `Legend.drawn_height()` and `drawn_width()`;
  - the height rule in `godot/test/menu/demo_overlays.gd` (`_why_the_legend_is_too_tall`, `_shown_below`, `_has_pad`) and its four planted cases;
  - the scene changes for the bot match, the infiltration, the maze and both racers, and the racers' `BELOW_LEGEND` placement;
  - `docs/godot/localisation.md`, the STATUS row, and the PR body.
- The claims checked against the code: the numbers each example ends at, and that every pad line is kept.

## Findings

Should fix:

1. **Where the racers' statuses end was ungated.** The status sits `BELOW_LEGEND` under the legend, so the neighbour rule passes it by construction, and its end is no longer measured anywhere.
   - In the 2D racer the Label kept its 488 px box, which at y=288 in pt-BR reaches 776, past the window.
   - "Ends at 684" was one measurement, 12 px from the gutter. A longer state (paused, the place lines, watching) could wrap one more line and nobody would see it.
   - In the 3D racer the status box ran from 226 to 580, and the Trace starts at 528. Nothing measured that either.
2. **Nothing checked that the real scenes with a pad were measured.** `_has_pad` looks at direct children only. If a pad moved elsewhere, its example's legend would silently go unmeasured.

Nits:

3. `_shown_below`'s comment should say that leaving out Controls which start above the legend is deliberate: the racers' background panels.
4. `drawn_height`'s doc should say that it over-counts by about a pixel for a last line with a clear swatch, which is on the safe side.
5. `racing_demo.tscn`'s `Speedo` ends at y=708, past the gutter. This was so before the wave.
6. `_has_pad` needs a line saying why it looks at direct children only.
7. Nothing listens to `joy_connection_changed`, so a pad plugged in mid-game never adds its lines to the legend.

## What was done about them

1. **Applied.** Two gdUnit4 suites, in the modules that own the racers:
   - `test/demo_racing/racing_layout_test.gd`:
     - Both languages, pad planted. It covers racing each of the three levels and watching each, paused or not, each over 300 steps, read every ten.
     - It fails a status whose words (its minimum height, as in T102) end below the gutter. It also holds that the status starts `BELOW_LEGEND` under the legend.
     - Planted case: a 30-line status, which must be reported.
     - The worst case found is 684, in pt-BR while racing. Lowering the limit by 15 px made it fail in six states, so the measure is real.
   - `test/racing3d/racing3d_layout_test.gd`:
     - Both languages, pad planted. It covers measuring and racing (`race.racing` is the only flag the panel reads to choose its lines), watching each car, under the eight settings of the three switches.
     - It fails a status whose words end less than 8 px above the Trace, or a Trace that ends below the gutter. Planted case: a 20-line status.
     - **It found a real overlap.** The racing panel, which the first version never reached, ended at 538 in English and 559 in pt-BR, over the Trace at 528. It was over the Trace before this wave too, at about 476 against 452.
     - The Trace now sits at 568..640.
   - Both status boxes were shrunk so that their rectangles stay inside the room they have: 208..616 for the 2D racer and 166..500 for the 3D racer. A wrapped Label grows to its words, so the minimum height is what the suites measure.
   - The docs and the STATUS row now name these suites instead of one measurement.
2. **Applied.** `HAS_PAD` beside `REQUIRED` names the seven examples with a pad: both racers, the stealth hall, the fighting game, the bot match, the infiltration and the maze. A listed example where `_has_pad` finds nothing fails. Mutation: adding the tactical match, which has no pad, to the list fails with that sentence.
3. **Applied.** The comment now names the background panels.
4. **Applied.** The doc comment now says it over-counts by about a pixel, on the safe side.
5. **Not fixed here; follow-up.** The 2D racer's `Speedo` (652..708) ends past the gutter. It was so before this wave, and no gate measures that Label's box.
6. **Applied.** The comment says why `_has_pad` looks at direct children, mirroring `_why_the_pad_is_missing`.
7. **Not fixed here; follow-up.** A pad connected mid-game adds no lines until the legend is rebuilt by a change of language. Listening to `Input.joy_connection_changed` in each example, or in `PadAsKeys`, would fix it. It is a task of its own.

## Runs

These were green after the fixes:

- `make test-demo-overlays`: 15 examples in English and in pt-BR, 0 failures;
- `make test-locale-screen`;
- `make test-pad`;
- `make test-godot-some SUITES="test/botmatch test/demo_racing test/racing3d test/maze"`;
- `check_readability.py`;
- `make check-affected BASE=origin/main`.

The only `SCRIPT ERROR`s are the planted crash's, three per language.
