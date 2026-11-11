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
runs one process and reuses its `engine_errors`, `kill_tree` and
`godot_command` rather than a second copy of them.

Since T141 (wave 180) every `-s` line in the `Makefile` runs through it,
gates and measurements alike, and `check_godot_checked.py` refuses a new
one that does not. The two exceptions it names are gdUnit4's runner, which
reports its own failures.

What it prints, it prints as the run goes: a fifteen-minute gate that said
nothing until its end would look hung.

`--project FOLDER` runs the script in another Godot project, one outside
this repository (T159): `check_published.py` loads every class of the
store's download in a blank project that holds only that download. A
folder with no `project.godot` is refused as wrong usage, before Godot
starts: given one, Godot would open no project and report nothing useful.

How the engine is started (T141)
--------------------------------
Headless, like every gate, unless the line says otherwise:

`--fixed-fps N`   Godot's own `--fixed-fps`: the 3D racer's gates step
                  their physics at 60 a second without pacing the frames
                  in real time.
`--windowed`      no `--headless`: `make measure-3d` measures a frame rate,
                  and a dummy renderer draws nothing worth timing.

An error printed on purpose
---------------------------
`--expect-error TEXT` names one engine error the gate prints on purpose (a
planted script it must see fail): an error line holding TEXT is forgiven.
It is given once per error, on the line that needs it, never as a switch
that forgives everything; and an expected error that is NOT printed fails
the run, because then the plant did not happen.

Exit codes
----------
0   the gate exited 0 and printed no engine error it was not told to expect
1   the gate exited 1, printed an unexpected engine error whatever it
    exited, or did not print one it was told to expect
2   wrong usage, or the gate exited 2, or it outlived `--timeout`

Usage
-----
    godot_checked.py res://test/x/gate.gd [--timeout SECONDS] [--project FOLDER]
        [--fixed-fps N] [--windowed] [--expect-error TEXT ...] [-- gate arguments]
    godot_checked.py --self-test
"""

from __future__ import annotations

import argparse
import dataclasses
import pathlib
import subprocess
import sys
import tempfile
import time
from typing import Callable, TextIO

from godot_shards import TIMEOUT, engine_errors, godot_command, kill_tree

#: Seconds between two looks at a running gate's output, to print what is new.
ECHO_EVERY = 0.5


@dataclasses.dataclass(frozen=True)
class Engine:
    """How Godot is started for one run: in which project, with which of its own flags.

    Why one value and not three parameters: every caller that builds a
    command passes all of it, and a fourth flag should not touch them all.
    """

    project: pathlib.Path | None = None
    fixed_fps: int | None = None
    windowed: bool = False


def unexpected_errors(output: str, expected: tuple[str, ...]) -> list[str]:
    """The engine errors in `output` that no `--expect-error` text names; these fail a run."""
    return [line for line in engine_errors(output) if not any(text in line for text in expected)]


def missing_errors(output: str, expected: tuple[str, ...]) -> list[str]:
    """The `--expect-error` texts that no engine error in `output` holds.

    Why a missing one fails: the error was planted, and a plant that printed
    nothing did not run -- the gate would pass without having looked.
    """
    errors = engine_errors(output)
    return [text for text in expected if not any(text in line for line in errors)]


def verdict(returncode: int | None, output: str, expected: tuple[str, ...] = ()) -> int:
    """The exit code a run deserves: an unexpected or a missing error makes any exit 1.

    Why: the gate's own exit code is trusted only when nothing in its output
    says that a function of it stopped half-way.
    """
    if returncode is None:
        return 2
    if unexpected_errors(output, expected) or missing_errors(output, expected):
        return 1
    return returncode if returncode in (0, 1, 2) else 1


def wait_and_echo(process: subprocess.Popen, reader: TextIO, timeout: float,
                  echo: Callable[[str], None]) -> int | None:
    """Wait for `process`, handing `echo` what it printed as it prints it.

    Its exit code, or None when it outlived `timeout` and was killed, as
    `godot_shards.wait_or_kill` does. Why it polls: the output goes to a
    file (see `run_to_file`), and a file has no reader to wake.
    """
    deadline = time.monotonic() + timeout
    returncode: int | None = None
    while True:
        try:
            returncode = process.wait(timeout=min(ECHO_EVERY, max(deadline - time.monotonic(), 0.0)))
            break
        except subprocess.TimeoutExpired:
            echo(reader.read())
        if time.monotonic() >= deadline:
            kill_tree(process)
            process.wait()
            returncode = None
            break
    echo(reader.read())
    return returncode


def run_to_file(command: list[str], folder: pathlib.Path, timeout: float,
                echo: Callable[[str], None] = lambda text: None) -> tuple[int | None, str]:
    """Run `command`, its stdout and stderr into a file in `folder`; its exit code and output.

    Why a file and not a pipe: a pipe holds 64 KiB on Linux, and a process
    that prints more than that blocks on its write until someone reads --
    while this waits for it to end, so it would sit until the timeout.
    `godot_shards.py` writes its shards' output to files for the same reason.
    `echo` is handed the output as it grows; by default nothing is shown.
    """
    path = folder / "gate.out"
    with path.open("w", encoding="utf-8") as output, path.open(encoding="utf-8", errors="replace") as reader:
        with subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT) as process:
            returncode = wait_and_echo(process, reader, timeout, echo)
    return returncode, path.read_text(encoding="utf-8", errors="replace")


def command_for(script: str, log: pathlib.Path, gate_arguments: list[str], engine: Engine) -> list[str]:
    """The Godot command for one run, started as `engine` says.

    Why it edits `godot_command`'s list and does not build a second one:
    the wrapper, the log and Windows' `bash` stay in one place.
    """
    command = godot_command(script, log, gate_arguments)
    if engine.project is not None:
        command[command.index("--path") + 1] = str(engine.project)
    if engine.windowed:
        command.remove("--headless")
    if engine.fixed_fps is not None:
        at = command.index("--path")
        command[at:at] = ["--fixed-fps", str(engine.fixed_fps)]
    return command


def print_now(text: str) -> None:
    """Print `text` at once: a gate's progress belongs on the screen while it runs."""
    sys.stdout.write(text)
    sys.stdout.flush()


