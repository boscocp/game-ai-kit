"""The valley's rules (T164): the world of any day, rebuilt from the record.

The world is a dictionary of facts, `place.fact` to true or false. Day 0 is
`valley_rules.json`'s `start`; each day after it is one night of the rules
-- every rule whose `when` holds on the day that ended writes its `then`
into the next, all read from that same day -- then the day's deeds, in the
record's order, each setting the facts its verb sets on its place. Godot's
`ValleyRules` is the same machine (godot/game/valley/valley_rules.gd).

Nothing is random and nothing is kept: the same record gives the same
world, rebuilt as often as asked.

    rules = ValleyRules.read()
    log = rules.new_record()
    log.append({"day": 2, "verb": "burn", "place": "barn"})
    rules.rebuild(log, 3)["market.bread"]   # False: the grain burnt with the barn
"""

from __future__ import annotations

import json
import pathlib

from gameaikit.valley.record import DeedLog

RULES = pathlib.Path(__file__).resolve().parents[3] / "godot" / "game" / "valley" / "valley_rules.json"


class ValleyRules:
    """The first day's valley, what each verb does, and the overnight rules."""

    def __init__(self, table: dict) -> None:
        self.places = list(table["places"])
        self.start = dict(table["start"])
        self.verbs = table["verbs"]
        self.rules = table["rules"]

    @classmethod
    def read(cls, path: pathlib.Path = RULES) -> ValleyRules:
        """The rules as `valley_rules.json` writes them."""
        return cls(json.loads(path.read_text()))

    def new_record(self) -> DeedLog:
        """An empty record that knows this valley's verbs and places."""
        return DeedLog(self.places, self.verbs)

    def rebuild(self, log: DeedLog, day: int) -> dict:
        """The facts at the end of `day`; deeds after it are not read."""
        facts = dict(self.start)
        deeds = log.deeds()
        following = 0
        for today in range(1, day + 1):
            facts = self.overnight(facts)
            while following < len(deeds) and deeds[following]["day"] == today:
                self.apply(facts, deeds[following])
                following += 1
        return facts

    def overnight(self, facts: dict) -> dict:
        """The next day's facts before its deeds: every rule that holds on `facts`, applied."""
        following = dict(facts)
        for rule in self.rules:
            if all(facts[name] == value for name, value in rule["when"].items()):
                following.update(rule["then"])
        return following

    def apply(self, facts: dict, deed: dict) -> None:
        """Do `deed` in `facts`, at once: the facts its verb sets on its place."""
        place = deed["place"]
        for fact, value in self.verbs[deed["verb"]][place]["sets"].items():
            facts[f"{place}.{fact}"] = value
