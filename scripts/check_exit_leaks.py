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

`--demos` runs every scene in `check_demos.py`'s list, the one
`test/menu/demo_overlays.gd` reads, so a new demo is checked the day it is
listed and no second list is kept (T146). It also runs every extra mode
that file's `MODE_REQUIRED` names, the way `make demo-tactical MODE=squad`
opens one: the menu, with `--open=<card's target> --mode=<mode>`. The
planted leak runs once per run, not once per scene. A list that came back
empty fails 1: a sweep of no scene would read as clean.

Each run starts with a planted leak, `godot/test/rts/planted_exit_leak.gd`,
which must show both lines. A reader that sees nothing there is broken, and
its silence on the scene would mean nothing (invariant 4). Each child has a
deadline (`wait_or_kill`). A child that stops on an error before `quit()`
never ends, and is killed, and the run fails 2. `godot_shards.py`'s
`FORGIVEN` ignores the "still in use" line on purpose; this gate is the
one that reads it.

Exit codes
----------
0   the planted leak was seen, and every scene closed clean
1   a scene left something alive, or did not end well, or the planted
    leak was not seen, or `--demos` found no scene or a mode with no card.
    A leak wins over a kill: in a sweep, one scene's 1 is the run's 1
    even when another was killed, since 2 says usage or unreadable
2   wrong usage, or a child outlived `--timeout` and was killed, and no
    scene leaked

Usage
-----
    check_exit_leaks.py res://game/rts/rts.tscn [--frames N] [--timeout SECONDS]
    check_exit_leaks.py --demos [--frames N] [--timeout SECONDS]
    check_exit_leaks.py --self-test
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import tempfile

from check_demos import CATALOGUE, OVERLAYS, listed_scenes
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


def scene_command(opened: list[str], frames: int, log: pathlib.Path) -> list[str]:
    """One headless, verbose Godot run that quits after `frames`, opening
    `opened`: a scene's path, or the user arguments the menu reads.

    Why not `godot_command`: that one runs a `-s` script, and a leak made
    while the engine opens a main scene is only seen when it opens it.
    """
    shell = [windows_bash()] if os.name == "nt" else []
    return [*shell, str(GODOT), "--headless", "--verbose", "--path", str(ROOT / "godot"),
            "--log-file", str(log), "--quit-after", str(frames), *opened]


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


def demo_scenes(root: pathlib.Path) -> list[str]:
    """Every scene in `check_demos.py`'s list, as `res://` paths, sorted.

    Why that list: `lint-demos` refuses an example missing from it, so it is
    every demo there is, and a second list here would one day differ.
    """
    return [f"res://{scene}" for scene in sorted(listed_scenes(root))]


MODE_KEY = re.compile(r'^\s*"(res://\S+\.tscn) ([^"]+)"\s*:', re.MULTILINE)


def demo_modes(root: pathlib.Path) -> list[tuple[str, list[str]]]:
    """Every extra mode `MODE_REQUIRED` names, as [label, what to open]:
    the menu's user arguments, or [] when no card in the catalogue has
    that scene.

    Why that file: `test-demo-overlays` steps every such mode, and
    `lint-demos` holds it to the catalogue's cards.
    """
    overlays = (root / OVERLAYS).read_text(encoding="utf-8") if (root / OVERLAYS).exists() else ""
    block = overlays.split("const MODE_REQUIRED", 1)[1].split("\n}", 1)[0] if "const MODE_REQUIRED" in overlays else ""
    path = root / CATALOGUE
    cards = json.loads(path.read_text(encoding="utf-8")).get("examples", []) if path.exists() else []
    found = []
    for scene, mode in MODE_KEY.findall(block):
        targets = [card.get("target") for card in cards if card.get("scene") == scene]
        opened = ["--", f"--open={targets[0]}", f"--mode={mode}"] if targets else []
        found.append((f"{scene} {mode}", opened))
    return found


def sweep_code(codes: list[int]) -> int:
    """A sweep's exit code from its scenes': 1 if any left something alive
    or ended badly, else 2 if any was killed, else 0; 1 for no scene.

    Why a leak wins: 2 means usage or unreadable, and a sweep that says 2
    would hide a leak another scene printed (review of PR #124).
    """
    if not codes or 1 in codes:
        return 1
    return 2 if 2 in codes else 0


def _say(reasons: list[str]) -> None:
    """Print each reason, prefixed with this gate's name."""
    for reason in reasons:
        print(f"check_exit_leaks: {reason}")


