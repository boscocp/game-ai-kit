"""The Python half of the combat conformance run.

Each vector in `spec/vectors/combat/` hands `combat.fight` a list of rolls and
says what must come out. The GDScript half, `godot/test/combat_vectors_runner.gd`,
reads the same files and hands them to the tactical board's combat.
"""

import json
import pathlib
import unittest

from gameaikit.dataset import combat

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "combat"

#: Fewer than this and the directory is wrong, not the vectors: a run over an
#: empty glob passes by checking nothing.
FEWEST_VECTORS = 5


class CombatVectors(unittest.TestCase):

    def test_there_are_vectors_to_check(self) -> None:
        self.assertGreaterEqual(len(list(VECTORS.glob("*.json"))), FEWEST_VECTORS)

    def test_every_vector_fights_the_fight_it_writes_down(self) -> None:
        for path in sorted(VECTORS.glob("*.json")):
            with self.subTest(vector=path.name):
                vector = json.loads(path.read_text())
                rolls = list(vector["rolls"])
                used = []

                def roll() -> int:
                    used.append(rolls[len(used)])
                    return used[-1]

                outcome = combat.fight(roll=roll, **vector["fight"])
                expect = vector["expect"]
                self.assertEqual(outcome.attacker_won, expect["attacker_won"])
                self.assertEqual(outcome.attacker_left, expect["attacker_left"])
                self.assertEqual(outcome.defender_left, expect["defender_left"])
                self.assertEqual(len(used), expect["rolls_used"])

    def test_the_rules_file_is_the_one_the_vectors_were_checked_against(self) -> None:
        # The vectors were checked by hand against these numbers; a change to
        # the file must come with new vectors, not slip under the old ones.
        self.assertEqual(combat.RULES["die"], {"lowest": 1, "highest": 4})
        self.assertEqual((combat.TERRAIN_WORTH, combat.NUMBERS_WORTH, combat.COUNTER_WORTH), (1, 1, 2))


if __name__ == "__main__":
    unittest.main()
