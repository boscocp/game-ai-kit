"""The bot match's player model and its table (T100), in Python.

What the vectors cannot say on their own: that the table is bounded and in
order, that an empty model starts in the middle, that the model keeps
counts and nothing else, and that replaying one log twice gives one answer.
"""

import unittest

from gameaikit.botmatch import player_model


class TheTable(unittest.TestCase):
    def setUp(self):
        self.rules = player_model.read_rules()
        self.table = player_model.read_table()

    def test_rows_rise_in_share_and_tighten_in_aim(self):
        rows = self.table["rows"]
        self.assertEqual(rows[0]["from"], 0.0)
        froms = [row["from"] for row in rows]
        errors = [row["aim_error_degrees"] for row in rows]
        self.assertEqual(froms, sorted(set(froms)))
        self.assertEqual(errors, sorted(set(errors), reverse=True))

    def test_an_empty_model_reads_the_middle_row_the_knobs_aim_error(self):
        share = player_model.PlayerModel().damage_share(self.table)
        row = self.table["rows"][player_model.row_for(self.table, share)]
        self.assertEqual(share, 0.5)
        self.assertEqual(row["aim_error_degrees"], self.rules["knobs"]["aim_error_degrees"])

    def test_the_interval_is_a_whole_number_of_steps(self):
        self.assertAlmostEqual(self.table["interval_steps"] * self.rules["step"], self.table["interval"], places=9)

    def test_no_share_reads_outside_the_table(self):
        for share in (0.0, 0.2, 0.999, 1.0):
            self.assertIn(player_model.row_for(self.table, share), range(len(self.table["rows"])))


class TheModel(unittest.TestCase):
    def test_it_keeps_counts_only(self):
        model = player_model.PlayerModel()
        for event in ({"kind": "shot"}, {"kind": "hit", "points": 24}, {"kind": "hurt", "points": 12},
                      {"kind": "kill"}, {"kind": "death"}):
            model.count(event)
        self.assertEqual(vars(model), {"shots": 1, "hits": 1, "kills": 1, "deaths": 1, "dealt": 24, "taken": 12})

    def test_an_unknown_event_is_refused(self):
        with self.assertRaises(ValueError):
            player_model.PlayerModel().count({"kind": "rating"})

    def test_the_hit_rate_is_laplaces_rule(self):
        model = player_model.PlayerModel()
        self.assertEqual(model.hit_rate(), 0.5)
        for _ in range(3):
            model.count({"kind": "shot"})
        model.count({"kind": "hit", "points": 12})
        self.assertEqual(model.hit_rate(), 2.0 / 5.0)

    def test_one_log_replayed_twice_gives_one_answer(self):
        table = player_model.read_table()
        events = [{"step": step, "kind": "hurt" if step % 3 else "hit", "points": 12} for step in range(0, 2000, 7)]
        self.assertEqual(player_model.replay(table, events, 2000), player_model.replay(table, events, 2000))


if __name__ == "__main__":
    unittest.main()
