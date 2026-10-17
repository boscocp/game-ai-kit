"""Behaviour cloning's rules, one test each: the split, the fit, the report's refusals."""

import contextlib
import io
import json
import pathlib
import tempfile
import unittest

from gameaikit.cloning import compare, measure, softmax
from gameaikit.cloning.rows import Session

ACTIONS = ["high", "low", "throw"]


def session(name: str, rows: list[tuple[dict, str]]) -> Session:
    """A recording of `rows`, by player "someone", an action every 100 frames."""
    return Session(name, "someone", ["lancer", "dancer"], rows, [100 * (index + 1) for index in range(len(rows))])


class TestSplit(unittest.TestCase):
    def test_whole_recordings_are_held_out_every_fourth_counting_from_the_last(self) -> None:
        sessions = [session(f"r{index}", []) for index in range(8)]
        training, held = measure.split(sessions)
        self.assertEqual([s.recording for s in held], ["r3", "r7"])
        self.assertEqual(len(training), 6)

    def test_one_recording_cannot_be_split(self) -> None:
        training, held = measure.split([session("only", [])])
        self.assertEqual((len(training), held), (1, []))


class TestSoftmaxFit(unittest.TestCase):
    def test_a_word_that_decides_the_action_is_learnt(self) -> None:
        rows = [({"distance": "close"}, "throw"), ({"distance": "far"}, "high")] * 20
        model = softmax.fit(rows, ["distance"], ACTIONS)
        self.assertEqual(model.likeliest({"distance": "close"}), "throw")
        self.assertEqual(model.likeliest({"distance": "far"}), "high")

    def test_the_penalty_keeps_a_word_seen_once_from_running_away(self) -> None:
        model = softmax.fit([({"distance": "close"}, "throw")], ["distance"], ACTIONS)
        self.assertLess(max(abs(weight) for row in model.weights for weight in row), 10.0)

    def test_the_fit_is_deterministic(self) -> None:
        rows = [({"distance": "close", "last": "high"}, "low"), ({"distance": "far", "last": "low"}, "high")] * 5
        first = softmax.fit(rows, ["distance", "last"], ACTIONS)
        second = softmax.fit(rows, ["distance", "last"], ACTIONS)
        self.assertEqual((first.weights, first.bias), (second.weights, second.bias))


class TestNGramScore(unittest.TestCase):
    def test_the_ngram_starts_empty_in_every_held_out_fight(self) -> None:
        habit = [({}, "high"), ({}, "low")] * 10
        one = measure.ngram_score([session("a", habit)], ACTIONS, 15)
        two = measure.ngram_score([session("a", habit), session("b", habit)], ACTIONS, 15)
        self.assertEqual(two.right, 2 * one.right)

    def test_the_ngram_sees_an_action_only_reaction_frames_after_it_began(self) -> None:
        def right_with(frames: list[int]) -> int:
            habit = Session("habit", "someone", [], [({}, "high")] * 3, frames)
            return measure.ngram_score([habit], ["low", "high"], 15).right
        # Spread out, the third high is guessed from "high after high",
        # counted from the first two. Ten frames apart, the second has not
        # been seen when the third is guessed: the table is empty, and the
        # tie goes to the first action, low.
        self.assertEqual(right_with([100, 200, 300]), 1)
        self.assertEqual(right_with([100, 110, 120]), 0)


class TestReportRefuses(unittest.TestCase):
    def test_no_win_rates_is_named_and_another_files_are_stale(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            published = pathlib.Path(folder) / "clone_weights.json"
            published.write_text("{}")
            wins, wrong = compare.win_rates(published, pathlib.Path(folder) / "missing.json")
            self.assertEqual(wins, {})
            self.assertIn("no win rates", wrong)
            measured = pathlib.Path(folder) / "win_rates.json"
            measured.write_text('{"weights_sha256": "not this one", "fights": 1, "wins": {}}')
            self.assertIn("another", compare.win_rates(published, measured)[1])


class TestReportNeedsAHeldOutSet(unittest.TestCase):
    def test_one_recording_is_refused_with_exit_1(self) -> None:
        rows = {"header": {"features": ["distance"], "actions": ACTIONS, "reaction": 15},
                "sessions": [{"about": {"recording": "only.json", "player": "person", "characters": ["a", "b"]},
                              "rows": [["close", "throw", 10], ["far", "high", 40]]}]}
        with tempfile.TemporaryDirectory() as folder:
            rows_path = pathlib.Path(folder) / "rows.json"
            rows_path.write_text(json.dumps(rows))
            published = pathlib.Path(folder) / "clone_weights.json"
            published.write_text(json.dumps({"trained_on": {"player": "person"}}))
            with contextlib.redirect_stdout(io.StringIO()) as printed:
                code = compare.report(published, rows_path, pathlib.Path(folder) / "none.json")
        self.assertEqual(code, 1)
        self.assertIn("no held-out", printed.getvalue())


class TestTheNGramIsTheGames(unittest.TestCase):
    def test_the_report_says_how_many_decisions_were_a_backdash(self) -> None:
        before = Session("old.json", "person", ["lancer", "dancer"], [({}, "step in"), ({}, "mid")])
        after = Session("new.json", "person", ["lancer", "dancer"], [({}, "evade"), ({}, "mid")])
        self.assertIn("0 of 2 decisions, in 1 recording(s) -- none", compare.evades([before]))
        self.assertEqual(compare.evades([before, after]), "evades: 1 of 4 decisions, in 2 recording(s)")

    def test_the_report_scores_the_ngram_with_the_learners_own_settings(self) -> None:
        """`measure` copies the learner's order and decay; this holds the copy to the game's defaults."""
        import re
        learner = (pathlib.Path(__file__).resolve().parents[2]
                   / "godot/game/fighting/fight_model_opponent.gd").read_text(encoding="utf-8")
        found = re.search(r"func _init\([^)]*order: int = (\d+), decay: float = ([\d.]+)\)", learner)
        self.assertIsNotNone(found, "the learner's _init no longer names its order and decay defaults")
        self.assertEqual((int(found.group(1)), float(found.group(2))), (measure.NGRAM_ORDER, measure.NGRAM_DECAY))
        self.assertIn("NGramPredictor.new(order, ACTIONS, decay, 1.0)", learner)
        self.assertEqual(measure.NGRAM_PRIOR, 1.0)


class TestTheReportScoresThePublishedSplit(unittest.TestCase):
    def test_a_file_fitted_on_another_split_is_named(self) -> None:
        training, held = [session("a.json", [])], [session("b.json", [])]
        with tempfile.TemporaryDirectory() as folder:
            published = pathlib.Path(folder) / "clone_weights.json"
            published.write_text(json.dumps({"trained_on": {"recordings": ["a.json"], "held_out": ["b.json"]}}))
            self.assertEqual(compare.split_matches(published, training, held), "")
            published.write_text(json.dumps({"trained_on": {"recordings": ["a.json", "b.json"], "held_out": []}}))
            self.assertIn("another split", compare.split_matches(published, training, held))


class TestLeaveOneOut(unittest.TestCase):
    def test_every_recording_is_scored_once(self) -> None:
        sessions = [session(f"r{index}", [({"distance": "far", "last": "nothing"}, "high")] * (index + 1))
                    for index in range(3)]
        pooled = measure.leave_one_out(sessions, ["distance", "last"], ACTIONS)
        self.assertTrue(all(score.rows == 6 for score in pooled))
