"""Write the valley vectors in this directory.

Imports nothing from the repository: a third copy of the machine, written
from the "about" of `godot/game/valley/valley_rules.json` and
`standing.json` in plain dictionaries, so the worlds and standings come
from neither implementation the vectors hold. It also checks that each case
shows what its name says -- a vector named for the bread that fails the
next day, in which the bread never failed, would hold nothing.

    python3 spec/vectors/valley/derive.py spec/vectors/valley
"""
import json
import pathlib
import sys

VALLEY = pathlib.Path(__file__).resolve().parents[3] / "godot" / "game" / "valley"
RULES = json.loads((VALLEY / "valley_rules.json").read_text())
WEIGHTS = json.loads((VALLEY / "standing.json").read_text())


def night(facts):
    after = dict(facts)
    for rule in RULES["rules"]:
        if all(facts[name] == value for name, value in rule["when"].items()):
            after.update(rule["then"])
    return after


def days(deeds, last):
    """The facts and the standing at the end of each day from 1 to `last`."""
    facts, worlds, standings = dict(RULES["start"]), [], []
    for today in range(1, last + 1):
        facts = night(facts)
        for deed in deeds:
            if deed["day"] == today:
                for fact, value in RULES["verbs"][deed["verb"]][deed["place"]]["sets"].items():
                    facts[deed["place"] + "." + fact] = value
        worlds.append(facts)
        standings.append(standing([deed for deed in deeds if deed["day"] <= today]))
    return worlds, standings


def standing(deeds):
    rows = {(row["verb"], row["place"]): row for row in WEIGHTS["weights"]}
    return {virtue: sum(rows[(deed["verb"], deed["place"])][virtue] for deed in deeds) for virtue in WEIGHTS["virtues"]}


def at_fault(lines):
    """The word a refusal of `lines` must name, or None when they are a good record."""
    header = json.loads(lines[0])
    if "version" not in header:
        return "no version"
    if header["version"] != 1:
        return f"version {header['version']}"
    last = 0
    for line in lines[1:]:
        deed = json.loads(line)
        extra = [key for key in deed if key not in ("day", "verb", "place")]
        if extra:
            return extra[0]
        if deed["day"] < last:
            return f"day {deed['day']}"
        if deed["verb"] not in RULES["verbs"]:
            return deed["verb"]
        if deed["place"] not in RULES["verbs"][deed["verb"]]:
            return deed["place"]
        last = deed["day"]
    return None


def deed(day, verb, place):
    return {"day": day, "verb": verb, "place": place}


def changed_on(worlds, fact, value):
    """The first day (1-based) `fact` has `value`, or None."""
    return next((number for number, facts in enumerate(worlds, start=1) if facts[fact] == value), None)


