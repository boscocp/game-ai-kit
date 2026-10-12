# T13 — `ai_fuzzy`, from a library that already exists

Size: M · Prereqs: T2 · Files: `godot/addons/ai_fuzzy/`, `python/gameaikit/fuzzy/`

## Goal

Fuzzy logic, which game AI uses constantly and teaching material covers almost
never. The author has already written a fuzzy library in Python
(`github.com/boscocp/Fuzzy-library`); this task ports it rather than inventing
it again, which also means there is no licence question to answer.

The lesson it teaches is one booleans cannot: a guard is not "alerted" or "not
alerted", and writing it as a boolean is where that AI starts feeling stupid.

## Steps

1. Read the existing library and decide, in writing, what carries over. A port
   is a chance to drop what did not earn its place, and a port that copies
   everything is a vendoring with extra steps.
2. The Python half stays Python, standard library only — tier 1 reads it and
   runs it with no install step. The GDScript half is inference only, which is
   invariant 6 in a different costume.
3. Membership functions, a rule base, and defuzzification. Each in its own
   file, each readable beside the textbook, each with the complexity and the
   "when not to use it" its header owes the reader.
4. **When not to use it** is the hard half of this header and must be real: a
   fuzzy controller with twenty rules is a system nobody can predict, and a
   decision tree is clearer whenever the inputs are genuinely discrete.
5. Conformance vectors in `spec/vectors/fuzzy/`, so the Python and the GDScript
   are held to the same numbers. The runner from T3 is the model.

## Acceptance

```bash
make test-godot
make test-python
make test-vectors
python3 scripts/check_addon_deps.py
```

```bash
grep -c "func test_" godot/test/fuzzy_test.gd | grep -qvx 0
test -d spec/vectors/fuzzy
```

The vectors must include a case where a rule base with overlapping rules
produces a value strictly between the two rules' outputs — which is the whole
of fuzzy logic in one number, and the thing a broken defuzzifier gets wrong.

## Manual check

Plot one controller's output across its input range and look at the curve. A
fuzzy controller that steps rather than slopes has a bug, and the plot is where
you see it.
