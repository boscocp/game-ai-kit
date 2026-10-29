"""Value iteration and policy iteration, as AIMA writes them (4th ed., 17.2).

Both rest on one quantity, the Q-value: what taking `action` in `state`
is worth if every state after it is worth what `values` says --

    Q(s, a) = sum over outcomes of P(s' | s, a) [R(s, a, s') + gamma U(s')]

with U(s') = 0 when the outcome ends the episode.

**Value iteration** (17.2.1) applies the Bellman update to
every state, U'(s) = max_a Q(s, a), sweep after sweep, until no state's
value moves by more than epsilon (1 - gamma) / gamma in a sweep; then
the values are within epsilon of the true ones.

**Policy iteration** (17.2.2) keeps a policy instead. It
evaluates it -- here by sweeps of the simplified update U(s) =
Q(s, pi(s)), one action a state, to the same threshold, rather than
solving the linear equations exactly -- and then improves it, every state taking the action
with the best Q. When an improvement changes nothing, the policy is
optimal. Fewer improvements than value iteration has sweeps; much more
work inside each.

A policy is read off the values greedily, the first action in the MDP's
order winning a tie, so two solvers that agree on the values agree on the
policy.

Complexity: one sweep is O(states x actions x outcomes). Value iteration
takes about log(epsilon) / log(gamma) sweeps at worst; in a game whose
episodes end, far fewer.

When not to use it: a state space that cannot be listed, or a model
nobody can write down. Then the agent learns from play (AIMA 22), and that
is learning, which this kit does in Python only.
"""

from __future__ import annotations

from dataclasses import dataclass

from gameaikit.mdp.model import TERMINAL, FiniteMdp


@dataclass
class Solution:
    """What a solver found, and how much work it took to find it."""

    values: list[float]
    policy: list[int]
    sweeps: int
    backups: int
    improvements: int = 0


def q_value(mdp: FiniteMdp, values: list[float], state: int, action: int) -> float:
    """What `action` in `state` is worth, if the states after it are worth `values`."""
    worth = 0.0
    for probability, reward, after in mdp.outcomes[state][action]:
        future = 0.0 if after == TERMINAL else values[after]
        worth += probability * (reward + mdp.discount * future)
    return worth


def greedy(mdp: FiniteMdp, values: list[float], state: int) -> int:
    """The action with the best Q-value in `state`; the first in order on a tie."""
    best, best_worth = 0, q_value(mdp, values, state, 0)
    for action in range(1, len(mdp.actions)):
        worth = q_value(mdp, values, state, action)
        if worth > best_worth:
            best, best_worth = action, worth
    return best


def greedy_policy(mdp: FiniteMdp, values: list[float]) -> list[int]:
    """The greedy action in every state."""
    return [greedy(mdp, values, state) for state in range(len(mdp.states))]


def stopping_threshold(epsilon: float, discount: float) -> float:
    """The largest change in a sweep that still leaves the values within `epsilon` (AIMA 17.2.1)."""
    return epsilon * (1.0 - discount) / discount


def value_iteration(mdp: FiniteMdp, epsilon: float) -> Solution:
    """Bellman updates over every state until the values settle within `epsilon`."""
    threshold = stopping_threshold(epsilon, mdp.discount)
    values = [0.0] * len(mdp.states)
    sweeps = 0
    while True:
        updated = [max(q_value(mdp, values, state, action) for action in range(len(mdp.actions)))
                   for state in range(len(mdp.states))]
        change = max((abs(new - old) for new, old in zip(updated, values)), default=0.0)
        values = updated
        sweeps += 1
        if change <= threshold:
            break
    backups = sweeps * len(mdp.states) * len(mdp.actions)
    return Solution(values, greedy_policy(mdp, values), sweeps, backups)


def evaluate(mdp: FiniteMdp, policy: list[int], values: list[float], threshold: float) -> tuple[list[float], int]:
    """The values of following `policy`, by simplified Bellman updates from `values`.

    Returns the values and the sweeps it took.
    """
    sweeps = 0
    while True:
        updated = [q_value(mdp, values, state, policy[state]) for state in range(len(mdp.states))]
        change = max((abs(new - old) for new, old in zip(updated, values)), default=0.0)
        values = updated
        sweeps += 1
        if change <= threshold:
            return values, sweeps


def policy_iteration(mdp: FiniteMdp, epsilon: float) -> Solution:
    """Evaluate a policy, improve it, and stop when improving changes nothing.

    It starts from the first action everywhere. A state's action changes
    only when another is strictly better than the one it has, so ties
    cannot make it cycle.
    """
    threshold = stopping_threshold(epsilon, mdp.discount)
    policy = [0] * len(mdp.states)
    values = [0.0] * len(mdp.states)
    sweeps = backups = improvements = 0
    while True:
        values, evaluated = evaluate(mdp, policy, values, threshold)
        sweeps += evaluated + 1
        backups += (evaluated + len(mdp.actions)) * len(mdp.states)
        improvements += 1
        changed = False
        for state in range(len(mdp.states)):
            best = greedy(mdp, values, state)
            if q_value(mdp, values, state, best) > q_value(mdp, values, state, policy[state]):
                policy[state], changed = best, True
        if not changed:
            return Solution(values, policy, sweeps, backups, improvements)
