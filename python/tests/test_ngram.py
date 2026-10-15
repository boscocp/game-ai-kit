"""The n-gram predictor's rules, one test each: the ones a vector cannot show."""

import unittest

from gameaikit.ngram import NGramPredictor


class TestNGramPredictor(unittest.TestCase):
    def test_settings_that_cannot_work_are_named(self) -> None:
        self.assertIn("order", NGramPredictor(0, ["a"]).problem())
        self.assertIn("at least one action", NGramPredictor(1, []).problem())
        self.assertIn("decay", NGramPredictor(1, ["a"], decay=0.0).problem())
        self.assertIn("prior", NGramPredictor(1, ["a", "b"], prior=0.0).problem())
        self.assertEqual(NGramPredictor(2, ["a", "b"], 0.9, 1.0).problem(), "")

    def test_an_action_it_was_not_told_about_is_ignored(self) -> None:
        predictor = NGramPredictor(2, ["a", "b"])
        predictor.observe("a")
        predictor.observe("z")
        self.assertEqual(predictor.context(), "a")

    def test_a_habit_is_learnt_and_then_unlearnt_faster_with_decay(self) -> None:
        def flips_after(decay: float) -> int:
            predictor = NGramPredictor(2, ["a", "b", "c"], decay)
            for _ in range(10):
                for action in ("a", "b"):
                    predictor.observe(action)
            for count in range(1, 40):
                predictor.observe("c")
                predictor.observe("a")
                if predictor.likeliest() == "c":
                    return count
            return 40

        self.assertLess(flips_after(0.7), flips_after(1.0))


if __name__ == "__main__":
    unittest.main()
