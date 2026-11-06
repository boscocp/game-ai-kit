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

A third, `.toolchain/` (T143), is linked instead: the toolchain when
GAK_TOOLCHAIN is not set, gigabytes, and shared by every checkout. A main
checkout without one is a note, never a refusal.

Why copies, not links
---------------------
Godot writes `.uid` files beside the scripts of an addon it imports, so two
checkouts importing one linked gdUnit4 write one folder at once -- the
collision T83 removes for `user://`. And a link on Windows needs a privilege
Git Bash does not have.

Exit codes
----------
0   everything needed is present now
2   a source is missing in the main checkout (run there, a needed file is
    missing), the main repository is bare, or git cannot list the checkouts

A gdUnit4 whose `.pinned-version` is not the tag this checkout's
bootstrap.sh pins is said, not refused: a branch may move the pin, and the
copy still runs the suites.

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
import re
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

# The checkout's own toolchain folder, linked rather than copied (T143).
TOOLCHAIN = ".toolchain"

# The line in bootstrap.sh that pins gdUnit4's tag, e.g. gdunit_tag="v6.2.2".
GDUNIT_TAG = re.compile(r'^gdunit_tag="([^"]+)"', re.M)


def main_checkout(porcelain: str) -> tuple[pathlib.Path | None, bool]:
    """The main checkout in `git worktree list --porcelain`, and whether it is bare.

    Git lists the main one first. A bare repository has no working tree, so
    there is nothing in it to copy from.
    """
    blocks = [block.splitlines() for block in porcelain.strip().split("\n\n") if block.strip()]
    if not blocks or not blocks[0][0].startswith("worktree "):
        return None, False
    return pathlib.Path(blocks[0][0].split(" ", 1)[1]), "bare" in blocks[0][1:]


def pinned_gdunit_tag(bootstrap: pathlib.Path) -> str | None:
    """The gdUnit4 tag `make bootstrap` installs, read from bootstrap.sh itself."""
    if not bootstrap.is_file():
        return None
    found = GDUNIT_TAG.search(bootstrap.read_text(encoding="utf-8", errors="replace"))
    return found.group(1) if found else None


def gdunit_note(here: pathlib.Path) -> str:
    """A line when this checkout's gdUnit4 is not the tag its bootstrap.sh pins, else ""."""
    wanted = pinned_gdunit_tag(here / "scripts" / "bootstrap.sh")
    marker = here / "godot" / "addons" / "gdUnit4" / ".pinned-version"
    have = marker.read_text(encoding="utf-8").split()[0] if marker.is_file() else "no .pinned-version"
    if wanted is None or have == wanted:
        return ""
    return (f"worktree-setup: note     godot/addons/gdUnit4 is {have}, and this checkout's "
            f"bootstrap.sh pins {wanted}; run make bootstrap here")


def copy_one(source: pathlib.Path, target: pathlib.Path) -> None:
    """Copy a file or a whole folder beside the target, then rename it into place.

    A copy cut short (^C, a full disk) leaves only the hidden sibling, never a
    half folder at the target, which a second run would report as present.
    """
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_name(f".{target.name}.partial")
    if partial.is_dir():
        shutil.rmtree(partial)
    else:
        partial.unlink(missing_ok=True)
    if source.is_dir():
        shutil.copytree(source, partial, symlinks=True)
    else:
        shutil.copy2(source, partial)
    partial.rename(target)


def missing_in_main(main: pathlib.Path) -> int:
    """Run in the main checkout: say which needed file is missing here; 2 if any is."""
    missing = 0
    for relative, how in NEEDED:
        if (main / relative).exists():
            print(f"worktree-setup: present  {relative} (main checkout)")
        else:
            print(f"worktree-setup: MISSING  {relative} in the main checkout; make it with: {how}")
            missing += 1
    return 2 if missing else 0


def set_up(here: pathlib.Path, main: pathlib.Path) -> int:
    """Copy into `here` each needed path it lacks; 2 if a source is missing."""
    if here.resolve() == main.resolve():
        print(f"worktree-setup: {here} is the main checkout; nothing to copy")
        return missing_in_main(main)
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
    link_toolchain(here, main)
    note = gdunit_note(here)
    if note:
        print(note)
    return 2 if refused else 0


