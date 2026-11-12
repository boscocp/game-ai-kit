"""`gameaikit.sifting`: what the vectors do not say on their own.

The sifter only reads: a record handed to it is the same afterwards, and a
planted sifter that marks the events it used is caught by the same check.
"""

import copy
import unittest

from gameaikit import techniques
from gameaikit.sifting import StorySifter, bindings_if_matches, problem, same

RECORD = [
    {"day": 1, "kind": "deed", "verb": "burn", "place": "barn"},
    {"day": 2, "kind": "night", "place": "market", "fact": "bread", "value": False},
    {"day": 3, "kind": "deed", "verb": "repair", "place": "barn"},
    {"day": 4, "kind": "deed", "verb": "burn", "place": "mill"},
]

REBUILT = {
    "name": "rebuilt",
    "find": [{"as": "burned", "where": {"verb": "burn", "place": "?place"}},
             {"as": "rebuilt", "where": {"verb": "repair", "place": "?place"}}],
    "before": [["burned", "rebuilt"]],
}


def writes_into_the_record(sifter: StorySifter) -> bool:
    """Whether sifting changed the record it was handed."""
    record = copy.deepcopy(RECORD)
    sifter.sift(record, REBUILT)
    return record != RECORD


class TestStorySifter(unittest.TestCase):
    def test_a_match_names_its_events_and_bindings(self) -> None:
        self.assertEqual(StorySifter().sift(RECORD, REBUILT),
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
        self.assertEqual(sifter.sift(RECORD, REBUILT), sifter.sift(RECORD, REBUILT))

    def test_a_pattern_with_a_problem_matches_nothing(self) -> None:
        broken = dict(REBUILT, before=[["burned", "nobody"]])
        self.assertTrue(problem(broken).startswith("P3"))
        self.assertEqual(StorySifter().sift(RECORD, broken), [])

    def test_matching_does_not_change_the_bindings_it_is_given(self) -> None:
        bound = {"place": "barn"}
        self.assertIsNone(bindings_if_matches(RECORD[3], {"place": "?place"}, bound))
        self.assertEqual(bindings_if_matches(RECORD[3], {"verb": "?verb"}, bound),
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
