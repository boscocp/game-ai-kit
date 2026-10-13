"""The split, the report's rules, and the three properties T5 asks for.

The rules in `report.py` and `evaluate.py` are handed fabricated input here
rather than the real pipeline. A rule that can only be exercised by training
for seven seconds is a rule nobody plants a case against, and the wave before
this one found nine of exactly those in a conformance runner.
"""

import argparse
import copy
import dataclasses
import unittest

from gameaikit.dataset.rows import CAPTURE_FEATURES, COMBAT_FEATURES
from gameaikit.dataset import board, simulate
from gameaikit.dataset.simulate import collect
from gameaikit.training import evaluate, report
from gameaikit.training.models import Model
from gameaikit.training.split import split_by_game
from gameaikit.training import train
from gameaikit.training.train import Fitted, Training, run


def sound_report() -> dict:
    """A report with nothing wrong with it, for the rules to pass."""
    return {
        "feature_conventions": dict(report.FEATURE_CONVENTIONS),
        "models": {
            "combat": {
                "features": list(COMBAT_FEATURES),
                "weights": [1.0, 2.0, -3.0, -0.5],
                "comparable_weights": [2.0, 1.4, -1.3, -0.6],
                "bias": 0.5,
            },
            "capture": {
                "features": list(CAPTURE_FEATURES),
                "weights": [1.0, 0.1, 0.1, 0.4],
                "comparable_weights": [1.1, 0.2, 0.1, 0.1],
                "bias": 1.0,
            },
        },
    }


def fitted(score: float, baseline: float, kind: str = "logistic") -> Fitted:
    """A fitted model that scored whatever the test needs it to have scored.

    The two game sets are disjoint here, so a test about something else is not
    quietly also testing E4. They carry no default on `Fitted` on purpose --
    an empty pair made E4 pass without looking at anything.
    """
    features = COMBAT_FEATURES if kind == "logistic" else CAPTURE_FEATURES
    model = Model(kind=kind, features=features, weights=(1.0, 1.0, 1.0, 1.0),
                  bias=0.0, comparable_weights=(1.0, 1.0, 1.0, 1.0), rows_trained_on=10)
    return Fitted(model=model, score=score, baseline=baseline, memoriser=baseline,
                  twinned_share=0.0, distinct_rows=10, holdout_rows=10,
                  training_games=frozenset({1, 2}), holdout_games=frozenset({3}))


def training(combat_score: float, combat_baseline: float,
             capture_score: float = -0.5, capture_baseline: float = -1.0) -> Training:
    return Training(combat=fitted(combat_score, combat_baseline),
                    capture=fitted(capture_score, capture_baseline, kind="linear"),
                    games=10)


