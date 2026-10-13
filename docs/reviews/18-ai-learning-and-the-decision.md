# Review: wave/18-ai-learning-and-the-decision

Two fresh contexts, one per half — the addon with the game wiring, and the
gate with the conformance vectors. Neither wrote the code. Both were asked to
mutate rather than read, and the addon reviewer found the thing this wave had
no way of noticing on its own: **a bug that only exists on a board bigger than
the one the data came from**, which is exactly the board `make run` ships.

## What was reviewed

Commit 9424a8f on this branch: `godot/addons/ai_learning/` (five files, the
published `weights.json`), the AI turn in `godot/game/main.gd` and the node
tile in `board_view.gd`, `scripts/check_no_training.py`, the three vectors in
`spec/vectors/learning/` with both halves of their runner, the four new test
suites, the `feature_conventions` block added to
`python/gameaikit/training/report.py`, and `docs/godot/reading-json-in-godot.md`.

## Findings

### The sentinel was a cap, and the vectors could not have caught it

`BoardFeatures._nearest_friend` seeded its search with
`reinforcement_distance_when_alone` and then took the minimum, which makes
**"I am alone" and "my nearest friend is seventeen cells away" the same
number** — and that number means *nobody is coming* to a model whose weight on
it is negative.

It survived writing, self-review and twelve conformance cases for one reason:
the two board-carrying vectors are 5×4 and 6×4, whose longest Manhattan
distance is 7 and 8, and the sentinel is 15. The board the game ships is 12×8,
where it reaches 18. A probe on a 40×3 board with a friend 39 cells away
printed 15 where Python prints 39.

Fixed by collecting the distance and falling back to the sentinel only when
there is no friend at all, with two tests — one past the sentinel, one alone.
A fourth vector on a board wide enough to exceed it now pins it across both
languages.

Two things measured while fixing it, both worth keeping:

- **a real distance above the sentinel is not clamped.** Terrain is, because
  "the worst ground" is a real category the data contains; this has no honest
  replacement, and reporting 15 would tell the model nobody is coming while a
  friend is on the way. It is extrapolation, and it is now labelled as such
  rather than hidden under a clamp;
- **the sentinel is only clean by luck.** Over the 2937 training rows the real
  distances run 1 to 11 and none reaches 15 — but the simulator's geometry
  permits 16. The separation between "a long way" and "nobody" was never
  designed, it was measured after the fact, and T18 should not rely on it.

### Rules that could be deleted with every gate green

Six, found by deleting them and watching 203 tests, 3 decision scenarios and
12 vector cases stay green:

| deleted | what it was supposed to hold |
|---|---|
| all of `_affordable` | that every move a policy returns is one the board allows |
| `other.id < nearest.id` | which of two equidistant enemies gets weighed |
| the `+ 1` in `reach` | that an enemy one step out of range is still a fight |
| the coordinate tie-break in `_quicker_node` | that two nodes the model cannot separate are not decided by sort order |
| `M10 model is not an object` | a weights file whose model is a string |
| `M6 a feature name that is not a string` | a feature nothing can ever match by name |

Every one of them now has a test, and every one of those tests was then run
against the mutation that motivated it: five went red for the right test, and
the sixth — the affordability cut — was verified in a one-test suite, because
a gdUnit4 suite stops at its first failure and an earlier test was catching
the mutation first.

The affordability finding is the sharpest of the six. The function is the only
thing making its own doc comment true, and no existing test produced a route
the unit could not pay for: the new one walks on ground costing 3 with 3
points, where a three-step route has to come back as one step.

### Comments that were false

- `_nearest_to` claimed ties went to the lowest id. They go to the earliest in
  `state.units`; `id` is never read. Measured with two equidistant units in
  array order `[7, 2]`, the row came from id 7. The behaviour is right — it is
  deterministic, and it is what Python's `min(...)` does — so the comment was
  rewritten rather than the code.
- `_move_at`'s `stop_short` was presented as the mechanism by which a unit
  closes with an enemy. Deleting it changed nothing: the board already refuses
  a move onto an occupied cell, so `_affordable` cuts the route there. The
  parameter is gone and the one rule is named in one place; walking at a node
  enters it and walking at an enemy stops in contact, out of the same call.
- `decision_scenarios.gd` said "every feature points one way" of a board where
  `numeric_advantage` was zero: the friend was four cells from the defender,
  outside the radius of 2, so it moved only `reinforcement_distance`. The
  friend was moved to where the sentence is true.

### `enemy_units` is a two-faction feature and now says so

Python counts `living(1 - faction)` — *the other side*, which means nothing
with three of them. GDScript counts everyone who is not mine. On a
two-faction board the two agree, and every vector is two-faction; with one own
unit, one of faction 1 and two of faction 2, GDScript gives 3 and Python's
rule gives 1. `ai_core` explicitly allows three sides.

Left as it is and written into `capture_row`'s doc comment, with a test
pinning the generalisation so it is a decision rather than an accident. The
alternative — inventing a "the other side" for a three-faction board — would
be a feature the model was never fitted on, dressed as agreement.

### The headline acceptance command proves less than it reads like

