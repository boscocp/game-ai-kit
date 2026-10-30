"""Write the director vectors in this directory.

Imports nothing from the repository: a third copy of the machine, written
from `spec/director/director.json`'s "about" in plain dictionaries, so the
curves come from neither implementation the vectors hold. It also checks
that each case shows what its name says -- a vector named for the relax
that ends early, in which the relax ran its full time, would hold nothing.

    python3 spec/vectors/director/derive.py spec/vectors/director
"""
import json
import pathlib
import sys

SPEC = json.loads((pathlib.Path(__file__).resolve().parents[2] / "director" / "director.json").read_text())
STEP = SPEC["step_seconds"]


def whole_steps(seconds):
    return round(seconds / STEP)


def run(steps, events):
    state = {"value": 0.0, "phase": "build_up", "since": 0, "chased": False, "exit": float("inf"), "relax_from": float("inf")}
    curve, changes = [], []
    for number in range(steps):
        for event in [happening for happening in events if happening["step"] == number]:
            state["value"] += added(state, event)
        if not state["chased"]:
            state["value"] -= SPEC["decay_per_second"] * STEP
        state["value"] = min(max(state["value"], 0.0), SPEC["most"])
        state["since"] += 1
        after = following(state)
        if after != state["phase"]:
            changes.append({"step": number, "from": state["phase"], "to": after})
            state["phase"], state["since"] = after, 0
            if after == "relax":
                state["relax_from"] = state["exit"]
        curve.append(state["value"])
    return {"intensity": curve, "changes": changes}


def added(state, event):
    kind = event["kind"]
    if kind == "chase":
        state["chased"] = event["on"]
        return 0.0
    if kind == "exit":
        state["exit"] = float(event["metres"])
        return 0.0
    if kind == "hurt":
        return SPEC["raise"]["hurt_per_point"] * event["points"]
    if kind == "search_near":
        distance = event["distance"]
        if distance > SPEC["search"]["radius"]:
            return 0.0
        share = 1.0 if distance <= SPEC["search"]["full_within"] else SPEC["search"]["full_within"] / distance
        return SPEC["raise"]["search_near"] * STEP * share
    return SPEC["raise"][kind]


def following(state):
    phase, value, since = state["phase"], state["value"], state["since"]
    if phase == "build_up":
        return "sustain_peak" if value >= SPEC["peak"] else phase
    if phase == "sustain_peak":
        return "peak_fade" if since >= whole_steps(SPEC["sustain_seconds"]) else phase
    if phase == "peak_fade":
        return "relax" if value < SPEC["fade_below"] else phase
    done = since >= whole_steps(SPEC["relax_seconds"]) or state["relax_from"] - state["exit"] >= SPEC["relax_travel"]
    return "build_up" if done else phase


def sightings(*steps):
    return [{"step": step, "kind": "seen"} for step in steps]


def phases_in(result):
    return [change["to"] for change in result["changes"]]


def holds_cycle(result):
    return phases_in(result) == ["sustain_peak", "peak_fade", "relax", "build_up"]


def holds_chase(result):
    flat = result["intensity"][20:60]
    return min(flat) == max(flat) and flat[0] > 0.0 and result["intensity"][70] < flat[0]


def holds_nearness(result):
    rises = [round(result["intensity"][step] - result["intensity"][step - 1] + SPEC["decay_per_second"] * STEP, 9)
             for step in (11, 21, 31, 41)]
    beyond = round(result["intensity"][50] - result["intensity"][51], 9) == round(SPEC["decay_per_second"] * STEP, 9)
    return rises[0] == rises[1] > rises[2] > rises[3] > 0.0 and rises[2] == round(rises[1] / 2, 9) and beyond


def holds_hurt(result):
    return result["intensity"][5] == SPEC["raise"]["hurt_per_point"] * 30 - SPEC["decay_per_second"] * STEP \
        and result["intensity"][10] == SPEC["most"]


def holds_early_relax(result):
    entered = {change["to"]: change["step"] for change in result["changes"]}
    return "relax" in entered and "build_up" in entered and \
        entered["build_up"] - entered["relax"] < whole_steps(SPEC["relax_seconds"])


def holds_hearing(result):
    decay = SPEC["decay_per_second"] * STEP
    heard = round(result["intensity"][3] + decay, 9)
    seen = round(result["intensity"][13] - result["intensity"][12] + decay, 9)
    return heard == SPEC["raise"]["heard"] and seen == SPEC["raise"]["seen"] and heard != seen


def holds_quiet(result):
    return not result["changes"] and max(result["intensity"]) == 0.0


def walking_on(start, every, metres, count):
    return [{"step": start + index * every, "kind": "exit", "metres": metres - index} for index in range(count)]


CASES = {
    "a-peak-is-sustained-then-fades-then-relaxes": (
        "Four sightings close together reach the peak; it is held for the sustain's steps however the intensity falls, "
        "faded until below fade_below, then relaxed for the relax's whole time, and built up again.",
        560, sightings(5, 10, 15, 20), holds_cycle),
    "no-decay-while-a-guard-chases": (
        "Two sightings, then a chase from step 20 to step 60: the intensity does not move while it lasts, and decays after.",
        80, sightings(2, 4) + [{"step": 20, "kind": "chase", "on": True}, {"step": 60, "kind": "chase", "on": False}],
        holds_chase),
    "a-search-adds-less-the-further-it-is": (
        "One guard searching at 1, 2, 4 and 8 metres, then at 12, beyond the radius: within full_within it adds the most, "
        "then half at twice that, less again at 8, and nothing at 12. A sighting first, so the intensity is above zero for the rises to show.",
        60, [{"step": 0, "kind": "seen"}, {"step": 11, "kind": "search_near", "distance": 1.0}, {"step": 21, "kind": "search_near", "distance": 2.0},
             {"step": 31, "kind": "search_near", "distance": 4.0}, {"step": 41, "kind": "search_near", "distance": 8.0},
             {"step": 51, "kind": "search_near", "distance": 12.0}], holds_nearness),
    "hurt-is-proportional-and-the-top-is-most": (
        "Thirty points of damage add thirty times hurt_per_point; a hundred and twenty more would pass `most`, and stop there.",
        20, [{"step": 5, "kind": "hurt", "points": 30}, {"step": 10, "kind": "hurt", "points": 120}], holds_hurt),
    "the-relax-ends-when-the-player-moves-on": (
        "A peak, a fade, then in the relax the player walks towards the exit a metre a second: the relax ends when they "
        "are relax_travel metres nearer, before its time is up.",
        420, sightings(5, 10, 15, 20) + [{"step": 0, "kind": "exit", "metres": 40}] + walking_on(200, 10, 39, 22),
        holds_early_relax),
    "hearing-adds-less-than-sight": (
        "A guard hears the player and rises a phase, then another sees it: each adds its own weight, hearing's less than sight's.",
        20, [{"step": 3, "kind": "heard"}, {"step": 13, "kind": "seen"}], holds_hearing),
    "nothing-happens-and-nothing-changes": (
        "No event: the intensity stays at zero, never below it, and the director stays building up.",
        30, [], holds_quiet),
}


def main(directory):
    folder = pathlib.Path(directory)
    failed = 0
    for name, (description, steps, events, holds) in CASES.items():
        result = run(steps, events)
        if not holds(result):
            print(f"{name}: does not show what its name says", file=sys.stderr)
            failed += 1
            continue
        vector = {"description": description, "steps": steps, "events": events,
                  "intensity": result["intensity"], "changes": result["changes"]}
        (folder / f"{name}.json").write_text(json.dumps(vector, indent=1) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: derive.py DIRECTORY", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
