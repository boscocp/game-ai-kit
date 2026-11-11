# Review: wave/183-no-self-naming

PR #139, task T167. A new lint, `make lint-self-naming`
(`scripts/check_self_naming.py`, in `check-no-engine`), refuses an addon
script under `godot/addons/ai_*/` that names its own `class_name` as a
value in its own file. It allows the name only in the type positions T162
measured harmless, and refuses every other use.

A fresh context reviewed head 2364e64. **Verdict: no blocker.** There is
one medium finding (the self-test did not hold the end anchor of the type
rule), two low findings (raw strings, and a comma inside a default
dictionary), and three nits.

## What was reviewed

- The whole diff against the task, its decisions and the wave's changes to
  them, CLAUDE.md invariants 1, 4 and 11, "Readable by a person", and
  `docs/godot/exit-leaks.md`.
- **The lint on both trees.** main: exit 0, 117 scripts with a
  `class_name`. The addons before T162 (`84becd0b~1`): exit 1, 33 lines in
  the 16 files T162 changed.
- **The self-test, by mutation.** Each regex part and each guard of the
  lint was changed in a copy and the self-test was run against it. Two
  parts it did not hold: the `$` anchor of `TYPE_BEFORE`, and `const` in
  `TYPE_LEAD`.
- **Two spellings measured on 4.7.2** for findings 2 and 3: how GDScript
  ends a raw string, and a dictionary as a default argument.
- **Authorship.** The commit and the PR body are by Adalberto Pereira,
  with no `Co-Authored-By`, no "Generated with" and no tooling byline.

## Findings

### 1. Medium: the self-test did not hold the end anchor of `TYPE_BEFORE`

Without the `$` at the end of `TYPE_BEFORE` (line 84), the self-test still
passed. The mutant read a value after a type lead on the same statement
as a type: `var x: Toy = Toy.new()`, `func f(x: Toy = Toy.make())`,
`func f() -> Toy: return Toy.new()`, `@export var x: Toy = Toy.new()`,
`var t: Toy = o as Toy`. On the tree before T162 it found 17 lines, not
33. Every value plant was a bare `return ...`. Dropping `const` from
`TYPE_LEAD` (line 79) also passed, since no types-only line used it.
**Fix:** plant values that follow a type lead on the same statement, add
`const X: Toy` to the types-only script, and run both mutations again.

### 2. Low: raw strings were stripped wrongly

`_string_end` (lines 97-104) let a backslash escape nothing in a raw
string. In GDScript `r"a\"b"` is one string: `\"` does not close it.
`var r := [r"\"", Toy.new()]` passed. **Fix:** in a raw string, still skip
the character after a backslash when it is a quote or a backslash. Add a
plant.

### 3. Low: a comma inside a default dictionary was crossed

`func f(y: Dictionary = {1: 2, CAP: Toy}) -> int:` passed. The argument
part of `TYPE_LEAD` (line 80) crossed the comma inside `{}`, so `CAP:`
read as an argument's name and `Toy` as its type. **Fix:** do not cross
`{}` or `[]` there, with a plant, or name the gap in the docstring.

### Nits

- The `%` in the look-behind of `value_uses` (line 160) also skips modulo
  written without a space, `"%s"%Toy.CAP`. Say so in a comment.
- A known false positive: `func f(a: Vector2 = Vector2(maxf(1.0, 2.0),
  0.0), b: Toy = null)` is refused, since the argument part reads one
  level of nested parentheses. Name it in the docstring.
- The commit message said 14 mutations were caught, which reads as if the
  self-test held the whole lint. It did not (finding 1).

## What was done about them

All of them were applied on the branch, in one commit:

- **Finding 1.** Seven new plants: `var built: Toy = Toy.new()`,
  `var cast: Toy = thing as Toy`, `func value(thing: Toy = Toy.make())`,
  `func value() -> Toy: return Toy.new()`, `@export var kept: Toy =
  Toy.new()`, the raw string and the default dictionary below. The
  types-only script gains `const NONE: Toy = null`. With the anchor
  dropped, the self-test is red (`plant_typed_then_built`,
  `plant_typed_then_cast`, `plant_default_argument`, ...). With `const`
  dropped, it is red on the types-only script.
- **Finding 2.** A backslash before a quote or a backslash skips that
  character in a raw string too. There is a plant
  (`return [r"\"", Toy.new()]`), and `const RAW: String = r"a\"b Toy.new()"`
  in the types-only script. With the old handling, both go red.
- **Finding 3.** The argument part now reads `ARGUMENT_PIECE`: any
  character but a bracket, or a whole `(...)`, `[...]` (one level deeper
  too) or `{...}`. A comma inside a default `{}` is never crossed. There is
  a plant for `{1: 2, CAP: Toy}`. The types-only script gains
  `func keyed(table: Dictionary = {1: 2, 3: 4}, rows: Array[int] = [1, 2],
  deep: Dictionary[String, Array[int]] = {}, last: Toy = null)`, so a fix
  that stopped at any bracket would refuse it. Both mutations (crossing
  braces again, or crossing no bracket) go red.
- **Nits.** A comment on the `%`. The docstring names the two-level
  default as a known false positive. This commit and the PR body give the
  real count: 19 mutations of the lint, each now caught by the self-test.
  The first round's 14 did not include the two in finding 1.

Re-run after the changes: `check_self_naming.py --self-test` 0 (19
refused plants, the types-only script passes, empty and unnamed folders
refused, a missing folder 2). The 19 mutations: each self-test exit 1.
`check_self_naming.py` on main: 0. On the tree before T162: 1, 33 lines
in 16 files. Also run: `run_selftests.py` 0, `make lint-readability` 0,
`lint-tasks` 0, `lint-status` 0. `__pycache__` was removed after the
mutations.
