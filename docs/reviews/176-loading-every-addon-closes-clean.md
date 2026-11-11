# Review: wave/176-loading-every-addon-closes-clean

T162. The store's 0.1.0 download printed `7 resources still in use at exit`
after T159's loader. The PR names the leaking scripts. It says the cause is
a script naming its own class as a value, and `GDScriptLanguage::finish`'s
walk over `script_list` ending early. It rewrites 16 addon scripts to say
`new(...)`, gives `BehaviourTree` a `const SAID`, and makes
`check_published.py` and `library_check.py`'s `kit` step fail on the two
exit lines, with a planted case `check_published.LEAKING`.

A fresh context reviewed PR #135 on
`origin/wave/176-loading-every-addon-closes-clean` (head `0914b81`). It ran
the owner's short list of commands only, not `make check`.
**Verdict: changes requested.** The leak fix holds in every load order
tried, including seven the implementer did not try. The checks really
refuse the plant. There are two blockers. Decision 4's "green when 0.2.0 is
uploaded" is false by the code: the gate checks every recorded upload, and
0.1.0's record stays. Also, `new()` in the two *instance* methods changes
what a subclass gets back, so it is not behaviour-preserving. Nothing was
bumped, tagged, released or uploaded.

## What was reviewed

- The task file, `git diff origin/main...HEAD` (22 files), CLAUDE.md
  (invariants 1-4, 9; "Check the documentation"; the traps),
  `docs/howto/parallel-batch.md`, `docs/howto/publish.md`,
  `docs/godot/exit-leaks.md` before and after, and the review record of
  wave 172 for the format.
- **The engine source, read at the tag.** `modules/gdscript/gdscript.cpp`
  and `core/templates/self_list.h` at `4.7.2-stable`. `finish()` (line
  2228) clears the cache, then walks `script_list.first()`. It takes
  `Ref<GDScript> scr = s->self()`, clears it, and reads `s = s->next()`
  while `scr` is still held. `scr` is released at the end of the loop
  body. `GDScript::GDScript()` calls `script_list.add` (line 1319), and
  `SelfList::List::add` puts the new node first (lines 45-60), so the walk
  goes newest to oldest. `~GDScript` removes the node (line 1528), and
  `remove` sets its `_next` to null (line 97). The PR's reading matches the
  source line for line, with one imprecision (finding 6).
- **The leak, reproduced independently** (question 2). Both trees'
  `godot/addons/` were put into blank projects in the scratchpad, imported,
  and loaded by a loader of my own. It reads the order from a file, so
  T159's loader was not involved. 117 scripts were loaded each time, with
  no `SCRIPT ERROR`.

  | order | origin/main | branch |
  |---|---|---|
  | sorted by path (≈ the loader's order) | 10 still in use | clean |
  | reverse | 33 | clean |
  | by file name, ignoring the folder | 4 | clean |
  | by file name, reversed | 33 | clean |
  | 8 seeded shuffles (11, 22, ..., 88) | 30, 31, 17, 26, 34, 18, 27, 16 | clean ×8 |

  The PR's 10 for the loader's order reproduces. Seven of these orders were
  not among the PR's five (the by-name pair and the shuffles have their own
  seeds), and the fix holds in all twelve.
- **Behaviour of the 16 rewrites** (question 3). Each `:=` → explicit type
  is the script's own class, the same type `:=` inferred. `BehaviourTree`
  keeps `Status`, `said()` and the inner classes, and `SAID` is an
  addition. A probe, `subclass_probe.gd`, subclassed four of the rewritten
  classes from outside the addon. On both trees:

  | call | origin/main | branch |
  |---|---|---|
  | `SubPlan.impossible(4)` (static) | a `PlanResult` | a `PlanResult` |
  | `SubCommand.move(...)` (static) | a `RtsCommand` | a `RtsCommand` |
  | `SubModel.from_dictionary(...)` (static) | a `ModelFile` | a `ModelFile` |
  | `SubWorld.new().after(...)` (instance) | a `WorldState` | **a `SubWorld`** |
  | `SubGraphSameArgs.new(4, 4).duplicate_graph()` (instance) | a `GakGridGraph` | **the subclass** |
  | `SubGraph.new().duplicate_graph()`, `_init()` taking no arguments | a `GakGridGraph` | **`null`**, `SCRIPT ERROR: Invalid call to function 'new' ... Expected 0 argument(s)` |

  In a static function, `new()` builds the class it is written in. In an
  instance function, it builds the instance's own script (finding 2).
