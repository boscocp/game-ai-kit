#!/usr/bin/env python3
"""Hold invariant 6: Python trains and emits weights, GDScript only infers.

The rule
--------
No training at game time. Fitting is a batch job that runs on a desk, writes a
file and is reviewed; inference is four multiplications in a frame. Mixing the
two is how a game ships a model nobody can reproduce, and the first symptom is
an opponent that plays differently on two machines and identically to no
recorded version of itself.

So the split is physical. `python/gameaikit/training/` descends a gradient;
`godot/addons/ai_learning/` multiplies published weights by a feature row and
stops. This gate is four claims about that split:

  * N1 no GDScript *code* uses the vocabulary of fitting;
  * N2 nothing in the inference addon writes a file, and nothing in GDScript
    writes over the weights;
  * N3 no GDScript assigns to a model's weights after it is built -- which is
    the update step itself, whatever it is called;
  * N4 the committed weights are the Python pipeline's own output, and a fresh
    run still produces them.

N4 is the one with teeth. The other three are about the shape of the code and
could all pass over a weights file somebody typed by hand.

What this gate cannot do
------------------------
Recognise a training loop written in innocent words. A function called
`_improve_the_numbers` that walks a gradient trips N1 on nothing and N3 only
if it assigns to something called `weights`. That hole is real and is left
open deliberately: the alternative is a list of verbs long enough to fire on
the word `fit` in a comment about a window, and a gate that fires on good code
teaches people to switch it off.

`train` is deliberately not in the vocabulary. This game's planner trains
units, in a domain written out in GDScript, and the word belongs to the game
before it belongs to machine learning.

Exit codes
----------
0   training lives on the Python side
1   violations found (each one printed)
2   wrong usage, or a file that cannot be read
3   the Python pipeline could not be run, so N4 checked nothing

Usage
-----
    check_no_training.py [--repo PATH] [--skip-retrain]
    check_no_training.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import math
import pathlib
import re
import subprocess
import sys
import tempfile

# Where each half of the split lives.
GODOT = pathlib.Path("godot")
LEARNING_ADDON = pathlib.Path("godot") / "addons" / "ai_learning"
WEIGHTS = LEARNING_ADDON / "weights.json"
TRAINER = "gameaikit.training.report"

# Third-party GDScript this project does not author.
VENDORED_DIRS = {"gdUnit4"}

# The vocabulary of fitting. Each entry is a word that has no other job in a
# game, which is the whole test for putting one here.
FITTING_WORDS = {
    "gradient": "the direction a fit moves in; a game has no use for one",
    "backprop": "the chain rule through a network, by its short name",
    "backpropagate": "the same, spelled out",
    "learning_rate": "how far along the gradient to step",
    "epoch": "one pass over a training set",
    "optimizer": "the thing that holds the update rule",
    "optimiser": "the same, spelled the other way",
    "sgd": "stochastic gradient descent, by its initials",
    "standardise": "centring and scaling rows, which happens before a fit",
    "standardize": "the same, spelled the other way",
}

WORD_RE = {word: re.compile(rf"\b{re.escape(word)}\b", re.I) for word in FITTING_WORDS}

# Writing a file. `FileAccess.WRITE` covers the two open modes that truncate;
# the store_* calls are what a writer then does, and are listed separately so
# a handle obtained some other way is still caught.
WRITING_RE = re.compile(
    r"FileAccess\.(?:WRITE|WRITE_READ)\b"
    r"|FileAccess\.open_encrypted\w*\s*\("
    r"|\.store_(?:string|var|line|buffer|8|16|32|64|float|double|real|csv_line)\s*\("
    r"|ResourceSaver\.save\s*\("
)

# Assigning to a model's numbers. Two shapes: writing another object's weights
# at all, and the compound assignment that *is* the update step.
MEMBER_WRITE_RE = re.compile(r"\b[A-Za-z_][\w.]*\.(weights|bias)\s*(?:\[[^\]]*\])?\s*=[^=]")
UPDATE_RE = re.compile(r"\b(weights|bias)\s*(?:\[[^\]]*\])?\s*(?:\+|-|\*|/)=")

# How far two runs of a deterministic pipeline may differ. The weights are
# published rounded to six decimals precisely so that two machines can agree
# on the text; this allows one unit in that last place and nothing more.
TOLERANCE = 1e-6


def gdscript_files(root: pathlib.Path) -> list[pathlib.Path]:
    """Every .gd file this project authors, vendored code excluded."""
    if not root.is_dir():
        return []
    return [
        path for path in sorted(root.rglob("*.gd"))
        if not any(part in VENDORED_DIRS for part in path.parts)
    ]


def code_only(text: str) -> str:
    """The same file with its comments and string literals blanked out.

    Prose about training is not training, and this gate would be unusable
    without that distinction: every file in the inference addon explains, in
    its header, what it is deliberately not doing. Blanked rather than removed
    so that line numbers survive.
    """
    kept = []
    for line in text.splitlines():
        kept.append(_strip_line(line))
    return "\n".join(kept)


def _strip_line(line: str) -> str:
    """One line, with anything quoted or commented replaced by spaces."""
    out = []
    quote = ""
    for character in line:
        if quote:
            out.append(" ")
            if character == quote:
                quote = ""
            continue
        if character in "\"'":
            quote = character
            out.append(" ")
            continue
        if character == "#":
            break
        out.append(character)
    return "".join(out)


def check_vocabulary(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N1: no GDScript code uses a word that only fitting needs."""
    findings = []
    for path in gdscript_files(root):
        code = code_only(path.read_text(encoding="utf-8"))
        for number, line in enumerate(code.splitlines(), start=1):
            for word, pattern in WORD_RE.items():
                if pattern.search(line):
                    findings.append(
                        f"N1 {_label(path, repo)}:{number} uses `{word}` in code -- "
                        f"{FITTING_WORDS[word]}"
                    )
    return findings


