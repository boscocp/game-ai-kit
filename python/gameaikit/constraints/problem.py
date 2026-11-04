"""What a solution is: variables, the values each may take, and the constraints.

Read `godot/addons/ai_constraints/constraint_problem.gd` for the why. A
constraint satisfaction problem (AIMA 4th ed., 6.1) is declared, not
searched: each variable gets a finite domain, a *binary* constraint names
two variables and says which pairs of values may stand together, and a
*global* constraint names any number of variables and says whether a
partial assignment can still be completed. The solver in `solver.py`
finds an assignment that breaks none of them, or says there is none.
"""

from __future__ import annotations

import dataclasses
from collections.abc import Callable
from typing import Any

#: A binary constraint's test: may these two values stand together?
Allowed = Callable[[Any, Any], bool]
#: A global constraint's test, on a partial assignment (variable -> value):
#: False only when no way of assigning the rest could satisfy it.
Holds = Callable[[dict], bool]


@dataclasses.dataclass(frozen=True)
class Binary:
    """Two variables and the pairs of values they may take together."""

    first: str
    second: str
    allowed: Allowed
    label: str

    def other(self, name: str) -> str:
        """The variable at the other end from `name`."""
        return self.second if name == self.first else self.first

    def allows(self, name: str, value: Any, other_value: Any) -> bool:
        """Whether `name` = `value` may stand beside its other end = `other_value`."""
        if name == self.first:
            return self.allowed(value, other_value)
        return self.allowed(other_value, value)


@dataclasses.dataclass(frozen=True)
class Global:
    """Any number of variables, and a test of a partial assignment of them."""

    names: tuple[str, ...]
    holds: Holds
    label: str


class ConstraintProblem:
    """Variables in the order declared, their domains, and their constraints."""

    def __init__(self) -> None:
        self.variables: list[str] = []
        self.domains: dict[str, list] = {}
        self.binaries: list[Binary] = []
        self.globals: list[Global] = []
        self._touching: dict[str, list[int]] = {}
        self._mistakes: list[str] = []

    def add_variable(self, name: str, values: list) -> None:
        """Declare `name`, which may take any of `values`, in that order."""
        if name in self.domains:
            self._mistakes.append(f"the variable {name!r} is declared twice")
            return
        self.variables.append(name)
        self.domains[name] = list(values)
        self._touching[name] = []

    def add_binary(self, first: str, second: str, allowed: Allowed, label: str = "") -> None:
        """Only pairs for which `allowed(first_value, second_value)` is true may stand."""
        if first not in self.domains or second not in self.domains or first == second:
            self._mistakes.append(f"the constraint {label!r} needs two declared variables, not {first!r} and {second!r}")
            return
        self._touching[first].append(len(self.binaries))
        self._touching[second].append(len(self.binaries))
        self.binaries.append(Binary(first, second, allowed, label))

    def add_global(self, names: list[str], holds: Holds, label: str = "") -> None:
        """`holds(partial_assignment)` must not answer False while a completion exists."""
        missing = [name for name in names if name not in self.domains]
        if missing or not names:
            self._mistakes.append(f"the constraint {label!r} names no declared variable, or {missing}")
            return
        self.globals.append(Global(tuple(names), holds, label))

    def touching(self, name: str) -> list[int]:
        """The binary constraints on `name`, as indices into `binaries`, in the order added."""
        return self._touching[name]

    def problem(self) -> str:
        """What is wrong with the declaration, or "" when nothing is."""
        if self._mistakes:
            return self._mistakes[0]
        if not self.variables:
            return "a problem needs at least one variable"
        empty = [name for name in self.variables if not self.domains[name]]
        if empty:
            return f"the variable {empty[0]!r} has no value it may take"
        return ""
