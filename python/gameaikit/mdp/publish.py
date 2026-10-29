"""Solve the maze by value iteration and write what Godot plays by.

    PYTHONPATH=python python3 -m gameaikit.mdp.publish --write godot/game/maze

Two files, both laid out by `maze.index`, one line per (Pac-Man's cell,
Blinky's cell, Blinky's heading) and sixteen slots on it, one per set of
pellets left:

* `values.json` -- each state's value in thousandths, a whole number so
  that Python and Godot read the same number; null for a slot no game
  reaches;
* `policy.json` -- each state's action as a letter (u, l, d, r), "." for
  no state. It is the greedy action over the *published* values, so a
  one-step lookahead in Godot over `values.json` finds the same action.

Solving is deterministic, so a fresh run writes the same bytes, and
`check_no_training.py` (N15) fails when the committed files are not what
this writes. That is invariant 6: Python solves, Godot looks up.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from gameaikit.mdp import maze, solve
from gameaikit.mdp.model import FiniteMdp

GENERATED_BY = "gameaikit.mdp.publish"
LETTERS = {"up": "u", "left": "l", "down": "d", "right": "r"}
NO_STATE = "."
VALUES_FILE = "values.json"
POLICY_FILE = "policy.json"
ABOUT = ("The maze's MDP (T98) solved by value iteration in Python; Godot only reads this. "
         "Laid out as spec/maze/mdp.json's 'about' says: row ((pacman x cells + ghost) x 4 + heading), "
         "slot = the pellets left as bits.")


def published_values(mdp: FiniteMdp, values: list[float]) -> list[float]:
    """The values as Godot reads them: rounded to thousandths, then divided back."""
    scale = maze.SPEC["published_scale"]
    return [round(value * scale) / scale for value in values]


def as_files(mdp: FiniteMdp, solution: solve.Solution) -> tuple[str, str]:
    """The text of `values.json` and of `policy.json`, from one solution."""
    scale = maze.SPEC["published_scale"]
    shown = published_values(mdp, solution.values)
    values: list[int | None] = [None] * maze.slots()
    letters = [NO_STATE] * maze.slots()
    for number, state in enumerate(mdp.states):
        slot = maze.index(state)
        values[slot] = round(shown[number] * scale)
        letters[slot] = LETTERS[mdp.actions[solve.greedy(mdp, shown, number)]]
    width = maze.ALL_PELLETS + 1
    value_rows = [values[start:start + width] for start in range(0, len(values), width)]
    letter_rows = ["".join(letters[start:start + width]) for start in range(0, len(letters), width)]
    head = {"about": ABOUT, "generated_by": GENERATED_BY, "states": len(mdp.states),
            "sweeps": solution.sweeps, "discount": mdp.discount, "scale": scale}
    return _with_rows(head, "values", value_rows), _with_rows(head, "actions", letter_rows)


def _with_rows(head: dict, key: str, rows: list) -> str:
    """`head` as JSON, then `key` holding `rows`, one row a line: a file a diff can read."""
    lines = [json.dumps(row, separators=(",", ":")) for row in rows]
    opening = json.dumps(head, indent=2)[:-2]
    return opening + f',\n  "{key}": [\n    ' + ",\n    ".join(lines) + "\n  ]\n}\n"


def run() -> tuple[str, str]:
    """Build the MDP, solve it, and return both files' text."""
    mdp = maze.build()
    return as_files(mdp, solve.value_iteration(mdp, maze.SPEC["epsilon"]))


def main(argv: list[str]) -> int:
    """Write both files into each folder named by --write."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="append", default=[], metavar="FOLDER")
    arguments = parser.parse_args(argv)
    if not arguments.write:
        parser.print_usage(sys.stderr)
        return 2
    values, policy = run()
    for folder in arguments.write:
        target = pathlib.Path(folder)
        target.mkdir(parents=True, exist_ok=True)
        (target / VALUES_FILE).write_text(values, encoding="utf-8")
        (target / POLICY_FILE).write_text(policy, encoding="utf-8")
        print(f"wrote {target / VALUES_FILE} and {target / POLICY_FILE}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
