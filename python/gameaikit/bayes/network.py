"""A Bayesian network over discrete variables, asked by exact enumeration.

Read `godot/addons/ai_bayes/bayes_network.gd` for the why. This is AIMA
4th ed.'s ENUMERATION-ASK (fig. 13.10): for each value of the query, the
evidence and that value fixed, the sum over every hidden variable's values
of the product of every variable's table entry, then normalised. It does
the same sums in the same order as the GDScript, and `spec/vectors/bayes/`
holds both to the same answers.
"""

from __future__ import annotations

import json
import math
import pathlib
from typing import Any

from gameaikit.techniques import technique

#: How far a table's row may sum from 1 and still be read as a distribution.
ROW_SUM_SLACK = 1e-9


@technique("bayes", "how likely something unseen is, from the evidence seen, by a Bayesian network")
class BayesNetwork:
    """Discrete variables, their parents and their tables, asked by enumeration."""

    def __init__(self, data: dict[str, Any] | None = None) -> None:
        """Read `{"variables": [{"name", "values", "parents", "table"}, ...]}`.

        A malformed network is kept, and `problem()` says what is wrong with
        it, as the GDScript does -- so the vectors' refusals read the same.
        """
        self.names: list[str] = []
        self.values: dict[str, list[str]] = {}
        self.parents: dict[str, list[str]] = {}
        self.tables: dict[str, list[list[float]]] = {}
        self._problem = ""
        rows = (data or {}).get("variables", [])
        if not isinstance(rows, list) or not rows:
            self._problem = "B1 the network has no variables"
            return
        for row in rows:
            self._problem = self._add(row)
            if self._problem:
                return

    @classmethod
    def read(cls, path: str | pathlib.Path) -> BayesNetwork:
        """The network in the JSON file at `path`."""
        return cls(json.loads(pathlib.Path(path).read_text(encoding="utf-8")))

    def problem(self) -> str:
        """What is wrong with the network as given, or "" when it can be asked."""
        return self._problem

    def probability(self, variable: str, value: str, assignment: dict[str, str]) -> float:
        """P(`variable` = `value` | its parents as `assignment` has them).

        A value the network does not have, for the variable or a parent, is
        a ValueError (from `list.index`), never a neighbouring row.
        """
        row = 0
        for parent in self.parents[variable]:
            row = row * len(self.values[parent]) + self.values[parent].index(assignment[parent])
        return float(self.tables[variable][row][self.values[variable].index(value)])

    def ask(self, query: str, evidence: dict[str, str]) -> list[float]:
        """P(`query` | `evidence`), one chance per value of the query, in order.

        Empty when the evidence cannot happen under the tables. A query or
        evidence naming what the network lacks is a ValueError.
        """
        unknown = self._unknown(query, evidence)
        if unknown:
            raise ValueError(unknown)
        distribution = []
        for value in self.values[query]:
            extended = dict(evidence)
            extended[query] = value
            distribution.append(self._enumerate_all(0, extended))
        return _normalised(distribution)

    def influence(self, query: str, value: str, evidence: dict[str, str]) -> dict[str, float]:
        """What each piece of evidence did to P(query = value): with it, less without it."""
        with_all = self.ask(query, evidence)
        if not with_all:
            return {}
        index = self.values[query].index(value)
        moved = {}
        for name in evidence:
            without = {other: seen for other, seen in evidence.items() if other != name}
            moved[name] = with_all[index] - self.ask(query, without)[index]
        return moved

    def _enumerate_all(self, index: int, assignment: dict[str, str]) -> float:
        """ENUMERATE-ALL: the sum of the products over every variable from `index` not fixed."""
        if index == len(self.names):
            return 1.0
        variable = self.names[index]
        if variable in assignment:
            return self.probability(variable, assignment[variable], assignment) * self._enumerate_all(
                index + 1, assignment)
        total = 0.0
        for value in self.values[variable]:
            extended = dict(assignment)
            extended[variable] = value
            total += self.probability(variable, value, extended) * self._enumerate_all(index + 1, extended)
        return total

    def _unknown(self, query: str, evidence: dict[str, str]) -> str:
        """Why `query` and `evidence` cannot be asked of this network, or ""."""
        if self._problem:
            return f"BayesNetwork: {self._problem}"
        if query not in self.values or query in evidence:
            return f"BayesNetwork: {query!r} is not a variable to ask about here"
        for name, seen in evidence.items():
            if name not in self.values or seen not in self.values[name]:
                return f"BayesNetwork: the evidence {name} = {seen} names no variable or value here"
        return ""

    def _add(self, row: Any) -> str:
        """Read one variable's row of the data; why it cannot be read, or ""."""
        if not isinstance(row, dict):
            return "B2 a variable is not an object"
        name = str(row.get("name", ""))
        if not isinstance(row.get("values"), list):
            return f"B2 the values of '{name}' are not a list"
        own = [str(value) for value in row["values"]]
        if not name or name in self.values or len(own) < 2 or len(set(own)) != len(own):
            return f"B2 the variable '{name}' has no name, a name taken, or fewer than two distinct values"
        above = [str(parent) for parent in row.get("parents", [])]
        for parent in above:
            if parent not in self.values:
                return f"B3 the parent '{parent}' of '{name}' is not a variable given before it"
        found = self._table_problem(name, own, above, row.get("table", []))
        if found:
            return found
        self.names.append(name)
        self.values[name] = own
        self.parents[name] = above
        self.tables[name] = [[float(chance) for chance in entry] for entry in row["table"]]
        return ""

    def _table_problem(self, name: str, own: list[str], above: list[str], table: Any) -> str:
        """Why `table` is not one distribution over `own` per combination of `above`, or ""."""
        rows_wanted = 1
        for parent in above:
            rows_wanted *= len(self.values[parent])
        if not isinstance(table, list) or len(table) != rows_wanted:
            return f"B4 the table of '{name}' does not have {rows_wanted} rows, one per combination of its parents"
        for entry in table:
            if not isinstance(entry, list) or len(entry) != len(own):
                return f"B4 a row of '{name}' does not give one chance for each of its {len(own)} values"
            if any(isinstance(chance, bool) or not isinstance(chance, (int, float)) or not math.isfinite(chance)
                   or chance < 0 for chance in entry):
                return f"B5 a row of '{name}' has an entry that is not a chance"
            if abs(sum(float(chance) for chance in entry) - 1.0) > ROW_SUM_SLACK:
                return f"B5 a row of '{name}' sums to {sum(entry)}, not 1"
        return ""


def most_moved(moved: dict[str, float]) -> str:
    """The evidence that moved the belief most either way; the first of equals; "" for none."""
    strongest = ""
    for name, change in moved.items():
        if not strongest or abs(change) > abs(moved[strongest]):
            strongest = name
    return strongest


def _normalised(distribution: list[float]) -> list[float]:
    """Each entry over their sum, in order; empty when they sum to 0."""
    total = 0.0
    for chance in distribution:
        total += chance
    if total <= 0.0:
        return []
    return [chance / total for chance in distribution]
