# Status

The index. One row per task; the task file holds everything needed to do it.
The topmost `## Resuming after` section is the next session's prompt.

## Milestone 1 — the vertical slice

A playable minimum where three techniques actually decide something.

| # | Task | State | Notes |
|---|---|---|---|
| T0 | Bootstrap: pinned Godot on the large disk | done | 4.7.2-stable, SHA-512 verified |
| T1 | Gates before the code | done | 14 gates, all in `make check` |
| T2 | `ai_core` and the board | done | reviewed three times; see the wave 07 record |
| T3 | `ai_search`: A\*, BFS, DFS, Dijkstra | done | 3 vectors and a 300-board property check |
| T4 | `ai_planning`: STRIPS, and a PDDL reader in Python | done | 8 steps, 14 states; 3 vectors read from both languages |
| T5 | Dataset and training (Python) | done | 87.8% against a 69.0% baseline, and 81.8% for a lookup table |
| T6 | `ai_learning`: inference, and the attack/retreat decision | done | 4 vectors read from both languages; invariant 6 finally has a gate |
| T7 | Close the slice: docs, ADRs, `make release` | todo | needs T3, T4, T6 |

## Milestone 2 — three games, three families of technique

Each game is chosen for the technique it makes obvious. The order is not
arbitrary: strategy finishes what T4 starts, stealth is the cheapest to build
and teaches the most per hour, and the fighting game is last of the three
because hitboxes and frame timing are a great deal of work that is not AI.

| # | Task | State | Notes |
|---|---|---|---|
| T8 | A board you can read | todo | T2's manual check failed; five measured defects |
| T9 | Art that is not a coloured square | todo | CC0 now, generated later, and an ADR |
| T10 | The tactical scenario | todo | five units, two towers, terrain that matters |
| T11 | The planner plays | todo | STRIPS drives a faction; needs T4 |
| T12 | Three difficulties, honestly | todo | horizon and depth, never cheating |
| T13 | `ai_fuzzy`, from a library that already exists | todo | ported, not reinvented |
| T14 | The stealth scenario | todo | perception, suspicion, influence maps |
| T15 | `ai_behaviour`: the three ways to decide | todo | FSM, tree, GOAP, beside STRIPS |
| T16 | The fighting scenario | todo | mostly not AI, and says so |
| T17 | The opponent model | todo | n-grams you can print |
| T18 | Behaviour cloning, and what a learned model buys | todo | the comparison is the task |
| T21 | Every example can be watched | todo | **before T8**: the standing rule for every example after it |

## Milestone 3 — real time, last

Deliberately last. It needs the content of T10, the difficulty knobs of T12, a
second state core, and everything the three earlier games taught about making
an AI legible. Built first it would have been a large pile of code with no
lesson in it.

| # | Task | State | Notes |
|---|---|---|---|
| T19 | The real-time core | todo | starts by trying to prove itself unnecessary |
| T20 | The RTS demo | todo | build orders against the clock, fog of war |

## Milestone 4 — driving, which is the first thing not on a grid

A fourth game, after the three strategy ones and after the RTS, because that is
the order the owner wants to build them in. It earns its place by teaching a
family nothing before it does: every decision in this kit so far picks a cell
or an action, and a car picks *how hard to turn, right now*.

It is also the genre where difficulty most often cheats, which makes it the
best place to show the T12 rule holding under pressure: the hard car is hard
because it is driven better, and a command proves every car runs one physics.

| # | Task | State | Notes |
|---|---|---|---|
| T22 | `ai_steering`: not on a grid | todo | seek, arrive, pursue, avoid; needs T21 |
| T23 | The racing demo, three honest difficulties | todo | no rubber-banding, and a gate that says so |

---

## Resuming after 2026-10-13 (wave 18)

**What landed.** T6: `godot/addons/ai_learning/` loads the weights Python
published and does nothing but infer. `LearnedModel` is `w·x + b` and a
sigmoid; `ModelFile` refuses a malformed file in one sentence with a code and
hands back *no* models rather than half of one; `BoardFeatures` reads the four
combat and four capture features off a live `BoardState`; `LearnedPolicy`
compares one probability against one threshold and takes the lower of two
predicted capture times. Blue in `make run` is played by it and says on screen
what it decided and the number it decided on. `check_no_training.py` gives
invariant 6 the gate it has never had, and `spec/vectors/learning/` holds the
two languages to the same rows and the same arithmetic.

**Two of the four combat features cannot be computed from a board.** How near
counts as near, and what a unit with no living friends reports -- and the
second is the *training* board's width, so a game helpfully reporting its own
would say "far" where the data said "nobody is coming". They are published in
`weights.json` now, with the range of terrain the data covered, and the game
reads them rather than keeping a copy. A number two languages must agree on,
living in two files, is a number that will one day differ.

