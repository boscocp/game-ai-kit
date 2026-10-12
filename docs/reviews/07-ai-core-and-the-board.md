# Review: wave/07-ai-core-and-the-board

Reviewed 2026-10-12 by a context that did not write the code, running against
`60add0d`, with instructions not to trust the planted cases — they were written
by the same context as the board, which is the symmetry the apparatus exists to
break.

**This record has a hole in it, and the hole is named rather than papered
over.** The reviewer's report arrived truncated by the transport, partway
through its third finding. Three further requests for the remainder — each
shorter and more constrained than the last — went unanswered; the reviewer
reported itself idle and sent nothing more. So findings 1 to 3 below are its
work in full. Everything after them is this session's own, which is a weaker
thing and is labelled as such: the author checking the author.

## What was reviewed

The diff `main..60add0d`: `ai_core` (`GridGraph`, `Unit`, `Move`, `BoardState`,
and the `Pathfinder` and `DecisionPolicy` interfaces), the `TileMapLayer` view
and main scene under `godot/game/`, and four test suites. 21 tests, `make
check` green.

The reviewer ran 35 mutations and 17 probe cases, and measured two things on the
pinned 4.7.2 rather than arguing them. It reported 13 of its 35 mutations
surviving; **the list of which 13 was in the part that was lost.** This session
then ran its own 21 mutations, which is not the same thing and does not replace
it.

## Findings

**1. Both interface files stated something false about the engine, and had
picked the weaker mechanism because of it.** `pathfinder.gd` said GDScript has
no `abstract` keyword and that the choice was between a polite comment and
`push_error`. On 4.7.2 `@abstract` exists, on the class and per method, and the
engine refuses to *load* a subclass that has not replaced one:

```
Parse Error: Class "ForgetfulChild" must implement "Pathfinder.find_path()"
```

Worse than being wrong about the engine: the mechanism it used instead returned
a default that each file's own contract defines as a legitimate answer — an
empty array means "no route exists", an empty path means "hold". A forgotten
override was indistinguishable from an implementation that had decided to do
nothing, in exactly the build where nobody reads the log. `ai_search` is the
next task and the first caller. This is precisely the failure CLAUDE.md's
"check the documentation before writing the rule" section exists to prevent,
committed in a wave whose own status entry boasts about a different
measurement.

**2. `BoardState.units` said "dead ones already removed" and nothing removed
them.** Four parts of the file then disagreed about what a corpse is: it
blocked a cell, was invisible to `units_of`, collected fresh movement from
`end_turn`, was not drawn, and `main.gd` would have let you select it. Three of
the reviewer's mutations covering this went unnoticed, because no test in the
branch ever built a dead unit.

**3. The constructor handed out a state the caller could keep mutating.**
`units = board_units` with no copy, under a class header that sells
immutability as the thing every technique here needs. The reviewer moved a unit
through its own reference after building the state, and the state moved with
it.

**Found by this session afterwards, not by the review.** A 21-rule mutation
sweep over `ai_core` and the view left three survivors:

- the "is this cell on the board" rule could be deleted outright: off the board
  is *also* blocked, so the rule below caught every case and only the refusal
  message changed. The rule earns its place by the message, so the message is
  now what the test asserts;
- `Move.cost_on` returning `BLOCKED` was never observed, because `why_refused`
  rejects a blocked step before it asks what the walk costs;
- nothing had ever handed a `Move` an array and then changed it, so the copy in
  its constructor was untested.

And two edge cases probed on the engine:

- `GridGraph.new(-2, 3)` passed the product to `resize`, which refused it with
  `ERR_INVALID_PARAMETER` and logged an engine error — after which the graph
  carried on reporting `width = -2`;
- two units sharing an id leaves the second **unmovable**, since `apply`
  resolves the mover through `unit_by_id`, which answers with the first.

## What was done about them

Findings 1 to 3 are fixed in `1f448de`, the three survivors in `f894bb0`, and
the negative dimension in `695dc18`. The suite is 34 tests and all 21 mutations
are now caught.

The interfaces use `@abstract`, and four tests hold it by building a forgetful
subclass **at run time** — one cannot be written in a test file, because the
file would not parse. Two things learned doing that are written down in
`docs/godot/addon-anatomy.md` rather than left in a commit message: gdUnit4
fails a test on any engine error unless the error is expected through
`assert_error`, and a GDScript lambda captures a local **by value**, so the
first version of that test asserted on a variable the closure could never
change. It passed, and it was measuring nothing.

The dead-unit rule now lives in one place — the constructor drops them — which
also made the `is_alive` branches elsewhere redundant, and they are gone rather
than kept as reassurance. The constructor copies what it is given, which let
`duplicate_state` lose its own copying loop: two places that copy are two
places that drift.

One finding was answered by changing a gate instead of the code: the
readability gate could not see an `@abstract func` at all, because an
annotation sits in front of `func`. An abstract method could have taken untyped
parameters and carried no doc comment, in the one kind of file whose entire
content is signatures. Three planted cases now cover it.

The duplicate-id case is **documented rather than fixed**, on `unit_by_id`: it
is a bug in whoever builds a scenario, not a state this type can refuse, and
the search in T3 should not have to rediscover it.

**What this record cannot claim.** The reviewer's remaining findings were never
delivered, so this wave merges knowing that a context which did not write the
code found things in it that nobody has read. The 21-mutation sweep that stands
in for them was written by the same session as the code — the exact symmetry
invariant 12 exists to break. The next wave should begin by reviewing this one,
and should treat `ai_core` as unreviewed below the three findings above.
