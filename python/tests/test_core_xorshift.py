"""The kit's one seeded generator (T109), and the file that holds it to Godot's.

`spec/vectors/core/xorshift.json` was written by `derive.py`, which imports
nothing from this repository; `make test-core-vectors` reads the same file
through `ai_core`'s `Xorshift`. Three planted generators must fail it: one
that spends a draw on a pick of one -- the maze's old copy did, harmlessly,
since its ghosts never pick among one way --, one a draw ahead, and one
that forgets the mask, the one Python mistake GDScript's 64-bit `int`
cannot make the same way: Python's integers never wrap.
"""

import json
import pathlib
import unittest

from gameaikit.core import Xorshift
from gameaikit.core.xorshift import MASK, SEED_FOR_ZERO, SPAN

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "core"
#: The margin a uniform may differ by: the decimal text in the JSON, read back.
TOLERANCE = 1e-12
VECTOR_KEYS = ["cases", "description"]
CASE_KEYS = ["draws", "picks", "picks_of", "seed", "uniforms"]


class SpendsOnOne(Xorshift):
    """A twin that draws even when there is only one choice."""

    def index(self, count: int) -> int:
        return self.next() % count


class OneAhead(Xorshift):
    """A twin that throws its first draw away."""

    def __init__(self, from_seed: int = 1) -> None:
        super().__init__(from_seed)
        self.next()


class Unmasked(Xorshift):
    """A twin that cuts the seed to 32 bits and never again: it grows without end."""

    def __init__(self, from_seed: int = 1) -> None:
        super().__init__(from_seed)
        self._wide = (from_seed & MASK) or SEED_FOR_ZERO

    def next(self) -> int:
        self._wide ^= self._wide << 13
        self._wide ^= self._wide >> 17
        self._wide ^= self._wide << 5
        return self._wide


def wrong_claims(vector: dict, make: type = Xorshift) -> list[str]:
    """Every claim in the vector that generators built by `make` do not meet."""
    wrong = []
    for case in vector["cases"]:
        seed = case["seed"]
        drawn = make(seed)
        if [drawn.next() for _ in case["draws"]] != case["draws"]:
            wrong.append(f"seed {seed}: the draws")
        fresh = make(seed)
        uniforms = [fresh.uniform() for _ in case["uniforms"]]
        if any(abs(found - claimed) > TOLERANCE for found, claimed in zip(uniforms, case["uniforms"])):
            wrong.append(f"seed {seed}: the uniforms")
        picking = make(seed)
        if [picking.index(count) for count in case["picks_of"]] != case["picks"]:
            wrong.append(f"seed {seed}: the picks")
    return wrong


class TheGenerator(unittest.TestCase):
    def test_it_starts_where_marsaglia_starts_and_zero_is_one(self) -> None:
        # Worked in the README: 1 ^ (1 << 13) is 8193, >> 17 is 0, and
        # 8193 ^ (8193 << 5) is 270369.
        self.assertEqual(Xorshift(1).next(), 270369)
        self.assertEqual(Xorshift(0).next(), 270369)
        self.assertEqual(Xorshift().next(), 270369)

    def test_a_seed_is_cut_to_32_bits(self) -> None:
        self.assertEqual(Xorshift(2 ** 32 + 1).next(), Xorshift(1).next())

    def test_a_pick_of_one_spends_no_draw(self) -> None:
        drawn = Xorshift(9)
        self.assertEqual({drawn.index(1) for _ in range(5)}, {0})
        self.assertEqual(drawn.next(), Xorshift(9).next())

    def test_a_uniform_is_a_draw_over_its_span(self) -> None:
        first, second = Xorshift(86), Xorshift(86)
        for _ in range(20):
            uniform = first.uniform()
            self.assertTrue(0.0 < uniform < 1.0)
            self.assertEqual(uniform * SPAN, second.next())


class TheVectors(unittest.TestCase):
    def read(self) -> dict:
        return json.loads((VECTORS / "xorshift.json").read_text(encoding="utf-8"))

    def test_every_case_has_its_claims_and_the_generator_meets_them(self) -> None:
        vector = self.read()
        self.assertEqual(sorted(vector), VECTOR_KEYS)
        self.assertGreaterEqual(len(vector["cases"]), 4)
        for case in vector["cases"]:
            self.assertEqual(sorted(case), CASE_KEYS)
            self.assertEqual(len(case["picks"]), len(case["picks_of"]))
            self.assertTrue(case["draws"] and case["uniforms"], case["seed"])
        self.assertEqual(wrong_claims(vector), [])

    def test_a_twin_that_spends_a_draw_on_one_choice_fails_the_picks(self) -> None:
        wrong = wrong_claims(self.read(), SpendsOnOne)
        self.assertTrue(wrong)
        self.assertTrue(all(found.endswith("the picks") for found in wrong))

    def test_a_twin_without_the_mask_fails_the_draws(self) -> None:
        wrong = wrong_claims(self.read(), Unmasked)
        self.assertTrue(any(found.endswith("the draws") for found in wrong))

    def test_a_negative_seed_is_cut_as_godot_cuts_it(self) -> None:
        # -1 is 2^32 - 1 once cut, in two's complement as in GDScript's int.
        self.assertEqual(Xorshift(-1).next(), 253983)
        self.assertEqual(Xorshift(-1).next(), Xorshift(MASK).next())

    def test_a_twin_one_draw_ahead_fails_every_claim(self) -> None:
        wrong = wrong_claims(self.read(), OneAhead)
        for claim in ("the draws", "the uniforms", "the picks"):
            self.assertTrue(any(found.endswith(claim) for found in wrong), claim)


if __name__ == "__main__":
    unittest.main()
