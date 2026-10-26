"""The model file's refusals, held to the vectors the game is held to.

`spec/vectors/model_file/refusals.json` names, for every file in it, the code
of the first rule it breaks -- or the models it publishes and the fields
beside them. `godot/test/ai_learning/model_file_test.gd` reads the same file
through `ModelFile`; this reads it through `gameaikit.training.model_file`.
"""

import json
import pathlib
import tempfile
import unittest

from gameaikit.training import model_file
from gameaikit.training.models import Model

VECTOR = (pathlib.Path(__file__).resolve().parents[2]
          / "spec" / "vectors" / "model_file" / "refusals.json")


def answer(case: dict) -> str:
    """What this side makes of one case: a code, or what loaded, in one string."""
    if "text" in case:
        wrong = model_file.why_text_is_wrong(case["text"], "the vector")
        data = None if wrong else json.loads(case["text"])
    else:
        data = case["file"]
        wrong = model_file.why_wrong(data)
    if wrong:
        return wrong.split(" ", 1)[0]
    extra = sorted(name for name in data if name != "models")
    return f"loads {sorted(data['models'])} beside {extra}"


def claimed(case: dict) -> str:
    """What the vector says about the same case, in the same string."""
    if "refused" in case:
        return case["refused"]
    return f"loads {sorted(case['loads'])} beside {sorted(case['extra'])}"


class TheVectors(unittest.TestCase):

    def test_every_case_gets_the_answer_the_vector_claims(self) -> None:
        cases = json.loads(VECTOR.read_text(encoding="utf-8"))["cases"]
        self.assertGreater(len(cases), 10)
        for case in cases:
            with self.subTest(case["why"]):
                self.assertEqual(answer(case), claimed(case))

    def test_a_wrong_claim_is_caught(self) -> None:
        # The planted case for the comparison itself: a vector whose every
        # claim this side meets is worth something only if a wrong one fails.
        # Each kind of claim made wrong, and put through the same comparison.
        cases = json.loads(VECTOR.read_text(encoding="utf-8"))["cases"]
        wrong_code = dict(cases[4], refused="M4")
        wrong_names = dict(cases[0], loads=["somebody else's"])
        wrong_fields = dict(cases[1], extra=["generated_by"])
        for wrong in (wrong_code, wrong_names, wrong_fields):
            with self.subTest(wrong["why"]):
                self.assertNotEqual(answer(wrong), claimed(wrong))

    def test_the_first_wrong_feature_name_is_the_one_reported(self) -> None:
        # The code alone cannot tell the two M6 sentences apart, so this one
        # case is held to its sentence: the game walks the names once, in
        # order, and reports the repeat before the number after it.
        data = {"models": {"only": {"kind": "linear", "features": ["a", "a", 1],
                                    "weights": [1.0, 1.0, 1.0], "bias": 0.0}}}
        self.assertIn("twice", model_file.why_wrong(data))

    def test_every_refusal_code_has_a_case(self) -> None:
        # A rule with no case in the vector can be deleted from either
        # language with both suites green.
        cases = json.loads(VECTOR.read_text(encoding="utf-8"))["cases"]
        covered = {case["refused"] for case in cases if "refused" in case}
        self.assertEqual(covered, {"M2", "M3", "M4", "M5", "M6", "M7", "M8", "M10"})

    def test_a_parse_error_is_placed_on_the_line_an_editor_shows(self) -> None:
        # Counted from 1, as the game counts it: the third line here.
        wrong = model_file.why_text_is_wrong('{\n"a": 1,\n oops\n}', "the test")
        self.assertTrue(wrong.endswith("at line 3"), wrong)


class TheFileOnDisk(unittest.TestCase):

    def test_a_missing_file_is_refused_by_name(self) -> None:
        self.assertTrue(model_file.why_unreadable(
            pathlib.Path("/nonexistent/weights.json")).startswith("M1 "))

    def test_what_the_writer_writes_the_reader_loads(self) -> None:
        model = Model(kind="logistic", features=("my_health", "their_health"),
                      weights=(0.05, -0.05), bias=0.5,
                      comparable_weights=(1.0, -1.0), rows_trained_on=40)
        published = model_file.as_json({"chance": model}, "a test", my_radius=3)
        self.assertEqual(list(published), ["generated_by", "my_radius", "models"])
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "weights.json"
            path.write_text(json.dumps(published), encoding="utf-8")
            self.assertEqual(model_file.why_unreadable(path), "")


if __name__ == "__main__":
    unittest.main()
