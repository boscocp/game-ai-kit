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
    """A recording of `rows`, by player "someone"."""
    return Session(name, "someone", ["lancer", "dancer"], rows)


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
        one = measure.ngram_score([session("a", habit)], ACTIONS)
        two = measure.ngram_score([session("a", habit), session("b", habit)], ACTIONS)
        self.assertEqual(two.right, 2 * one.right)


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
        rows = {"header": {"features": ["distance"], "actions": ACTIONS},
                "sessions": [{"about": {"recording": "only.json", "player": "person", "characters": ["a", "b"]},
                              "rows": [["close", "throw"], ["far", "high"]]}]}
        with tempfile.TemporaryDirectory() as folder:
            rows_path = pathlib.Path(folder) / "rows.json"
            rows_path.write_text(json.dumps(rows))
            published = pathlib.Path(folder) / "clone_weights.json"
            published.write_text(json.dumps({"trained_on": {"player": "person"}}))
            with contextlib.redirect_stdout(io.StringIO()) as printed:
                code = compare.report(published, rows_path, pathlib.Path(folder) / "none.json")
        self.assertEqual(code, 1)
        self.assertIn("no held-out", printed.getvalue())
