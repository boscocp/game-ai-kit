"""Publish the learned checkers weights, the match, and the control beside them.

One artifact: `checkers_weights.json`, which the Godot game reads and never
writes (invariant 6). `check_no_training.py` trains again from the seed and
compares (N7), so the file in the repository is this pipeline's output.

    python3 -m gameaikit.checkers.report               print what was learned and how it played
    python3 -m gameaikit.checkers.report --write DIR   write checkers_weights.json

About eighty seconds: four hundred games of self-play, five fits, and a
thousand match games, all in pure Python.

Exit codes: 0 done, 2 wrong usage.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from ..training.models import DIGITS
from . import evaluation, selfplay
from .train import MATCH_SEED, Record, Trained, run

FILE_NAME = "checkers_weights.json"


def as_json(trained: Trained) -> dict:
    """Everything the game shows and the gate checks, rounded so text compares."""
    played = trained.played
    return {
        "generated_by": "gameaikit.checkers.report",
        "features": list(evaluation.FEATURES),
        "hand": {"weights": list(evaluation.HAND_WEIGHTS)},
        "learned": _model(trained.learned),
        "controls": [_model(control) for control in trained.controls],
        "without_advancement": {"weights": [round(weight, DIGITS) for weight in trained.without_advancement]},
        "self_play": {
            "seed": selfplay.SEED, "games": played.games, "distinct_games": played.distinct_games,
            "opening_plies": selfplay.OPENING_PLIES, "depth": selfplay.DEPTH,
            "won_by_red": played.won_by_red, "won_by_white": played.won_by_white, "drawn": played.drawn,
            "rows": len(played.rows), "every": selfplay.EVERY,
        },
        "match_seed": MATCH_SEED,
        "learned_against_hand": [_record(record) for record in trained.learned_matches],
        "controls_against_hand": [[_record(record) for record in records] for records in trained.control_matches],
        "without_advancement_against_hand": [_record(record) for record in trained.without_advancement_matches],
    }


def text(trained: Trained) -> str:
    """What was learned, and how it played, for a person."""
    played = trained.played
    lines = [f"self-play: {played.games} games from seed {selfplay.SEED}, {played.distinct_games} distinct; "
             f"red won {played.won_by_red}, white {played.won_by_white}, {played.drawn} drawn; "
             f"{len(played.rows)} positions from the decisive ones",
             "",
             f"{'':12} {'hand':>8} {'learned':>8} {'in sd':>8}"]
    for index, name in enumerate(evaluation.FEATURES):
        lines.append(f"{name:12} {evaluation.HAND_WEIGHTS[index]:>8.3f} {trained.learned.weights[index]:>8.3f} "
                     f"{trained.learned.comparable_weights[index]:>8.3f}")
    lines.append("")
    for index, learned in enumerate(trained.learned_matches):
        controls = ", ".join(f"{records[index].score():.3f}" for records in trained.control_matches)
        lines.append(f"depth {learned.depth}: learned {_words(learned)}; "
                     f"without advancement {_words(trained.without_advancement_matches[index])}; "
                     f"controls score {controls}")
    return "\n".join(lines) + "\n"


def write(directory: pathlib.Path, trained: Trained) -> pathlib.Path:
    """Write the weights file, and say where it went."""
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / FILE_NAME
    path.write_text(json.dumps(as_json(trained), indent=1) + "\n", encoding="utf-8")
    return path


def _model(model) -> dict:
    """A fitted model's weights, the same in standard deviations, and its bias."""
    return {"weights": [round(weight, DIGITS) for weight in model.weights],
            "comparable_weights": [round(weight, DIGITS) for weight in model.comparable_weights],
            "bias": round(model.bias, DIGITS), "rows_trained_on": model.rows_trained_on}


def _record(record: Record) -> dict:
    """One match, from the side of the weights being tried."""
    return {"depth": record.depth, "games": record.games, "won": record.won, "drawn": record.drawn,
            "lost": record.lost, "score": round(record.score(), DIGITS)}


def _words(record: Record) -> str:
    return f"won {record.won}, drew {record.drawn}, lost {record.lost} of {record.games} ({record.score():.3f})"


def main(argv: list[str]) -> int:
    """Print the report, or write the file to each `--write` folder."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="append", default=None, metavar="DIR")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    trained = run()
    if args.write:
        for directory in args.write:
            print(f"wrote {write(pathlib.Path(directory), trained)}")
    print(text(trained), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
