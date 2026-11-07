"""A decision tree that reads the fighting opponent: fitted, published, and measured (T113).

    python3 -m gameaikit.cloning.opponent_tree --write godot/game/fighting
    python3 -m gameaikit.cloning.opponent_tree --check godot/game/fighting/opponent_tree.json
    python3 -m gameaikit.cloning.opponent_tree --report

The question is the one T17's n-gram answers: what will the player do next?
The n-gram answers from the last action alone, and learns during the fight.
The tree answers from the whole situation -- the same six words behaviour
cloning (T18) reads, cut from the same recordings -- and was fitted before
the fight on the player's training recordings, with the held-out ones kept
out, as `publish.py` keeps them out of the clone.

`--write` and `--check` work as `publish.py`'s do: the fit is deterministic,
so `--check` fits again and fails if the committed file differs, which is
how invariant 6's gate knows the tree came from here (N16).

`--report` is the page's table: at each depth, how often the tree guessed
right on the rows it was fitted on and on the held-out ones, beside the
n-gram. Training accuracy climbing while held-out accuracy does not is what
overfitting looks like, and on these few recordings it is what happens.

Exit codes: 0 written, up to date, or reported; 1 the committed file is
stale, or there are no held-out rows to report on; 2 wrong usage,
unreadable rows, or no recordings of that player.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from ..training import model_file, tree
from . import measure
from .rows import ROWS_PATH, Recorded, read

#: The top of the repository, which the rows path is relative to.
REPOSITORY = pathlib.Path(__file__).resolve().parents[3]
#: The file the game loads, under the folder given to `--write`.
FILE_NAME = "opponent_tree.json"
#: The name the tree is published under in the model file.
MODEL_NAME = "next action"
#: Whose recordings: the person's, as the clone's are.
PLAYER = "person"
#: How deep, and how few rows a leaf may hold. Three tests is a path the
#: panel can show whole. Chosen for the reading, not the score, and not on
#: the held-out fights, which would make them training data: `--report`
#: shows no depth doing much better there -- 133 held-out rows cannot tell
#: 20% from 23% -- and the deep ones doing worse. Five rows is about the
#: fewest a leaf's counts say anything with.
MAX_DEPTH = 3
MIN_LEAF = 5
#: The depths and leaf sizes the report fits, the published pair among them.
SWEEP = ((1, 1), (2, MIN_LEAF), (MAX_DEPTH, MIN_LEAF), (5, MIN_LEAF), (8, 2), (20, 1))


def fitted(recorded: Recorded, player: str, max_depth: int = MAX_DEPTH, min_leaf: int = MIN_LEAF) -> tree.Tree:
    """The tree fitted on `player`'s training recordings, the held-out ones left out."""
    training, _ = measure.split(recorded.of_player(player))
    return tree.fit(measure.rows_of(training), recorded.features, recorded.actions, max_depth, min_leaf)


def published(recorded: Recorded, player: str) -> dict:
    """The model file's content: what wrote it, on which recordings, and the tree."""
    training, held = measure.split(recorded.of_player(player))
    trained_on = {"player": player, "recordings": [session.recording for session in training],
                  "held_out": [session.recording for session in held],
                  "rows": len(measure.rows_of(training)), "max_depth": MAX_DEPTH, "min_leaf": MIN_LEAF}
    return model_file.as_json({MODEL_NAME: fitted(recorded, player)}, "gameaikit.cloning.opponent_tree",
                              trained_on=trained_on)


def as_text(document: dict) -> str:
    """The file as written: indented, keys in a fixed order, a newline at the end."""
    return json.dumps(document, indent=1) + "\n"


def accuracy(model: tree.Tree, rows: list) -> float:
    """How often the tree's likeliest answer was the one taken."""
    return sum(1 for situation, action in rows if model.likeliest(situation) == action) / len(rows)


def report(recorded: Recorded, player: str) -> int:
    """Print the depth sweep beside the n-gram; see the module's header for the exit code."""
    training, held = measure.split(recorded.of_player(player))
    rows, held_rows = measure.rows_of(training), measure.rows_of(held)
    print(f"player: {player}; fitted on {len(training)} recording(s), {len(rows)} decisions; "
          f"held out {len(held)}, {len(held_rows)} decisions")
    if not held_rows:
        print("FAIL: no held-out recordings to score on -- training accuracy is not a result.")
        return 1
    print(f"{'tree':<22}{'leaves':>8}{'fitted on':>11}{'held out':>10}")
    for depth, least in SWEEP:
        model = tree.fit(rows, recorded.features, recorded.actions, depth, least)
        mark = "  <- published" if (depth, least) == (MAX_DEPTH, MIN_LEAF) else ""
        print(f"{f'depth {depth}, leaf >= {least}':<22}{model.leaves():>8}{accuracy(model, rows):>11.1%}"
              f"{accuracy(model, held_rows):>10.1%}{mark}")
    floor = tree.fit(rows, recorded.features, recorded.actions, 0, 1)
    print(f"{'always the commonest':<22}{floor.leaves():>8}{accuracy(floor, rows):>11.1%}"
          f"{accuracy(floor, held_rows):>10.1%}  a tree of depth 0: the floor")
    ngram = measure.ngram_score(held, recorded.actions, recorded.reaction)
    print(f"{ngram.method:<22}{'':>8}{'-':>11}{ngram.accuracy():>10.1%}  {ngram.how}")
    print("a column 'fitted on' that climbs while 'held out' does not is the tree learning the rows, not the player.")
    return 0


def main(arguments: list[str]) -> int:
    """Write, check or report the opponent's tree; see the module's header."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--player", default=PLAYER, help="whose recordings")
    parser.add_argument("--rows", type=pathlib.Path, default=REPOSITORY / ROWS_PATH)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--write", type=pathlib.Path, metavar="FOLDER")
    action.add_argument("--check", type=pathlib.Path, metavar="FILE")
    action.add_argument("--report", action="store_true")
    options = parser.parse_args(arguments)
    try:
        recorded = read(options.rows)
    except (OSError, ValueError, KeyError) as problem:
        print(f"opponent_tree: cannot read the rows: {problem}", file=sys.stderr)
        return 2
    if not recorded.of_player(options.player):
        print(f"opponent_tree: no recordings of {options.player!r}; recorded: {', '.join(recorded.players())}",
              file=sys.stderr)
        return 2
    if options.report:
        return report(recorded, options.player)
    text = as_text(published(recorded, options.player))
    if options.check:
        fresh = options.check.is_file() and options.check.read_text(encoding="utf-8") == text
        print(f"{'ok' if fresh else 'STALE'}: {options.check} {'is' if fresh else 'is not'} what a fresh fit writes")
        return 0 if fresh else 1
    options.write.mkdir(parents=True, exist_ok=True)
    (options.write / FILE_NAME).write_text(text, encoding="utf-8")
    print(f"opponent_tree: {options.player} -> {options.write / FILE_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
