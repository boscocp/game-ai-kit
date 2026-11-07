"""A random forest that reads the fighting opponent: fitted, published, and measured (T114).

    python3 -m gameaikit.cloning.opponent_forest --write godot/game/fighting
    python3 -m gameaikit.cloning.opponent_forest --check godot/game/fighting/opponent_forest.json
    python3 -m gameaikit.cloning.opponent_forest --report

The same question as T113's tree -- what will the player do next? -- on the
same rows, the same player and the same split, so the reader can put one
tree beside many. The published forest uses the published tree's depth and
leaf size, so the only differences are the ones that make it a forest:
each tree's bootstrap sample, a random subset of features at each node, and
the vote.

`--write` and `--check` work as `opponent_tree.py`'s do: the fit is seeded,
so `--check` fits again and fails if the committed file differs, which is
how invariant 6's gate knows the forest came from here (N18).

`--report` is the page's table: one tree against forests of 5, 25 and 100,
on the rows they were fitted on and on the held-out fights, at the published
depth and grown deep; and how far the held-out score moves when only the
seed changes, which is the variance a forest exists to take out.

Exit codes: 0 written, up to date, or reported; 1 the committed file is
stale, or there are no held-out rows to report on; 2 wrong usage,
unreadable rows, or no recordings of that player.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from ..training import forest, model_file, tree
from . import measure
from .opponent_tree import MAX_DEPTH, MIN_LEAF, MODEL_NAME, PLAYER, REPOSITORY, accuracy
from .rows import ROWS_PATH, Recorded, read

#: The file the game loads, under the folder given to `--write`.
FILE_NAME = "opponent_forest.json"
#: How many trees, and the seed they are drawn from. Chosen for the panel and
#: the cost, not on the held-out score, which would make the held-out fights
#: training data: 25 votes fit on the panel in five rows of five, and 25
#: walks of three tests are 75 comparisons a decision. The report shows 100
#: steadier still, at four times the walks.
TREES = 25
SEED = 1
#: The forest sizes the report compares with one tree -- 1 is a single tree
#: on a bootstrap, which the seed moves as it moves a forest -- and the depth
#: and leaf size pairs it fits them at: the published tree's, and grown deep,
#: as Breiman grew them.
SIZES = (1, 5, 25, 100)
SETTINGS = ((MAX_DEPTH, MIN_LEAF), (20, 1))
#: The seeds the report refits each forest with, to show how far it moves.
SEEDS = (1, 2, 3, 4, 5)


def fitted(recorded: Recorded, player: str, trees: int = TREES, max_depth: int = MAX_DEPTH,
           min_leaf: int = MIN_LEAF, seed: int = SEED) -> forest.Forest:
    """The forest fitted on `player`'s training recordings, the held-out ones left out."""
    training, _ = measure.split(recorded.of_player(player))
    return forest.fit(measure.rows_of(training), recorded.features, recorded.actions, trees, max_depth,
                      min_leaf, seed)


def published(recorded: Recorded, player: str) -> dict:
    """The model file's content: what wrote it, on which recordings, with what settings, and the forest."""
    training, held = measure.split(recorded.of_player(player))
    trained_on = {"player": player, "recordings": [session.recording for session in training],
                  "held_out": [session.recording for session in held],
                  "rows": len(measure.rows_of(training)), "trees": TREES, "max_depth": MAX_DEPTH,
                  "min_leaf": MIN_LEAF, "seed": SEED}
    return model_file.as_json({MODEL_NAME: fitted(recorded, player)}, "gameaikit.cloning.opponent_forest",
                              trained_on=trained_on)


def as_text(document: dict) -> str:
    """The file as written: indented like the tree's, but each node on one line.

    Twenty-five trees with one key per line would run to thousands of lines;
    a node per line keeps each tree a short block a person can read.
    """
    trees = document["models"][MODEL_NAME]["trees"]
    shell = json.loads(json.dumps(document))
    shell["models"][MODEL_NAME]["trees"] = [f"@tree {number}" for number in range(len(trees))]
    text = json.dumps(shell, indent=1)
    for number, nodes in enumerate(trees):
        block = "[\n" + ",\n".join("     " + json.dumps(node) for node in nodes) + "\n    ]"
        text = text.replace(json.dumps(f"@tree {number}"), block, 1)
    return text + "\n"


def report(recorded: Recorded, player: str) -> int:
    """Print one tree beside the forests and the n-gram; see the module's header for the exit code."""
    training, held = measure.split(recorded.of_player(player))
    rows, held_rows = measure.rows_of(training), measure.rows_of(held)
    print(f"player: {player}; fitted on {len(training)} recording(s), {len(rows)} decisions; "
          f"held out {len(held)}, {len(held_rows)} decisions")
    if not held_rows:
        print("FAIL: no held-out recordings to score on -- training accuracy is not a result.")
        return 1
    print(f"{'model':<40}{'fitted on':>10}{'held out':>10}{'held out, seeds 1-5':>22}")
    for depth, least in SETTINGS:
        single = tree.fit(rows, recorded.features, recorded.actions, depth, least)
        print(f"{f'one tree, depth {depth}, leaf >= {least}':<40}{accuracy(single, rows):>10.1%}"
              f"{accuracy(single, held_rows):>10.1%}{'(no seed)':>22}")
        for size in SIZES:
            print(_forest_line(rows, held_rows, recorded, size, depth, least))
    floor = tree.fit(rows, recorded.features, recorded.actions, 0, 1)
    print(f"{'always the commonest':<40}{accuracy(floor, rows):>10.1%}{accuracy(floor, held_rows):>10.1%}"
          "  the floor")
    ngram = measure.ngram_score(held, recorded.actions, recorded.reaction)
    print(f"{ngram.method:<40}{'-':>10}{ngram.accuracy():>10.1%}  {ngram.how}")
    print("a forest narrows how far the held-out score moves with the seed; it cannot find what the situation does not hold.")
    return 0


def _forest_line(rows: list, held_rows: list, recorded: Recorded, size: int, depth: int, least: int) -> str:
    """One forest's row: seed 1's two scores, and the lowest and highest held-out score over `SEEDS`."""
    scores = []
    for seed in SEEDS:
        grown = forest.fit(rows, recorded.features, recorded.actions, size, depth, least, seed)
        scores.append(accuracy(grown, held_rows))
        if seed == SEEDS[0]:
            first = grown
    mark = "  <- published" if (size, depth, least) == (TREES, MAX_DEPTH, MIN_LEAF) else ""
    spread = f"{min(scores):.1%} to {max(scores):.1%}"
    name = "1 tree, bootstrapped" if size == 1 else f"{size} trees"
    return (f"{f'{name}, depth {depth}, leaf >= {least}':<40}{accuracy(first, rows):>10.1%}"
            f"{scores[0]:>10.1%}{spread:>22}{mark}")


def main(arguments: list[str]) -> int:
    """Write, check or report the opponent's forest; see the module's header."""
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
        print(f"opponent_forest: cannot read the rows: {problem}", file=sys.stderr)
        return 2
    if not recorded.of_player(options.player):
        print(f"opponent_forest: no recordings of {options.player!r}; recorded: {', '.join(recorded.players())}",
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
    print(f"opponent_forest: {options.player} -> {options.write / FILE_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