def check_writing(root: pathlib.Path, repo: pathlib.Path) -> list[str]:
    """N2 and N3: the addon writes nothing, and nobody rewrites the weights."""
    findings = []
    for path in gdscript_files(root):
        raw = path.read_text(encoding="utf-8").splitlines()
        code = code_only("\n".join(raw)).splitlines()
        inside_addon = LEARNING_ADDON.name in path.parts
        # Both spellings of the line. The write is read off the stripped one,
        # because `# we never FileAccess.WRITE here` is a sentence; the path
        # is read off the raw one, because a path *is* a string literal and
        # stripping it leaves the rule nothing to match. That was not a guess
        # -- the planted case for it passed until both were read.
        for number, (line, written) in enumerate(zip(raw, code), start=1):
            label = f"{_label(path, repo)}:{number}"
            if not WRITING_RE.search(written):
                continue
            if inside_addon:
                findings.append(
                    f"N2 {label} writes a file; the inference addon only reads")
            elif WEIGHTS.name in line:
                findings.append(f"N2 {label} writes over the weights file")
        for number, written in enumerate(code, start=1):
            if MEMBER_WRITE_RE.search(written) or UPDATE_RE.search(written):
                findings.append(
                    f"N3 {_label(path, repo)}:{number} assigns to a model's weights; "
                    "a fitted model is read-only at game time")
    return findings


