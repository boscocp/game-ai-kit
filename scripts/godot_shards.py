#!/usr/bin/env python3
"""Run a Godot `-s` gate in shards, at once, and then its merge (T72).

What it does
------------
`botmatch_effects.gd` plays 189 whole matches, one after another, in one
process: about forty minutes. Each match is independent, so this starts N
Godot processes, each told `-- --shard K/N --out DIR` and playing its share,
waits for all of them, and runs the gate once more with `-- --merge DIR`,
which reads every shard's counts back, adds them in the serial order and
asks every claim as before. The merge's report is the serial run's, bit for
bit (`docs/godot/botmatch.md` says how that was shown).

What it refuses
---------------
A `-s` script that hits a SCRIPT ERROR still exits 0 (CLAUDE.md's trap),
and a shard that played nothing would pass by finding nothing. So a shard
fails when it exits non-zero, writes no counts, or prints an engine error;
the merge's own output is read for engine errors the same way. Each is a
planted case in `--self-test`.

Exit codes
----------
0   every shard ran clean, and the merge exited 0
1   an engine error in a shard or in the merge, or the merge exited 1
2   wrong usage, a shard that could not run or wrote nothing, or the merge
    exited 2 (the gate's own 2: an exploring run that claims nothing)

Usage
-----
    godot_shards.py [--shards N] SCRIPT [-- GATE ARGUMENTS]
    godot_shards.py --self-test

Each shard gets its own `--log-file`: Godot's default log is one file under
`user://`, and twelve processes rotating it at once is a race nobody needs.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
GODOT = ROOT / "scripts" / "godot"
#: Where the shards' counts and logs go: ignored by git, on the large disk.
BUILD = ROOT / "build" / "shards"
#: More processes than this gains little and starves whatever else runs.
MOST_SHARDS = 12
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


def shard_verdict(shard: int, returncode: int, output: str, wrote: bool) -> tuple[int, list[str]]:
    """The exit code one shard earns, and why: 0 clean, 1 an engine error, 2 it did not run.

    A shard with no counts file counts as not run, whatever its exit code:
    a runner that finds nothing must not pass (CLAUDE.md).
    """
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
    """
    if 2 in shard_codes or merge_code is None:
        return 2
    if 1 in shard_codes or merge_errors:
        return 1
    return merge_code


def godot_command(script: str, log: pathlib.Path, extra: list[str]) -> list[str]:
    """One headless Godot run of `script`, its log in `log`, `extra` after `--`."""
    return [str(GODOT), "--headless", "--path", str(ROOT / "godot"), "--log-file", str(log), "-s", script, "--", *extra]


def run_shards(script: str, count: int, folder: pathlib.Path, gate_arguments: list[str]) -> list[int]:
    """Start every shard at once, wait for all, and judge each one."""
    running = []
    for shard in range(count):
        output = (folder / f"shard-{shard}.out").open("w", encoding="utf-8")
        extra = [*gate_arguments, "--shard", f"{shard}/{count}", "--out", str(folder)]
        command = godot_command(script, folder / f"shard-{shard}.log", extra)
        running.append((subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT), output))
    codes = []
    for shard, (process, output) in enumerate(running):
        returncode = process.wait()
        output.close()
        text = (folder / f"shard-{shard}.out").read_text(encoding="utf-8", errors="replace")
        code, reasons = shard_verdict(shard, returncode, text, (folder / f"shard-{shard}.bin").is_file())
        for reason in reasons:
            print(reason, file=sys.stderr)
        codes.append(code)
    return codes


def run_merge(script: str, folder: pathlib.Path, gate_arguments: list[str]) -> tuple[int, list[str]]:
    """The gate once more, reading the shards' counts; its output is shown as it is."""
    command = godot_command(script, folder / "merge.log", [*gate_arguments, "--merge", str(folder)])
    done = subprocess.run(command, capture_output=True, text=True, check=False)
    sys.stdout.write(done.stdout)
    sys.stderr.write(done.stderr)
    errors = engine_errors(done.stdout + done.stderr)
    for line in errors[:5]:
        print(f"merge: {line}", file=sys.stderr)
    return done.returncode, errors


def run(script: str, count: int, gate_arguments: list[str]) -> int:
    """Shards, then the merge if every shard ran clean; the exit code."""
    BUILD.mkdir(parents=True, exist_ok=True)
    folder = pathlib.Path(tempfile.mkdtemp(prefix="effects-", dir=BUILD))
    started = time.monotonic()
    codes = run_shards(script, count, folder, gate_arguments)
    print(f"godot_shards: {count} shards in {time.monotonic() - started:.0f} s, kept in {folder}")
    if any(codes):
        return overall(codes, 0, [])
    merge_code, merge_errors = run_merge(script, folder, gate_arguments)
    print(f"godot_shards: done in {time.monotonic() - started:.0f} s")
    return overall(codes, merge_code, merge_errors)


def self_test() -> int:
    """Every refusal, asked of a planted case it must refuse; 0 when all were."""
    clean = "botmatch effects: 4 pairings of 20 matches\n"
    cases = [
        ("a clean shard", shard_verdict(0, 0, clean, True)[0], 0),
        ("a shard with a SCRIPT ERROR", shard_verdict(0, 0, clean + "SCRIPT ERROR: Invalid call.\n", True)[0], 1),
        ("a shard with an engine ERROR", shard_verdict(0, 0, "ERROR: Condition failed.\n", True)[0], 1),
        ("a shard that wrote no counts", shard_verdict(0, 0, clean, False)[0], 2),
        ("a shard that exited 1", shard_verdict(0, 1, clean, True)[0], 2),
        ("a leak report, forgiven", shard_verdict(0, 0, "ERROR: 18 resources still in use at exit\n", True)[0], 0),
        ("a merge with an engine error", overall([0, 0], 0, ["SCRIPT ERROR: x"]), 1),
        ("a merge that failed a claim", overall([0, 0], 1, []), 1),
        ("a merge that never ran", overall([0, 0], None, []), 2),
        ("one shard not run among clean ones", overall([0, 2, 0], 0, []), 2),
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
    parser.add_argument("--shards", type=int, default=min(os.cpu_count() or 1, MOST_SHARDS))
    parser.add_argument("--self-test", action="store_true")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    if options.script is None or options.shards < 1:
        parser.print_usage(sys.stderr)
        return 2
    return run(options.script, options.shards, gate_arguments)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
