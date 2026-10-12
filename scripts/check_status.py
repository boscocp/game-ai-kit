#!/usr/bin/env python3
"""Fail when tasks/STATUS.md and the task files disagree.

The rule
--------
`STATUS.md` is the index someone reads to decide what to do next. When it drifts
from the files, the reader either works on something that does not exist or
skips something that does. Four things must hold:

  * every task file has a row in the index;
  * every row with an id has a file;
  * every `Prereqs:` names a task that exists;
  * the prerequisite graph has no cycle.

An ADR may gate a task just as a task can (`Prereqs: T4, ADR 0007`). The ADR is
deliberately **not** required to exist: a prerequisite you have not met yet is
the normal case, not a broken reference. Only its shape is checked, so
`ADR seven` is still caught.

Exit codes
----------
0   index and files agree
1   disagreement (each one printed)
2   wrong usage, or no task files where they were expected

Usage
-----
    check_status.py [--tasks PATH]
    check_status.py --self-test
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

TASK_FILE_RE = re.compile(r"^(T\d+(?:\.\d+)?)-")
ROW_RE = re.compile(r"^\|\s*(T\d+(?:\.\d+)?)\s*\|\s*([^|]*?)\s*\|\s*\*{0,2}([a-z]+)\*{0,2}\s*\|", re.M)
# `Prereqs: T2, ADR 0004`, wherever it sits on the header line. Anchoring it to
# a line starting with `Size:` meant reordering the header, or dropping it,
# switched the prerequisite and cycle checks off without a word -- a dangling
# prereq then passed. Either separator is accepted, because a middle dot is
# easy to lose in an editor and the rule should survive that.
PREREQ_RE = re.compile(r"^.*?\bPrereqs:\s*([^·\n]+?)(?:\s+[·-]\s+\S|\s*$)", re.M)
ADR_RE = re.compile(r"^ADR\s+\d{4}$", re.I)

ALLOWED_STATES = {"todo", "wip", "blocked", "done"}
NO_PREREQS = {"none", "-", "—"}


def task_id(path: pathlib.Path) -> str:
    found = TASK_FILE_RE.match(path.name)
    return found.group(1) if found else ""


def index_rows(status_text: str) -> tuple[dict[str, str], list[str]]:
    """Every `| T3 | Title | state |` row, plus any id listed more than once.

    A dict comprehension kept the last duplicate, so a row with a nonsense state
    followed by a valid one for the same id passed. Two rows for one task is
    itself a problem: the reader cannot tell which is current.
    """
    rows: dict[str, str] = {}
    duplicates = []
    for identifier, _title, state in ROW_RE.findall(status_text):
        if identifier in rows:
            duplicates.append(identifier)
        rows[identifier] = state
    return rows, duplicates


def prerequisites(text: str) -> list[str]:
    """The ids and ADRs a task declares it waits on."""
    found = PREREQ_RE.search(text)
    if found is None:
        return []
    raw = found.group(1).strip()
    if raw.lower() in NO_PREREQS:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


def find_cycle(graph: dict[str, list[str]]) -> list[str] | None:
    """The first cycle found in the prerequisite graph, as a path."""
    visiting: set[str] = set()
    done: set[str] = set()
    cycle: list[str] = []

    def walk(node: str, path: list[str]) -> bool:
        if node in visiting:
            cycle.extend(path[path.index(node):] + [node])
            return True
        if node in done:
            return False
        visiting.add(node)
        for neighbour in graph.get(node, []):
            if walk(neighbour, path + [node]):
                return True
        visiting.discard(node)
        done.add(node)
        return False

    for node in sorted(graph):
        if walk(node, []):
            return cycle
    return None


def run(tasks: pathlib.Path) -> int:
    status_file = tasks / "STATUS.md"
    if not status_file.exists():
        print(f"S0 no index at {status_file}")
        return 1

    files = {task_id(p): p for p in sorted(tasks.glob("*.md")) if TASK_FILE_RE.match(p.name)}
    if not files:
        print(f"S1 no task files in {tasks} -- this gate would pass on an empty tree")
        return 1

    rows, duplicates = index_rows(status_file.read_text(encoding="utf-8"))
    findings = [f"S8 STATUS.md lists {identifier} more than once" for identifier in duplicates]

    for identifier in sorted(files):
        if identifier not in rows:
            findings.append(f"S2 {files[identifier].name} has no row in STATUS.md")
    for identifier, state in sorted(rows.items()):
        if identifier not in files:
            findings.append(f"S3 STATUS.md has a row for {identifier} but no task file")
        if state not in ALLOWED_STATES:
            findings.append(
                f"S4 {identifier} has state {state!r}; allowed: {', '.join(sorted(ALLOWED_STATES))}"
            )

    graph: dict[str, list[str]] = {}
    for identifier, path in sorted(files.items()):
        needed = []
        for item in prerequisites(path.read_text(encoding="utf-8")):
            if ADR_RE.match(item):
                continue  # a decision not yet taken is the normal case
            if not TASK_FILE_RE.match(item + "-"):
                findings.append(f"S5 {path.name}: prereq {item!r} is neither a task id nor `ADR NNNN`")
                continue
            if item not in files:
                findings.append(f"S6 {path.name}: prereq {item} has no task file")
                continue
            needed.append(item)
        graph[identifier] = needed

    cycle = find_cycle(graph)
    if cycle:
        findings.append(f"S7 the prerequisite graph has a cycle: {' -> '.join(cycle)}")

    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


def task_text(identifier: str, prereqs: str = "none") -> str:
    return (
        f"# {identifier} - A task\n\n"
        f"Size: M · Prereqs: {prereqs} · Files: `godot/`\n\n"
        "## Goal\n\nSomething.\n\n## Acceptance\n\n```bash\nmake check\n```\n"
    )


def status_text(*rows: tuple[str, str]) -> str:
    lines = ["# Status", "", "| # | Task | State | Notes |", "|---|---|---|---|"]
    lines += [f"| {identifier} | A task | {state} | |" for identifier, state in rows]
    return "\n".join(lines) + "\n"


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(tasks: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(tasks)

    def build(root: pathlib.Path, name: str, status: str,
              files: dict[str, str]) -> pathlib.Path:
        folder = root / name
        folder.mkdir(parents=True)
        (folder / "STATUS.md").write_text(status)
        for identifier, text in files.items():
            (folder / f"{identifier}-task.md").write_text(text)
        return folder

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        expect("index agrees with files", quiet(build(
            root, "good", status_text(("T2", "done"), ("T3", "todo")),
            {"T2": task_text("T2"), "T3": task_text("T3", "T2")},
        )), 0)

        # Planted: no task files at all.
        bare = root / "bare"
        bare.mkdir()
        (bare / "STATUS.md").write_text(status_text())
        expect("no task files", quiet(bare), 1)

        # Planted: no index.
        noindex = root / "noindex"
        noindex.mkdir()
        (noindex / "T2-task.md").write_text(task_text("T2"))
        expect("no STATUS.md", quiet(noindex), 1)

        # Planted: a file with no row.
        expect("file missing from the index", quiet(build(
            root, "unlisted", status_text(("T2", "done")),
            {"T2": task_text("T2"), "T3": task_text("T3")},
        )), 1)

        # Planted: a row with no file.
        expect("row without a file", quiet(build(
            root, "ghost", status_text(("T2", "done"), ("T9", "todo")),
            {"T2": task_text("T2")},
        )), 1)

        # Planted: a state nobody defined.
        expect("unknown state", quiet(build(
            root, "weird", status_text(("T2", "nearly")),
            {"T2": task_text("T2")},
        )), 1)

        # Planted: a prereq pointing at a task that does not exist.
        expect("dangling prereq", quiet(build(
            root, "dangling", status_text(("T2", "todo")),
            {"T2": task_text("T2", "T7")},
        )), 1)

        # Planted: a prereq that is not an id and not an ADR.
        expect("malformed prereq", quiet(build(
            root, "malformed", status_text(("T2", "todo")),
            {"T2": task_text("T2", "ADR seven")},
        )), 1)

        # A well-formed ADR prereq passes even though no ADR file is checked.
        expect("ADR prereq", quiet(build(
            root, "adr", status_text(("T2", "todo")),
            {"T2": task_text("T2", "ADR 0004")},
        )), 0)

        # Planted: the header reordered so it no longer starts with Size:. The
        # prerequisite half used to switch itself off entirely.
        reordered = task_text("T2", "T7").replace(
            "Size: M · Prereqs: T7 · Files: `godot/`",
            "Prereqs: T7 · Size: M · Files: `godot/`")
        expect("reordered header, dangling prereq", quiet(build(
            root, "reordered", status_text(("T2", "todo")), {"T2": reordered},
        )), 1)

        # Planted: two rows for the same id, the bad state first. The dict used
        # to keep the last one and report nothing.
        twice = status_text(("T2", "nonsense")) + "| T2 | A task | todo | |\n"
        expect("duplicate row", quiet(build(
            root, "twice", twice, {"T2": task_text("T2")},
        )), 1)

        # Planted: a cycle.
        expect("cycle in the graph", quiet(build(
            root, "cycle", status_text(("T2", "todo"), ("T3", "todo")),
            {"T2": task_text("T2", "T3"), "T3": task_text("T3", "T2")},
        )), 1)

        script = pathlib.Path(__file__).resolve()
        extra = subprocess.run(
            [sys.executable, str(script), "--unknown-flag"], capture_output=True
        )
        expect("unknown flag", extra.returncode, 2)

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__)
    parser.add_argument("--tasks", default=None)
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

    tasks = pathlib.Path(args.tasks or pathlib.Path(__file__).resolve().parent.parent / "tasks")
    if not tasks.is_dir():
        print(f"check_status: no such directory: {tasks}", file=sys.stderr)
        return 2

    try:
        return run(tasks)
    except OSError as error:
        print(f"check_status: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