def run(script: str, gate_arguments: list[str], timeout: float,
        engine: Engine = Engine(), expected: tuple[str, ...] = ()) -> int:
    """Run `script` once, show its output as it comes, then name what fails it."""
    with tempfile.TemporaryDirectory() as folder:
        log = pathlib.Path(folder) / "gate.log"
        command = command_for(script, log, gate_arguments, engine)
        returncode, output = run_to_file(command, pathlib.Path(folder), timeout, print_now)
    for line in unexpected_errors(output, expected):
        print(f"godot_checked: an engine error, so the run fails: {line}")
    for text in missing_errors(output, expected):
        print(f"godot_checked: no engine error held {text!r}, which this run must print, so it fails")
    if returncode is None:
        print(f"godot_checked: {script} was still running after {timeout:.0f} s, and was killed")
    return verdict(returncode, output, expected)


def _a_long_output_is_read_whole() -> bool:
    """True when a stub printing 200 KiB ends at once, exit 0, and all of it is read.

    Planted for the pipe that held a long gate until its timeout: through a
    pipe this stub would block on its write and be killed at 10 s.
    """
    stub = [sys.executable, "-c", "import sys; sys.stdout.write('x' * 204800 + '\\n')"]
    with tempfile.TemporaryDirectory() as folder:
        returncode, output = run_to_file(stub, pathlib.Path(folder), 10.0)
    return returncode == 0 and len(output) > 204800


def _the_output_is_shown_before_the_end() -> bool:
    """True when a line printed early is echoed while the stub is still running.

    Planted for an echo that waits for the end: a fifteen-minute gate
    would say nothing for fifteen minutes.
    """
    stub = [sys.executable, "-u", "-c", "import time; print('early'); time.sleep(3); print('late')"]
    seen_after: list[float] = []
    started = time.monotonic()

    def note(text: str) -> None:
        if "early" in text:
            seen_after.append(time.monotonic() - started)

    with tempfile.TemporaryDirectory() as folder:
        run_to_file(stub, pathlib.Path(folder), 10.0, note)
    return bool(seen_after) and seen_after[0] < 2.5


def _a_hung_gate_is_killed() -> int | None:
    """The exit code `run_to_file` reports for a stub that outlives its deadline."""
    stub = [sys.executable, "-c", "import time; time.sleep(30)"]
    with tempfile.TemporaryDirectory() as folder:
        return run_to_file(stub, pathlib.Path(folder), 0.5)[0]


def _index_of(command: list[str], flag: str) -> int:
    """Where `flag` is in `command`, or -1 when it is not there."""
    return command.index(flag) if flag in command else -1


def _the_engine_flags_reach_godot() -> list[str]:
    """The claims about `--project`, `--fixed-fps` and `--windowed` that the commands break.

    Planted for an option parsed and dropped: without them, a 3D race
    would run paced in real time, a frame rate would be timed on a dummy
    renderer, and the store's download would load inside this repository.
    """
    log = pathlib.Path("gate.log")
    elsewhere = pathlib.Path("/elsewhere/project")
    default = command_for("res://x.gd", log, [], Engine())
    moved = command_for("res://x.gd", log, [], Engine(project=elsewhere))
    paced = command_for("res://x.gd", log, [], Engine(fixed_fps=60))
    windowed = command_for("res://x.gd", log, [], Engine(windowed=True))
    fixed_at = _index_of(paced, "--fixed-fps")
    claims = [
        ("--project names the folder", moved[moved.index("--path") + 1] == str(elsewhere)),
        ("no --project keeps the repository's", default[default.index("--path") + 1] != str(elsewhere)),
        ("a run is headless by default", "--headless" in default),
        ("--windowed drops --headless", "--headless" not in windowed),
        ("--fixed-fps 60 comes before -s", -1 < fixed_at < _index_of(paced, "-s")
         and paced[fixed_at + 1] == "60"),
        ("no --fixed-fps unless asked", "--fixed-fps" not in default),
    ]
    return [label for label, holds in claims if not holds]


