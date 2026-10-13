"""The JSON reader refuses a malformed controller with `F0`, never a crash.

Each case below used to escape as a `TypeError`, a `ValueError`, or a number
quietly truncated -- found by a review feeding the reader broken vectors.
"""

import copy
import unittest

from gameaikit.fuzzy import FuzzyError, from_dictionary

SOUND = {
    "inputs": [{"name": "noise", "minimum": 0, "maximum": 10,
                "sets": {"quiet": [0, 0, 2, 6], "loud": [4, 8, 10, 10]}}],
    "outputs": [{"name": "alertness", "minimum": 0, "maximum": 100, "samples": 11,
                 "sets": {"calm": [0, 0, 20, 50], "alarmed": [50, 80, 100, 100]}}],
    "rules": [{"if": [["noise", "quiet"]], "then": ["alertness", "calm"]},
              {"if": [["noise", "loud"]], "then": ["alertness", "alarmed"]}],
}


def but(path: tuple, value: object) -> dict:
    """The sound controller with one field replaced."""
    data = copy.deepcopy(SOUND)
    target = data
    for step in path[:-1]:
        target = target[step]
    target[path[-1]] = value
    return data


class LoadingTests(unittest.TestCase):
    def test_the_sound_controller_reads(self) -> None:
        self.assertEqual(from_dictionary(SOUND).outputs[0].samples, 11)

    def test_samples_written_as_a_whole_float_read(self) -> None:
        self.assertEqual(from_dictionary(but(("outputs", 0, "samples"), 11.0)).outputs[0].samples, 11)

    def test_every_malformed_shape_is_refused_with_f0(self) -> None:
        broken = {
            "inputs is not a list": but(("inputs",), 5),
            "a variable is not an object": but(("inputs", 0), "noise"),
            "a variable with no name": but(("outputs", 0, "name"), None),
            "a minimum that is a word": but(("inputs", 0, "minimum"), "low"),
            "a point that is a word": but(("inputs", 0, "sets", "quiet"), ["a", 0, 2, 6]),
            "a point that is null": but(("inputs", 0, "sets", "quiet"), [0, None, 2, 6]),
            "a set that is not a list": but(("inputs", 0, "sets", "quiet"), "low"),
            "fractional samples": but(("outputs", 0, "samples"), 2.9),
            "samples that are a word": but(("outputs", 0, "samples"), "eleven"),
            "a rule with no if": but(("rules", 0), {"then": ["alertness", "calm"]}),
            "a conclusion of one name": but(("rules", 0, "then"), ["alertness"]),
            "a condition of three names": but(("rules", 0, "if"), [["noise", "quiet", "x"]]),
            "a connective that is a number": but(("rules", 0, "connective"), 1),
        }
        for label, data in broken.items():
            with self.subTest(label), self.assertRaisesRegex(FuzzyError, "^F0"):
                from_dictionary(data)

    def test_a_shape_error_is_not_a_meaning_error(self) -> None:
        # The right shape and an unknown set is the controller's to refuse.
        with self.assertRaisesRegex(FuzzyError, "^F7"):
            from_dictionary(but(("rules", 0, "then"), ["alertness", "bored"]))


if __name__ == "__main__":
    unittest.main()
