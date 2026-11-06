#!/usr/bin/env python3
"""Run a Godot `-s` gate in shards, at once, and then its merge (T72).

What it does
------------
`botmatch_effects.gd` plays 187 whole matches, one after another, in one
process: about forty-five minutes. Each match is independent, so this starts N
Godot processes, each told `-- --shard K/N --out DIR` and playing its share,
waits for all of them, and runs the gate once more with `-- --merge DIR`,
which reads every shard's counts back, adds them in the serial order and
asks every claim as before. The merge's report is the serial run's, bit for
bit (`docs/godot/botmatch.md` says how that was shown).

What it refuses
---------------
A `-s` script that hits a SCRIPT ERROR still exits 0 (CLAUDE.md's trap),
and a shard that played nothing would pass by finding nothing. So a shard
fails when it exits non-zero, writes no counts, prints an engine error, or
outlives `--timeout` -- an error inside `_initialize` can leave a script
that never reaches `quit()`, and a gate that waits on it waits forever. The
merge's own output is read for engine errors the same way, and it has the
same deadline. Each is a planted case in `--self-test`.

Exit codes
----------
0   every shard ran clean, and the merge exited 0
1   an engine error in a shard or in the merge, or the merge exited 1
2   wrong usage, Godot could not be started, a shard that could not run,
    wrote nothing or timed out, or the merge exited 2 (the gate's own 2: an
    exploring run that claims nothing) or timed out

Usage
-----
    godot_shards.py [--shards N] [--timeout SECONDS] SCRIPT [-- GATE ARGUMENTS]
    godot_shards.py --self-test

Each shard gets its own `--log-file`: Godot's default log is one file under
`user://`, and twelve processes rotating it at once is a race nobody needs.
A run's folder under `build/shards/` is removed when it passes, and kept,
and named, when it does not.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
GODOT = ROOT / "scripts" / "godot"
#: Where the shards' counts and logs go: ignored by git, inside the checkout.
BUILD = ROOT / "build" / "shards"
#: More processes than this gains little and starves whatever else runs.
MOST_SHARDS = 12
#: Seconds every shard together, and then the merge, may take. In shards the
#: gate measured 455 s (2026-10-22), so a shard still running after eight
#: times that has hung rather than worked; one process alone took 2748 s,
#: and a longer gate run serially wants `--timeout`.
TIMEOUT = 3600.0
#: Lines Godot prints for an error.
ENGINE_ERROR = re.compile(r"^(SCRIPT ERROR|ERROR):", re.MULTILINE)
#: Printed at exit by a script that leaves objects alive: a leak report, not a
#: wrong answer, and the serial gates print it too.
FORGIVEN = ("resources still in use at exit",)


def engine_errors(output: str) -> list[str]:
    """The engine-error lines in one process's output, but the forgiven ones.

    Why: a SCRIPT ERROR aborts one function and the run exits 0 with that
    check skipped, so the exit code alone cannot say a shard played its share.
    """
    found = []
    for line in output.splitlines():
        if ENGINE_ERROR.match(line) and not any(text in line for text in FORGIVEN):
            found.append(line.strip())
    return found


def shard_verdict(shard: int, returncode: int | None, output: str, wrote: bool) -> tuple[int, list[str]]:
    """The exit code one shard earns, and why: 0 clean, 1 an engine error, 2 it did not run.

    A shard with no counts file counts as not run, whatever its exit code:
    a runner that finds nothing must not pass (CLAUDE.md). A `returncode` of
    None is a shard that outlived the deadline and was killed.
    """
    if returncode is None:
        return 2, [f"shard {shard}: still running at the deadline, killed"]
    if returncode != 0 or not wrote:
        return 2, [f"shard {shard}: exit {returncode}, {'wrote' if wrote else 'wrote no'} counts"]
    errors = engine_errors(output)
    if errors:
        return 1, [f"shard {shard}: {line}" for line in errors[:5]]
    return 0, []


def overall(shard_codes: list[int], merge_code: int | None, merge_errors: list[str]) -> int:
    """The runner's exit code from the shards' and the merge's.

    A shard that did not run outranks everything (2), then any engine error
    (1); with clean shards and a clean merge, the merge's own code stands.
    A merge that never ran or timed out is None, and a 2.
    """
    if 2 in shard_codes or merge_code is None:
        return 2
    if 1 in shard_codes or merge_errors:
        return 1
    return merge_code


def wait_or_kill(process: subprocess.Popen, seconds: float) -> int | None:
    """Its exit code, or None when it was still running after `seconds` and was killed.

    Why: a `-s` script whose `_initialize` stops on an error never quits, and
    `wait()` with no deadline would hold the gate, and the wave, forever.
    """
    try:
        return process.wait(timeout=max(seconds, 0.0))
    except subprocess.TimeoutExpired:
        kill_tree(process)
        process.wait()
        return None


def kill_tree(process: subprocess.Popen) -> None:
    """Kill `process` and everything it started.

    On Linux `scripts/godot` ends in `exec`, so the process is Godot and
    `kill()` reaches it. Git Bash's `exec` of a Windows program leaves bash
    behind as a stub, and killing the stub left Godot running, holding its
    log, its counts and the shared user:// (a review of wave 83 measured
    it). `taskkill /T` takes the whole tree.
    """
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(process.pid)],
                       capture_output=True, check=False)
    else:
        process.kill()


def windows_bash() -> str:
    """Git Bash's bash, which runs `scripts/godot` on Windows.

    Asked of PATH, not left to Windows: a bare "bash" is looked for in
    System32 before PATH, and there, on a machine with WSL, is WSL's
    launcher -- where `scripts/godot` would look for a Linux toolchain.
    """
    found = shutil.which("bash")
    system = os.environ.get("SystemRoot", r"C:\Windows").lower()
    if found is None or found.lower().startswith(system):
        raise OSError(f"no Git Bash on PATH (found {found!r}); run this from Git Bash")
    return found


def godot_command(script: str, log: pathlib.Path, extra: list[str]) -> list[str]:
    """One headless Godot run of `script`, its log in `log`, `extra` after `--`.

    On Windows a bash script is not a program Windows can start, so Git
    Bash's `bash` is named in front of the wrapper.
    """
    shell = [windows_bash()] if os.name == "nt" else []
    return [*shell, str(GODOT), "--headless", "--path", str(ROOT / "godot"), "--log-file", str(log), "-s", script, "--", *extra]


def run_shards(script: str, count: int, folder: pathlib.Path, gate_arguments: list[str], timeout: float) -> list[int]:
    """Start every shard at once, wait for all until the deadline, and judge each one."""
    running = []
    for shard in range(count):
        output = (folder / f"shard-{shard}.out").open("w", encoding="utf-8")
        extra = [*gate_arguments, "--shard", f"{shard}/{count}", "--out", str(folder)]
        command = godot_command(script, folder / f"shard-{shard}.log", extra)
        try:
            running.append((subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT), output))
        except OSError:
            output.close()
            raise
    deadline = time.monotonic() + timeout
    codes = []
    for shard, (process, output) in enumerate(running):
        returncode = wait_or_kill(process, deadline - time.monotonic())
        output.close()
        text = (folder / f"shard-{shard}.out").read_text(encoding="utf-8", errors="replace")
        code, reasons = shard_verdict(shard, returncode, text, (folder / f"shard-{shard}.bin").is_file())
        for reason in reasons:
            print(reason, file=sys.stderr)
        codes.append(code)
    return codes


def run_merge(script: str, folder: pathlib.Path, gate_arguments: list[str], timeout: float) -> tuple[int | None, list[str]]:
    """The gate once more, reading the shards' counts; its output is shown as it is."""
    command = godot_command(script, folder / "merge.log", [*gate_arguments, "--merge", str(folder)])
    # To a file and our own deadline, not `run(timeout=)`: after its kill,
    # `run` reads the pipes to the end, and on Windows a Godot that outlived
    # the stub kept them open -- the timeout became a hang.
    with (folder / "merge.out").open("w", encoding="utf-8") as output:
        returncode = wait_or_kill(subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT), timeout)
    text = (folder / "merge.out").read_text(encoding="utf-8", errors="replace")
    if returncode is None:
        print(f"merge: still running after {timeout:.0f} s, killed", file=sys.stderr)
        return None, []
    sys.stdout.write(text)
    errors = engine_errors(text)
    for line in errors[:5]:
        print(f"merge: {line}", file=sys.stderr)
    return returncode, errors


