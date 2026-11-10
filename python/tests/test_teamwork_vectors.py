"""The Python half of the teamwork conformance run.

The vectors in `spec/vectors/teamwork/` fix each technique's answer on a
stated query: which candidate a bot takes and why the others were dropped,
a team's influence at stated points, where a commander sends each squad,
a squad's states and waves over a run of facts, and who holds an attack
token after each event of a script. Both languages answer
them and check every value against the file, never against each other. The
answers came from neither: `derive.py` beside them is a third copy of the
rules, importing nothing from this repository.
"""

import json
import math
import pathlib
import unittest

from gameaikit.teamwork import commander, confidence, influence, passage, positions, roles, search, tokens

VECTORS = pathlib.Path(__file__).resolve().parents[2] / "spec" / "vectors" / "teamwork"

#: Fewer than this and something is wrong with the directory, not the vectors.
FEWEST_VECTORS = 10

#: Shared with `godot/test/ai_teamwork/teamwork_vector.gd`, sized for the
#: GDScript side's 32-bit `Vector2`.
TOLERANCE = 1e-4

KINDS = ("positions", "influence", "commander", "confidence", "passage", "search", "roles", "tokens")


def answer_positions(vector: dict) -> dict:
    query = vector["query"]
    weights = positions.Weights(**vector["weights"])
    candidates = [positions.Candidate(**each) for each in query["candidates"]]
    choice = positions.choose(query["bot"], candidates, weights, query["has_threat"], query["use_claims"])
    return {"statuses": choice.statuses, "scores": choice.scores, "chosen": choice.chosen}


def answer_influence(vector: dict) -> dict:
    shape = vector["map"]
    grid = influence.TeamInfluence(shape["width"], shape["height"], shape["cell_size"],
                                   tuple(shape["origin"]), shape["radius"])
    for source in vector["query"]["sources"]:
        grid.add_source(tuple(source["place"]), source["strength"])
    return {"values": [grid.value_at(tuple(place)) for place in vector["query"]["asked"]]}


def answer_commander(vector: dict) -> dict:
    weights = commander.Weights(**vector["weights"])
    squads = [commander.SquadReport(each["id"], tuple(each["position"]), each["size"]) for each in vector["query"]["squads"]]
    objectives = [commander.Objective(each["id"], tuple(each["position"]), each["held_by"], each["ideal"],
                                      each["influence"]) for each in vector["query"]["objectives"]]
    return {"priorities": [commander.priority_of(each, weights) for each in objectives],
            "assigned": commander.assign(squads, objectives, weights),
            "nearest": commander.nearest(squads, objectives)}


def answer_confidence(vector: dict) -> dict:
    thresholds = confidence.Thresholds(**vector["thresholds"])
    query = vector["query"]
    values = [confidence.confidence(confidence.Facts(**each), thresholds) for each in query["facts"]]
    answer = {"values": values}
    for may, key in ((True, "states_with_retreat"), (False, "states_without_retreat")):
        state, states = confidence.HOLD, []
        for value in values:
            state = confidence.next_state(state, value, thresholds, may)
            states.append(state)
        answer[key] = states
    answer["waves"] = []
    for phase in query["phases"]:
        moving, covering = confidence.waves(query["members"], phase)
        answer["waves"].append({"phase": phase, "moving": moving, "covering": covering})
    return answer


def _bounded(value):
    """JSON's null, for no bound, as infinity; and back."""
    return math.inf if value is None else value


def answer_passage(vector: dict) -> dict:
    costs, chosen = [], []
    for each in vector["query"]["facts"]:
        fields = dict(each, detour_metres=_bounded(each["detour_metres"]), spot_loss=_bounded(each["spot_loss"]))
        found, way = passage.choose(passage.Facts(**fields))
        costs.append([None if cost == math.inf else cost for cost in found])
        chosen.append(way)
    prices = passage.Prices(**vector["prices"])
    answers = []
    for each in vector["query"]["requests"]:
        cost, granted = passage.answer(passage.Request(**dict(each, saves=_bounded(each["saves"]))), prices)
        answers.append({"cost": None if cost == math.inf else cost, "granted": granted})
    return {"costs": costs, "chosen": chosen, "answers": answers}


