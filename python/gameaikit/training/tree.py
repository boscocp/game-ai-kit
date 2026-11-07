"""A decision tree: fitted here by CART, walked in the game by `LearnedTree`.

A tree asks one question at a time -- "is the distance close?", "is the
health at most 2.5?" -- and goes left or right on the answer until it
reaches a leaf, which holds how often each answer was seen among the rows
that came the same way. Read aloud, the path is a rule a person can follow,
which is the reason to fit one rather than a weight per feature.

Fitting is CART (Breiman et al., 1984) with Gini impurity: at each node,
of every test the rows allow, take the one whose two sides are the least
mixed, and stop when no test makes them less mixed, when a side would hold
fewer than `min_leaf` rows, or at `max_depth`. The impurity is computed in
exact fractions, so two tests that split equally well are equal, and the
first in feature order wins -- the same tree on every machine.

A value is a word or a number. A word is tested by equality (`is`), a
number by a threshold (`at_most`, halfway between two values the rows
hold). A value of the wrong kind, or none, stops the walk: the tree cannot
read that row, and says so with an empty leaf rather than a guess.

Complexity: fitting is rows x candidate tests per node, per level; a walk is
one comparison per level, so its cost is the depth.

When not to use it: alone, deep, on few rows -- it overfits, learning the
rows rather than the player (docs/concepts/learning.md#a-decision-tree
measures it). Many trees voting (a random forest, T114) is the usual answer; so is a
cap on the depth.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from fractions import Fraction

#: The kind a tree is published as, in a model file beside `logistic`.
KIND = "tree"

#: A row's values, by feature name: words or numbers.
Situation = dict[str, object]

#: A row: its situation and the answer that was given in it.
Row = tuple[Situation, str]


def is_number(value: object) -> bool:
    """An int or a float, and not a bool, which Python counts as an int."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


@dataclass(frozen=True)
class Test:
    """One question: is `feature` the word `value`, or at most the number `value`?"""

    feature: str
    value: str | float
    numeric: bool

    def answer(self, situation: Situation) -> bool | None:
        """Yes or no for this situation; None when it holds no readable value."""
        seen = situation.get(self.feature)
        if self.numeric:
            return seen <= self.value if is_number(seen) else None
        return seen == self.value if isinstance(seen, str) else None

    def as_node(self, yes: int, no: int) -> dict:
        """The test as the file writes it, pointing at its two children."""
        key = "at_most" if self.numeric else "is"
        return {"feature": self.feature, key: self.value, "yes": yes, "no": no}


def counts_of(rows: list[Row], classes: list[str]) -> dict[str, int]:
    """How often each answer was given among `rows`, in `classes` order, zeros left out."""
    counted = {answer: 0 for answer in classes}
    for _, answer in rows:
        counted[answer] += 1
    return {answer: count for answer, count in counted.items() if count}


def impurity(rows: list[Row], classes: list[str]) -> Fraction:
    """Gini impurity times the number of rows: n - (sum of each count squared) / n.

    Scaled by n so the impurity of a split is simply the sum of its two
    sides', with no division to round; zero for a side that is all one answer.
    """
    if not rows:
        return Fraction(0)
    squares = sum(count * count for count in counts_of(rows, classes).values())
    return len(rows) - Fraction(squares, len(rows))


def candidate_tests(rows: list[Row], feature: str) -> list[Test]:
    """Every test on `feature` the rows allow, in a fixed order.

    Words: one `is` per word seen, sorted. Numbers: one `at_most` halfway
    between each two neighbouring values seen. A feature whose values are
    not all words or all numbers offers no test at all.
    """
    values = [situation.get(feature) for situation, _ in rows]
    if values and all(isinstance(value, str) for value in values):
        return [Test(feature, word, False) for word in sorted(set(values))]
    if values and all(is_number(value) for value in values):
        seen = sorted(set(values))
        return [Test(feature, (low + high) / 2, True) for low, high in zip(seen, seen[1:])]
    return []


def best_test(rows: list[Row], features: list[str], classes: list[str], min_leaf: int) -> Test | None:
    """The test that leaves the two sides least mixed, or None when none helps.

    Public, and given its features, so an ensemble can ask it about a subset
    at each node (T114's random forest does). Of equal tests the first in
    `features` order wins; a test must make the rows strictly purer, and
    leave at least `min_leaf` rows on each side.
    """
    best, lowest = None, impurity(rows, classes)
    for feature in features:
        for test in candidate_tests(rows, feature):
            yes = [row for row in rows if test.answer(row[0])]
            no = [row for row in rows if not test.answer(row[0])]
            if len(yes) < min_leaf or len(no) < min_leaf:
                continue
            split = impurity(yes, classes) + impurity(no, classes)
            if split < lowest:
                best, lowest = test, split
    return best


