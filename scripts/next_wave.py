#!/usr/bin/env python3
"""Work out which wave comes next, cut its branch, and print its prompt.

The rule
--------
A wave is one task from `tasks/STATUS.md`, on its own branch, reviewed before
it merges. Deciding *which* task is mechanical -- the first `todo` whose
prerequisites are all `done` -- and so is naming the branch. Doing it by hand
means reading a table, picking a number nobody checked, and inventing a slug.

Why this exists
---------------
Three waves in this repository were started by hand and two of them needed the
branch name corrected afterwards. The wave number is the part that goes wrong:
it is one more than the highest review record, not one more than the last task,
and those have not been the same number since wave 6.

What it does NOT do
-------------------
It does not do the work. There is no command that writes a wave; this one puts
you at the start of it with the branch cut, the task file named and the
resuming section printed, which is exactly what a fresh session needs to read.

Exit codes
----------
0   a branch was cut (or --dry-run printed what would happen)
1   nothing to do, or the base is not safe to branch from
2   wrong usage, or STATUS.md cannot be read

Usage
-----
    next_wave.py [--dry-run]
    next_wave.py --self-test
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys

STATUS = "tasks/STATUS.md"
REVIEWS = "docs/reviews"
TASKS = "tasks"

ROW_RE = re.compile(r"^\|\s*(T\d+)\s*\|\s*(.+?)\s*\|\s*(\w+)\s*\|")
PREREQS_RE = re.compile(r"Prereqs:\s*([^·|\n]+)")
RECORD_RE = re.compile(r"^(\d+)-")
RESUMING_RE = re.compile(r"^## Resuming after.*?(?=^---\s*$)", re.M | re.S)

# Markdown and backticks in a title are decoration; a branch name is not.
DECORATION_RE = re.compile(r"[`*\\]")


def rows(status: pathlib.Path) -> list[tuple[str, str, str]]:
    """Every task row in the index: id, title, state."""
    found = []
    for line in status.read_text(encoding="utf-8").splitlines():
        match = ROW_RE.match(line)
        if match and match.group(1) != "#":
            found.append((match.group(1), match.group(2), match.group(3).lower()))
    return found


def prerequisites(repo: pathlib.Path, task_id: str) -> list[str]:
    """The tasks this one declares it needs, read from its own file."""
    path = task_file(repo, task_id)
    if path is None:
        return []
    found = PREREQS_RE.search(path.read_text(encoding="utf-8"))
    if found is None:
        return []
    return re.findall(r"T\d+", found.group(1))


def task_file(repo: pathlib.Path, task_id: str) -> pathlib.Path | None:
    """The file for a task id, found by its prefix rather than by a table."""
    matches = sorted((repo / TASKS).glob(f"{task_id}-*.md"))
    return matches[0] if matches else None


def next_task(repo: pathlib.Path) -> tuple[str, str] | None:
    """The first task that is `todo` and whose prerequisites are all `done`.

    A task blocked by an unfinished prerequisite is skipped rather than
    reported, because the table is written in the order it is meant to be done
    and the first unblocked row is the answer.
    """
    states = {task_id: state for task_id, _title, state in rows(repo / STATUS)}
    for task_id, title, state in rows(repo / STATUS):
        if state != "todo":
            continue
        if all(states.get(need) == "done" for need in prerequisites(repo, task_id)):
            return task_id, title
    return None


def next_number(repo: pathlib.Path) -> int:
    """One more than the highest review record.

    Not one more than the last task: a wave can fix another wave, and two of
    them have. The records are the only honest count of how many waves there
    have been.
    """
    highest = 0
    for record in (repo / REVIEWS).glob("*.md"):
        found = RECORD_RE.match(record.name)
        if found:
            highest = max(highest, int(found.group(1)))
    return highest + 1


def slug_of(task_id: str, repo: pathlib.Path, title: str) -> str:
    """A branch slug: the task file's own name when it has one, else the title."""
    path = task_file(repo, task_id)
    if path is not None:
        return path.stem.split("-", 1)[1]
    plain = DECORATION_RE.sub("", title).lower()
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", plain)).strip("-")


def resuming_section(repo: pathlib.Path) -> str:
    """The topmost `## Resuming after` section, which is the session's prompt."""
    found = RESUMING_RE.search((repo / STATUS).read_text(encoding="utf-8"))
    return found.group(0).strip() if found else ""


