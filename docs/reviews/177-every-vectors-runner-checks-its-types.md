# Review: wave/177-every-vectors-runner-checks-its-types

PR #136, task T121. The PR adds `VectorShape` (`godot/test/vector_shape.gd`).
It checks a parsed vector against a shape written like the JSON, and
names the first path that parts from it. Every vectors runner, or the
`*Vector` class it reads through, now asks it before reading a field.

A fresh context reviewed head 158ce10. **Verdict: changes requested.**
There are two blockers. After this PR, two runners still exit 0 on a
vector with a wrong type, both with a `SCRIPT ERROR`: the learning
runner and the squad search runner. The PR says it leaves "no exit 0
and no SCRIPT ERROR", and those two plants contradict it. The PR's own
measurement only planted text in place of a list. A wrong *leaf* type
was never tried, so it did not find these. There are also three shoulds
and four nits.

## What was reviewed

- `git diff origin/main...HEAD` (73 files), against the task, the PR
  body's six decisions, CLAUDE.md invariants 1, 3, 4 and 6, "Readable by
  a person", the two `-s` traps, and `docs/howto/parallel-batch.md`.
- **Runners counted.** `git ls-files 'godot/test/*_vectors_runner.gd'`
  lists 30 files. `ai_search/vectors_runner.gd` makes 31. The Makefile
  runs them 32 times, because planning runs twice (`spec/vectors/planning`
  and `spec/pddl`). All 31 are touched by the PR or were already guarded.
  Valley and teamwork are covered.
- **Authorship.** The three commits are by Adalberto Pereira. They and
  the PR body carry no `Co-Authored-By`, no "Generated with" and no
  tooling byline.

## What was run

| command | result |
|---|---|
| `make test-vectors` | exit 0. Every family's output was read. No `SCRIPT ERROR`; the only two `ERROR:` lines are the perception and racing self-checks' planted ones. File counts match `spec/` (e.g. teamwork 59, utility 28, racing3d 35). |
| `make check-no-engine` | exit 0 |
| `python3 scripts/check_modules.py --self-test` | exit 0 |
| `python3 scripts/affected.py --self-test` | exit 0 |
| `make lint-no-training`, `check_no_training.py --self-test` | exit 0, exit 0 |
| `python3 scripts/check_readability.py` | exit 0 |
| `make test-godot-some` on steering_test, flock_test, teamwork_test, utility_test, vector_shape_test, learning_vector_test, `test/squad`, talk_test and `test/ai_constraints` | 258 cases, 0 failures |
| each of the 31 runners on an empty folder | all exit 2, no `SCRIPT ERROR` |
| reviewer plants, set 1 (`plant2.py`): per run, on the *last* file of each folder | 273 plants, see below |
| reviewer plants, set 2 (`plant3.py`): per run, six leaves spread through the *middle* file, each set to `null` and then to a flipped type | 384 plants, see below |

Both scripts are in the session scratchpad, not committed. Each one
copies the folder, plants one change, runs the runner directly (not
through `godot_checked.py`) with a 90 s timeout, and greps for
`SCRIPT ERROR`.

Set 1 tried these plants:

- the whole file as `3`, as `null`, and as an empty file;
- the last nested object replaced by a number;
- the last list replaced by `{}`;
- the last case of a list of cases replaced by a number;
- the deepest last leaf flipped;
- a middle leaf set to `null`;
- every whole number rewritten as a float (`3` → `3.0`).

Results:

- **No hang.**
- Whole file as a number, `null` or empty: **every runner exits 2.**
- Number for an object, object for a list, case as a number: every
  runner exits 2, except where `expect` is compared by `differences()`
  (decision 3).
- **Ints written as floats: every runner still exits 0.** There is no
  false refusal: `NUMBER` accepts both, and the casts are `int(...)`.
- The only exit 1 that came from my harness was talk, whose recordings
  sit outside the copied folder. See finding 3.

Set 2's failures are findings 1, 2 and 4. Fields that are only text for
a person (`description`, `name`, `about`, `why`) exit 0 when planted.
That is right, because nothing reads them. The tree and forest `rows`
also exit 0 when planted, which is also right: the fits are Python's,
and Godot never reads the rows.

## Findings

### 1. Blocker: the learning runner exits 0 on a wrong leaf type, with and without a SCRIPT ERROR

