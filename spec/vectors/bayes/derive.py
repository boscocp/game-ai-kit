"""Write the Bayesian network vectors in this directory.

Imports nothing from the repository, so the answers come from neither
implementation the vectors hold. And it does not enumerate as they do: it
writes out the whole joint distribution -- every assignment of every
variable, its chance the product of one table entry a variable -- and adds
up the rows that agree with what is asked. Same numbers, a different road
(AIMA 4th ed., 12.3, inference from the full joint):

    python3 spec/vectors/bayes/derive.py spec/vectors/bayes
"""
import itertools
import json
import pathlib
import sys

YES, NO = "yes", "no"


def variable(name, parents, table, values=(YES, NO)):
    return {"name": name, "values": list(values), "parents": list(parents), "table": table}


# AIMA 4th ed., figure 13.2: the burglar alarm, John and Mary.
BURGLARY = {"variables": [
    variable("burglary", [], [[0.001, 0.999]]),
    variable("earthquake", [], [[0.002, 0.998]]),
    variable("alarm", ["burglary", "earthquake"], [[0.95, 0.05], [0.94, 0.06], [0.29, 0.71], [0.001, 0.999]]),
    variable("john_calls", ["alarm"], [[0.90, 0.10], [0.05, 0.95]]),
    variable("mary_calls", ["alarm"], [[0.70, 0.30], [0.01, 0.99]]),
]}

# The infiltration guard's network (T115), as
# godot/game3d/infiltration/intruder_network.json writes it; a test there
# holds that file to this one.
GUARD = {"variables": [
    variable("intruder", [], [[0.05, 0.95]]),
    variable("radio_fault", [], [[0.02, 0.98]]),
    variable("noise", ["intruder"], [[0.7, 0.3], [0.1, 0.9]]),
    variable("open_door", ["intruder"], [[0.5, 0.5], [0.005, 0.995]]),
    variable("partner_quiet", ["intruder", "radio_fault"], [[0.95, 0.05], [0.6, 0.4], [0.9, 0.1], [0.01, 0.99]]),
]}

# Values of three and of two, so a row read with the wrong parent varying
# fastest lands on another row: the first parent varies slowest.
NOISY = {"variables": [
    variable("weather", [], [[0.5, 0.3, 0.2]], ("calm", "windy", "storm")),
    variable("window", [], [[0.25, 0.75]], ("open", "shut")),
    variable("rattle", ["weather", "window"],
             [[0.3, 0.7], [0.05, 0.95], [0.6, 0.4], [0.2, 0.8], [0.9, 0.1], [0.5, 0.5]],
             ("loud", "quiet")),
    variable("draught", ["window"], [[0.8, 0.2], [0.1, 0.9]]),
]}


def row_of(network, name, assignment):
    by_name = {entry["name"]: entry for entry in network["variables"]}
    entry = by_name[name]
    row = 0
    for parent in entry["parents"]:
        row = row * len(by_name[parent]["values"]) + by_name[parent]["values"].index(assignment[parent])
    return entry["table"][row][entry["values"].index(assignment[name])]


def joint(network):
    """Every whole assignment, with its chance."""
    names = [entry["name"] for entry in network["variables"]]
    for values in itertools.product(*(entry["values"] for entry in network["variables"])):
        assignment = dict(zip(names, values))
        chance = 1.0
        for name in names:
            chance *= row_of(network, name, assignment)
        yield assignment, chance


def answer(network, query, evidence):
    """P(query | evidence) from the full joint; [] when the evidence cannot happen."""
    values = next(entry["values"] for entry in network["variables"] if entry["name"] == query)
    sums = [0.0] * len(values)
    for assignment, chance in joint(network):
        if all(assignment[name] == seen for name, seen in evidence.items()):
            sums[values.index(assignment[query])] += chance
    total = sum(sums)
    return [part / total for part in sums] if total > 0 else []


