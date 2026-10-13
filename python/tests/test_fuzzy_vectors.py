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

    def test_a_between_claim_is_strict(self) -> None:
        # T13 asks for one case whose answer lies strictly between two others.
        # A file that loses its `between` claims still passes every number in
        # it, so the claim's presence is checked here rather than assumed.
        claims = [case for path in vector_files()
                  for case in json.loads(path.read_text(encoding="utf-8"))["cases"]
                  if "between" in case]
        self.assertGreaterEqual(len(claims), 2)

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
                low, high = sorted(answers[name][output] for name in case["between"])
                self.assertLess(low, found[output])
                self.assertLess(found[output], high)


if __name__ == "__main__":
    unittest.main()