**The bug worth remembering is the one no vector could have caught.**
`_nearest_friend` seeded its search with the sentinel instead of falling back
on it, so "I am alone" and "my nearest friend is seventeen away" were the same
number. The two board-carrying vectors are 5x4 and 6x4 -- longest distance 8,
sentinel 15 -- and the board `make run` ships is 12x8, where it reaches 18.
**A conformance vector only tests the range its board can reach.** There is a
fourth vector now, on a board twenty wide, and it goes red against the old
code.

**The sentinel is clean by luck, not by design.** Over the 2937 training rows
the real distances run 1 to 11 and none reaches 15 -- but the simulator's
geometry permits 16. Worth knowing before T18 leans on that feature.

**Six rules were deletable with every gate green**, found by the review
deleting them: the whole of `_affordable` (the only thing making every
returned move legal -- no test had ever produced a route the unit could not
pay for), two tie-breaks, the reach boundary, and two of `ModelFile`'s
refusals. Each has a test now, and each test was then run against the mutation
that motivated it rather than assumed to work -- one of them turned out to be
hidden behind an earlier failure in the same suite, which is the gdUnit4 trap
`CLAUDE.md` already warns about.

**T6's headline acceptance command proves less than it reads like.** The three
decision scenarios stayed green under all five mutations of the feature
extraction. They are about nerve; the arithmetic is the vectors' job, and the
file says so now.

**A measurement that belongs in anyone's Godot notes:** the static
`JSON.parse_string` prints an engine error of its own before returning null,
where `JSON.new().parse()` returns the code quietly and hands over the
message. Found because a *passing* test printed a stack trace. Written up in
[docs/godot/reading-json-in-godot.md](../docs/godot/reading-json-in-godot.md).

**Not proven.** The manual check is a person's job: whether the retreat reads
as a decision rather than a bug, and whether the overlay makes the probability
legible. Nothing is profiled. `enemy_units` has no three-faction meaning in
either language -- documented and pinned, not solved.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner -- this wave added four and then cut them, so
the count is unchanged. Planning and learning still have no pages under
`docs/`, so `check_tiers.py` sees neither lesson until T7. The `doc-meta`
blocks in `spec/vectors/*/README.md` still declare a `half_life` the docs gate
does not know. Nothing enforces a line width. And the search and planning
vector runners still use the noisy JSON parser.

**Next: T7** -- close the slice: the docs pages that make `check_tiers.py` see
planning and learning at tier 1, the ADRs, and `make release`. It is the last
task in milestone 1.

Read tasks/T7-close-the-slice.md next, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-13 (wave 15)

**What landed.** T5: `python/gameaikit/dataset/` simulates games with a fixed
policy and writes down every fight and every captured node -- 1500 games give
2937 combats and 1029 captures -- and `python/gameaikit/training/` fits a
logistic regression to *will this attack work* and a linear one to *how long
will this node take*, by gradient descent, standard library only. `make train`
writes `dist/weights.json` and a readable `weights.txt`; `make test-models`
runs the five acceptance commands and is part of `make check`.

**Combat is dice rather than a formula, on purpose.** If the chance of winning
were a logistic function of the features, a logistic regression would recover
the line somebody wrote three files away and the lesson would be circular. The
model is right about 87.8% of held-back fights against 69.0% for always saying
the attacker loses, and every weight has the sign the simulator's rules imply.

**The two models share one update rule.** Log loss through a sigmoid and
squared error through a linear prediction have the same gradient with respect
to the weights -- exactly for the first, up to a factor of two for the second,
which disappears into the learning rate. That is why there is one `fit` and not
two, and the factor is now written down because the file exists to be rederived.

**The majority baseline was flattering the model by fifteen points.** The
features are small integers, so 2937 rows cover 976 distinct vectors and 83% of
held-back rows have an **exact twin** among the rows trained on. A lookup table
of training rows scores 0.8177 where the majority class scores 0.6900 and the
model scores 0.8780. The report publishes all three now. Four weights cannot
memorise 976 answers so this score is honest -- but **T18's behaviour cloning
has capacity, and must be read against the table rather than the majority**.

**The control does not catch what T5 said it catches.** The task file claimed a
shuffled-label run catches a leak in the features. Both leaks were planted and
measured: the label appended to every row scores 1.0000 honestly and exactly
the baseline shuffled, and a contaminated split scores 0.8794 honestly and
exactly the baseline shuffled. The control **passes both**, because shuffling
destroys the leaked relationship along with the honest ones. It is still worth
running -- it tests that the score is measured against labels the fitting never
saw -- and the leaks themselves now need `--assert-no-leak`, which asks the two
questions directly.

