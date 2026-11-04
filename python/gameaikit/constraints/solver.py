"""Find an assignment that breaks no constraint, or say there is none.

Read `godot/addons/ai_constraints/constraint_solver.gd` for the why. This
is AIMA 4th ed.'s BACKTRACKING-SEARCH (fig. 6.5) with its three named
choices: the variable by *minimum remaining values*, ties to the one on
the most constraints with unassigned variables (the degree heuristic); the
values by *least constraining value*; and inference by AC-3 (fig. 6.3), run
once before the search and again after every assignment (*maintaining arc
consistency*). A global constraint is checked, not propagated. This file
does the same steps in the same order as the GDScript, and
`spec/vectors/constraints/` holds both to the same assignment and the same
counts.
"""

from __future__ import annotations

import collections
from typing import Any

from gameaikit.constraints.draws import SEED_FOR_ZERO, ConstraintDraws
from gameaikit.constraints.problem import ConstraintProblem
from gameaikit.techniques import technique

#: An arc: a binary constraint's index, and the variable it revises.
Arc = tuple[int, str]


@technique("constraints", "an assignment of values to variables that breaks no declared constraint")
class ConstraintSolver:
    """Backtracking with MRV, LCV and AC-3 over a `ConstraintProblem`."""

    def __init__(self, problem: ConstraintProblem, seed: int = SEED_FOR_ZERO, mrv: bool = True,
                 lcv: bool = True, propagate: bool = True, record: bool = False, limit: int = 0) -> None:
        self.problem = problem
        self.seed = seed
        self.mrv = mrv
        self.lcv = lcv
        self.propagate = propagate
        self.record = record
        self.limit = limit
        self.domains: dict[str, list] = {}
        self.assignment: dict[str, Any] = {}
        self.trace: list[dict] = []
        self.assignments = 0
        self.backtracks = 0
        self.pruned = 0
        self.refusals = 0
        self.gave_up = False
        self._order: list[str] = []

    def solve(self) -> dict | None:
        """The assignment, every variable in the order declared, or None when there is none.

        A declaration that `problem.problem()` refuses has none. Each call
        starts the counts, the trace and `gave_up` afresh.
        """
        self.trace, self.assignments, self.backtracks, self.pruned, self.refusals = [], 0, 0, 0, 0
        self.gave_up = False
        if self.problem.problem():
            return None
        draws = ConstraintDraws(self.seed)
        self._order = draws.shuffle(self.problem.variables)
        self.domains = {name: draws.shuffle(self.problem.domains[name]) for name in self.problem.variables}
        self.assignment = {}
        if self.propagate and not self._ac3(self._every_arc()):
            return None
        found = self._backtrack()
        if found is None:
            return None
        return {name: found[name] for name in self.problem.variables}

    # -- the search, AIMA fig. 6.5 -------------------------------------------

    def _backtrack(self) -> dict | None:
        """Assign one more variable and go on; when every value fails, go back."""
        if len(self.assignment) == len(self.problem.variables):
            return dict(self.assignment)
        name = self._select()
        self._note({"event": "choose", "variable": name, "remaining": len(self.domains[name])})
        for value in self._values(name):
            refused = self._refusal(name, value)
            if refused is not None:
                self.refusals += 1
                self._note({"event": "refuse", "variable": name, "value": value, "constraint": refused})
                continue
            found = self._try(name, value)
            if found is not None or self.gave_up:
                return found
        self.backtracks += 1
        self._note({"event": "backtrack", "variable": name})
        return None

    def _try(self, name: str, value: Any) -> dict | None:
        """Assign `value`, propagate, search on; undo it all when that fails."""
        if self.limit and self.assignments >= self.limit:
            self.gave_up = True
            return None
        saved = {key: list(values) for key, values in self.domains.items()}
        self.assignment[name] = value
        self.assignments += 1
        self._note({"event": "assign", "variable": name, "value": value})
        self.domains[name] = [value]
        if not self.propagate or self._ac3(self._arcs_into(name)):
            found = self._backtrack()
            if found is not None or self.gave_up:
                return found
        self.domains = saved
        del self.assignment[name]
        self._note({"event": "undo", "variable": name, "value": value})
        return None

    def _select(self) -> str:
        """Minimum remaining values, then the most constraints on unassigned
        variables, then the seeded order; without MRV, the seeded order alone."""
        unassigned = [name for name in self._order if name not in self.assignment]
        best = unassigned[0]
        if not self.mrv:
            return best
        for name in unassigned[1:]:
            if (len(self.domains[name]), -self._degree(name)) < (len(self.domains[best]), -self._degree(best)):
                best = name
        return best

    def _degree(self, name: str) -> int:
        """How many binary constraints tie `name` to a variable not yet assigned."""
        return sum(1 for index in self.problem.touching(name)
                   if self.problem.binaries[index].other(name) not in self.assignment)

    def _values(self, name: str) -> list:
        """The domain, least constraining value first; equal ones in the seeded order."""
        values = list(self.domains[name])
        if not self.lcv:
            return values
        costs = [(self._ruled_out(name, value), place) for place, value in enumerate(values)]
        return [values[place] for _cost, place in sorted(costs)]

    def _ruled_out(self, name: str, value: Any) -> int:
        """How many values of unassigned neighbours `name` = `value` would rule out."""
        count = 0
        for index in self.problem.touching(name):
            binary = self.problem.binaries[index]
            other = binary.other(name)
            if other not in self.assignment:
                count += sum(1 for other_value in self.domains[other] if not binary.allows(name, value, other_value))
        return count

    def _refusal(self, name: str, value: Any) -> str | None:
        """The label of the first constraint `name` = `value` breaks, or None when none.

        A label may be "": "refused" and "why" are two answers, and an
        unlabelled constraint still refuses.
        """
        for index in self.problem.touching(name):
            binary = self.problem.binaries[index]
            other = binary.other(name)
            if other in self.assignment and not binary.allows(name, value, self.assignment[other]):
                return binary.label
        self.assignment[name] = value
        broken = next((rule.label for rule in self.problem.globals
                       if name in rule.names and not rule.holds(self.assignment)), None)
        del self.assignment[name]
        return broken

    # -- inference, AIMA fig. 6.3 --------------------------------------------

    def _every_arc(self) -> list[Arc]:
        """Both directions of every binary constraint, in the order added."""
        arcs: list[Arc] = []
        for index, binary in enumerate(self.problem.binaries):
            arcs.extend([(index, binary.first), (index, binary.second)])
        return arcs

    def _arcs_into(self, name: str) -> list[Arc]:
        """The arcs that revise each unassigned neighbour of `name` against it."""
        arcs: list[Arc] = []
        for index in self.problem.touching(name):
            other = self.problem.binaries[index].other(name)
            if other not in self.assignment:
                arcs.append((index, other))
        return arcs

    def _ac3(self, arcs: list[Arc]) -> bool:
        """Make every arc consistent; False when a domain is emptied."""
        waiting = collections.deque(arcs)
        queued = set(arcs)
        while waiting:
            index, target = waiting.popleft()
            queued.discard((index, target))
            if not self._revise(index, target):
                continue
            if not self.domains[target]:
                return False
            for other_index in self.problem.touching(target):
                arc = (other_index, self.problem.binaries[other_index].other(target))
                if other_index != index and arc not in queued:
                    waiting.append(arc)
                    queued.add(arc)
        return True

    def _revise(self, index: int, target: str) -> bool:
        """Cross out each value of `target` that no value at the other end allows."""
        binary = self.problem.binaries[index]
        other_values = self.domains[binary.other(target)]
        kept = []
        for value in self.domains[target]:
            if any(binary.allows(target, value, other_value) for other_value in other_values):
                kept.append(value)
            else:
                self._note({"event": "prune", "variable": target, "value": value, "constraint": binary.label})
        removed = len(self.domains[target]) - len(kept)
        self.domains[target] = kept
        self.pruned += removed
        return removed > 0

    def _note(self, event: dict) -> None:
        """Keep one step of the search, when asked to record them."""
        if self.record:
            self.trace.append(event)
