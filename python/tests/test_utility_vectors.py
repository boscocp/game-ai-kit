"""The Python half of the utility conformance run.

The vectors in `spec/vectors/utility/` fix each choice's answer on a stated
query: every action's score, every consideration's answer behind it and the
action taken; each errand weighed as a gain less its costs, whom a team
sends to fetch, and which errand a bot takes. Both languages answer them and
check every value against the file, never against each other. The answers
came from neither: `derive.py` beside them is a third copy of the rules,
importing nothing from this repository. Until T101 these were teamwork
vectors; they moved unchanged, and the aim vectors after them in T64.
"""

import json
import math
import pathlib
import unittest

from gameaikit.utility import action, aim, errands

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "utility"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 10

#: Shared with `godot/test/ai_utility/utility_vector.gd`.
TOLERANCE = 1e-4

KINDS = ("action", "errands", "aim")


def answer_action(vector: dict) -> dict:
    actions = action.actions_from(vector["query"]["actions"])
    scores, answers, chosen = [], [], []
    for percepts in vector["query"]["percepts"]:
        found, why, taken = action.choose(actions, percepts)
        scores.append(found)
        answers.append(why)
        chosen.append(taken)
    return {"scores": scores, "answers": answers, "chosen": chosen}


def answer_errands(vector: dict) -> dict:
    weights = errands.Weights(**vector["weights"])
    query = vector["query"]
    return {"resupply": [errands.weigh_resupply(errands.Resupply(**each), weights) for each in query["resupply"]],
            "fetch": [errands.weigh_fetch(errands.Fetch(**each), weights) for each in query["fetch"]],
            "hide": [errands.weigh_hide(errands.Hide(**each), weights) for each in query["hide"]],
            "fetcher": [errands.fetcher(scores) for scores in query["teams"]],
            "chosen": [errands.choose(*pair) for pair in query["pairs"]]}


def answer_aim(vector: dict) -> dict:
    query = vector["query"]
    zones = [aim.Zone(each["name"], each["multiplier"], tuple(each["aim"]), [tuple(rect) for rect in each["rects"]],
                      each["exposure"]) for each in query["zones"]]
    choice = aim.choose(zones, query["spread"])
    return {"own_chances": choice.own_chances, "expected": choice.expected, "aimed": choice.aimed,
            "chances": choice.chances, "landed": [aim.land(choice.chances, roll) for roll in query["rolls"]]}


ANSWER = {"action": answer_action, "errands": answer_errands, "aim": answer_aim}


def misses(expected, found, where: str = "") -> list[str]:
    """Every place `found` differs from `expected`, numbers within TOLERANCE."""
    if isinstance(expected, dict):
        if not isinstance(found, dict) or set(expected) != set(found):
            return [f"{where}: keys {sorted(found) if isinstance(found, dict) else found}, the file says {sorted(expected)}"]
        return [line for key in expected for line in misses(expected[key], found[key], f"{where}.{key}")]
    if isinstance(expected, list):
        if not isinstance(found, list) or len(found) != len(expected):
            return [f"{where}: {found}, the file says {expected}"]
        return [line for index, item in enumerate(expected) for line in misses(item, found[index], f"{where}[{index}]")]
    if isinstance(expected, float) and not isinstance(found, bool):
        return [] if math.isclose(found, expected, abs_tol=TOLERANCE) else [f"{where}: {found}, the file says {expected}"]
    return [] if found == expected else [f"{where}: {found!r}, the file says {expected!r}"]


def vector_files() -> list[pathlib.Path]:
    return sorted(VECTORS.glob("*.json"))


class UtilityVectorTests(unittest.TestCase):
    def test_the_directory_holds_every_kind(self) -> None:
        kinds = [json.loads(path.read_text(encoding="utf-8"))["kind"] for path in vector_files()]
        self.assertGreaterEqual(len(kinds), FEWEST_VECTORS)
        self.assertEqual(sorted(set(kinds)), sorted(KINDS))

    def test_every_answer_is_the_files(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                self.assertEqual(misses(vector["expect"], ANSWER[vector["kind"]](vector)), [])

    def test_a_planted_wrong_answer_is_caught(self) -> None:
        # The comparison above, shown each kind's answer moved: it has to fail.
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            answer = ANSWER[vector["kind"]](vector)
            first_key = sorted(answer)[0]
            answer[first_key] = "planted"
            with self.subTest(vector=path.name):
                self.assertTrue(misses(vector["expect"], answer))

    def test_actions_with_an_unknown_key_or_curve_are_refused(self) -> None:
        good = [{"name": "go", "weight": 1.0, "considerations": [{"percept": "x", "curve": "step", "at": 0.5}]}]
        self.assertEqual(action.why_not_actions(good), "")
        self.assertEqual(len(action.actions_from(good)), 1)
        for planted in ([{"name": "go", "wieght": 1.0}],
                        [{"name": "go", "considerations": [{"percept": "x", "curve": "stepp"}]}],
                        [{"name": "go", "considerations": [{"percept": "x", "slop": 2.0}]}],
                        [{"weight": 1.0}]):
            with self.subTest(planted=planted):
                with self.assertRaises(ValueError):
                    action.actions_from(planted)

    def test_a_number_off_by_ten_tolerances_is_caught(self) -> None:
        self.assertTrue(misses(1.0, 1.0 + 10 * TOLERANCE))
        self.assertFalse(misses(1.0, 1.0 + TOLERANCE / 10))


if __name__ == "__main__":
    unittest.main()