def check_weights(repo: pathlib.Path, retrain: bool) -> tuple[list[str], bool]:
    """N4: the committed weights are what the Python pipeline produces.

    Returns the findings and whether the pipeline actually ran. A gate that
    quietly skips its only expensive claim is a gate reporting green about
    something it did not look at, so the caller turns a skip into its own
    exit code.
    """
    if not (repo / LEARNING_ADDON).is_dir():
        print(f"N0 note: no {LEARNING_ADDON} yet -- N4 inspected nothing")
        return [], True

    path = repo / WEIGHTS
    if not path.exists():
        return [f"N4 {WEIGHTS} is missing; run `make train`"], True
    committed = json.loads(path.read_text(encoding="utf-8"))
    if not str(committed.get("generated_by", "")).startswith(TRAINER):
        return [
            f"N4 {WEIGHTS} says it was generated by "
            f"{committed.get('generated_by')!r}, not by {TRAINER}"
        ], True

    if not retrain:
        return [], False
    fresh = fresh_weights(repo)
    if fresh is None:
        return [], False
    return differences_between(committed, fresh, WEIGHTS.name), True


def fresh_weights(repo: pathlib.Path) -> dict | None:
    """What the Python pipeline produces right now, or None if it cannot run."""
    sys.path.insert(0, str(repo / "python"))
    try:
        from gameaikit.training import report, train  # noqa: PLC0415
    except ImportError as error:
        print(f"N0 the training pipeline could not be imported: {error}")
        return None
    return report.as_json(train.run())


def differences_between(committed: object, fresh: object, where: str) -> list[str]:
    """Every place the committed weights and a fresh run disagree.

    Pure, and public, so a test can hand it two reports that differ in one
    specific way rather than training for four seconds to find out whether the
    rule works.
    """
    if isinstance(committed, dict) and isinstance(fresh, dict):
        return _differences_in_dicts(committed, fresh, where)
    if isinstance(committed, list) and isinstance(fresh, list):
        if len(committed) != len(fresh):
            return [f"N4 {where} has {len(committed)} entries, a fresh run has "
                    f"{len(fresh)}"]
        return [finding
                for index, (one, other) in enumerate(zip(committed, fresh))
                for finding in differences_between(one, other, f"{where}[{index}]")]
    if _both_numbers(committed, fresh):
        if not math.isclose(committed, fresh, rel_tol=0.0, abs_tol=TOLERANCE):
            return [f"N4 {where} is {committed}, and a fresh run gives {fresh}"]
        return []
    if committed != fresh:
        return [f"N4 {where} is {committed!r}, and a fresh run gives {fresh!r}"]
    return []


def _differences_in_dicts(committed: dict, fresh: dict, where: str) -> list[str]:
    """The same comparison over two objects, keys included."""
    findings = []
    for key in sorted(set(committed) | set(fresh)):
        if key not in committed:
            findings.append(f"N4 {where}.{key} is missing; run `make train`")
        elif key not in fresh:
            findings.append(f"N4 {where}.{key} is no longer produced by the pipeline")
        else:
            findings += differences_between(committed[key], fresh[key], f"{where}.{key}")
    return findings


def _both_numbers(one: object, other: object) -> bool:
    """True for two numbers, and false for the booleans that pretend to be."""
    return (isinstance(one, (int, float)) and not isinstance(one, bool)
            and isinstance(other, (int, float)) and not isinstance(other, bool))


def _label(path: pathlib.Path, repo: pathlib.Path) -> str:
    """The path as a reader would type it, when it is inside the repository."""
    try:
        return str(path.resolve().relative_to(repo.resolve()))
    except ValueError:
        return str(path)


def run(repo: pathlib.Path, retrain: bool = True) -> int:
    findings = check_vocabulary(repo / GODOT, repo)
    findings += check_writing(repo / GODOT, repo)
    weights_findings, ran = check_weights(repo, retrain)
    findings += weights_findings
    for finding in findings:
        print(finding)
    if findings:
        return 1
    return 0 if ran else 3


# --- self-test -------------------------------------------------------------


INFERENCE = """\
## Multiplies published weights by a row. Nothing here fits anything: the
## gradient descent that produced these numbers is in Python, and this file
## exists so that it stays there.
class_name LearnedModel
extends RefCounted

var weights: PackedFloat64Array
var bias: float


func _init(given: PackedFloat64Array, given_bias: float) -> void:
\tweights = given
\tbias = given_bias
"""

