"""The player model vectors in `spec/vectors/player_model/`, against `gameaikit.botmatch`.

Each vector is an event list -- the person's bot's, its team-mates' hits
and hurts, and its seats -- and every interval's reading over it: the
counts, the team's share and the hit rate, the table's row and its aim
error, and whether the band held the row. The Python model must reproduce
them. The other half is
`make test-player-model-vectors`, the same files against Godot's
`PlayerModel`. The answers came from neither, from `derive.py` beside them.
"""

import json
import pathlib
import unittest

from gameaikit.botmatch import player_model

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "player_model"
FEWEST_VECTORS = 11


class TheVectors(unittest.TestCase):
    def test_there_are_vectors_to_check(self):
        self.assertGreaterEqual(len(list(VECTORS.glob("*.json"))), FEWEST_VECTORS)

    def test_every_reading_is_the_vectors(self):
        table = player_model.read_table()
        for path in sorted(VECTORS.glob("*.json")):
            vector = json.loads(path.read_text())
            found = player_model.replay(table, vector["events"], vector["last_step"])
            self.assertEqual(len(found), len(vector["readings"]), path.name)
            for reading, wanted in zip(found, vector["readings"]):
                where = f"{path.name}, step {wanted['step']}"
                self.assertEqual(reading["step"], wanted["step"], where)
                self.assertEqual(reading["counts"], wanted["counts"], where)
                self.assertEqual(reading["row"], wanted["row"], where)
                self.assertEqual(reading["aim_error_degrees"], wanted["aim_error_degrees"], where)
                self.assertEqual(reading["held"], wanted["held"], where)
                self.assertAlmostEqual(reading["share"], wanted["share"], places=12, msg=where)
                self.assertAlmostEqual(reading["hit_rate"], wanted["hit_rate"], places=12, msg=where)


class ThePlantedModels(unittest.TestCase):
    """Four wrong models the vectors must refuse, so a green run means something."""

    def _differs(self, replay) -> bool:
        table = player_model.read_table()
        for path in sorted(VECTORS.glob("*.json")):
            vector = json.loads(path.read_text())
            rows = [reading["row"] for reading in replay(table, vector["events"], vector["last_step"])]
            if rows != [reading["row"] for reading in vector["readings"]]:
                return True
        return False

    def test_a_boundary_given_to_the_row_below_is_refused(self):
        def strict(table, events, last_step):
            readings = player_model.replay(table, events, last_step)
            for reading in readings:
                below = [index for index, row in enumerate(table["rows"]) if reading["share"] > row["from"]]
                reading["row"] = below[-1] if below else 0
            return readings
        self.assertTrue(self._differs(strict))

    def test_a_model_with_no_band_is_refused(self):
        def no_band(table, events, last_step):
            return player_model.replay(dict(table, band={"from": 0.5, "to": 0.5}), events, last_step)
        self.assertTrue(self._differs(no_band))

    def test_a_model_that_keeps_its_counts_across_a_change_of_team_is_refused(self):
        def keeps(table, events, last_step):
            return player_model.replay(table, [event for event in events if event["kind"] != "seat"], last_step)
        self.assertTrue(self._differs(keeps))

    def test_a_model_with_a_prior_of_one_is_refused(self):
        def prior_of_one(table, events, last_step):
            return player_model.replay(dict(table, prior_points=1), events, last_step)
        self.assertTrue(self._differs(prior_of_one))


if __name__ == "__main__":
    unittest.main()
