"""Write the player model vectors in this directory.

Imports nothing from the repository: a third copy of the arithmetic, written
from the "about" of `godot/game3d/botmatch/rules.json`'s difficulty table in
plain dictionaries, so the readings come from neither implementation the
vectors hold. It also checks that each case shows what its name says -- a
vector named for the hard row that never reaches it would hold nothing.

    python3 spec/vectors/player_model/derive.py spec/vectors/player_model
"""
import json
import pathlib
import sys

RULES = json.loads((pathlib.Path(__file__).resolve().parents[3] / "godot" / "game3d" / "botmatch" / "rules.json").read_text())
TABLE = RULES["difficulty"]
EVERY = round(TABLE["interval"] / RULES["step"])
# What each kind adds one to, and what it adds its points to. A seat is
# neither: it is handled on its own.
ADDS = {"shot": (["shots"], []), "hit": (["hits"], ["dealt", "team_dealt"]), "hurt": ([], ["taken", "team_taken"]),
        "kill": (["kills"], []), "death": (["deaths"], []), "mate_hit": ([], ["team_dealt"]),
        "mate_hurt": ([], ["team_taken"])}
EMPTY = {"shots": 0, "hits": 0, "kills": 0, "deaths": 0, "dealt": 0, "taken": 0, "team_dealt": 0, "team_taken": 0}


def row_reached(share):
    return [index for index, row in enumerate(TABLE["rows"]) if share >= row["from"]][-1]


def middle():
    knob = RULES["knobs"]["aim_error_degrees"]
    return [index for index, row in enumerate(TABLE["rows"]) if row["aim_error_degrees"] == knob][0]


def run(events, last_step):
    counts = dict(EMPTY, restarts=0)
    seated = -1
    row = middle()
    readings = []
    for tick in range(EVERY, last_step + 1, EVERY):
        # The first window reaches back past step 0: a seat before the first
        # step is stamped -1.
        since = tick - EVERY if tick > EVERY else -1
        for event in [happening for happening in events if since <= happening["step"] < tick]:
            if event["kind"] == "seat":
                if seated not in (-1, event["team"]):
                    counts = dict(EMPTY, restarts=counts["restarts"] + 1)
                    row = middle()
                seated = event["team"]
                continue
            ones, sums = ADDS[event["kind"]]
            for name in ones:
                counts[name] += 1
            for name in sums:
                counts[name] += event["points"]
        prior = float(TABLE["prior_points"])
        share = (float(counts["team_dealt"]) + prior) / (float(counts["team_dealt"] + counts["team_taken"]) + 2.0 * prior)
        held = TABLE["band"]["from"] <= share < TABLE["band"]["to"]
        row = row if held else row_reached(share)
        readings.append({"step": tick, "counts": dict(counts), "share": share,
                         "hit_rate": (counts["hits"] + 1.0) / (counts["shots"] + 2.0),
                         "row": row, "aim_error_degrees": TABLE["rows"][row]["aim_error_degrees"], "held": held})
    return readings


def hits(steps, points=12):
    return [event for step in steps for event in ({"step": step, "kind": "shot"},
                                                   {"step": step, "kind": "hit", "points": points})]


def hurts(steps, points=12):
    return [{"step": step, "kind": "hurt", "points": points} for step in steps]


def seat(step, team):
    return [{"step": step, "kind": "seat", "points": 0, "team": team}]


def rows_of(readings):
    return [reading["row"] for reading in readings]


HARD = len(TABLE["rows"]) - 1