SOUND_WEIGHTS = {
    "generated_by": "gameaikit.training.report",
    "games": 1500,
    "feature_conventions": {"nearby_radius": 2},
    "models": {"combat": {"weights": [0.5081, 1.8326], "bias": 3.3937}},
}


def self_test() -> int:
    failures = []

    def expect(label: str, got: tuple[int, str], want: int, code: str = "") -> None:
        exit_code, output = got
        if exit_code != want:
            failures.append(f"{label}: expected exit {want}, got {exit_code} ({output!r})")
        elif code and code not in output:
            failures.append(
                f"{label}: expected a {code} finding, got {output.strip() or 'nothing'!r}")

    def quiet(repo: pathlib.Path) -> tuple[int, str]:
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            return run(repo, retrain=False), stream.getvalue()

    def build(root: pathlib.Path, name: str, files: dict[str, str]) -> pathlib.Path:
        repo = root / name
        for relative, text in files.items():
            path = repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return repo

    sound = {
        str(LEARNING_ADDON / "learned_model.gd"): INFERENCE,
        str(WEIGHTS): json.dumps(SOUND_WEIGHTS),
    }

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        # Inference beside a published weights file. This is the shape the
        # project promises and it must pass -- including the header above,
        # which says `gradient` in a comment about not having one.
        expect("inference only", quiet(build(root, "good", dict(sound))), 3)

        # Planted: the vocabulary of fitting, in code rather than in prose.
        expect("a learning rate in code", quiet(build(root, "rate", dict(
            sound, **{str(LEARNING_ADDON / "fitter.gd"):
                      "const learning_rate: float = 0.1\n"}))), 1, "N1")

        expect("a gradient in code", quiet(build(root, "grad", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "var gradient: float = 0.0\n"}))), 1, "N1")

        # The same word in a comment is prose about training, not training.
        expect("a gradient in a comment", quiet(build(root, "comment", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "# No gradient is computed here; see python/.\nvar steps: int = 0\n"}))), 3)

        # ...and in a string. The word has to be one the gate actually
        # looks for: this planted `"train_the_unit"` until a review pointed
        # out that `train` is deliberately absent from the vocabulary, so the
        # case passed whether or not strings were stripped at all.
        expect("a word inside a string", quiet(build(root, "string", dict(
            sound, **{str(GODOT / "game" / "domain.gd"):
                      'var label: String = "gradient of the hill"\n'}))), 3)

        # The planner's own domain, which is why `train` is not a word this
        # gate knows. A game that trains units is a game, not a fit.
        expect("the planner's domain", quiet(build(root, "domain", dict(
            sound, **{str(GODOT / "game" / "domain.gd"):
                      'var action: String = "train_the_unit"\n'}))), 3)

        # Planted: the inference addon writing a file.
        expect("the addon writes a file", quiet(build(root, "writes", dict(
            sound, **{str(LEARNING_ADDON / "saver.gd"):
                      'var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)\n'}))),
            1, "N2")

        # A file *read* is the addon's whole job.
        expect("the addon reads a file", quiet(build(root, "reads", dict(
            sound, **{str(LEARNING_ADDON / "loader.gd"):
                      'var file: FileAccess = FileAccess.open(path, FileAccess.READ)\n'}))), 3)

        # Planted: something outside the addon writing over the weights.
        expect("the game rewrites the weights", quiet(build(root, "rewrite", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      'var out: FileAccess = FileAccess.open("res://weights.json", FileAccess.WRITE)\n'}))),
            1, "N2")

        # Planted: the update step itself, under any name at all.
        expect("the update step", quiet(build(root, "update", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "\tweights[index] -= rate * error\n"}))), 1, "N3")

        expect("writing another model's weights", quiet(build(root, "member", dict(
            sound, **{str(GODOT / "game" / "ai.gd"):
                      "\tmodel.weights = fresh\n"}))), 1, "N3")

        # Setting one's own fields in a constructor is how a model is built.
        expect("a constructor", quiet(build(root, "ctor", dict(sound))), 3)

        # Planted: no weights file where the addon is.
        expect("no weights file", quiet(build(root, "noweights", {
            str(LEARNING_ADDON / "learned_model.gd"): INFERENCE})), 1, "N4")

        # Planted: weights nobody generated. The numbers may be perfect; what
        # is missing is any claim that a pipeline produced them.
        expect("hand-written weights", quiet(build(root, "byhand", dict(
            sound, **{str(WEIGHTS): json.dumps(
                dict(SOUND_WEIGHTS, generated_by="a person, carefully"))}))), 1, "N4")

        # No addon at all is the state of any checkout before T6, and of one
        # that took `ai_search` and left this behind: a note, not a finding.
        # Nothing infers, so nothing can be training to do it. Every case
        # above is what proves the gate can still fail.
        expect("no learning addon", quiet(build(root, "empty", {
            str(GODOT / "game" / "main.gd"): "var turn: int = 0\n"})), 0)

        # Planted: the two unreadable files. Both used to be a traceback on
        # exit 1, which every caller reads as a finding.
        broken = build(root, "brokenjson", dict(
            sound, **{str(WEIGHTS): "{ not json at all"}))
        expect("a weights file that is not JSON",
               (main(["--repo", str(broken), "--skip-retrain"]), ""), 2)

        unreadable = build(root, "notutf8", dict(sound))
        (unreadable / GODOT / "game" / "ai.gd").parent.mkdir(parents=True, exist_ok=True)
        (unreadable / GODOT / "game" / "ai.gd").write_bytes(b"var name := \xff\xfe\n")
        expect("a script that is not UTF-8",
               (main(["--repo", str(unreadable), "--skip-retrain"]), ""), 2)

        failures += _self_test_the_comparison()

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True)
        expect("unknown flag", (extra.returncode, ""), 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def _self_test_the_comparison() -> list[str]:
    """N4's own rule, handed two reports rather than a four-second pipeline."""
    failures = []
    fresh = json.loads(json.dumps(SOUND_WEIGHTS))

    if differences_between(SOUND_WEIGHTS, fresh, "w"):
        failures.append("two identical reports were reported as different")

    drifted = json.loads(json.dumps(SOUND_WEIGHTS))
    drifted["models"]["combat"]["weights"][0] = 0.5082
    if not differences_between(SOUND_WEIGHTS, drifted, "w"):
        failures.append("a weight that moved was not reported")

    rounded = json.loads(json.dumps(SOUND_WEIGHTS))
    rounded["models"]["combat"]["bias"] = 3.3937004
    if differences_between(SOUND_WEIGHTS, rounded, "w"):
        failures.append("a difference inside the published rounding was reported")

    renamed = json.loads(json.dumps(SOUND_WEIGHTS))
    renamed["feature_conventions"] = {"nearby_distance": 2}
    if len(differences_between(SOUND_WEIGHTS, renamed, "w")) != 2:
        failures.append("a renamed convention was not reported as both a loss and a gain")

    counted = json.loads(json.dumps(SOUND_WEIGHTS))
    counted["models"]["combat"]["weights"].append(0.0)
    if not differences_between(SOUND_WEIGHTS, counted, "w"):
        failures.append("a weight appearing from nowhere was not reported")
    return failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--skip-retrain", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    try:
        return run(repo, retrain=not args.skip_retrain)
    except (OSError, ValueError) as error:
        # ValueError as well as OSError, and the docstring promised it before
        # the code did. A malformed weights.json raises JSONDecodeError and a
        # .gd file that is not UTF-8 raises UnicodeDecodeError; both are
        # ValueErrors, both used to come out as a traceback on exit 1 -- the
        # code reserved for "violations found, each one printed", which is
        # indistinguishable from a finding to every caller.
        print(f"check_no_training: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
