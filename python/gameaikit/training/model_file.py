"""The model file: what Python publishes and the game's `ModelFile` reads.

A JSON object whose `models` maps a name to `kind`, `features`, `weights`
and `bias` -- one weight per feature, applying to raw game numbers. That is
the whole format, and it belongs to no game. Anything else at the top level
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

from .models import PREDICTORS, Model

#: The fields every published model carries.
MODEL_FIELDS = ("kind", "features", "weights", "bias")


def as_json(models: dict[str, Model], generated_by: str, **fields: object) -> dict:
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
    """One model: an object, every field there, and every number a number."""
    if not isinstance(entry, dict):
        return f"M10 model `{name}` is not an object"
    for field in MODEL_FIELDS:
        if field not in entry:
            return f"M4 model `{name}` has no `{field}`"
    if str(entry["kind"]) not in PREDICTORS:
        return f"M5 model `{name}` is of kind `{entry['kind']}`, which nothing here can evaluate"
    features = _why_features_are_wrong(name, entry["features"])
    if features:
        return features
    weights = entry["weights"]
    if not isinstance(weights, list) or len(weights) != len(entry["features"]):
        count = len(weights) if isinstance(weights, list) else "no"
        return f"M7 model `{name}` has {count} weights for {len(entry['features'])} features"
    for number in [*weights, entry["bias"]]:
        if not _is_a_number(number):
            return f"M8 model `{name}` publishes {json.dumps(number)}, which is not a finite number"
    return ""


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