def run(runs: list[tuple[str, list[str]]], frames: int, timeout: float) -> int:
    """The planted leak once, then each [label, what to open], each under
    `timeout`; print why, and exit with `sweep_code` of them."""
    if not runs:
        print("check_exit_leaks: no scene to check: a sweep of none would read as clean")
        return 1
    codes = []
    with tempfile.TemporaryDirectory() as folder:
        place = pathlib.Path(folder)
        planted = godot_command(PLANTED, place / "planted.log", [])
        code, reasons = planted_reading(*run_to_file(planted, place, timeout))
        _say(reasons)
        if code != 0:
            return code
        for index, (label, opened) in enumerate(runs):
            if opened:
                command = scene_command(opened, frames, place / f"scene{index}.log")
                code, reasons = scene_reading(label, *run_to_file(command, place, timeout))
            else:
                code, reasons = 1, [f"{label}: no card in {CATALOGUE} has this scene, so the mode cannot be opened"]
            _say(reasons)
            print(f"check_exit_leaks: {label}: " + ("closed clean" if code == 0 else f"exit {code}"))
            codes.append(code)
    worst = sweep_code(codes)
    if len(runs) > 1 or worst != 0:
        print(f"check_exit_leaks: {len(runs)} scene(s) and mode(s): " + ("all closed clean" if worst == 0 else f"exit {worst}"))
    return worst


def _a_hung_child_is_killed() -> int:
    """The planted leak's verdict on a stub that never ends, under a 1 s deadline.

    Planted for a child that stops on an error before `quit()`: it must
    fail 2 at the deadline, not hold the gate.
    """
    stub = [sys.executable, "-c", "import time; time.sleep(30)"]
    with tempfile.TemporaryDirectory() as folder:
        return planted_reading(*run_to_file(stub, pathlib.Path(folder), 1.0))[0]


def _planted_demo_list() -> tuple[list[str], list[tuple[str, list[str]]]]:
    """`demo_scenes` and `demo_modes` on a planted overlays file and
    catalogue: two scenes, one commented out; two modes, one with no card."""
    with tempfile.TemporaryDirectory() as folder:
        root = pathlib.Path(folder)
        overlays = root / OVERLAYS
        overlays.parent.mkdir(parents=True)
        overlays.write_text('const SCENES: Array[String] = [\n\t"res://game/b.tscn",\n'
                            '\t# "res://game/c.tscn",\n\t"res://demos/a.tscn",\n]\n'
                            'const MODE_REQUIRED: Dictionary = {\n\t"res://game/b.tscn squad": [],\n'
                            '\t"res://game/c.tscn x": [],\n}\nconst OTHER: Dictionary = {\n\t"res://game/d.tscn y": [],\n}\n',
                            encoding="utf-8")
        (root / CATALOGUE).parent.mkdir(parents=True)
        (root / CATALOGUE).write_text(json.dumps({"examples": [{"target": "demo-b", "scene": "res://game/b.tscn"}]}),
                                      encoding="utf-8")
        return demo_scenes(root), demo_modes(root)


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
        ("a sweep of no scene", sweep_code([]), 1),
        ("a sweep: one leak, then a clean scene", sweep_code([1, 0]), 1),
        ("a sweep: a clean scene, then a leak", sweep_code([0, 1]), 1),
        ("a sweep: a leak wins over a kill", sweep_code([0, 2, 1]), 1),
        ("a sweep: a kill, nothing leaked", sweep_code([0, 2]), 2),
        ("a sweep: all clean", sweep_code([0, 0]), 0),
        ("the demo list, read from the overlays", _planted_demo_list()[0], ["res://demos/a.tscn", "res://game/b.tscn"]),
        ("the modes, read from the overlays and the cards", _planted_demo_list()[1],
         [("res://game/b.tscn squad", ["--", "--open=demo-b", "--mode=squad"]), ("res://game/c.tscn x", [])]),
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
    parser.add_argument("--demos", action="store_true", help="every scene in check_demos.py's list, and every extra mode")
    parser.add_argument("--frames", type=int, default=FRAMES)
    parser.add_argument("--timeout", type=float, default=TIMEOUT)
    parser.add_argument("--self-test", action="store_true")
    options = parser.parse_args(argv)
    if options.self_test:
        return self_test()
    if (options.scene is None) == (not options.demos) or options.frames <= 0 or options.timeout <= 0:
        parser.print_usage(sys.stderr)
        return 2
    scenes = demo_scenes(ROOT) if options.demos else [options.scene]
    runs = [(scene, [scene]) for scene in scenes] + (demo_modes(ROOT) if options.demos else [])
    return run(runs, options.frames, options.timeout)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
