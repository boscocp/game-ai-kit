"""The valley vectors in `spec/vectors/valley/`, against `gameaikit.valley`.

A `rebuilt` vector is a record and the world and standing of every day;
the Python machine must reproduce them. A `refused` vector is a saved
record's lines and the word its refusal must name. The other half is
`make test-valley-vectors`, the same files against Godot's classes.
"""

import json
import pathlib
import unittest

from gameaikit.valley import record
from gameaikit.valley.rules import ValleyRules
from gameaikit.valley.standing import Standing

REPO = pathlib.Path(__file__).resolve().parents[2]
VECTORS = REPO / "spec" / "vectors" / "valley"
FEWEST_REBUILT = 8
FEWEST_REFUSED = 13


def vectors(kind: str) -> list[tuple[str, dict]]:
    """Every vector of `kind`, by file name."""
    found = [(path.name, json.loads(path.read_text())) for path in sorted(VECTORS.glob("*.json"))]
    return [(name, vector) for name, vector in found if vector["kind"] == kind]


class TheVectors(unittest.TestCase):
    def setUp(self) -> None:
        self.rules = ValleyRules.read()
        self.standing = Standing.read()

    def test_there_are_vectors_of_both_kinds(self) -> None:
        self.assertGreaterEqual(len(vectors("rebuilt")), FEWEST_REBUILT)
        self.assertGreaterEqual(len(vectors("refused")), FEWEST_REFUSED)

    def test_every_day_is_the_vectors(self) -> None:
        for name, vector in vectors("rebuilt"):
            log = self.rules.new_record()
            for deed in vector["deeds"]:
                self.assertEqual(log.append(deed), "", name)
            for day in range(1, vector["days"] + 1):
                self.assertEqual(self.rules.rebuild(log, day), vector["worlds"][day - 1], f"{name}, day {day}")
                self.assertEqual(self.standing.of(log.cut(day)), vector["standing"][day - 1], f"{name}, day {day}")

    def test_every_refused_record_is_refused_by_name(self) -> None:
        for name, vector in vectors("refused"):
            self.assertTrue(vector["names"].strip(), f"{name} names nothing, so any refusal would hold it")
            why = record.read_lines(vector["lines"], self.rules.new_record())
            self.assertIn(vector["names"], why, name)
            text = "\n".join(vector["lines"]) + "\n"
            self.assertIn(vector["names"], record.read_text(text, self.rules.new_record()), f"{name}, as a file")


if __name__ == "__main__":
    unittest.main()
