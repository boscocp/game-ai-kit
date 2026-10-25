# Review: wave/86-double-tap-evade

The owner asked on 2026-10-25, playing `make demo-fighting`, that back
tapped twice evade, as in shipped fighting games, beside O and LB. The same
message reported the guard inverted after changing sides; measured headless
against a jab, the fixed and the learner opponents, crossed over and not,
holding away blocked on both sides and holding toward was hit, and the only
strikes through were lows, landings and jumps. The owner then saw it work:
nothing about the guard was changed.

`FightDoubleTap` turns the second press of back, within 12 frames of the
first, into `FightInput.EVADE` before the frame is logged, so the rules
never learn a double tap exists and every log replays as it did. A fresh
context reviewed the diff and ran `make test-godot-some SUITES=test/fighting`.

**Verdict: fix first**, then merge.

## Findings

1. **A key held through a turn counted as a first tap** (medium): crossing
   over holding forward, the fighter turns and the key is back, read as a
   fresh press; let go and pressed again to guard, it evaded.
2. **The window runs from the first press** (low, design): back briefly,
   then back held to guard inside 12 frames, is an evade.
3. **A punch on the same frame as the second tap is lost** (low): the evade
   wins in `FightInput.pressed`, as O already does.
4. **Readability nits**: `NEVER` undocumented, the scene's header line
   unwrapped, two spellings of a typed `var`.

## What was done about them

1. A turn now takes the held state as it is; the first frame, with no old
   way, is not a turn (the first fix swallowed the first tap, and the suite
   caught it). Test `test_a_key_held_through_a_turn_is_not_a_first_tap`;
   planted, the fix removed, it fails.
2. Named in the class header as the trade-off every double tap makes, and
   pinned by `test_back_then_back_held_inside_the_window_is_an_evade`.
3. Left: the same rule as O.
4. Done.

Run on Windows: `make test-godot-some SUITES=test/fighting`, 150 cases,
0 failures, no SCRIPT ERROR; two more plants (a window a hundred times
wider, back read as forward) each fail a test. Lints readability, modules,
demos, links, docs-freshness, employer-refs, license, tiers, no-training: 0.
`make check-affected` does not run on Windows -- `scripts/affected.py`
spawns `make` through Windows, which cannot find Git Bash's -- and the
Makefile's help line selects the whole `make check`, left for Linux on the
owner's word.
