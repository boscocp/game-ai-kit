#!/usr/bin/env python3
"""Run one Godot `-s` gate, and fail it on an engine error in its output.

Why it exists
-------------
A `SCRIPT ERROR` in a `-s` script aborts the function it happens in, and the
script carries on to its summary and `quit(0)` (CLAUDE.md's trap). Worse, an
aborted function hands its caller the default of its return type: a typed
`Array[String]` comes back empty, so a validator that broke reads exactly
like one that found nothing (measured on 4.7.2 by the second review of wave
136). No count inside the script can tell the two apart; only the output
can. `godot_shards.py` reads its shards' output for the same lines; this
runs one process and reuses its `engine_errors`, `wait_or_kill` and
`godot_command` rather than a second copy of them.

T88's duel (`make test-squad-duel`, `make measure-squad-duel`) runs through
it. Any other `-s` gate can: the trap applies to all of them.

Exit codes
----------
0   the gate exited 0 and printed no engine error
1   the gate exited 1, or printed an engine error whatever it exited
2   wrong usage, or the gate exited 2, or it outlived `--timeout`

Usage
-----
    godot_checked.py res://test/x/gate.gd [--timeout SECONDS] [-- gate arguments]
    godot_checked.py --self-test
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
import tempfile

from godot_shards import TIMEOUT, engine_errors, godot_command, wait_or_kill


def verdict(returncode: int | None, output: str) -> int:
    """The exit code a run deserves: an engine error makes any exit 1.

    Why: the gate's own exit code is trusted only when nothing in its output
    says that a function of it stopped half-way.
    """
    if returncode is None:
        return 2
    if engine_errors(output):
        return 1
    return returncode if returncode in (0, 1, 2) else 1


def run_to_file(command: list[str], folder: pathlib.Path, timeout: float) -> tuple[int | None, str]:
    """Run `command`, its stdout and stderr into a file in `folder`; its exit code and output.

    Why a file and not a pipe: a pipe holds 64 KiB on Linux, and a process
    that prints more than that blocks on its write until someone reads --
    while this waits for it to end, so it would sit until the timeout.
    `godot_shards.py` writes its shards' output to files for the same reason.
    """
    path = folder / "gate.out"
    with path.open("w", encoding="utf-8") as output:
        with subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT) as process:
            returncode = wait_or_kill(process, timeout)
    return returncode, path.read_text(encoding="utf-8", errors="replace")


def run(script: str, gate_arguments: list[str], timeout: float) -> int:
    """Run `script` once, print what it printed and the engine errors found."""
    with tempfile.TemporaryDirectory() as folder:
        log = pathlib.Path(folder) / "gate.log"
        returncode, output = run_to_file(godot_command(script, log, gate_arguments), pathlib.Path(folder), timeout)
    print(output, end="")
    for line in engine_errors(output):
        print(f"godot_checked: an engine error, so the run fails: {line}")
    if returncode is None:
        print(f"godot_checked: {script} was still running after {timeout:.0f} s, and was killed")
    return verdict(returncode, output)


def _a_long_output_is_read_whole() -> bool:
    """True when a stub printing 200 KiB ends at once, exit 0, and all of it is read.

    Planted for the pipe that held a long gate until its timeout: through a
    pipe this stub would block on its write and be killed at 10 s.
    """
    stub = [sys.executable, "-c", "import sys; sys.stdout.write('x' * 204800 + '\\n')"]
    with tempfile.TemporaryDirectory() as folder:
        returncode, output = run_to_file(stub, pathlib.Path(folder), 10.0)
    return returncode == 0 and len(output) > 204800


def self_test() -> int:
    """Every verdict, asked of a planted case; 0 when each came out as it must."""
    clean = "squad duel, fixed: 30 position row(s), 6 match(es), 0 failure(s)\n"
    cases = [
        ("a clean run", verdict(0, clean), 0),
        ("a run that failed a claim", verdict(1, clean), 1),
        ("a SCRIPT ERROR in a run that exited 0", verdict(0, clean + "SCRIPT ERROR: Invalid call.\n"), 1),
        ("an engine ERROR in a run that exited 0", verdict(0, "ERROR: Condition failed.\n" + clean), 1),
        ("a leak report, forgiven", verdict(0, clean + "ERROR: 3 resources still in use at exit\n"), 0),
        ("a usage error", verdict(2, ""), 2),
        ("a run killed at the deadline", verdict(None, clean), 2),
        ("a crash's exit code", verdict(139, clean), 1),
        ("a process printing past a pipe's 64 KiB", _a_long_output_is_read_whole(), True),
    ]
    wrong = [f"{label}: {got}, expected {want}" for label, got, want in cases if got != want]
    for line in wrong:
        print(f"self-test: {line}")
    print("self-test: ok" if not wrong else f"self-test: {len(wrong)} wrong")
    return 0 if not wrong else 1


def main(argv: list[str]) -> int:
    """Parse the command line and run; usage errors exit 2."""
    gate_arguments: list[str] = []
    if "--" in argv:
        gate_arguments = argv[argv.index("--") + 1:]
        argv = argv[:argv.index("--")]
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("script", nargs="?")
    parser.add_argument("--timeout", type=float, default=TIMEOUT)
    parser.add_argument("--self-test", action="store_true")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    if options.script is None or options.timeout <= 0:
        parser.print_usage(sys.stderr)
        return 2
    return run(options.script, gate_arguments, options.timeout)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
