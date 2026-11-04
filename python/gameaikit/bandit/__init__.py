"""A bandit: which of a fixed set of options to try next, by its payoffs so far.

The Python half of `godot/addons/ai_bandit/` (T99), written again so the
conformance vectors in `spec/vectors/bandit/` can hold the two languages to
the same choices, and so a regret curve can be measured with no engine. It
is not run here and published: the game counts during the fight (ADR 0016,
amended 2026-10-26). This copy exists to be checked, and read beside the
other one.

    bandit.py   UCB1 and epsilon-greedy over pulls and payoff sums, drawing
                from `gameaikit.core`'s seeded generator
"""

from gameaikit.bandit.bandit import EPSILON, EPSILON_GREEDY, EXPLORATION, UCB1, Bandit

__all__ = ["EPSILON", "EPSILON_GREEDY", "EXPLORATION", "UCB1", "Bandit"]
