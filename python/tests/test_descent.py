"""Gradient descent, against answers that are known in advance.

A fitting routine is the easiest thing in a project like this to be quietly
wrong about: it produces numbers whatever it does, and the numbers look like
weights. So it is fitted here to data whose answer was written down first.
"""

import unittest

from gameaikit.training import descent


def known_line() -> tuple[list[list[float]], list[float]]:
    """A grid of points on `y = 2a + 3b + 1`, with no noise anywhere."""
    rows = [[float(a), float(b)] for a in range(-5, 6) for b in range(-5, 6)]
    return rows, [2 * row[0] + 3 * row[1] + 1 for row in rows]


class FittingSomethingWithAKnownAnswer(unittest.TestCase):
    def test_it_recovers_the_line_it_was_given(self) -> None:
        rows, labels = known_line()
        means, deviations = descent.standardise(rows)
        scaled = descent.apply_standardisation(rows, means, deviations)

        weights, bias = descent.fit(scaled, labels, descent.linear_prediction)
        raw, raw_bias = descent.unstandardise(weights, bias, means, deviations)

        self.assertAlmostEqual(raw[0], 2.0, places=3)
        self.assertAlmostEqual(raw[1], 3.0, places=3)
        self.assertAlmostEqual(raw_bias, 1.0, places=3)

    def test_two_runs_give_bit_for_bit_the_same_weights(self) -> None:
        # What `report.py --check` rests on, and what makes a committed
        # weights.json reviewable.
        rows, labels = known_line()
        self.assertEqual(
            descent.fit(rows, labels, descent.linear_prediction, steps=50),
            descent.fit(rows, labels, descent.linear_prediction, steps=50),
        )

    def test_logistic_descent_separates_what_is_separable(self) -> None:
        rows = [[float(value)] for value in range(-20, 21)]
        labels = [1.0 if row[0] > 0 else 0.0 for row in rows]

        weights, bias = descent.fit(rows, labels, descent.logistic_prediction)

        self.assertGreater(weights[0], 0.0)
        self.assertGreater(descent.logistic_prediction(weights, bias, [10.0]), 0.5)
        self.assertLess(descent.logistic_prediction(weights, bias, [-10.0]), 0.5)

    def test_fitting_nothing_is_refused_rather_than_returning_zeros(self) -> None:
        # A weight vector of zeros is a model that always answers the same
        # thing, and it would pass every shape check downstream.
        with self.assertRaises(ValueError):
            descent.fit([], [], descent.linear_prediction)


class TheKnobs(unittest.TestCase):
    def test_the_step_count_is_read_when_fit_runs_not_when_it_was_imported(self) -> None:
        # `steps: int = STEPS` in the signature captures the constant at import
        # time, so changing `descent.STEPS` changed nothing -- which produced a
        # convergence measurement that was five runs of the same step count.
        original = descent.STEPS
        try:
            descent.STEPS = 1
            one_step, _bias = descent.fit([[1.0], [2.0]], [1.0, 2.0],
                                          descent.linear_prediction)
            descent.STEPS = 200
            many_steps, _bias = descent.fit([[1.0], [2.0]], [1.0, 2.0],
                                            descent.linear_prediction)
        finally:
            descent.STEPS = original

        self.assertNotEqual(one_step, many_steps)


class TheSigmoid(unittest.TestCase):
    def test_it_does_not_overflow_on_a_number_a_real_fit_produces(self) -> None:
        # `1 / (1 + exp(-value))` raises OverflowError somewhere around -746.
        self.assertAlmostEqual(descent.sigmoid(-1000.0), 0.0, places=12)
        self.assertAlmostEqual(descent.sigmoid(1000.0), 1.0, places=12)

    def test_it_is_a_half_at_zero_and_symmetric_either_side(self) -> None:
        self.assertAlmostEqual(descent.sigmoid(0.0), 0.5)
        self.assertAlmostEqual(descent.sigmoid(2.0) + descent.sigmoid(-2.0), 1.0)


class Standardising(unittest.TestCase):
    def test_a_column_that_never_varies_does_not_divide_by_zero(self) -> None:
        means, deviations = descent.standardise([[1.0, 5.0], [2.0, 5.0], [3.0, 5.0]])

        self.assertEqual(deviations[1], 1.0)
        self.assertEqual(means[1], 5.0)

    def test_folding_the_scaling_back_in_predicts_the_same_number(self) -> None:
        # The substitution in `unstandardise` is the one place a sign or a
        # division could be wrong and everything downstream would still look
        # like a model.
        rows = [[3.0, 100.0], [5.0, 140.0], [9.0, 90.0], [1.0, 200.0]]
        means, deviations = descent.standardise(rows)
        scaled = descent.apply_standardisation(rows, means, deviations)
        weights = [0.7, -0.3]
        bias = 0.2
        raw, raw_bias = descent.unstandardise(weights, bias, means, deviations)

        for row, scaled_row in zip(rows, scaled):
            self.assertAlmostEqual(
                descent.linear_prediction(weights, bias, scaled_row),
                descent.linear_prediction(raw, raw_bias, row),
                places=9,
            )


if __name__ == "__main__":
    unittest.main()