`godot/test/tactical/learning_vector.gd:64`, `:72` and `:111`. The
runner, `tactical/learning_vectors_runner.gd`, is not changed by this PR.
The PR counts learning among the four runners that "already exited 2",
and gives it only a planted case: text for a list.

| plant in `two-nodes-one-army.json` or `past-the-sentinel.json` | exit | output |
|---|---|---|
| `board.units[1].faction = null` | 0 | `SCRIPT ERROR: Nonexistent 'int' constructor` in `board_of`, then "0 failure(s)" |
| `board.units[1].faction = {}` | 0 | the same |
| `board.costs[0][0] = null` | 0 | `SCRIPT ERROR` |
| `cases[0].attacker = null` | 0 | `SCRIPT ERROR` |
| `board.units[1].faction = "x"` | 0 | **silent**: `int("x")` is 0, nothing is reported |
| `board.costs[0][19] = "x"` | 0 | silent |

The trap applies exactly here. The `SCRIPT ERROR` aborts
`_why_a_case_is_wrong`. The aborted function returns `""`, which reads
as "nothing wrong", and the run exits 0. A string where a cost or a
faction should be passes with no error at all.

This target is not wrapped in `godot_checked.py` either.

**Fix:** give `LearningVector` a shape: board costs `[[NUMBER]]`, each
unit's fields, and each case's ids. Check it before `board_of` runs.
Plant a leaf in `learning_vector_test.gd`.

### 2. Blocker: the squad search runner exits 0 when a `visits` or `pieces` item is the wrong type

`godot/test/squad/squad_search_vectors_runner.gd:26-27` declares
`"pieces": [[VectorShape.ANY]]` and `"visits": [[VectorShape.ANY]]`.
`:68` and `:90-91` then cast those items with `int(...)`.

| plant in `spec/squad/positions.json` | exit | output |
|---|---|---|
| `positions[0].visits[21][1] = null` | **0** | `SCRIPT ERROR` |
| `positions[2].visits[15][0] = 5` | **0** | `SCRIPT ERROR` |
| `positions[1].pieces[2][2] = null` (and `= 5`) | 1 | `SCRIPT ERROR` |
| `positions[0].pieces[5][4] = null` | 1 | `SCRIPT ERROR` |

The `SCRIPT ERROR` aborts `check_position`. The aborted function returns
`[]`, which reads as "agrees", so the runner exits 0.

The cause is a gap in the shape language. A piece (`[id, faction, type,
x, y, health, ...]`) and a visit (`[answer, count]`) are *tuples*: lists
whose items each have their own type. `VectorShape` has no way to say
that, so `ANY` stands in for it. `ANY`'s own doc says it is "read only
by a comparison that copes with any value, never cast", and these items
are cast.

The same `[[ANY]]` is used for maze `trace[].ghosts` and the
tree/forest `rows`. The maze plants exit 1 (compared, never cast), and
the rows are never read by Godot, so those two are safe. The squad's
are not.

**Fix:** either add a tuple form, or type the squad's items. For a tuple
form, a list of more than one item could mean "exactly these, by
position": `[TEXT, NUMBER]` for a visit. Whichever you choose, plant
`null` in a `visits` item in `squad_search_test.gd`.

### 3. Should: a talk recording of the wrong type exits 1, not 2

`godot/test/talk/talk_vectors_runner.gd:77-79`. The runner now checks
the recording a vector names against `RECORDING_SHAPE`. When it does
not match, the runner returns a *failure*.

Plant: in a copy of the repo, set
`data/talk/recordings/becoming-the-expected.en.json` `turns = "x"`.
The runner exits **1**, with "becoming-the-expected.en.json: cannot read
… .turns is not a list". A missing recording also exits 1.

The task's first decision says a file the runner cannot read "exits 2
with a reason, never 0 and never 1". This case is not one of the two
exits that decision 3 lists. The fix is to check the recording's shape
in the first loop and exit 2 there. Otherwise, add it to decision 3 and
say why.

### 4. Should: mixed types inside a constraint variable's values reach the solver as a SCRIPT ERROR

`godot/test/ai_constraints/constraint_vector.gd:21` types `"values":
[VectorShape.ANY]`. Line 104's `first != second` then compares across
those values.

Plant: in `australia-in-three-colours.json`, set
`variables[3].values[1] = 5` (the other values are text). The run
exits 1, but prints three `SCRIPT ERROR: Invalid operands 'String' and
'float' in operator '!='`, from inside `ConstraintSolver._revise`. So
the PR's "no SCRIPT ERROR" does not hold here either.

