"""Publish one recorded player: the model and the ghost's table, in one file.

    python3 -m gameaikit.cloning.publish --player "person" --write godot/addons/ai_learning
    python3 -m gameaikit.cloning.publish --check godot/addons/ai_learning/clone_weights.json

Both are fitted on the player's training recordings only -- the held-out ones
stay out of what the game ships, so the numbers `compare.py` prints are the
numbers of the file the game loads. The run is deterministic: `--check` fits
again and fails if the committed file is not what it writes, which is how
invariant 6's gate knows the weights came from here.

Exit codes: 0 written, or up to date; 1 the committed file is stale; 2 wrong
usage, unreadable rows, or no recordings of that player.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys

from . import measure
from .rows import ROWS_PATH, Recorded, read

#: The top of the repository, which the rows path is relative to.
REPOSITORY = pathlib.Path(__file__).resolve().parents[3]
#: The file the game loads, under the folder given to `--write`.
FILE_NAME = "clone_weights.json"


def published(recorded: Recorded, player: str) -> dict:
    """The file's content for `player`: what was fitted, on what, and the table."""
    training, held = measure.split(recorded.of_player(player))
    _, model, table = measure.every_score(training, held, recorded.features, recorded.actions)
    return {
        "generated_by": "gameaikit.cloning.publish",
        "trained_on": {
            "player": player,
            "recordings": [session.recording for session in training],
            "held_out": [session.recording for session in held],
            "rows": len(measure.rows_of(training)),
        },
        "features": recorded.features,
        "classes": recorded.actions,
        "model": {"kind": "softmax", "columns": model.columns, "weights": model.weights, "bias": model.bias},
        "cases": table.as_published(),
    }


def as_text(document: dict) -> str:
    """The file as written: indented, keys in a fixed order, a newline at the end."""
    return json.dumps(document, indent=1) + "\n"


def digest(path: pathlib.Path) -> str:
    """The sha256 of a published file: how a measurement says which file it measured."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main(arguments: list[str]) -> int:
    """Write or check the published player; see the module's header."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--player", help="whose recordings; by default, the one the --check file names")
    parser.add_argument("--rows", type=pathlib.Path, default=REPOSITORY / ROWS_PATH)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", type=pathlib.Path, metavar="FOLDER")
    action.add_argument("--check", type=pathlib.Path, metavar="FILE")
    options = parser.parse_args(arguments)
    try:
        recorded = read(options.rows)
        player = options.player or json.loads(options.check.read_text())["trained_on"]["player"]
    except (OSError, ValueError, KeyError, TypeError) as problem:
        print(f"publish: cannot read what it needs: {problem}", file=sys.stderr)
        return 2
    if not recorded.of_player(player):
        print(f"publish: no recordings of {player!r}; recorded: {', '.join(recorded.players())}", file=sys.stderr)
        return 2
    text = as_text(published(recorded, player))
    if options.check:
        fresh = options.check.read_text(encoding="utf-8") == text
        print(f"{'ok' if fresh else 'STALE'}: {options.check} {'is' if fresh else 'is not'} what a fresh fit writes")
        return 0 if fresh else 1
    options.write.mkdir(parents=True, exist_ok=True)
    (options.write / FILE_NAME).write_text(text, encoding="utf-8")
    print(f"publish: {player} -> {options.write / FILE_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
