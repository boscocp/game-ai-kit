#!/usr/bin/env python3
"""Refuse a Godot `-s` line in the Makefile that does not run through `godot_checked.py`.

The rule
--------
T141: every `-s` script the `Makefile` starts -- a gate, a measurement, a
recording -- starts as `$(PYTHON) scripts/godot_checked.py res://...`, not
as `$(GODOT) ... -s res://...`. The few that may not are named below, one
target and one script at a time, each with its reason.

Why this gate exists
--------------------
A `SCRIPT ERROR` in a `-s` script aborts the function it happens in, and
the script carries on to its summary and `quit(0)`; an aborted typed
function hands back an empty answer that reads like "nothing wrong"
(CLAUDE.md's traps). Only the output can tell, and `godot_checked.py` reads
it. Before wave 180 about eighty lines started Godot directly, and the next
gate written by copying one of them would have done the same.

What it reads
-------------
Each line, joined to the lines its trailing backslashes continue, so
`$(GODOT) --path godot \\` with `-s` on the next line is still one command.

* A Godot is `$(GODOT)`, `${GODOT}`, `scripts/godot` (not
  `scripts/godot_checked.py`), or any variable or `define` whose value
  holds one of those -- `GODOT_RUN := $(GODOT) --headless` makes
  `$(GODOT_RUN)` a Godot too.
* A script is what follows `-s` or Godot's long form, `--script`.
* A recipe is a line that starts with a tab, or what follows `;` on a
  rule's own line (`test-y: ; $(GODOT) -s ...`).
* A Godot with a script anywhere else -- a variable, a `define` body -- is
  refused whatever ALLOWED says: an allowance names a target, and a
  command hidden in a variable has none.

A run with no script -- a scene opened in a window, `--import`,
`--version` -- is not this gate's business. An allowance that matches no
line is a finding too: an exception nobody uses is one somebody will reuse
without reading why it was there.

Exit codes
----------
0   every `-s` line runs through the wrapper, or is allowed by name
1   a line that bypasses it (target, line and script printed), a Godot
    script outside a recipe, or an allowance that matches nothing
2   wrong usage, or the Makefile cannot be read

Usage
-----
    check_godot_checked.py [--makefile PATH]
    check_godot_checked.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent

#: (target, script) -> why that one line starts Godot itself. Keep it short:
#: every entry is a gate whose engine errors nobody reads.
ALLOWED = {
    ("test-godot", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"):
        "gdUnit4's runner reports a failed test itself, and its suites provoke "
        "engine errors on purpose (push_error, a planted bad script) as they test",
    ("test-godot-some", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"):
        "the same runner as test-godot, on the suites SUITES names",
}

#: The name of the variable the Makefile keeps `scripts/godot` in.
GODOT_VARIABLE = "GODOT"
ASSIGNMENT = re.compile(r"^\s*(?:(?:override|export)\s+)*([A-Za-z_][A-Za-z0-9_]*)\s*(?::{1,3}=|\?=|\+=|!=|=)(.*)$")
DEFINE = re.compile(r"^\s*(?:(?:override|export)\s+)*define\s+([A-Za-z_][A-Za-z0-9_]*)")
RULE_HEAD = re.compile(r"^([A-Za-z0-9_.%/$(){}-]+(?:\s+[A-Za-z0-9_.%/$(){}-]+)*)\s*:(?![:=])")
SCRIPT_FLAG = re.compile(r"(?:^|\s)(?:-s|--script)(?:\s+|=)(\S+)")


def logical_lines(text: str) -> list[tuple[int, str]]:
    """Each line with the lines its trailing backslashes continue, and where it starts."""
    joined: list[tuple[int, str]] = []
    pending = ""
    start = 0
    for number, line in enumerate(text.splitlines(), start=1):
        if not pending:
            start = number
        if line.endswith("\\"):
            pending += line[:-1] + " "
            continue
        joined.append((start, pending + line))
        pending = ""
    if pending:
        joined.append((start, pending))
    return joined


def variables(lines: list[tuple[int, str]]) -> tuple[dict[str, str], set[int]]:
    """Every variable's value (a `define`'s body included), and the lines inside a `define`.

    Why the bodies' lines are kept apart: they may start with a tab, and a
    tab there does not make them a recipe.
    """
    values: dict[str, str] = {}
    in_define: set[int] = set()
    defining: str | None = None
    for number, line in lines:
        if defining is not None:
            if line.strip() == "endef":
                defining = None
            else:
                values[defining] = values.get(defining, "") + "\n" + line
                in_define.add(number)
            continue
        define = DEFINE.match(line)
        assignment = ASSIGNMENT.match(line) if not line.startswith("\t") else None
        if define:
            defining = define.group(1)
        elif assignment:
            values[assignment.group(1)] = values.get(assignment.group(1), "") + " " + assignment.group(2)
    return values, in_define


def godot_pattern(names: set[str]) -> re.Pattern[str]:
    """A Godot: `scripts/godot` itself, or any of `names` expanded, in either bracket."""
    spelled = [rf"\$\({re.escape(name)}\)|\$\{{{re.escape(name)}\}}" for name in sorted(names)]
    return re.compile("|".join([*spelled, r"scripts/godot(?![\w.])"]))


def godot_names(values: dict[str, str]) -> set[str]:
    """`GODOT`, and every variable whose value holds a Godot, followed until none is new."""
    names = {GODOT_VARIABLE}
    while True:
        pattern = godot_pattern(names)
        found = {name for name, value in values.items() if name not in names and pattern.search(value)}
        if not found:
            return names
        names |= found


def recipe_of(line: str, target: str) -> tuple[str, str | None, str]:
    """The target a line belongs to now, the target its recipe runs for, and the recipe text.

    The second is None for a line outside every recipe; its text is still
    returned, so a Godot script hidden there is seen.
    """
    if line.startswith("\t"):
        return target, target, line
    if ASSIGNMENT.match(line):
        return target, None, line
    head = RULE_HEAD.match(line)
    if head is None:
        return target, None, line
    after = line[head.end():]
    recipe = after.split(";", 1)[1] if ";" in after else ""
    return head.group(1), head.group(1), recipe


def direct_runs(text: str) -> list[tuple[str | None, int, str]]:
    """Every Godot started with a script outside the wrapper: (target or None, line, script)."""
    lines = logical_lines(text)
    values, in_define = variables(lines)
    pattern = godot_pattern(godot_names(values))
    found: list[tuple[str | None, int, str]] = []
    target = ""
    for number, line in lines:
        if number in in_define:
            owner, command = None, line
        else:
            target, owner, command = recipe_of(line, target)
        for godot in pattern.finditer(command):
            script = SCRIPT_FLAG.search(command, godot.end())
            if script:
                found.append((owner, number, script.group(1)))
    return found


def findings(text: str, allowed: dict[tuple[str, str], str]) -> list[str]:
    """What is wrong with the Makefile `text`, each said for a person; empty when nothing."""
    runs = direct_runs(text)
    problems = [
        f"Makefile:{number}: a Godot run of {script} outside a recipe (a variable or a define); "
        f"write it in its recipe, through scripts/godot_checked.py"
        for target, number, script in runs if target is None
    ]
    problems += [
        f"Makefile:{number}: {target} starts Godot on {script} without "
        f"scripts/godot_checked.py, so an engine error in its output would pass"
        for target, number, script in runs if target is not None and (target, script) not in allowed
    ]
    used = {(target, script) for target, _, script in runs}
    problems += [f"allowed {target} on {script}, but no line does that; take it out of ALLOWED"
                 for target, script in allowed if (target, script) not in used]
    return problems


def check(makefile: pathlib.Path, allowed: dict[tuple[str, str], str]) -> int:
    """Read `makefile`, print each finding; the exit code."""
    try:
        text = makefile.read_text(encoding="utf-8")
    except OSError as error:
        print(f"check_godot_checked: cannot read {makefile}: {error}", file=sys.stderr)
        return 2
    problems = findings(text, allowed)
    for problem in problems:
        print(problem)
    if not problems:
        print(f"check_godot_checked: every -s line runs through godot_checked.py, "
              f"{len(allowed)} allowed by name")
    return 1 if problems else 0


def quiet_check(makefile: pathlib.Path, allowed: dict[tuple[str, str], str]) -> int:
    """`check`, with what it prints swallowed: a planted finding is not news."""
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return check(makefile, allowed)


GOOD = """\
GODOT := ./scripts/godot
PLANT := --expect-error "planted"

