"""The fighting opponent's decision tree (T113): fitted on the person's training fights only, published as a model file."""

import contextlib
import io
import pathlib
import tempfile
import unittest

from gameaikit.cloning import measure, opponent_tree
from gameaikit.cloning.rows import Recorded, Session
from gameaikit.training import model_file, tree

FEATURES = ["last", "distance"]
ACTIONS = ["high", "low", "throw"]


def recorded() -> Recorded:
    """Five recordings of one player: the last and every fourth before it are held out."""
    sessions = []
    for number in range(5):
        session = Session(f"fight-{number}.json", "person", ["lancer", "dancer"])
        for row in range(6):
            answer = "throw" if row % 2 else "low"
            session.rows.append(({"last": "high", "distance": "close" if row % 2 else "far"}, answer))
            session.frames.append(row * 20)
        sessions.append(session)
    held_out = sessions[4]
    held_out.rows = [({"last": "high", "distance": "close"}, "high")] * 6
    return Recorded(FEATURES, ACTIONS, sessions)


class TheOpponentTree(unittest.TestCase):

    def test_the_held_out_fights_are_kept_out_of_the_fit(self) -> None:
        # The held-out fight always answers high; a tree that had seen it
        # would know high exists. This one has never counted a high.
        published = opponent_tree.published(recorded(), "person")
        self.assertEqual(published["trained_on"]["held_out"], ["fight-0.json", "fight-4.json"])
        nodes = published["models"][opponent_tree.MODEL_NAME]["nodes"]
        counted = {answer for node in nodes for answer in node.get("counts", {})}
        self.assertNotIn("high", counted)

    def test_what_it_publishes_is_a_model_file_the_game_loads(self) -> None:
        published = opponent_tree.published(recorded(), "person")
        self.assertEqual(model_file.why_wrong(published), "")
        self.assertEqual(published["generated_by"], "gameaikit.cloning.opponent_tree")

    def test_the_fit_reads_the_rows_it_was_given(self) -> None:
        fitted = tree.from_dict(opponent_tree.published(recorded(), "person")["models"][opponent_tree.MODEL_NAME])
        self.assertEqual(fitted.likeliest({"last": "high", "distance": "close"}), "throw")
        self.assertEqual(fitted.likeliest({"last": "high", "distance": "far"}), "low")

    def test_check_passes_a_fresh_file_and_fails_an_edited_one(self) -> None:
        # The planted case for `--check`, which N16 relies on: one count
        # changed by hand, and the file is stale.
        rows_file = pathlib.Path(__file__).resolve().parents[2] / "data" / "cloning" / "rows.json"
        with tempfile.TemporaryDirectory() as folder:
            arguments = ["--rows", str(rows_file)]
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(opponent_tree.main(arguments + ["--write", folder]), 0)
                written = pathlib.Path(folder) / opponent_tree.FILE_NAME
                self.assertEqual(opponent_tree.main(arguments + ["--check", str(written)]), 0)
                written.write_text(written.read_text().replace('"rows": ', '"rows": 1', 1))
                self.assertEqual(opponent_tree.main(arguments + ["--check", str(written)]), 1)

    def test_the_report_needs_a_held_out_fight(self) -> None:
        alone = recorded()
        alone.sessions = alone.sessions[:1]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(opponent_tree.report(alone, "person"), 1)
            self.assertEqual(opponent_tree.report(recorded(), "person"), 0)

    def test_the_split_is_the_clone_s(self) -> None:
        training, held = measure.split(recorded().of_player("person"))
        published = opponent_tree.published(recorded(), "person")["trained_on"]
        self.assertEqual(published["recordings"], [session.recording for session in training])
        self.assertEqual(published["held_out"], [session.recording for session in held])


if __name__ == "__main__":
    unittest.main()
