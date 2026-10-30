"""What will the player do next? Counts of what it did after what.

Read `godot/addons/ai_opponent/ngram_predictor.gd` for the why: order, the
additive smoothing, the decay. This file does the same arithmetic in the
same order, and `spec/vectors/ngram/` holds both to the same numbers.
"""

from __future__ import annotations

from gameaikit.techniques import technique

#: How a context is written: its actions, oldest first, joined by this.
JOINER = " > "


@technique("n-gram-prediction", "the opponent's next move, from what followed the last few it made")
class NGramPredictor:
    """A table of which action followed which context, smoothed and decaying."""

    def __init__(self, order: int, actions: list[str], decay: float = 1.0, prior: float = 1.0) -> None:
        self.order = order
        self.actions = list(actions)
        self.decay = decay
        self.prior = prior
        self._counts: dict[str, dict[str, float]] = {}
        self._recent: list[str] = []

    def problem(self) -> str:
        """What is wrong with the settings, or "" when nothing is."""
        if self.order < 1:
            return f"an n-gram's order is at least 1, and this one is {self.order}"
        if not self.actions:
            return "a predictor needs at least one action to predict"
        if not 0.0 < self.decay <= 1.0:
            return f"decay must be above 0 and at most 1, and is {self.decay}"
        if self.prior <= 0.0:
            return "prior must be above 0, or nothing could be said about a context never seen"
        return ""

    def observe(self, action: str) -> None:
        """Count `action` after the current context, then shift it into the next."""
        if action not in self.actions:
            return
        if len(self._recent) == self.order - 1:
            row = self._counts.setdefault(self.context(), {})
            for seen in row:
                row[seen] = row[seen] * self.decay
            row[action] = row.get(action, 0.0) + 1.0
        self._recent.append(action)
        if len(self._recent) > self.order - 1:
            self._recent.pop(0)

    def context(self) -> str:
        """The context the next action will be counted under."""
        return JOINER.join(self._recent)

    def probabilities(self) -> dict[str, float]:
        """Each action's smoothed chance of coming next; they sum to 1."""
        row = self._counts.get(self.context(), {}) if len(self._recent) == self.order - 1 else {}
        total = self.prior * len(self.actions)
        for seen in row:
            total += row[seen]
        return {action: (row.get(action, 0.0) + self.prior) / total for action in self.actions}

    def ceiling(self) -> float:
        """The surest any prediction can be, given how much a row can remember."""
        if self.decay >= 1.0:
            return 1.0
        remembered = 1.0 / (1.0 - self.decay)
        return (remembered + self.prior) / (remembered + self.prior * len(self.actions))

    def likeliest(self) -> str:
        """The likeliest next action; of equal ones, the first in `actions`."""
        chances = self.probabilities()
        best = self.actions[0]
        for action in self.actions:
            if chances[action] > chances[best]:
                best = action
        return best