REBUILT = {
    "a-quiet-valley-stays-as-it-is": (
        "No deed: every night of the rules leaves the first day's valley as it was, and the standing at zero.",
        [], 4, lambda worlds, standings: all(facts == RULES["start"] for facts in worlds)
        and all(set(values.values()) == {0} for values in standings)),
    "a-burnt-barn-leaves-the-market-without-bread-the-next-day": (
        "The barn burns on day 2. It is down that day, and the market still has bread; the next day it has none.",
        [deed(2, "burn", "barn")], 4,
        lambda worlds, standings: not worlds[1]["barn.standing"] and worlds[1]["market.bread"]
        and changed_on(worlds, "market.bread", False) == 3),
    "a-diverted-river-stops-the-mill-then-the-bread": (
        "The river is diverted on day 1: the field is watered and the mill stops on day 2, and the bread fails on day 3 "
        "-- a consequence through two places takes two nights.",
        [deed(1, "divert_water", "river")], 4,
        lambda worlds, standings: changed_on(worlds, "mill.turning", False) == 2
        and changed_on(worlds, "field.watered", True) == 2 and changed_on(worlds, "market.bread", False) == 3),
    "a-mended-barn-brings-the-bread-back": (
        "The barn burns on day 1 and is mended on day 3: no bread on days 2 and 3, bread again on day 4. "
        "Care falls and rises, fear only rises.",
        [deed(1, "burn", "barn"), deed(3, "repair", "barn")], 5,
        lambda worlds, standings: [facts["market.bread"] for facts in worlds] == [True, False, False, True, True]
        and standings[0]["care"] < 0 < standings[0]["fear"] == standings[2]["fear"]
        and standings[2]["care"] > standings[0]["care"]),
    "the-bridge-down-and-a-footbridge-built": (
        "The bridge is pulled down on day 1 and a footbridge built at the ford on day 3: no travellers on days 2 "
        "and 3, travellers again on day 4 with the bridge still down.",
        [deed(1, "pull_down", "bridge"), deed(3, "build_footbridge", "ford")], 5,
        lambda worlds, standings: [facts["market.travellers"] for facts in worlds] == [True, False, False, True, True]
        and not worlds[4]["bridge.standing"]),
    "a-sown-field-with-a-well-grows-a-harvest": (
        "The field is sown and a well dug on day 1: watered on day 2, a harvest on day 3, and the mill still turns.",
        [deed(1, "plant", "field"), deed(1, "dig_well", "square")], 4,
        lambda worlds, standings: changed_on(worlds, "field.watered", True) == 2
        and changed_on(worlds, "field.harvest", True) == 3 and all(facts["mill.turning"] for facts in worlds)),
    "an-open-gate-lets-the-goats-in": (
        "The gate is opened on day 1 and shut on day 3: the trees are stripped on days 2 and 3 and fruit again on day 4.",
        [deed(1, "open_gate", "gate"), deed(3, "close_gate", "gate")], 5,
        lambda worlds, standings: [facts["orchard.fruit"] for facts in worlds] == [True, False, False, True, True]),
    "two-deeds-on-one-day-in-the-records-order": (
        "On day 2 the mill is burnt and then mended: the record's order is the order they happened, so it ends the "
        "day standing, the bread never fails, and the standing still counts both.",
        [deed(2, "burn", "mill"), deed(2, "repair", "mill")], 4,
        lambda worlds, standings: all(facts["mill.standing"] and facts["market.bread"] for facts in worlds)
        and standings[1]["fear"] > 0),
}

HEADER = json.dumps({"version": 1})

REFUSED = {
    "a-deed-whose-target-is-a-person-is-refused": (
        "A planted deed naming a villager as its target: the schema has no such key, and the refusal names it.",
        [HEADER, json.dumps({"day": 1, "verb": "burn", "target": "villager_3"})]),
    "a-person-in-the-place-of-a-place-is-refused": (
        "A deed whose place is a villager: not a place in the valley, refused by its name.",
        [HEADER, json.dumps(deed(1, "burn", "villager_3"))]),
    "an-unknown-verb-is-refused": (
        "A verb the rules do not know, after a good deed: refused by its name.",
        [HEADER, json.dumps(deed(1, "plant", "field")), json.dumps(deed(2, "kick", "barn"))]),
    "a-verb-on-a-place-it-does-not-act-on-is-refused": (
        "Burning the river: a known verb and a known place, but burn does not act on it.",
        [HEADER, json.dumps(deed(1, "burn", "river"))]),
    "a-deed-out-of-order-is-refused": (
        "A day-2 deed after a day-3 one: the record is kept in the order deeds were done.",
        [HEADER, json.dumps(deed(3, "plant", "field")), json.dumps(deed(2, "dig_well", "square"))]),
    "a-record-of-another-version-is-refused": (
        "A header with version 2: this game reads version 1, and refuses rather than misreads.",
        [json.dumps({"version": 2}), json.dumps(deed(1, "plant", "field"))]),
    "a-record-with-no-version-is-refused": (
        "No header: the first line is a deed, so the record carries no version.",
        [json.dumps(deed(1, "plant", "field"))]),
}


def main(directory):
    folder = pathlib.Path(directory)
    failed = 0
    for name, (description, deeds, last, holds) in REBUILT.items():
        worlds, standings = days(deeds, last)
        if not holds(worlds, standings):
            print(f"{name}: does not show what its name says", file=sys.stderr)
            failed += 1
            continue
        vector = {"kind": "rebuilt", "description": description, "deeds": deeds, "days": last,
                  "worlds": worlds, "standing": standings}
        (folder / f"{name}.json").write_text(json.dumps(vector, indent=1) + "\n")
    for name, (description, lines) in REFUSED.items():
        names = at_fault(lines)
        if names is None:
            print(f"{name}: a good record, so it shows no refusal", file=sys.stderr)
            failed += 1
            continue
        vector = {"kind": "refused", "description": description, "lines": lines, "names": names}
        (folder / f"{name}.json").write_text(json.dumps(vector, indent=1) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: derive.py DIRECTORY", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
