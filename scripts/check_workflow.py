#!/usr/bin/env python3
"""Keep CI running the Makefile, and nothing of its own.

The rule
--------
Every `run:` step in the workflow is a `make` target that exists. A workflow
with its own copy of a command is a second definition of what the project
checks, and two definitions drift -- the drift being noticed only when CI passes
something that fails locally, or the reverse.

And every gate the Makefile knows about is reached by CI. A target that exists,
passes locally and is never run anywhere else is a check nobody is actually
running.

Why this gate exists
--------------------
Both halves were real here. The workflow hand-listed gate targets beside
`make check`, because `check` includes one that cannot run on a runner -- two
lists, drifting from their first edit. And the workflow's own header said every
job runs a Makefile target while one step inlined a block of python.

Exit codes
----------
0   CI and the Makefile agree
1   a step that is not a make target, or a gate CI never reaches
2   wrong usage, or a file that cannot be read

Usage
-----
    check_workflow.py [--repo PATH]
    check_workflow.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import subprocess
import sys
import tempfile

WORKFLOW = ".github/workflows/ci.yml"
MAKEFILE = "Makefile"

RUN_RE = re.compile(r"^\s*(?:-\s*)?run:\s*(.+?)\s*$", re.M)
# `${{ runner.temp }}` contains spaces, so splitting a command on whitespace
# tore it into two words that looked like missing make targets. It is collapsed
# to a placeholder before the command is read.
EXPRESSION_RE = re.compile(r"\$\{\{[^}]*\}\}")
TARGET_RE = re.compile(r"^([a-z][a-z0-9_-]*):", re.M)
PHONY_RE = re.compile(r"^\.PHONY:\s*(\S+)", re.M)

# Targets that are not gates and are not expected in CI.
NOT_A_GATE = {"help", "hooks", "wave-start", "wave-merge", "godot-version", "check"}


def make_targets(makefile: pathlib.Path) -> set[str]:
    """Every target the Makefile declares."""
    text = makefile.read_text(encoding="utf-8")
    return set(TARGET_RE.findall(text)) | set(PHONY_RE.findall(text))


def target_prerequisites(makefile: pathlib.Path, target: str) -> set[str]:
    """The targets `target` depends on, following one level of continuation."""
    text = makefile.read_text(encoding="utf-8")
    found = re.search(rf"^{re.escape(target)}:([^\n]*(?:\\\n[^\n]*)*)", text, re.M)
    if found is None:
        return set()
    body = found.group(1).replace("\\\n", " ")
    body = body.split("##")[0]
    return {word for word in body.split() if re.fullmatch(r"[a-z][a-z0-9_-]*", word)}


def workflow_commands(workflow: pathlib.Path) -> list[str]:
    """Every command a `run:` step executes, one per line of a block."""
    text = workflow.read_text(encoding="utf-8")
    commands = []
    for raw in RUN_RE.findall(text):
        if raw in ("|", ">"):
            # A block scalar: this gate wants single commands, and says so.
            commands.append("<multi-line block>")
            continue
        commands.append(EXPRESSION_RE.sub("EXPR", raw))
    return commands


def check(repo: pathlib.Path) -> list[str]:
    workflow = repo / WORKFLOW
    makefile = repo / MAKEFILE
    if not workflow.exists():
        return [f"W0 no workflow at {WORKFLOW}"]
    if not makefile.exists():
        return [f"W0 no {MAKEFILE}"]

    targets = make_targets(makefile)
    findings = []
    invoked: set[str] = set()

    commands = workflow_commands(workflow)
    if not commands:
        return [f"W1 {WORKFLOW} has no run: steps -- it checks nothing"]

    for command in commands:
        if command == "<multi-line block>":
            findings.append(
                f"W2 {WORKFLOW} has a multi-line run: block; put it in a make target "
                "so CI and a laptop run the same thing"
            )
            continue
        words = command.split()
        if words[0] != "make":
            findings.append(f"W3 {WORKFLOW} runs {command!r}, which is not a make target")
            continue
        for word in words[1:]:
            if "=" in word:
                continue  # a variable override, not a target
            if word not in targets:
                findings.append(f"W4 {WORKFLOW} runs `make {word}`, which the Makefile has not got")
            invoked.add(word)

    # Every gate `make check` depends on must be reached by CI, directly or
    # through a target CI does invoke.
    reachable = set(invoked)
    for target in list(invoked):
        reachable |= target_prerequisites(makefile, target)
    for gate in sorted(target_prerequisites(makefile, "check") - NOT_A_GATE):
        if gate not in reachable:
            findings.append(f"W5 `make {gate}` is in `make check` but CI never reaches it")

    return findings


def run(repo: pathlib.Path) -> int:
    findings = check(repo)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


MAKEFILE_TEXT = """\
.PHONY: check
check: lint-one lint-two test-python

