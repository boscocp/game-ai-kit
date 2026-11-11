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
the home, and a command that deletes must not follow it there.

Exit codes
----------
0   erased, or there was nothing to erase
1   refused: no redirect, or one outside this checkout's .user-data/
2   wrong usage

Usage
-----
    valley_erase.py [--repo PATH]
    valley_erase.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

SAVE_FOLDER = "valley"
PROJECT_NAME_RE = re.compile(r'^config/name="([^"]+)"', re.M)


def redirect_of(repo: pathlib.Path) -> dict[str, str]:
    """The NAME=PATH pairs this checkout's scripts/godot gives user://."""
    asked = subprocess.run([str(repo / "scripts" / "godot"), "--gak-print-redirect"], cwd=repo,
                           capture_output=True, text=True, timeout=60)
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
    allowed = (repo / ".user-data").resolve()
    if not folder.resolve().is_relative_to(allowed):
        print(f"valley-erase: {folder} is outside {allowed}; refused, nothing erased", file=sys.stderr)
        return 1
    if not folder.exists():
        print(f"valley-erase: no save at {folder}; nothing to erase")
        return 0
    shutil.rmtree(folder)
    print(f"valley-erase: erased {folder}; the valley starts again from the first day")
    return 0


def self_test() -> int:
    """Planted: a redirect into the home is refused and deletes nothing; no
    redirect is refused; a sound one removes `valley/` and its sibling stays."""
    failures = []
    with tempfile.TemporaryDirectory() as workspace, contextlib.redirect_stdout(io.StringIO()), \
            contextlib.redirect_stderr(io.StringIO()):
        repo = pathlib.Path(workspace) / "repo"
        (repo / "godot").mkdir(parents=True)
        (repo / "godot" / "project.godot").write_text('[application]\nconfig/name="game-ai-kit"\n')
        home = pathlib.Path(workspace) / "home" / ".local" / "share"
        outside = home / "godot" / "app_userdata" / "game-ai-kit" / SAVE_FOLDER
        outside.mkdir(parents=True)
        if erase(repo, {"XDG_DATA_HOME": str(home)}) != 1 or not outside.exists():
            failures.append("a save in the home was erased, or not refused")
        if erase(repo, {}) != 1:
            failures.append("no redirect was not refused")
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
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


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
    return erase(repo, redirect_of(repo))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