- **The checks, mutated** (question 4). `exit_leaks()` was made to return
  `[]`. `check_published.py --self-test` then exited 1:
  `self-test FAIL: a script left alive at exit is refused, naming 'alive
  at exit' ([])`. `library_check.py --self-test` exited 1, naming the
  `LEAKING` plant. Restored, and `__pycache__` removed under `python` and
  `scripts`. An empty load: `load_every_class()` on a project whose
  `addons/` holds a folder and no script returns `([], (0, 0))`, which is
  a pass (finding 3). A project with no `addons/` at all fails, because
  `DirAccess` prints an engine error.
- **The proposed lint** (question 5). `self_naming_probe.py` is about 20
  lines, a regex per `class_name`: `Name.<call>(`, `is Name`,
  `Name.CONSTANT`, with comments stripped. It found 33 lines in exactly
  the 16 files on origin/main, and 0 lines on the branch (finding 4).
- **Where `check-published` runs** (question 1). It is not in `make check`
  (Makefile lines 152-167), not in `check-no-engine`, not in `release`
  (`release: release-version export`, line 1306), and not in
  `.github/workflows/ci.yml`. It runs by hand, as `publish.md` step 3 says.
  Merging this does not make main red.
- **Authorship (invariant 11).** `git log origin/main..HEAD` shows three
  commits, all by Adalberto Pereira, with no trailer. `gh pr view 135`:
  author boscocp, and the body has no tooling byline.

## Findings

1. **blocker -- `check-published` does not turn green when 0.2.0 is
   uploaded. It stays red for good, and a gate that is always red is soon
   ignored.** `scripts/check_published.py`'s `check()` (line ~357) loops
   over *every* entry in `tools/store/published.json`. `publish.md` step 2
   says to *add* an entry after each upload, and the 0.1.0 record says
   what the file is, so it stays. That file will leak 7 at exit forever.
   The PR body, the STATUS row for T162 and decision 4 all say "the gate
   turns green when 0.2.0 is uploaded". That is not what the code does.
   **Recommendation:** record the 0.1.0 leak as a known, named exception
   in its own entry, for example
   `"known_at_exit": {"still_in_use": 7, "why": "T162, fixed in 0.2.0"}`.
   The gate then fails on any leak in an upload that has no such field,
   and on a count different from the recorded one in an upload that has
   it. That keeps the gate green and still meaningful: a newer engine that
   changes 0.1.0's count shows up. It also matches decision 4's own reason
   for leaving the record alone. Fix the decision text and the STATUS row
   to match. The other way out, deleting 0.1.0's entry once 0.2.0 is up,
   loses the record T159 exists to keep.

2. **blocker -- `new()` in an instance method changes what a subclass
   gets.** `godot/addons/ai_core/grid_graph.gd:124` (`duplicate_graph`)
   and `godot/addons/ai_planning/world_state.gd:57` (`after`). Measured
   with the probe above: before, both returned the addon's own class.
   Now they build `get_script()`'s class. A game's
   `class HexGraph extends GakGridGraph` with another `_init` gets `null`
   and a `SCRIPT ERROR` from `duplicate_graph()`. One with the same `_init`
   gets a half-copied subclass. No test in the repository subclasses
   either, so the suites stay green (341/341). The static rewrites (the
   other 14 files) keep their behaviour. Suggested fix: build the copy
   through a static factory in the same file, for example
   `static func _sized(...) -> GakGridGraph: return new(...)`, called from
   the instance method. A static `new()` is the toy table's clean row.
   Re-run the five load orders after the change. `docs/godot/exit-leaks.md:214`
   says "`new(...)` builds one in a static or an instance function", and
   line 224 says "write `new()`". Both need the same caveat, because a
   reader who follows the advice in an instance method gets this bug.

3. **should -- the `kit` step passes a load of zero scripts.**
   `scripts/library_check.py:342` keeps only `load_every_class(...)[0]` and
   drops the counts. `load_every_class` itself passes an `addons/` with no
   script (`([], (0, 0))`, measured). Today the earlier `kit` checks make
   an empty kit impossible. But if the loader ever walks nothing (a renamed
   `ADDONS`, a moved kit layout), this step goes green having loaded
   nothing. That is invariant 4's "does this pass on an empty scene?"
   Compare the loaded count with the number of `.gd` files under
   `my_kit/addons/`, as `check_published.py` already does with
   `expected_counts`.

