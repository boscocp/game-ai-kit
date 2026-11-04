# Conformance vectors: constraints

<!-- doc-meta
half_life: structure
verified_on: 2026-11-04
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the solver's order of choices, AC-3's queue, the shuffle, or the xorshift generator changes
teaches: none
-->

> One constraint solver, two languages, and the files that say they made
> the same choices.

`ai_constraints`'s `ConstraintSolver` (GDScript) and `gameaikit.constraints`
(Python) search the same way. Each vector is one `.json` file: a problem
(`variables` with their `values`, `binary` constraints by a named
`relation`, `global` ones the same), the solver's settings (`seed`, `mrv`,
`lcv`, `propagate`), and the claims -- the `solution` (or `null` when there
is none), every value `assigned` in order, and the counts of `assignments`,
`backtracks` and values `pruned` by AC-3. Both sides check every claim
against the file, never against each other: `make test-constraints-vectors`
on the GDScript side, `make test-python` on the Python side.

The relations: `different` (a != b), `less` (a < b), `queens` (a != b and
|a - b| != `apart`); globally, `sum-at-most` (the values assigned so far
add up to at most `limit`) and `some-equals` (while any is unassigned, yes;
then some must equal `value`).

The rules the two follow, and that a third implementation must follow to
agree:

1. before anything else, one generator seeded with `seed` shuffles the
   variables, then each variable's values, in the order declared --
   Fisher and Yates from the last place down to the second, each swapped
   with place `next() % (place + 1)`; a list of one draws nothing;
2. with `propagate`, AC-3 runs once on every arc: for each binary
   constraint in the order declared, its first variable revised against its
   second, then the second against the first. A queue, first in first out;
   when a variable loses a value, every arc that revises one of its
   neighbours against it goes on the end -- in the order its constraints
   were declared, except through the constraint just revised, and not when
   that arc is waiting already;
3. the next variable is the first, in the shuffled order, of those
   unassigned with fewest values left and, among those, most binary
   constraints to unassigned variables; without `mrv`, simply the first
   unassigned;
4. its values in their current order, or with `lcv` sorted by how many
   values of its unassigned neighbours each would rule out, fewest first,
   ties kept in order;
5. a value is refused when it breaks a binary constraint with an assigned
   variable, or a global constraint on it is false of the assignment with
   it added; binary first, then globals, each in the order declared;
6. a value not refused is assigned and counted; with `propagate`, AC-3 runs
   from the arcs that revise each unassigned neighbour against it, in the
   order its constraints were declared. If that empties a domain, or the
   search below fails, everything since is undone and the next value tried;
7. when every value of the variable has been tried, that is one backtrack.

The draws are Marsaglia's 32-bit xorshift, the generator T86 wrote for
Monte Carlo search and T99 copied for the bandit; seed 1 starts 270369.

## Where the numbers came from

From neither implementation: `derive.py`, a script importing nothing from
this repository, wrote them, in a shape of its own -- domains passed down the
recursion as copies, not saved and restored. One can be checked by hand:
`a-triangle-in-two-colours-has-none`, three states that all border each
other and two colours. AC-3 alone crosses out nothing, since for any colour
of one state the other has a different one. The search picks C (all three
tie on values and degree, and C comes first in seed 1's order) and assigns
red; AC-3 then crosses red out of A and B, and revising A against B finds
A's green has no partner in B's {green}: A is empty. Three values pruned,
undone; green fails the same way, three more. Every value of C failed: one
backtrack, two assignments, six pruned, no solution -- what the file claims.

The others: `australia-in-three-colours` starts at South Australia, the
state with most borders (MRV's tie broken by degree); `australia-another-seed`
colours the same map otherwise; `australia-in-order-alone` has no heuristic
and no inference; six queens plain takes 21 assignments and 15 backtracks,
with all three choices 9 and 1; `least-constraining-first` is six queens with
LCV alone; `four-by-four-sudoku` is solved by propagation, no backtrack;
`a-global-checked-late` has two global constraints, one of which can say no
only once all three variables are placed.

`derive.py` wrote them; run it again to check.

## What is refused

A vector with a key nobody reads, a relation neither side knows, a problem
that cannot be declared, an `assigned` list that does not match its count,
or a solution that does not name every variable, is refused rather than
half-checked. Two planted solvers must fail, in both languages: one that
gives a tie between variables to the last (rule 3), and one with least
constraining value the wrong way round (rule 4).
