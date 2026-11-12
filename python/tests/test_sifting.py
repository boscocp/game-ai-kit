"""`gameaikit.sifting`: what the vectors do not say on their own.

The sifter only reads: a record handed to it is the same afterwards, and a
planted sifter that marks the events it used is caught by the same check.
Every test builds its own record with `record()`: a record shared between
tests would carry a writing sifter's marks from one test into the next,
and the check would compare a marked record with a marked copy (review
189, finding 1).
"""

import json
import unittest

from gameaikit import techniques
from gameaikit.sifting import StorySifter, bindings_if_matches, problem, same

REBUILT = {
    "name": "rebuilt",
    "find": [{"as": "burned", "where": {"verb": "burn", "place": "?place"}},
             {"as": "rebuilt", "where": {"verb": "repair", "place": "?place"}}],
    "before": [["burned", "rebuilt"]],
    "unless": [{"where": {"verb": "repair", "place": "?place"}, "after": "burned", "before": "rebuilt"}],
}

#: The record as JSON, the one form no sifter can reach and change.
RECORD_TEXT = json.dumps([
    {"day": 1, "kind": "deed", "verb": "burn", "place": "barn"},
    {"day": 2, "kind": "night", "place": "market", "fact": "bread", "value": False},
    {"day": 3, "kind": "deed", "verb": "repair", "place": "barn"},
    {"day": 4, "kind": "deed", "verb": "burn", "place": "mill"},
])


def record() -> list[dict]:
    """A record of its own, for one test."""
    return json.loads(RECORD_TEXT)


def writes_into_the_record(sifter: StorySifter) -> bool:
    """Whether sifting changed the record it was handed, against its JSON text."""
    events = record()
    sifter.sift(events, REBUILT)
    return json.dumps(events) != RECORD_TEXT


class TestStorySifter(unittest.TestCase):
    def test_a_match_names_its_events_and_bindings(self) -> None:
        self.assertEqual(StorySifter().sift(record(), REBUILT),
                         [{"events": {"burned": 0, "rebuilt": 2}, "bindings": {"place": "barn"}}])

    def test_the_sifter_leaves_the_record_as_it_was(self) -> None:
        self.assertFalse(writes_into_the_record(StorySifter()))

    def test_a_sifter_that_marks_what_it_used_is_caught(self) -> None:
        class Marking(StorySifter):
            def sift(self, events, pattern):
                found = super().sift(events, pattern)
                for match in found:
                    for index in match["events"].values():
                        events[index]["told"] = True
                return found

        self.assertTrue(writes_into_the_record(Marking()))

    def test_sifting_twice_gives_the_same_matches(self) -> None:
        sifter = StorySifter()
        events = record()
        self.assertEqual(sifter.sift(events, REBUILT), sifter.sift(events, REBUILT))

    def test_a_pattern_with_a_problem_matches_nothing(self) -> None:
        broken = dict(REBUILT, before=[["burned", "nobody"]])
        self.assertTrue(problem(broken).startswith("P3"))
        self.assertEqual(StorySifter().sift(record(), broken), [])

    def test_matching_does_not_change_the_bindings_it_is_given(self) -> None:
        bound = {"place": "barn"}
        burned_mill = record()[3]
        self.assertIsNone(bindings_if_matches(burned_mill, {"place": "?place"}, bound))
        self.assertEqual(bindings_if_matches(burned_mill, {"verb": "?verb"}, bound),
                         {"place": "barn", "verb": "burn"})
        self.assertEqual(bound, {"place": "barn"})

    def test_a_flag_is_never_a_number(self) -> None:
        self.assertFalse(same(True, 1))
        self.assertFalse(same(0, False))
        self.assertTrue(same(1, 1.0))
        self.assertFalse(same(None, None))

    def test_the_kit_lists_it(self) -> None:
        self.assertIs(techniques.kit()["sifting"].entry, StorySifter)


if __name__ == "__main__":
    unittest.main()
