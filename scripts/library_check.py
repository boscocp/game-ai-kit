#!/usr/bin/env python3
"""Install the release where a stranger would, and run it there (T64).

The release's own self-test proves what is *in* each archive. This proves
the archives *work* away from this repository, which is the only place a
library is used:

  * **Python.** A fresh virtual environment in a throwaway directory
    outside the tree installs the wheel -- no index, no dependencies, so
    a wheel that needed either fails -- and imports a technique and the
    registry from it, with the repository nowhere on the path.
  * **Godot.** A blank project in the same throwaway directory, holding
    only `addons/ai_core/` and `addons/ai_search/` as their zips unpack,
    imports itself and runs `scripts/library/stranger.gd`, which finds a
    route with the classes the documentation names. The run must exit 0
    *and* print the script's marker: a script error inside a `-s` script
    still exits 0 (CLAUDE.md).

The release is built from HEAD by `release.py`, into the throwaway
directory, so what is checked is what `make release` ships.

Why `--self-test` exists
------------------------
To prove the check refuses. It builds the release, takes `grid_graph.gd`
out of `ai_core`'s zip -- the file every script of `ai_search` needs -- and
expects the Godot half to fail; then takes `gameaikit/utility/aim.py` out
of the wheel's install and expects the Python half to fail.

Exit codes
----------
0   both halves ran outside the repository
1   one half failed (what failed is printed)
2   wrong usage, or the release could not be built

Usage
-----
    library_check.py
    library_check.py --self-test
"""

from __future__ import annotations

import argparse
import pathlib
import shutil
import subprocess
import sys
import tempfile
import venv
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
GODOT = REPO / "scripts" / "godot"
STRANGER = REPO / "scripts" / "library" / "stranger.gd"
MARKER = "LIBRARY-CHECK: the route goes round the wall"
ADDONS = ("ai_core", "ai_search")
PROBE = (
    "from gameaikit import techniques\n"
    "from gameaikit.utility import aim\n"
    "import gameaikit, pathlib\n"
    "assert 'aim-choice' in techniques.available(), 'the registry lists the kit'\n"
    "assert 'site-packages' in pathlib.Path(gameaikit.__file__).parts, gameaikit.__file__\n"
    "head = aim.Zone('head', 2.0, (0.0, 1.65), [(-0.12, 1.5, 0.12, 1.8)], 1.0)\n"
    "torso = aim.Zone('torso', 1.0, (0.0, 1.175), [(-0.2, 0.85, 0.2, 1.5)], 1.0)\n"
    "assert aim.choose([head, torso], 0.5).aimed == 1, 'far away, the torso'\n"
    "print('LIBRARY-CHECK: the wheel answers from site-packages')\n"
)


class Unbuildable(Exception):
    """The release could not be built, so there is nothing to check."""


def build_release(into: pathlib.Path) -> dict[str, pathlib.Path]:
    """Every artifact `release.py` builds from HEAD, by file name."""
    built = subprocess.run(
        [sys.executable, str(REPO / "scripts" / "release.py"), "--build", "--output", str(into)],
        capture_output=True, text=True,
    )
    if built.returncode != 0:
        raise Unbuildable(built.stderr.strip())
    return {pathlib.Path(line).name: pathlib.Path(line) for line in built.stdout.split()}


def the_one(artifacts: dict[str, pathlib.Path], prefix: str) -> pathlib.Path:
    """The artifact whose name starts with `prefix`."""
    return next(path for name, path in artifacts.items() if name.startswith(prefix))