@dataclass
class Tree:
    """A fitted tree: its features, its answers and its nodes, root first."""

    features: list[str]
    classes: list[str]
    nodes: list[dict]

    def walk(self, situation: Situation) -> list[int]:
        """The nodes visited, root first; it ends at a leaf, or at the test that could not be read."""
        visited, index = [], 0
        while True:
            visited.append(index)
            node = self.nodes[index]
            if "counts" in node:
                return visited
            answer = test_of(node).answer(situation)
            if answer is None:
                return visited
            index = node["yes"] if answer else node["no"]

    def counts(self, situation: Situation) -> dict[str, int]:
        """The leaf's counts for this situation; empty when the walk stopped short."""
        return dict(self.nodes[self.walk(situation)[-1]].get("counts", {}))

    def likeliest(self, situation: Situation) -> str:
        """The answer the leaf saw most; of equal ones, the first in `classes`; "" when unread."""
        counts = self.counts(situation)
        best = ""
        for answer in self.classes:
            if counts.get(answer, 0) > counts.get(best, 0):
                best = answer
        return best

    def probabilities(self, situation: Situation) -> dict[str, float]:
        """Each answer's share of the leaf; empty when the walk stopped short."""
        counts = self.counts(situation)
        total = sum(counts.values())
        return {answer: counts.get(answer, 0) / total for answer in self.classes} if total else {}

    def depth(self) -> int:
        """The most tests on any path from the root to a leaf."""
        return _depth_below(self.nodes, 0)

    def leaves(self) -> int:
        """How many leaves: the number of rules the tree is."""
        return sum(1 for node in self.nodes if "counts" in node)

    def to_dict(self) -> dict:
        """The model as a model file publishes it, beside `logistic` and `linear`."""
        return {"kind": KIND, "features": list(self.features), "classes": list(self.classes),
                "nodes": [dict(node) for node in self.nodes]}


def test_of(node: dict) -> Test:
    """The test a published node asks."""
    if "at_most" in node:
        return Test(node["feature"], node["at_most"], True)
    return Test(node["feature"], node["is"], False)


def _depth_below(nodes: list[dict], index: int) -> int:
    """The depth of the subtree rooted at `index`."""
    node = nodes[index]
    if "counts" in node:
        return 0
    return 1 + max(_depth_below(nodes, node["yes"]), _depth_below(nodes, node["no"]))


#: How a node chooses its test: rows, features, classes, min_leaf -> a test or None.
Chooser = Callable[[list[Row], list[str], list[str], int], "Test | None"]


def fit(rows: list[Row], features: list[str], classes: list[str], max_depth: int, min_leaf: int,
        choose: Chooser = best_test) -> Tree:
    """A tree fitted to `rows` by CART: deterministic, the same tree for the same rows.

    `choose` picks each node's test; the default is `best_test` over every
    feature. An ensemble passes its own -- one that looks at a random subset
    of the features -- and gets the rest of the fitting unchanged.
    """
    if not rows:
        raise ValueError("a tree needs at least one row to fit")
    nodes: list[dict] = []
    _grow(rows, features, classes, max_depth, min_leaf, choose, nodes, 0)
    return Tree(list(features), list(classes), nodes)


def _grow(rows: list[Row], features: list[str], classes: list[str], max_depth: int, min_leaf: int,
          choose: Chooser, nodes: list[dict], depth: int) -> int:
    """Add the subtree for `rows` to `nodes`, root first, and return the root's index.

    Root first means every child sits after its parent in the list, which
    is what lets the game refuse a file whose children point backwards: a
    walk can then never loop.
    """
    index = len(nodes)
    nodes.append({})
    test = choose(rows, features, classes, min_leaf) if depth < max_depth else None
    if test is None:
        nodes[index] = {"counts": counts_of(rows, classes)}
        return index
    yes_rows = [row for row in rows if test.answer(row[0])]
    no_rows = [row for row in rows if not test.answer(row[0])]
    yes = _grow(yes_rows, features, classes, max_depth, min_leaf, choose, nodes, depth + 1)
    no = _grow(no_rows, features, classes, max_depth, min_leaf, choose, nodes, depth + 1)
    nodes[index] = test.as_node(yes, no)
    return index


def from_dict(entry: dict) -> Tree:
    """A published tree, read back: the file is assumed sound (`model_file.why_wrong` says)."""
    nodes = []
    for node in entry["nodes"]:
        read = dict(node)
        for key in ("yes", "no"):
            if key in read:
                read[key] = int(read[key])
        if "counts" in read:
            read["counts"] = {answer: int(count) for answer, count in read["counts"].items()}
        nodes.append(read)
    return Tree(list(entry["features"]), list(entry["classes"]), nodes)
