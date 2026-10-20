"""The Python half of the combat conformance run.

Each vector in `spec/vectors/combat/` hands `combat.fight` a list of rolls and
says what must come out. The GDScript half, `godot/test/tactical/combat_vectors_runner.gd`,
reads the same files and hands them to the tactical board's combat.
"""

import json
import pathlib
import unittest

from gameaikit.dataset import combat

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "combat"

#: Fewer than this and the directory is wrong, not the vectors: a run over an
#: empty glob passes by checking nothing.
FEWEST_VECTORS = 7

SPEC_RULES = pathlib.Path(__file__).resolve().parents[2] / "spec" / "combat" / "rules.json"


def _failures(vector: dict) -> list[str]:
    """What is wrong with the fight this vector writes down, as lines."""
    rolls = list(vector["rolls"])
    used: list[int] = []

    def roll() -> int:
        used.append(rolls[len(used)])
        return used[-1]

    outcome = combat.fight(roll=roll, **vector["fight"])
    found = [
        f"{key}: {getattr(outcome, key)} against {vector['expect'][key]}"
        for key in ("attacker_won", "attacker_left", "defender_left")
        if getattr(outcome, key) != vector["expect"][key]
    ]
    if len(used) != vector["expect"]["rolls_used"]:
        found.append(f"rolls_used: {len(used)} against {vector['expect']['rolls_used']}")
    return found


class CombatVectors(unittest.TestCase):

    def test_a_planted_wrong_vector_is_caught(self) -> None:
        # Before any real one is trusted: an expected number one off must fail.
        vector = json.loads(sorted(VECTORS.glob("*.json"))[0].read_text())
        vector["expect"]["defender_left"] += 1
        self.assertTrue(_failures(vector))

    def test_the_package_s_rules_are_the_spec_s_byte_for_byte(self) -> None:
        self.assertEqual(combat.RULES_PATH.read_bytes(), SPEC_RULES.read_bytes())

    def test_nobody_coming_is_the_dataset_board_s_width(self) -> None:
        # The fight's "no friend left" and the feature row's are one number.
        from gameaikit.dataset import simulate
        self.assertEqual(combat.RULES["nobody_coming"], simulate.WIDTH)

    def test_there_are_vectors_to_check(self) -> None:
        self.assertGreaterEqual(len(list(VECTORS.glob("*.json"))), FEWEST_VECTORS)

    def test_every_vector_fights_the_fight_it_writes_down(self) -> None:
        for path in sorted(VECTORS.glob("*.json")):
            with self.subTest(vector=path.name):
                self.assertEqual(_failures(json.loads(path.read_text())), [])

    def test_the_rules_file_is_the_one_the_vectors_were_checked_against(self) -> None:
        # The vectors were checked by hand against these numbers; a change to
        # the file must come with new vectors, not slip under the old ones.
        self.assertEqual(combat.RULES["die"], {"lowest": 1, "highest": 4})
        self.assertEqual((combat.TERRAIN_WORTH, combat.NUMBERS_WORTH, combat.COUNTER_WORTH), (1, 1, 1))


if __name__ == "__main__":
    unittest.main()
