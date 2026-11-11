#!/usr/bin/env python3
"""Erase the valley's save in this checkout, and nothing else (T163, ADR 0025).

What it does
------------
The valley is the one example that remembers between sessions, and only a
record of deeds: `user://valley/`. The game has an erase button; this is
the same erase from the command line, for `make valley-erase`.

It asks `scripts/godot --gak-print-redirect` where this checkout's
`user://` is (ADR 0022: under `.user-data/`), rather than repeating the
rule, and removes `valley/` there. It refuses a folder outside the
checkout's `.user-data/`: a wrapper that stopped redirecting would point at
the home, and a command that deletes must not follow it there. Nor does
it follow a link: containment is decided on the path as written, and a
`.user-data/` or any folder below it that is a symbolic link is refused,
since a link resolved first lies wherever it points.

Exit codes
----------
0   erased, or there was nothing to erase
1   refused: no redirect, one outside this checkout's .user-data/, or a
    link on the way to it
2   wrong usage, or it could not ask or erase: no scripts/godot, a wrapper
    that did not answer, or a `valley` that is not a folder

Usage
-----
    valley_erase.py [--repo PATH]
    valley_erase.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

SAVE_FOLDER = "valley"
PROJECT_NAME_RE = re.compile(r'^config/name="([^"]+)"', re.M)


class CannotErase(Exception):
    """Something stopped the erase before it could decide: exit 2, with why."""


def redirect_of(repo: pathlib.Path, timeout: float = 60) -> dict[str, str]:
    """The NAME=PATH pairs this checkout's scripts/godot gives user://.

    CannotErase when the wrapper is missing or does not answer in time; an
    empty answer is `{}`, which `erase` refuses.
    """
    try:
        asked = subprocess.run([str(repo / "scripts" / "godot"), "--gak-print-redirect"], cwd=repo,
                               capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise CannotErase(f"could not ask scripts/godot where user:// is: {error}") from error
    if asked.returncode != 0:
        return {}
    pairs = [line.split("=", 1) for line in asked.stdout.splitlines() if "=" in line]
    return {name: value for name, value in pairs}


def save_folder(repo: pathlib.Path, redirect: dict[str, str]) -> pathlib.Path | None:
    """Where `user://valley/` is under that redirect, or None when it gives none.

    The engine's own layout, measured on 4.7.2 (docs/godot/user-data.md):
    `<XDG_DATA_HOME>/godot/app_userdata/<config/name>` on Linux, and
    `<APPDATA>/Godot/app_userdata/<config/name>` on Windows.
    """
    named = PROJECT_NAME_RE.search((repo / "godot" / "project.godot").read_text(encoding="utf-8"))
    project = named.group(1) if named else "game-ai-kit"
    if "XDG_DATA_HOME" in redirect:
        return pathlib.Path(redirect["XDG_DATA_HOME"]) / "godot" / "app_userdata" / project / SAVE_FOLDER
    if "APPDATA" in redirect:
        return pathlib.Path(redirect["APPDATA"]) / "Godot" / "app_userdata" / project / SAVE_FOLDER
    return None


def erase(repo: pathlib.Path, redirect: dict[str, str]) -> int:
    """Remove the save when it lies inside this checkout's `.user-data/`."""
    folder = save_folder(repo, redirect)
    if folder is None:
        print("valley-erase: scripts/godot gave no user:// redirect; nothing erased", file=sys.stderr)
        return 1
    why = outside_the_checkout(repo, folder)
    if why:
        print(f"valley-erase: {why}; refused, nothing erased", file=sys.stderr)
        return 1
    if not folder.exists():
        print(f"valley-erase: no save at {folder}; nothing to erase")
        return 0
    if not folder.is_dir():
        raise CannotErase(f"{folder} is not a folder; nothing erased")
    shutil.rmtree(folder)
    print(f"valley-erase: erased {folder}; the valley starts again from the first day")
    return 0


