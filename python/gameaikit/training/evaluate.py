"""Measure the two models, and refuse to be impressed by an accuracy.

An accuracy on its own proves very little. 87.8% sounds good until you notice
that always answering "the attacker loses" scores 69.0% on the same rows, and
a *leak* in the features would produce a high number just as happily as
learning would. So there are four assertions here and each is a command with
an exit code:

    --assert-beats-majority-baseline      the model is worth more than the
                                          commonest answer, by a stated margin
    --shuffled-labels                     fit against labels that have been
      --assert-no-better-than-baseline    put in a meaningless order; the model
                                          must collapse to the baseline
    --assert-no-leak                      the holdout is really held out, and
                                          the score is not suspiciously perfect
    --assert-runs-under-seconds N         the whole pipeline still fits in a
                                          tier-1 afternoon

Run with no flags it prints the numbers and asserts nothing.

What the shuffled-label control does **not** catch
--------------------------------------------------
T5 introduced it with the sentence "a leak in the features produces the same
number", and that is not true of this control. Both leaks were planted and
measured:

* the label itself appended to every feature row -- the honest run scores
  **1.0000** and the shuffled control scores exactly the baseline, 0.6900, so
  the control **passes**;
* the holdout rows left in the training set as well -- the honest run scores
  0.8794 against an uncontaminated 0.8780, and again the control passes.

The reason is the same both times: shuffling the training labels destroys the
leaked relationship along with every honest one, so the model has nothing left
to exploit and collapses to the base rate whatever was wrong with the data.

The control is still worth running. What it actually tests is the *measuring
apparatus* -- that the score is computed against labels the fitting never saw,
and that the baseline is what it claims to be. A pipeline that scored against
its own training labels would sail through the control's shuffled run with a
high number, and that is a real mistake somebody makes once.

Catching the two leaks above needs the structural checks in `check_no_leak`,
which ask the questions directly rather than hoping a statistic notices.

Exit codes: 0 every assertion held, 1 one did not, 2 wrong usage.
"""

from __future__ import annotations

import argparse
import sys
import time

from .train import Fitted, Training, run

#: How much better than the baseline a model has to be before it is worth
#: shipping. Measured: the combat model is worth 18.8 points of accuracy and
#: the capture model saves 0.54 turns of error, so neither is near this line.
#: It is here so that a model that quietly stops learning fails rather than
#: passing by a hair.
LEAST_WORTH_SHIPPING = {"combat": 0.05, "capture": 0.10}

#: How much better than the baseline a model fitted to shuffled labels is
#: allowed to be. Not zero: the holdout is a few hundred rows and a fit to
#: noise can come out a hair either side of the baseline by luck. Measured, the
#: control lands at exactly the baseline for combat and slightly below it for
#: capture.
NOISE_ALLOWANCE = 0.02

#: A score at or above this is not a good model, it is a told model. Nothing
#: that predicts a fight decided by dice is right this often: measured, the
#: honest combat model scores 0.878, and appending the label to every feature
#: row scores 1.000.
TOO_GOOD = 0.99

#: The same rule for a model that answers with a number rather than a
#: yes-or-no: an average error this small is not a good fit either. Measured,
#: the honest capture model is wrong by 0.56 turns; planting `turns_taken` into
#: its own features gets the error to 0.0000.
#:
#: This half was missing, and the check was gated on the model being logistic
#: -- so the one leak it exists to catch passed silently on half the kit.
TOO_GOOD_AN_ERROR = 0.10


def describe(training: Training) -> list[str]:
    """The numbers, in the units each model is scored in."""
    return [
        f"games {training.games}",
        _line("combat", training.combat, "accuracy"),
        _line("capture", training.capture, "turns of error saved"),
    ]


def _line(name: str, fitted: Fitted, units: str) -> str:
    return (
        f"{name:8} score {fitted.score:+.4f}  baseline {fitted.baseline:+.4f}  "
        f"lookup {fitted.memoriser:+.4f}  gain {fitted.beats_baseline_by():+.4f} "
        f"({units}, {fitted.holdout_rows} held-back rows)"
    )