def _a_folder_with_no_project_is_refused() -> int:
    """The exit code of a run whose `--project` holds no `project.godot`."""
    with tempfile.TemporaryDirectory() as folder:
        return main(["res://x.gd", "--project", folder])


def _an_empty_expected_error_is_refused() -> int:
    """The exit code of `--expect-error ""`: a text every line holds would forgive every error."""
    return main(["res://x.gd", "--expect-error", " "])


def self_test() -> int:
    """Every verdict, asked of a planted case; 0 when each came out as it must."""
    clean = "squad duel, fixed: 30 position row(s), 6 match(es), 0 failure(s)\n"
    planted = "ERROR: Parse Error: planted.\n"
    cases = [
        ("a clean run", verdict(0, clean), 0),
        ("a run that failed a claim", verdict(1, clean), 1),
        ("a SCRIPT ERROR in a run that exited 0", verdict(0, clean + "SCRIPT ERROR: Invalid call.\n"), 1),
        ("an engine ERROR in a run that exited 0", verdict(0, "ERROR: Condition failed.\n" + clean), 1),
        ("a leak report, forgiven", verdict(0, clean + "ERROR: 3 resources still in use at exit\n"), 0),
        ("an expected error, printed", verdict(0, planted + clean, ("planted",)), 0),
        ("an expected error, not printed", verdict(0, clean, ("planted",)), 1),
        ("an expected error beside an unexpected one",
         verdict(0, planted + "SCRIPT ERROR: Invalid call.\n" + clean, ("planted",)), 1),
        ("an expected error does not excuse a failed claim", verdict(1, planted + clean, ("planted",)), 1),
        ("a usage error", verdict(2, ""), 2),
        ("a run killed at the deadline", verdict(None, clean), 2),
        ("a crash's exit code", verdict(139, clean), 1),
        ("a process printing past a pipe's 64 KiB", _a_long_output_is_read_whole(), True),
        ("the output shown while the gate runs", _the_output_is_shown_before_the_end(), True),
        ("a gate past its deadline", _a_hung_gate_is_killed(), None),
        ("the engine's flags in the command", _the_engine_flags_reach_godot(), []),
        ("--project on a folder with no project.godot", _a_folder_with_no_project_is_refused(), 2),
        ("--expect-error with a blank text", _an_empty_expected_error_is_refused(), 2),
    ]
    wrong = [f"{label}: {got}, expected {want}" for label, got, want in cases if got != want]
    for line in wrong:
        print(f"self-test: {line}")
    print("self-test: ok" if not wrong else f"self-test: {len(wrong)} wrong")
    return 0 if not wrong else 1


def parse(argv: list[str]) -> tuple[argparse.ArgumentParser, argparse.Namespace]:
    """The parser, and what it read from `argv` once the gate's own arguments are taken out."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("script", nargs="?")
    parser.add_argument("--timeout", type=float, default=TIMEOUT)
    # Resolved here, so the folder stays the same one should the wrapper
    # ever change directory before it starts Godot.
    parser.add_argument("--project", type=lambda text: pathlib.Path(text).resolve(), default=None)
    parser.add_argument("--fixed-fps", type=int, default=None)
    parser.add_argument("--windowed", action="store_true")
    parser.add_argument("--expect-error", action="append", default=[])
    parser.add_argument("--self-test", action="store_true")
    return parser, parser.parse_args(argv)


def usage_error(options: argparse.Namespace) -> str | None:
    """What is wrong with the command line, said for a person, or None; each exits 2."""
    if options.script is None or options.timeout <= 0:
        return "a script to run, and a --timeout above 0"
    if options.fixed_fps is not None and options.fixed_fps <= 0:
        return "--fixed-fps takes a number above 0"
    if any(not text.strip() for text in options.expect_error):
        return "--expect-error takes a text: a blank one would forgive every error"
    if options.project is not None and not (options.project / "project.godot").is_file():
        return f"{options.project} holds no project.godot"
    return None


def main(argv: list[str]) -> int:
    """Parse the command line and run; usage errors exit 2."""
    gate_arguments: list[str] = []
    if "--" in argv:
        gate_arguments = argv[argv.index("--") + 1:]
        argv = argv[:argv.index("--")]
    parser, options = parse(argv)
    if options.self_test:
        return self_test()
    problem = usage_error(options)
    if problem is not None:
        parser.print_usage(sys.stderr)
        print(f"godot_checked: {problem}", file=sys.stderr)
        return 2
    engine = Engine(options.project, options.fixed_fps, options.windowed)
    return run(options.script, gate_arguments, options.timeout, engine, tuple(options.expect_error))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
