"""The Python half of the Bayesian network conformance run.

The vectors in `spec/vectors/bayes/` are read from both languages, and each
side checks every claim in them against the file -- never against the other
side. The answers came from neither: `derive.py`, importing nothing from
this repository, wrote them from the full joint distribution, not by
enumeration (the README works the burglary by hand).
"""

import json
import pathlib
import unittest

from gameaikit.bayes import BayesNetwork

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "bayes"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 7

#: The margin both sides allow on a chance. The vectors were summed in
#: another order than enumeration sums, so the last bits may differ.
TOLERANCE = 1e-12

VECTOR_KEYS = {"description", "network", "problem", "queries"}
QUERY_KEYS = {"query", "value", "evidence", "distribution", "influence"}


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable vector, or "" when it is one."""
    if set(vector) != VECTOR_KEYS:
        return f"V1 its keys are {sorted(vector)}, not {sorted(VECTOR_KEYS)}"
    if bool(vector["problem"]) == bool(vector["queries"]):
        return "V2 it must either name the rule a network is refused by, or ask it something -- one, not both"
    for asked in vector["queries"]:
        if set(asked) != QUERY_KEYS:
            return f"V3 a query's keys are {sorted(asked)}, not {sorted(QUERY_KEYS)}"
        if asked["distribution"] and abs(sum(asked["distribution"]) - 1.0) > 1e-9:
            return "V4 a distribution does not sum to 1"
        if asked["distribution"] and list(asked["influence"]) != list(asked["evidence"]):
            return "V5 an influence does not name exactly the evidence, in its order"
    return ""


def _close(found: list[float], claimed: list[float]) -> bool:
    return len(found) == len(claimed) and all(abs(one - other) <= TOLERANCE for one, other in zip(found, claimed))


def wrong_claims(vector: dict, make=BayesNetwork) -> list[str]:
    """Every claim in the vector that the network `make` builds does not meet."""
    network = make(vector["network"])
    if vector["problem"]:
        found = network.problem()
        return [] if found.startswith(vector["problem"]) else [f"refused with {found!r}, not {vector['problem']}"]
    if network.problem():
        return [f"refused a sound network: {network.problem()}"]
    wrong = []
    for index, asked in enumerate(vector["queries"]):
        distribution = network.ask(asked["query"], asked["evidence"])
        if not _close(distribution, asked["distribution"]):
            wrong.append(f"query {index}: {distribution}, not {asked['distribution']}")
        moved = network.influence(asked["query"], asked["value"], asked["evidence"])
        claimed = asked["influence"]
        if list(moved) != list(claimed) or not _close(list(moved.values()), list(claimed.values())):
            wrong.append(f"query {index}: influence {moved}, not {claimed}")
    return wrong


def _vectors() -> dict[str, dict]:
    return {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(VECTORS.glob("*.json"))}


class TestBayesVectors(unittest.TestCase):
    def test_the_directory_holds_vectors(self) -> None:
        self.assertGreaterEqual(len(_vectors()), FEWEST_VECTORS)

    def test_every_vector_is_one(self) -> None:
        for name, vector in _vectors().items():
            with self.subTest(name):
                self.assertEqual(why_not_a_vector(vector), "")

    def test_the_network_meets_every_claim(self) -> None:
        for name, vector in _vectors().items():
            with self.subTest(name):
                self.assertEqual(wrong_claims(vector), [])

    def test_a_broken_vector_is_refused_by_its_rule(self) -> None:
        sound = _vectors()["burglary-john-and-mary-call"]
        asked = sound["queries"][0]
        for rule, change in [("V1", {"queris": []}), ("V2", {"problem": "B3"}),
                             ("V3", {"queries": [dict(asked, valu="yes")]}),
                             ("V4", {"queries": [dict(asked, distribution=[0.5, 0.6])]}),
                             ("V5", {"queries": [dict(asked, influence={"mary_calls": 0.1})]})]:
            with self.subTest(rule):
                broken = {key: value for key, value in sound.items() if not (rule == "V1" and key == "queries")}
                self.assertTrue(why_not_a_vector(dict(broken, **change)).startswith(rule))

    def test_a_network_that_reads_rows_the_wrong_way_fails(self) -> None:
        class LastParentSlowest(BayesNetwork):
            def probability(self, variable, value, assignment):
                row = 0
                for parent in reversed(self.parents[variable]):
                    row = row * len(self.values[parent]) + self.values[parent].index(assignment[parent])
                return float(self.tables[variable][row][self.values[variable].index(value)])

        self.assertNotEqual(wrong_claims(_vectors()["three-values-and-two-parents"], LastParentSlowest), [])

    def test_a_network_that_ignores_hidden_values_fails(self) -> None:
        class FirstValueOnly(BayesNetwork):
            def _enumerate_all(self, index, assignment):
                if index < len(self.names) and self.names[index] not in assignment:
                    assignment = dict(assignment, **{self.names[index]: self.values[self.names[index]][0]})
                return super()._enumerate_all(index, assignment)

        self.assertNotEqual(wrong_claims(_vectors()["burglary-john-and-mary-call"], FirstValueOnly), [])

    def test_a_network_that_takes_any_row_fails_the_refusals(self) -> None:
        class NoRowCheck(BayesNetwork):
            def _table_problem(self, name, own, above, table):
                return ""

        refusals = [vector for vector in _vectors().values() if vector["problem"] in ("B4", "B5")]
        self.assertTrue(refusals)
        for vector in refusals:
            self.assertNotEqual(wrong_claims(vector, NoRowCheck), [])


if __name__ == "__main__":
    unittest.main()
