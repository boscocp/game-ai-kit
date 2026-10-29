"""A finite Markov decision process, written out as a table.

AIMA (4th ed., 17.1) defines an MDP by its states, the actions in each,
a transition model P(s' | s, a), a reward R(s, a, s') and a discount
gamma. Here all of that is one table: for each state and each action, the
list of what can happen -- each outcome a probability, the reward paid on
the way, and the state it leads to, or `TERMINAL` when the episode ends
there. A terminal outcome is worth its reward and nothing after it.

The table is built once, from a function that says what an action does,
because the solvers sweep it hundreds of times and a function call per
outcome per sweep is most of the cost in pure Python. States are numbered
in the order they are given, and every solver works on the numbers.

When not to use it: a model too large to list -- a state for every
position of a real game. Then the states are sampled or approximated
(AIMA 22), which is learning, and that is another lesson.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Hashable, Sequence

#: Where an outcome leads when the episode ends with it.
TERMINAL = -1
#: How far the probabilities of one action may stray from summing to 1.
SUM_TOLERANCE = 1e-9

#: One outcome of an action: (probability, reward, the next state's number or TERMINAL).
Outcome = tuple[float, float, int]
#: What an action does, before the states are numbered: (probability, reward, next state or None).
Described = tuple[float, float, Hashable | None]


@dataclass
class FiniteMdp:
    """States, actions, the outcomes of each action in each state, and the discount."""

    states: list[Hashable]
    actions: tuple[str, ...]
    outcomes: list[list[list[Outcome]]]
    discount: float
    numbers: dict[Hashable, int]

    @classmethod
    def from_model(cls, states: Sequence[Hashable], actions: Sequence[str],
                   transition: Callable[[Hashable, str], list[Described]], discount: float) -> "FiniteMdp":
        """Number the states and ask `transition` what every action does in each.

        `transition(state, action)` returns the outcomes, each a probability,
        a reward and the next state -- None when the episode ends. A next
        state not among `states` is an error: the model would leak value.
        """
        number = {state: index for index, state in enumerate(states)}
        table = []
        for state in states:
            row = []
            for action in actions:
                described = transition(state, action)
                _check_probabilities(state, action, described)
                row.append([(probability, reward, TERMINAL if after is None else number[after])
                            for probability, reward, after in described])
            table.append(row)
        return cls(list(states), tuple(actions), table, discount, number)

    def number_of(self, state: Hashable) -> int:
        """The number the solvers know `state` by."""
        return self.numbers[state]


def _check_probabilities(state: Hashable, action: str, described: list[Described]) -> None:
    total = sum(probability for probability, _, _ in described)
    if abs(total - 1.0) > SUM_TOLERANCE:
        raise ValueError(f"{action!r} in {state!r}: probabilities sum to {total}, not 1")
