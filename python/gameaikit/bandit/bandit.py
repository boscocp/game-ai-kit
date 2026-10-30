"""Which option next? Counts of how often each was tried, and what it paid.

Read `godot/addons/ai_bandit/bandit.gd` for the why: exploration against
exploitation, UCB1's two terms, and what ADR 0016 allows. This file does the
same arithmetic in the same order, and `spec/vectors/bandit/` holds both to
the same choices.
"""

from __future__ import annotations

import math
from collections.abc import Callable

from gameaikit.bandit.draws import SEED_FOR_ZERO, BanditDraws
from gameaikit.techniques import technique

#: Choose by the highest upper confidence bound [Auer et al. 2002].
UCB1 = "ucb1"
#: Choose the best mean, except with chance `epsilon` any arm at random.
EPSILON_GREEDY = "epsilon-greedy"
#: UCB1's constant, the square root of two: Auer, Cesa-Bianchi and Fischer's
#: bound for payoffs between 0 and 1 is `mean + sqrt(2 ln n / n_j)`.
EXPLORATION = math.sqrt(2.0)
#: How often epsilon-greedy explores, when nobody says.
EPSILON = 0.1


@technique("bandit", "which of a fixed set of options to try next, by what each has paid so far")
class Bandit:
    """Pulls and payoff sums per arm, and a policy that reads them."""

    def __init__(self, arms: int, policy: str = UCB1, exploration: float = EXPLORATION,
                 epsilon: float = EPSILON, seed: int = SEED_FOR_ZERO) -> None:
        self.policy = policy
        self.exploration = exploration
        self.epsilon = epsilon
        self.pulls = [0] * max(arms, 0)
        self.sums = [0.0] * max(arms, 0)
        self._draws = BanditDraws(seed)

    def problem(self) -> str:
        """What is wrong with the settings, or "" when nothing is."""
        if not self.pulls:
            return "a bandit needs at least one arm"
        if self.policy not in (UCB1, EPSILON_GREEDY):
            return f"the policy is {UCB1!r} or {EPSILON_GREEDY!r}, not {self.policy!r}"
        if self.exploration < 0.0:
            return f"the exploration constant is 0 or more, and is {self.exploration}"
        if not 0.0 <= self.epsilon <= 1.0:
            return f"epsilon is a chance, between 0 and 1, and is {self.epsilon}"
        return ""

    def total(self) -> int:
        """How many pulls, of every arm."""
        return sum(self.pulls)

    def mean(self, arm: int) -> float:
        """The arm's mean payoff, computed when read; 0 before its first pull."""
        if self.pulls[arm] == 0:
            return 0.0
        return self.sums[arm] / self.pulls[arm]

    def bound(self, arm: int) -> float:
        """UCB1's bound: the mean plus the exploration term; infinite untried."""
        if self.pulls[arm] == 0:
            return math.inf
        return self.mean(arm) + self.exploration * math.sqrt(math.log(self.total()) / self.pulls[arm])

    def choose(self) -> int:
        """The arm to pull next, by the policy. Changes nothing but the draws."""
        untried = self._first_untried()
        if untried >= 0:
            return untried
        if len(self.pulls) == 1:
            return 0
        if self.policy == UCB1:
            return self._highest(self.bound)
        if self._draws.uniform() < self.epsilon:
            return self._draws.index(len(self.pulls))
        return self._highest(self.mean)

    def reward(self, arm: int, payoff: float) -> None:
        """Count one pull of `arm` and add what it paid, kept to [0, 1]."""
        self.pulls[arm] += 1
        self.sums[arm] += min(max(payoff, 0.0), 1.0)

    def _first_untried(self) -> int:
        """The first arm never pulled, or -1 when every one has been."""
        for arm, pulled in enumerate(self.pulls):
            if pulled == 0:
                return arm
        return -1

    def _highest(self, score: Callable[[int], float]) -> int:
        """The arm with the highest score; of equal ones, the first."""
        best = 0
        for arm in range(1, len(self.pulls)):
            if score(arm) > score(best):
                best = arm
        return best
