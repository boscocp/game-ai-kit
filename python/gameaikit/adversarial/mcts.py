"""Monte Carlo tree search, as `ai_adversarial/mcts.gd` searches.

Read the Godot file for the why: AIMA's four phases (section 5.4, figure
5.11), UCB1 as the selection policy, one child per outcome drawn. This file
makes the same choices in the same order -- the same draws from the same
`Xorshift`, the same tie-breaks -- because `spec/vectors/adversarial/` holds
the two to the same visit counts, and one draw out of place moves them all.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any

from gameaikit.adversarial.game import AdversarialGame
from gameaikit.adversarial.xorshift import Xorshift
from gameaikit.techniques import technique

#: UCB1's exploration constant, the square root of two.
EXPLORATION = math.sqrt(2.0)
#: How many moves a playout plays before it stops and asks `evaluate`.
PLAYOUT_LIMIT = 200


class TreeNode:
    """A position in the tree: its state, whose turn, a branch per action."""

    def __init__(self, game: AdversarialGame, state: Any) -> None:
        self.state = state
        self.player = game.to_move(state)
        self.actions = list(game.actions(state))
        self.terminal = game.is_terminal(state) or not self.actions
        self.branches: list[Branch | None] = [None] * len(self.actions)
        self.untried = list(range(len(self.actions)))
        self.visits = 0


class Branch:
    """One action from a node: its playouts, their total, a child per outcome."""

    def __init__(self, action: Any, player: int, outcomes: list[tuple[float, Any]]) -> None:
        self.action = action
        self.player = player
        self.outcomes = outcomes
        self.children: list[TreeNode | None] = [None] * len(outcomes)
        self.visits = 0
        self.total = 0.0


@dataclass
class Descent:
    """The nodes one iteration passed, and the branches between them."""

    nodes: list[TreeNode] = field(default_factory=list)
    branches: list[Branch] = field(default_factory=list)


@dataclass
class MctsResult:
    """Where the search stands: the most visited move, every root move's numbers."""

    action: Any = None
    considered: list[dict] = field(default_factory=list)
    iterations: int = 0


@technique("monte-carlo-tree-search", "UCT over a game: the move whose random play-outs win most, within a budget")
class MonteCarloSearch:
    """UCT over an `AdversarialGame`, run a bounded number of iterations at a time."""

    def __init__(self, game: AdversarialGame, state: Any, from_seed: int = 1,
                 exploration: float = EXPLORATION, playout_limit: int = PLAYOUT_LIMIT) -> None:
        self._game = game
        self._root = TreeNode(game, state)
        self._random = Xorshift(from_seed)
        self._exploration = exploration
        self._playout_limit = max(playout_limit, 0)
        self._iterations = 0

    def step(self, iterations: int) -> MctsResult:
        """Run `iterations` more iterations; the tree carries over to the next call."""
        if not self._root.terminal:
            for _ in range(max(iterations, 0)):
                self._iterate()
        return self.result()

    def result(self) -> MctsResult:
        """The most visited root move, of equals the first, and every move's numbers."""
        found = MctsResult(iterations=self._iterations)
        most_visits = -1
        for index in range(len(self._root.actions)):
            entry = self._entry_for(index)
            found.considered.append(entry)
            if entry["visits"] > most_visits:
                most_visits = entry["visits"]
                found.action = entry["action"]
        return found

    def _iterate(self) -> None:
        """One iteration: the loop body of the book's figure 5.11."""
        descent = Descent()
        leaf = self._select(descent)
        child = self._expand(leaf, descent)
        final_state = self._simulate(child.state)
        self._back_propagate(final_state, descent)
        self._iterations += 1

    def _select(self, descent: Descent) -> TreeNode:
        """Follow the highest UCB1 bound while every action has been tried."""
        node = self._root
        descent.nodes.append(node)
        while not node.terminal and not node.untried:
            branch = self._best_by_ucb1(node)
            descent.branches.append(branch)
            node = self._child_by_chance(branch)
            descent.nodes.append(node)
        return node

    def _expand(self, leaf: TreeNode, descent: Descent) -> TreeNode:
        """Try one untried action, drawn among them, and add the node it leads to."""
        if leaf.terminal:
            return leaf
        index = leaf.untried.pop(self._random.index(len(leaf.untried)))
        action = leaf.actions[index]
        branch = Branch(action, leaf.player, self._game.outcomes(leaf.state, action))
        leaf.branches[index] = branch
        descent.branches.append(branch)
        child = self._child_by_chance(branch)
        descent.nodes.append(child)
        return child

    def _simulate(self, state: Any) -> Any:
        """Random moves and random outcomes to the end or to the playout limit."""
        played = 0
        while played < self._playout_limit and not self._game.is_terminal(state):
            actions = self._game.actions(state)
            if not actions:
                break
            action = actions[self._random.index(len(actions))]
            outcomes = self._game.outcomes(state, action)
            state = outcomes[self._draw_outcome(outcomes)][1]
            played += 1
        return state

    def _back_propagate(self, final_state: Any, descent: Descent) -> None:
        """A visit to every node passed; the value, per chooser, to every branch."""
        value_for: dict[int, float] = {}
        for node in descent.nodes:
            node.visits += 1
        for branch in descent.branches:
            if branch.player not in value_for:
                value_for[branch.player] = self._game.evaluate(final_state, branch.player)
            branch.visits += 1
            branch.total += value_for[branch.player]

    def _best_by_ucb1(self, node: TreeNode) -> Branch:
        """The highest bound; of equal bounds, the first in the game's order."""
        best, best_bound = None, -math.inf
        for branch in node.branches:
            bound = self._ucb1(branch, node.visits)
            if bound > best_bound:
                best, best_bound = branch, bound
        return best

    def _ucb1(self, branch: Branch, parent_visits: int) -> float:
        """The branch's mean plus the bonus for being little tried."""
        if branch.visits == 0:
            return math.inf
        mean = branch.total / branch.visits
        return mean + self._exploration * math.sqrt(math.log(float(parent_visits)) / branch.visits)

    def _child_by_chance(self, branch: Branch) -> TreeNode:
        """The child for the outcome drawn, made the first time it is drawn."""
        drawn = self._draw_outcome(branch.outcomes)
        if branch.children[drawn] is None:
            branch.children[drawn] = TreeNode(self._game, branch.outcomes[drawn][1])
        return branch.children[drawn]

    def _draw_outcome(self, outcomes: list[tuple[float, Any]]) -> int:
        """Which outcome happens; one outcome spends no draw."""
        if len(outcomes) <= 1:
            return 0
        drawn = self._random.uniform()
        reached = 0.0
        for index, (probability, _) in enumerate(outcomes):
            reached += float(probability)
            if drawn < reached:
                return index
        return len(outcomes) - 1

    def _entry_for(self, index: int) -> dict:
        """What `MctsResult.considered` says about the root's action at `index`."""
        branch = self._root.branches[index]
        if branch is None:
            return {"action": self._root.actions[index], "visits": 0, "mean": 0.0, "bound": math.inf}
        mean = branch.total / branch.visits if branch.visits > 0 else 0.0
        return {"action": branch.action, "visits": branch.visits, "mean": mean,
                "bound": self._ucb1(branch, self._root.visits)}
