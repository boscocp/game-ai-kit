"""Membership, inference and the centroid, each held to what its header claims.

The numbers that two languages must agree on are in the conformance vectors;
these are the claims that are about one side only -- the refusals, and the
shape of the curve.
"""

import contextlib
import io
import math
import pathlib
import unittest

from gameaikit.fuzzy import FuzzyError, FuzzySet, Rule, RuleBase, Variable, read_fcl
from gameaikit.fuzzy.defuzzify import centroid, sample_points
from gameaikit.fuzzy.plot import draw, main, sweep

GUARD = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "fuzzy" / "the-guard.fcl"


def a_set(name: str, *points: float) -> FuzzySet:
    """A set from its points, as a test would write it."""
    return FuzzySet.from_points(name, list(points))


def small_controller(rules: tuple[Rule, ...] | None = None) -> RuleBase:
    """Two terms in, two terms out, the two rules joining them."""
    noise = Variable("noise", 0, 10, (a_set("quiet", 0, 0, 2, 6), a_set("loud", 4, 8, 10, 10)))
    alertness = Variable("alertness", 0, 100,
                         (a_set("calm", 0, 0, 20, 50), a_set("alarmed", 50, 80, 100, 100)), 11)
    default = (Rule((("noise", "quiet"),), ("alertness", "calm")),
               Rule((("noise", "loud"),), ("alertness", "alarmed")))
    return RuleBase((noise,), (alertness,), default if rules is None else rules)


class MembershipTests(unittest.TestCase):
    def test_three_points_are_a_triangle(self) -> None:
        self.assertEqual(a_set("peak", 1, 2, 3), FuzzySet("peak", 1, 2, 2, 3))

    def test_a_vertical_edge_answers_one_at_its_corner(self) -> None:
        shoulder = a_set("edge", 0, 0, 1, 2)
        self.assertEqual(shoulder.degree(0), 1.0)
        self.assertEqual(shoulder.degree(-0.001), 0.0)

    def test_a_vertical_falling_edge_answers_one_at_its_corner(self) -> None:
        self.assertEqual(a_set("wall", 0, 1, 2, 2).degree(2), 1.0)

    def test_points_out_of_order_are_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F1"):
            a_set("backwards", 0, 4, 3, 5)

    def test_the_wrong_number_of_points_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F1 .* three or four points"):
            a_set("two", 0, 1)

    def test_a_point_that_is_not_a_number_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F1 .* not a number"):
            a_set("hole", 0, math.nan, 2)

    def test_an_infinite_point_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F1 .* not a number"):
            a_set("forever", 0, 1, math.inf)

    def test_an_input_is_clamped_before_it_is_fuzzified(self) -> None:
        noise = small_controller().inputs[0]
        self.assertEqual(noise.fuzzify(-5), noise.fuzzify(0))
        self.assertEqual(noise.fuzzify(50), {"quiet": 0.0, "loud": 1.0})

    def test_a_value_that_is_not_a_finite_number_is_refused(self) -> None:
        # NaN survives the clamp and divides by zero on a shoulder; a string
        # is not a distance however it is spelled.
        for value in (math.nan, math.inf, "5", None, True):
            with self.subTest(value=value), self.assertRaisesRegex(FuzzyError, "F8"):
                small_controller().evaluate({"noise": value})


class VariableTests(unittest.TestCase):
    def test_an_empty_range_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F2"):
            Variable("flat", 3, 3, (a_set("one", 3, 3, 3),)).check(is_output=False)

    def test_an_infinite_range_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F2 .* not finite"):
            Variable("endless", 0, math.inf, (a_set("one", 0, 1, 1),)).check(is_output=False)

    def test_a_variable_reports_a_broken_set_it_holds(self) -> None:
        # Built directly, past `from_points`, so only the variable can see it.
        backwards = FuzzySet("backwards", 0, 4, 3, 5)
        with self.assertRaisesRegex(FuzzyError, "F1"):
            Variable("holder", 0, 5, (backwards,)).check(is_output=False)

    def test_a_variable_with_no_sets_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F2"):
            Variable("bare", 0, 1, ()).check(is_output=False)

    def test_a_set_named_twice_is_refused(self) -> None:
        twice = (a_set("same", 0, 1, 2), a_set("same", 1, 2, 3))
        with self.assertRaisesRegex(FuzzyError, "F2"):
            Variable("doubled", 0, 3, twice).check(is_output=False)

    def test_an_output_with_one_sample_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F3"):
            Variable("blind", 0, 1, (a_set("one", 0, 1, 1),), 1).check(is_output=True)

    def test_a_fractional_number_of_samples_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F3"):
            Variable("blurred", 0, 1, (a_set("one", 0, 1, 1),), 2.5).check(is_output=True)

    def test_an_output_set_no_sample_reaches_is_refused(self) -> None:
        # Concluded at full strength, it would add nothing to the pile, and
        # the answer would be NaN -- which everywhere else means no rule fired.
        controller = small_controller()
        for points in ((150, 180, 200, 200), (81, 85, 89)):
            narrow = Variable("alertness", 0, 100,
                              (controller.outputs[0].sets[0], a_set("alarmed", *points)), 11)
            with self.subTest(points=points), self.assertRaisesRegex(FuzzyError, "F3 .* no sample"):
                RuleBase(controller.inputs, (narrow,), controller.rules)

    def test_an_input_needs_no_samples(self) -> None:
        Variable("input", 0, 1, (a_set("one", 0, 1, 1),)).check(is_output=False)