**Thirteen findings from two reviews**, in
[docs/reviews/15-dataset-and-training.md](../docs/reviews/15-dataset-and-training.md).
The two worst were in the two places this wave is about: nothing had ever built
a board and looked at the feature row it produced, so eight mutations changed
the data in silence; and the leak check's "suspiciously perfect" rule was gated
on the model being logistic, so planting the label into the *capture* features
gave a model wrong by 0.0000 turns and nothing objected. Both are pinned now,
with twenty-two mutations run red across the two halves.

**Two numbers that were about the measuring rather than the thing.** A
published 0.8808 came from a 500-step probe where the pipeline fits 2000 and
gives 0.8794. And an earlier convergence measurement was five runs of the same
step count, because `steps: int = STEPS` in a signature captures the constant at
import. Both corrected; both worth remembering before quoting a number from a
scratch script.

**Not proven.** The manual check is still a person's job: whether the weight
dump explains, from those numbers alone, what the model learned. Nothing is
profiled. The "no friends left" sentinel on a fifth of combat rows is
documented rather than fixed -- capping it instead scores 0.885 against 0.878,
five rows in seven hundred, and every alternative is arbitrary in its own way.

**Still open, and carried forward.** The eleven over-long addon headers from
wave 07 still wait on the owner. Planning and learning have no pages under
`docs/`, so `check_tiers.py` sees neither lesson until T7. The `doc-meta`
blocks in `spec/vectors/*/README.md` still declare a `half_life` the docs gate
does not know. And a new one: **nothing enforces a line width**, the tree
breaks 88 columns in both directions, and mechanical wrapping made it worse --
either it becomes a rule with a gate or it stops being raised in review.

**A trap worth adding to CLAUDE.md, which is the owner's file:** mutating a
Python file in place can alias a `.pyc` written in the same second and **fake a
green**. Run mutation sweeps with `PYTHONDONTWRITEBYTECODE=1` or in a clone.

**Next: T6** -- `ai_learning`: the addon loads `weights.json` and does nothing
but infer, the decision gets wired into the game's AI turn, and
`check_no_training.py` finally gives invariant 6 the gate it has never had. The
conformance vector there is the one that matters: the GDScript inference and
the Python training have to agree on the same arithmetic, and the weights are
published rounded to six decimals so that they can.

Read tasks/T6-ai-learning-and-the-decision.md next, then: make check, write the
review record, make wave-merge.

## Resuming after 2026-10-12 (wave 14)

**What landed.** T4: `ai_planning` -- `WorldState`, `StripsAction`,
`StripsPlanner` and `PlanResult`, with the game's domain written out in full in
`game_domain.gd`. Forward state-space search over worlds rather than cells: a
queue, so the first plan found has the fewest actions; a visited set, because
several routes reach the same world; and a budget, so "no plan" can say whether
the **space** was exhausted or the **search** was. `python/gameaikit/pddl/`
reads a domain somebody else wrote, in propositional STRIPS only. Three vectors
in `spec/vectors/planning/`, each a JSON file beside two PDDL files: GDScript
plans over the JSON, Python asserts the PDDL says the same thing, and the
runner replays every plan rather than reading the planner's own `solved`.

**The domain is the lesson.** The barracks and the unit are paid for out of one
bank, so the node has to be mined twice: eight steps, 14 states. A reactive rule
that trains a unit whenever it can afford one never builds the barracks and
never attacks. Checked against an exhaustive enumeration written from the JSON
with no repo code in it -- 8 is the shortest, and the same sequence.

**The review found the claim the whole addon rests on was pinned by nothing.**
Turning the frontier into a stack -- `pop_front` to `pop_back`, one word -- left
118 unit tests, 400 property trials and 3 conformance vectors green. A stack
returns four actions where three exist, so it is a wrong answer and not an
equivalent mutant. The test named for the shortest-plan claim forked at the
*start*, where the goal is generated during the first expansion whichever end
of the frontier is read.

**And the property written to fix that could not see it either.** The first
generator -- eight predicates over six actions -- produced chains: 66 of 400
solvable and no two routes of different lengths to the same world. Six
predicates over twelve actions forks: 218 solvable, 156 plans measured against
an exhaustive search that shares no code with the planner, 19 of them failing
under a stack. **A property is only as good as the inputs that reach it**, and
that is the sentence this wave cost most to learn.

**Fifteen findings in all**, in
[docs/reviews/14-ai-planning.md](../docs/reviews/14-ai-planning.md). Five more
in the PDDL reader that it accepted after promising to refuse: a section written
twice silently kept the second, `:effect (and)` walked past the refusal written
for an action that does nothing, a bare word was read as a predicate, a
duplicate action name was accepted where the cross-language comparison is keyed
by name, and `:parameters` could be missing entirely. Nine rules in
`PlanningVector` and seven in the reader had **no planted case at all** --
deleting them left every gate green, under headers claiming the opposite.

