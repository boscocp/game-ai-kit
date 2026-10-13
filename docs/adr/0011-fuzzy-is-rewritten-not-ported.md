# 0011 — `ai_fuzzy` is rewritten from the old library, not ported

Status: accepted · 2026-10-13 (decided in T13)

## Context

T13 says the author already has a fuzzy library "in Python", that the task
ports it rather than inventing it again, and that this means there is no
licence question. Reading the library at
[github.com/boscocp/Fuzzy-library](https://github.com/boscocp/Fuzzy-library)
(one commit, July 2020) showed that two of those three claims were wrong:

- **It is C#, not Python.** The README says it was written to teach AI in
  Unity.
- **The algorithm is not in the repository.** `Program.cs` calls
  `Fuzzification`, `FuzzyInference` and `GetDefuzzification` on a class
  called `ControleFuzzy`, and no file defines that class. What is published
  is three data classes (`TermFuzzy`, `VarFuzzy`, `RuleFuzzy`), a reader for
  a text format (`FuzzyReader.cs`), and an example file (`FLC.txt`). As
  published it does not compile.
- **The licence claim holds**, for a narrower reason than the task gives.
  The repository has no licence file, so nobody else may copy it. The author
  of that repository and of this one is the same person, and that is why
  carrying it into an Apache-2.0 project needs no permission.

So "ported, not reinvented" was not possible. Membership, inference and
defuzzification are written here for the first time.

## Decision

What carries over is what the old library decided:

- **Three points make a triangle, four a trapezoid.** `TermFuzzy` held a list
  of numbers and the README names those two shapes. Here both are one shape,
  a trapezoid, and a triangle is a trapezoid with a top one point wide. A
  shoulder is a trapezoid with a vertical edge, so it needs no third kind.
- **Rules join their conditions with AND or OR**, as `RuleFuzzy` did.
- **The centroid** ("center of mass" in the README) is the only
  defuzzifier.
- **The text format** of `FLC.txt`: blocks named `VAR_INPUT`, `VAR_OUTPUT`,
  `FUZZIFY`, `DEFUZZIFY` and `RULEBLOCK`, with a set written as
  `name = 0,15,25,32`. The Python reader in `gameaikit/fuzzy/fcl.py` reads it.

What does not carry over, and why:

- **Mixing AND and OR in one rule.** `RuleFuzzy` kept a list of operators
  between its conditions, and nothing said which one binds tighter. Here a
  rule has one connective. Two rules say the same thing without the
  ambiguity.
- **Carrying on past an error.** `FuzzyReader` printed `Key = ... is not
  found` and kept reading, so a rule with a misspelled set was dropped and
  the controller still evaluated. Every error is a refusal with a line
  number now.
- **Mutable degrees stored on the terms.** `TermFuzzy.SetPertinence` wrote
  each evaluation's result into the controller's own data, so a controller
  could not be asked two questions at once and an old answer could leak into
  a new one. Here evaluation returns its degrees and changes nothing.
- **The Gaussian shape** in `TypeFunction`, which nothing used.

Added, because the old format had nowhere to say it:

- `RANGE = low,high` on every variable. An input is clamped into it, and an
  output is sampled across it.
- `SAMPLES = n` on an output. This is where the centroid measures, and it is
  part of the controller rather than a constant on each side, for the reason
  ADR 0007 gives: a number two languages must agree on lives in one file.

## Alternatives considered

- **Read the IEC 61131-7 Fuzzy Control Language instead.** It is the
  standard that `FLC.txt` loosely follows, and real tools read it. Rejected
  for now: its syntax for a set (`TERM near := (0,0) (3,1) (7,0);`) is a list
  of points rather than a shape, which is a bigger reader and a bigger
  lesson. Nothing here prevents adding it later, beside this one.
- **Integrate the centroid exactly.** The cut shapes are piecewise linear, so
  an exact integral exists. Rejected: it means finding where every pair of
  edges crosses, and that is more code than the rest of the addon put
  together. Sampling is what the textbooks show, and the sample count is
  printed in the controller.
- **Leave the text reader out.** Rejected. It is the one piece of the old
  library that was working code, and without it "rewritten from" would mean
  only "inspired by".

## Consequences

- T13's opening sentence is wrong about the language and about what exists.
  The task file is left as written, as a dated record, and this ADR
  corrects it.
- The reader is Python only. A game does not parse a controller in a frame;
  it builds one in code, or reads the JSON shape the conformance vectors use.
- Anyone comparing the two libraries will find the same file format and
  different code. That is the intended result.
