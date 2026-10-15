"""What a learned model buys: the n-gram, two ghosts and the cloned model, compared.

    python3 python/gameaikit/cloning/compare.py --report

The table is the task (T18). For the player the published file was fitted
on, each method is scored on recordings held out of the fitting: how often
it guessed the player's next action, how many numbers it is, how long it
took to build, and -- measured by Godot, `make test-clone-fights` -- how
often an opponent driven by it beats the fixed opponent at medium.

Exits non-zero when there is no held-out set to score on: training accuracy
is not a result, and a comparison with no held-out split is a sales pitch.
Also when the win rates were measured on another file than the one
published, because a stale number in a comparison is the same pitch.

Exit codes: 0 reported; 1 no held-out rows, or win rates missing or stale;
2 wrong usage or unreadable files.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

if __package__ in (None, ""):
    # Run as a file, as the task's acceptance runs it: make the package importable.
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))

from gameaikit.cloning import measure  # noqa: E402
from gameaikit.cloning.publish import REPOSITORY, digest  # noqa: E402
from gameaikit.cloning.rows import ROWS_PATH, read  # noqa: E402

PUBLISHED = REPOSITORY / "godot/addons/ai_learning/clone_weights.json"
WIN_RATES = REPOSITORY / "data/cloning/win_rates.json"
#: Which game opponent each method is played by in the win-rate fights.
IN_THE_GAME = {"n-gram (T17)": "learner: medium", "ghost, exact": "ghost: exact",
               "ghost, nearest": "ghost: nearest", "model, the situation": "clone"}


def table(scores: list[measure.Score], wins: dict[str, str]) -> list[str]:
    """The comparison, one line a method, plain text."""
    lines = [f"{'method':<26}{'held-out':>10}{'numbers':>9}{'built in':>10}{'wins':>10}  how",
             "-" * 100]
    for score in scores:
        accuracy = f"{score.accuracy():.1%}"
        built = f"{score.seconds:.2f} s" if score.seconds else "-"
        lines.append(f"{score.method:<26}{accuracy:>10}{score.size:>9}{built:>10}"
                     f"{wins.get(score.method, '-'):>10}  {score.how}")
    return lines


def win_rates(published: pathlib.Path, measured: pathlib.Path) -> tuple[dict[str, str], str]:
    """Each method's wins against the fixed opponent, and what is wrong with them, or ""."""
    if not measured.exists():
        return {}, f"no win rates at {measured} -- run `make test-clone-fights`"
    rates = json.loads(measured.read_text(encoding="utf-8"))
    if rates.get("weights_sha256") != digest(published):
        return {}, f"{measured} measured another clone_weights.json -- run `make test-clone-fights` again"
    fights = rates["fights"]
    wins = {method: f"{rates['wins'][mode]}/{fights}" for method, mode in IN_THE_GAME.items() if mode in rates["wins"]}
    for mode in rates["wins"]:
        if mode.startswith("stand-in: "):
            wins[mode] = f"{rates['wins'][mode]}/{fights}"
    return wins, ""


def report(published: pathlib.Path, rows: pathlib.Path, measured: pathlib.Path) -> int:
    """Print the comparison; see the module's header for the exit code."""
    recorded = read(rows)
    player = json.loads(published.read_text(encoding="utf-8"))["trained_on"]["player"]
    training, held = measure.split(recorded.of_player(player))
    print(f"player: {player}; fitted on {len(training)} recording(s), "
          f"{len(measure.rows_of(training))} decisions; held out {len(held)}, {len(measure.rows_of(held))} decisions")
    if player != "person":
        print("  a stand-in, not a person: these numbers say the pipeline works, not what cloning a person buys")
    if not measure.rows_of(held):
        print("FAIL: no held-out recordings to score on -- training accuracy is not a result. Record more fights.")
        return 1
    scores, _, _ = measure.every_score(training, held, recorded.features, recorded.actions)
    wins, stale = win_rates(published, measured)
    print("\n".join(table(scores, wins)))
    if player in wins:
        print(f"{'the player itself':<26}{'':>10}{'':>9}{'':>10}{wins[player]:>10}  the stand-in, seated in the game")
    print("wins: of fights against the fixed opponent at medium; 'n-gram' is T17's learner at medium.")
    print("told apart by a person: not yet asked -- T18's manual check.")
    if stale:
        print(f"FAIL: {stale}")
        return 1
    return 0


def main(arguments: list[str]) -> int:
    """Parse the arguments and report."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--report", action="store_true", required=True, help="print the comparison table")
    parser.add_argument("--published", type=pathlib.Path, default=PUBLISHED)
    parser.add_argument("--rows", type=pathlib.Path, default=REPOSITORY / ROWS_PATH)
    parser.add_argument("--win-rates", type=pathlib.Path, default=WIN_RATES)
    options = parser.parse_args(arguments)
    try:
        return report(options.published, options.rows, options.win_rates)
    except (OSError, ValueError, KeyError) as problem:
        print(f"compare: cannot read what it needs: {problem}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
