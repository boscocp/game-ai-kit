#!/usr/bin/env python3
"""Write the story sifting vectors, by a method the sifters do not use.

`StorySifter` searches depth first, an event at a time, binding variables
as it goes. This script imports nothing from the repository and tries every
ordered choice of distinct events instead -- `itertools.permutations` of the
record's places, k at a time -- and keeps a choice when every event has the
fields its clause names, every variable has one value across the choice,
every `before` pair is in order, and no `unless` event lies between its
bounds. Permutations come in lexicographic order, which is the order the
sifters promise. A refused pattern's rule is declared by hand below, from
the README's list.

    python3 spec/vectors/sifting/derive.py          # rewrite the vectors
    python3 spec/vectors/sifting/derive.py --check  # fail if one would change
"""

from __future__ import annotations

import itertools
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent


def deed(day, verb, place):
    return {"day": day, "kind": "deed", "verb": verb, "place": place}


def night(day, place, fact, value):
    return {"day": day, "kind": "night", "place": place, "fact": fact, "value": value}


#: A small valley's record, shared by most vectors: two burnings of the
#: barn with a repair between, the market's bread failing after the first
#: burning, and the bridge pulled down four times -- so "the third time"
#: has three triples to refuse besides the one it keeps.
VALLEY = [
    deed(1, "burn", "barn"),            # 0
    night(2, "market", "bread", False),  # 1
    deed(3, "repair", "barn"),          # 2
    night(4, "market", "bread", True),   # 3
    deed(5, "pull_down", "bridge"),     # 4
    deed(6, "repair", "bridge"),        # 5
    deed(7, "burn", "barn"),            # 6
    deed(8, "pull_down", "bridge"),     # 7
    deed(9, "repair", "bridge"),        # 8
    deed(10, "pull_down", "bridge"),    # 9
    deed(11, "repair", "bridge"),       # 10
    deed(12, "pull_down", "bridge"),    # 11
]


def _kind(value):
    if isinstance(value, bool):
        return "flag"
    if isinstance(value, (int, float)):
        return "number"
    return "text" if isinstance(value, str) else ""


def _same(first, second):
    return _kind(first) != "" and _kind(first) == _kind(second) and first == second


def _fits(event, where, values):
    """Whether `event` has `where`'s fields; each variable's value is added to `values`."""
    if not isinstance(event, dict):
        return False
    for field, wanted in where.items():
        if field not in event:
            return False
        if isinstance(wanted, str) and wanted.startswith("?"):
            values.setdefault(wanted[1:], []).append(event[field])
        elif not _same(event[field], wanted):
            return False
    return True


def _one_value_each(values):
    return all(all(_same(seen[0], other) for other in seen) for seen in values.values())


def _absent_found(events, pattern, places, bindings):
    for clause in pattern.get("unless", []):
        first = places[clause["after"]] + 1 if "after" in clause else 0
        last = places[clause["before"]] if "before" in clause else len(events)
        for index in range(first, last):
            if index in places.values():
                continue
            values = {name: [value] for name, value in bindings.items()}
            if _fits(events[index], clause["where"], values) and _one_value_each(values):
                return True
    return False


def matches(events, pattern):
    """Every match, by trying every ordered choice of distinct events."""
    names = [clause["as"] for clause in pattern["find"]]
    found = []
    for choice in itertools.permutations(range(len(events)), len(names)):
        values = {}
        if not all(_fits(events[index], clause["where"], values) for index, clause in zip(choice, pattern["find"])):
            continue
        if not _one_value_each(values):
            continue
        places = dict(zip(names, choice))
        if any(places[first] >= places[second] for first, second in pattern.get("before", [])):
            continue
        bindings = {name: seen[0] for name, seen in values.items()}
        if not _absent_found(events, pattern, places, bindings):
            found.append({"events": places, "bindings": bindings})
    return found


def find(name, where):
    return {"as": name, "where": where}


BURNED_THEN_REBUILT = {
    "name": "rebuilt",
    "find": [find("burned", {"verb": "burn", "place": "?place"}), find("rebuilt", {"verb": "repair", "place": "?place"})],
    "before": [["burned", "rebuilt"]],
}

PULLED_DOWN_THEN_REPAIRED = {
    "name": "repaired",
    "find": [find("down", {"verb": "pull_down", "place": "?place"}),
             find("up", {"verb": "repair", "place": "?place"})],
    "before": [["down", "up"]],
}