**Two things T3 left behind, found by the re-read the wave 08 note asked for.**
The search conformance runner never checked that a path **ends at the goal** --
every rule it had was about the steps, so a legal stroll to the wrong cell
conformed, in work two reviews had passed. And `check_readability.py` matched
neither of its patterns against `static func`, so it had been reading
`search_vector.gd` -- a file that is nothing but static functions -- as empty.
Fixing the pattern produced no cascade: the existing tree was clean, and the
only two findings were in this wave's own new files.

**Not proven.** T4's manual check is still a person's job: whether someone who
has never seen STRIPS can read `game_domain.gd` and tell what the AI is
reasoning about. Nothing has been profiled; `WorldState.key()` sorts and joins
on every generated state, which is the obvious cost and has not been measured
against anything.

**Still open, and carried forward.** The eleven over-long addon headers from the
wave 07 review are still waiting on the owner. Planning has no page under
`docs/`, so `check_tiers.py` cannot see the lesson at either tier until T7. The
`doc-meta` blocks in `spec/vectors/*/README.md` declare a `half_life` the docs
gate does not know, and no gate looks outside `docs/` to say so.

**Next: T5** -- the dataset and the training, which is the first task whose
output is a *file* rather than code: Python trains and emits weights, GDScript
only infers, and `check_no_training.py` is the gate invariant 6 still does not
have.

Read tasks/T5-dataset-and-training.md next, then: make check, write the review
record, make wave-merge.

## Resuming after 2026-10-12 (wave 8)

**What landed.** T3: `ai_search` with breadth-first, depth-first, Dijkstra and
A\* over `GridGraph`, each implementing `Pathfinder`. A `SearchResult` that
carries what was expanded and what was still waiting. Three conformance vectors
in `spec/vectors/search/` with a runner, a property check over 300 random
boards, and a demo that draws the expansion in the order it happened. `make
check` is green and now includes `make test-vectors` and
`make test-search-properties`, both wired into CI as well.

Also here, because T3 could not be trusted without it: the fixes from **two**
independent reviews of `ai_core`, which was merged in wave 7 with a review that
arrived truncated. Mixing them into this branch rather than cutting a separate
wave is a deliberate exception -- A\* is wrong on a board with a negative cost,
and that board was buildable.

**The property check found a defect instead of confirming the code.** The claim
T3 asks for is that A\* expands no more cells than Dijkstra. Over 300 random
boards the costs agreed everywhere -- the heuristic is admissible -- and A\*
expanded **more** on 14 of them, which is the reverse of the reason it exists.
Neither costed search had a closed set, so a cell improved after being queued
was taken off the frontier twice and `expanded` was counting pops rather than
cells. That is also what the demo would have drawn. With the guard: 0 of 300.

**Three things the reviews found that were defects rather than gaps.** A
negative terrain cost was legal and *refunded* movement -- a unit with three
points finished a move with eight -- and it broke the one guarantee A\* offers,
since Manhattan distance is admissible exactly because no step costs less than
one. A cost is now `BLOCKED` or at least one, so the condition `astar.gd`
carried in prose is a rule. Two units sharing an id walked through each other
and **stacked on one cell**, because the occupancy rule compared ids rather than
identity. And `end_turn(0)` was a modulo-by-zero engine error returning null, on
the one type whose `apply` argues against exactly that.

**A test whose expected value is also the broken value measures nothing.** Two
of this session's own tests were that: one asserted a copy keeps whose turn it
is while ending on faction 0, so a copy hardcoding 0 passed; one asserted a
closed set on a board where no cell is ever re-queued. Both were found by
mutation and both are rewritten -- the second against a 4x4 board that was
*searched for* rather than invented.

**One mutation is recorded rather than closed.** Deleting the lower bound in
`GridGraph.contains` does not fail the suite, it **hangs** it: `neighbours`
hands back cells below the board and the searches walk downwards forever. On CI
that reads as a slow job rather than a broken one. The sentence is in the doc
comment of the rule that prevents it.

**Not proven.** The demo's legibility is still a person's job -- five tests hold
that it loads, that stepping replays rather than re-runs, and that its board
actually makes the four disagree, which is the demo's own premise. Nothing has
been profiled: `_cheapest` and the closed set are both linear scans, documented
as such, and the benchmark that would justify a heap has not been run because
the answer to needing one is `AStarGrid2D`.

**What its own review then found, after all of that.** Twelve findings, in
[docs/reviews/08-ai-search.md](../docs/reviews/08-ai-search.md), and the first
is the one worth reading: `dijkstra.gd` carried the textbook improvement branch
and its header called that branch "the line worth reading them for". Measured
with a counter, it fires **0 times in 250 boards** -- against 165 for A\* on the
same boards -- because `_cheapest` reads `g` as it is now, so the cell taken off
is already final. The duplicate guard beside it was dead for the same reason and
its comment was a byte-for-byte copy of A\*'s, citing A\*'s measurement as its
own. Both are gone and the header says what is actually true, including that a
binary heap keyed at insertion brings both straight back.