class SplittingByGame(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.combats, _ = collect(80, 99)

    def test_no_game_appears_on_both_sides(self) -> None:
        train, held = split_by_game(self.combats, 5)

        self.assertEqual({row.game for row in train} & {row.game for row in held}, set())

    def test_both_sides_get_rows(self) -> None:
        train, held = split_by_game(self.combats, 5)

        self.assertGreater(len(train), 0)
        self.assertGreater(len(held), 0)
        self.assertEqual(len(train) + len(held), len(self.combats))

    def test_the_same_seed_holds_back_the_same_games(self) -> None:
        self.assertEqual(split_by_game(self.combats, 5), split_by_game(self.combats, 5))

    def test_a_different_seed_holds_back_different_games(self) -> None:
        _train, held = split_by_game(self.combats, 5)
        _other_train, other_held = split_by_game(self.combats, 6)

        self.assertNotEqual({row.game for row in held},
                            {row.game for row in other_held})

    def test_splitting_nothing_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            split_by_game([], 5)

    def test_a_tiny_set_still_holds_something_back(self) -> None:
        # A quarter of three games rounds to zero, and a holdout of nothing
        # scores a model on nothing while reporting a number.
        few = [row for row in self.combats if row.game < 3]
        _train, held = split_by_game(few, 5)

        self.assertGreater(len(held), 0)


class TheReportsRules(unittest.TestCase):
    def test_a_sound_report_has_nothing_said_about_it(self) -> None:
        self.assertEqual(report.findings_for(sound_report(), sound_report()), [])

    def test_two_runs_that_disagree_are_reported(self) -> None:
        drifted = copy.deepcopy(sound_report())
        drifted["models"]["combat"]["bias"] = 0.6

        self.assertIn("W1", report.findings_for(sound_report(), drifted)[0])

    def test_a_renamed_feature_is_reported(self) -> None:
        # The game reads these weights positionally in T6. A rename that nobody
        # notices is every weight applied to the wrong number.
        renamed = copy.deepcopy(sound_report())
        renamed["models"]["combat"]["features"][0] = "hp_diff"

        self.assertIn("W2", report.findings_for(renamed, renamed)[0])

    def test_a_weight_missing_from_a_feature_is_reported(self) -> None:
        short = copy.deepcopy(sound_report())
        short["models"]["capture"]["weights"] = [1.0]

        self.assertIn("W3", report.findings_for(short, short)[0])

    def test_a_weight_that_is_not_a_number_is_reported(self) -> None:
        # A fit that diverges publishes nan, and json.dump writes `NaN`
        # happily -- which every reader downstream then parses into a model
        # that predicts nan for everything.
        broken = copy.deepcopy(sound_report())
        broken["models"]["combat"]["bias"] = float("nan")

        self.assertIn("W4", report.findings_for(broken, broken)[0])

    def test_a_weight_that_is_an_infinity_is_reported(self) -> None:
        # The half of W4 that nothing tested, which is how it came to be
        # dropped during a rewrite of the other half. A diverged fit publishes
        # inf, and json.dump writes `Infinity` for the game to load.
        diverged = copy.deepcopy(sound_report())
        diverged["models"]["combat"]["weights"][2] = float("inf")

        self.assertIn("W4", report.findings_for(diverged, diverged)[0])

    def test_an_infinite_bias_is_reported_too(self) -> None:
        # The bias is published separately from the weights, and the check on
        # it was the one that lost its infinity branch.
        diverged = copy.deepcopy(sound_report())
        diverged["models"]["capture"]["bias"] = float("-inf")

        self.assertIn("W4", report.findings_for(diverged, diverged)[0])

    def test_a_report_with_no_feature_conventions_is_caught(self) -> None:
        # The block the game reads to build a row. Published since T6: without
        # it the GDScript side falls back on numbers of its own, which is the
        # arrangement the block exists to end.
        bare = sound_report()
        del bare["feature_conventions"]
        self.assertIn("W6", report.findings_for(bare, bare)[0])

    def test_a_convention_that_is_not_a_number_is_caught(self) -> None:
        wrong = sound_report()
        wrong["feature_conventions"]["nearby_radius"] = "two"
        self.assertIn("W6", report.findings_for(wrong, wrong)[0])

    def test_a_convention_of_zero_is_caught(self) -> None:
        # Zero is the value a missing key reads as once somebody writes
        # `conventions.get(name, 0)` on the other side, and it is a radius
        # that counts nobody.
        zeroed = sound_report()
        zeroed["feature_conventions"]["nearby_radius"] = 0
        self.assertIn("W6", report.findings_for(zeroed, zeroed)[0])

    def test_the_published_conventions_are_the_simulator_s_own(self) -> None:
        # Not a restatement of the constant: it asserts that what the report
        # publishes is what `simulate.py` actually used, so renaming or
        # retuning either number there cannot leave the game reading a stale
        # copy of it.
        published = report.as_json(training(0.9, 0.7))["feature_conventions"]
        self.assertEqual(published["nearby_radius"], simulate.NEARBY)
        self.assertEqual(
            published["reinforcement_distance_when_alone"], simulate.WIDTH)
        # All four, not two: hard-coding either terrain bound as a literal in
        # report.py left this green, which is the drift it exists to catch.
        self.assertEqual(published["cheapest_ground"], board.CHEAPEST_GROUND)
        self.assertEqual(published["dearest_ground"], board.DEAREST_GROUND)

    def test_a_model_that_learned_nothing_is_reported(self) -> None:
        flat = copy.deepcopy(sound_report())
        flat["models"]["capture"]["weights"] = [0.0, 0.0, 0.0, 0.0]

        self.assertIn("W5", report.findings_for(flat, flat)[0])


class TheBaselineProperties(unittest.TestCase):
    def test_a_model_no_better_than_the_baseline_is_not_worth_shipping(self) -> None:
        self.assertTrue(evaluate.check_beats_baseline(training(0.70, 0.69)))

    def test_a_model_well_clear_of_the_baseline_passes(self) -> None:
        self.assertEqual(evaluate.check_beats_baseline(training(0.88, 0.69)), [])

    def test_a_shuffled_fit_that_still_beats_the_baseline_is_a_leak(self) -> None:
        # The control failing is the only evidence that the honest number was
        # about the game rather than about a feature carrying the answer.
        findings = evaluate.check_no_better_than_baseline(training(0.88, 0.69))

        self.assertTrue(findings)
        self.assertIn("never saw", findings[0])

    def test_a_shuffled_fit_that_collapses_to_the_baseline_passes(self) -> None:
        self.assertEqual(
            evaluate.check_no_better_than_baseline(training(0.69, 0.69, -1.01, -1.0)),
            [],
        )


class TheLeaksTheControlCannotSee(unittest.TestCase):
    """Both of these were planted in the real pipeline and measured: the
    shuffled-label control passed each one while the model was plainly
    broken."""

    def test_a_holdout_that_is_also_in_the_training_set_is_caught(self) -> None:
        overlapping = dataclasses.replace(
            fitted(0.88, 0.69), training_games=frozenset({1, 2, 3}),
            holdout_games=frozenset({3, 4}),
        )
        findings = evaluate.check_no_leak(Training(
            combat=overlapping, capture=fitted(-0.5, -1.0, kind="linear"), games=10))

        self.assertTrue(findings)
        self.assertIn("not held out", findings[0])

    def test_a_suspiciously_perfect_score_is_caught(self) -> None:
        # Nothing predicts a fight decided by dice this well. The planted
        # version -- the label appended to every feature row -- scores exactly
        # this.
        findings = evaluate.check_no_leak(training(1.0, 0.69))

        self.assertTrue(findings)
        self.assertIn("told the answer", findings[0])

    def test_an_honest_pipeline_has_neither(self) -> None:
        self.assertEqual(evaluate.check_no_leak(training(0.88, 0.69)), [])

    def test_a_capture_model_that_is_never_wrong_is_caught_too(self) -> None:
        # This half was missing: the check was gated on the model being
        # logistic, so planting `turns_taken` into the capture features gave a
        # perfect model and `--assert-no-leak` said nothing at all.
        findings = evaluate.check_no_leak(training(0.88, 0.69, capture_score=-0.0))

        self.assertTrue(findings)
        self.assertIn("this exact", findings[0])

    def test_the_control_passes_a_model_that_was_told_the_answer(self) -> None:
        # Recorded rather than fixed, because it is a property of the control
        # and not a defect in it: a shuffled fit collapses to the baseline
        # whatever was wrong with the features, so it cannot see this.
        told = training(0.69, 0.69, capture_score=-1.0, capture_baseline=-1.0)

        self.assertEqual(evaluate.check_no_better_than_baseline(told), [])


class TheScoringItself(unittest.TestCase):
    """Four rules that `make test-models` catches and the unit suite did not.

    A gate catching them is not nothing, but it takes twenty seconds and says
    "the model got worse"; these say which line was wrong.
    """

    def model_on(self, weight: float, bias: float, kind: str = "logistic") -> Model:
        return Model(kind=kind, features=("only",), weights=(weight,), bias=bias,
                     comparable_weights=(weight,), rows_trained_on=1)

    def test_accuracy_counts_a_probability_over_a_half_as_a_yes(self) -> None:
        # The threshold, which a mutation can drop entirely: comparing the
        # probability with the label directly scores nearly everything wrong.
        # One function holds it now -- there were two, which is two copies of
        # a number that has to agree.
        model = self.model_on(weight=1.0, bias=0.0)
        predictions = train._predictions_of(model, [[4.0], [-4.0], [4.0], [-4.0]])

        self.assertEqual(train._share_right(predictions, [1.0, 0.0, 1.0, 0.0]), 1.0)
        self.assertEqual(train._share_right(predictions, [0.0, 1.0, 0.0, 1.0]), 0.0)

    def test_the_model_is_scored_through_the_same_path_as_the_lookup_table(self) -> None:
        # Both go through `_predictions_of` then `_share_right`, so the model
        # and the yardstick it is compared with cannot be scored differently.
        model = self.model_on(weight=1.0, bias=0.0)

        self.assertEqual(train._predictions_of(model, [[0.0]]), [0.5])

    def test_the_majority_share_is_the_commoner_answer_not_the_positive_one(self) -> None:
        # Without the max(), a set that is 80% negative reports a baseline of
        # 0.2 and every model looks miraculous.
        self.assertEqual(train._majority_share([0.0] * 8 + [1.0] * 2), 0.8)
        self.assertEqual(train._majority_share([1.0] * 8 + [0.0] * 2), 0.8)

    def test_mean_absolute_error_is_the_distance_not_the_difference(self) -> None:
        model = self.model_on(weight=1.0, bias=0.0, kind="linear")
        predictions = train._predictions_of(model, [[3.0], [5.0]])

        # Errors of -2 and +2 average to zero if the absolute is dropped.
        self.assertEqual(train._mean_absolute_difference(predictions, [5.0, 3.0]), 2.0)

    def test_the_capture_model_is_scored_so_that_bigger_is_better(self) -> None:
        # Both halves are negated mean errors. Dropping the minus signs makes
        # a worse model score higher, in a comparison that reads fine.
        result = train.run(games=40)

        self.assertLess(result.capture.score, 0.0)
        self.assertLess(result.capture.baseline, 0.0)
        self.assertGreater(result.capture.beats_baseline_by(), 0.0)

    def test_fitting_works_when_one_feature_is_a_thousand_times_the_other(self) -> None:
        # What the standardisation buys. At this rate an unstandardised fit
        # does not converge on these numbers, and deleting it left every unit
        # test green because every other fixture here is already on one scale.
        rows = [[float(a), 1000.0 * b] for a in range(-4, 5) for b in range(-4, 5)]
        labels = [2.0 * row[0] + 0.003 * row[1] + 1.0 for row in rows]

        model = train._fit(rows, labels, "linear", ("small", "large"))

        self.assertAlmostEqual(model.weights[0], 2.0, places=2)
        self.assertAlmostEqual(model.weights[1], 0.003, places=5)


    def test_the_twinned_share_is_measured_on_the_run_that_reports_it(self) -> None:
        # It was a constant in the report's prose, so a sixty-game run printed
        # the thousand-game figure. Sixty games produce no exact twins at all.
        few = train.run(games=60)

        self.assertEqual(few.combat.twinned_share, 0.0)
        self.assertGreater(few.combat.distinct_rows, 0)

    def test_twins_appear_as_the_feature_space_fills_up(self) -> None:
        # The share is saturation, not a defect: four small integers have only
        # so many combinations, and more games keep landing on the same ones.
        self.assertGreater(train.run(games=400).combat.twinned_share, 0.3)


class TheClockAssertion(unittest.TestCase):
    """E3 had no planted case at all: `if False:` there left the unit suite and
    all five acceptance commands green."""

    def arguments(self, seconds: float | None) -> argparse.Namespace:
        return argparse.Namespace(
            shuffled_labels=False, assert_beats_majority_baseline=False,
            assert_no_better_than_baseline=False, assert_no_leak=False,
            assert_runs_under_seconds=seconds,
        )

    def test_a_pipeline_over_its_budget_is_reported(self) -> None:
        findings = evaluate._assertions(self.arguments(5.0), training(0.88, 0.69), 9.0)

        self.assertTrue(findings)
        self.assertIn("E3", findings[0])

    def test_a_pipeline_inside_its_budget_is_not(self) -> None:
        self.assertEqual(
            evaluate._assertions(self.arguments(30.0), training(0.88, 0.69), 3.6), [])

    def test_no_budget_asked_for_is_no_assertion_made(self) -> None:
        self.assertEqual(
            evaluate._assertions(self.arguments(None), training(0.88, 0.69), 900.0), [])


class TheWholePipelineOnFewGames(unittest.TestCase):
    """End to end, but small. The real run is seven seconds and belongs in the
    acceptance commands, not in a suite somebody runs on every save."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.result = run(games=60)

    def test_both_models_come_back_with_the_features_the_dataset_declares(self) -> None:
        self.assertEqual(self.result.combat.model.features, COMBAT_FEATURES)
        self.assertEqual(self.result.capture.model.features, CAPTURE_FEATURES)

    def test_the_weights_apply_to_raw_game_numbers(self) -> None:
        # A fight the attacker should obviously win, against one it should
        # obviously lose, through the published weights rather than through
        # anything the trainer kept to itself.
        winning = self.result.combat.model.predict([10.0, 2.0, 1.0, 1.0])
        losing = self.result.combat.model.predict([-10.0, -2.0, 3.0, 9.0])

        self.assertGreater(winning, 0.5)
        self.assertLess(losing, 0.5)

    def test_the_strongest_feature_is_listed_first(self) -> None:
        ordered = self.result.combat.model.by_importance()
        sizes = [abs(comparable) for _name, _raw, comparable in ordered]

        self.assertEqual(sizes, sorted(sizes, reverse=True))

    def test_the_dump_prints_every_feature_and_both_baselines(self) -> None:
        text = report.dump(self.result)

        for name in COMBAT_FEATURES + CAPTURE_FEATURES:
            self.assertIn(name, text)
        self.assertIn("the attacker loses", text)
        self.assertIn("training mean", text)

    def test_the_json_carries_the_seeds_that_produced_it(self) -> None:
        # Without them the artifact cannot be reproduced, and a weights file
        # nobody can regenerate is one nobody can review.
        published = report.as_json(self.result)

        self.assertIn("data_seed", published)
        self.assertIn("split_seed", published)
        self.assertEqual(published["games"], 60)


if __name__ == "__main__":
    unittest.main()
