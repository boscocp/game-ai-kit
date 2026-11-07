"""The fighting opponent's random forest (T114): fitted on the person's training fights only, published as a model file."""

import contextlib
import io
import json
import pathlib
import tempfile
import unittest

from gameaikit.cloning import opponent_forest, opponent_tree
from gameaikit.training import forest, model_file

from .test_opponent_tree import recorded


class TheOpponentForest(unittest.TestCase):

    def test_the_held_out_fights_are_kept_out_of_every_tree(self) -> None:
        # The held-out fight always answers high; a tree that had seen it
        # would know high exists. No tree of this forest has counted one.
        published = opponent_forest.published(recorded(), "person")
        self.assertEqual(published["trained_on"]["held_out"], ["fight-0.json", "fight-4.json"])
        trees = published["models"][opponent_tree.MODEL_NAME]["trees"]
        self.assertEqual(len(trees), opponent_forest.TREES)
        counted = {answer for nodes in trees for node in nodes for answer in node.get("counts", {})}
        self.assertNotIn("high", counted)

    def test_what_it_publishes_is_a_model_file_the_game_loads(self) -> None:
        published = opponent_forest.published(recorded(), "person")
        self.assertEqual(model_file.why_wrong(published), "")
        self.assertEqual(published["generated_by"], "gameaikit.cloning.opponent_forest")
        self.assertEqual(json.loads(opponent_forest.as_text(published)), published)

    def test_the_vote_reads_the_rows_it_was_given(self) -> None:
        read = forest.from_dict(opponent_forest.published(recorded(), "person")["models"][opponent_tree.MODEL_NAME])
        self.assertEqual(read.likeliest({"last": "high", "distance": "close"}), "throw")
        self.assertEqual(read.likeliest({"last": "high", "distance": "far"}), "low")

    def test_the_published_forest_has_the_published_tree_s_settings(self) -> None:
        # So the page compares one tree with many, and nothing else.
        trained_on = opponent_forest.published(recorded(), "person")["trained_on"]
        self.assertEqual((trained_on["max_depth"], trained_on["min_leaf"]),
                         (opponent_tree.MAX_DEPTH, opponent_tree.MIN_LEAF))

    def test_check_passes_a_fresh_file_and_fails_an_edited_one(self) -> None:
        # The planted case for `--check`, which N18 relies on: one count
        # changed by hand, and the file is stale.
        rows_file = pathlib.Path(__file__).resolve().parents[2] / "data" / "cloning" / "rows.json"
        with tempfile.TemporaryDirectory() as folder:
            arguments = ["--rows", str(rows_file)]
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(opponent_forest.main(arguments + ["--write", folder]), 0)
                written = pathlib.Path(folder) / opponent_forest.FILE_NAME
                self.assertEqual(opponent_forest.main(arguments + ["--check", str(written)]), 0)
                written.write_text(written.read_text().replace('"rows": ', '"rows": 1', 1))
                self.assertEqual(opponent_forest.main(arguments + ["--check", str(written)]), 1)

    def test_the_report_needs_a_held_out_fight(self) -> None:
        alone = recorded()
        alone.sessions = alone.sessions[:1]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(opponent_forest.report(alone, "person"), 1)
            self.assertEqual(opponent_forest.report(recorded(), "person"), 0)


if __name__ == "__main__":
    unittest.main()