def outside_the_checkout(repo: pathlib.Path, folder: pathlib.Path) -> str:
    """Why `folder` is not safely inside this checkout's `.user-data/`, or "".

    Decided on absolute paths with `..` folded but no link followed, and
    then every step from `.user-data/` down is asked whether it is a link.
    """
    allowed = pathlib.Path(os.path.abspath(repo / ".user-data"))
    target = pathlib.Path(os.path.abspath(folder))
    if not target.is_relative_to(allowed):
        return f"{folder} is outside {allowed}"
    parts = target.relative_to(allowed).parts
    for depth in range(len(parts) + 1):
        step = allowed.joinpath(*parts[:depth])
        if step.is_symlink():
            return f"{step} is a symbolic link, and the erase does not follow one"
    return ""


def self_test() -> int:
    """Every planted case below, each a temporary checkout of its own."""
    failures = []
    with tempfile.TemporaryDirectory() as workspace, contextlib.redirect_stdout(io.StringIO()), \
            contextlib.redirect_stderr(io.StringIO()):
        failures += _self_test_refusals(pathlib.Path(workspace))
        failures += _self_test_erasing(pathlib.Path(workspace))
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def _checkout(workspace: pathlib.Path, name: str) -> pathlib.Path:
    """A temporary checkout with only the project file the erase reads."""
    repo = workspace / name
    (repo / "godot").mkdir(parents=True)
    (repo / "godot" / "project.godot").write_text('[application]\nconfig/name="game-ai-kit"\n')
    return repo


def _self_test_refusals(workspace: pathlib.Path) -> list[str]:
    """Planted: a redirect into the home, no redirect, and `.user-data` a
    link into the home are refused, and the home's save survives each."""
    failures = []
    repo = _checkout(workspace, "refusals")
    home = workspace / "home" / ".local" / "share"
    outside = home / "godot" / "app_userdata" / "game-ai-kit" / SAVE_FOLDER
    outside.mkdir(parents=True)
    if erase(repo, {"XDG_DATA_HOME": str(home)}) != 1 or not outside.exists():
        failures.append("a save in the home was erased, or not refused")
    if erase(repo, {}) != 1:
        failures.append("no redirect was not refused")
    (repo / ".user-data").symlink_to(home, target_is_directory=True)
    if erase(repo, {"XDG_DATA_HOME": str(repo / ".user-data")}) != 1 or not outside.exists():
        failures.append("a .user-data that is a link into the home was followed")
    try:
        redirect_of(repo)
        failures.append("a missing scripts/godot was not reported")
    except CannotErase:
        pass
    (repo / "scripts").mkdir()
    (repo / "scripts" / "godot").write_text("#!/bin/sh\nsleep 5\n")
    (repo / "scripts" / "godot").chmod(0o755)
    try:
        redirect_of(repo, timeout=0.5)
        failures.append("a wrapper that did not answer was not reported")
    except CannotErase:
        pass
    return failures


def _self_test_erasing(workspace: pathlib.Path) -> list[str]:
    """Sound: the checkout's save goes and its sibling stays; nothing to
    erase is a success; a `valley` that is a file is reported, and kept."""
    failures = []
    repo = _checkout(workspace, "erasing")
    xdg = repo / ".user-data" / "xdg"
    inside = xdg / "godot" / "app_userdata" / "game-ai-kit"
    (inside / SAVE_FOLDER).mkdir(parents=True)
    (inside / SAVE_FOLDER / "deeds.json").write_text("{}\n")
    (inside / "settings.cfg").write_text("[locale]\n")
    if erase(repo, {"XDG_DATA_HOME": str(xdg)}) != 0 or (inside / SAVE_FOLDER).exists():
        failures.append("the checkout's save was not erased")
    if not (inside / "settings.cfg").exists():
        failures.append("erasing the save removed something beside it")
    if erase(repo, {"XDG_DATA_HOME": str(xdg)}) != 0:
        failures.append("nothing to erase was not a success")
    (inside / SAVE_FOLDER).write_text("not a folder\n")
    try:
        erase(repo, {"XDG_DATA_HOME": str(xdg)})
        failures.append("a valley that is a file was not reported")
    except CannotErase:
        pass
    if not (inside / SAVE_FOLDER).is_file():
        failures.append("a valley that is a file was removed")
    return failures


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2
    if args.self_test:
        return self_test()
    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    try:
        return erase(repo, redirect_of(repo))
    except (CannotErase, OSError) as error:
        print(f"valley-erase: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