Next to it, a retraction: `astar.gd` claimed a stale `f` "would send the search
the wrong way". Freezing `f` across 241 boards changed neither the cost nor the
expansion count, not once. The line stays, for a different and honest reason.

Three more worth knowing before touching this code: **no search validated its
start** (`from = (-1, 2)` came back `reached`, with a path walking in from
nowhere, and the vector runner accepted it because every *step* was legal); the
runner was **a gate with no planted case for any of its rules**, which
`lint-selftests` cannot help with because it only ever looks inside `scripts/`
and the runner is GDScript; and the demo **hid the thing it exists to show** --
the
expansion rectangles buried the mud band exactly when the picture completed.

**Next: T4** -- `ai_planning`: STRIPS, and a PDDL reader in Python. It is the
first task with a Python half, so `make test-python` stops being a placeholder,
and the first addon that must not reach into `ai_search` -- the gate for that
has been inspecting a real addon only since wave 7.

**Start T4 by reviewing T3.** Three reviews in this project have now each found
real defects in work the previous one had passed over or never reached. That is
the argument for the rule, not against it.

**Milestones 2 and 3 are written and queued**, thirteen task files from a
board you can read through to an RTS. Three decisions are already taken and are
in the task files rather than left to be rediscovered: the strategy game is
**turn-based first**, because `BoardState.apply` copies the units into a new
state and that is right for search and wrong for two hundred units at sixty
frames a second; art is **CC0 now and generated later**, because hours spent
fighting a diffusion model are hours not spent on the AI; and the **RTS is
last**, after all three games.

**T8 is first, and it exists because the manual check worked.** The owner ran
`make run` and could not tell what he was looking at. That is T2's
`## Manual check` doing exactly what it is for, and the task file carries the
five measured reasons rather than "make it nicer".

**One finding is open and waiting on the owner**, recorded at the end of
[the wave 07 review](../docs/reviews/07-ai-core-and-the-board.md): eleven of the
twelve addon files have headers longer than the 5-10 lines `CLAUDE.md` asks
for, several by two or three times, and the longest are long because they carry
measurements this project asked for. Either the headers get cut or the rule
gets rewritten, and a session failing a rule should not be the one to quietly
change it.

---

## Resuming after 2026-10-12 (wave 7)

**What landed.** T2: `ai_core` and a board you can play with a mouse.
`GridGraph`, `Unit`, `Move` and `BoardState` under
`godot/addons/ai_core/`, two interfaces (`Pathfinder`, `DecisionPolicy`) that
say what an implementation must guarantee, a `TileMapLayer` view under
`godot/game/`, and 21 tests. `make check` is green, engine included.

**The gates stopped inspecting nothing.** Before this wave `check_addon_deps.py`
and `check_renderer.py` printed that they had found no addons and no scenes;
both now read real files and say nothing, which is the first time either has
actually held its invariant. The licence gate fired the moment `ai_core`
appeared, exactly as designed: an addon that would ship without LICENSE and
NOTICE. Both are in the folder now, as copies rather than symlinks, because the
promise is that you copy the folder and it works.

**Three design decisions worth knowing before T3.**

- **A `Move` carries its own path.** The board rules on whether a walk is
  legal; it never works one out. That is what lets `ai_core` hold no
  algorithms: A\*, a planner and a human clicking a tile all produce the same
  type. `ai_search` fills in the route and nothing else changes.
- **`apply` returns a new state**, and `why_refused` returns a sentence rather
  than a code. A search tries illegal moves constantly, so refusing must be
  cheap and must not fill the log with engine errors.
- **The path excludes the starting cell.** Cost is paid on entering a cell. The
  first version included the start and every cost calculation grew an "except
  the first one" clause, which is where off-by-one bugs live.

**Measured, not assumed: a failing gdUnit4 suite hides the tests after it.** A
suite of ten whose third test fails reports three cases and stops; the other
seven are not run and are not counted as skipped. Found by hitting it three
times while writing the board tests. It is in `docs/godot/addon-anatomy.md`,
because a red run that lists one defect is not a red run that lists them all.

**Two of this wave's own tests were wrong in the same way**, and the board
caught them: both walked a unit straight through the square the *other* unit was
standing on, so they passed or failed for a reason that had nothing to do with
what they claimed to test. The movement-points test now turns north, and the
terrain test rounds the top of the board.

