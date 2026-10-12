"""Read a PDDL domain written by somebody who is not a programmer.

The planner itself is GDScript and runs in the game; this is the offline half,
and the split is deliberate -- parsing a domain file is not work a frame should
ever do.

    from gameaikit.pddl import read_domain, read_problem

What it reads, and what it refuses, is in `reader.py`.
"""

from .reader import Action, Domain, Problem, read_domain, read_problem
from .sexpr import PddlError, parse

__all__ = [
    "Action",
    "Domain",
    "PddlError",
    "Problem",
    "parse",
    "read_domain",
    "read_problem",
]
