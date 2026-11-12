"""Which moments of a record are worth telling: story sifting, as in Felt.

Read `godot/addons/ai_sifting/story_sifter.gd` and `sift_pattern.gd` for
the why: a pattern names events to find, joined by shared variables, in an
order, and events that must not be there; the sifter finds every place in
a record where it fits. This file does the same search in the same order,
and `spec/vectors/sifting/` holds both to the same matches.

It only reads: `sift` never writes into the record it is handed.
"""

from __future__ import annotations

import json
from typing import Any

from gameaikit.techniques import technique

#: The keys a pattern may have; `name` and `find` must be there.
KEYS = ("before", "find", "name", "unless")
#: The keys of an event to find, both required.
FIND_KEYS = ("as", "where")
#: The keys of an event that must not be there; only `where` is required.
UNLESS_KEYS = ("after", "before", "where")
#: What a variable starts with.
VARIABLE = "?"


def _kind(value: Any) -> str:
    """"text", "number" or "flag", or "" for anything else.

    `bool` is tested first because Python counts it as a number, and the
    Godot twin does not: `True` is not the same as `1` on either side.
    """
    if isinstance(value, bool):
        return "flag"
    if isinstance(value, (int, float)):
        return "number"
    if isinstance(value, str):
        return "text"
    return ""


def same(first: Any, second: Any) -> bool:
    """Whether two values are the same kind -- text, number, flag -- and equal."""
    return _kind(first) != "" and _kind(first) == _kind(second) and first == second


def is_variable(value: Any) -> bool:
    """Whether `value` is a variable: text that starts with `?`."""
    return isinstance(value, str) and value.startswith(VARIABLE)


def _shown(value: Any) -> str:
    return json.dumps(value)


def problem(pattern: dict) -> str:
    """Why `pattern` cannot be sifted for, or "" when it can; P1 to P5 first."""
    for key in pattern:
        if key not in KEYS:
            return f"P1 a pattern has no key {_shown(key)}"
    if not (isinstance(pattern.get("name"), str) and pattern["name"]):
        return "P1 a pattern needs a name"
    if not (isinstance(pattern.get("find"), list) and pattern["find"]):
        return "P1 a pattern needs at least one event to find"
    names: list[str] = []
    for clause in pattern["find"]:
        wrong = _find_problem(clause, names)
        if wrong:
            return wrong
        names.append(clause["as"])
    return _order_problem(pattern.get("before", []), names) or _unless_problem(pattern.get("unless", []), names)


def _find_problem(clause: Any, names: list[str]) -> str:
    if not (isinstance(clause, dict) and sorted(clause) == list(FIND_KEYS)):
        return f"P2 an event to find is {{as, where}}, not {_shown(clause)}"
    if not (isinstance(clause["as"], str) and clause["as"]):
        return "P2 an event to find needs a name in `as`"
    if clause["as"] in names:
        return f"P2 two events to find are both named {clause['as']}"
    return _where_problem(clause["where"])


def _order_problem(order: Any, names: list[str]) -> str:
    if not isinstance(order, list):
        return "P3 `before` is a list of pairs"
    for pair in order:
        if not (isinstance(pair, list) and len(pair) == 2):
            return f"P3 a pair in `before` is two names, not {_shown(pair)}"
        if not (str(pair[0]) in names and str(pair[1]) in names) or pair[0] == pair[1]:
            return f"P3 {_shown(pair)} does not name two different events to find"
    return ""


def _unless_problem(absent: Any, names: list[str]) -> str:
    if not isinstance(absent, list):
        return "P4 `unless` is a list"
    for clause in absent:
        if not (isinstance(clause, dict) and "where" in clause):
            return "P4 an event that must not be there needs a `where`"
        for key in clause:
            if key not in UNLESS_KEYS:
                return f"P4 an event that must not be there has no key {_shown(key)}"
        for bound in ("after", "before"):
            if bound in clause and str(clause[bound]) not in names:
                return f"P4 `{bound}` names no event to find: {_shown(clause[bound])}"
        wrong = _where_problem(clause["where"])
        if wrong:
            return wrong
    return ""


def _where_problem(where: Any) -> str:
    if not isinstance(where, dict):
        return f"P5 a `where` is a dictionary of fields, not {_shown(where)}"
    for field, value in where.items():
        if not _kind(value):
            return f"P5 the field {field} is {_shown(value)}: a value is text, a number or true or false"
    return ""


def bindings_if_matches(event: Any, where: dict, bound: dict) -> dict | None:
    """The bindings once `event` matches `where` given `bound`, or None. `bound` is not changed."""
    if not isinstance(event, dict):
        return None
    binds = dict(bound)
    for field, wanted in where.items():
        if field not in event:
            return None
        if is_variable(wanted):
            binds.setdefault(wanted[len(VARIABLE):], event[field])
            wanted = binds[wanted[len(VARIABLE):]]
        if not same(event[field], wanted):
            return None
    return binds


@technique("sifting", "which moments of a record of events are worth telling, by patterns matched over it")
class StorySifter:
    """Every match of a pattern in a record, with the events that made it."""

    def sift(self, events: list, pattern: dict) -> list[dict]:
        """Every match, `{"events": {name: index}, "bindings": {variable: value}}`, in order."""
        matches: list[dict] = []
        if problem(pattern):
            return matches
        self._extend(events, pattern, {}, {}, matches)
        return matches

    def _extend(self, events: list, pattern: dict, found: dict, bound: dict, matches: list[dict]) -> None:
        clauses = pattern["find"]
        if len(found) == len(clauses):
            if not self._absent_found(events, pattern, found, bound):
                matches.append({"events": dict(found), "bindings": dict(bound)})
            return
        clause = clauses[len(found)]
        for index, event in enumerate(events):
            if index in found.values():
                continue
            binds = bindings_if_matches(event, clause["where"], bound)
            if binds is None:
                continue
            found[clause["as"]] = index
            if self._in_order(pattern.get("before", []), found):
                self._extend(events, pattern, found, binds, matches)
            del found[clause["as"]]

    @staticmethod
    def _in_order(order: list, found: dict) -> bool:
        return all(not (first in found and second in found) or found[first] < found[second]
                   for first, second in order)

    @staticmethod
    def _absent_found(events: list, pattern: dict, found: dict, bound: dict) -> bool:
        for clause in pattern.get("unless", []):
            first = found[clause["after"]] + 1 if "after" in clause else 0
            last = found[clause["before"]] if "before" in clause else len(events)
            for index in range(first, last):
                if index not in found.values() and \
                        bindings_if_matches(events[index], clause["where"], bound) is not None:
                    return True
        return False