**What the review changed, and what it could not.** A fresh context found three
things, the worst of them in the interfaces: they claimed GDScript has no
`abstract` keyword and used `push_error` with a default return instead. It has
`@abstract`, enforced at load time -- measured twice -- and the defaults those
files returned were values their own contracts define as legitimate answers, so
a forgotten override looked exactly like an implementation that had decided to
do nothing. `ai_search` is the next task and the first caller. See
[the review](../docs/reviews/07-ai-core-and-the-board.md) for the other two and
for the five this session found afterwards.

**That review is incomplete and the record says so.** The reviewer's report was
truncated in transport partway through its third finding, and three requests for
the rest went unanswered. It said 13 of its 35 mutations survived; which 13 was
in the part that was lost. This wave therefore merges knowing a context that did
not write the code found things nobody has read. The 21-mutation sweep run
afterwards does not replace it: it was written by the session that wrote the
code, which is the symmetry invariant 12 exists to break.

**Not proven.** Nothing has pathfound anything: the scene moves a unit one cell
per click, which is honest -- a route is a search and the search is T3. The view
is checked by four tests for the half that is mechanical (the tile set builds,
a cost chooses a tile, a repaint forgets the old board); whether the board is
*legible* is still the manual check in T2 and still needs a person.

**Next: T3** -- `ai_search`: A\*, BFS, DFS and Dijkstra over `GridGraph`,
implementing `Pathfinder`. It is the first addon that must not depend on
another, so `check_addon_deps.py` gets its first real question, and the click
that moves one cell becomes a click that moves along a route. Three things it
needs that do not exist yet: a `make test-vectors` target (and therefore a CI
step, or `check_workflow.py` refuses it), `godot/demos/search/`, and
`godot/test/search_properties.gd`, which T3's acceptance runs directly with
`-s` rather than through gdUnit4.

**Start T3 by reviewing T2.** Not as a formality: the review that should have
covered it is missing its tail, and `ai_core` is what every later lesson is
built on.

---

## Resuming after 2026-10-12 (wave 6)

**What landed.** The last four gates and T1's close (`check_addon_deps.py`,
`check_tiers.py`, `check_links.py`, `check_workflow.py`), two rounds of fixes,
ADR 0005, and the review of all of it in
[docs/reviews/06-the-last-gates.md](../docs/reviews/06-the-last-gates.md). Nine
confirmed findings, all fixed on the branch. `make check` is green, engine
included.

**The session that wrote this wave ended before it could finish**, and what it
left behind was enough to resume from: the branch, the task files, and a last
commit message that named the open decision instead of leaving it to be
rediscovered. That is the resuming log doing its job, and it is worth saying
once -- the cost of writing the paragraph was far below the cost of the session
that would have had to reconstruct it.

**Wave 5 has no section here**, and that is not an omission being hidden: its
record went to `docs/reviews/05-the-wave-flow.md` when the review flow landed,
and nobody wrote the STATUS entry. The reviews directory is now where a wave's
findings live; this log is for what the next session needs to pick up.

**The gate for invariant 10 was violating invariant 10.** Three of the nine
findings are that, in three places: it exempted its own file from its own scan,
so the one spot where a match gets quoted while being documented was the one
spot nothing watched; the same quote had reached two commit messages, which is
what turned `make check` red; and its line-break planted case never reached the
rule it was filed under. The two unmerged commits were rebuilt to remove the
term from the message *and* the file content, and the backup branch was deleted
-- a ref holding the old blobs is the term still being in the repository.

**A question about Godot was settled by measuring it.** `check_addon_deps.py`
only knew the `res://addons/other/` spelling of a cross-addon dependency. On the
pinned 4.7.2, `preload("../ai_b/x.gd")` from inside `addons/ai_a/` parses,
resolves and runs. The gate catches both now, and the measurement is in
`docs/godot/addon-anatomy.md` with the engine version, where the six-month
half-life rule can reach it.

**Still open, and it is the owner's call, not a defect.** Rebuilding those two
commits left the old objects unreachable but still in `.git`. `git gc
--prune=now` removes them; this session did not have permission to run it.

**Not proven.** Four of the gates have still never seen the thing they are
about: there are no addons, no scenes and no lessons above tier 1, and three of
them say so on every run rather than passing in silence. The only thing standing
behind this wave's fixes is a mutation sweep written by the same session that
wrote the fixes.

**Next: T2** -- `ai_core` and the board. The first real GDScript in the
repository, and the first time `check_readability.py` and `check_addon_deps.py`
look at something instead of printing that they found nothing.

---

## Resuming after 2026-10-12 (wave 4)

**What landed.** `check_acceptance.py` and `check_status.py`, and the eight task
files T0–T7 they check. `make check` runs ten gate self-tests plus both suites,
green. T0 and T1 were written retroactively rather than excused as bootstrap
rows: their Acceptance blocks record the commands that were actually run,
including the two negative controls.