def run(script: str, count: int, gate_arguments: list[str], timeout: float) -> int:
    """Shards, then the merge if every shard ran clean; the exit code.

    The run's folder is removed when it passed and kept when it did not, so
    the logs of a failure are there to read and a green run leaves nothing.
    """
    BUILD.mkdir(parents=True, exist_ok=True)
    folder = pathlib.Path(tempfile.mkdtemp(prefix="effects-", dir=BUILD))
    started = time.monotonic()
    try:
        codes = run_shards(script, count, folder, gate_arguments, timeout)
        print(f"godot_shards: {count} shards in {time.monotonic() - started:.0f} s")
        merge_code, merge_errors = (0, []) if any(codes) else run_merge(script, folder, gate_arguments, timeout)
    except OSError as error:
        print(f"godot_shards: could not start Godot ({error}); the logs are in {folder}", file=sys.stderr)
        return 2
    code = overall(codes, merge_code, merge_errors)
    print(f"godot_shards: done in {time.monotonic() - started:.0f} s, exit {code}")
    if code == 0:
        shutil.rmtree(folder, ignore_errors=True)
    else:
        print(f"godot_shards: the shards' counts and logs are kept in {folder}", file=sys.stderr)
    return code


def _a_hung_process_is_killed() -> int | None:
    """A process that outlives its deadline: its exit code, None when it was killed."""
    process = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"])
    return wait_or_kill(process, 0.2)


