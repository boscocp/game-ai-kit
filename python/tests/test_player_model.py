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

    def test_the_band_holds_the_middle_row_and_is_inside_the_table(self):
        band = self.table["band"]
        self.assertLess(band["from"], 0.5)
        self.assertGreater(band["to"], 0.5)
        start = player_model.start_row(self.table)
        self.assertEqual(player_model.next_row(self.table, 0.5, 0), 0)
        self.assertEqual(player_model.next_row(self.table, band["to"], 0), player_model.row_for(self.table, band["to"]))
        self.assertEqual(player_model.row_for(self.table, 0.5), start)

    def test_no_share_reads_outside_the_table(self):
        for share in (0.0, 0.2, 0.999, 1.0):
            self.assertIn(player_model.row_for(self.table, share), range(len(self.table["rows"])))


class TheModel(unittest.TestCase):
    def test_it_keeps_counts_only(self):
        model = player_model.PlayerModel()
        for event in ({"kind": "shot"}, {"kind": "hit", "points": 24}, {"kind": "hurt", "points": 12},
                      {"kind": "kill"}, {"kind": "death"}):
            model.count(event)
        model.count({"kind": "mate_hit", "points": 6})
        model.count({"kind": "mate_hurt", "points": 3})
        model.count({"kind": "seat", "team": 0})
        self.assertEqual(vars(model), {"shots": 1, "hits": 1, "kills": 1, "deaths": 1, "dealt": 24, "taken": 12,
                                       "team_dealt": 30, "team_taken": 15, "team": 0, "restarts": 0})

    def test_the_share_is_the_teams(self):
        model = player_model.PlayerModel()
        model.count({"kind": "mate_hit", "points": 100})
        self.assertEqual(model.dealt, 0)
        self.assertEqual(model.damage_share({"prior_points": 100}), 200.0 / 300.0)

    def test_a_seat_on_the_other_team_empties_the_counts_and_the_same_team_keeps_them(self):
        model = player_model.PlayerModel()
        for event in ({"kind": "seat", "team": 0}, {"kind": "hit", "points": 24}, {"kind": "seat", "team": 0}):
            self.assertFalse(model.counted_from_empty(event))
        self.assertEqual(model.dealt, 24)
        self.assertTrue(model.counted_from_empty({"kind": "seat", "team": 1}))
        self.assertEqual(model.counts(), dict.fromkeys(player_model.COUNTED, 0) | {"restarts": 1})

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
