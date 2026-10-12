# Review: wave/14-ai-planning

Two fresh contexts, one per half, neither of which wrote the code: the GDScript
planner with its gates, and the Python reader with the vectors. Both were asked
to **mutate rather than read** — a rule whose deletion leaves every gate green
is the finding this project is arranged to catch, and between them they found
fourteen of them.

Two further findings came before the reviews, from re-reading T3 as the wave 08
record asked. Both were in work that had already been reviewed twice.

## What was reviewed

The three commits that built T4 — the `ai_planning` addon, `python/gameaikit/
pddl/`, the three conformance vectors in `spec/vectors/planning/`, the new
`make` targets and their CI steps — and the two fixes to things T3 left behind.

## Findings

### Before the reviews: two holes in work that had passed twice

**The search conformance runner never asked where a path ended.** Every rule it
had was about the *steps*: each follows the last, each lands on ground a unit
may enter. All of them hold for a path that walks somewhere else entirely, so a
search could report `reached`, hand back a legal stroll to the wrong cell and
conform. That is the same shape as the unvalidated `from` the wave 08 review
found, at the other end of the path, and it survived that review.

**`check_readability.py` could not see a `static func`.** It matched neither
`FUNC_RE` nor `OPENS_FUNC`, so the declaration was skipped whole — length,
nesting, parameter types and doc comment all unchecked. `search_vector.gd` is
nothing but static functions and the gate had been reading it as an empty file.
`VAR_RE` had always handled `static var`, which is how the hole stayed
invisible: the keyword was clearly in mind when that line was written.

### The GDScript half

**1. The one claim breadth-first makes was pinned by nothing.** `pop_front` →
`pop_back` and all 118 unit tests, 400 property trials and 3 vectors stayed
green. It is a real wrong answer — a stack returns four actions where three
exist — so `strips_planner.gd`'s header was true of the code and held up by
nothing. The test named for it forked at the *start*, where the goal is tested
during the first expansion whichever end of the frontier is read.

**2. The unit suite claimed to test the visited set and did not.** Deleting the
dedup left every case in `planning_test.gd` green; only the property run
noticed. The test that looked like it covered this tests `WorldState.key()`,
which is a different thing from the frontier's use of it.

**3. Nine rules in `PlanningVector` had no planted case** — including all three
applied to an unsolvable vector, and the half of the replay that the file's own
doc comment says exists because of the wave 08 finding. The reviewer deleted all
nine at once and both gates stayed green, under a header stating that every rule
there has a case.

**4. The property run passed on empty input.** `TRIALS = 0` printed "0 trials, 0
failure(s)" and exited 0, and so did a generator whose every goal was
unreachable — with the plan-replay half never executing once. The comment beside
it said both numbers had to be non-zero; nothing enforced that.

**5. A paragraph claimed a hung run leaves trial 0 as its last printed line.**
Nothing prints inside the loop, so a hang prints nothing at all — the exact
failure the paragraph said it guarded against.

Gaps: no shortest-plan property at all; a budget guard that cannot fire; a
condition that is always true; no planted case for the fourth thing the
readability gate checks about a static func; two doc comments that restate the
line below them and three public fields undocumented beside one that was not.

**What the review found clean, and said so:** the algorithm. It is genuinely
breadth-first over states, it does return a shortest plan, and the visited set
is sound — dedup-on-generation cannot prune a state a shorter plan needed.
Cross-checked against an independent iterative-deepening search over the same
400 domains: 0 disagreements. Every measured number in a comment is right (8
steps, 14 states, 7 actions, 8 predicates), and `game_domain.gd`'s table matches
the code row for row.

### The Python half

**6–10. Five things the reader accepted after promising to refuse them.** A
section written twice kept the second and dropped the first in silence, so a
domain whose predicates are declared in two blocks lost the first block.
`:effect (and)` parses as a non-empty list and walked past the refusal written
for an action that does nothing. An unparenthesised bare word was wrapped into
a one-item list and read as a predicate, by a function whose docstring says it
reads `(name)`. An action declared twice was accepted, and the cross-language
comparison is keyed by name, so the first declaration was checked by nothing.
And `:parameters` could be missing entirely, because `fields.get` is falsy for
absent as well as empty.

**11. `when` and `forall` were refused by dumping the parse tree.** The module
docstring claims this reader names what it refused, and a conditional effect is
the most common thing a real domain has that this subset does not.

**12. Names were compared case-sensitively.** PDDL folds case: `(At_Home)` and
`(at_home)` were two predicates here and one in every real planner — the
"parses perfectly, plans wrongly" failure this reader exists to prevent.

**13. Seven refusals had no test.** Deleting any of them left `make test-python`
green, which is the invariant 4 condition on rules written in the same session.

**14. The cross-language test could pass while checking nothing** in one shape:
a vector with an empty `actions` list compares `{}` with `{}`. Everything else
the reviewer tried — missing PDDL files, a swapped pair, a cross-wired pair, an
empty directory — went red.

**15. Both vector READMEs said a vector's `name` is "used in failure messages".**
Nothing reads it; the runners quote the file name. The claim has been in the
search README since wave 8 and was copied into the planning one.

## What was done about them

All fifteen are fixed, in three commits, each with the mutation that would have
caught it:

- the shortest-plan test now forks **one level down** with the long branch
  declared last, and a stack fails it. A shortest-plan **property** was added
  beside it — and then the generator had to be rebuilt, because the first one
  could not exercise it: eight predicates over six actions produced chains, and
  a stack passed 400 trials. Six predicates over twelve actions forks, and the
  stack now fails 19 of 156 measured plans, each measured against an exhaustive
  search sharing no code with the planner;
- a door that opens and shuts pins the visited set, on a budget of 50 so the
  red run takes 24ms rather than 24 seconds;
- nine planted cases in `planning_vector_test.gd`, each verified by deleting
  its rule; nineteen more in the Python suite, each verified the same way;
- the property run fails when every trial falls the same way, when no plan was
  measured, and therefore when there are no trials at all;
- the reader refuses duplicated sections, an empty `(and)` effect, a bare word,
  a duplicate action name and a missing `:parameters`; names the construct it
  refused, out of a table of the ones a real domain carries; folds case, on both
  sides of the cross-language comparison; and checks that every predicate an
  action names is one the domain declared, which is the classic PDDL typo;
- two dead branches deleted rather than left to look like checks, and the false
  sentence about a hung run replaced with what actually happens.

`make check` is green: 128 Godot cases, 72 Python tests, both vector families,
both property runs.

## What is still open

**The manual check in T4 has not been done by a person.** "Read the domain file
and decide whether someone who has never seen STRIPS could tell what the AI is
reasoning about" is not something the author of the file can answer.

**Invariant 5 has nothing to enforce yet for this lesson.** STRIPS is taught at
tier 2 — the addon — and `check_tiers.py` reads the `teaches:` field of pages
under `docs/`, where planning has no page at all. The tier-1 half exists in the
code (the PDDL reader is standard-library Python), but until T7 writes the page,
the gate cannot see either half. The README line claiming tier 1 could "run the
planner" was corrected to what tier 1 actually gives you today.

**The doc-meta block in `spec/vectors/*/README.md` is decoration.** It declares
`half_life: structure`, which is not one of the three values
`check_doc_freshness.py` knows — and no gate ever looks outside `docs/`, so
nothing says so. Either those blocks should be checked or they should go.

**`python/tests/test_placeholder.py` says it should be deleted in T5**, and its
stated purpose — keeping `make test-python` honest before the first real module
— is spent now that there is one. It was left for T5 to remove, as written.