**The acceptance gate caught two bugs in itself, and then one in me.**

1. Its first non-terminating rule used a lookahead for `--headless` after the
   word `godot`. In `--path godot` the word appears twice, and the second
   occurrence has no `--headless` after it, so a correct criterion was reported
   as broken. Replaced with a per-line check that only matches Godot in command
   position, which is also easier to read.
2. Its "the assertion sits in the comment" rule required a pipe before `grep`,
   so the same mistake written without a pipe passed. Broadened.
3. Then it rejected this repository's own T3, because the Acceptance prose used
   the word "plausible". That was the rule working: Acceptance prose is exactly
   where a human verdict hides. The sentence was rewritten, not the rule.

**Two dangling references, deliberately.** T2's acceptance calls
`check_addon_deps.py` and T7's calls `check_tiers.py` and `scripts/release.py`.
None exists yet. They are named now so that writing them is part of finishing
T1, rather than something remembered later; running those tasks' acceptance
today fails on a missing file, which is the correct state for a `todo` task.

**Next, to finish T1:** `check_addon_deps.py` (invariant 2: no addon imports
another), `check_tiers.py` (invariant 5: no lesson above tier 1), then
`check_links.py` and `check_workflow.py` ported from `desk-panel`,
`CONTRIBUTING.md`, and `.github/workflows/ci.yml` running the same strings the
Makefile does. Then T2, which is the first real GDScript.

Correction to the line that was here: it predicted the link gate would flag
`github.com/boscocp/game-ai-kit`. It does not, and the prediction was wrong --
that URL appears only in `NOTICE`, which is not markdown, and inside backticks
in this file. There is no markdown link to it, so there is nothing for the gate
to follow. No exception is needed.

---

## Resuming after 2026-10-12 (wave 3)

**What landed.** Three gates: `check_readability.py` (invariant 1, mechanical
half), `check_doc_freshness.py` (the three half-life layers), and
`check_no_employer_refs.py` (tree and history). `make check` runs eight gate
self-tests plus both test suites, and is green.

**What reading the documentation first changed.** Four Godot facts were checked
against the 4.7 docs rather than assumed, and one of them was a live bug:

- a `plugin.cfg` requires an `@tool` script extending `EditorPlugin`. The
  library addons here need none, because `class_name` registers a class
  project-wide with no plugin. `check_license.py` had been using `plugin.cfg` as
  the marker for "shippable addon", so a library addon was **skipped in
  silence** -- a gate failing open. Fixed, and the self-test case inverted.
- the Asset Library does not require `plugin.cfg`, does require `LICENSE` at the
  repository root, and **does** offer Apache-2.0. The tutorial page lists a few
  licences as examples and briefly looked like it ruled Apache out; the live
  filter has it.
- `TileMapLayer`, not `TileMap` -- the latter is deprecated in 4.x.
- `AStarGrid2D` is engine core in C++ with four heuristics, which is what the
  README's "when not to use this" should point at.

All four are in `docs/godot/addon-anatomy.md` with source URLs and a
`verified_on` date. `CLAUDE.md` gained the rule: read the documentation for the
pinned version first, then measure to confirm.

**How the employer gate avoids the obvious contradiction.** A gate searching for
a company name must contain that name, and a file saying "never mention X" is a
mention of X. The repository stores **salted SHA-256 hashes** instead, with a
prefix rule so one stored term also catches its compounds. `--add-term` reads
from a hidden prompt, so adding one never puts it in a file or a shell history.
The list is seeded with a single term derived from the work email domain;
**internal repository, client and project names are not on it yet** and should
be added with `--add-term`.

**Not proven.** The readability gate has only ever seen `smoke_test.gd`, which
is exempt from its doc-comment rule. It was confirmed to find real files by
planting an untyped function there (five findings, exit 1), but it has never
run against an addon, because none exists. The employer gate's history scan
walks every blob ever committed, which is fast on four commits and has not been
timed on a real history.

**Next:** `check_acceptance.py` and `check_status.py` (port from `desk-panel`,
and note that the former has **no** `--self-test` there -- the port must gain
one, and its non-terminating-command rules are about `adb` and a Python server,
which here means a Godot invocation without `--headless`). Then
`check_addon_deps.py`, `check_tiers.py`, `check_links.py`, `check_workflow.py`,
CONTRIBUTING.md and the CI workflow. After that, T2.

---

## Resuming after 2026-10-12 (wave 2)

**What landed.** gdUnit4 v6.2.2 installed by `make bootstrap`, pinned by tag and
verified by SHA-256. Two tests in `godot/test/smoke_test.gd`, and
`make test-godot` is now part of `make check`. The licence gate learned to tell
a third-party addon from one of ours.

