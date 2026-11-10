#!/usr/bin/env python3
"""Keep the project's import on one thread, where a cold import does not crash.

The rule
--------
`godot/project.godot` sets, in its `[editor]` section:

    import/use_multiple_threads=false

Why this gate exists
--------------------
On 4.7.2 a cold `--import` -- a new worktree, or after `git clean` -- with
the setting at its default, `true`, crashed in 11 of 115 runs: signal 11
(exit 139) on a worker thread reimporting the CSV translation tables, or
SIGABRT (exit 134) at shutdown. With it `false`, in none of 160 runs, 50 of
them beside two other checkouts' `make check`. A similar crash, with the
same workaround, is reported upstream (godotengine/godot#125245); whether it
is the same race is not known. The setting is the one thing this project
can turn. docs/godot/cold-import.md has the counts, the error, and when to
take this line out again.

The line is easy to lose: the editor rewrites `project.godot` whenever a
setting changes in its dialog, and a line nobody remembers the reason for is
a line somebody tidies away. The crash it prevents came back between one cold
import in five and one in fifty, and in none of a reviewer's thirty, so the
run that loses it will most likely pass.

Exit codes
----------
0   the setting is there, and false
1   it is missing, true, or outside `[editor]` (said which). Godot keeps
    the last of two assignments to one key, so this reads the last too
2   wrong usage, or `project.godot` cannot be read

Usage
-----
    check_import_threads.py [--godot-dir PATH]
    check_import_threads.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import sys
import tempfile

SECTION = "[editor]"
KEY = "import/use_multiple_threads"
WANTED = "false"


def setting_in(text: str) -> tuple[str | None, str | None]:
    """The section the key sits in and the value it has, or (None, None).

    Read line by line, not with configparser: `project.godot` is Godot's own
    format, and its values (`PackedStringArray(...)`) are not INI's. The
    LAST assignment under `[editor]` is the one returned, because Godot's
    loader sets each line in order and the last one wins: `=false` then
    `=true`, from a hand edit or a merge, imports on several threads. Only
    when `[editor]` has none is a match elsewhere returned, to be named.
    """
    section: str | None = None
    found: tuple[str | None, str | None] = (None, None)
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line
            continue
        key, sign, value = line.partition("=")
        if sign and key.strip() == KEY and (section == SECTION or found[0] != SECTION):
            found = (section, value.strip())
    return found


def findings(text: str) -> list[str]:
    """What is wrong with the setting in this `project.godot`; empty if nothing."""
    section, value = setting_in(text)
    if value is None:
        return [f"{KEY} is missing from {SECTION}; add `{KEY}={WANTED}`"]
    if section != SECTION:
        return [f"{KEY} is under {section}, not {SECTION}, so Godot ignores it"]
    if value != WANTED:
        return [f"{KEY} is {value}; a cold --import with threads on crashed "
                f"on 4.7.2 (docs/godot/cold-import.md)"]
    return []


def check(godot_dir: pathlib.Path) -> int:
    """Read the project file under `godot_dir` and report; the exit code."""
    project = godot_dir / "project.godot"
    try:
        text = project.read_text(encoding="utf-8")
    except OSError as error:
        print(f"check_import_threads: cannot read {project}: {error}", file=sys.stderr)
        return 2
    problems = findings(text)
    for problem in problems:
        print(f"{project}: {problem}")
    return 1 if problems else 0


def quiet_check(godot_dir: pathlib.Path) -> int:
    """`check`, with what it prints swallowed: a planted finding is not news."""
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return check(godot_dir)


def self_test() -> int:
    """Each planted project gets the exit code it must; 0 if all of them do."""
    good = f"[application]\n\nconfig/name=\"x\"\n\n{SECTION}\n\n{KEY}=false\n"
    cases = (
        ("the setting, false", good, 0),
        ("an empty project file", "", 1),
        ("no [editor] section", "[application]\n\nconfig/name=\"x\"\n", 1),
        ("the setting, true", good.replace("=false", "=true"), 1),
        ("the setting under another section",
         f"[application]\n\n{KEY}=false\n", 1),
        ("false, then true: Godot keeps the last",
         good + f"{KEY}=true\n", 1),
        ("true, then false: the last is false", good.replace(
            f"{KEY}=false", f"{KEY}=true\n{KEY}=false"), 0),
        ("false under [editor], true under another section",
         good + f"\n[application]\n\n{KEY}=true\n", 0),
    )
    failures = 0
    with tempfile.TemporaryDirectory() as scratch:
        folder = pathlib.Path(scratch)
        for name, text, expected in cases:
            (folder / "project.godot").write_text(text, encoding="utf-8")
            got = quiet_check(folder)
            if got != expected:
                print(f"self-test: {name}: exit {got}, expected {expected}")
                failures += 1
        (folder / "project.godot").unlink()
        if quiet_check(folder) != 2:
            print("self-test: a missing project file: expected exit 2")
            failures += 1
    print(f"check_import_threads self-test: {failures} failure(s)")
    return 1 if failures else 0


def main() -> int:
    """Parse the arguments and run the check or its self-test."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--godot-dir", type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parent.parent / "godot")
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    if arguments.self_test:
        return self_test()
    return check(arguments.godot_dir)


if __name__ == "__main__":
    sys.exit(main())
