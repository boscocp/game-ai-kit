"""The player's standing (T164): fixed weights summed over the record.

`standing.json` holds one weight per verb and place for each virtue, each
with the reason a designer wrote. The standing is their sum over the
record's deeds: rebuilt, never saved, and never changed except by a deed
being added. It estimates nothing about the person and sets no difficulty
(ADR 0025). Godot's `Standing` is the same sum
(godot/game/valley/standing.gd).

    standing = Standing.read()
    standing.of(log)                    # {"care": -3, "fear": 3}
    standing.contributions(log, "care") # the deeds that sum to it
"""

from __future__ import annotations

import json
import pathlib

from gameaikit.valley.record import DeedLog

WEIGHTS = pathlib.Path(__file__).resolve().parents[3] / "godot" / "game" / "valley" / "standing.json"


class Standing:
    """The virtues, and each deed's authored weight for them."""

    def __init__(self, table: dict) -> None:
        self.virtues = list(table["virtues"])
        self.consequences = list(table["consequences"])
        self._rows = {(row["verb"], row["place"]): row for row in table["weights"]}

    @classmethod
    def read(cls, path: pathlib.Path = WEIGHTS) -> Standing:
        """The weights as `standing.json` writes them."""
        return cls(json.loads(path.read_text()))

    def weight(self, deed: dict, virtue: str) -> int:
        """The weight of `deed` for `virtue`, as a designer wrote it."""
        return self._rows[(deed["verb"], deed["place"])][virtue]

    def why(self, deed: dict) -> str:
        """Why `deed` weighs what it does, in the designer's words."""
        return self._rows[(deed["verb"], deed["place"])]["why"]

    def of(self, log: DeedLog) -> dict:
        """For each virtue, the sum of every deed's weight."""
        return {virtue: sum(self.weight(deed, virtue) for deed in log.deeds()) for virtue in self.virtues}

    def contributions(self, log: DeedLog, virtue: str) -> list[dict]:
        """The deeds that moved `virtue`, in order, each with its weight and reason."""
        return [{"deed": deed, "weight": self.weight(deed, virtue), "why": self.why(deed)}
                for deed in log.deeds() if self.weight(deed, virtue) != 0]
