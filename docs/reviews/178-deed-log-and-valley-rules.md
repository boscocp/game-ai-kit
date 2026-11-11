# Review: wave/178-deed-log-and-valley-rules

T164. The PR adds the memory under the karma example, with no screen yet
(ADR 0025): `DeedLog` (deeds `{day, verb, place}`, appended, refused by
name), `ValleySave` (the one writer of `user://valley/deeds.json`, header
`{"version": 1}` then one deed a line, appended through `READ_WRITE`),
`ValleyRules` and `ValleyWorld` (the world of any day rebuilt from the
record and 18 authored overnight rules), `Standing` (care and fear, integer
weights per verb and place); the Python twin `gameaikit.valley`; 15 vectors
from an independent `derive.py`; `make test-valley-vectors`; a new example
module, `modules/valley.json`.

A fresh context reviewed PR #133 on `origin/wave/178-deed-log-and-valley-rules`
(one commit, 91c6fef), on the owner's short list of commands (no `make check`).
**Verdict: changes requested. No blocker; five shoulds and six nits.**
Every acceptance command is green, the three properties the task names
hold, the PR's planted cases are caught as it says, and the save lands only
under the checkout's `.user-data/`. What is missing: `ValleySave.append`
writes into a file it never looks at, so one call out of turn makes the
one file the kit keeps unreadable (finding 1); and three survivors among
the mutants are promises the code makes with no case (findings 2, 3).

## What was reviewed