class RuleBaseTests(unittest.TestCase):
    def test_and_is_the_smaller_and_or_the_larger(self) -> None:
        degrees = {"one": {"yes": 0.25}, "two": {"yes": 0.75}}
        conditions = (("one", "yes"), ("two", "yes"))
        self.assertEqual(Rule(conditions, ("out", "x"), "and").strength(degrees), 0.25)
        self.assertEqual(Rule(conditions, ("out", "x"), "or").strength(degrees), 0.75)

    def test_a_term_concluded_twice_takes_the_stronger_rule(self) -> None:
        rules = (Rule((("noise", "quiet"),), ("alertness", "calm")),
                 Rule((("noise", "loud"),), ("alertness", "calm")))
        strengths = small_controller(rules).activations({"noise": 4.5})
        self.assertEqual(strengths["alertness"], {"calm": 0.375, "alarmed": 0.0})

    def test_two_variables_sharing_a_name_are_refused(self) -> None:
        controller = small_controller()
        clash = Variable("noise", 0, 100, controller.outputs[0].sets, 11)
        with self.assertRaisesRegex(FuzzyError, "F4"):
            RuleBase(controller.inputs, (clash,), controller.rules)

    def test_a_controller_with_no_rules_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F5"):
            small_controller(())

    def test_an_unknown_connective_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F6"):
            small_controller((Rule((("noise", "quiet"),), ("alertness", "calm"), "xor"),))

    def test_a_rule_with_no_conditions_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F6"):
            small_controller((Rule((), ("alertness", "calm")),))

    def test_a_condition_on_no_input_s_set_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F7"):
            small_controller((Rule((("noise", "deafening"),), ("alertness", "calm")),))

    def test_a_condition_on_an_output_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F7"):
            small_controller((Rule((("alertness", "calm"),), ("alertness", "calm")),))

    def test_a_conclusion_on_no_output_s_set_is_refused(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F7"):
            small_controller((Rule((("noise", "quiet"),), ("noise", "loud")),))

    def test_a_missing_input_is_refused_rather_than_zeroed(self) -> None:
        with self.assertRaisesRegex(FuzzyError, "F8"):
            small_controller().evaluate({})


class CentroidTests(unittest.TestCase):
    def test_the_samples_include_both_ends(self) -> None:
        output = small_controller().outputs[0]
        self.assertEqual(sample_points(output), [float(step * 10) for step in range(11)])

    def test_nothing_fired_is_nan_rather_than_a_number(self) -> None:
        output = small_controller().outputs[0]
        self.assertTrue(math.isnan(centroid(output, {"calm": 0.0, "alarmed": 0.0})))

    def test_a_weak_rule_cannot_outvote_a_strong_one(self) -> None:
        output = small_controller().outputs[0]
        self.assertLess(centroid(output, {"calm": 0.9, "alarmed": 0.1}), 50.0)


class SlopeTests(unittest.TestCase):
    """The half of T13's manual check a command can hold: no steps."""

    #: The guard's output moves at most this much between neighbouring
    #: samples a twentieth of a cell apart. Measured at 0.93 at most across
    #: all three sweeps. A defuzzifier that keeps only the strongest rule's
    #: term was planted and jumps by tens where two rules cross -- it fails
    #: the bright sweep here, and five vector cases besides.
    LARGEST_STEP = 3.0

    def test_the_guard_slopes_rather_than_steps(self) -> None:
        guard = read_fcl(GUARD.read_text(encoding="utf-8"))
        for light in (0.1, 0.35, 0.9):
            with self.subTest(light=light):
                answers = [outputs["alertness"] for _, outputs in
                           sweep(guard, "distance", {"light": light}, rows=401)]
                steps = [abs(after - before) for before, after in zip(answers, answers[1:])]
                self.assertLess(max(steps), self.LARGEST_STEP)

    def test_the_plot_exits_zero_and_refuses_with_two(self) -> None:
        missing = str(GUARD.with_name("no-such-file.fcl"))
        cases = {
            0: [str(GUARD), "distance", "light=0.9"],
            2: [missing, "distance", "light=0.9"],
        }
        refused = (["distance", "light=nan"], ["distance"], ["volume", "light=0.9"],
                   ["distance", "light=0.9", "bogus=1"], ["distance", "light=0.9", "distance=3"])
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(main(cases[0]), 0)
            self.assertEqual(main(cases[2]), 2)
            for arguments in refused:
                with self.subTest(arguments=arguments):
                    self.assertEqual(main([str(GUARD), *arguments]), 2)

    def test_the_plot_names_what_it_swept(self) -> None:
        guard = read_fcl(GUARD.read_text(encoding="utf-8"))
        self.assertIn("alertness against distance", draw(guard, "distance", {"light": 0.9}))


if __name__ == "__main__":
    unittest.main()