.PHONY: lint-one
lint-one:
\t@true

.PHONY: lint-two
lint-two:
\t@true

.PHONY: test-python
test-python:
\t@true

.PHONY: help
help:
\t@true
"""

WORKFLOW_TEXT = """\
name: ci
jobs:
  gates:
    steps:
      - run: make lint-one lint-two
      - run: make test-python
"""


def self_test() -> int:
    failures = []

    def expect(label: str, got: tuple[int, str], want: int, code: str = "") -> None:
        exit_code, output = got
        if exit_code != want:
            failures.append(f"{label}: expected exit {want}, got {exit_code}")
        elif code and code not in output:
            failures.append(
                f"{label}: expected a {code} finding, got {output.strip() or 'nothing'!r}"
            )

    def quiet(repo: pathlib.Path) -> tuple[int, str]:
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            return run(repo), stream.getvalue()

    def build(root: pathlib.Path, name: str, makefile: str, workflow: str) -> pathlib.Path:
        repo = root / name
        (repo / ".github" / "workflows").mkdir(parents=True)
        (repo / MAKEFILE).write_text(makefile)
        (repo / WORKFLOW).write_text(workflow)
        return repo

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        expect("CI runs make targets", quiet(build(
            root, "good", MAKEFILE_TEXT, WORKFLOW_TEXT)), 0)

        # Planted: a step that is not a make target at all.
        expect("a raw command", quiet(build(root, "raw", MAKEFILE_TEXT,
            WORKFLOW_TEXT.replace("      - run: make test-python",
                                  "      - run: python3 scripts/something.py"))), 1, "W3")

        # Planted: a multi-line block, which is a second definition by nature.
        expect("a multi-line block", quiet(build(root, "block", MAKEFILE_TEXT,
            WORKFLOW_TEXT.replace("      - run: make test-python",
                                  "      - run: |\n          echo one\n          echo two"))), 1, "W2")

        # Planted: a target CI runs that the Makefile has not got.
        expect("a target that does not exist", quiet(build(root, "ghost", MAKEFILE_TEXT,
            WORKFLOW_TEXT.replace("make test-python", "make test-nothing"))), 1, "W4")

        # Planted: a gate in `make check` that CI never reaches.
        expect("a gate CI never runs", quiet(build(root, "missed", MAKEFILE_TEXT,
            WORKFLOW_TEXT.replace("      - run: make lint-one lint-two\n",
                                  "      - run: make lint-one\n"))), 1, "W5")

        # A variable override is not a target.
        expect("a variable override", quiet(build(root, "override", MAKEFILE_TEXT,
            WORKFLOW_TEXT.replace("make test-python", "make test-python PYTHON=python3.12"))), 0)

        # A GitHub expression holds spaces, and used to be torn into words
        # that looked like missing targets.
        expect("a github expression in an override", quiet(build(root, "expr", MAKEFILE_TEXT,
            WORKFLOW_TEXT.replace("make test-python",
                                  "make test-python TOOLCHAIN=${{ runner.temp }}/x"))), 0)

        # Planted: a workflow with no steps checks nothing.
        expect("no run steps", quiet(build(root, "nosteps", MAKEFILE_TEXT,
            "name: ci\njobs:\n  gates:\n    steps:\n      - uses: actions/checkout@abc\n")), 1, "W1")

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", (extra.returncode, ""), 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
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
        return run(repo)
    except OSError as error:
        print(f"check_workflow: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
