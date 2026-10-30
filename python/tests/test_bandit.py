"""The bandit's rules, one test each, and the regret curve a vector cannot show."""

import math
import unittest

from gameaikit.bandit import EPSILON_GREEDY, UCB1, Bandit, BanditDraws

#: A known two-arm problem: an arm paying 1 with chance 0.7, and one with 0.3.
CHANCES = (0.7, 0.3)
#: How long the comparison runs, and where the first count is taken.
PULLS = 10_000
EARLY = 1_000
SEEDS = range(1, 6)


def regret(policy: str, seed: int) -> dict[int, float]:
    """The expected payoff given up by `policy` on `CHANCES`, at EARLY and PULLS.

    Regret is the best arm's chance less the chosen arm's, summed over the
    pulls (AIMA 4th ed., 17.3): what was lost to trying the worse arm. The
    world's coin is a separate generator, so the two policies see the same
    world only as far as they pull the same arms.
    """
    bandit = Bandit(len(CHANCES), policy, seed=seed)
    world = BanditDraws(seed * 7919 + 13)
    best = max(CHANCES)
    lost = 0.0
    taken = {}
    for pull in range(1, PULLS + 1):
        arm = bandit.choose()
        bandit.reward(arm, 1.0 if world.uniform() < CHANCES[arm] else 0.0)
        lost += best - CHANCES[arm]
        if pull in (EARLY, PULLS):
            taken[pull] = lost
    return taken


class TestBandit(unittest.TestCase):
    def test_settings_that_cannot_work_are_named(self) -> None:
        self.assertIn("one arm", Bandit(0).problem())
        self.assertIn("policy", Bandit(2, "softmax").problem())
        self.assertIn("exploration", Bandit(2, exploration=-1.0).problem())
        self.assertIn("epsilon", Bandit(2, EPSILON_GREEDY, epsilon=1.5).problem())
        self.assertEqual(Bandit(3).problem(), "")

    def test_every_arm_is_tried_once_first_in_order(self) -> None:
        for policy in (UCB1, EPSILON_GREEDY):
            bandit = Bandit(4, policy, epsilon=1.0)
            tried = []
            for _ in range(4):
                arm = bandit.choose()
                tried.append(arm)
                bandit.reward(arm, 1.0 if arm == 3 else 0.0)
            self.assertEqual(tried, [0, 1, 2, 3], policy)

    def test_a_mean_is_a_sum_over_pulls_read_when_asked(self) -> None:
        bandit = Bandit(2)
        self.assertEqual(bandit.mean(0), 0.0)
        for payoff in (1.0, 0.0, 0.5):
            bandit.reward(0, payoff)
        self.assertEqual((bandit.pulls[0], bandit.sums[0]), (3, 1.5))
        self.assertEqual(bandit.mean(0), 0.5)
        self.assertFalse(hasattr(bandit, "means"), "a mean is never kept, only computed (ADR 0016)")

    def test_the_bound_is_the_mean_plus_the_confidence_term(self) -> None:
        bandit = Bandit(2)
        self.assertEqual(bandit.bound(0), math.inf)
        bandit.reward(0, 1.0)
        bandit.reward(1, 0.0)
        bandit.reward(1, 0.5)
        self.assertAlmostEqual(bandit.bound(0), 1.0 + math.sqrt(2.0 * math.log(3) / 1), places=12)
        self.assertAlmostEqual(bandit.bound(1), 0.25 + math.sqrt(2.0 * math.log(3) / 2), places=12)

    def test_a_payoff_outside_zero_to_one_is_kept_to_it(self) -> None:
        bandit = Bandit(1)
        bandit.reward(0, 3.0)
        bandit.reward(0, -1.0)
        self.assertEqual(bandit.sums[0], 1.0)

    def test_a_pull_waiting_for_its_payoff_is_not_untried(self) -> None:
        bandit = Bandit(3)
        chosen = []
        for _ in range(3):
            arm = bandit.choose()
            chosen.append(arm)
            bandit.pull(arm)
        self.assertEqual(chosen, [0, 1, 2], "a pending arm is tried, not chosen again")
        self.assertEqual(bandit.mean(0), 0.0)
        bandit.pay(0, 1.0)
        self.assertEqual((bandit.pulls[0], bandit.paid[0], bandit.mean(0)), (1, 1, 1.0))

    def test_choosing_changes_no_count(self) -> None:
        bandit = Bandit(3, EPSILON_GREEDY)
        for _ in range(5):
            bandit.choose()
        self.assertEqual((bandit.pulls, bandit.sums), ([0, 0, 0], [0.0, 0.0, 0.0]))

    def test_ucb1_regret_grows_slower_than_epsilon_greedys(self) -> None:
        """The comparison the task asks for, over 10,000 pulls and five seeds.

        UCB1's regret grows with the logarithm of the pulls (Auer et al. 2002,
        theorem 1); epsilon-greedy's, at a fixed epsilon, grows in proportion
        to them -- a tenth of its pulls are random for ever, and half of
        those pick the worse arm. Measured on these seeds: UCB1 24 to 41 at
        10,000 pulls, epsilon-greedy 192 to 206.
        """
        totals = {UCB1: {EARLY: 0.0, PULLS: 0.0}, EPSILON_GREEDY: {EARLY: 0.0, PULLS: 0.0}}
        for seed in SEEDS:
            upper, greedy = regret(UCB1, seed), regret(EPSILON_GREEDY, seed)
            with self.subTest(seed=seed):
                self.assertLess(upper[PULLS], greedy[PULLS])
                self.assertLess(upper[PULLS] - upper[EARLY], greedy[PULLS] - greedy[EARLY])
            for policy, taken in ((UCB1, upper), (EPSILON_GREEDY, greedy)):
                for pull in taken:
                    totals[policy][pull] += taken[pull]
        # Logarithmic, not linear, over the five seeds together (one seed is
        # noisy): ten times the pulls is about twice UCB1's regret, and near
        # ten times epsilon-greedy's.
        self.assertLess(totals[UCB1][PULLS], 3.0 * totals[UCB1][EARLY])
        self.assertGreater(totals[EPSILON_GREEDY][PULLS], 8.0 * totals[EPSILON_GREEDY][EARLY])

if __name__ == "__main__":
    unittest.main()
