# Review: tasks/17-driving-and-a-picture-you-can-check

Not reviewed by a fresh context. This wave adds no code — three task files, two
backlog rows, one standing rule and two stale claims corrected — and the thing
most worth reviewing in it was settled by measurement before a line was
written, which is recorded below rather than taken on trust.

## What was reviewed

The owner asked for two things: a racing example after the RTS, with three
difficulty levels; and a standing rule that **every example has something
visual a person can test** — clarified mid-wave as *a human being able to see
what the AI does*.

The clarification mattered. The first draft of T21 was a machine-checkable
display-list harness: views would emit what-where-what-colour as data and a
gate would assert properties of the list. That is a defensible piece of
engineering and it is not what was asked for. It was deleted and rewritten
around a person opening a window.

## Findings

**No command in this repository can look at a picture, and a rule that assumed
otherwise would have been unrunnable.** Measured on the pinned 4.7.2 before
writing the rule down, which is the order `CLAUDE.md` asks for:

- `--headless` selects the dummy rendering driver. A `ColorRect` added to the
  tree and given two frames produces `texture_2d_get: Parameter "t" is null`
  and `get_image()` returns null. Nothing is rasterised;
- there is no `xvfb` in the toolchain, so there is no display-free renderer to
  fall back on either.

So invariant 13 is written as half-gateable on purpose. `check_demos.py` can
assert that an example exists, that its scene loads, and that the decision
overlay is populated after a step. It cannot assert that anything is legible,
and the task says so instead of implying a gate that would have to be faked.

**Two claims in `CLAUDE.md` were already false.** Invariant 2's gate was
described as inspecting nothing "because no addon exists yet" — three do, and
`check_addon_deps.py` has held it fully since wave 7. And the count of
unenforced invariants needed re-deriving rather than adjusting: removing one
and adding one left it at four, and the first edit said five. The four are now
named — 4, 6, 7 and 13 — so the next reader can check the claim against the
table instead of counting.

**A dependency that was prose became a prerequisite.** T21 binds every example
built after it, so T8 — the first example in the backlog — now lists it in
`Prereqs`. A "comes before" in a Notes column is not a dependency; the
prerequisite graph is what `check_status.py` actually reads.

**The gate caught the author.** `check_acceptance.py` refused T22 for the
phrase "a trajectory that looks right", which was an aside about why three
properties are asserted rather than a criterion asking a person to look. The
gate cannot tell those apart and should not try. The sentence was reworded.

## What was done about them

Three task files: T21 (every example can be watched), T22 (`ai_steering`) and
T23 (the racing demo). A fourth milestone, after the RTS, because that is the
order the owner wants to build in — and T23's `Prereqs` say T21 and T22 rather
than T20, because it does not actually need the RTS and a backlog that claims
dependencies it does not have stops being read.

Invariant 13 is in `CLAUDE.md` with its gate named and its limits stated.

**Why `ai_steering` is a new addon rather than a reuse.** Every decision in the
kit so far picks a cell or an action on a grid, in a turn. A car picks how hard
to turn, right now. There is nothing in `ai_core` for continuous heading and
speed, and squeezing one in would make the grid types worse for the three games
that depend on them.

**Why the racing difficulties are worth a task.** Racing is the genre where
difficulty most often cheats, and rubber-banding is the industry default. T12
already states the rule for the strategy game; T23 is where it is tested under
the pressure of a genre that routinely breaks it, with a command asserting the
three presets share one physics resource field for field and that no car
exceeds its stated grip or top speed on any frame of a recorded race.

## What is still open

**T21 has not been built, so invariant 13 binds nothing yet.** It is marked in
the table as unenforced, which is the honest state, and the rule's first real
test is whether T8 — already written, already waiting — adopts it or routes
around it.

**The existing demos predate the rule.** `make run` and `make demo-search` draw
outcomes; whether they show a decision before it happens is exactly the
question T21's manual check asks, and the answer today is probably no for the
board and partly yes for the search demo.