def check_beats_baseline(training: Training) -> list[str]:
    """Both models are worth more than answering without them."""
    findings = []
    for name, fitted in (("combat", training.combat), ("capture", training.capture)):
        margin = LEAST_WORTH_SHIPPING[name]
        if fitted.beats_baseline_by() < margin:
            findings.append(
                f"E1 {name} beat its baseline by only "
                f"{fitted.beats_baseline_by():+.4f}, and {margin:+.4f} is the "
                "least worth shipping"
            )
    return findings


def check_no_better_than_baseline(training: Training) -> list[str]:
    """Trained on nonsense, a model must learn nothing.

    A model that still beats the baseline here is not reading the game: it is
    reading something that survived the labels being scrambled, which in
    practice means the score is not being computed the way it claims. See the
    module docstring for what this does and does not catch -- it is weaker
    evidence than T5 took it for, and `check_no_leak` is where the leaks are
    actually caught.
    """
    findings = []
    for name, fitted in (("combat", training.combat), ("capture", training.capture)):
        if fitted.beats_baseline_by() > NOISE_ALLOWANCE:
            findings.append(
                f"E2 {name} was fitted to shuffled labels and still beat its "
                f"baseline by {fitted.beats_baseline_by():+.4f}; the score is "
                "not being measured against labels the fitting never saw"
            )
    return findings


def check_no_leak(training: Training) -> list[str]:
    """Ask the two leak questions directly, rather than hoping a score notices.

    Both of these are cheap and neither is statistical, which is the point: the
    shuffled-label control is a statistic, and a statistic cannot see a holdout
    that was never held out.
    """
    findings = []
    for name, fitted in (("combat", training.combat), ("capture", training.capture)):
        shared = fitted.training_games & fitted.holdout_games
        if shared:
            findings.append(
                f"E4 {name} was scored on {len(shared)} game(s) it was also "
                "trained on; the holdout is not held out"
            )
        findings += _why_it_is_too_good(name, fitted)
    return findings


def _why_it_is_too_good(name: str, fitted: Fitted) -> list[str]:
    """A score no honest fit to dice-driven data reaches, in the units of
    whichever model is being asked."""
    if fitted.model.kind == "logistic" and fitted.score >= TOO_GOOD:
        return [
            f"E5 {name} scored {fitted.score:.4f} on fights decided by dice; "
            "a model this certain has been told the answer"
        ]
    if fitted.model.kind == "linear" and -fitted.score <= TOO_GOOD_AN_ERROR:
        return [
            f"E5 {name} is wrong by only {-fitted.score:.4f} turns; a model "
            "this exact has been told the answer"
        ]
    return []


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--shuffled-labels", action="store_true")
    parser.add_argument("--assert-beats-majority-baseline", action="store_true")
    parser.add_argument("--assert-no-better-than-baseline", action="store_true")
    parser.add_argument("--assert-no-leak", action="store_true")
    parser.add_argument("--assert-runs-under-seconds", type=float, default=None)
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    started = time.perf_counter()
    training = run(shuffle_labels=args.shuffled_labels)
    took = time.perf_counter() - started

    for line in describe(training):
        print(line)
    print(f"pipeline took {took:.2f}s" + (" (labels shuffled)" if args.shuffled_labels else ""))

    findings = _assertions(args, training, took)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


def _assertions(args: argparse.Namespace, training: Training,
                took: float) -> list[str]:
    """Whichever assertions were asked for, in the order the flags read."""
    findings: list[str] = []
    if args.assert_beats_majority_baseline:
        findings += check_beats_baseline(training)
    if args.assert_no_better_than_baseline:
        findings += check_no_better_than_baseline(training)
    if args.assert_no_leak:
        findings += check_no_leak(training)
    budget = args.assert_runs_under_seconds
    if budget is not None and took > budget:
        findings.append(
            f"E3 the pipeline took {took:.2f}s and was given {budget:.0f}s"
        )
    return findings


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
