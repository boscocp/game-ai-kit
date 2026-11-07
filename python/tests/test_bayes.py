"""The Bayesian network's rules, one test each, beside what the vectors hold."""

import unittest

from gameaikit.bayes import BayesNetwork, most_moved
from gameaikit.techniques import kit

YES, NO = "yes", "no"


def burglary() -> BayesNetwork:
    """AIMA 4th ed., figure 13.2."""
    return BayesNetwork({"variables": [
        {"name": "burglary", "values": [YES, NO], "parents": [], "table": [[0.001, 0.999]]},
        {"name": "earthquake", "values": [YES, NO], "parents": [], "table": [[0.002, 0.998]]},
        {"name": "alarm", "values": [YES, NO], "parents": ["burglary", "earthquake"],
         "table": [[0.95, 0.05], [0.94, 0.06], [0.29, 0.71], [0.001, 0.999]]},
        {"name": "john_calls", "values": [YES, NO], "parents": ["alarm"], "table": [[0.90, 0.10], [0.05, 0.95]]},
        {"name": "mary_calls", "values": [YES, NO], "parents": ["alarm"], "table": [[0.70, 0.30], [0.01, 0.99]]},
    ]})


def one_variable(values: list, table: list, parents: list | None = None) -> dict:
    """A network of one variable called `one`, as data."""
    return {"variables": [{"name": "one", "values": values, "parents": parents or [], "table": table}]}


class TestBayesNetwork(unittest.TestCase):
    def test_the_books_answer(self) -> None:
        # AIMA 4th ed., 13.3.1: P(Burglary | john, mary) is about <0.284, 0.716>.
        distribution = burglary().ask("burglary", {"john_calls": YES, "mary_calls": YES})
        self.assertAlmostEqual(distribution[0], 0.284, places=3)
        self.assertAlmostEqual(sum(distribution), 1.0)

    def test_no_evidence_is_the_prior(self) -> None:
        self.assertAlmostEqual(burglary().ask("burglary", {})[0], 0.001)

    def test_a_table_entry_is_read_by_its_parents(self) -> None:
        network = burglary()
        self.assertEqual(network.probability("alarm", YES, {"burglary": NO, "earthquake": YES}), 0.29)

    def test_an_earthquake_explains_the_alarm_away(self) -> None:
        network = burglary()
        alone = network.ask("burglary", {"alarm": YES})[0]
        explained = network.ask("burglary", {"alarm": YES, "earthquake": YES})[0]
        self.assertLess(explained, alone)
        self.assertLess(network.influence("burglary", YES, {"alarm": YES, "earthquake": YES})["earthquake"], 0.0)

    def test_the_evidence_that_moved_it_most(self) -> None:
        moved = burglary().influence("burglary", YES, {"john_calls": YES, "mary_calls": YES})
        self.assertEqual(most_moved(moved), "mary_calls")
        self.assertEqual(most_moved({"one": -0.5, "two": 0.25}), "one")
        self.assertEqual(most_moved({"one": 0.25, "two": -0.25}), "one")
        self.assertEqual(most_moved({}), "")

    def test_impossible_evidence_has_no_answer(self) -> None:
        network = BayesNetwork({"variables": [
            {"name": "cause", "values": [YES, NO], "parents": [], "table": [[1.0, 0.0]]},
            {"name": "effect", "values": [YES, NO], "parents": ["cause"], "table": [[1.0, 0.0], [0.0, 1.0]]}]})
        self.assertEqual(network.ask("cause", {"effect": NO}), [])
        self.assertEqual(network.influence("cause", YES, {"effect": NO}), {})

    def test_asking_what_is_not_there_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            burglary().ask("thief", {})
        with self.assertRaises(ValueError):
            burglary().ask("burglary", {"alarm": "maybe"})
        with self.assertRaises(ValueError):
            burglary().ask("burglary", {"burglary": YES})

    def test_each_malformed_network_is_named_by_its_rule(self) -> None:
        cases = [
            ("B1", {"variables": []}),
            ("B2", one_variable([YES], [[1.0]])),
            ("B2", one_variable([YES, YES], [[0.5, 0.5]])),
            ("B3", one_variable([YES, NO], [[0.5, 0.5]], ["two"])),
            ("B4", one_variable([YES, NO], [[0.5, 0.5], [0.5, 0.5]])),
            ("B4", one_variable([YES, NO], [[1.0]])),
            ("B5", one_variable([YES, NO], [[0.7, 0.7]])),
            ("B5", one_variable([YES, NO], [[1.5, -0.5]])),
        ]
        for rule, data in cases:
            with self.subTest(rule):
                self.assertTrue(BayesNetwork(data).problem().startswith(rule), BayesNetwork(data).problem())
        self.assertEqual(burglary().problem(), "")

    def test_the_kit_lists_it(self) -> None:
        self.assertIn("bayes", kit())


if __name__ == "__main__":
    unittest.main()
