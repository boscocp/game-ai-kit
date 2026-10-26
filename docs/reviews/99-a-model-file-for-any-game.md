# Review: wave/99-a-model-file-for-any-game

T106: `ai_learning`'s `ModelFile` stops requiring the tactical game's four
`feature_conventions`. It checks what every model file has, and hands the
other top-level fields over unread in `extra`. The tactical game checks its
conventions itself, in `TacticalWeights`. A Python twin,
`gameaikit.training.model_file`, writes and refuses the same format.

A fresh context reviewed PR #39 at head 735809d.

**Verdict: no blockers.** Four should-fix findings and several nits. Every
one was applied on the branch.

## What was reviewed

The diff against main:

- `ModelFile` and the new `TacticalWeights`, with every tactical and
  skirmish reader that now takes it;
- the Python writer and its refusals, and `report.py`'s use of them;
- the 19-case `spec/vectors/model_file/` and both suites that read it;
- the technique page in both languages, `docs/godot/learning.md` and ADR
  0007;
- the manifests and the regenerated catalogue;
- the task file and the STATUS rows.

The reviewer ran every vector case through both languages and compared the
codes.

## What the reviewer found sound

- **Invariant 2 holds.** The addon names no game. `extra` is a deep copy, so
  a reader changing it cannot reach back into the data, and it is the only
  seam between the addon and the game.
- **Invariant 6 holds.** Nothing about inference changed. `weights.json`
  regenerates byte for byte, so no field was added and nothing was
  retrained.
- **Behaviour is unchanged.** The tactical game refuses the same files it
  refused before, now in its own layer, and loads the same models.
- The codes match on all 19 vector cases.
- `checkers.json` keeping `ai_learning` is right. The checkers trainer
  imports `gameaikit.training`.

## Findings

1. **`NaN` and `Infinity` (should-fix).** Python's `json.loads` accepts them
   by default, so Python gave M8; Godot's parser refuses them, so Godot gave
   M2.
2. **An integer too big for a float (should-fix).** `1` followed by four
   hundred zeros made Python's `math.isfinite` raise `OverflowError`, where
   Godot reads infinity and gives M8. `report.findings_for` crashed on such
   a report instead of refusing it.
3. **The task file was stale (should-fix).** Its Goal and step 5 still said
   `checkers.json`'s `ai_learning` was wrong and would move to
   `tests_depend_on`. The wave measured the opposite: `train.py:36-37` and
   `report.py:23` import `gameaikit.training`, and `lint-modules` (M3)
   requires the dependency. The task also did not mention the skirmish
   change.
4. **W6 differed between the languages (should-fix).**
   - Godot accepted a whole-valued float such as 2.0; Python accepted only
     `int`.
   - Python walked the conventions sorted by name; Godot walked them in
     `REQUIRED_CONVENTIONS` order.
   - Nothing shared held the two sides together.
5. **Nits.**
   - M6 on `["a", "a", 1]`: Godot said "listed twice", Python "not a
     string". Python checked every name's type before looking for repeats.
   - A parse error's line: Godot's `get_error_line()` counts from 0, Python
     from 1.
   - The "a wrong claim is caught" tests never fed a wrong claim through
     the comparison.
   - Missing vector cases: a bad second model, a bool among the weights,
     and a kind that is not a string.
   - `chance_example.gd` called `chance_to_win` on a null model when its
     file was refused. Readers copy this example.
   - `cloned_player.gd:33` still tells the reader to `run make train-clone`,
     the same tie to this kit that M1 had.
   - The page said "the catalogue (T76, coming)" in both languages.

## What was done about them

1. Python reads JSON with a `parse_constant` that refuses `NaN`,
   `Infinity` and `-Infinity`, so both sides give M2. A text case for each
   was added to the vector.
2. `_is_a_number` converts to `float` first and treats `OverflowError` as
   "not a number", so both sides give M8. A text case was added to the
   vector. `test_training` plants the integer in a report and checks that
   `findings_for` returns an M8 finding instead of raising.
3. The task file's Goal records the reversal with the measured lines and
   M3, and the skirmish change. Step 5 says what the manifests now are.
4. W6 now agrees on both sides:
   - Python's W6 accepts a whole-valued float. An integer too big for a
     float is not whole on either side.
   - Python walks `FEATURE_CONVENTIONS` in declared order, the order of
     `REQUIRED_CONVENTIONS`.
   - Python's "no block" sentence now matches Godot's.
   - A new shared vector, `spec/vectors/tactical_conventions/` (13 cases,
     owned by `tactical`), claims the code and, for a W6, the convention
     named first. `test_training` and `learning_test.gd` both read it.
5. The nits:
   - Python walks the feature names once, in order, like Godot. Both suites
     hold that case to its sentence.
   - Godot adds 1 to the error line, and a test in each language expects
     "at line 3".
   - The wrong-claim tests now put a wrong code, wrong model names and
     wrong fields through the comparison, in both languages and for both
     vectors.
   - The three missing cases, plus the M6 order case, are in the vector
     (26 cases).
   - `chance_to_win` answers NAN when there is no model, with a test. The
     page's example block is re-pasted in both languages and
     `translation_of` recomputed.
   - The `ClonedPlayer` C1 sentence is recorded as a STATUS follow-up for
     T64. It is not changed in this wave.
   - The page links the catalogue in both languages.

A second mutation round covered the new rules. Each mutation broke one rule
and the suites had to fail:

- `parse_constant` dropped;
- the overflow guard dropped;
- the type check moved back in front of the repeat check;
- W6 back to `int` only;
- W6 sorted;
- W6 accepting a fraction;
- Godot's line counted from 0;
- the example's null guard dropped.

Every one of the eight was caught. The first round's 21 GDScript and 16
Python mutations still apply.
