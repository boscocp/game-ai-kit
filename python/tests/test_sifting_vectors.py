"""The Python half of the story sifting conformance run.

The vectors in `spec/vectors/sifting/` are read from both languages, and
each side checks every claim in them against the file -- never against the
other side. The matches came from neither: `derive.py`, importing nothing
from this repository, tried every ordered choice of events instead of
searching (the README works one by hand).
"""

import json
import pathlib
import unittest

from gameaikit.sifting import StorySifter, bindings_if_matches, problem, same

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "sifting"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 15

VECTOR_KEYS = {"description", "events", "pattern", "refused", "matches"}
RULES = {"P1", "P2", "P3", "P4", "P5"}


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable vector, or "" when it is one."""
    if set(vector) != VECTOR_KEYS:
        return f"V1 its keys are {sorted(vector)}, not {sorted(VECTOR_KEYS)}"
    if vector["refused"] not in RULES | {""}:
        return f"V2 it is refused by {vector['refused']!r}, which is no rule"
    if vector["refused"] and vector["matches"]:
        return "V3 a refused pattern claims a match"
    names = sorted(clause.get("as") for clause in vector["pattern"].get("find", []) if isinstance(clause, dict))
    for match in vector["matches"]:
        if set(match) != {"events", "bindings"} or sorted(match["events"]) != names:
            return f"V4 a match {match} does not name every event to find"
        if any(not 0 <= index < len(vector["events"]) for index in match["events"].values()):
            return f"V5 a match {match} names an event the record does not have"
    return ""


def _same_table(found: dict, claimed: dict) -> bool:
    return found.keys() == claimed.keys() and all(same(found[key], claimed[key]) for key in claimed)


def wrong_claims(vector: dict, sifter=None) -> list[str]:
    """Every claim in the vector that `sifter` does not meet."""
    sifter = sifter or StorySifter()
    if vector["refused"]:
        found = problem(vector["pattern"])
        return [] if found.startswith(vector["refused"]) else [f"refused by {found!r}, not {vector['refused']}"]
    if problem(vector["pattern"]):
        return [f"the pattern is refused: {problem(vector['pattern'])}"]
    found = sifter.sift(vector["events"], vector["pattern"])
    if len(found) != len(vector["matches"]):
        return [f"{len(found)} match(es), not {len(vector['matches'])}: {found}"]
    return [f"match {place}: {got}, not {claimed}" for place, (got, claimed) in enumerate(zip(found, vector["matches"]))
            if not (_same_table(got["events"], claimed["events"])
                    and _same_table(got["bindings"], claimed["bindings"]))]


def _vectors() -> dict[str, dict]:
    return {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(VECTORS.glob("*.json"))}


class TestSiftingVectors(unittest.TestCase):
    def test_the_directory_holds_vectors(self) -> None:
        self.assertGreaterEqual(len(_vectors()), FEWEST_VECTORS)

    def test_every_vector_is_one(self) -> None:
        for name, vector in _vectors().items():
            with self.subTest(name):
                self.assertEqual(why_not_a_vector(vector), "")

    def test_every_rule_has_a_refused_vector(self) -> None:
        self.assertEqual({vector["refused"] for vector in _vectors().values()} - {""}, RULES)

    def test_the_sifter_finds_every_claimed_match(self) -> None:
        for name, vector in _vectors().items():
            with self.subTest(name):
                self.assertEqual(wrong_claims(vector), [])

    def test_a_broken_vector_is_refused_by_its_rule(self) -> None:
        sound = _vectors()["every-later-repair"]
        changes = [("V1", {"match": []}), ("V2", {"refused": "P9"}), ("V3", {"refused": "P1"}),
                   ("V4", {"matches": [{"events": {"down": 4}, "bindings": {}}]}),
                   ("V5", {"matches": [{"events": {"down": 4, "up": 99}, "bindings": {}}]})]
        for rule, change in changes:
            with self.subTest(rule):
                self.assertTrue(why_not_a_vector(dict(sound, **change)).startswith(rule))

    def test_a_sifter_that_lets_two_events_be_one_fails(self) -> None:
        class OneEventTwice(StorySifter):
            def _extend(self, events, pattern, found, bound, matches):
                clauses = pattern["find"]
                if len(found) == len(clauses):
                    matches.append({"events": dict(found), "bindings": dict(bound)})
                    return
                clause = clauses[len(found)]
                for index, event in enumerate(events):
                    binds = bindings_if_matches(event, clause["where"], bound)
                    if binds is not None:
                        found[clause["as"]] = index
                        self._extend(events, pattern, found, binds, matches)
                        del found[clause["as"]]

        self.assertNotEqual(wrong_claims(_vectors()["two-events-are-two-events"], OneEventTwice()), [])

    def test_a_sifter_that_forgets_unless_fails(self) -> None:
        class NoUnless(StorySifter):
            @staticmethod
            def _absent_found(events, pattern, found, bound):
                return False

        for name in ("unless-between-keeps-the-next-one", "the-third-time", "unless-after-never-again"):
            with self.subTest(name):
                self.assertNotEqual(wrong_claims(_vectors()[name], NoUnless()), [])


if __name__ == "__main__":
    unittest.main()
