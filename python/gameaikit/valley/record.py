"""The record of deeds, and a saved record's lines read back (T164).

A deed is `{day, verb, place}` and nothing else: the schema has no field
for a person (ADR 0025). The log is appended to and never edited, and its
deeds come in the order of their days. A deed is refused, by name, when it
has another key, an unknown verb, a place that is not the valley's, a verb
that does not act on that place, or a day before the last one kept.

A saved record is one JSON object a line: the header `{"version": 1}`,
then one deed a line, each ending in a newline. Godot's `ValleySave`
writes it; this side reads a file's text or its lines, as the vectors
give them, and says whether a deed may be appended to a text.

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
                return (f"a deed has no key {shown(key)}: a deed is {{day, verb, place}}, "
                        "and none has a person as its target")
        for key in KEYS:
            if key not in deed:
                return f"a deed has no {key}"
        day = deed["day"]
        if not _whole(day) or day < 1:
            return f"day {shown(day)} is not a day of the game; days are counted from 1"
        if self._deeds and day < self._deeds[-1]["day"]:
            return (f"day {int(day)} comes after day {self._deeds[-1]['day']} in the record; "
                    "deeds are kept in the order they were done")
        return self._vocabulary_refusal(deed["verb"], deed["place"])

    def _vocabulary_refusal(self, verb: object, place: object) -> str:
        if not (isinstance(verb, str) and verb in self._verbs):
            return f"unknown verb {shown(verb)}"
        if not (isinstance(place, str) and place in self._places):
            return f"{shown(place)} is not a place in the valley; a deed acts on a place"
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


def shown(value: object) -> str:
    """`value` as the record's JSON writes it, so both twins name it alike."""
    if isinstance(value, float) and value.is_integer() and abs(value) < 1e15:
        value = int(value)
    return json.dumps(value, separators=(",", ":"), sort_keys=True)


def read_text(text: str, log: DeedLog) -> str:
    """Read a saved record's whole text into `log`; "" or why it was refused.

    The writer ends every line with a newline and writes no blank line, so
    a text not ending in one has a torn last line, and a blank line is not
    a deed. An empty text is refused too.
    """
    if text == "":
        return f'the record file is empty; its first line must be the header {{"version": {VERSION}}}'
    if not text.endswith("\n"):
        return "the record's last line is torn: the file does not end in a newline"
    return read_lines(text[:-1].split("\n"), log)


def append_refusal(text: str, log: DeedLog, deed: dict) -> str:
    """Why `deed` cannot be appended to a saved record `text`, kept in memory as `log`, or "".

    The text must read clean, `deed` must follow its last deed, and `log`
    must be what the text holds: a session that appends before loading
    would otherwise write a day out of order.
    """
    on_disk = log.cut(0)
    why = read_text(text, on_disk)
    if why:
        return f"the record on disk is refused, and nothing was appended: {why}"
    why = on_disk.refusal(deed)
    if why:
        return why
    if on_disk.deeds() != log.deeds():
        return "the record in memory is not the one on disk; load it before appending"
    return ""


def read_lines(lines: list[str], log: DeedLog) -> str:
    """Read a saved record's lines into `log`; "" or why they were refused.

    A line repeating the header's `version` is refused like any key beyond
    the three: stricter than N20, which lets it pass, on purpose (ADR 0025).
    """
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
    if not _number(version):
        return f"the record's version {shown(version)} is not a number; this game reads version {VERSION}"
    if version != VERSION:
        return f"the record is version {shown(version)}, and this game reads version {VERSION}"
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
