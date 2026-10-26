#!/usr/bin/env python3
"""Give a new git worktree the ignored files the main checkout has and it needs.

The rule
--------
Two things this repository needs are ignored by git on purpose, so a new
worktree starts without them:

  * `godot/addons/gdUnit4/`, installed by `make bootstrap` and never vendored
    (docs/adr/0004). Without it every Godot suite fails to start;
  * `scripts/forbidden-term-hashes.txt`, the author's list of terms that must
    never enter the repository (docs/adr/0005). Without it
    `check_no_employer_refs.py` checks nothing and passes, saying so only in a
    note -- the quiet kind of failure.

This copies each one from the main checkout (`git worktree list --porcelain`
names it first) when the worktree lacks it, and leaves alone what is there,
so running it twice changes nothing. A source the main checkout lacks is
refused by name, with the command that makes it; the others are still copied.

Why copies, not links
---------------------
Godot writes `.uid` files beside the scripts of an addon it imports, so two
checkouts importing one linked gdUnit4 write one folder at once -- the
collision T83 removes for `user://`. And a link on Windows needs a privilege
Git Bash does not have.

Exit codes
----------
0   everything needed is present now (or this is the main checkout)
2   a source is missing in the main checkout, or git cannot list the checkouts

Usage
-----
    worktree_setup.py [--repo PATH]
    worktree_setup.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import shutil
import subprocess
import sys
import tempfile

# What a worktree needs, and the command that makes it in the main checkout.
NEEDED = (
    ("godot/addons/gdUnit4", "make bootstrap"),
    ("scripts/forbidden-term-hashes.txt",
     "python3 scripts/check_no_employer_refs.py --add-term (docs/adr/0005)"),
)


def main_checkout(porcelain: str) -> pathlib.Path | None:
    """The main checkout in `git worktree list --porcelain`: git lists it first."""
    for line in porcelain.splitlines():
        if line.startswith("worktree "):
            return pathlib.Path(line.split(" ", 1)[1])
    return None


def copy_one(source: pathlib.Path, target: pathlib.Path) -> None:
    """Copy a file or a whole folder, making the folders above it."""
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, target, symlinks=True)
    else:
        shutil.copy2(source, target)


def set_up(here: pathlib.Path, main: pathlib.Path) -> int:
    """Copy into `here` each needed path it lacks; 2 if a source is missing."""
    if here.resolve() == main.resolve():
        print(f"worktree-setup: {here} is the main checkout; nothing to copy")
        return 0
    refused = 0
    for relative, how in NEEDED:
        target, source = here / relative, main / relative
        if target.exists():
            print(f"worktree-setup: present  {relative}")
        elif not source.exists():
            print(f"worktree-setup: REFUSED  {relative} -- the main checkout has none at "
                  f"{source}; make it there with: {how}")
            refused += 1
        else:
            copy_one(source, target)
            print(f"worktree-setup: copied   {relative} from {main}")
    return 2 if refused else 0


# --- self-test -------------------------------------------------------------


def self_test() -> int:
    """Planted checkouts: copied once, left alone twice, refused without a source."""
    failures = []

    def expect(label: str, got: object, want: object) -> None:
        if got != want:
            failures.append(f"{label}: expected {want!r}, got {got!r}")

    def quiet(here: pathlib.Path, main: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return set_up(here, main)

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        main = root / "main"
        (main / "godot/addons/gdUnit4/bin").mkdir(parents=True)
        (main / "godot/addons/gdUnit4/bin/GdUnitCmdTool.gd").write_text("extends SceneTree\n")
        (main / "scripts").mkdir()
        (main / "scripts/forbidden-term-hashes.txt").write_text("salt\nhash\n")

        fresh = root / "fresh"
        fresh.mkdir()
        expect("a fresh worktree", quiet(fresh, main), 0)
        expect("gdUnit4 copied", (fresh / "godot/addons/gdUnit4/bin/GdUnitCmdTool.gd").is_file(), True)
        expect("term list copied", (fresh / "scripts/forbidden-term-hashes.txt").read_text(),
               "salt\nhash\n")

        # Idempotent: a second run leaves the worktree's own copy alone.
        (fresh / "scripts/forbidden-term-hashes.txt").write_text("its own\n")
        expect("a second run", quiet(fresh, main), 0)
        expect("its own copy kept", (fresh / "scripts/forbidden-term-hashes.txt").read_text(),
               "its own\n")

        # Planted: the main checkout has no term list. Refused, and the
        # rest still copied.
        bare_main, waiting = root / "bare-main", root / "waiting"
        shutil.copytree(main / "godot", bare_main / "godot")
        waiting.mkdir()
        expect("a missing source", quiet(waiting, bare_main), 2)
        expect("nothing invented for it", (waiting / "scripts/forbidden-term-hashes.txt").exists(), False)
        expect("the rest still copied", (waiting / "godot/addons/gdUnit4").is_dir(), True)

        expect("run in the main checkout", quiet(main, main), 0)

    porcelain = ("worktree /big/repo\nHEAD 6d615cb\nbranch refs/heads/main\n\n"
                 "worktree /big/repo/.claude/worktrees/one\nHEAD 6d615cb\ndetached\n")
    expect("the main checkout is listed first", main_checkout(porcelain), pathlib.Path("/big/repo"))
    expect("no checkout listed", main_checkout(""), None)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Find the main checkout with git, then copy what this one lacks."""
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

    here = pathlib.Path(args.repo or pathlib.Path(__file__).resolve().parent.parent)
    listed = subprocess.run(["git", "-C", str(here), "worktree", "list", "--porcelain"],
                            capture_output=True, text=True)
    main_path = main_checkout(listed.stdout) if listed.returncode == 0 else None
    if main_path is None:
        print(f"worktree-setup: git lists no checkout for {here}", file=sys.stderr)
        return 2
    return set_up(here, main_path)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
