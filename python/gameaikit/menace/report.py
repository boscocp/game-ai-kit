"""Publish MENACE's beads, and say how strong each age of it is.

One artifact: `menace_beads.json`, the bead counts in every box at each
snapshot, which the Godot game plays by and never changes (invariant 6).
`check_no_training.py` trains again from the seed and compares, so the file
in the repository is the one this pipeline writes, not one typed by hand.

    python3 -m gameaikit.menace.report                 print each age's record
    python3 -m gameaikit.menace.report --write DIR     write menace_beads.json
    python3 -m gameaikit.menace.report --seeds 10      the same training from ten seeds

Exit codes: 0 done, 2 wrong usage.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

from . import board as game
from .matchbox import REWARDS, STARTING_BEADS, Menace
from .opponents import perfect_move, random_move
from .train import AGAINST_RANDOM, SEED, SNAPSHOTS, greedy_record, run

FILE_NAME = "menace_beads.json"

#: The games each age is measured over, and the seed of the opponent's dice.
MEASURED_GAMES = 1000
MEASURE_SEED = 7


def as_json(snapshots: dict[int, Menace]) -> dict:
    """Every snapshot's boxes, with what the game needs to read them."""
    return {
        "generated_by": "gameaikit.menace.report",
        "seed": SEED,
        "against_random": AGAINST_RANDOM,
        "starting_beads": {str(pieces): beads for pieces, beads in STARTING_BEADS.items()},
        "rewards": dict(REWARDS),
        "symmetries": [list(symmetry) for symmetry in game.SYMMETRIES],
        "snapshots": {
            str(age): {"games": age, "boxes": dict(sorted(menace.boxes.items()))}
            for age, menace in sorted(snapshots.items())
        },
    }


def text(snapshots: dict[int, Menace]) -> str:
    """Each age's record against both opponents, playing its favourite bead."""
    lines = [f"MENACE, seed {SEED}: {AGAINST_RANDOM} games against a random player, then a perfect one.",
             f"Each age plays its most-beaded move, {MEASURED_GAMES} games against each opponent.",
             ""]
    for age, menace in sorted(snapshots.items()):
        random_record = greedy_record(menace, MEASURED_GAMES, MEASURE_SEED, random_move)
        perfect_record = greedy_record(menace, MEASURED_GAMES, MEASURE_SEED, perfect_move)
        lines.append(f"after {age:>5} games  vs random: {_record(random_record)}"
                     f"   vs perfect: {_record(perfect_record)}")
    return "\n".join(lines) + "\n"


def spread(seeds: int) -> str:
    """The 10- and 10,000-game machines' losses from `seeds` different seeds.

    The published file is one seed. This is how far that seed can be trusted
    to speak for Michie's rules: the doc quotes these numbers, not one run's.
    """
    lines = ["losses in 1000 games, playing the favourite bead",
             "seed   10 vs random  10k vs random   10 vs perfect  10k vs perfect"]
    for seed in range(1, seeds + 1):
        snapshots = run(seed)
        young, old = snapshots[min(SNAPSHOTS)], snapshots[max(SNAPSHOTS)]
        losses = [greedy_record(machine, MEASURED_GAMES, MEASURE_SEED, opponent)[game.NOUGHT]
                  for opponent in (random_move, perfect_move) for machine in (young, old)]
        lines.append(f"{seed:>4} {losses[0]:>13} {losses[1]:>14} {losses[2]:>15} {losses[3]:>15}")
    return "\n".join(lines) + "\n"


def _record(record: dict[str, int]) -> str:
    return (f"won {record[game.CROSS]:>4}, drew {record[game.DRAW]:>4}, "
            f"lost {record[game.NOUGHT]:>4}")


def write(directory: pathlib.Path, snapshots: dict[int, Menace]) -> pathlib.Path:
    """Write the bead file, and say where it went."""
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / FILE_NAME
    path.write_text(as_text(as_json(snapshots)), encoding="utf-8")
    return path


def as_text(published: dict) -> str:
    """The JSON with each list of numbers on one line, so a box reads as one
    line in a diff -- `"....X...O": [291, 1124, 1466, 0, 0, 1035, 0, 0, 0]` --
    rather than eleven.
    """
    spread = json.dumps(published, indent=1)
    return re.sub(r"\[\s*([-\d,\s]+?)\s*\]",
                  lambda found: "[" + ", ".join(found.group(1).split()).replace(",,", ",") + "]",
                  spread) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--write", action="append", default=None, metavar="DIR")
    parser.add_argument("--seeds", type=int, default=0, metavar="N")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    if args.seeds:
        print(spread(args.seeds), end="")
        return 0
    snapshots = run()
    if args.write:
        for directory in args.write:
            print(f"wrote {write(pathlib.Path(directory), snapshots)}")
        return 0
    print(text(snapshots), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
