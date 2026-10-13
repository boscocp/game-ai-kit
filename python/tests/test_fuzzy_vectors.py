"""The Python half of the fuzzy conformance run.

The vectors in `spec/vectors/fuzzy/` are read from both languages, and each
side checks every claim in them against the file -- never against the other
side. The numbers came from neither: an exact-fraction script importing
nothing from this repository produced them, and the two small vectors can be
checked by hand (the arithmetic is in the README beside them).
"""

import json
import math
import pathlib
import unittest

from gameaikit.fuzzy import from_dictionary, read_fcl

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "fuzzy"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 3

#: The margin both sides allow, scaled by the size of the answer.
TOLERANCE = 1e-9


def vector_files() -> list[pathlib.Path]:
    """Every vector, in a fixed order."""
    return sorted(VECTORS.glob("*.json"))


def close_enough(found: float, expected: float | None) -> bool:
    """Equal to the last places of a double; `None` in a file means NaN."""
    if expected is None:
        return math.isnan(found)
    return abs(found - expected) <= TOLERANCE * max(1.0, abs(expected))


#: Every key a case of each kind may carry. A misspelt key is otherwise
#: ignored in silence, and `"betwen"` drops the very claim T13 asks for while
#: every number in the file still passes.
CASE_KEYS = {
    "membership": {"kind", "why", "variable", "set", "value", "degree"},
    "fuzzify": {"kind", "why", "variable", "value", "degrees"},
    "evaluate": {"kind", "why", "name", "inputs", "activations", "outputs", "between"},
}


def strictly_between(found: float, one: float, other: float) -> bool:
    """`found` lies strictly inside the interval the other two make."""
    low, high = sorted((one, other))
    return low < found < high


def all_cases() -> list[tuple[str, dict]]:
    """Every case of every vector, with the file it came from."""
    return [(path.name, case) for path in vector_files()
            for case in json.loads(path.read_text(encoding="utf-8"))["cases"]]


class FuzzyVectorTests(unittest.TestCase):
    def test_there_are_vectors_to_check(self) -> None:
        self.assertGreaterEqual(len(vector_files()), FEWEST_VECTORS)

    def test_every_case_holds(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            controller = from_dictionary(vector["controller"])
            answers = {}
            for case in vector["cases"]:
                with self.subTest(vector=path.name, case=case.get("name", case["why"])):
                    self._check(controller, case, answers)

    def test_the_case_t13_asks_for_is_present(self) -> None:
        # The two rules' own outputs on either side, by name: counting claims
        # let the one T13 names be deleted while the count stayed above two.
        found = {(name, case.get("name")): case for name, case in all_cases()}
        both = found[("two-rules-overlap.json", "both")]
        self.assertEqual(both["between"], ["only-calm", "only-alarmed"])

    def test_every_case_carries_only_the_keys_its_kind_allows(self) -> None:
        for name, case in all_cases():
            with self.subTest(vector=name, case=case.get("name", case.get("why"))):
                self.assertIn(case.get("kind"), CASE_KEYS)
                self.assertLessEqual(set(case), CASE_KEYS[case["kind"]])

    def test_the_check_applies_between_to_an_answer_at_one_end(self) -> None:
        # The planted case for the *call site*: the helper below has its own,
        # and deleting the line that calls it left every other test green.
        vector = json.loads((VECTORS / "two-rules-overlap.json").read_text(encoding="utf-8"))
        controller = from_dictionary(vector["controller"])
        answers: dict = {}
        cases = {case["name"]: case for case in vector["cases"]}
        for name in ("only-calm", "only-alarmed"):
            self._check_evaluation(controller, cases[name], answers)
        at_one_end = dict(cases["only-calm"], name="planted",
                          between=["only-calm", "only-alarmed"])
        with self.assertRaises(AssertionError):
            self._check_evaluation(controller, at_one_end, answers)

    def test_strictly_between_refuses_an_end(self) -> None:
        # The planted case for the check below: an answer equal to one end.
        self.assertFalse(strictly_between(15.0, 15.0, 85.0))
        self.assertFalse(strictly_between(85.0, 15.0, 85.0))
        self.assertTrue(strictly_between(50.0, 85.0, 15.0))

    def test_the_text_file_describes_the_same_controller(self) -> None:
        for text_path in sorted(VECTORS.glob("*.fcl")):
            with self.subTest(file=text_path.name):
                vector = json.loads(text_path.with_suffix(".json").read_text(encoding="utf-8"))
                self.assertEqual(read_fcl(text_path.read_text(encoding="utf-8")),
                                 from_dictionary(vector["controller"]))

    def _check(self, controller, case: dict, answers: dict) -> None:
        if case["kind"] == "membership":
            variable = next(one for one in controller.inputs if one.name == case["variable"])
            found = variable.set_named(case["set"]).degree(case["value"])
            self.assertTrue(close_enough(found, case["degree"]), found)
        elif case["kind"] == "fuzzify":
            variable = next(one for one in controller.inputs if one.name == case["variable"])
            found = variable.fuzzify(case["value"])
            self.assertEqual(set(found), set(case["degrees"]))
            for name, degree in case["degrees"].items():
                self.assertTrue(close_enough(found[name], degree), (name, found[name]))
        else:
            self._check_evaluation(controller, case, answers)

    def _check_evaluation(self, controller, case: dict, answers: dict) -> None:
        strengths = controller.activations(case["inputs"])
        for output, expected in case["activations"].items():
            self.assertEqual(set(strengths[output]), set(expected))
            for term, strength in expected.items():
                self.assertTrue(close_enough(strengths[output][term], strength), term)
        found = controller.evaluate(case["inputs"])
        for output, expected in case["outputs"].items():
            self.assertTrue(close_enough(found[output], expected), (output, found[output]))
        answers[case["name"]] = found
        for output in case["outputs"]:
            if "between" in case:
                one, other = (answers[name][output] for name in case["between"])
                self.assertTrue(strictly_between(found[output], one, other),
                                (output, found[output], one, other))


if __name__ == "__main__":
    unittest.main()