A domain may be text or numbers, but not both in one variable. Add a
rule that a variable's values share one type, as V7 or the next number.

### 5. Should: `VectorShape` should say which values may be `ANY`, and its tests should hold that

This follows from findings 2 and 4. The header sets the rule for `ANY`
(`vector_shape.gd`, the `ANY` constant): "never cast". Two families
broke it within this PR, and nothing checks it.

The readable fix is the one in finding 2: a tuple shape, so that `ANY`
is rarely needed. Then list each remaining `ANY` in the PR with the
comparison that reads it.

### 6. Nit: teamwork's and utility's shapes are hard to read as nested data

`godot/test/ai_teamwork/teamwork_vector.gd:18-103` and
`godot/test/ai_utility/utility_vector.gd:17-43` indent their
continuation lines all at one level, whatever the nesting.

In `"rings"`, for example, `"target"`, `"view_from"` and `"script"` sit
at the same indent as `config`'s inner keys, but they are `query`'s keys.
A reader has to count braces to see the shape. For teaching material,
indent one level per nesting level, as `steering_vector.gd` and
`flock_vector.gd` do.

### 7. Nit: flock's own missing-key rule is now held only by the shape

`godot/test/ai_steering/flock_vector.gd:60-62`.

Mutation: replace the `it has no %s` loop with `if false:`. Result:
`flock_test.gd` still passes, because `VectorShape`'s "the file has no
expected" also contains `expected`.

So the rule is still enforced, but the explicit loop is now code that
no test pins. Either drop it, or have the test assert the loop's own
wording (`it has no expected`).

The other fixture changes (decision 5) do **not** weaken their tests.
Removing the "it expects nothing" rule from `teamwork_vector.gd` and
`utility_vector.gd` fails both checker tests. Removing steering's
unknown-key rule fails `steering_test.gd`'s misspelt-field test. All
mutations were restored, and `git status` was clean afterwards.

### 8. Nit: two edge cases in the helper itself

`planted(vector, [], value)` indexes `path[-1]` on an empty path. A
one-item-list shape written as `[]` would index `shape[0]`. Neither
happens today. A one-line guard, or a sentence in each doc comment,
would keep a reader from wondering.

### 9. Nit: the vector name is not always passed in as `where`

Perception's refusal reads "the-stance-counts-points.json is not a
perception vector -- the file.query.looks[0].light is not a number". The
runner names the file, but the path inside the message still says
"the file". Some families pass the name (talk, checkers, menace) and
some do not (perception, teamwork, utility, steering).

## The decisions

1. **The helper is global, and a change to it selects everything.**
   Agreed. The two alternatives are worse:
   - Owned by `ai_core`: M9 fails, because twelve modules would use
     `ai_core`'s test helper without depending on its code.
   - One copy per family: 30 copies of the same 150 lines, in a project
     whose first rule is readability.

   A file that every vector gate stands on is global in the plain sense.
   Listing `vector_shape_test.gd` as global too costs a full selection
   when only the test changes. That is acceptable.

   As teaching material, the header is good. It says what the helper
   does, why it exists (the `-s` trap) and when not to use it, and the
   shape language reads like the JSON it describes. The tuple gap
   (finding 2) is the one place where the language pushed families into
   writing something false.
2. **Shapes beside their readers; the player model's in
   `ModelVectorFiles`.** Agreed, and it is honest under N14.
   `player_model_test.gd` already read its vectors through
   `ModelVectorFiles.read_all` on main (lines 150 and 164 there). The new
   test only calls `VectorShape.why_not`, which loads nothing.
   `lint-no-training` and its self-test pass.
3. **Two places still exit 1.** Agreed for these two:
   - the tree and forest `model`, which `ModelFile` refuses and the
     runner's header calls a failure;
   - `expect` in perception, teamwork and utility, which
     `differences()` compares and never casts.

   My plants confirmed both, with no `SCRIPT ERROR`. Finding 3 is a
   third case the PR does not list, and findings 2 and 4 are places
   where `ANY` is cast after all.
4. **Key order kept.** Agreed. The rules' letters still come first, so
   an existing test that expects `V1` or `A4` still gets it.
5. **Fixtures changed.** Agreed. The checks above found no weakening,
   apart from the redundancy in finding 7.
6. **The director's length check.** Agreed. A short `intensity` would
   crash in the same way, and the check exits 2 with a reason.