T6's acceptance is the three decision scenarios, and they stayed green under
all five mutations of `BoardFeatures`: a flipped sign on `numeric_advantage`,
terrain read from the attacker's cell, the reinforcement measured from the
defender, the nearest unit swapped for the first, and the terrain clamp
deleted. Those boards are lopsided enough that the decision survives a
mangled row.

That is not a defect in the scenarios — they are about nerve, and the
arithmetic is the vectors' job — but reading the two as one check would be a
mistake, so the file now says which is which at the top.

### Four headers this wave added over the 5–10 line rule

15, 15, 14 and 12 lines as committed. CLAUDE.md carries a standing open
finding about eleven existing headers and this wave quietly added four more.
All five are now within the rule. The rule is not mechanically checked —
`check_readability.py` exits 0 on all of them — which is the same gap the open
finding is about.

### A claim about the engine that was false in three places

The sigmoid in `LearnedModel` is written in two branches, and all three places
that mention it said the naive `1 / (1 + exp(-x))` would overflow or return an
infinity **on the GDScript side**. Measured on the pinned engine, in a
throwaway script, twice — by the reviewer and then again before rewriting the
comment: `exp` saturates to `inf` rather than raising, so the naive spelling
returns 1.0 at a logit of +1000 and 0.0 at -1000, which are the correctly
rounded answers. Replacing the two branches with the naive line leaves every
vector and every test green.

The overflow is real on the **Python** side, where `math.exp` raises around
-710 and kills a training run because one row was unusual. So the branches
stay — they make the two files read alike, which is the point of a
conformance vector family — and the three comments now say that, measured,
instead of claiming an engine behaviour that is not there.

### The vectors could not tell x-then-y from y-then-x

`two-nodes-one-army.json` claimed in its own `why` that a side averaging
terrain along a route it chose rather than the fixed one would disagree with
it. Swapping the two loops in *either* language left both suites green: of its
three cases, one moves on a single axis, another does too, and the third
happens to cost 2.0 whichever way round it is walked.

There is a fourth case now, on the same board, chosen so the two orders give
1.75 and 1.0 — and the swap goes red in GDScript and in Python.

### Four more rules with no planted case, and a code that hid them

`V7 board is not an object`, `V7 a board holding nothing`, `V7 a unit is not
an object`, and the `is_finite` half of `_is_a_number` were all deletable with
the suite green, in a file whose header says every rule has a planted case.

Worse, and found while fixing it: **every board rule answers with the code
`V7`**, so a test asserting `contains("V7")` cannot tell which of eleven rules
fired. One of the four new cases was passing through a different rule
entirely. Every board-rule assertion now names its own sentence, and all ten
were then deleted one at a time to confirm each goes red for its own test.

The same shape, in the addon: two different rules answered `M4`. The rarer one
is `M10` now.

### The gate broke its own exit-code contract

`check_no_training.py` promises exit 2 for a file it cannot read. A malformed
`weights.json` raised `JSONDecodeError` and a non-UTF-8 `.gd` raised
`UnicodeDecodeError` — both `ValueError`, neither caught, both arriving as a
traceback on **exit 1**, which is the code reserved for "violations found,
each one printed". Indistinguishable from a finding to every caller. One word
in the `except`, and two planted cases.

And one of its self-test cases proved nothing: the case for "a word inside a
string is not training" planted `"train_the_unit"`, and `train` is
deliberately *not* in the vocabulary, so the case passed whether or not
strings were stripped at all. It plants `"gradient of the hill"` now, and the
planner's domain word has a case of its own saying why it is allowed.

### Two suspicions, both acted on

- the capture model is fitted on *opening* positions and the policy asks it
  every turn, on boards with fewer units and shorter distances than it ever
  saw. There is no honest correction — unlike terrain, which has a clamp — so
  it is said: what the policy uses is the *ordering* of two nodes, and the
  ordering is the part that survives being asked out of population;
- nothing refused a terrain range the wrong way round. Both numbers can be
  positive and the pair still nonsense, and `clampi(value, 3, 1)` answers
  rather than objects. Refused now, with a planted case.

## What was done about them

Everything above is fixed on this branch. Every rule that had no planted case
has one, and **every one of those cases was then run against the mutation that
motivated it** rather than assumed to work — which caught two that were
passing through some other rule, and one that was hidden behind an earlier
failure in the same suite.

`make check` is green: 217 gdUnit4 cases, four learning vectors among three families, two property
runs, three decision scenarios.

Carried forward, deliberately:

- the sentinel's clean separation from real distances is measured, not
  designed, and `rows.py` should say so before T18 leans on the feature;
- `enemy_units` has no three-faction meaning in either language;
- the search and planning vector runners still use `JSON.parse_string`, which
  prints an engine error of its own before their own message — written up in
  `docs/godot/reading-json-in-godot.md` and left for a wave that is about
  them;
- `check_no_training.py` still cannot see a training loop written in innocent
  words. Its own docstring says so, and the reviewer confirmed it by writing
  one: the hole is the price of not having a vocabulary long enough to fire
  on good code;
- planning and learning still have no pages under `docs/`, so `check_tiers.py`
  sees neither lesson until T7.
