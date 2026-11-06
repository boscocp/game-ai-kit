#!/usr/bin/env python3
"""Run a scene for a few frames and fail it on anything left alive at exit.

Why it exists
-------------
T138. Closing `make demo-rts` printed `21 ObjectDB instances were leaked at
exit` and `15 resources still in use at exit`, and the scene's own tests
were green: a leak is printed after the last line a script can run, so no
check inside the process can see it. This one runs Godot as a child and
reads what it printed. Godot prints both lines whenever there is a leak,
verbose or not (`ObjectDB::cleanup` in core/object/object.cpp,
`ResourceCache::clear` in core/io/resource.cpp, read at 4.7.2-stable);
`--verbose` adds each leaked object's class and each resource's path, which
a failure prints.

Each run starts with a planted leak, `godot/test/rts/planted_exit_leak.gd`,
which must show both lines. A reader that sees nothing there is broken, and
its silence on the scene would mean nothing (invariant 4). Each child has a
deadline (`wait_or_kill`). A child that stops on an error before `quit()`
never ends, and is killed, and the run fails 2. `godot_shards.py`'s
`FORGIVEN` ignores the "still in use" line on purpose; this gate is the
one that reads it.

Exit codes
----------
0   the planted leak was seen, and the scene closed clean
1   the scene left something alive, or did not end well, or the planted
    leak was not seen
2   wrong usage, or a child outlived `--timeout` and was killed

Usage
-----
    check_exit_leaks.py res://game/rts/rts.tscn [--frames N] [--timeout SECONDS]
    check_exit_leaks.py --self-test
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys
import tempfile

from godot_checked import run_to_file
from godot_shards import ENGINE_ERROR, GODOT, ROOT, godot_command, windows_bash

PLANTED = "res://test/rts/planted_exit_leak.gd"
LEAKED = "leaked at exit"
IN_USE = "still in use at exit"
# Lines that name what was left: the two counts, and the verbose details.
NAMING = (LEAKED, IN_USE, "Leaked instance:", "Resource still in use:")
# What `--verbose` prints once a script is loaded: a run without one ran
# nothing. A clean run of the RTS prints it, and no engine-error line.
SCRIPT_LOADED = re.compile(r"^Completed load for: '[^']+\.gd'", re.MULTILINE)
FRAMES = 30
TIMEOUT = 60.0


def scene_command(scene: str, frames: int, log: pathlib.Path) -> list[str]:
    """One headless, verbose Godot run of `scene` that quits after `frames`.

    Why not `godot_command`: that one runs a `-s` script, and a leak made
    while the engine opens a main scene is only seen when it opens it.
    """
    shell = [windows_bash()] if os.name == "nt" else []
    return [*shell, str(GODOT), "--headless", "--verbose", "--path", str(ROOT / "godot"),
            "--log-file", str(log), scene, "--quit-after", str(frames)]


def planted_reading(returncode: int | None, output: str) -> tuple[int, list[str]]:
    """The planted leak's verdict: 0 when both lines were seen, and why not.

    Why: the reader is trusted on the scene only once it has seen a leak.
    """
    if returncode is None:
        return 2, ["the planted leak's run was still going at the deadline, and was killed"]
    missing = [line for line in (LEAKED, IN_USE) if line not in output]
    if missing:
        return 1, [f"the planted leak printed no '{line}': this reader cannot see a leak" for line in missing]
    return 0, []


def scene_reading(scene: str, returncode: int | None, output: str) -> tuple[int, list[str]]:
    """The scene's verdict: 0 when it ran a script, ended 0, printed no
    engine error and left nothing alive.

    Why the first three: a scene that never ran its script leaks nothing, so
    a scene whose script did not parse, or that has none, would otherwise
    read as clean -- the empty scene of invariant 4 (second review of #100).
    """
    if returncode is None:
        return 2, [f"{scene} was still running at the deadline, and was killed"]
    errors = [line.strip() for line in output.splitlines() if ENGINE_ERROR.match(line)]
    if returncode != 0:
        return 1, [f"{scene} exited {returncode}", *errors]
    if not SCRIPT_LOADED.search(output):
        return 1, [f"{scene} loaded no script: nothing in it ran, so its silence says nothing"]
    named = [line.strip() for line in output.splitlines()
             if any(text in line for text in NAMING) or ENGINE_ERROR.match(line)]
    if named:
        return 1, [f"{scene} printed an engine error, or left something alive at exit:", *named]
    return 0, []


def run(scene: str, frames: int, timeout: float) -> int:
    """The planted leak, then the scene, each under `timeout`; print why and exit."""
    with tempfile.TemporaryDirectory() as folder:
        place = pathlib.Path(folder)
        planted = godot_command(PLANTED, place / "planted.log", [])
        code, reasons = planted_reading(*run_to_file(planted, place, timeout))
        if code == 0:
            command = scene_command(scene, frames, place / "scene.log")
            code, reasons = scene_reading(scene, *run_to_file(command, place, timeout))
    for reason in reasons:
        print(f"check_exit_leaks: {reason}")
    print(f"check_exit_leaks: {scene}: " + ("closed clean" if code == 0 else f"exit {code}"))
    return code


def _a_hung_child_is_killed() -> int:
    """The planted leak's verdict on a stub that never ends, under a 1 s deadline.

    Planted for a child that stops on an error before `quit()`: it must
    fail 2 at the deadline, not hold the gate.
    """
    stub = [sys.executable, "-c", "import time; time.sleep(30)"]
    with tempfile.TemporaryDirectory() as folder:
        return planted_reading(*run_to_file(stub, pathlib.Path(folder), 1.0))[0]


def self_test() -> int:
    """Every reading, asked of planted output; 0 when each came out as it must."""
    warning = "WARNING: 2 ObjectDB instances were leaked at exit (run with `--verbose` for details).\n"
    error = "ERROR: 1 resources still in use at exit.\n"
    loaded = "Completed load for: 'res://x.gd' remapped 'res://x.gd' at thread -1\n"
    started = "Godot Engine v4.7.2.stable.official\n" + loaded
    scene = "res://x.tscn"
    broken = "SCRIPT ERROR: Parse Error: Expected end of statement.\nERROR: Failed to load script \"res://x.gd\".\n"
    cases = [
        ("scene: its script did not parse", scene_reading(scene, 0, started + broken)[0], 1),
        ("scene: no script loaded at all (an empty scene)",
         scene_reading(scene, 0, "Godot Engine v4.7.2\nLoading resource: res://x.tscn\n")[0], 1),
        ("scene: an instance named, counts lost",
         scene_reading(scene, 0, started + "Leaked instance: GDScript:1 - Reference count: 1\n")[0], 1),
        ("scene: a nonzero exit says why", "Cannot open" in "\n".join(
            scene_reading(scene, 1, "ERROR: Cannot open file 'res://x.tscn'.\n")[1]), True),
        ("planted: both lines seen", planted_reading(0, started + warning + error)[0], 0),
        ("planted: nothing printed", planted_reading(0, "")[0], 1),
        ("planted: only the WARNING", planted_reading(0, warning)[0], 1),
        ("planted: only the ERROR", planted_reading(0, error)[0], 1),
        ("planted: killed at the deadline", planted_reading(None, "")[0], 2),
        ("scene: closed clean", scene_reading(scene, 0, started)[0], 0),
        ("scene: only the WARNING", scene_reading(scene, 0, started + warning)[0], 1),
        ("scene: only the ERROR", scene_reading(scene, 0, started + error)[0], 1),
        ("scene: a resource named, counts lost", scene_reading(scene, 0, "Resource still in use: res://a.gd\n")[0], 1),
        ("scene: a crash's exit code", scene_reading(scene, 139, started)[0], 1),
        ("scene: killed at the deadline", scene_reading(scene, None, started)[0], 2),
        ("a child that never ends is killed", _a_hung_child_is_killed(), 2),
    ]
    wrong = [f"{label}: {got}, expected {want}" for label, got, want in cases if got != want]
    for line in wrong:
        print(f"self-test: {line}")
    print("self-test: ok" if not wrong else f"self-test: {len(wrong)} wrong")
    return 0 if not wrong else 1


def main(argv: list[str]) -> int:
    """Parse the command line and run; usage errors exit 2."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("scene", nargs="?")
    parser.add_argument("--frames", type=int, default=FRAMES)
    parser.add_argument("--timeout", type=float, default=TIMEOUT)
    parser.add_argument("--self-test", action="store_true")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    if options.scene is None or options.frames <= 0 or options.timeout <= 0:
        parser.print_usage(sys.stderr)
        return 2
    return run(options.scene, options.frames, options.timeout)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