def _a_grandchild_outlives_the_kill() -> bool:
    """A stub that started a child, as Git Bash's `exec` leaves one: is the child alive after the kill?

    Windows only: on Linux `scripts/godot` execs, so there is no stub, and a
    plain kill does not reach a grandchild -- this case would plant a shape
    that cannot happen there.
    """
    with tempfile.TemporaryDirectory() as workspace:
        pid_file = pathlib.Path(workspace) / "child.pid"
        stub = ("import pathlib, subprocess, sys, time; "
                "child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)']); "
                f"pathlib.Path({str(pid_file)!r}).write_text(str(child.pid)); time.sleep(30)")
        process = subprocess.Popen([sys.executable, "-c", stub])
        while not pid_file.is_file() or not pid_file.read_text():
            time.sleep(0.05)
        wait_or_kill(process, 0.2)
        # Bytes: tasklist writes in the console's code page, not UTF-8.
        listing = subprocess.run(["tasklist", "/FI", f"PID eq {pid_file.read_text()}", "/NH"],
                                 capture_output=True, check=False).stdout
        return pid_file.read_bytes() in listing


def self_test() -> int:
    """Every refusal, asked of a planted case it must refuse; 0 when all were."""
    clean = "botmatch effects: 4 pairings of 20 matches\n"
    cases = [
        ("a clean shard", shard_verdict(0, 0, clean, True)[0], 0),
        ("a shard with a SCRIPT ERROR", shard_verdict(0, 0, clean + "SCRIPT ERROR: Invalid call.\n", True)[0], 1),
        ("a shard with an engine ERROR", shard_verdict(0, 0, "ERROR: Condition failed.\n", True)[0], 1),
        ("a shard that wrote no counts", shard_verdict(0, 0, clean, False)[0], 2),
        ("a shard that exited 1", shard_verdict(0, 1, clean, True)[0], 2),
        ("a shard killed at the deadline", shard_verdict(0, None, clean, True)[0], 2),
        ("a leak report, forgiven", shard_verdict(0, 0, "ERROR: 18 resources still in use at exit\n", True)[0], 0),
        ("a merge with an engine error", overall([0, 0], 0, ["SCRIPT ERROR: x"]), 1),
        ("a merge that failed a claim", overall([0, 0], 1, []), 1),
        ("a merge that never ran or timed out", overall([0, 0], None, []), 2),
        ("one shard not run among clean ones", overall([0, 2, 0], 0, []), 2),
        ("a process past its deadline", _a_hung_process_is_killed(), None),
    ]
    if os.name == "nt":
        cases.append(("a stub's child past its deadline", _a_grandchild_outlives_the_kill(), False))
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
    parser.add_argument("--shards", type=int, default=min(os.cpu_count() or 1, MOST_SHARDS))
    parser.add_argument("--timeout", type=float, default=TIMEOUT)
    parser.add_argument("--self-test", action="store_true")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    if options.script is None or options.shards < 1 or options.timeout <= 0:
        parser.print_usage(sys.stderr)
        return 2
    return run(options.script, options.shards, gate_arguments, options.timeout)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