def run(repo: pathlib.Path, dry_run: bool) -> int:
    chosen = next_task(repo)
    if chosen is None:
        print("next_wave: every task in the index is done or blocked")
        return 1

    task_id, title = chosen
    branch = f"wave/{next_number(repo):02d}-{slug_of(task_id, repo, title)}"
    path = task_file(repo, task_id)

    print(f"next task:   {task_id} -- {title}")
    print(f"task file:   {path.relative_to(repo) if path else '(none; write one first)'}")
    print(f"branch:      {branch}")
    if dry_run:
        return 0

    base = subprocess.run(
        [sys.executable, str(repo / "scripts" / "check_branch_base.py"), "--check-base"],
        cwd=repo, check=False,
    )
    if base.returncode != 0:
        return 1
    cut = subprocess.run(["git", "-C", str(repo), "switch", "-c", branch], check=False)
    if cut.returncode != 0:
        return 1

    print()
    print(resuming_section(repo))
    print()
    print(f"Read {path.relative_to(repo) if path else STATUS} next, then: make check, "
          "write the review record, make wave-merge.")
    return 0


# --- self-test -------------------------------------------------------------


INDEX = """\
| # | Task | State | Notes |
|---|---|---|---|
| T0 | Bootstrap | done | |
| T1 | Gates | done | |
| T2 | `ai_core` and the board | done | |
| T3 | `ai_search`: A\\*, BFS | todo | |
| T4 | `ai_planning` | todo | |
"""


def self_test() -> int:
    import tempfile

    failures = []

    def expect(label: str, got: object, want: object) -> None:
        if got != want:
            failures.append(f"{label}: expected {want!r}, got {got!r}")

    with tempfile.TemporaryDirectory() as workspace:
        repo = pathlib.Path(workspace)
        (repo / TASKS).mkdir()
        (repo / REVIEWS).mkdir(parents=True)
        (repo / STATUS).parent.mkdir(exist_ok=True)
        (repo / STATUS).write_text(INDEX + "\n## Resuming after X\n\nA prompt.\n\n---\n")
        (repo / TASKS / "T3-ai-search.md").write_text("Size: M · Prereqs: T2 · Files: x\n")
        (repo / TASKS / "T4-ai-planning.md").write_text("Size: M · Prereqs: T3 · Files: x\n")

        expect("first unblocked task", next_task(repo), ("T3", "`ai_search`: A\\*, BFS"))

        # Planted: T3 blocked by an unfinished prerequisite. The answer is not
        # "T3 anyway", and it is not "nothing" -- it is the next row that is
        # free, which is what makes this worth checking by hand once.
        (repo / TASKS / "T3-ai-search.md").write_text("Size: M · Prereqs: T9 · Files: x\n")
        expect("blocked task is skipped", next_task(repo), None)
        (repo / TASKS / "T3-ai-search.md").write_text("Size: M · Prereqs: T2 · Files: x\n")

        # Planted: the wave number comes from the records, not the tasks. With
        # ten records and five tasks, a wave numbered 4 would be wrong.
        for number in range(5, 11):
            (repo / REVIEWS / f"{number:02d}-a-record.md").write_text("x\n")
        expect("number follows the records", next_number(repo), 11)

        # The slug is the task file's own name, so a title full of markdown
        # does not become a branch full of punctuation.
        expect("slug from the task file", slug_of("T3", repo, "`ai_search`: A\\*, BFS"),
               "ai-search")
        expect("slug from a title", slug_of("T9", repo, "`ai_llm`: orders, *badly*"),
               "ai-llm-orders-badly")

        expect("the prompt is found", resuming_section(repo).splitlines()[0],
               "## Resuming after X")

        empty = pathlib.Path(workspace) / "empty"
        (empty / TASKS).mkdir(parents=True)
        (empty / REVIEWS).mkdir(parents=True)
        (empty / STATUS).write_text("| # | Task | State | Notes |\n")
        expect("an index with no tasks", next_task(empty), None)
        # Planted: no records yet. The first wave is 1, not 0.
        expect("first wave number", next_number(empty), 1)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        if exit_request.code == 0:
            raise
        return 2

    if args.self_test:
        return self_test()

    repo = pathlib.Path(__file__).resolve().parent.parent
    try:
        return run(repo, args.dry_run)
    except OSError as error:
        print(f"next_wave: cannot read the index: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
