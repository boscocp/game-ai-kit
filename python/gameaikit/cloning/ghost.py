"""A ghost: what the recorded player did in each situation it met, counted.

Read `godot/addons/ai_learning/case_table.gd` for the why: exact lookup as
the published ghost papers do it, nearest-case lookup as Killer Instinct's
Shadows do. This is the same table, counted here from the training rows and
published for the game to read; and the same two lookups, so the held-out
rows can be scored without Godot.
"""

from __future__ import annotations

from collections import Counter

from .rows import Situation

#: How a key joins a situation's words, as the game joins them.
JOINER = " | "


class CaseTable:
    """Situation key to how many times each action was taken there."""

    def __init__(self, features: list[str], rows: list[tuple[Situation, str]]) -> None:
        self.features = list(features)
        self.cases: dict[str, Counter[str]] = {}
        for situation, action in rows:
            self.cases.setdefault(self.key_of(situation), Counter())[action] += 1

    def key_of(self, situation: Situation) -> str:
        """The key `situation` is filed under: its words, in feature order."""
        return JOINER.join(situation.get(feature, "") for feature in self.features)

    def exact(self, situation: Situation) -> Counter[str]:
        """What was done in exactly `situation`; empty if never met. A copy, so the table cannot be edited through it."""
        return Counter(self.cases.get(self.key_of(situation), Counter()))

    def nearest(self, situation: Situation) -> tuple[int, Counter[str]]:
        """How many features apart the nearest cases are, and their actions pooled."""
        words = self.key_of(situation).split(JOINER)
        closest, pooled = -1, Counter()
        for key, counts in self.cases.items():
            apart = sum(1 for mine, theirs in zip(words, key.split(JOINER)) if mine != theirs)
            if closest == -1 or apart < closest:
                closest, pooled = apart, Counter(counts)
            elif apart == closest:
                pooled.update(counts)
        return closest, pooled

    def everything(self) -> Counter[str]:
        """Every action taken anywhere: the exact ghost's answer to the unknown."""
        pooled: Counter[str] = Counter()
        for counts in self.cases.values():
            pooled.update(counts)
        return pooled

    def size(self) -> int:
        """How many numbers the table is: one count per case and action seen there."""
        return sum(len(counts) for counts in self.cases.values())

    def as_published(self) -> dict[str, dict[str, int]]:
        """The table as the game reads it, keys and actions sorted."""
        return {key: dict(sorted(self.cases[key].items())) for key in sorted(self.cases)}


def likeliest(counts: Counter[str], actions: list[str]) -> str:
    """The most often taken; of equal ones, the first in `actions`."""
    best = actions[0]
    for action in actions:
        if counts[action] > counts[best]:
            best = action
    return best
