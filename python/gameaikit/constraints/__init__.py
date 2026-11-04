"""Constraint satisfaction: declare what a solution is, and let a solver find one.

The Python half of `godot/addons/ai_constraints/` (T95), written again so
the conformance vectors in `spec/vectors/constraints/` can hold the two
languages to the same assignment and the same counts, and so map colouring
and Sudoku -- AIMA 4th ed., 6.1.1 and 6.2.6 -- can be solved with no engine.
The infiltration level is solved in the game, on the game's own ground.

    problem.py  variables, domains, binary and global constraints
    solver.py   backtracking with MRV, LCV and AC-3
    draws.py    the seeded generator that orders the ties
"""

from gameaikit.constraints.draws import ConstraintDraws
from gameaikit.constraints.problem import Binary, ConstraintProblem, Global
from gameaikit.constraints.solver import ConstraintSolver

__all__ = ["Binary", "ConstraintDraws", "ConstraintProblem", "ConstraintSolver", "Global"]
