"""The model file: what Python publishes and the game's `ModelFile` reads.

A JSON object whose `models` maps a name to `kind`, `features`, `weights`
and `bias` -- one weight per feature, applying to raw game numbers -- or,
for a decision tree (`kind` "tree", T113), to `kind`, `features`, `classes`
and `nodes` -- or, for a random forest (`kind` "forest", T114), to `kind`,
`features`, `classes` and `trees`, one list of nodes per tree. That is the
whole format, and it belongs to no game. Anything else at the top level
is the publishing game's own (the tactical board's `feature_conventions`,
say), written here unread and checked by that game, on both sides.

The refusals are `ai_learning`'s, code for code: `why_wrong` names the first
rule a file breaks with the code `ModelFile` gives it, and the vectors in
`spec/vectors/model_file/` hold the two languages to the same answer.
"""

from __future__ import annotations

import json
import math
import pathlib

from . import forest, tree
from .models import PREDICTORS, Model

#: The fields every published model carries.
MODEL_FIELDS = ("kind", "features", "weights", "bias")
#: The fields a published tree carries instead.
TREE_FIELDS = ("kind", "features", "classes", "nodes")
#: The fields a published forest carries: its trees share its features and classes.
FOREST_FIELDS = ("kind", "features", "classes", "trees")
#: Every kind a file may publish: the weighted ones, the tree and the forest.
KINDS = (*PREDICTORS, tree.KIND, forest.KIND)
#: Which fields each kind must carry; the weighted kinds carry `MODEL_FIELDS`.
FIELDS_OF = {tree.KIND: TREE_FIELDS, forest.KIND: FOREST_FIELDS}


def as_json(models: dict[str, Model | tree.Tree | forest.Forest], generated_by: str, **fields: object) -> dict:
    """A model file: what wrote it, the game's own fields, then the models.

    In that order, so a person opening the file reads what it is before the
    numbers. `fields` go in as given: what they must hold is the game's rule.
    """
    return {
        "generated_by": generated_by,
        **fields,
        "models": {name: model.to_dict() for name, model in models.items()},
    }


def why_unreadable(path: pathlib.Path) -> str:
    """The first thing wrong with the file at `path`, or "" when it is sound."""
    if not path.is_file():
        return f"M1 no model file at {path}"
    return why_text_is_wrong(path.read_text(encoding="utf-8"), str(path))


def why_text_is_wrong(text: str, source: str) -> str:
    """The same, over a file's text already in hand."""
    try:
        data = json.loads(text, parse_constant=_not_json)
    except json.JSONDecodeError as problem:
        return f"M2 {source} is not JSON: {problem.msg}, at line {problem.lineno}"
    if not isinstance(data, dict):
        return f"M2 {source} is JSON, but not an object"
    return why_wrong(data)


def _not_json(word: str) -> float:
    """Refuse `NaN`, `Infinity` and `-Infinity`, which JSON does not have.

    Python's reader accepts them by default and the game's does not, so left
    alone the same file would be an M8 here and an M2 there.
    """
    raise json.JSONDecodeError(f"{word} is not a JSON value", word, 0)


def why_wrong(data: dict) -> str:
    """The first rule this content breaks, as the sentence to show, or ""."""
    models = data.get("models")
    if not isinstance(models, dict) or not models:
        return "M3 the file publishes no models"
    for name, entry in models.items():
        wrong = _why_model_is_wrong(name, entry)
        if wrong:
            return wrong
    return ""


def _why_model_is_wrong(name: str, entry: object) -> str:
    """One model: an object, a kind this reader knows, that kind's fields, sound values.

    The kind is read before the other fields, because which fields a model
    must have depends on it: a tree has no weights to miss.
    """
    if not isinstance(entry, dict):
        return f"M10 model `{name}` is not an object"
    if "kind" not in entry:
        return f"M4 model `{name}` has no `kind`"
    if str(entry["kind"]) not in KINDS:
        return f"M5 model `{name}` is of kind `{entry['kind']}`, which nothing here can evaluate"
    for field in FIELDS_OF.get(entry["kind"], MODEL_FIELDS):
        if field not in entry:
            return f"M4 model `{name}` has no `{field}`"
    features = _why_features_are_wrong(name, entry["features"])
    if features:
        return features
    if entry["kind"] == tree.KIND:
        return _why_tree_is_wrong(name, entry)
    if entry["kind"] == forest.KIND:
        return _why_forest_is_wrong(name, entry)
    weights = entry["weights"]
    if not isinstance(weights, list) or len(weights) != len(entry["features"]):
        count = len(weights) if isinstance(weights, list) else "no"
        return f"M7 model `{name}` has {count} weights for {len(entry['features'])} features"
    for number in [*weights, entry["bias"]]:
        if not _is_a_number(number):
            return f"M8 model `{name}` publishes {json.dumps(number)}, which is not a finite number"
    return ""