def influence(network, query, value, evidence):
    with_all = answer(network, query, evidence)
    if not with_all:
        return {}
    values = next(entry["values"] for entry in network["variables"] if entry["name"] == query)
    index = values.index(value)
    return {name: with_all[index] - answer(network, query, {other: seen for other, seen in evidence.items()
                                                              if other != name})[index]
            for name in evidence}


def query(network, asked, value, evidence):
    return {"query": asked, "value": value, "evidence": evidence,
            "distribution": answer(network, asked, evidence),
            "influence": influence(network, asked, value, evidence)}


def vector(description, network, queries=(), problem=""):
    return {"description": description, "network": network, "problem": problem, "queries": list(queries)}


def every_vector():
    guard_evidence = [{"noise": noise, "open_door": door, "partner_quiet": quiet}
                      for noise, door, quiet in itertools.product((YES, NO), repeat=3)]
    yield "burglary-john-and-mary-call", vector(
        "AIMA's burglary network (figure 13.2). John and Mary both call: P(burglary) is about 0.284 -- the "
        "book's answer, worked by hand in the README -- and Mary's call moved it more than John's.",
        BURGLARY, [query(BURGLARY, "burglary", YES, {"john_calls": YES, "mary_calls": YES}),
                   query(BURGLARY, "alarm", YES, {"john_calls": YES, "mary_calls": YES}),
                   query(BURGLARY, "burglary", YES, {})])
    yield "burglary-explained-away", vector(
        "The alarm rang. Learning there was an earthquake explains it away: P(burglary) falls, and the "
        "earthquake's influence is negative.",
        BURGLARY, [query(BURGLARY, "burglary", YES, {"alarm": YES}),
                   query(BURGLARY, "burglary", YES, {"alarm": YES, "earthquake": YES}),
                   query(BURGLARY, "earthquake", YES, {"john_calls": NO, "mary_calls": YES})])
    yield "three-values-and-two-parents", vector(
        "Values of three and two. The rattle's table has six rows, the weather varying slowest: a "
        "reading that swaps the parents lands on the wrong row.",
        NOISY, [query(NOISY, "weather", "storm", {"rattle": "loud"}),
                query(NOISY, "window", "open", {"rattle": "loud", "draught": YES}),
                query(NOISY, "rattle", "loud", {"weather": "windy"})])
    yield "impossible-evidence", vector(
        "Evidence whose chance is 0 has no answer: the distribution and the influence are empty.",
        {"variables": [variable("cause", [], [[1.0, 0.0]]), variable("effect", ["cause"], [[1.0, 0.0], [0.0, 1.0]])]},
        [query({"variables": [variable("cause", [], [[1.0, 0.0]]),
                              variable("effect", ["cause"], [[1.0, 0.0], [0.0, 1.0]])]},
               "cause", YES, {"effect": NO})])
    yield "the-guards-intruder", vector(
        "The infiltration guard's network, asked as the game asks it: every piece of evidence seen, "
        "yes or no, all eight ways.",
        GUARD, [query(GUARD, "intruder", YES, evidence) for evidence in guard_evidence])
    yield "refused-a-parent-after-its-child", vector(
        "A parent named before it is given, so not yet a variable: refused, B3.",
        {"variables": [variable("effect", ["cause"], [[0.9, 0.1], [0.2, 0.8]]), variable("cause", [], [[0.5, 0.5]])]},
        problem="B3")
    yield "refused-a-row-short", vector(
        "Two parents of two values each need four rows; three are given: refused, B4.",
        {"variables": [variable("one", [], [[0.5, 0.5]]), variable("two", [], [[0.5, 0.5]]),
                       variable("both", ["one", "two"], [[0.9, 0.1], [0.5, 0.5], [0.1, 0.9]])]},
        problem="B4")
    yield "refused-a-row-not-summing-to-one", vector(
        "A row whose chances sum to 1.1: refused, B5.",
        {"variables": [variable("cause", [], [[0.6, 0.5]])]}, problem="B5")


def main(directory):
    for name, written in every_vector():
        path = pathlib.Path(directory) / f"{name}.json"
        path.write_text(json.dumps(written, indent=1) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
