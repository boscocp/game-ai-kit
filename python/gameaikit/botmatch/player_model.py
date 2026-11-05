"""How well the person plays, from counts, and what the bot match does about it.

Hamlet, a dynamic difficulty system on Valve's Half-Life engine, models the
damage a player takes as a distribution [Hunicke & Chapman]; Ocio Barriales
balances difficulty through the enemies' accuracy [GAP3 ch. 33]. This model
does the smallest honest version of both: it counts the damage the person's
team dealt and took during this match, the person's bot's included, reads
the share it dealt as a Beta mean with a fixed prior, and a fixed table
turns the share into the other team's aim error, re-read every interval.

    share = (team_dealt + prior) / (team_dealt + team_taken + 2 * prior)

The prior is `prior_points` dealt and as many taken before the match
starts: an empty model reads 0.5, the table's middle row, and one burst of
fire cannot swing it to an end of the table. A share inside the table's
band moves nothing: the row read last stays, so a match that has come even
is left where it came even (T123). A seat on the other team empties the
counts, and the row goes back to the middle. The hit rate,
(hits + 1) / (shots + 2), is the person's bot's, kept and shown beside the
share, and sets nothing.

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
# The kinds of event the model counts: the person's bot's, a team-mate's
# hit or hurt, and a seat.
KINDS = ("shot", "hit", "hurt", "kill", "death", "mate_hit", "mate_hurt", "seat")
# What each kind adds one to, and what it adds its points to.
ADDS = {"shot": (("shots",), ()), "hit": (("hits",), ("dealt", "team_dealt")),
        "hurt": ((), ("taken", "team_taken")), "kill": (("kills",), ()), "death": (("deaths",), ()),
        "mate_hit": ((), ("team_dealt",)), "mate_hurt": ((), ("team_taken",))}
COUNTED = ("shots", "hits", "kills", "deaths", "dealt", "taken", "team_dealt", "team_taken")


def read_rules(path: pathlib.Path = RULES) -> dict:
    """The bot match's rules, as `rules.json` writes them."""
    return json.loads(path.read_text())


def read_table(path: pathlib.Path = RULES) -> dict:
    """The difficulty table -- interval, prior, band and rows -- with the step
    it is counted in, so an interval is a whole number of steps on both sides."""
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
        self.team_dealt = 0
        self.team_taken = 0
        self.team = -1
        self.restarts = 0

    def count(self, event: dict) -> None:
        """Add one event: of the person's bot, a shot, a hit (its points
        dealt), a hurt (its points taken), a kill or a death; of a team-mate,
        a hit or a hurt; or a seat, which on the other team empties the
        counts, since what the person did for one side says nothing of the
        other."""
        kind = event["kind"]
        if kind == "seat":
            self._seat(event["team"])
            return
        if kind not in ADDS:
            raise ValueError(f"not an event the model counts: {kind!r}")
        ones, sums = ADDS[kind]
        for name in ones:
            setattr(self, name, getattr(self, name) + 1)
        for name in sums:
            setattr(self, name, getattr(self, name) + event["points"])

    def _seat(self, seated: int) -> None:
        # On another team than the counts are of, they start empty; the
        # same team, or the first seat, keeps them.
        if self.team != -1 and seated != self.team:
            for name in COUNTED:
                setattr(self, name, 0)
            self.restarts += 1
        self.team = seated

    def counted_from_empty(self, event: dict) -> bool:
        """Count `event`, and say whether it emptied the counts -- after which
        the knob starts again from the middle row."""
        before = self.restarts
        self.count(event)
        return self.restarts != before

    def counts(self) -> dict:
        """Every count, by name, as the vectors write them."""
        return {**{name: getattr(self, name) for name in COUNTED}, "restarts": self.restarts}

    def damage_share(self, table: dict) -> float:
        """The share of the damage the person's team dealt, with the table's
        prior: what the knob is read from."""
        prior = float(table["prior_points"])
        return (float(self.team_dealt) + prior) / (float(self.team_dealt + self.team_taken) + 2.0 * prior)

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


def start_row(table: dict) -> int:
    """The row every match starts on, and a change of team starts again on:
    the one an empty model's share, 0.5, reaches."""
    return row_for(table, 0.5)


def in_band(table: dict, share: float) -> bool:
    """Whether the share is inside the band, from its `from` short of its `to`."""
    return table["band"]["from"] <= share < table["band"]["to"]


def next_row(table: dict, share: float, before: int) -> int:
    """The row a reading sets, `before` being the row read last: a share inside
    the band keeps it, any other takes its own row."""
    return before if in_band(table, share) else row_for(table, share)


def replay(table: dict, events: list[dict], last_step: int) -> list[dict]:
    """Every interval's reading over `events`, up to `last_step`.

    At each step that is a whole number of intervals from the start, before
    that step's events, the model reads the share and the table's row --
    what the game does at that step. Events are in order; each has the step
    it happened in. A seat that empties the counts puts the row back to the
    start, as the game does.
    """
    model = PlayerModel()
    every = table["interval_steps"]
    row = start_row(table)
    readings = []
    pending = list(events)
    for tick in range(every, last_step + 1, every):
        while pending and pending[0]["step"] < tick:
            if model.counted_from_empty(pending.pop(0)):
                row = start_row(table)
        share = model.damage_share(table)
        row = next_row(table, share, row)
        readings.append({"step": tick, "counts": model.counts(), "share": share, "hit_rate": model.hit_rate(),
                         "row": row, "aim_error_degrees": table["rows"][row]["aim_error_degrees"],
                         "held": in_band(table, share)})
    return readings
