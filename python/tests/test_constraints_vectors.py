"""The Python half of the constraint conformance run.

The vectors in `spec/vectors/constraints/` are read from both languages, and
each side checks every claim in them against the file -- never against the
other side. The claims came from neither: a script importing nothing from
this repository wrote them (`derive.py`, by the README's rules).
"""

import json
import pathlib
import unittest

from gameaikit.constraints import ConstraintProblem, ConstraintSolver

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "constraints"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 8

VECTOR_KEYS = {"description", "variables", "binary", "global", "seed", "mrv", "lcv", "propagate", "solution",
               "assigned", "assignments", "backtracks", "pruned"}
RELATIONS = {"different", "less", "queens"}
GLOBALS = {"sum-at-most", "some-equals"}


def allowed_by(entry: dict):
    """The test a vector's binary relation names."""
    kind = entry["relation"]
    if kind == "different":
        return lambda first, second: first != second
    if kind == "less":
        return lambda first, second: first < second
    return lambda first, second: first != second and abs(first - second) != entry["apart"]


def holds_by(entry: dict):
    """The test a vector's global relation names, on a partial assignment."""
    names = entry["over"]
    if entry["relation"] == "sum-at-most":
        return lambda partial: sum(partial[name] for name in names if name in partial) <= entry["limit"]
    return lambda partial: (any(name not in partial for name in names)
                            or any(partial[name] == entry["value"] for name in names))


def problem_of(vector: dict) -> ConstraintProblem:
    """The problem the vector declares, in its order."""
    problem = ConstraintProblem()
    for variable in vector["variables"]:
        problem.add_variable(variable["name"], variable["values"])
    for entry in vector["binary"]:
        problem.add_binary(entry["between"][0], entry["between"][1], allowed_by(entry), entry["relation"])
    for entry in vector["global"]:
        problem.add_global(entry["over"], holds_by(entry), entry["relation"])
    return problem


def solver_of(vector: dict, solver_class: type = ConstraintSolver) -> ConstraintSolver:
    """The solver the vector's settings describe, recording its steps."""
    return solver_class(problem_of(vector), seed=vector["seed"], mrv=vector["mrv"], lcv=vector["lcv"],
                        propagate=vector["propagate"], record=True)


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable vector, or "" when it is one."""
    if set(vector) != VECTOR_KEYS:
        return f"V1 its keys are {sorted(vector)}, not {sorted(VECTOR_KEYS)}"
    if any(entry.get("relation") not in RELATIONS for entry in vector["binary"]):
        return "V2 a binary constraint names a relation neither side knows"
    if any(entry.get("relation") not in GLOBALS for entry in vector["global"]):
        return "V3 a global constraint names a relation neither side knows"
    declared = problem_of(vector).problem()
    if declared:
        return f"V4 its problem cannot be declared: {declared}"
    if len(vector["assigned"]) != vector["assignments"]:
        return "V5 its assignments do not count the values it claims were assigned"
    if vector["solution"] is not None and set(vector["solution"]) != {v["name"] for v in vector["variables"]}:
        return "V6 its solution does not name every variable"
    return ""


def wrong_claims(vector: dict, solver: ConstraintSolver) -> list[str]:
    """Every claim of the vector that `solver` does not reproduce."""
    found = solver.solve()
    assigned = [[event["variable"], event["value"]] for event in solver.trace if event["event"] == "assign"]
    claims = [("solution", found, vector["solution"]), ("assigned", assigned, vector["assigned"]),
              ("assignments", solver.assignments, vector["assignments"]),
              ("backtracks", solver.backtracks, vector["backtracks"]), ("pruned", solver.pruned, vector["pruned"])]
    return [f"{name}: {got!r}, the vector says {want!r}" for name, got, want in claims if got != want]


def vectors() -> dict[str, dict]:
    """Every vector in the directory, by file name."""
    return {path.name: json.loads(path.read_text(encoding="utf-8")) for path in sorted(VECTORS.glob("*.json"))}


class LastOfEqualVariables(ConstraintSolver):
    """A planted solver: of equally constrained variables, the last in the seeded order."""

    def _select(self) -> str:
        unassigned = [name for name in self._order if name not in self.assignment]
        best = unassigned[0]
        for name in unassigned[1:]:
            if (len(self.domains[name]), -self._degree(name)) <= (len(self.domains[best]), -self._degree(best)):
                best = name
        return best if self.mrv else unassigned[0]


class MostConstrainingValue(ConstraintSolver):
    """A planted solver: LCV the wrong way round."""

    def _values(self, name: str) -> list:
        values = list(self.domains[name])
        if not self.lcv:
            return values
        return sorted(values, key=lambda value: -self._ruled_out(name, value))


class ConstraintVectors(unittest.TestCase):
    def test_there_are_vectors(self) -> None:
        self.assertGreaterEqual(len(vectors()), FEWEST_VECTORS)

    def test_every_vector_is_a_vector_and_holds(self) -> None:
        for name, vector in vectors().items():
            with self.subTest(name):
                self.assertEqual(why_not_a_vector(vector), "")
                self.assertEqual(wrong_claims(vector, solver_of(vector)), [])

    def test_a_broken_vector_is_refused_by_its_rule(self) -> None:
        sound = vectors()["australia-in-three-colours.json"]
        changes = [("V1", "solutoin", None), ("V2", "binary", [{"between": ["WA", "NT"], "relation": "unequal"}]),
                   ("V3", "global", [{"over": ["WA"], "relation": "sum"}]),
                   ("V4", "variables", [{"name": "WA", "values": []}]), ("V5", "assignments", 99),
                   ("V6", "solution", {"WA": "red"})]
        for rule, key, value in changes:
            broken = json.loads(json.dumps(sound))
            broken[key] = value
            self.assertTrue(why_not_a_vector(broken).startswith(rule), rule)

    def test_a_solver_that_breaks_ties_to_the_last_fails(self) -> None:
        vector = vectors()["australia-in-three-colours.json"]
        self.assertNotEqual(wrong_claims(vector, solver_of(vector, LastOfEqualVariables)), [])

    def test_a_solver_with_lcv_backwards_fails(self) -> None:
        vector = vectors()["least-constraining-first.json"]
        self.assertNotEqual(wrong_claims(vector, solver_of(vector, MostConstrainingValue)), [])


if __name__ == "__main__":
    unittest.main()
