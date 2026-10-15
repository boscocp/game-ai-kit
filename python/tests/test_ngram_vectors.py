"""The Python half of the n-gram conformance run.

The vectors in `spec/vectors/ngram/` are read from both languages, and each
side checks every claim in them against the file -- never against the other
side. The numbers came from neither: an exact-fraction script importing
nothing from this repository wrote them (the README works one by hand).
"""

import json
import math
import pathlib
import unittest

from gameaikit.ngram import NGramPredictor

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "ngram"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 4

#: The margin both sides allow: a different formula, never a different maths library.
TOLERANCE = 1e-9

VECTOR_KEYS = {"description", "order", "actions", "decay", "prior", "sequence", "cases"}
CASE_KEYS = {"seen", "context", "probabilities", "likeliest"}


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable vector, or "" when it is one."""
    if set(vector) != VECTOR_KEYS:
        return f"V1 its keys are {sorted(vector)}, not {sorted(VECTOR_KEYS)}"
    if not vector["cases"]:
        return "V2 it claims nothing"
    for case in vector["cases"]:
        if set(case) != CASE_KEYS:
            return f"V3 a case's keys are {sorted(case)}, not {sorted(CASE_KEYS)}"
        if set(case["probabilities"]) != set(vector["actions"]):
            return "V4 a case's probabilities do not name every action"
        if not math.isclose(sum(case["probabilities"].values()), 1.0, abs_tol=TOLERANCE):
            return "V5 a case's probabilities do not sum to 1"
        if not 0 <= case["seen"] <= len(vector["sequence"]):
            return "V6 a case is after more actions than the sequence has"
    return ""


def wrong_claims(vector: dict, make=NGramPredictor) -> list[str]:
    """Every claim in the vector the predictor `make` builds does not meet."""
    predictor = make(vector["order"], vector["actions"], vector["decay"], vector["prior"])
    claims = {case["seen"]: case for case in vector["cases"]}
    wrong = []
    for seen in range(len(vector["sequence"]) + 1):
        if seen in claims:
            wrong += _against(predictor, claims[seen])
        if seen < len(vector["sequence"]):
            predictor.observe(vector["sequence"][seen])
    return wrong


def _against(predictor: NGramPredictor, case: dict) -> list[str]:
    found = predictor.probabilities()
    wrong = []
    if predictor.context() != case["context"]:
        wrong.append(f"after {case['seen']}: context {predictor.context()!r}, not {case['context']!r}")
    for action, expected in case["probabilities"].items():
        if abs(found[action] - expected) > TOLERANCE:
            wrong.append(f"after {case['seen']}: {action} {found[action]}, not {expected}")
    if predictor.likeliest() != case["likeliest"]:
        wrong.append(f"after {case['seen']}: likeliest {predictor.likeliest()}, not {case['likeliest']}")
    return wrong


class NeverForgets(NGramPredictor):
    """A planted predictor that ignores its decay: the one T17's decay is for."""

    def __init__(self, order, actions, decay=1.0, prior=1.0):
        super().__init__(order, actions, 1.0, prior)


class TestNGramVectors(unittest.TestCase):
    def vectors(self) -> dict[str, dict]:
        files = sorted(VECTORS.glob("*.json"))
        self.assertGreaterEqual(len(files), FEWEST_VECTORS, f"found {len(files)} vectors under {VECTORS}")
        return {path.name: json.loads(path.read_text(encoding="utf-8")) for path in files}

    def test_every_vector_is_a_vector_and_every_claim_holds(self) -> None:
        for name, vector in self.vectors().items():
            with self.subTest(vector=name):
                self.assertEqual(why_not_a_vector(vector), "")
                self.assertEqual(wrong_claims(vector), [])

    def test_a_predictor_that_never_forgets_fails_the_decay_vector(self) -> None:
        decay = self.vectors()["decay-follows-a-change.json"]
        self.assertNotEqual(wrong_claims(decay, NeverForgets), [])

    def test_a_broken_vector_is_refused(self) -> None:
        vector = self.vectors()["order-two-by-hand.json"]
        misspelt = dict(vector, cases=[dict(vector["cases"][0], likelist="high")])
        self.assertIn("V3", why_not_a_vector(misspelt))
        short = dict(vector, cases=[dict(vector["cases"][0], probabilities={"high": 1.0})])
        self.assertIn("V4", why_not_a_vector(short))
        lopsided = dict(vector, cases=[dict(vector["cases"][0], probabilities={"high": 0.5, "low": 0.5, "throw": 0.5})])
        self.assertIn("V5", why_not_a_vector(lopsided))
        self.assertIn("V1", why_not_a_vector({key: vector[key] for key in vector if key != "decay"}))


if __name__ == "__main__":
    unittest.main()
