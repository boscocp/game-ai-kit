#!/usr/bin/env python3
"""Refuse to start a wave on a stale base, and refuse to merge an unreviewed one.

The rule
--------
Work happens on a branch, one branch per wave, and the review lands **before**
the merge rather than after it. The branch is cut from a `main` that is current.

Why this gate exists
--------------------
Both halves were learned the expensive way.

A sentence in an instructions file saying "update main before branching" does
not hold: in the author's other repository it was written after an incident and
the very next session repeated the error, and it only stopped once a script
refused a stale base.

The second half is this repository's own mistake. The first four waves went
straight onto `main` with no branch, no review and no CI -- seven commits of
gate code read by nobody but their author, which is exactly the symmetry the
whole apparatus exists to break. `--check-review` is the rule stated as an exit
code so that it cannot be forgotten again.

Modes
-----
    --check-base      main is current and the tree is clean: safe to cut a branch
    --check-review    this branch has a review record, so it may be merged

Exit codes
----------
0   safe to proceed
1   not safe (the reason is printed)
2   wrong usage, or git is unavailable

Usage
-----
    check_branch_base.py --check-base
    check_branch_base.py --check-review [--branch NAME]
    check_branch_base.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import re
import subprocess
import sys
import tempfile

BRANCH_RE = re.compile(r"^(wave|fix|docs|chore|tasks)/[a-z0-9][a-z0-9-]*$")
REVIEW_DIR = "docs/reviews"


def git(repo: pathlib.Path, *args: str) -> str:
    done = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True, check=True
    )
    return done.stdout.strip()


def check_base(repo: pathlib.Path) -> list[str]:
    """main is current and the tree is clean, so a new branch starts level."""
    problems = []

    if git(repo, "status", "--porcelain"):
        problems.append("B1 the working tree is dirty; commit or stash before branching")

    # Branching from wherever you happen to be stacks the new wave on the old
    # one. This was not checked at all, so cutting a branch while still on the
    # previous wave's branch passed.
    current = git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    if current != "main":
        problems.append(f"B4 you are on {current}, not main; a wave branches from main")

    has_remote = bool(git(repo, "remote"))
    if has_remote:
        fetched = subprocess.run(
            ["git", "-C", str(repo), "fetch", "--quiet", "origin"],
            capture_output=True, check=False,
        )
        # A failed fetch used to be ignored, which left origin/main at whatever
        # it was last time: `main..origin/main` then counted zero and the check
        # passed while main was behind. A check that cannot see is not a check
        # that passes.
        if fetched.returncode != 0:
            return problems + [
                "B5 could not fetch origin; staleness is unknown, so this is not a pass"
            ]
        try:
            behind = git(repo, "rev-list", "--count", "main..origin/main")
        except subprocess.CalledProcessError:
            return problems + ["B2 cannot compare main with origin/main"]
        if behind != "0":
            problems.append(
                f"B3 main is {behind} commit(s) behind origin/main; pull before branching"
            )
    # With no remote there is nothing to be stale against, and saying so beats
    # passing silently: the check is weaker here and the operator should know.
    else:
        print("B0 note: no remote configured, so staleness cannot be checked")

    return problems


def check_review(repo: pathlib.Path, branch: str) -> list[str]:
    """This branch carries a review record written by something that did not write the code."""
    if branch in ("main", "HEAD"):
        return ["R1 you are on main; a wave is merged from its branch, not committed here"]

    if not BRANCH_RE.match(branch):
        return [f"R2 branch {branch!r} is not <wave|fix|docs|chore|tasks>/<slug>"]

    slug = branch.split("/", 1)[1]
    record = repo / REVIEW_DIR / f"{slug}.md"
    if not record.exists():
        return [
            f"R3 no review record at {REVIEW_DIR}/{slug}.md -- "
            "reviews land before the merge, not after"
        ]

    text = record.read_text(encoding="utf-8")
    for heading in ("## What was reviewed", "## Findings", "## What was done about them"):
        section = re.search(
            rf"^{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)", text, re.M | re.S
        )
        if section is None:
            return [f"R4 {record.name} has no {heading!r} section"]
        if len(section.group(1).split()) < 10:
            return [f"R5 {record.name}: {heading!r} says almost nothing"]

    return check_branch_has_work(repo, branch, slug)


def check_branch_has_work(repo: pathlib.Path, branch: str, slug: str) -> list[str]:
    """The branch has something to merge, and the record is part of it.

    Both of these were found by falling into them, in one go. A commit was
    refused by the message hook -- wrong type in the subject -- so nothing was
    committed; the review record was sitting in the working tree where
    `record.exists()` found it; `make check` passed, because it also reads the
    working tree; and `make wave-merge` merged a branch identical to main and
    printed "merged". Every gate was green and nothing had happened.

    So: the branch must be ahead of main, and the record must be in the
    branch's own tree rather than merely on the disk beside it.
    """
    try:
        ahead = git(repo, "rev-list", "--count", f"main..{branch}")
    except subprocess.CalledProcessError:
        return [f"R6 cannot compare {branch} with main -- is it a branch that exists?"]
    if ahead == "0":
        return [
            f"R7 {branch} has no commit that main has not got -- there is nothing "
            "to merge, and a refused commit looks exactly like this"
        ]

    committed = subprocess.run(
        ["git", "-C", str(repo), "cat-file", "-e", f"{branch}:{REVIEW_DIR}/{slug}.md"],
        capture_output=True, check=False,
    )
    if committed.returncode != 0:
        return [
            f"R8 {REVIEW_DIR}/{slug}.md exists on disk but is not committed on "
            f"{branch} -- the record merges with the work or it is not a record"
        ]
    return []


def run(repo: pathlib.Path, mode: str, branch: str | None) -> int:
    if mode == "base":
        problems = check_base(repo)
    else:
        current = branch or git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        problems = check_review(repo, current)

    for problem in problems:
        print(problem)
    return 1 if problems else 0


# --- self-test -------------------------------------------------------------


REVIEW_TEMPLATE = """\
# Review: a slug

