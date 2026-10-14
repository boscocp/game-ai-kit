#!/usr/bin/env python3
"""Run every gate's own `--self-test`, and fail if any of them does.

Why this is a script and not a Makefile recipe
----------------------------------------------
It used to be fourteen lines of shell inside the Makefile, and a review called
it the hardest thing in the repository to read -- which is also where its one
real defect lived. The recipe chose an interpreter with
`python3 "$script" || bash "$script"`, and when a Python self-test failed, bash
then read the same file and treated the backticks inside its module docstring
as command substitution. One gate documents `adb logcat`; on a machine with adb
installed, that streams forever, so a failing self-test hung instead of
reporting. A rule that cannot be read is a rule nobody checks.

How a gate is found
-------------------
By glob over `scripts/`, never by a list. A gate left out of a list is a gate
that silently stops running, and nobody notices a check that is not there.

The interpreter comes from the shebang. A script with no recognisable one is a
finding rather than a skip, and every run is bounded by a timeout, so a
self-test that hangs on its own fails loudly instead of burning a CI job to its
six-hour limit.

Exit codes
----------
0   every self-test passed
1   one or more failed, timed out, or had no usable shebang
2   wrong usage, or no gates found where they were expected

Usage
-----
    run_selftests.py [--scripts PATH] [--timeout SECONDS]
    run_selftests.py --self-test
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

TIMEOUT_SECONDS = 120
MARKER = "--self-test"

# A file named this way is a gate, whether or not it still says so.
GATE_NAME_RE = re.compile(r"^check_[a-z0-9_]+\.py$")


def interpreter_for(script: pathlib.Path) -> str | None:
    """The command that runs this file, read from its shebang."""
    first_line = script.read_text(encoding="utf-8", errors="replace").splitlines()[:1]
    shebang = first_line[0] if first_line else ""
    if "python" in shebang:
        return sys.executable
    if "bash" in shebang or shebang.endswith("/sh"):
        return "bash"
    return None


def gates(scripts_dir: pathlib.Path) -> tuple[list[pathlib.Path], list[str]]:
    """Every script offering a --self-test, plus gates that have lost theirs.

    Discovery is in two parts, because one was not enough. Searching for the
    string alone meant a gate that renamed, broke or lost its flag simply
    vanished from the list and the run stayed green -- the exact hole this
    runner exists to close, reproduced by the thing meant to close it.

    So a file named `check_*.py` is a gate *by its name*, and a gate with no
    self-test is a finding rather than an absence. Anything else carrying the
    marker is run as well.
    """
    found, missing = [], []
    for path in sorted(scripts_dir.iterdir()):
        # A script with no suffix counts too: scripts/artgen is one, and while
        # only .py and .sh were looked at its self-test never ran.
        if path.suffix not in (".py", ".sh", "") or not path.is_file():
            continue
        has_marker = MARKER in path.read_text(encoding="utf-8", errors="replace")
        if has_marker:
            found.append(path)
        elif GATE_NAME_RE.match(path.name):
            missing.append(f"{path.name}: named like a gate but offers no {MARKER}")
    return found, missing


def run_one(script: pathlib.Path, timeout: int) -> tuple[str, bool]:
    """Run one self-test. Returns the verdict to print and whether it passed."""
    runner = interpreter_for(script)
    if runner is None:
        return "NO SHEBANG", False
    try:
        done = subprocess.run(
            [runner, str(script), MARKER],
            capture_output=True, timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return f"TIMEOUT after {timeout}s", False
    if done.returncode == 0:
        return "ok", True
    # The shell version this replaced printed nothing on failure either, and a
    # review called that a regression in the dimension the rewrite was
    # justified on: a red gate that says only FAIL tells you to go run it
    # yourself, which is the step the runner exists to save.
    output = (done.stdout + done.stderr).decode("utf-8", errors="replace").strip()
    return ("FAIL\n" + indent(output)) if output else "FAIL", False


def indent(text: str) -> str:
    """Four spaces in front of every line, so a gate's output reads as its own."""
    return "\n".join("    " + line for line in text.splitlines())