def link_toolchain(here: pathlib.Path, main: pathlib.Path) -> None:
    """Point this worktree's `.toolchain` at the main checkout's, when it has one.

    `.toolchain/` is the toolchain when GAK_TOOLCHAIN is not set (T143), and
    a new worktree has none: without this, every Godot gate there says
    "run make bootstrap". A link, not a copy: it is gigabytes, and every
    checkout shared one toolchain before T143 too. Never refused -- with
    GAK_TOOLCHAIN set nothing reads it -- only said.
    """
    target, source = here / TOOLCHAIN, main / TOOLCHAIN
    if target.exists() or target.is_symlink():
        print(f"worktree-setup: present  {TOOLCHAIN}")
    elif not source.exists():
        print(f"worktree-setup: note     no {TOOLCHAIN} in the main checkout; "
              "GAK_TOOLCHAIN, or make bootstrap there, gives one")
    else:
        try:
            target.symlink_to(source.resolve(), target_is_directory=True)
            print(f"worktree-setup: linked   {TOOLCHAIN} to {source.resolve()}")
        except OSError as error:
            print(f"worktree-setup: note     {TOOLCHAIN} not linked ({error}); "
                  f"set GAK_TOOLCHAIN={source.resolve()}")


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

    def printed(here: pathlib.Path, main: pathlib.Path) -> str:
        stream = io.StringIO()
        with contextlib.redirect_stdout(stream):
            set_up(here, main)
        return stream.getvalue()

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        main = root / "main"
        (main / "godot/addons/gdUnit4/bin").mkdir(parents=True)
        (main / "godot/addons/gdUnit4/bin/GdUnitCmdTool.gd").write_text("extends SceneTree\n")
        (main / "godot/addons/gdUnit4/.pinned-version").write_text("v6.2.2\nsha256:x\n")
        (main / "scripts").mkdir()
        (main / "scripts/forbidden-term-hashes.txt").write_text("salt\nhash\n")

        fresh = root / "fresh"
        (fresh / "scripts").mkdir(parents=True)
        (fresh / "scripts/bootstrap.sh").write_text('gdunit_tag="v6.2.2"\n')
        # Planted: a copy cut short by an earlier run. Its leftover sibling
        # is not the folder, and is cleared before the next copy.
        (fresh / "godot/addons/.gdUnit4.partial/half").mkdir(parents=True)
        expect("a fresh worktree", quiet(fresh, main), 0)
        expect("gdUnit4 copied", (fresh / "godot/addons/gdUnit4/bin/GdUnitCmdTool.gd").is_file(), True)
        expect("no partial copy left", (fresh / "godot/addons/.gdUnit4.partial").exists(), False)
        expect("no stale half inside", (fresh / "godot/addons/gdUnit4/half").exists(), False)
        expect("term list copied", (fresh / "scripts/forbidden-term-hashes.txt").read_text(),
               "salt\nhash\n")
        expect("the pinned gdUnit4 says nothing", "bootstrap.sh pins" in printed(fresh, main), False)

        # Idempotent: a second run leaves the worktree's own copy alone.
        (fresh / "scripts/forbidden-term-hashes.txt").write_text("its own\n")
        expect("a second run", quiet(fresh, main), 0)
        expect("its own copy kept", (fresh / "scripts/forbidden-term-hashes.txt").read_text(),
               "its own\n")

        # Planted: this branch's bootstrap.sh pins another gdUnit4 than the
        # one copied from main. Said, not refused: the copy is still usable.
        (fresh / "scripts/bootstrap.sh").write_text('gdunit_tag="v6.3.0"\n')
        expect("another gdUnit4 than the pinned one is said", "pins v6.3.0" in printed(fresh, main), True)

        # Planted: the main checkout has no term list. Refused, and the
        # rest still copied.
        bare_main, waiting = root / "bare-main", root / "waiting"
        shutil.copytree(main / "godot", bare_main / "godot")
        waiting.mkdir()
        expect("a missing source", quiet(waiting, bare_main), 2)
        expect("nothing invented for it", (waiting / "scripts/forbidden-term-hashes.txt").exists(), False)
        expect("the rest still copied", (waiting / "godot/addons/gdUnit4").is_dir(), True)

        # T143: the main checkout's .toolchain is linked, never copied, and
        # a worktree's own is left alone.
        expect("no .toolchain in main: nothing made", (fresh / ".toolchain").is_symlink(), False)
        (main / ".toolchain" / "godot").mkdir(parents=True)
        quiet(fresh, main)
        expect(".toolchain linked", (fresh / ".toolchain").is_symlink(), True)
        expect("... to the main checkout's", (fresh / ".toolchain").resolve(),
               (main / ".toolchain").resolve())
        own_toolchain = root / "own-toolchain"
        (own_toolchain / ".toolchain").mkdir(parents=True)
        quiet(own_toolchain, main)
        expect("a worktree's own .toolchain kept", (own_toolchain / ".toolchain").is_symlink(), False)

        expect("run in a complete main checkout", quiet(main, main), 0)
        # Planted: run in a main checkout that lacks what worktrees need.
        expect("run in a main checkout missing the term list", quiet(bare_main, bare_main), 2)

    porcelain = ("worktree /big/repo\nHEAD 6d615cb\nbranch refs/heads/main\n\n"
                 "worktree /big/repo/.claude/worktrees/one\nHEAD 6d615cb\ndetached\n")
    expect("the main checkout is listed first", main_checkout(porcelain),
           (pathlib.Path("/big/repo"), False))
    expect("a bare main repository is said", main_checkout(
        "worktree /big/repo.git\nbare\n\nworktree /big/one\nHEAD 6d615cb\ndetached\n"),
        (pathlib.Path("/big/repo.git"), True))
    expect("no checkout listed", main_checkout(""), (None, False))

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
    main_path, bare = main_checkout(listed.stdout) if listed.returncode == 0 else (None, False)
    if main_path is None:
        print(f"worktree-setup: git lists no checkout for {here}", file=sys.stderr)
        return 2
    if bare:
        print(f"worktree-setup: the main repository at {main_path} is bare, with no files "
              "to copy; run make bootstrap here, and build the term list with --add-term",
              file=sys.stderr)
        return 2
    return set_up(here, main_path)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
