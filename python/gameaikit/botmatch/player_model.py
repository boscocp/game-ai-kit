"""How well the person plays, from counts, and what the bot match does about it.

Hamlet, a dynamic difficulty system on Valve's Half-Life engine, models the
damage a player takes as a distribution [Hunicke & Chapman]; Ocio Barriales
balances difficulty through the enemies' accuracy [GAP3 ch. 33]. This model
does the smallest honest version of both: it counts the damage the person's
bot dealt and took during this match, reads the share it dealt as a Beta
mean with a fixed prior, and a fixed table turns the share into the other
team's aim error, re-read every interval.

    share = (dealt + prior) / (dealt + taken + 2 * prior)

The prior is `prior_points` dealt and as many taken before the match
starts: an empty model reads 0.5, the table's middle row, and one burst of
fire cannot swing it to an end of the table. The hit rate,
(hits + 1) / (shots + 2), is kept and shown beside it, and sets nothing.

Each event is one addition, each read one division and a walk down five
rows. There is no step towards a target here, and no rating: an Elo or a
TrueSkill moves a value a step towards each result, which ADR 0016's
amendment refuses at game time.

When not to use it: to model a player across matches. It starts empty and
is never saved, so it is a reading of this person now, not a profile.

    model = PlayerModel()
    model.count({"step": 12, "kind": "hit", "points": 12})
    row = row_for(read_table(), model.damage_share(read_table()))
"""

from __future__ import annotations

import json
import pathlib

RULES = pathlib.Path(__file__).resolve().parents[3] / "godot" / "game3d" / "botmatch" / "rules.json"
# What each event kind adds to, and by how much: one, or its points.
KINDS = ("shot", "hit", "hurt", "kill", "death")


def read_rules(path: pathlib.Path = RULES) -> dict:
    """The bot match's rules, as `rules.json` writes them."""
    return json.loads(path.read_text())


def read_table(path: pathlib.Path = RULES) -> dict:
    """The difficulty table -- interval, prior and rows -- with the step it is
    counted in, so an interval is a whole number of steps on both sides."""
    rules = read_rules(path)
    table = dict(rules["difficulty"])
    table["interval_steps"] = round(table["interval"] / rules["step"])
    return table


class PlayerModel:
    """The person's counts during one match, and the two Beta means read off them."""

    def __init__(self) -> None:
        self.shots = 0
        self.hits = 0
        self.kills = 0
        self.deaths = 0
        self.dealt = 0
        self.taken = 0

    def count(self, event: dict) -> None:
        """Add one event of the person's bot: a shot fired, a hit landed (its
        points dealt), a hurt (its points taken), a kill or a death."""
        kind = event["kind"]
        if kind == "shot":
            self.shots += 1
        elif kind == "hit":
            self.hits += 1
            self.dealt += event["points"]
        elif kind == "hurt":
            self.taken += event["points"]
        elif kind == "kill":
            self.kills += 1
        elif kind == "death":
            self.deaths += 1
        else:
            raise ValueError(f"not an event the model counts: {kind!r}")

    def counts(self) -> dict:
        """Every count, by name, as the vectors write them."""
        return {"shots": self.shots, "hits": self.hits, "kills": self.kills,
                "deaths": self.deaths, "dealt": self.dealt, "taken": self.taken}

    def damage_share(self, table: dict) -> float:
        """The share of the damage the person dealt, with the table's prior:
        what the knob is read from."""
        prior = float(table["prior_points"])
        return (float(self.dealt) + prior) / (float(self.dealt + self.taken) + 2.0 * prior)

    def hit_rate(self) -> float:
        """Hits over shots with one of each before the match, Laplace's rule:
        shown beside the share, and setting nothing."""
        return (float(self.hits) + 1.0) / (float(self.shots) + 2.0)


def row_for(table: dict, share: float) -> int:
    """The index of the last row whose `from` the share reaches."""
    chosen = 0
    for index, row in enumerate(table["rows"]):
        if share >= row["from"]:
            chosen = index
    return chosen


def replay(table: dict, events: list[dict], last_step: int) -> list[dict]:
    """Every interval's reading over `events`, up to `last_step`.

    At each step that is a whole number of intervals from the start, before
    that step's events, the model reads the share and the table's row --
    what the game does at that step. Events are in order; each has the step
    it happened in.
    """
    model = PlayerModel()
    every = table["interval_steps"]
    readings = []
    pending = list(events)
    for tick in range(every, last_step + 1, every):
        while pending and pending[0]["step"] < tick:
            model.count(pending.pop(0))
        share = model.damage_share(table)
        row = row_for(table, share)
        readings.append({"step": tick, "counts": model.counts(), "share": share, "hit_rate": model.hit_rate(),
                         "row": row, "aim_error_degrees": table["rows"][row]["aim_error_degrees"]})
    return readings
