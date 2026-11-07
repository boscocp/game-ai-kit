"""A random forest: many decision trees, each fitted on its own sample, voting.

One tree fitted to a few rows learns those rows: move a handful of them and
its tests change, and so do its answers. That is variance, and a forest is
the textbook answer to it (Breiman, 2001). Each tree is fitted by CART, as
`tree.fit` fits one, with two differences that make the trees disagree:

- it sees a **bootstrap sample** -- as many rows as there are, drawn with
  replacement, so some rows come twice and about a third not at all;
- at each node it may test only a **random subset of the features** -- the
  square root of their number, rounded down -- so one strong feature cannot
  put itself at the root of every tree.

To answer, every tree walks the situation and votes its likeliest answer,
and the forest's answer is the one with the most votes; of equal tallies,
the first in `classes`. A tree whose walk stops at a value it cannot read
abstains, as a single tree answers nothing there.

Seeded with T109's `Xorshift`, drawn in a fixed order -- a tree's bootstrap,
then the subsets of its nodes as they are grown -- so the same rows and the
same seed give the same forest on every machine.

Complexity: fitting is a tree's cost times the number of trees; an answer is
one walk per tree, so it costs the trees times their depth.

When not to use it: when one tree's path is what the reader needs -- a
forest's reasons are a tally, not a rule anyone can read aloud -- and when
the features hold no signal. Averaging many guesses removes the noise in
them; it adds nothing that was not there (docs/concepts/learning.md#a-random-forest
measures both).
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from gameaikit.core.xorshift import Xorshift

from . import tree

#: The kind a forest is published as, in a model file beside `tree`.
KIND = "forest"


@dataclass
class Forest:
    """A fitted forest: its features, its answers, and its trees, which share them."""

    features: list[str]
    classes: list[str]
    trees: list[tree.Tree]

    def votes(self, situation: tree.Situation) -> list[str]:
        """Each tree's likeliest answer, in tree order; "" for a tree that abstains."""
        return [each.likeliest(situation) for each in self.trees]

    def tally(self, situation: tree.Situation) -> dict[str, int]:
        """How many trees voted for each answer, in `classes` order, zeros and abstentions left out."""
        cast = self.votes(situation)
        counted = {answer: cast.count(answer) for answer in self.classes}
        return {answer: count for answer, count in counted.items() if count}

    def likeliest(self, situation: tree.Situation) -> str:
        """The answer with the most votes; of equal tallies, the first in `classes`; "" when all abstain."""
        tally = self.tally(situation)
        best = ""
        for answer in self.classes:
            if tally.get(answer, 0) > tally.get(best, 0):
                best = answer
        return best

    def probabilities(self, situation: tree.Situation) -> dict[str, float]:
        """Each answer's share of the votes cast; empty when every tree abstained."""
        tally = self.tally(situation)
        total = sum(tally.values())
        return {answer: tally.get(answer, 0) / total for answer in self.classes} if total else {}

    def to_dict(self) -> dict:
        """The model as a model file publishes it: one list of nodes per tree."""
        return {"kind": KIND, "features": list(self.features), "classes": list(self.classes),
                "trees": [[dict(node) for node in each.nodes] for each in self.trees]}


def subset_size(features: list[str]) -> int:
    """How many features a node may look at: the square root of their number, at least one."""
    return max(1, math.isqrt(len(features)))


def bootstrap(rows: list[tree.Row], generator: Xorshift) -> list[tree.Row]:
    """As many rows as `rows` holds, each drawn from it at random, with replacement."""
    return [rows[generator.index(len(rows))] for _ in rows]


def subset_chooser(generator: Xorshift, size: int) -> tree.Chooser:
    """A node's chooser for `tree.fit`: `tree.best_test` over `size` features drawn at random.

    The features are drawn without replacement, then put back in their
    original order, so a tie between two of them still goes to the first in
    `features`, as it does in a single tree. When none of the drawn features
    helps, the node is a leaf: it does not draw again.
    """
    def choose(rows: list[tree.Row], features: list[str], classes: list[str], min_leaf: int) -> tree.Test | None:
        pool, drawn = list(features), []
        for _ in range(min(size, len(features))):
            drawn.append(pool.pop(generator.index(len(pool))))
        drawn.sort(key=features.index)
        return tree.best_test(rows, drawn, classes, min_leaf)
    return choose


def fit(rows: list[tree.Row], features: list[str], classes: list[str], trees: int, max_depth: int,
        min_leaf: int, seed: int) -> Forest:
    """`trees` trees, each fitted by CART on a bootstrap of `rows` with a subset of features per node.

    One generator, seeded once, draws everything in order, so the forest is
    the same for the same rows and seed.
    """
    if not rows:
        raise ValueError("a forest needs at least one row to fit")
    if trees < 1:
        raise ValueError("a forest needs at least one tree")
    generator = Xorshift(seed)
    choose = subset_chooser(generator, subset_size(features))
    grown = []
    for _ in range(trees):
        sample = bootstrap(rows, generator)
        grown.append(tree.fit(sample, features, classes, max_depth, min_leaf, choose))
    return Forest(list(features), list(classes), grown)


def from_dict(entry: dict) -> Forest:
    """A published forest, read back: the file is assumed sound (`model_file.why_wrong` says)."""
    trees = [tree.from_dict({"features": entry["features"], "classes": entry["classes"], "nodes": nodes})
             for nodes in entry["trees"]]
    return Forest(list(entry["features"]), list(entry["classes"]), trees)
