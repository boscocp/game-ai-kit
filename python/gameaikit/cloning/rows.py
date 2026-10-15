"""The recorded decisions, read from the rows file Godot writes.

A row is a situation -- six words, one per feature -- and the action the
player took in it. Rows come grouped by the recording they were cut from,
because a recording is the unit of the split: rows from one fight are not
independent of each other, and a held-out set that shared fights with the
training set would be measuring memory.
"""

from __future__ import annotations

import json
import pathlib
from dataclasses import dataclass, field

#: Where the game's rows live, from the top of the repository.
ROWS_PATH = pathlib.Path("data/cloning/rows.json")

#: A situation: feature name to word.
Situation = dict[str, str]


@dataclass
class Session:
    """One recording's decisions, oldest first."""

    recording: str
    player: str
    characters: list[str]
    rows: list[tuple[Situation, str]] = field(default_factory=list)

    def actions(self) -> list[str]:
        """What the player did, in order: what the n-gram is shown."""
        return [action for _, action in self.rows]


@dataclass
class Recorded:
    """Everything in the rows file: the features, the actions, the sessions."""

    features: list[str]
    actions: list[str]
    sessions: list[Session]

    def of_player(self, player: str) -> list[Session]:
        """The sessions recorded of `player`, by recording name."""
        return sorted((s for s in self.sessions if s.player == player), key=lambda session: session.recording)

    def players(self) -> list[str]:
        """Every player recorded, by name."""
        return sorted({session.player for session in self.sessions})


def read(path: pathlib.Path) -> Recorded:
    """The rows file at `path`. Raises ValueError, saying why, on a bad one."""
    document = json.loads(path.read_text(encoding="utf-8"))
    header = document["header"]
    features, actions = list(header["features"]), list(header["actions"])
    sessions = []
    for entry in document["sessions"]:
        about = entry["about"]
        session = Session(about["recording"], about["player"], list(about["characters"]))
        for row in entry["rows"]:
            if len(row) != len(features) + 1 or row[-1] not in actions:
                raise ValueError(f"{about['recording']}: a row is not {len(features)} words and an action: {row}")
            session.rows.append((dict(zip(features, row[:-1])), row[-1]))
        sessions.append(session)
    return Recorded(features, actions, sessions)