def run(scripts_dir: pathlib.Path, timeout: int) -> int:
    found, missing = gates(scripts_dir)
    if not found and not missing:
        print(f"no scripts with a {MARKER} in {scripts_dir}")
        return 2

    failed = bool(missing)
    for complaint in missing:
        print(f"{complaint:<40} NO SELF-TEST")
    for script in found:
        # Keep going after the first failure, so one broken gate does not hide
        # the state of the others.
        verdict, passed = run_one(script, timeout)
        print(f"{str(script):<40} {verdict}")
        failed = failed or not passed
    return 1 if failed else 0


def self_test() -> int:
    """Prove this runner reports each outcome, including the ones that hang."""
    failures = []
    with tempfile.TemporaryDirectory() as workspace:
        folder = pathlib.Path(workspace)

        # The marker has to appear in the file without breaking it, so it goes
        # in a comment -- which is also how a real gate carries it, in a
        # docstring and an argparse flag.
        passing = folder / "check_good.py"
        passing.write_text("#!/usr/bin/env python3\n# --self-test\nraise SystemExit(0)\n")

        if run(folder, 5) != 0:
            failures.append("a passing gate was not reported as ok")

        failing = folder / "check_bad.py"
        failing.write_text("#!/usr/bin/env python3\n# --self-test\nraise SystemExit(1)\n")
        if run(folder, 5) != 1:
            failures.append("a failing gate did not fail the run")
        failing.unlink()

        # Planted: the exact shape that used to hang. A docstring with
        # backticks, which bash would have executed, plus a self-test that
        # never returns.
        hanging = folder / "check_hangs.py"
        hanging.write_text(
            '#!/usr/bin/env python3\n"""Docs mentioning `sleep 60`."""\n'
            "import sys, time\nif '--self-test' in sys.argv:\n    time.sleep(30)\n"
        )
        if run(folder, 2) != 1:
            failures.append("a hanging gate did not fail the run")
        hanging.unlink()

        # Planted: no shebang at all. A skip here is a gate that stops running.
        headless = folder / "check_nohead.py"
        headless.write_text("# --self-test\nraise SystemExit(0)\n")
        if run(folder, 5) != 1:
            failures.append("a script with no shebang was not reported")
        headless.unlink()

        # Planted: a gate that lost its flag. Searching for the string alone
        # made it vanish from the list while the run stayed green -- the one
        # hole this runner was written to close.
        lost = folder / "check_lost.py"
        lost.write_text("#!/usr/bin/env python3\n# --selftest\nraise SystemExit(0)\n")
        if run(folder, 5) != 1:
            failures.append("a gate that lost its --self-test did not fail the run")
        lost.unlink()

        # Planted: a wrapper with no suffix, like scripts/artgen, whose
        # self-test fails. Looking only at .py and .sh never ran it.
        wrapper = folder / "wrapper"
        wrapper.write_text("#!/usr/bin/env bash\n# --self-test\nexit 1\n")
        if run(folder, 5) != 1:
            failures.append("a failing self-test in a script with no suffix was not run")
        wrapper.unlink()

        # A helper that is not named like a gate and has no self-test is not a
        # finding, or every utility in scripts/ becomes one.
        helper = folder / "helper.py"
        helper.write_text("#!/usr/bin/env python3\nprint('hi')\n")
        if run(folder, 5) != 0:
            failures.append("a plain helper was reported as a missing gate")
        helper.unlink()

        # Planted: an empty directory must be usage, never a pass.
        empty = folder / "empty"
        empty.mkdir()
        if run(empty, 5) != 2:
            failures.append("an empty scripts directory did not return 2")

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--scripts", default=None)
    parser.add_argument("--timeout", type=int, default=TIMEOUT_SECONDS)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    scripts_dir = pathlib.Path(args.scripts or pathlib.Path(__file__).resolve().parent)
    if not scripts_dir.is_dir():
        print(f"run_selftests: no such directory: {scripts_dir}", file=sys.stderr)
        return 2
    return run(scripts_dir, args.timeout)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
