"""The Python half of the bandit conformance run.

The vectors in `spec/vectors/bandit/` are read from both languages, and each
side checks every claim in them against the file -- never against the other
side. The choices came from neither: a script importing nothing from this
repository wrote them (the README works one by hand).
"""

import json
import pathlib
import unittest

from gameaikit.bandit import EPSILON_GREEDY, UCB1, Bandit

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "bandit"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 6

#: The margin both sides allow on a sum: the payoffs are exact binary
#: fractions, so the sums are exact, and this only forgives the printing.
TOLERANCE = 1e-9

VECTOR_KEYS = {"description", "policy", "arms", "exploration", "epsilon", "seed", "payoffs", "chosen", "pulls",
               "sums"}


def bandit_of(vector: dict) -> Bandit:
    """The bandit the vector describes, before its first pull."""
    return Bandit(vector["arms"], vector["policy"], vector["exploration"], vector["epsilon"], vector["seed"])


def why_not_a_vector(vector: dict) -> str:
    """Why this is not a usable vector, or "" when it is one."""
    if set(vector) != VECTOR_KEYS:
        return f"V1 its keys are {sorted(vector)}, not {sorted(VECTOR_KEYS)}"
    settings = bandit_of(vector).problem()
    if settings:
        return f"V2 its settings cannot work: {settings}"
    if len(vector["payoffs"]) != vector["arms"] or not all(vector["payoffs"]):
        return "V3 it does not give every arm a payoff sequence"
    if any(not 0.0 <= payoff <= 1.0 for sequence in vector["payoffs"] for payoff in sequence):
        return "V4 a payoff lies outside [0, 1], where UCB1's bound holds"
    if not vector["chosen"]:
        return "V5 it claims no pull"
    if len(vector["pulls"]) != vector["arms"] or len(vector["sums"]) != vector["arms"]:
        return "V6 its final pulls and sums do not name every arm"
    if sum(vector["pulls"]) != len(vector["chosen"]):
        return "V7 its final pulls do not add up to the pulls it claims"
    return ""


def wrong_claims(vector: dict, make=bandit_of) -> list[str]:
    """Every claim in the vector that the bandit `make` builds does not meet.

    The k-th pull of an arm pays its sequence's k-th payoff, from the start
    again when the sequence runs out.
    """
    bandit = make(vector)
    wrong = []
    for pull, claimed in enumerate(vector["chosen"]):
        arm = bandit.choose()
        if arm != claimed:
            wrong.append(f"pull {pull}: arm {arm}, not {claimed}")
            return wrong
        sequence = vector["payoffs"][arm]
        bandit.reward(arm, sequence[bandit.pulls[arm] % len(sequence)])
    if bandit.pulls != vector["pulls"]:
        wrong.append(f"pulls {bandit.pulls}, not {vector['pulls']}")
    for arm, claimed in enumerate(vector["sums"]):
        if abs(bandit.sums[arm] - claimed) > TOLERANCE:
            wrong.append(f"arm {arm}'s sum {bandit.sums[arm]}, not {claimed}")
    return wrong


def _vectors() -> dict[str, dict]:
    return {path.stem: json.loads(path.read_text(encoding="utf-8")) for path in sorted(VECTORS.glob("*.json"))}


class TestBanditVectors(unittest.TestCase):
    def test_the_directory_holds_vectors(self) -> None:
        self.assertGreaterEqual(len(_vectors()), FEWEST_VECTORS)

    def test_every_vector_is_one(self) -> None:
        for name, vector in _vectors().items():
            with self.subTest(name):
                self.assertEqual(why_not_a_vector(vector), "")

    def test_both_policies_are_held(self) -> None:
        policies = {vector["policy"] for vector in _vectors().values()}
        self.assertEqual(policies, {UCB1, EPSILON_GREEDY})

    def test_the_bandit_makes_every_claimed_choice(self) -> None:
        for name, vector in _vectors().items():
            with self.subTest(name):
                self.assertEqual(wrong_claims(vector), [])

    def test_a_broken_vector_is_refused_by_its_rule(self) -> None:
        sound = _vectors()["ucb1-two-arms-by-hand"]
        for rule, change in [("V1", {"chosn": [0]}), ("V2", {"policy": "softmax"}), ("V3", {"payoffs": [[1.0]]}),
                             ("V4", {"payoffs": [[1.5], [0.0]]}), ("V5", {"chosen": []}),
                             ("V6", {"sums": [5.0]}), ("V7", {"pulls": [5, 3]})]:
            with self.subTest(rule):
                self.assertTrue(why_not_a_vector(dict(sound, **change)).startswith(rule))

    def test_a_bandit_that_breaks_ties_to_the_last_fails(self) -> None:
        class LastOfEqual(Bandit):
            def _highest(self, score):
                best = 0
                for arm in range(1, len(self.pulls)):
                    if score(arm) >= score(best):
                        best = arm
                return best

        vector = _vectors()["ucb1-ties-go-to-the-first"]
        self.assertNotEqual(wrong_claims(vector, lambda v: LastOfEqual(v["arms"], v["policy"], v["exploration"])), [])

    def test_a_bandit_that_spends_a_spare_draw_fails(self) -> None:
        class SpareDraw(Bandit):
            def choose(self):
                if self.policy == EPSILON_GREEDY and self._first_untried() < 0:
                    self._draws.next()
                return super().choose()

        vector = _vectors()["epsilon-greedy-seeded"]
        made = lambda v: SpareDraw(v["arms"], v["policy"], v["exploration"], v["epsilon"], v["seed"])  # noqa: E731
        self.assertNotEqual(wrong_claims(vector, made), [])


if __name__ == "__main__":
    unittest.main()
