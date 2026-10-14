#!/usr/bin/env python3
"""Fail if the Godot toolchain, or the art generator's model, writes to the small disk.

The rule
--------
Everything this project installs lives on the large disk, under the toolchain
directory. Nothing lands in the user's home.

Why this gate exists
--------------------
On 2026-10-12, during bootstrap, enabling Godot's self-contained mode (an empty
`._sc_` file next to the binary) was assumed to be enough. It is not. Measured
on Godot 4.7.2: `._sc_` redirects editor settings, cache and export templates
-- the part that grows past 1 GB -- but a single `--headless --import` still
recreated `~/.local/share/godot/app_userdata/`, because the project's `user://`
directory is not editor data. The second mechanism, XDG_DATA_HOME, covers it.

Two mechanisms means two ways to silently regress, so both are asserted here
rather than trusted.

The art generator (T31) has the same trap, larger: tens of GB of model that Hugging
Face, torch and Triton would all cache under ~/.cache by default. scripts/artgen
points every one of them at the toolchain directory, and the paths below say
where they would land if it stopped.

Exit codes
----------
0   clean: nothing on the small disk, toolchain intact
1   violations found (each one printed)
2   wrong usage, or a path that cannot be read

Usage
-----
    check_disk_layout.py [--repo PATH] [--toolchain PATH] [--home PATH]
    check_disk_layout.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import os
import pathlib
import subprocess
import sys
import tempfile

# Where Godot writes when neither mechanism is in place. Relative to home.
LEAK_PATHS = (
    ".local/share/godot",
    ".config/godot",
    ".cache/godot",
    # Added after a review pointed out the list was three fixed paths and the
    # engine has more than three places to write.
    ".local/state/godot",
    ".godot",
    # The art generator's model and kernel caches, where they land without
    # scripts/artgen. ~/.cache/pip and ~/.nv are not listed: on the owner's
    # machine other software already keeps caches there, so their presence
    # says nothing about this repository. That pip and the driver honour
    # PIP_CACHE_DIR and CUDA_CACHE_PATH was measured instead, by mtime.
    # The three below are shared with any other machine-learning project, so
    # a developer with one will see this fire: that is the price of catching
    # a 30 GB model landing on the small disk, and the message says where from.
    ".cache/huggingface",
    ".cache/torch",
    ".triton",
)

DEFAULT_TOOLCHAIN = "/mnt/games/gamedev/toolchain"


def find_leaks(home: pathlib.Path) -> list[str]:
    """Report any Godot directory, or model cache, that exists under home.

    An empty leftover directory is reported too: it means a mechanism stopped
    working, and the files follow the directory.
    """
    findings = []
    for relative in LEAK_PATHS:
        leaked = home / relative
        if leaked.exists():
            size = sum(f.stat().st_size for f in leaked.rglob("*") if f.is_file())
            findings.append(f"D1 {leaked} exists on the small disk ({size} bytes)")
    return findings


def check_toolchain(toolchain: pathlib.Path) -> list[str]:
    """Report a toolchain that is missing or has lost self-contained mode."""
    findings = []
    binary = toolchain / "godot" / "godot"
    marker = toolchain / "godot" / "._sc_"

    # `exists()` was true for a *directory* named godot/godot, which then
    # satisfied every other check here.
    if not binary.is_file() or not os.access(binary, os.X_OK):
        findings.append(f"D2 no executable Godot at {binary} -- run 'make bootstrap'")
        return findings
    if not marker.exists():
        findings.append(f"D3 self-contained marker missing: {marker}")
    if not (toolchain / "godot" / "editor_data").exists():
        findings.append(f"D4 no editor_data/ beside the binary; is ._sc_ being honoured?")
    return findings


def check_repo_location(repo: pathlib.Path, home: pathlib.Path) -> list[str]:
    """Report a repository that sits on the small disk."""
    try:
        repo.resolve().relative_to(home.resolve())
    except ValueError:
        return []
    return [f"D5 the repository itself is under {home} -- it belongs on the large disk"]


def run(repo: pathlib.Path, toolchain: pathlib.Path, home: pathlib.Path) -> int:
    findings = find_leaks(home) + check_toolchain(toolchain) + check_repo_location(repo, home)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------
#
# Every gate in this repo is born with a case it must reject. A gate that only
# knows how to go green is worse than no gate, because nobody investigates a
# green.


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(*call_args) -> int:
        """Run the check without printing: a planted finding is not a failure."""
        with contextlib.redirect_stdout(io.StringIO()):
            return run(*call_args)

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        clean_home = root / "clean-home"
        clean_home.mkdir()
        good_toolchain = root / "toolchain"
        (good_toolchain / "godot" / "editor_data").mkdir(parents=True)
        binary = good_toolchain / "godot" / "godot"
        binary.write_text("#!/bin/sh\n")
        binary.chmod(0o755)
        (good_toolchain / "godot" / "._sc_").touch()
        repo_off_home = root / "repo"
        repo_off_home.mkdir()

        expect("clean layout", quiet(repo_off_home, good_toolchain, clean_home), 0)

        # Planted: the exact leak measured during bootstrap.
        dirty_home = root / "dirty-home"
        (dirty_home / ".local/share/godot/app_userdata/game-ai-kit").mkdir(parents=True)
        expect("leaked user:// dir", quiet(repo_off_home, good_toolchain, dirty_home), 1)

        # Planted: the generator run without its wrapper, fetching a model
        # into Hugging Face's default cache.
        model_home = root / "model-home"
        (model_home / ".cache/huggingface/hub/models--some--model").mkdir(parents=True)
        expect("a model cache under home", quiet(repo_off_home, good_toolchain, model_home), 1)
        # Planted: torch's and Triton's caches, each on its own -- with only
        # the Hugging Face case, deleting either path from the list stayed green.
        for leak in (".cache/torch/hub", ".triton/cache"):
            leaked_home = root / ("leak-" + leak.replace("/", "-"))
            (leaked_home / leak).mkdir(parents=True)
            expect(f"{leak} under home", quiet(repo_off_home, good_toolchain, leaked_home), 1)

        # Planted: someone removed the self-contained marker.
        no_marker = root / "no-marker"
        (no_marker / "godot" / "editor_data").mkdir(parents=True)
        (no_marker / "godot" / "godot").write_text("#!/bin/sh\n")
        (no_marker / "godot" / "godot").chmod(0o755)
        expect("missing ._sc_", quiet(repo_off_home, no_marker, clean_home), 1)

        # Planted: a directory where the binary should be. exists() said yes.
        a_directory = root / "adirectory"
        (a_directory / "godot" / "godot").mkdir(parents=True)
        (a_directory / "godot" / "editor_data").mkdir()
        (a_directory / "godot" / "._sc_").touch()
        expect("a directory named godot/godot", quiet(repo_off_home, a_directory, clean_home), 1)

        # Planted: a non-executable file where the binary should be.
        not_executable = root / "notexec"
        (not_executable / "godot" / "editor_data").mkdir(parents=True)
        (not_executable / "godot" / "godot").write_text("#!/bin/sh\n")
        (not_executable / "godot" / "godot").chmod(0o644)
        (not_executable / "godot" / "._sc_").touch()
        expect("binary without the execute bit",
               quiet(repo_off_home, not_executable, clean_home), 1)

        # Planted: no toolchain at all.
        expect("absent toolchain", quiet(repo_off_home, root / "nowhere", clean_home), 1)

        # Planted: the repository living on the small disk.
        repo_on_home = clean_home / "projects" / "game-ai-kit"
        repo_on_home.mkdir(parents=True)
        expect("repo under home", quiet(repo_on_home, good_toolchain, clean_home), 1)

        # Usage errors must be exit 2, never confused with a finding.
        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"],
            capture_output=True,
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--repo", default=None)
    parser.add_argument("--toolchain", default=None)
    parser.add_argument("--home", default=None)
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        # argparse raises SystemExit for `--help` too, with code 0. Catching it
        # blindly turned a successful --help into exit 2 in every gate here.
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    toolchain = pathlib.Path(
        args.toolchain or os.environ.get("GAK_TOOLCHAIN", DEFAULT_TOOLCHAIN)
    )
    home = pathlib.Path(args.home or pathlib.Path.home())

    try:
        return run(repo, toolchain, home)
    except OSError as error:
        print(f"check_disk_layout: cannot read a path: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
