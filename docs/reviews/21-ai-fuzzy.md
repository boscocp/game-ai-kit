# Review: wave/21-ai-fuzzy

Two fresh contexts reviewed it, one per language. Neither wrote the code, and
both were asked to mutate it rather than read it. Between them they reported
twenty-two findings, and every confirmed one came with the input or mutation
that showed it. The Python reviewer also recomputed all thirty vector
numbers in exact fractions, independently of the oracle that wrote them.
Every one matched.

## What was reviewed

Commit 06db159 on this branch:
- `godot/addons/ai_fuzzy/` (five files);
- `python/gameaikit/fuzzy/` (the same three steps, the text reader, a
  terminal plot);
- the three vectors in `spec/vectors/fuzzy/` with both halves of their
  runner;
- `docs/adr/0011`;
- the four new test files.

## The finding that matters most: the task's premise

T13 says to port the author's Python fuzzy library. **The library is C#, and
the class that does the work is not in the repository.** `Program.cs` calls
`ControleFuzzy`, and no file defines it. This was found before any code was
written, and ADR 0011 records what carried over.

The ADR then made three claims about the old library that review showed
were wrong:
- "one commit" -- there are ten, all on one day;
- a misspelt set "dropped" the rule -- the reader skipped the *condition* and
  kept the rule, which made the rule broader;
- the reader was "working code" -- it cannot compile, because it builds the
  missing class.

A description of someone else's code needs checking against that code, in
the same way wave 20 found that a summary of sources needs checking against
the sources.

## Findings

### The runner could skip the claim T13 asks for, and exit 0

`FuzzyVector` checked that `activations` was a dictionary, but not that each
output's entry was one. Write `"alertness": 5` there and the check aborted
part-way through that case, with a script error. The case's own answer went
unchecked, and so did every `between` that named it, and the run still
reported `0 failure(s)`. **Fixed**: every claimed number is type-checked
(a degree, a strength, an answer, or `null` where NaN is meant), and there
is a planted case for each. Also refused now:
- a word where a number belongs (`float("zero")` is 0.0, so a word would
  have read as an answer of nought);
- a `null` among a set's points (it became 0.0);
- fractional `samples`;
- a variable with no name.

**Unknown keys are refused on both sides.** A case carrying `"betwen"` used
to drop the strictly-between claim while every number in the file still
passed.

### NaN in, a confident answer out

`clampf(NAN)` stays NaN, `maxf(0, NAN)` spreads it, and `minf(NAN, d)`
returns `d`. So in GDScript, `evaluate({"noise": NAN})` answered **50.0**.
Python, on the same input, divided by zero on a shoulder. The two sides
disagreed, and both contradicted their own doc comments. **Fixed**: an input
that is missing, not a number, or not finite is refused before any of that.
Python raises `F8`; GDScript returns an empty `fuzzify`, so every output is
NaN.

### A NaN that claimed no rule had fired, when one had

An output set lying outside the range, or narrow enough to fall between two
sample points, can be concluded at full strength and still add nothing to the
pile. The answer was then NaN, which everywhere else here means "no rule
fired". **Fixed**: both sides refuse such a set (`F3`).

### The strictly-between claim was held less tightly than it read

- Python only counted the claims. It deleted fine.
- `assertLess` could be weakened to `assertLessEqual` and stay green.
- The line calling the check could go.
- The guard's claim was measured against the wrong two cases: the calm
  rule's answer and the alarmed rule's, when the rules actually firing are
  alarmed and suspicious.

**Fixed**:
- The T13 case is now asserted by name.
- There is a planted case at the call site as well as in the helper.
- The guard vector has a `suspicious-only` case to measure against.

### Rules deletable with every gate green

**GDScript** -- each of these could go:
- the controller's checks of its own inputs and outputs (F1, F2 and F3 were
  tested only on the parts);
- the `is_inf` refusal;
- the count of points (a second rule hid it, so the test now matches the
  sentence);
