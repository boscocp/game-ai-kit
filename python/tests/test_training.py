"""The split, the report's rules, and the three properties T5 asks for.

The rules in `report.py` and `evaluate.py` are handed fabricated input here
rather than the real pipeline. A rule that can only be exercised by training
for seven seconds is a rule nobody plants a case against, and the wave before
this one found nine of exactly those in a conformance runner.
"""

import copy
import dataclasses
import unittest

from gameaikit.dataset.rows import CAPTURE_FEATURES, COMBAT_FEATURES
from gameaikit.dataset.simulate import collect
from gameaikit.training import evaluate, report
from gameaikit.training.models import Model
from gameaikit.training.split import split_by_game
from gameaikit.training.train import Fitted, Training, run


def sound_report() -> dict:
    """A report with nothing wrong with it, for the rules to pass."""
    return {
        "models": {
            "combat": {
                "features": list(COMBAT_FEATURES),
                "weights": [1.0, 2.0, -3.0, -0.5],
                "bias": 0.5,
            },
            "capture": {
                "features": list(CAPTURE_FEATURES),
                "weights": [1.0, 0.1, 0.1, 0.4],
                "bias": 1.0,
            },
        },
    }


def fitted(score: float, baseline: float) -> Fitted:
    """A fitted model that scored whatever the test needs it to have scored."""
    model = Model(kind="logistic", features=COMBAT_FEATURES, weights=(1.0, 1.0, 1.0, 1.0),
                  bias=0.0, comparable_weights=(1.0, 1.0, 1.0, 1.0), rows_trained_on=10)
    return Fitted(model=model, score=score, baseline=baseline,
                  memoriser=baseline, holdout_rows=10)


def training(combat_score: float, combat_baseline: float,
             capture_score: float = -0.5, capture_baseline: float = -1.0) -> Training:
    return Training(combat=fitted(combat_score, combat_baseline),
                    capture=fitted(capture_score, capture_baseline), games=10)


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

    def test_a_model_that_learned_nothing_is_reported(self) -> None:
        flat = copy.deepcopy(sound_report())
        flat["models"]["capture"]["weights"] = [0.0, 0.0, 0.0, 0.0]

        self.assertIn("W5", report.findings_for(flat, flat)[0])


class TheThreeProperties(unittest.TestCase):
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
        findings = evaluate.check_no_leak(
            Training(combat=overlapping, capture=fitted(-0.5, -1.0), games=10))

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
        honest = dataclasses.replace(
            fitted(0.88, 0.69), training_games=frozenset({1, 2}),
            holdout_games=frozenset({3}),
        )
        self.assertEqual(
            evaluate.check_no_leak(
                Training(combat=honest, capture=fitted(-0.5, -1.0), games=10)),
            [],
        )

    def test_the_control_passes_a_model_that_was_told_the_answer(self) -> None:
        # Recorded rather than fixed, because it is a property of the control
        # and not a defect in it: a shuffled fit collapses to the baseline
        # whatever was wrong with the features, so it cannot see this.
        told = training(0.69, 0.69, capture_score=-1.0, capture_baseline=-1.0)

        self.assertEqual(evaluate.check_no_better_than_baseline(told), [])


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