## What was reviewed

The diff between main and this branch, read in a context that did not write it.

## Findings

One real defect in the gate's regex, reproduced with a constructed case.

## What was done about them

Fixed on this branch, and the fix was reviewed again before the merge.
"""


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(repo: pathlib.Path, mode: str, branch: str | None = None) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(repo, mode, branch)

    def make_repo(root: pathlib.Path, name: str) -> pathlib.Path:
        repo = root / name
        repo.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)],
                       check=True, capture_output=True)
        env = _isolated_env()
        (repo / "README.md").write_text("x\n")
        subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True,
                       capture_output=True, env=env)
        subprocess.run(["git", "-C", str(repo), "commit", "-qm", "chore: start"],
                       check=True, capture_output=True, env=env)
        return repo

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        clean = make_repo(root, "clean")
        expect("clean tree, no remote", quiet(clean, "base"), 0)

        # Planted: cutting a branch while still on the previous wave's branch.
        on_branch = make_repo(root, "onbranch")
        subprocess.run(["git", "-C", str(on_branch), "switch", "-qc", "wave/04-old"],
                       check=True, capture_output=True, env=_isolated_env())
        expect("not on main", quiet(on_branch, "base"), 1)

        # Planted: a remote that cannot be reached. Ignoring the failed fetch
        # left origin/main stale and the comparison vacuously green.
        unreachable = make_repo(root, "unreachable")
        subprocess.run(["git", "-C", str(unreachable), "remote", "add", "origin",
                        "file:///nonexistent/repo.git"],
                       check=True, capture_output=True, env=_isolated_env())
        expect("unreachable remote", quiet(unreachable, "base"), 1)

        # Planted: an uncommitted change.
        dirty = make_repo(root, "dirty")
        (dirty / "scratch.txt").write_text("unstaged\n")
        expect("dirty tree", quiet(dirty, "base"), 1)

        # Planted: merging from main itself.
        expect("on main", quiet(clean, "review", "main"), 1)

        # Planted: a branch name nobody can parse.
        expect("bad branch name", quiet(clean, "review", "my-stuff"), 1)

        # Planted: a well-named branch with no review record.
        expect("no review record", quiet(clean, "review", "wave/05-gates"), 1)

        def with_record(name: str, text: str, commit: bool = True) -> pathlib.Path:
            """A repo on a real branch with a real commit, like the live case."""
            repo = make_repo(root, name)
            env = _isolated_env()
            subprocess.run(["git", "-C", str(repo), "switch", "-qc", "wave/05-gates"],
                           check=True, capture_output=True)
            (repo / REVIEW_DIR).mkdir(parents=True)
            (repo / REVIEW_DIR / "05-gates.md").write_text(text)
            (repo / "work.txt").write_text("the wave's actual work\n")
            if commit:
                subprocess.run(["git", "-C", str(repo), "add", "-A"],
                               check=True, capture_output=True, env=env)
                subprocess.run(["git", "-C", str(repo), "commit", "-qm", "feat: a wave"],
                               check=True, capture_output=True, env=env)
            return repo

        expect("review record present",
               quiet(with_record("reviewed", REVIEW_TEMPLATE), "review", "wave/05-gates"), 0)

        # Planted: a record with the headings but nothing under them. An empty
        # form is the way a process turns into a formality.
        hollow = with_record("hollow",
            "# Review\n\n## What was reviewed\n\n## Findings\n\nnone\n\n"
            "## What was done about them\n\nnothing\n")
        expect("hollow review record", quiet(hollow, "review", "wave/05-gates"), 1)

        # Planted: the commit was refused, so the branch is empty and the record
        # is only on disk. Every other check passes and there is nothing to
        # merge -- this is the live case that produced these two rules.
        refused = with_record("refused", REVIEW_TEMPLATE, commit=False)
        expect("a branch with no commits", quiet(refused, "review", "wave/05-gates"), 1)

        # Planted: a branch name that is not a branch. The record is on disk,
        # so every rule above it passes and this is the only one left to catch
        # it -- which is why it needs a case where nothing else can fire.
        ghost = make_repo(root, "ghost")
        (ghost / REVIEW_DIR).mkdir(parents=True)
        (ghost / REVIEW_DIR / "05-gates.md").write_text(REVIEW_TEMPLATE)
        expect("a branch that does not exist",
               quiet(ghost, "review", "wave/05-gates"), 1)

        # Planted: an empty branch whose record is already committed -- on main,
        # from an earlier wave. R8 cannot fire here because the record *is* in
        # the branch's tree, so this is the only case where R7 is the reason.
        # Without it, deleting R7 left the self-test green: the case above was
        # failing for R8's reason and R7 was decorative.
        inherited = make_repo(root, "inherited")
        env = _isolated_env()
        (inherited / REVIEW_DIR).mkdir(parents=True)
        (inherited / REVIEW_DIR / "05-gates.md").write_text(REVIEW_TEMPLATE)
        subprocess.run(["git", "-C", str(inherited), "add", "-A"],
                       check=True, capture_output=True, env=env)
        subprocess.run(["git", "-C", str(inherited), "commit", "-qm", "docs: a record"],
                       check=True, capture_output=True, env=env)
        subprocess.run(["git", "-C", str(inherited), "switch", "-qc", "wave/05-gates"],
                       check=True, capture_output=True)
        expect("an empty branch with an inherited record",
               quiet(inherited, "review", "wave/05-gates"), 1)

        # Planted: work committed, record left behind in the working tree.
        uncommitted = make_repo(root, "uncommitted")
        env = _isolated_env()
        subprocess.run(["git", "-C", str(uncommitted), "switch", "-qc", "wave/05-gates"],
                       check=True, capture_output=True)
        (uncommitted / "work.txt").write_text("committed work\n")
        subprocess.run(["git", "-C", str(uncommitted), "add", "work.txt"],
                       check=True, capture_output=True, env=env)
        subprocess.run(["git", "-C", str(uncommitted), "commit", "-qm", "feat: a wave"],
                       check=True, capture_output=True, env=env)
        (uncommitted / REVIEW_DIR).mkdir(parents=True)
        (uncommitted / REVIEW_DIR / "05-gates.md").write_text(REVIEW_TEMPLATE)
        expect("record on disk but not committed",
               quiet(uncommitted, "review", "wave/05-gates"), 1)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def _isolated_env() -> dict[str, str]:
    """Git environment for the self-test, independent of the user's config."""
    import os

    env = dict(os.environ)
    env.update({
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_SYSTEM": "/dev/null",
        "GIT_AUTHOR_NAME": "Self Test",
        "GIT_AUTHOR_EMAIL": "selftest@example.invalid",
        "GIT_COMMITTER_NAME": "Self Test",
        "GIT_COMMITTER_EMAIL": "selftest@example.invalid",
    })
    return env


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--check-base", action="store_true")
    parser.add_argument("--check-review", action="store_true")
    parser.add_argument("--branch", default=None)
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
    if args.check_base == args.check_review:
        print("check_branch_base: pass exactly one of --check-base or --check-review",
              file=sys.stderr)
        return 2

    repo = pathlib.Path(__file__).resolve().parent.parent
    try:
        return run(repo, "base" if args.check_base else "review", args.branch)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"check_branch_base: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
