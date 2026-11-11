"""The record of deeds, and a saved record's lines read back (T164).

A deed is `{day, verb, place}` and nothing else: the schema has no field
for a person (ADR 0025). The log is appended to and never edited, and its
deeds come in the order of their days. A deed is refused, by name, when it
has another key, an unknown verb, a place that is not the valley's, a verb
that does not act on that place, or a day before the last one kept.

A saved record is one JSON object a line: the header `{"version": 1}`,
then one deed a line. Godot's `ValleySave` writes it; this side only reads
lines, as the vectors give them.

    log = DeedLog(places, verbs)
    log.append({"day": 1, "verb": "burn", "place": "barn"})   # "" when kept
"""

from __future__ import annotations

import json

KEYS = ("day", "verb", "place")
VERSION = 1


def make(day: int, verb: str, place: str) -> dict:
    """A deed as the record keeps it."""
    return {"day": day, "verb": verb, "place": place}


class DeedLog:
    """The player's deeds, in order, each refused or kept as it comes."""

    def __init__(self, places: list[str], verbs: dict) -> None:
        self._places = list(places)
        self._verbs = verbs
        self._deeds: list[dict] = []

    def append(self, deed: dict) -> str:
        """Keep `deed` at the end, or say why not; "" when it was kept."""
        why = self.refusal(deed)
        if not why:
            self._deeds.append(make(int(deed["day"]), str(deed["verb"]), str(deed["place"])))
        return why

    def refusal(self, deed: dict) -> str:
        """Why `deed` cannot follow the deeds already kept, or ""."""
        for key in deed:
            if key not in KEYS:
                return (f"a deed has no key {key}: a deed is {{day, verb, place}}, "
                        "and none has a person as its target")
        for key in KEYS:
            if key not in deed:
                return f"a deed has no {key}"
        day = deed["day"]
        if not _whole(day) or day < 1:
            return f"day {day} is not a day of the game; days are counted from 1"
        if self._deeds and day < self._deeds[-1]["day"]:
            return (f"day {int(day)} comes after day {self._deeds[-1]['day']} in the record; "
                    "deeds are kept in the order they were done")
        return self._vocabulary_refusal(str(deed["verb"]), str(deed["place"]))

    def _vocabulary_refusal(self, verb: str, place: str) -> str:
        if verb not in self._verbs:
            return f"unknown verb {verb}"
        if place not in self._places:
            return f"{place} is not a place in the valley; a deed acts on a place"
        if place not in self._verbs[verb]:
            return f"{verb} does not act on the {place}"
        return ""

    def deeds(self) -> list[dict]:
        """Every deed kept, in order: copies, so the record cannot be changed through them."""
        return [dict(deed) for deed in self._deeds]

    def cut(self, day: int) -> DeedLog:
        """The record as it stood at the end of `day`: every deed done on it or before."""
        earlier = DeedLog(self._places, self._verbs)
        earlier._deeds = [dict(deed) for deed in self._deeds if deed["day"] <= day]
        return earlier


def read_lines(lines: list[str], log: DeedLog) -> str:
    """Read a saved record's lines into `log`; "" or why they were refused."""
    if not lines:
        return f'the record is empty; its first line must be the header {{"version": {VERSION}}}'
    why = header_refusal(lines[0])
    if why:
        return why
    for number, line in enumerate(lines[1:], start=2):
        deed = _parsed(line)
        if not isinstance(deed, dict):
            return f"line {number} is not a deed"
        why = log.append(deed)
        if why:
            return f"line {number}: {why}"
    return ""


def header_refusal(line: str) -> str:
    """Why `line` is not the header of a record this side reads, or ""."""
    header = _parsed(line)
    if not isinstance(header, dict) or "version" not in header:
        return f'the record has no version; its first line must be the header {{"version": {VERSION}}}'
    if len(header) != 1:
        return "the record's header holds more than its version"
    version = header["version"]
    if not _number(version) or version != VERSION:
        return f"the record is version {version}, and this game reads version {VERSION}"
    return ""


def _number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _whole(value: object) -> bool:
    return _number(value) and float(value).is_integer()


def _parsed(line: str) -> object:
    try:
        return json.loads(line)
    except json.JSONDecodeError:
        return None