CASES = {
    "one-event-every-match": ("Each burning is a match of its own.", VALLEY, {
        "name": "burned", "find": [find("burned", {"kind": "deed", "verb": "burn"})]}),
    "a-shared-variable-joins-two-events": ("A burning, then a repair of the same place.", VALLEY,
                                          BURNED_THEN_REBUILT),
    "without-before-both-orders": ("With no order asked, a repair before a burning matches too.", VALLEY, {
        "name": "both", "find": BURNED_THEN_REBUILT["find"]}),
    "every-later-repair": ("Each time the bridge came down, every repair after it.", VALLEY,
                           PULLED_DOWN_THEN_REPAIRED),
    "unless-between-keeps-the-next-one": ("Each time the bridge came down, only the repair that answered it.",
                                          VALLEY, {
        **PULLED_DOWN_THEN_REPAIRED,
        "unless": [{"where": {"verb": "repair", "place": "?place"}, "after": "down", "before": "up"}]}),
    "unless-after-never-again": ("A burning nobody repaired afterwards.", VALLEY, {
        "name": "never-rebuilt", "find": [find("burned", {"verb": "burn", "place": "?place"})],
        "unless": [{"where": {"verb": "repair", "place": "?place"}, "after": "burned"}]}),
    "the-third-time": ("The third time the same deed was done to the same place, and only the third.", VALLEY, {
        "name": "third-time",
        "find": [find("first", {"kind": "deed", "verb": "?verb", "place": "?place"}),
                 find("second", {"kind": "deed", "verb": "?verb", "place": "?place"}),
                 find("third", {"kind": "deed", "verb": "?verb", "place": "?place"})],
        "before": [["first", "second"], ["second", "third"]],
        "unless": [{"where": {"verb": "?verb", "place": "?place"}, "before": "first"},
                   {"where": {"verb": "?verb", "place": "?place"}, "after": "first", "before": "second"},
                   {"where": {"verb": "?verb", "place": "?place"}, "after": "second", "before": "third"}]}),
    "a-deed-and-what-followed": ("The market lost its bread, and the last deed before it.", VALLEY, {
        "name": "no-bread",
        "find": [find("done", {"kind": "deed", "verb": "?verb", "place": "?place"}),
                 find("lack", {"kind": "night", "place": "market", "fact": "bread", "value": False})],
        "before": [["done", "lack"]],
        "unless": [{"where": {"kind": "deed"}, "after": "done", "before": "lack"}]}),
    "nothing-matches-an-empty-list": ("Nobody dug a well: no match at all.", VALLEY, {
        "name": "well", "find": [find("dug", {"verb": "dig_well"})]}),
    "a-flag-is-not-a-number": ("`false` in the record is not `0` in the pattern, nor `1` true.", [
        night(1, "market", "bread", False), night(2, "market", "bread", True), {"day": 3, "value": 0},
        {"day": 4, "value": 1.0}], {
        "name": "zero", "find": [find("zero", {"value": 0})]}),
    "a-whole-number-is-one-number": ("Day 1 written 1 and 1.0 is the same day.", [
        {"day": 1, "verb": "burn"}, {"day": 1.0, "verb": "repair"}], {
        "name": "same-day", "find": [find("one", {"day": "?day", "verb": "burn"}),
                                     find("other", {"day": "?day", "verb": "repair"})]}),
    "a-missing-field-does-not-match": ("An event without the field a pattern names is not a match.", [
        {"day": 1}, {"day": 2, "verb": "burn"}, {"verb": "repair"}], {
        "name": "any-verb", "find": [find("done", {"verb": "?verb"})]}),
    "two-events-are-two-events": ("Two events to find never take the same event.", [
        deed(1, "burn", "barn"), deed(2, "burn", "mill")], {
        "name": "two-burnings", "find": [find("one", {"verb": "burn"}), find("other", {"verb": "burn"})]}),
}

#: Patterns each rule refuses, with the rule from the README.
REFUSED = {
    "refused-an-unknown-key": ("P1", {"name": "x", "find": [find("a", {})], "limit": 3}),
    "refused-nothing-to-find": ("P1", {"name": "x", "find": []}),
    "refused-one-name-twice": ("P2", {"name": "x", "find": [find("a", {}), find("a", {})]}),
    "refused-an-order-on-an-unknown-name": ("P3", {"name": "x", "find": [find("a", {})], "before": [["a", "b"]]}),
    "refused-an-unless-bound-to-nothing": ("P4", {"name": "x", "find": [find("a", {})],
                                                  "unless": [{"where": {}, "after": "b"}]}),
    "refused-a-list-as-a-value": ("P5", {"name": "x", "find": [find("a", {"place": ["barn", "mill"]})]}),
}


def vectors():
    """Every vector, by file name."""
    written = {}
    for name, (description, events, pattern) in CASES.items():
        written[name] = {"description": description, "events": events, "pattern": pattern, "refused": "",
                         "matches": matches(events, pattern)}
    for name, (rule, pattern) in REFUSED.items():
        written[name] = {"description": f"Refused by {rule}.", "events": VALLEY, "pattern": pattern,
                         "refused": rule, "matches": []}
    return written


def main(arguments):
    stale = []
    for name, vector in vectors().items():
        path = HERE / f"{name}.json"
        text = json.dumps(vector, indent=1) + "\n"
        if "--check" in arguments:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                stale.append(path.name)
        else:
            path.write_text(text, encoding="utf-8")
    for name in stale:
        print(f"derive: {name} would change")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
