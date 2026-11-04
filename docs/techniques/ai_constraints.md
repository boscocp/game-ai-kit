# ai_constraints — what must hold, and a solver that finds it

<!-- doc-meta
half_life: practice
verified_on: 2026-11-04
tier: 1
source: https://aima.cs.berkeley.edu/contents.html ; book:Stuart Russell and Peter Norvig, "Artificial Intelligence: A Modern Approach", 4th edition, Pearson, 2020 -- chapter 6, Constraint Satisfaction Problems
invalidated_if: the kit's ConstraintProblem or ConstraintSolver signature changes, or the infiltration demo stops solving its levels with them
teaches: constraint-satisfaction
-->

> Português: [ai_constraints.pt-BR.md](ai_constraints.pt-BR.md). The words
> that stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

An assignment of values to variables that breaks none of the constraints
declared between them -- or the news that there is none. You do not say
*how* to build the answer; you say *what* an answer is. Each variable has a
finite domain of values; a *binary* constraint says which pairs of values two
variables may take together; a *global* constraint looks at any number of
them and says whether what is assigned so far can still be completed.
`ConstraintSolver` is AIMA 4th edition's backtracking search (6.3, fig. 6.5)
with its three named choices: the variable with the *minimum remaining
values* (ties to the one on most constraints, the degree heuristic), its
values *least constraining* first, and *arc consistency* kept by AC-3 (fig.
6.3) after every assignment. A seed orders the ties, so a seed is one answer.

## When not to use it {#when-not}

When any answer will do and the first random one is usually fine:
generating and testing is shorter. When a constraint is a preference
("rather far than near"): this answers yes or no, and a score is a utility
or an optimiser's job. When most constraints are global and cannot be
propagated: the solver then tries values one by one, which is generate and
test with extra steps. When the problem is large enough to want local search
(min-conflicts, AIMA 6.4) or a dedicated solver. And when chronological
backtracking thrashes -- going back over choices that were never the
trouble -- this kit restarts with fresh ties rather than jumping back (AIMA
6.3.3's backjumping is not here).

## Where to watch it {#watch}

- `make demo-infiltration` -- **L** to a generated level, then **K**: the
  first press solves the level instead of drawing it, the second also replays
  the solver over the screen. On it, the thing about to be placed has each of
  its candidate places drawn, white while possible and a red cross once
  propagation crossed it out; every thing not yet placed is listed with how
  many places it has left, the next one first; a value undone by a backtrack
  flashes red; the last refusal names its constraint. **N** builds another
  level the same way.
- `make measure-level-constraints` -- the solver against the drawn levels
  over 200 seeds; the table is on the [infiltration page](../godot/infiltration.md).
- Which demo uses which technique, both ways: the
  [catalogue](catalogue.md).

## In this kit {#in-this-kit}

`godot/game3d/infiltration/level_constraints.gd` declares the infiltration
level: each box, lamp, hiding place, patrol point and the sentry's post is a
variable whose domain is a few candidate places drawn from the seed. Boxes
apart, nothing under a box, one guard a cell, hiding places and lamps apart
are binary and propagated; the exit and every guard place reachable, no post
in sight of the start, a hiding place near each route and a dark way to the
exit are global, written by the game (`level_constraint_rules.gd`) and asked
of each partial level. The knobs:

| knob | where | what it changes |
|---|---|---|
| variables | `add_variable(name, values)` | what is decided, and the values each may take, in your order |
| binary | `add_binary(first, second, allowed, label)` | a test of two values; propagated by AC-3 |
| global | `add_global(names, holds, label)` | a test of a partial assignment: false only when nothing still to come could save it |
| label | the last argument of either, "" by default | the name a refusal reports in `trace`; an unlabelled constraint is enforced all the same |
| seed | `ConstraintSolver.new(problem, seed)` | which way the ties go, the same in GDScript and Python |
| mrv, lcv, propagate | properties of the solver, all on | switch one off to see what it is worth: the same problem, the backtracks counted both ways |
| record | a property, off | keep every step in `trace` -- chosen, assigned, refused, crossed out, undone -- for a view |
| limit | a property, 0 for none | the most assignments before giving up; `gave_up` then says no answer was proved impossible |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_constraints/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. The Python twin is `gameaikit.constraints`.

### A minimal example {#example}

Four rooms in a row and three things to put in them: the key before the
chest, the guard beside the chest and not on the key, and something in the
tower. This file is run by `rooms_example_test.gd`, and the gate holds the
page equal to it.

<!-- example: godot/test/ai_constraints/rooms_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_constraints.md, run by
# rooms_example_test.gd. A dungeon of four rooms in a row, and three things
# to put in them -- a key, the chest it opens, the guard of the chest --
# said as what must hold, not as how to place them.
extends Node

const ROOMS: Array[String] = ["hall", "library", "cellar", "tower"]

var _problem := ConstraintProblem.new()


func _ready() -> void:
	# Each thing may go in any room, by its index along the row.
	for thing: String in ["key", "chest", "guard"]:
		_problem.add_variable(thing, range(ROOMS.size()))
	# The key comes before the chest, so the player finds it first.
	_problem.add_binary("key", "chest", func(key: int, chest: int) -> bool: return key < chest, "key first")
	# The guard stands in the chest's room or the one beside it.
	_problem.add_binary("guard", "chest", func(guard: int, chest: int) -> bool: return absi(guard - chest) <= 1, "guarded")
	# Not where the key is: the player must be able to take it.
	_problem.add_binary("guard", "key", func(guard: int, key: int) -> bool: return guard != key, "key free")
	# Global, checked on each partial answer: the tower is used. It can only
	# say no once all three are placed, so until then it says yes.
	_problem.add_global(["key", "chest", "guard"], func(placed: Dictionary) -> bool:
		return placed.size() < 3 or placed.values().has(3), "tower used")
	# A misspelt name or an empty domain is refused here.
	if _problem.problem() != "":
		push_error(_problem.problem())


## Where each thing goes, by room name, for `seed_value`; {} when no
## placement satisfies every constraint.
func place(seed_value: int) -> Dictionary:
	var solver := ConstraintSolver.new(_problem, seed_value)
	var found: Dictionary = solver.solve()
	var named: Dictionary = {}
	for thing: String in found:
		named[thing] = ROOMS[found[thing]]
	return named
```

### What you implement {#implement}

The constraints, as tests. A binary one is a Callable on two values, the
first variable's then the second's; make it cheap, because AC-3 and least
constraining value ask it about every pair many times -- the infiltration
level asks each pair once and keeps a table. A global one is a Callable on
the partial assignment: it must answer false only when no way of assigning
the rest could satisfy it, and true while it cannot yet tell. Getting that
wrong the other way -- false on something a later value would fix -- makes
the solver miss answers and say "none" when there is one. Do not change the
assignment it is shown. Keep values comparable with `==`: an index into a
list of candidates is the usual answer when the things are large.

## Deeper {#deeper}

- What a CSP is, propagation against search, and why the infiltration level
  moved from drawing to declaring:
  [concepts/constraint-satisfaction.md](../concepts/constraint-satisfaction.md).
- The two levels side by side, measured over 200 seeds:
  [godot/infiltration.md](../godot/infiltration.md).
- Where constraint satisfaction sits among the field's techniques:
  [concepts/the-literature-and-the-kit.md](../concepts/the-literature-and-the-kit.md).
