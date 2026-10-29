"""The Python half of the perception conformance run.

The vectors in `spec/vectors/perception/` fix each technique's answer on a
stated query: the zone and certainty of a look, a loudness along a path,
an awareness over a run of steps and the phase it reads as, a belief
over a run of percepts, and a particle cloud drawn from a stated seed. Both languages answer them and check every value
against the file, never against each other. `derive.py` beside them is a
third copy of the rules, importing nothing from this repository.
"""

import json
import pathlib
import unittest

from gameaikit.perception import awareness, belief, hearing, particles, shape

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "perception"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 12

#: Shared with `godot/test/ai_perception/perception_vector.gd`.
TOLERANCE = 1e-9

KINDS = ("shape", "loudness", "awareness", "phase", "belief", "particles")


def answer_shape(vector: dict) -> dict:
    looks = [shape.Look(**each) for each in vector["query"]["looks"]]
    answers = [shape.percept(vector["shape"], each) for each in looks]
    return {"zones": [zone for zone, _ in answers], "certainties": [found for _, found in answers]}


def answer_loudness(vector: dict) -> dict:
    return {"loudness": [hearing.loudness(*each) for each in vector["query"]["heard"]]}


def answer_awareness(vector: dict) -> dict:
    number, values, phases = awareness.Awareness(), [], []
    for each in vector["query"]["steps"]:
        number.step(vector["row"], each["perceived"], each["rate"], each["seconds"], each["now"])
        values.append(number.value)
        phases.append(awareness.phase(number.value, vector["row"]))
    return {"values": values, "phases": phases}


def answer_phase(vector: dict) -> dict:
    return {"phases": [awareness.phase(each, vector["row"]) for each in vector["query"]["numbers"]]}


def answer_belief(vector: dict) -> dict:
    held = belief.BeliefMap(vector["query"]["neighbours"])
    shares, reseeded = [], []
    for each in vector["query"]["steps"]:
        if "collapse" in each:
            held.collapse(each["collapse"])
        else:
            held.step_unseen(each["seen"], each["spread"])
        shares.append(list(held.shares))
        reseeded.append(held.reseeded)
    return {"shares": shares, "reseeded": reseeded}


def answer_particles(vector: dict) -> dict:
    query = vector["query"]
    cloud = particles.ParticleBelief(query["neighbours"], query["count"], query["seed"])
    cloud.walk_on, cloud.turn, cloud.unheard = (query["knobs"][name] for name in ("walk_on", "turn", "unheard"))
    found = {"nodes": [], "weights": [], "shares": [], "emptied": [], "reseeded": []}
    for each in query["steps"]:
        if "collapse" in each:
            cloud.collapse(each["collapse"])
        else:
            cloud.step_unseen(each["seen"], each["unheard"])
        for name in found:
            value = getattr(cloud, name)
            found[name].append(list(value) if isinstance(value, list) else value)
    return found


ANSWERS = {"shape": answer_shape, "loudness": answer_loudness, "awareness": answer_awareness,
           "phase": answer_phase, "belief": answer_belief, "particles": answer_particles}


def differences(expected, answer, where: str) -> list[str]:
    """Every place `answer` differs from `expected`, numbers within TOLERANCE."""
    if isinstance(expected, dict):
        if not isinstance(answer, dict) or answer.keys() != expected.keys():
            return [f"{where}: {answer}, the file says {expected}"]
        return [line for key in expected for line in differences(expected[key], answer[key], f"{where}.{key}")]
    if isinstance(expected, list):
        if not isinstance(answer, list) or len(answer) != len(expected):
            return [f"{where}: {answer}, the file says {expected}"]
        return [line for i, item in enumerate(expected) for line in differences(item, answer[i], f"{where}[{i}]")]
    if isinstance(expected, bool) or isinstance(answer, bool):
        return [] if expected == answer else [f"{where}: {answer}, the file says {expected}"]
    if abs(float(answer) - float(expected)) > TOLERANCE:
        return [f"{where}: {answer}, the file says {expected}"]
    return []


def vectors() -> list[dict]:
    return [json.loads(path.read_text()) for path in sorted(VECTORS.glob("*.json"))]


class PerceptionVectorTest(unittest.TestCase):
    def test_there_are_enough_vectors_of_every_kind(self):
        found = vectors()
        self.assertGreaterEqual(len(found), FEWEST_VECTORS)
        self.assertEqual({each["kind"] for each in found}, set(KINDS))

    def test_every_vector(self):
        for vector in vectors():
            with self.subTest(vector["name"]):
                self.assertEqual(differences(vector["expect"], ANSWERS[vector["kind"]](vector), vector["name"]), [])

    def test_the_comparison_sees_a_wrong_answer(self):
        # The planted case: a certainty off by more than the tolerance, and a
        # reseed flag flipped, must each be named.
        self.assertTrue(differences({"c": [0.5]}, {"c": [0.5 + 1e-6]}, "planted"))
        self.assertTrue(differences({"r": [True]}, {"r": [False]}, "planted"))


if __name__ == "__main__":
    unittest.main()