- an evaluate case missing its activations;
- reversing a `between` pair;
- a non-string name;
- a tolerance 100 000 times looser (there is now a planted answer one part
  in a million off).

**Python** -- each of these could go:
- five of the text reader's refusals, three of which were passing because a
  *different* refusal with the same `F9` fired;
- every `except` in the JSON reader;
- every exit path in `plot.py`.

All of these now have cases. The reader's tests match each refusal's
sentence, and its fixture refuses a substitution that would match twice:
`RANGE = 0,10` had been editing `RANGE = 0,100` as well.

After the fixes, **19 GDScript and 24 Python mutations were re-run**,
covering every survivor both reviewers reported and each new rule. Two
GDScript mutations survived the first re-run: deleting the controller's
output check was hidden by the new sampling check, which also answers `F3`
when there is only one sample. The test now matches the sentence, and both
go red.

### The text reader accepted what it said it refused

It accepted:
- `SAMPLES = 2.9` (as 2) and `SAMPLES = 5,6` (as 5);
- a repeated `RANGE`;
- `SAMPLES = 1,2,3` in an input, which became a *set* named `SAMPLES`;
- words after `END`;
- any text before a rule's `=`;
- a set with an empty name, or a space in it.

`int()` let `nan` and `inf` escape as bare `ValueError` and `OverflowError`.
**Fixed**, every one with a test. Numbers are matched by a pattern now,
rather than by `float()`, which would also read `nan`, `inf` and `1_0`. A
rule naming an unknown set reports the file's line rather than the rule's
index.

### GDScript claimed immutability it did not have

The problem was computed once, at construction, and the arrays are public.
Append a rule naming a set nobody declared, and `problem()` went on saying
`""`. **Fixed**: it is found afresh on every call, at about the cost of one
evaluation.

### Smaller

- `FuzzyRule`'s header had no complexity line.
- `strength` with no conditions returned null from a `-> float`.
- The README listed codes `F1`–`F8` as shared, when GDScript has no `F8`.
- A Python JSON-reader code meant something different from the same code in
  the controller; it is `F0` now.
- `plot.py` silently ignored a held value naming no input.
- A dead parameter.

All fixed.

## What was done about them

Every confirmed finding above is fixed in the commit that follows this record,
and each section says how. The check on the fixes was the same one the
reviewers used: plant the mutation or feed the input that showed the
finding, and watch it go red. 19 GDScript mutations and 24 Python ones were
run that way. The five malformed vectors the GDScript reviewer built now
each exit 2 with one coded sentence, and with no engine error before it.
`make check` is green.

### Recorded, not fixed

- **No upper bound on `samples`.** `SAMPLES = 1000000000` reads fine and
  makes every evaluation a billion steps. A limit would be a number nobody
  derived. It is the controller author's to choose, and it is printed in
  the controller.
- **GDScript's `F8` is not a code.** GDScript has no
  exceptions, so a missing input is an empty `fuzzify` and NaN outputs rather
  than a coded refusal. That is documented, not unified.

### Not proven

- **The manual check is a person's.** Plot the guard and look at the curve:
  `PYTHONPATH=python python3 -m gameaikit.fuzzy.plot spec/vectors/fuzzy/the-guard.fcl distance light=0.9`.
  `test_the_guard_slopes_rather_than_steps` holds the half a command can.
  The largest step between samples a twentieth of a cell apart is 0.93, and
  a planted winner-take-all defuzzifier fails it.
- **Nothing is profiled.**
- **No fresh context reviewed the fixes in this record.** Each was checked
  by planting the mutation it answers and watching it go red, which is what
  the last three waves did too, and each of those waves found that the fixes
  needed reviewing as much as the code.

## A trap worth knowing

A gdUnit suite with a helper named `_set` does not parse:
`Object._set(StringName, Variant) -> bool` is an engine virtual, and the
override check fires during test discovery. The helper is `_term` now.
