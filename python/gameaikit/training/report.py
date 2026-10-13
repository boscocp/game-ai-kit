"""Write the weights out, and the sentence that explains them.

Two artifacts, because they are for two different readers. `weights.json` is
for the game: raw weights, a bias, and the feature order they go with.
`weights.txt` is for a person, and it is the one that matters here -- a model
whose weights nobody can read is a model nobody can argue with, and the whole
reason this kit fits a logistic regression rather than a small network is that
four numbers can be argued with.

    python3 -m gameaikit.training.report                 print the dump
    python3 -m gameaikit.training.report --check         assert it is sound
    python3 -m gameaikit.training.report --write DIR     write both artifacts

Exit codes: 0 sound, 1 a finding (each one printed), 2 wrong usage.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from ..dataset.rows import CAPTURE_FEATURES, COMBAT_FEATURES
from ..dataset.board import CHEAPEST_GROUND, DEAREST_GROUND
from ..dataset.simulate import NEARBY, WIDTH
from .train import DATA_SEED, SPLIT_SEED, Fitted, Training, run

#: Numbers the *game* has to know to build a feature row, and could otherwise
#: work out wrongly from its own board.
#:
#: Both were discovered by writing the GDScript side of `health_difference` and
#: its three neighbours and finding that two of the four could not be computed
#: from the board alone:
#:
#: * `nearby_radius` is how close another unit has to be to count towards
#:   `numeric_advantage`. It is a rule of the simulator, invisible in the
#:   weights, and a game using 1 or 3 instead feeds the model a feature that is
#:   not the one it was fitted to;
#: * `reinforcement_distance_when_alone` is the sentinel a unit with no living
#:   friends reports. It is the *training* board's width, which is the point:
#:   a game whose board is twelve wide and which helpfully reports 12 is
#:   reporting "quite far", where the model was taught "nobody is coming";
#: * `cheapest_ground` and `dearest_ground` are the range of terrain the data
#:   was gathered on. Every board in `simulate.py` draws its costs from it and
#:   none of them has a wall, so a game with a wall or with ground costing 6
#:   is asking the model about terrain it has never seen. Publishing the range
#:   lets the game say so -- see `BoardFeatures` -- instead of extrapolating
#:   in silence.
#:
#: They are published rather than documented because a number two languages
#: must agree on, living in two files, is a number that will one day differ.
FEATURE_CONVENTIONS = {
    "nearby_radius": NEARBY,
    "reinforcement_distance_when_alone": WIDTH,
    "cheapest_ground": CHEAPEST_GROUND,
    "dearest_ground": DEAREST_GROUND,
}

#: What each model is for, in the words someone would use to ask for it.
QUESTIONS = {
    "combat": "will this attack work?",
    "capture": "how long will this node take?",
}


def dump(training: Training) -> str:
    """The whole report, as the text written to `weights.txt`."""
    lines = [
        "game-ai-kit: what the two models learned",
        "=" * 40,
        "",
        f"Trained on {training.games} simulated games (dice seed {DATA_SEED}).",
        f"A quarter of the games were held back by seed {SPLIT_SEED} and never",
        "fitted on -- held back whole, because several fights come out of one",
        "game and they share a board, a set of units and a run of dice.",
        "",
        _how_to_read(),
    ]
    lines += _section("combat", training.combat, COMBAT_FEATURES)
    lines += _section("capture", training.capture, CAPTURE_FEATURES)
    lines += _conventions_block()
    lines += _capture_caveat(training)
    return "\n".join(lines) + "\n"


def _how_to_read() -> str:
    """The paragraph without which the numbers below get read wrongly."""
    return (
        "How to read the two columns\n"
        "---------------------------\n"
        "`per unit` is what the game applies: multiply it by the raw number --\n"
        "a health difference of 7, terrain of 3 -- and add the bias.\n"
        "`per sd` is the same model with every feature put on one scale, and it\n"
        "is the column to compare across rows. A big `per unit` weight on a\n"
        "feature that never varies much is not an important feature; it is a\n"
        "feature measured in small units.\n"
    )


def _section(name: str, fitted: Fitted, features: tuple[str, ...]) -> list[str]:
    """One model: how it scored, and what it concluded, strongest first."""
    lines = [
        "",
        QUESTIONS[name],
        "-" * len(QUESTIONS[name]),
        f"  {fitted.model.rows_trained_on} rows trained on, "
        f"{fitted.holdout_rows} held back",
        *[f"  {line}" for line in _score_sentence(name, fitted)],
        "",
        f"  {'feature':<24}{'per unit':>12}{'per sd':>12}",
    ]
    for feature, raw, comparable in fitted.model.by_importance():
        lines.append(f"  {feature:<24}{raw:>+12.4f}{comparable:>+12.4f}")
    lines.append(f"  {'(bias)':<24}{fitted.model.bias:>+12.4f}")
    if set(features) != set(fitted.model.features):
        lines.append("  WARNING: these are not the features the dataset declares")
    return lines


def _score_sentence(name: str, fitted: Fitted) -> list[str]:
    """The score beside the thing it has to beat, in that model's own units.

    Always beside it. An accuracy on its own is unreadable -- 87.8% sounds
    good and would be poor on a set where 95% of fights go one way -- so the
    baseline is never printed on a different line from the score.
    """
    if name == "combat":
        return [
            f"right about {fitted.score:.1%} of held-back fights, against",
            f"{fitted.baseline:.1%} for always saying 'the attacker loses'",
            f"and {fitted.memoriser:.1%} for looking the fight up in a table",
            "of the fights it was trained on",
        ]
    return [
        f"wrong by {-fitted.score:.2f} turns on average, against",
        f"{-fitted.baseline:.2f} for always guessing the training mean",
        f"and {-fitted.memoriser:.2f} for looking the situation up in a table",
        "of the games it was trained on",
    ]


def _conventions_block() -> list[str]:
    """The numbers a game needs that are not weights.

    In the readable dump as well as in the JSON, because a person comparing
    the game's behaviour against this file has to be able to see that the
    radius the game counted friends within is the radius the data was built
    with.
    """
    return [
        "",
        "What the game needs to know that is not a weight",
        "------------------------------------------------",
        f"  nearby_radius = {NEARBY}: how close another unit must be to count",
        "  towards numeric_advantage.",
        f"  reinforcement_distance_when_alone = {WIDTH}: what a unit with no",
        "  living friends reports. It is the training board's width, so it sits",
        "  outside every real distance -- a game that reports its own, smaller",
        "  width instead is saying 'far' where the data said 'nobody is coming'.",
        f"  terrain ran from {CHEAPEST_GROUND} to {DEAREST_GROUND}, and no board here has a",
        "  wall on it. Anything outside that range is extrapolation, and the",
        "  game is expected to clamp rather than to invent a number.",
    ]


def _capture_caveat(training: Training) -> list[str]:
    """The two things about this data a reader has to be told.

    The numbers come from the run that is printing them. They were constants
    here, which meant a sixty-game report quoting the thousand-game figures --
    measured prose inside generated output, which is the one place a stale
    number is indistinguishable from a fresh one.
    """
    combat = training.combat
    return [
        "",
        "Two things the numbers above do not say",
        "---------------------------------------",
        "  The lookup table is the honest yardstick, not the majority class.",
        "  These features are small integers, so most held-back rows have an",
        f"  exact twin among the rows that were trained on -- {combat.twinned_share:.0%}",
        f"  of them, over {combat.distinct_rows} distinct situations. A table that",
        "  answers with the twin's outcome already scores most of what the",
        "  model scores, and the majority class flatters both. Four weights",
        "  cannot memorise that many answers, so this model's score is honest;",
        "  one with capacity would have to be read against the table rather",
        "  than against the majority.",
        "",
        "  The capture rows are censored, and not in the obvious way. Only a",
        "  game where somebody took the node writes one, and the rest end with",
        "  one side destroyed instead. Measured over 2000 games of this",
        "  simulator: 1392 captures, 608 wipe-outs and none at all running out",
        "  of turns. So the missing rows are the lopsided games, and lopsided",
        "  is exactly what `own_units` and `enemy_units` measure.",
    ]


def as_json(training: Training) -> dict:
    """Both models in the shape `ai_learning` will read back in T6."""
    return {
        "generated_by": "gameaikit.training.report",
        "games": training.games,
        "data_seed": DATA_SEED,
        "split_seed": SPLIT_SEED,
        "feature_conventions": dict(FEATURE_CONVENTIONS),
        "models": {
            "combat": training.combat.model.to_dict(),
            "capture": training.capture.model.to_dict(),
        },
    }


def write(directory: pathlib.Path, training: Training) -> list[pathlib.Path]:
    """Write `weights.json` and `weights.txt`, and say where they went."""
    directory.mkdir(parents=True, exist_ok=True)
    weights = directory / "weights.json"
    readable = directory / "weights.txt"
    weights.write_text(json.dumps(as_json(training), indent=2) + "\n", encoding="utf-8")
    readable.write_text(dump(training), encoding="utf-8")
    return [weights, readable]


def check() -> list[str]:
    """Train twice, and hold the result up against everything it must satisfy."""
    return findings_for(as_json(run()), as_json(run()))


def findings_for(first: dict, second: dict) -> list[str]:
    """Everything that has to be true of a report before it is worth writing.

    Takes the two runs rather than performing them, so a test can hand these
    rules a report that is wrong in one specific way and watch them say so.
    A rule that can only be exercised by running the real pipeline is a rule
    nobody can plant a case against -- which is how `PlanningVector` ended up
    with nine of them in the wave before this one.

    The first finding is the one with teeth. Training twice and demanding the
    same weights is what makes a committed `weights.json` mean anything: a
    pipeline that drifts between runs cannot be reviewed, because the diff is
    noise either way.
    """
    findings = []
    if first != second:
        findings.append("W1 two runs of the same pipeline produced different weights")

    findings += _check_conventions(first.get("feature_conventions"))
    for name, model in sorted(first["models"].items()):
        findings += _check_model(name, model)
    return findings


def _check_conventions(published: dict | None) -> list[str]:
    """The feature conventions are there, and are numbers a game can use.

    A missing block is the finding that matters. The game reads these to build
    a row, and the one thing worse than publishing the wrong radius is
    publishing none -- the reader then falls back on a number of its own, which
    is the arrangement this block exists to end.
    """
    if not isinstance(published, dict):
        return ["W6 the report publishes no feature_conventions block"]
    findings = []
    for name in sorted(FEATURE_CONVENTIONS):
        value = published.get(name)
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            findings.append(
                f"W6 feature_conventions.{name} is {value!r}, and the game needs "
                "a positive whole number"
            )
    return findings


def _check_model(name: str, model: dict) -> list[str]:
    """One model's published numbers: present, finite, and the right shape."""
    declared = {"combat": COMBAT_FEATURES, "capture": CAPTURE_FEATURES}[name]
    findings = []
    if tuple(model["features"]) != declared:
        findings.append(
            f"W2 {name} publishes {model['features']}, and the dataset declares "
            f"{list(declared)}"
        )
    # Both columns, not just the first. `comparable_weights` is the one a
    # person reads to decide what the model learned, and it was unchecked: a
    # model could publish four sound weights beside four zeros, or beside three
    # of them, and nothing here would have said so.
    for column in ("weights", "comparable_weights"):
        if len(model[column]) != len(model["features"]):
            findings.append(f"W3 {name} has {len(model[column])} {column} for "
                            f"{len(model['features'])} features")
        if all(weight == 0.0 for weight in model[column]):
            findings.append(f"W5 {name} learned nothing: every {column} is zero")
        for number in model[column]:
            if not _is_a_number(number):
                findings.append(f"W4 {name} published {number} in {column}, "
                                "which is not a number")
    if not _is_a_number(model["bias"]):
        findings.append(f"W4 {name} published {model['bias']} as its bias, "
                        "which is not a number")
    return findings


def _is_a_number(value: float) -> bool:
    """False for nan and for either infinity.

    Both halves matter and the second was dropped once already, while this
    function was being widened to cover a second column: a bias of `inf`
    passed every rule here, and `json.dump` writes `Infinity` without
    complaint for the game to load.
    """
    return value == value and value not in (float("inf"), float("-inf"))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--check", action="store_true")
    # Repeatable: one training run, written to every directory given. The
    # staging copy under dist/ and the copy the game loads come out of the
    # same fit, which is the only way the two can be asserted to agree.
    parser.add_argument("--write", action="append", default=None, metavar="DIR")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.check:
        findings = check()
        for finding in findings:
            print(finding)
        print(f"report: {'ok' if not findings else str(len(findings)) + ' finding(s)'}")
        return 1 if findings else 0

    training = run()
    if args.write:
        for directory in args.write:
            for path in write(pathlib.Path(directory), training):
                print(f"wrote {path}")
        return 0

    print(dump(training), end="")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