.PHONY: test-x
check: test-x
test-x: import ## A gate
\t@$(PYTHON) scripts/godot_checked.py $(PLANT) res://test/x.gd -- a b
\t@$(GODOT) --path godot res://game/x.tscn

.PHONY: test-runner
test-runner: import ## A runner allowed by name
\t@$(GODOT) --headless --path godot \\
\t\t-s res://runner.gd -a test
"""
ONE_ALLOWED = {("test-runner", "res://runner.gd"): "planted"}
BYPASS = "\t@$(GODOT) --headless --path godot -s res://test/y.gd\n"


def planted_makefiles() -> list[tuple[str, str, dict[tuple[str, str], str], int]]:
    """(what is planted, the Makefile, what it allows, the exit code it must get)."""
    return [
        ("every line through the wrapper, one allowed", GOOD, ONE_ALLOWED, 0),
        ("a gate that starts Godot itself", GOOD + "test-y:\n" + BYPASS, ONE_ALLOWED, 1),
        ("the wrapper bypassed through the script's own path",
         GOOD + "test-y:\n" + BYPASS.replace("$(GODOT)", "./scripts/godot"), ONE_ALLOWED, 1),
        ("${GODOT}", GOOD + "test-y:\n" + BYPASS.replace("$(GODOT)", "${GODOT}"), ONE_ALLOWED, 1),
        ("Godot's long form, --script", GOOD + "test-y:\n" + BYPASS.replace(" -s ", " --script "), ONE_ALLOWED, 1),
        ("-s on a continued line", GOOD + "test-y:\n\t@$(GODOT) --headless --path godot \\\n"
         "\t\t-s res://test/y.gd\n", ONE_ALLOWED, 1),
        ("inside a shell sequence", GOOD + "test-y:\n\t@stub & \\\n\t\t$(GODOT) --headless --path godot "
         "-s res://y.gd; kill $$stub\n", ONE_ALLOWED, 1),
        ("a recipe on the rule's own line",
         GOOD + "test-y: import ; $(GODOT) --headless --path godot -s res://test/y.gd\n", ONE_ALLOWED, 1),
        ("a variable wrapping Godot", GOOD + "GODOT_RUN := $(GODOT) --headless --path godot\n"
         "test-y:\n\t@$(GODOT_RUN) -s res://test/y.gd\n", ONE_ALLOWED, 1),
        ("a variable holding the whole run", GOOD + "RUN_Y = $(GODOT) --headless -s res://test/y.gd\n",
         ONE_ALLOWED, 1),
        ("a define holding the run", GOOD + "define RUN_Y\n\t$(GODOT) --headless -s res://test/y.gd\nendef\n",
         ONE_ALLOWED, 1),
        ("the allowed script under a second target, the first still there",
         GOOD + "test-other: import\n\t@$(GODOT) --headless --path godot -s res://runner.gd\n", ONE_ALLOWED, 1),
        ("an allowance no line uses", GOOD, {**ONE_ALLOWED, ("test-z", "res://z.gd"): "stale"}, 1),
        ("the runner, with nothing allowed", GOOD, {}, 1),
    ]


def self_test() -> int:
    """Each planted Makefile gets the exit code it must; 0 if all of them do."""
    failures = 0
    with tempfile.TemporaryDirectory() as scratch:
        makefile = pathlib.Path(scratch) / "Makefile"
        for name, text, allowed, expected in planted_makefiles():
            makefile.write_text(text, encoding="utf-8")
            got = quiet_check(makefile, allowed)
            if got != expected:
                print(f"self-test: {name}: exit {got}, expected {expected}")
                failures += 1
        makefile.unlink()
        if quiet_check(makefile, ONE_ALLOWED) != 2:
            print("self-test: a missing Makefile: expected exit 2")
            failures += 1
    print(f"check_godot_checked self-test: {failures} failure(s)")
    return 1 if failures else 0


def main() -> int:
    """Parse the arguments and run the check or its self-test."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0], allow_abbrev=False)
    parser.add_argument("--makefile", type=pathlib.Path, default=ROOT / "Makefile")
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    if arguments.self_test:
        return self_test()
    return check(arguments.makefile, ALLOWED)


if __name__ == "__main__":
    sys.exit(main())