- The task (T164), ADR 0025 (especially "What a test may do" and "What
  N20 cannot see"), N20 in `scripts/check_no_training.py`, CLAUDE.md
  invariants 1, 3, 4, 6, 8, "Readable by a person" and the traps,
  `docs/howto/parallel-batch.md`, T165's task, and
  `git diff origin/main...origin/wave/178-deed-log-and-valley-rules`
  (42 files, 2584 lines added).
- **The PR's eight decisions, judged.**
  1. Names kept as proposed, N20's constants unchanged: agreed.
  2. Two virtues, care and fear: agreed; they read as two different
     things the valley believes, and `divert_water` (0 care, 1 fear) shows
     why two are better than one.
  3. Every fact a boolean, a day = one night then that day's deeds, day 0
     the start at rest: agreed; the order is the vectors' and `derive.py`'s.
  4. The authored files in `godot/game/valley/`, read by Python from
     there: agreed; `gameaikit.valley` is not in the wheel's package list,
     and `botmatch` set the precedent.
  5. Whether a deed is possible is left to T165: agreed as a split, but
     T165's task does not say so, and the standing can be farmed meanwhile
     (finding 4).
  6. A deed line repeating `version` is refused: agreed, stricter than
     ADR 0025's wording (nit 11), and it has no vector (finding 3).
  7. Integer weights: agreed.
  8. Consequence keys without thresholds: agreed; T165 sets them.
- **Readability (invariant 1).** `python3 scripts/check_readability.py`:
  exit 0. By eye: the longest GDScript function is `DeedLog.refusal`
  (13 lines), nesting at most 2, every file under 125 lines, static types
  throughout. Each script opens with what it solves, its cost and "when
  not to use it". The rules file reads top to bottom like the "about" in
  `valley_rules.json`.
- **Invariant 3.** All five acceptance lines are commands; the authored
  files' reasons are under `## Manual check`, read below.
- **Invariant 4.** The PR plants six cases and each is caught (re-run
  below as G1, G2, G4, G7 and the empty folder). The vectors are not
  trivially passable: the Godot runner exits 2 on an empty folder, the
  Python side asserts at least 8 rebuilt and 7 refused, and the "quiet
  valley" vector has no deeds but four days of worlds to match. One hole:
  a `refused` vector with `"names": ""` would pass on both sides (nit 9).
- **Invariant 6 / N20.** `python3 scripts/check_no_training.py`: exit 0.
  Planted against `check_valley` on a copy of the two folders (table
  below): eight of eleven refused; one gap is new with this wave's
  spelling (finding 5).
- **Invariant 8.** The tests' save resolved to
  `<checkout>/.user-data/xdg/godot/app_userdata/game-ai-kit/tmp/...` and is
  gone after the suite; `~/.local/share/godot/app_userdata/` does not exist.
- **Authorship.** The one commit is Adalberto Pereira's; neither its
  message nor PR #133's title and body carry a `Co-Authored-By`, a
  "Generated with" line or a mention of the tooling (grep over
  `git log origin/main..` and `gh pr view 133 --json title,body`: empty).

## What was run

| command | result |
|---|---|
| `make test-godot-some SUITES="test/valley"` | 12/12 passed, 0 orphans; no `SCRIPT ERROR`, no "still in use" in the output |
| `make test-valley-vectors` | 8 rebuilt, 7 refused, 0 failures |
| `make test-python` | 717 tests OK |
| `python3 scripts/check_no_training.py` | exit 0 |
| `make lint-modules` | ok, 42 modules |
| `make check-no-engine` | exit 0 |
| `python3 scripts/check_readability.py` | exit 0 |

## Twins on the same lines

22 hand-written records (day 1.5, `"1"`, 0, -1, `true`, 1e400, 2^53+1;
version `"1"`, `1.0`, `true`; a header with a second key; a repeated
header; a deed carrying `version`; `[]`; an empty line; a list as verb; a
number as place; duplicate keys; out-of-order floats; an empty record;
not JSON) read by `ValleySave.read_lines` (a `-s` probe) and
`record.read_lines`. **Both refuse or keep the same lines, every time.**
The messages differ only in how each prints a value: Godot `day 0.0`,
`day -1.0`, `3.0 is not a place`, `version true`, `unknown verb ["plant"]`;
Python `day 0`, `day -1`, `3`, `True`, `['plant']`. The vectors match by
substring, so a word like `day 0` would pass both by luck and `3.0` would
not (finding 3).

## Mutants

One at a time in place, the valley suite and the vectors run, the file
restored after each (`git status` clean at the end; `__pycache__` removed
after the Python round):

| # | mutant | result |
|---|---|---|
| G1 | the save opens with `WRITE` (truncates) | caught (append test; also a `SCRIPT ERROR`) |
| G2 | the header accepts any version | caught |
| G3 | the header may hold more than its version | **survived** |
| G4 | a deed with an extra key is kept | caught |
| G5 | an unknown verb is kept | caught |
| G6 | an out-of-order day is kept | caught (vectors only) |
| G7 | the rules read the night being written | caught (vectors only) |
| G8 | `cut` drops the day itself (`<`) | caught |
| G9 | the world shares the start's dictionary | caught (vectors only) |
| G10 | `deeds()` copies the array but not the deeds | **survived** |
| G11 | a weight drifts each time it is read | caught |
| G12 | the save appends without asking the record | caught |
| G13 | a day's deeds before its night | caught (vectors only) |
| G14 | `erase` does nothing | caught |
| G15 | `because` rewritten on every write, changed or not | **survived** |
| G16 | `load_into` skips the header check | caught |
| P1-P11 | Python: extra key, any version, out of order, rules read mid-night, `cut` with `<`, `deeds()` handing out the kept dicts, unknown verb, deeds before the night, drifting weight | caught |
| P3 | Python: header may hold more than its version | **survived** |
| P9 | Python: a deed on day 0 is kept (`day < 0`) | **survived** |

## N20 plants

| plant | result |
|---|---|
| a second file in the folder writes `"user://valley/deeds.json"` with `WRITE` | refused |
| the same through `save.path` and `store_line` | refused |
| a second file opens `save.path` with `READ_WRITE` (and then `resize(0)`) | **passes** (finding 5) |
| a file outside the folder naming `DeedLog` writes the save | refused |
| a file outside the folder naming no valley class writes `"user://valley/deeds.json"` | **passes** (ADR 0025's targets; noted in finding 5) |
| `valley_save.gd` stores `world.facts` | refused |
| `standing.gd` writes `_weights` inside `of()` | refused |
| a villager writes `standing._weights[...]` | refused |
| a game file builds `{"day", "verb", "target"}` | refused |
| the test names `ValleySave.PATH` | refused |
| `valley_save.gd` truncates (`WRITE` for `READ_WRITE`) | passes, as ADR 0025 says; G1 holds it |

## Findings

1. **Should.** `godot/game/valley/valley_save.gd:178-213`. `append` asks
   the in-memory `record` whether the deed may follow, and never looks at
   the file it appends to. A `-s` probe on a save under `user://tmp/`:
   - **A.** Two calls with fresh records (a session that appends before
     `load_into`): day 5, then day 1. Both return `""`. The next
     `load_into` refuses the whole file: "line 3: day 1 comes after day 5".
   - **B.** A file with header `{"version": 2}`: the append returns `""`
     and writes a version-1 deed into a file this game "refuses rather
     than misreads".
   - **C.** A file whose last line is torn (`{"day": 1, "verb": "pla`, a
     crash mid-write): the append returns `""` and joins its deed to the
     torn line; `load_into` then refuses everything ("line 2 is not a deed").
   - **D.** A file that exists but is empty (a crash before the header):
     the append writes a deed with no header; `load_into` refuses it ("no
     version").

   Each one turns the only file the kit keeps into one the game refuses,
   and the erase button is then the only way on. ADR 0025's "one class
   writes it" is the place to make this impossible, not T165's call
   order. Proposed: `ValleySave` remembers whether this file was loaded
   (or loads it itself) and refuses `append` otherwise; before appending
   to an existing file, checks its first line with `header_refusal` and
   that it ends in `"\n"`, refusing by name; one test each for A-D.

2. **Should.** `godot/test/valley/valley_test.gd:145-150`. The Godot test
   that a deed read out cannot change the record only `clear()`s the
   returned array. G10 (`_deeds.duplicate()` without `true`) survives: a
   reader can then write `record.deeds()[0]["place"] = "mill"` and edit a
   kept deed, the one thing an append-only record must refuse. The Python
   twin's test does exactly that edit and catches P7. Proposed: the same
   edit in the GDScript test, asserting the record's first deed unchanged.

3. **Should.** Refusals the code makes with no case on either side:
   - **A header holding more than its version** (G3 and P3 survive). The
     header is the one line of the save that is not a deed, so
     `{"version": 1, "player": "Ana"}` is exactly a person in the save,
     which ADR 0025 refuses.
   - **A deed on day 0 or a non-whole day** (P9 survives; G-side the same
     check). A day-0 deed is worse than refused-late: `rebuild` starts at
     day 1 and never applies it, while `Standing.of` counts it, so the
     world and the standing would disagree about what the player did.
   - **A repeated header line** (decision 6) and **a line that is not an
     object** (`[]`).

   Proposed: four `refused` vectors (`derive.py`'s `at_fault` learns the
   header's extra key, a day below 1 and a non-object line), so both twins
   are held by one file each. Pick each vector's `names` so that it
   matches both twins' formatting (`day 0` matches Godot's `day 0.0`
   only by luck; a place `3` would not match `3.0`), or make the twins
   print integers alike.

4. **Should.** Decision 5 and `godot/game/valley/standing.json`. The
   standing sums every kept deed, and the record keeps deeds that change
   nothing: `close_gate` on the gate that starts closed is +1 care, every
   day, as often as the player likes; `dig_well` on a square that already
   has one is +3. The weights' reasons ("Shutting the gate behind you",
   "water for every house") assume the deed changed something. T164
   leaves the check to T165, which is a fair split, but `tasks/T165-*.md`
   does not mention it, so nothing carries it there. Proposed: either
   refuse in `ValleySave.append`/`DeedLog` a deed that sets no fact that
   differs in the world of that day (with a test that farms `close_gate`),
   or add a decision to T165 now that a deed which changes no fact is not
   offered and not recorded, with its test named.

5. **Should.** `scripts/check_no_training.py:472-478` (`WRITING_RE`). This
   wave made `FileAccess.READ_WRITE` the save's mode, and N20's write net
   does not know it: a second file in the valley's folder that opens
   `save.path` with `READ_WRITE` and calls `resize(0)` truncates the
   record with no finding (plant above; `store_line` after it would be
   caught). Proposed: add `READ_WRITE` and `\.resize\s*\(` to what counts
   as a write beside the valley, with a planted case and the good
   `valley_save.gd` still passing. Separately, for the record of what N20
   cannot see: a file outside the folder that names no valley class and
   writes `"user://valley/deeds.json"` is not a target at all; ADR 0025
   lists its targets, so this is a note for its "cannot see" list, not
   this wave's fix.

6. **Nit.** `godot/game/valley/valley_world.gd:146-149` (G15). Nothing
   checks that a reason is kept only when the value changes, which is
   what `ValleyWorld`'s header promises ("names the cause of what the fact
   is now"), and rebuilding twice compares `facts` but not `because`.
   Proposed: in `test_the_world_says_why_a_fact_changed`, a rule that
   rewrites `market.bread` to the same `false` the next night must leave
   the barn's reason; and compare `because` in the rebuild-twice test.

7. **Nit.** `valley_save.gd:169-170` and `record.py:118-119`. A header
   `{"version": "1"}` is refused with "the record is version 1, and this
   game reads version 1", which reads as a contradiction. Print the value
   as JSON (`"1"`) or say it is not a number.

8. **Nit.** `valley_save.gd:137`. `load_into` splits with
   `allow_empty = false`, so a blank line inside the file is skipped,
   while `read_lines` on the vectors refuses `""` ("line 2 is not a
   deed"), and the Python side has no file reader. Say which is the
   format (the writer never writes a blank line) and make the file path
   and the lines path agree.

9. **Nit.** `valley_vectors_runner.gd:84` and `test_valley_vectors.py:50`.
   A `refused` vector with `"names": ""` passes on both sides, even for a
   good record (`"" in ""`). Refuse an empty `names` as an unreadable
   vector (exit 2 / a failed assertion).

10. **Nit.** `valley_rules.json` and `standing.json` (the manual check).
    Each rule and weight reads as a designer's reason, and the bread rules
    read like the task's example. One pair contradicts: `plant orchard`
    sets `orchard.standing`, and the next night "The shut gate keeps the
    goats from the trees, and they fruit", while `burn orchard`'s weight
    says "Trees take years to bear again". Either young trees do not fruit
    (a fact such as `orchard.young`) or the weight's reason changes.

11. **Nit.** Decision 6 against ADR 0025, "N20 also lets a deed line carry
    `version`, so a record that repeats it on each line is not refused".
    The reader refusing it is the better rule; a line in the ADR's
    consequences (or STATUS) saying the game's reader is stricter than
    N20 would keep a later reader from "fixing" the code to the ADR.