def python_half(wheel: pathlib.Path, place: pathlib.Path, drop: str = "") -> list[str]:
    """Install `wheel` in a fresh environment and run the probe; what failed, if anything.

    `drop` deletes one installed file before the probe -- the self-test's
    planted fault.
    """
    environment = place / "venv"
    venv.EnvBuilder(with_pip=True, clear=True).create(environment)
    python = environment / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")
    install = subprocess.run(
        [str(python), "-m", "pip", "install", "--quiet", "--no-index", "--no-deps", str(wheel)],
        capture_output=True, text=True, cwd=place,
    )
    if install.returncode != 0:
        return [f"the wheel does not install: {install.stderr.strip()}"]
    if drop:
        for found in environment.rglob(drop):
            found.unlink()
    probe = subprocess.run([str(python), "-I", "-c", PROBE], capture_output=True, text=True, cwd=place)
    if probe.returncode != 0 or "LIBRARY-CHECK" not in probe.stdout:
        return [f"the installed wheel does not answer: {probe.stderr.strip().splitlines()[-1:]}"]
    return []


def blank_project(place: pathlib.Path, zips: list[pathlib.Path]) -> pathlib.Path:
    """A Godot project with nothing in it but the unzipped addons and the stranger's script."""
    project = place / "stranger"
    (project / "addons").mkdir(parents=True)
    (project / "project.godot").write_text(
        "config_version=5\n\n[application]\n\nconfig/name=\"A stranger's game\"\n")
    for archive in zips:
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(project / "addons")
    shutil.copy(STRANGER, project / STRANGER.name)
    return project


def godot_half(zips: list[pathlib.Path], place: pathlib.Path) -> list[str]:
    """Run the stranger's script in a blank project holding `zips`; what failed, if anything."""
    project = blank_project(place, zips)
    imported = subprocess.run([str(GODOT), "--headless", "--path", str(project), "--import"],
                              capture_output=True, text=True)
    if imported.returncode != 0:
        return [f"the blank project does not import (exit {imported.returncode})"]
    ran = subprocess.run([str(GODOT), "--headless", "--path", str(project), "-s", STRANGER.name],
                         capture_output=True, text=True)
    output = ran.stdout + ran.stderr
    if ran.returncode != 0 or MARKER not in output:
        errors = [line for line in output.splitlines() if "ERROR" in line][:3]
        return [f"the addons do not run in a blank project (exit {ran.returncode}): {errors}"]
    return []


def addon_zips(artifacts: dict[str, pathlib.Path]) -> list[pathlib.Path]:
    """The zips of the addons the stranger's script needs."""
    return [the_one(artifacts, f"{addon}-") for addon in ADDONS]


def without(archive: pathlib.Path, member: str) -> pathlib.Path:
    """A copy of `archive` with `member` taken out: the self-test's planted fault."""
    planted = archive.with_name(f"planted-{archive.name}")
    with zipfile.ZipFile(archive) as source, zipfile.ZipFile(planted, "w") as copy:
        for entry in source.infolist():
            if entry.filename != member:
                copy.writestr(entry, source.read(entry))
    return planted


def check() -> int:
    """Both halves, outside the repository."""
    with tempfile.TemporaryDirectory(prefix="gak-library-") as workspace:
        place = pathlib.Path(workspace)
        artifacts = build_release(place / "release")
        failures = python_half(the_one(artifacts, "gameaikit-"), place)
        failures += godot_half(addon_zips(artifacts), place)
    for failure in failures:
        print(f"library-check: {failure}")
    if not failures:
        print("library-check: the wheel and two addons ran outside the repository")
    return 1 if failures else 0


def self_test() -> int:
    """Each half, given a planted fault, must report it."""
    failures = []
    with tempfile.TemporaryDirectory(prefix="gak-library-selftest-") as workspace:
        place = pathlib.Path(workspace)
        artifacts = build_release(place / "release")
        core, search = addon_zips(artifacts)
        if not godot_half([without(core, "ai_core/grid_graph.gd"), search], place / "no-grid"):
            failures.append("an ai_core zip without grid_graph.gd fails the Godot half")
        if not python_half(the_one(artifacts, "gameaikit-"), place / "no-aim", drop="aim.py"):
            failures.append("a wheel install without utility/aim.py fails the Python half")
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    try:
        return self_test() if args.self_test else check()
    except Unbuildable as refusal:
        print(f"library-check: the release does not build: {refusal}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
