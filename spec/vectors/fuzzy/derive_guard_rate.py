"""Write `a-guards-awareness-rate.json`: the patrol guard's awareness rate.

The controller is a copy of the `rate` of the `patrol` row of the
infiltration example's guard types, written out here so this
script reads nothing from the repository; `guard_type_test.gd` holds the
two equal. The answers come from a third copy of Mamdani inference --
trapezoids, min for and, max across rules, the centroid at the output's
sample points -- not from `ai_fuzzy` or `gameaikit.fuzzy`:

    python3 spec/vectors/fuzzy/derive_guard_rate.py spec/vectors/fuzzy
"""
import json, pathlib, sys


def sets(a, b):
    return {a[0]: a[1], b[0]: b[1]}


CONTROLLER = {
    "inputs": [
        {"name": "certainty", "minimum": 0.0, "maximum": 1.0,
         "sets": sets(("faint", [0.0, 0.0, 0.2, 0.6]), ("clear", [0.2, 0.6, 1.0, 1.0]))},
        {"name": "light", "minimum": 0.0, "maximum": 1.0,
         "sets": sets(("dark", [0.0, 0.0, 0.2, 0.6]), ("lit", [0.2, 0.6, 1.0, 1.0]))},
        {"name": "motion", "minimum": 0.0, "maximum": 1.0,
         "sets": sets(("still", [0.0, 0.0, 0.2, 0.6]), ("moving", [0.2, 0.6, 1.0, 1.0]))},
        {"name": "distance", "minimum": 0.0, "maximum": 18.0,
         "sets": sets(("near", [0.0, 0.0, 3.0, 10.0]), ("far", [3.0, 10.0, 18.0, 18.0]))},
    ],
    "outputs": [
        {"name": "rate", "minimum": 0.0, "maximum": 1.0, "samples": 101,
         "sets": sets(("slow", [0.0, 0.0, 0.05, 0.3]), ("fast", [0.2, 0.6, 1.0, 1.0]))},
    ],
    "rules": [
        {"if": [["certainty", "clear"], ["light", "lit"], ["distance", "near"]], "connective": "and", "then": ["rate", "fast"]},
        {"if": [["certainty", "clear"], ["motion", "moving"], ["distance", "near"]], "connective": "and", "then": ["rate", "fast"]},
        {"if": [["certainty", "faint"]], "connective": "and", "then": ["rate", "slow"]},
        {"if": [["distance", "far"]], "connective": "and", "then": ["rate", "slow"]},
        {"if": [["light", "dark"], ["motion", "still"]], "connective": "and", "then": ["rate", "slow"]},
    ],
}


def degree(points, x):
    a, b, c, d = points
    if x < a or x > d:
        return 0.0
    if b <= x <= c:
        return 1.0
    return (x - a) / (b - a) if x < b else (d - x) / (d - c)


def activations(inputs):
    degrees = {}
    for variable in CONTROLLER["inputs"]:
        x = min(max(inputs[variable["name"]], variable["minimum"]), variable["maximum"])
        for name, points in variable["sets"].items():
            degrees[(variable["name"], name)] = degree(points, x)
    terms = {"slow": 0.0, "fast": 0.0}
    for rule in CONTROLLER["rules"]:
        strength = min(degrees[tuple(pair)] for pair in rule["if"])
        terms[rule["then"][1]] = max(terms[rule["then"][1]], strength)
    return terms


def centroid(terms):
    out = CONTROLLER["outputs"][0]
    weighted = area = 0.0
    for index in range(out["samples"]):
        point = out["minimum"] + (out["maximum"] - out["minimum"]) * index / (out["samples"] - 1)
        height = max(min(terms[name], degree(points, point)) for name, points in out["sets"].items())
        weighted += height * point
        area += height
    return weighted / area


def case(name, why, certainty, light, motion, distance):
    inputs = {"certainty": certainty, "light": light, "motion": motion, "distance": distance}
    terms = activations(inputs)
    return {"kind": "evaluate", "name": name, "why": why, "inputs": inputs,
            "activations": {"rate": terms}, "outputs": {"rate": centroid(terms)}}


def vector():
    return {
        "name": "a guard's awareness rate",
        "why": "The patrol guard's fuzzy rate (T69): how fast awareness rises, in shares of the peak a second, "
               "from certainty, light, motion and distance. The controller is guard_types.json's patrol row.",
        "controller": CONTROLLER,
        "cases": [
            case("close-clear-lit", "every fast rule's lit half fully true", 1.0, 1.0, 0.0, 1.0),
            case("close-clear-dark-moving", "the moving rule carries it in the dark", 1.0, 0.0, 1.0, 1.0),
            case("close-clear-dark-still", "only slow rules: dark and still", 1.0, 0.0, 0.0, 1.0),
            case("far-off", "far is slow whatever else", 1.0, 1.0, 1.0, 16.0),
            case("faint", "a faint look is slow", 0.1, 1.0, 1.0, 1.0),
            case("halfway", "every input in a slope: both terms partly true", 0.4, 0.4, 0.4, 6.0),
        ],
    }


if __name__ == "__main__":
    folder = pathlib.Path(sys.argv[1])
    (folder / "a-guards-awareness-rate.json").write_text(json.dumps(vector(), indent=1) + "\n")