CASES = {
    "nothing-happens-and-it-stays-in-the-middle": (
        "No event in a minute: every reading is the prior's 0.5, the middle row, the knobs' own aim error.",
        6 * EVERY, [],
        lambda found: set(rows_of(found)) == {middle()} and all(reading["share"] == 0.5 for reading in found)),
    "dealing-damage-tightens-it-row-by-row": (
        "Twelve points dealt every second and six taken, for a minute: the share climbs, the row goes up through "
        "the one above the middle and stops at the hard one.",
        6 * EVERY, hits(range(0, 6 * EVERY, 20)) + hurts(range(0, 6 * EVERY, 40)),
        lambda found: rows_of(found) == sorted(rows_of(found)) and rows_of(found)[-1] == HARD
        and middle() + 1 in rows_of(found)),
    "taking-damage-eases-it-to-the-easy-row": (
        "Twelve points taken every second and six dealt, for a minute: down through the row below the middle to the "
        "easy one, and never past it.",
        6 * EVERY, hurts(range(0, 6 * EVERY, 20)) + hits(range(0, 6 * EVERY, 40)),
        lambda found: rows_of(found) == sorted(rows_of(found), reverse=True) and rows_of(found)[-1] == 0
        and middle() - 1 in rows_of(found)),
    "a-share-on-a-boundary-takes-that-row": (
        "Fifty points taken read exactly 100/250 = 0.4, the second row's from: that row. Eighty dealt and a hundred "
        "and twenty taken read exactly 180/400 = 0.45, the band's from: inside it, so the row stays the second. "
        "Two hundred and thirty dealt and a hundred and seventy taken read exactly 330/600 = 0.55, the band's to "
        "and the fourth row's from: outside the band, and that row.",
        3 * EVERY, hurts([10], 50) + hits([EVERY + 10], 80) + hurts([EVERY + 20], 70)
        + hits([2 * EVERY + 10], 150) + hurts([2 * EVERY + 20], 50),
        lambda found: [reading["share"] for reading in found] == [0.4, 0.45, 0.55] and rows_of(found) == [1, 1, 3]
        and [reading["held"] for reading in found] == [False, True, False]),
    "an-event-on-the-reading-step-waits-for-the-next": (
        "A hit in the very step of a reading is counted at the next one: the reading comes first in the step.",
        2 * EVERY, hits([EVERY], 100),
        lambda found: found[0]["counts"]["dealt"] == 0 and found[1]["counts"]["dealt"] == 100),
    "shots-kills-and-deaths-set-nothing": (
        "Forty shots, five kills and five deaths with no damage either way: the hit rate falls, the share stays at "
        "0.5 and the row in the middle -- only damage moves the knob.",
        2 * EVERY, [{"step": step, "kind": "shot"} for step in range(0, 2 * EVERY, 10)]
        + [{"step": 50 + step, "kind": kind} for step in range(5) for kind in ("kill", "death")],
        lambda found: set(rows_of(found)) == {middle()} and found[-1]["hit_rate"] < 0.1
        and found[-1]["counts"]["kills"] == 5),
    "a-person-who-wins-then-loses-is-eased-back": (
        "Dealing for half a minute, then taking twice as fast for a minute: up to the hard row, then down through "
        "the one above the middle to the easy one. The share falls past the band between two readings, so no "
        "reading is held on the way.",
        9 * EVERY, hits(range(0, 3 * EVERY, 20)) + hurts(range(3 * EVERY, 9 * EVERY, 10)),
        lambda found: max(rows_of(found)) == HARD and rows_of(found)[-1] == 0
        and middle() + 1 in rows_of(found)),
    "a-share-inside-the-band-moves-nothing": (
        "Dealing for twenty seconds reaches the hard row; then one blow of as much taken brings the share back to "
        "0.5, inside the band, for forty seconds: the row stays hard -- an even match is left where it came even.",
        6 * EVERY, hits(range(0, 2 * EVERY, 20)) + hurts([2 * EVERY + 10], 240),
        lambda found: rows_of(found)[1:] == [HARD] * 5 and found[-1]["share"] == 0.5 and found[-1]["held"]),
    "team-mates-damage-moves-the-share": (
        "The person deals nothing; a team-mate deals twelve points a second and another takes six: the share is "
        "the team's, so it climbs to the hard row while the person's own counts stay empty.",
        6 * EVERY, [{"step": step, "kind": "mate_hit", "points": 12} for step in range(0, 6 * EVERY, 20)]
        + [{"step": step, "kind": "mate_hurt", "points": 12} for step in range(0, 6 * EVERY, 40)],
        lambda found: rows_of(found)[-1] == HARD and found[-1]["counts"]["dealt"] == 0
        and found[-1]["counts"]["team_dealt"] > 0),
    "a-change-of-team-starts-from-empty": (
        "Seated on blue, the person deals for twenty seconds and reaches the hard row; then takes a bot on red: "
        "the counts start empty, the share is the prior's 0.5 and the row the middle one, with one restart counted.",
        4 * EVERY, seat(-1, 0) + hits(range(0, 2 * EVERY, 20)) + seat(2 * EVERY + 5, 1),
        lambda found: found[1]["row"] == HARD and rows_of(found)[2:] == [middle()] * 2
        and found[-1]["counts"] == dict(EMPTY, restarts=1)),
    "a-seat-on-the-same-team-keeps-the-counts": (
        "Seated on blue, the person deals for twenty seconds and reaches the hard row; then takes another blue "
        "bot: the counts carry on, and so does the row.",
        4 * EVERY, seat(-1, 0) + hits(range(0, 2 * EVERY, 20)) + seat(2 * EVERY + 5, 0),
        lambda found: rows_of(found)[1:] == [HARD] * 3 and found[-1]["counts"]["dealt"] == 120 * 2
        and found[-1]["counts"]["restarts"] == 0),
}


def main(directory):
    target = pathlib.Path(directory)
    for name, (description, last_step, events, holds) in CASES.items():
        events = sorted(events, key=lambda event: event["step"])
        found = run(events, last_step)
        if not holds(found):
            print(f"derive.py: {name} does not show what its name says: {rows_of(found)}", file=sys.stderr)
            return 1
        vector = {"description": description, "last_step": last_step, "events": events, "readings": found}
        (target / f"{name}.json").write_text(json.dumps(vector, indent=1) + "\n")
    print(f"derive.py: {len(CASES)} vectors written to {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).parent))