def answer_search(vector: dict) -> dict:
    query = vector["query"]
    weights = search.Weights(**vector["weights"])
    return {"assigned": search.assign(query["spots"], query["costs"], query["use_claims"], weights),
            "granted": search.grant_last_known(query["last_known"], query["cap"])}


def answer_roles(vector: dict) -> dict:
    query = vector["query"]
    return {"granted": roles.grant(query["requests"], query["use_arbiter"], query["max_flankers"])}


def play_tokens(pool: tokens.AttackTokens, event: dict):
    """One scripted event against `pool`, and what it answers."""
    if event["do"] == "request":
        return pool.request(event["id"], event["kind"], event["cost"], event["priority"], event["distance"], event["at"])
    if event["do"] == "release":
        return pool.release(event["id"], event["reason"], event["at"])
    if event["do"] == "withdraw":
        return pool.withdraw(event["id"], event["at"])
    if event["do"] == "revoke":
        return pool.revoke_kind(event["kind"], event["at"])
    granted = pool.step(event["at"], event["state"])
    kinds = pool.config.pools
    return {"granted": granted, "free": {kind: pool.free_tokens(kind) for kind in kinds},
            "holders": {kind: pool.holders(kind) for kind in kinds}}


def answer_tokens(vector: dict) -> dict:
    pool = tokens.AttackTokens(tokens.Config(**vector["query"]["config"]))
    answers = [play_tokens(pool, event) for event in vector["query"]["script"]]
    events = [[each["at"], each["id"], each["kind"], each["what"]] for each in pool.events]
    return {"answers": answers, "events": events}


ANSWER = {"passage": answer_passage, "positions": answer_positions, "influence": answer_influence,
          "commander": answer_commander, "confidence": answer_confidence, "search": answer_search, "roles": answer_roles,
          "tokens": answer_tokens}


def misses(expected, found, where: str = "") -> list[str]:
    """Every place `found` differs from `expected`, numbers within TOLERANCE."""
    if isinstance(expected, dict):
        if not isinstance(found, dict) or set(expected) != set(found):
            return [f"{where}: keys {sorted(found) if isinstance(found, dict) else found}, the file says {sorted(expected)}"]
        return [line for key in expected for line in misses(expected[key], found[key], f"{where}.{key}")]
    if isinstance(expected, list):
        if not isinstance(found, list) or len(found) != len(expected):
            return [f"{where}: {found}, the file says {expected}"]
        return [line for index, item in enumerate(expected) for line in misses(item, found[index], f"{where}[{index}]")]
    if isinstance(expected, float) and not isinstance(found, bool):
        return [] if math.isclose(found, expected, abs_tol=TOLERANCE) else [f"{where}: {found}, the file says {expected}"]
    return [] if found == expected else [f"{where}: {found!r}, the file says {expected!r}"]


def vector_files() -> list[pathlib.Path]:
    return sorted(VECTORS.glob("*.json"))


class TeamworkVectorTests(unittest.TestCase):
    def test_the_directory_holds_every_kind(self) -> None:
        kinds = [json.loads(path.read_text(encoding="utf-8"))["kind"] for path in vector_files()]
        self.assertGreaterEqual(len(kinds), FEWEST_VECTORS)
        self.assertEqual(sorted(set(kinds)), sorted(KINDS))

    def test_every_answer_is_the_files(self) -> None:
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            with self.subTest(vector=path.name):
                self.assertEqual(misses(vector["expect"], ANSWER[vector["kind"]](vector)), [])

    def test_a_planted_wrong_answer_is_caught(self) -> None:
        # The comparison above, shown each kind's answer moved: it has to fail.
        for path in vector_files():
            vector = json.loads(path.read_text(encoding="utf-8"))
            answer = ANSWER[vector["kind"]](vector)
            first_key = sorted(answer)[0]
            answer[first_key] = "planted"
            with self.subTest(vector=path.name):
                self.assertTrue(misses(vector["expect"], answer))

    def test_a_number_off_by_ten_tolerances_is_caught(self) -> None:
        self.assertTrue(misses(1.0, 1.0 + 10 * TOLERANCE))
        self.assertFalse(misses(1.0, 1.0 + TOLERANCE / 10))


if __name__ == "__main__":
    unittest.main()
