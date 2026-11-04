# Constraint satisfaction: saying what a level is, and letting a solver find one

<!-- doc-meta
half_life: concept
verified_on: 2026-11-04
tier: 1
source: https://aima.cs.berkeley.edu/contents.html
invalidated_if: gameaikit.constraints stops solving by backtracking with MRV, LCV and AC-3, or the infiltration level stops being declared with it
teaches: constraint-satisfaction
-->

> A generator says *how* to make a thing and hopes it is good. A
> constraint satisfaction problem says *what* good is and leaves the how to a
> solver. Tier 1: the solver is Python's standard library, in
> [`python/gameaikit/constraints/`](../../python/gameaikit/constraints/);
> `make demo-infiltration`, a generated level, then K twice, watches its
> twin place a level.

## The parts

A CSP (AIMA 4th ed., 6.1) is three lists:

- **variables** -- what is to be decided: a state's colour, a Sudoku cell, a
  guard's post;
- a **domain** for each, the finite list of values it may take;
- **constraints**, each naming some variables and saying which combinations
  of their values may stand together. A *binary* constraint names two; a
  *global* one any number -- "all different", "the exit can be reached".

A solution assigns every variable a value from its domain and breaks no
constraint. AIMA's first example colours the map of Australia's seven
states in three colours so that no two neighbours match; its second is
Sudoku. Both are tests in `python/tests/test_constraints.py`.

## Propagation: crossing out what cannot be

Before guessing anything, a solver can *infer*. An arc is one direction of
a binary constraint, X towards Y; it is *consistent* when every value left
for X has some value left for Y that the constraint allows. AC-3 (fig. 6.3)
keeps a queue of arcs, revises each -- crossing out the values of X with no
partner in Y -- and, whenever X loses a value, puts every arc into X back on
the queue. A domain emptied means there is no solution, proved without a
single guess. On an easy Sudoku that is the whole story: the puzzle on
Wikipedia's Sudoku page is solved by AC-3 before the search begins, every
cell left with one value (the tests count 0 backtracks).

## Search: guessing well, and going back

When propagation stops short, the solver guesses. Backtracking search
(fig. 6.5) assigns one variable at a time and, when a variable has no value
left that fits, goes back to the one before. Three choices decide how much
of that going back it does:

- **which variable next** -- *minimum remaining values*: the one with
  fewest values left, the one most likely to fail, so that it fails early
  and cheaply; ties to the one on most constraints with unassigned
  variables (the *degree heuristic*). On the map, South Australia first: it
  borders five states.
- **which value first** -- *least constraining value*: the one that crosses
  out fewest values of its neighbours, leaving the rest of the problem the
  most room.
- **what to infer after each guess** -- *maintaining arc consistency*: AC-3
  again, from the arcs into the variable just assigned.

The vectors in `spec/vectors/constraints/` show the difference: six queens
with none of the three takes 21 assignments and 15 backtracks; with all
three, 9 and 1.

## Global constraints, and what "partial" means

Some conditions cannot be written as pairs. "The exit can be walked to from
the start" depends on every box at once. The kit's solver takes such a
constraint as a test of the *partial* assignment, with one rule: it may say
no only when nothing still to be assigned could make it yes. Boxes only
ever close ways, so a partial level already walled off can be refused at
once; a guard's post in sight of the start cannot, because a box still to
come might hide it, so that test waits until every box is placed. Global
constraints are checked, not propagated -- which is why a problem made
mostly of them searches more.

## Generate and test, against declare and solve

The infiltration level had both. `LevelGenerator` (T70) draws a whole level
and keeps it when the exit and every guard's places can be reached: generate
and test, up to 40 draws. It almost never needs a second draw, because it
asks very little; and over 200 seeds, more than half of its levels have a
patrol route with no hiding place within six steps, about a third have no
dark way from the start to the exit, and nearly half put a guard's post in
plain sight of where the player starts (the table is on the
[infiltration page](../godot/infiltration.md)). Nothing in it can ask for
those: a draw that happens to meet them is luck.

`LevelConstraints` (T95) declares the same level -- each box, lamp, hiding
place, patrol point and post a variable over a few candidate places drawn
from the seed -- with the three old conditions and those designer's ones,
and every level it returns meets all of them; `LevelAudit` checks that on
the arena the game builds -- walking and light independently of the
solver's sketch, sight by the same reading of "in sight" (the
[infiltration page](../godot/infiltration.md) says which). The price is
time, a frame stalled while it solves, and a new failure: chronological backtracking can *thrash*, going back
over boxes that were never the trouble while a post stays in sight. AIMA's
answer is conflict-directed backjumping (6.3.3); the kit's, for now, is to
start again with the ties broken another way -- 6 fresh starts over 200
seeds, and every seed found a level.

## Where it goes next

Wave function collapse (T96) is a CSP too -- its author describes it as
translating "a texture synthesis problem into a constraint satisfaction
problem" -- with tiles as values and adjacency as the constraints. Local
search (min-conflicts, AIMA 6.4) is the other road for large problems; it
is not in the kit.

## References

- Russell, S., Norvig, P. *Artificial Intelligence: A Modern Approach*, 4th
  ed., Pearson, 2020, ch. 6 (contents:
  <https://aima.cs.berkeley.edu/contents.html>, opened 2026-10-26).
- Foged, L., Horswill, I. "Rolling Your Own Finite-Domain Constraint
  Solver", *Game AI Pro 2*, ch. 26, as cited by T73.