def _why_tree_is_wrong(name: str, entry: dict) -> str:
    """A tree: its answers named, then every node a sound test or leaf.

    The nodes are walked once, first to last, each checked whole before the
    next, so the first wrong node is the one reported, in both languages.
    """
    if not _are_distinct_words(entry["classes"]):
        return f"M11 tree `{name}` does not name its answers: `classes` must be distinct words"
    nodes = entry["nodes"]
    if not isinstance(nodes, list) or not nodes:
        return f"M12 tree `{name}` has no nodes"
    return _why_nodes_are_wrong(f"tree `{name}`", nodes, entry["features"], entry["classes"])


def _why_forest_is_wrong(name: str, entry: dict) -> str:
    """A forest: its answers named, at least one tree, and every tree's nodes as a tree's must be.

    The trees are checked first to last, and each tree's nodes first to
    last, so the first wrong node of the first wrong tree is the one reported.
    """
    if not _are_distinct_words(entry["classes"]):
        return f"M11 forest `{name}` does not name its answers: `classes` must be distinct words"
    trees = entry["trees"]
    if not isinstance(trees, list) or not trees:
        return f"M16 forest `{name}` has no trees"
    for number, nodes in enumerate(trees):
        if not isinstance(nodes, list) or not nodes:
            return f"M16 forest `{name}` tree {number} has no nodes"
        wrong = _why_nodes_are_wrong(f"forest `{name}` tree {number}", nodes, entry["features"], entry["classes"])
        if wrong:
            return wrong
    return ""


def _are_distinct_words(classes: object) -> bool:
    """A non-empty list of words, none of them twice: what `classes` must be."""
    return isinstance(classes, list) and bool(classes) and all(isinstance(answer, str) for answer in classes) \
        and len(set(classes)) == len(classes)


def _why_nodes_are_wrong(owner: str, nodes: list, features: list, classes: list) -> str:
    """One tree's nodes, first to last, each checked whole before the next."""
    for index, node in enumerate(nodes):
        wrong = _why_node_is_wrong(f"{owner} node {index}", index, node, features, classes, len(nodes))
        if wrong:
            return wrong
    return ""


def _why_node_is_wrong(where: str, index: int, node: object, features: list, classes: list, size: int) -> str:
    """One node: a leaf with sound counts, or a test on a known feature pointing forwards.

    Forwards only -- every child after its parent -- is what makes a walk
    end: a file whose children point back could send it round for ever.
    """
    if not isinstance(node, dict) or ("counts" in node) == ("feature" in node):
        return f"M12 {where} is neither a test nor a leaf"
    if "counts" in node:
        return _why_counts_are_wrong(where, node["counts"], classes)
    if ("is" in node) == ("at_most" in node) or "yes" not in node or "no" not in node:
        return f"M12 {where} is a test without one `is` or `at_most`, and a `yes` and a `no`"
    if node["feature"] not in features:
        return f"M13 {where} asks about {json.dumps(node['feature'])}, which is not among its features"
    if "is" in node and not isinstance(node["is"], str):
        return f"M13 {where} compares with {json.dumps(node['is'])}, which is not a word"
    if "at_most" in node and not _is_a_number(node["at_most"]):
        return f"M13 {where} compares with {json.dumps(node['at_most'])}, which is not a finite number"
    for child in (node["yes"], node["no"]):
        if not _is_whole(child) or not index < child < size:
            return f"M14 {where} points at {json.dumps(child)}, which is not a later node"
    return ""


def _why_counts_are_wrong(where: str, counts: object, classes: list) -> str:
    """A leaf's counts: answers the tree names, whole numbers, and at least one row."""
    if not isinstance(counts, dict) or not counts:
        return f"M15 {where} counts nothing"
    for answer, count in counts.items():
        if answer not in classes:
            return f"M15 {where} counts {json.dumps(answer)}, which is not among its classes"
        if not _is_whole(count) or count < 0:
            return f"M15 {where} counts {json.dumps(count)}, which is not a whole number of rows"
    if sum(counts.values()) == 0:
        return f"M15 {where} counts nothing"
    return ""


def _is_whole(value: object) -> bool:
    """A finite number with nothing after the point: a count, or an index into the nodes."""
    return _is_a_number(value) and float(value).is_integer()


def _why_features_are_wrong(name: str, given: object) -> str:
    """The feature names: a non-empty list of distinct strings."""
    if not isinstance(given, list) or not given:
        return f"M6 model `{name}` lists no features"
    # One walk, each name checked in turn, in the game's order: the first
    # name that is wrong is the one reported, in both languages.
    seen = set()
    for feature in given:
        if not isinstance(feature, str):
            return f"M6 model `{name}` has a feature name that is not a string"
        if feature in seen:
            return f"M6 model `{name}` lists the feature `{feature}` twice"
        seen.add(feature)
    return ""


def _is_a_number(value: object) -> bool:
    """A finite int or float -- and not a bool, which Python counts as an int.

    The bool is the half the GDScript side gets for free: its JSON reader
    hands `true` over as a bool, never a number, and a file one language
    refuses the other must refuse too.
    """
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    # An integer too big for a float -- `1` and four hundred zeros -- is one
    # Python keeps exactly and the game reads as infinity. `math.isfinite`
    # raises on it rather than answering, so it is converted first.
    try:
        return math.isfinite(float(value))
    except OverflowError:
        return False