4. **should -- the static lint (decision 5) is cheap enough, so give it a
   task now and do not leave it as prose.** The prototype is about 20
   lines. It is exact on both trees (16 files on main, 0 on the branch)
   and needs no engine. The loader checks catch the pattern only in the
   orders they run. A new self-naming script that ends up last in the
   loader's order leaks nothing there, and would ship. The owner decided
   against building it in this wave, and that decision stands. But with no
   task file, it is a rule with no gate, the thing CLAUDE.md's invariant
   table exists to stop. Open a task, or a line under T161's follow-ups,
   before the merge.

5. **should -- nothing at the 15 `new()` call sites says why.**
   `behaviour_tree.gd` explains `SAID`. The other files changed
   `Foo.new()` to a bare `new()` with no comment. By invariant 1, a reader
   who is used to `Foo.new()` will "tidy" it back, and nothing but the
   loader, in some orders, would notice. One line per file, or finding 4's
   lint, closes this.

6. **nit -- the page's description of the walk skips a step.**
   `docs/godot/exit-leaks.md:201`: "The walk reads that null and stops."
   By the source, the next iteration first runs `s->self()` on the freed
   node and makes a `Ref<GDScript>` of the freed script, which it clears.
   Only then does it read `_next == nullptr`. That is a use-after-free of
   the script as well as of the node. It strengthens decision 6, an engine
   bug worth reporting, and it means the result is undefined behaviour,
   not a guaranteed stop. Say so in a clause.

7. **nit -- the page's 26-33 range includes the loader's order, which
   leaked 10.** `docs/godot/exit-leaks.md:221`: "those orders leaked 26 to
   33". The loader's order is one of those five, and it leaked 10 (the
   section above says so, and it reproduced). Say "10 to 33", or name the
   four.

8. **nit -- the docstring of `check_published.py` merged two paragraphs.**
   Line 64: the sentence about the rebuild compare and the stray-path rule
   being planted in `test_check_published.py` now sits at the end of the
   T162 section, joined to its last sentence on an over-long line. It
   belongs back under "Why `--self-test` exists".

## What was run

| command | exit | notes |
|---|---|---|
| `python3 scripts/check_published.py --self-test` | 0 | `self-test: ok`, the `LEAKING` plant included; 0 `SCRIPT ERROR` |
| `python3 scripts/library_check.py --self-test` | 0 | `self-test: ok` |
| `make library-check` | 0 | "the 9 steps of using-the-library.md ran outside the repository" |
| `make test-godot-some SUITES="test/ai_bayes test/ai_behaviour test/ai_core test/ai_learning test/ai_llm test/ai_perception test/ai_planning test/ai_rts_core test/ai_search"` | 0 | 341/341; two `SCRIPT ERROR`s, both the deliberate abstract-class cases in `test/ai_core/interfaces_test.gd` |
| `make test-vectors` | 0 | no `SCRIPT ERROR` |
| `make test-demos-exit` | 0 | no `SCRIPT ERROR` |
| `make lint-selftests` | 0 | |
| `make check-no-engine` | 0 | test-python: 734 tests |
| mutation: `exit_leaks()` returns `[]` | 1 and 1 | both self-tests name the `LEAKING` plant; restored, `__pycache__` removed |
| own loader, 12 orders × 2 trees | -- | table above |
| `subclass_probe.gd` on both trees | -- | table above (finding 2) |
| `load_every_class` on an empty `addons/` | -- | `([], (0, 0))` (finding 3) |
| `self_naming_probe.py` on both trees | -- | 16 files / 0 files (finding 4) |

Not run: the full `make check` (owner's rule), `make check-published` (it
needs the network, and the PR records its expected exit), and the task's
`## Manual check` (the editor, open and close), which is a person's.

## Answers to the questions asked

1. `check-published` is in neither `make check` nor CI, so main stays
   green. But as written the gate stays red after 0.2.0 too (finding 1).
   Record 0.1.0's leak as a named, counted exception in its entry.
2. Reproduced: origin/main leaks 4 to 34 resources over 12 orders, the
   branch none. The fix holds in seven orders the implementer did not try.
3. The statics and `SAID` keep their behaviour. No `:=` changed a type.
   The two instance-method rewrites do not keep it (finding 2).
4. The plant is refused, and with the leak reading removed both
   self-tests fail. An empty load passes `load_every_class`, and the
   `kit` step drops the counts that would catch it (finding 3).
5. The lint is cheap (about 20 lines, exact on both trees). The owner
   chose a follow-up, so it needs a task opened now (finding 4).