**A decision reversed before it became history.** gdUnit4 was first vendored
into the repository. Staging it showed **509 files** of someone else's code
about to enter a repository whose premise is that you can read it. Switched to
install-at-bootstrap and gitignored; `docs/adr/0004` records why, including the
alternatives (submodule, writing a small runner) and what it costs: a fresh
clone must bootstrap before it can test.

**Three things the previous section got wrong, found by running them.**

1. `make test-godot` did not work. It ran `--path godot --quit` on a project
   with no main scene, which exits 1 -- and, despite `--headless`, popped a
   **zenity dialog** on the desktop. Replaced with a script entry point.
2. A rule was about to be written claiming Godot's exit code carries no
   information. Measured instead, and it is false: a parse error exits 1 and
   `quit(3)` exits 3. Godot propagates. The rule was not written.
3. gdUnit4 **refuses headless mode** unless given `--ignoreHeadlessMode`,
   because Godot does not deliver `InputEvent` there. That is now a standing
   constraint: a test in this repo must never depend on simulated input.

**What the licence gate found.** Vendoring gdUnit4 made `check_license.py` fire:
it would have required this project's NOTICE inside someone else's addon. The
gate now has a declared `VENDORED` table -- a vendored addon must carry its own
licence and must **not** carry ours, since our NOTICE in their folder claims
authorship we do not have. Declared one by one, never inferred.

**Still not proven.** The test suite has two tests and neither touches a line of
this project's own code, because none exists yet. What proves the runner can
fail is the planted failure: changing `2 + 2 == 4` to `== 5` gives exit 100, and
restoring it gives 0. Re-run that before trusting any future green.

**Known dangling reference.** `NOTICE` and `README.md` point at
`https://github.com/boscocp/game-ai-kit`, which returns 404 -- the repository is
local only, with no remote and nothing published. When `check_links.py` lands it
will flag this; the URL is the intended home, so it belongs in the link
exceptions file with that reason, not removed.

**Next:** the gates still missing -- `check_acceptance.py`, `check_status.py`,
`check_readability.py`, `check_no_employer_refs.py`, `check_tiers.py`,
`check_doc_freshness.py`, `check_addon_deps.py`, `check_links.py`,
`check_workflow.py` -- then CONTRIBUTING.md and the CI workflow. Note that
`desk-panel`'s `check_acceptance.py` has no `--self-test`; the port must gain
one, and its non-terminating-command rules need replacing (they are about `adb`
and a Python server; here the equivalent is a Godot invocation without
`--headless`).

---

## Resuming after 2026-10-12 (wave 1)

**What landed.** The repository exists at `/mnt/games/gamedev/game-ai-kit`, on
the large disk. Godot 4.7.2-stable is installed under
`/mnt/games/gamedev/toolchain/`, downloaded and verified by SHA-512. `make check`
is green with four gates: `check_disk_layout.py`, `check_renderer.py`,
`check_license.py` and the `bootstrap.sh` usage self-test. Three ADRs are
written (engine, toolchain layout, licence). LICENSE, NOTICE, README and
CLAUDE.md are in place.

**What the bootstrap found.** Enabling Godot's self-contained mode was assumed
to be enough to keep the toolchain off the small disk. It is not: with `._sc_`
in place, a bare `--headless --import` still recreated
`~/.local/share/godot/app_userdata/`. `XDG_DATA_HOME` covers the gap. Both
mechanisms now live in `scripts/godot`, and `check_disk_layout.py` asserts both.
Recorded in `docs/adr/0002`.

**What is not proven.** No Godot test has ever run — `make test-godot` only
opens and quits the project, because gdUnit4 is not installed yet. No GDScript
exists at all, so `check_renderer.py` has found nothing because there is nothing
to find; its self-test is what proves it can fail. `make` collapses every recipe
failure to exit 2, so a gate's own exit codes must be read by calling the script
directly.

**Next:** finish T1. `check_commit_msg.py` is done and the hook is live
(`make hooks`); it blocks assistant attribution in both forms, so overriding the
machine's global hook costs nothing. The gates still missing are
`check_acceptance.py`, `check_status.py`, `check_readability.py`,
`check_no_employer_refs.py`, `check_tiers.py`, `check_doc_freshness.py`,
`check_addon_deps.py`, `check_links.py`, `check_workflow.py`. Port the first
few from `desk-panel`, which is the only repository code is ported from here.

### What is still only true on this desk

- The toolchain path `/mnt/games/gamedev/toolchain` is this machine's layout.
  `GAK_TOOLCHAIN` overrides it, but nobody has run the gate with that override.
- `gdtoolkit` (gdformat/gdlint) has not been tried. Python here is 3.14.7 and
  `pip` is absent; if gdtoolkit cannot be installed, the GDScript formatting
  gate is deliberately left out of M1 and recorded in an ADR, rather than
  becoming a `continue-on-error`.
