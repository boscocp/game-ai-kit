#!/usr/bin/env python3
"""Keep the literature page from claiming what the kit does not have.

What it holds
-------------
T73. `docs/concepts/the-literature-and-the-kit.md` sets the field's
techniques against this kit in one table: for each, where the literature
puts it, and what the kit has of it. A row that says the kit has a technique
names where -- a module from `modules/*.json`, a path in the repository, or
the make target of the demo that shows it. The day a module is renamed or a
demo removed, the page would go on claiming it; this gate refuses that.

The rules, one finding each
---------------------------
  L1  no row could be read. A table the reader cannot find is not a table
      that holds -- "found nothing" is never a pass.
  L2  a row whose "In the kit" cell neither names something in backticks nor
      says `not in the kit`: a claim with nothing to check it against.
  L3  a backticked name that looks like a module (`ai_search`) and is not one.
  L4  a backticked path (anything with a `/`) that does not exist.
  L5  a demo cell naming a make target (`demo-x`, `run`, `make x`) that the
      Makefile does not define.

Exit codes
----------
0   every row's claim is held
1   a finding
2   wrong usage, or the page, the Makefile or a manifest cannot be read

Usage
-----
    check_literature_table.py [--root PATH]
    check_literature_table.py --self-test
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import pathlib
import re
import subprocess
import sys
import tempfile

PAGE = pathlib.Path("docs/concepts/the-literature-and-the-kit.md")
NOT_IN_KIT = "not in the kit"

# The table's header names the columns; these two are the ones read.
KIT_COLUMN = "In the kit"
DEMO_COLUMN = "Demos"

TICKED_RE = re.compile(r"`([^`]+)`")
MODULE_RE = re.compile(r"^[a-z][a-z0-9_]*$")
TARGET_RE = re.compile(r"^(?:make\s+)?([a-z][a-z0-9-]*)$")
RULE_RE = re.compile(r"^([A-Za-z0-9_.-]+):", re.M)


def table_rows(text: str) -> list[dict[str, str]]:
    """Every body row of every table whose header has an "In the kit" column."""
    rows: list[dict[str, str]] = []
    header: list[str] | None = None
    for line in text.splitlines():
        if not line.startswith("|"):
            header = None
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if header is None:
            header = cells if KIT_COLUMN in cells else []
        elif header and not set("".join(cells)) <= set("-: "):
            rows.append(dict(zip(header, cells)))
    return rows


def kit_findings(row: dict[str, str], root: pathlib.Path, modules: set[str]) -> list[str]:
    """What is wrong with one row's "In the kit" cell, if anything."""
    technique = row.get("Technique", "?")
    cell = row.get(KIT_COLUMN, "")
    names = TICKED_RE.findall(cell)
    if not names and NOT_IN_KIT not in cell:
        return [f"L2 {technique}: the kit cell names nothing and does not say `{NOT_IN_KIT}`"]
    findings = []
    for name in names:
        if "/" in name and not (root / name).exists():
            findings.append(f"L4 {technique}: path `{name}` does not exist")
        elif "/" not in name and MODULE_RE.match(name) and name not in modules:
            findings.append(f"L3 {technique}: `{name}` is not a module in modules/")
    return findings


def demo_findings(row: dict[str, str], targets: set[str]) -> list[str]:
    """Every make target the demo cell names that the Makefile does not define."""
    technique = row.get("Technique", "?")
    findings = []
    for name in TICKED_RE.findall(row.get(DEMO_COLUMN, "")):
        target = TARGET_RE.match(name)
        if target and target.group(1) not in targets:
            findings.append(f"L5 {technique}: `{name}` is not a make target")
    return findings


def check(root: pathlib.Path) -> list[str]:
    """Every finding for the page under `root`; raises OSError if unreadable."""
    rows = table_rows((root / PAGE).read_text(encoding="utf-8"))
    if not rows:
        return [f"L1 {PAGE}: no table with an `{KIT_COLUMN}` column was found"]
    modules = {json.loads(path.read_text(encoding="utf-8"))["module"]
               for path in (root / "modules").glob("*.json")}
    targets = set(RULE_RE.findall((root / "Makefile").read_text(encoding="utf-8")))
    findings = []
    for row in rows:
        findings.extend(kit_findings(row, root, modules))
        findings.extend(demo_findings(row, targets))
    return findings


def run(root: pathlib.Path) -> int:
    """Print the findings for `root` and return the exit code."""
    try:
        findings = check(root)
    except (OSError, ValueError, KeyError) as error:
        print(f"cannot read the page, the Makefile or a manifest: {error}")
        return 2
    for finding in findings:
        print(finding)
    if not findings:
        print(f"check_literature_table: ok -- {len(table_rows((root / PAGE).read_text(encoding='utf-8')))} rows")
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------

HEADER = "| Technique | Literature | In the kit | Demos |\n|---|---|---|---|\n"


def build(root: pathlib.Path, rows: str) -> pathlib.Path:
    """A tiny repository: one module, one path, one demo target, and the page."""
    (root / "modules").mkdir(parents=True)
    (root / "modules" / "ai_search.json").write_text('{"module": "ai_search"}')
    (root / "godot" / "addons" / "ai_search").mkdir(parents=True)
    (root / "Makefile").write_text("demo-search: import\n\t@true\n")
    (root / PAGE).parent.mkdir(parents=True)
    (root / PAGE).write_text("# The page\n\n" + rows)
    return root


def self_test() -> int:
    """The honest row passes; each planted row fails for its own rule."""
    cases = {
        "honest": (HEADER + "| A* | AIMA 3.5 | `ai_search`, `godot/addons/ai_search` | `demo-search` |\n"
                   "| MCTS | AIMA 5.4 | not in the kit | -- |\n", 0, ""),
        "no table": ("No table here.\n", 1, "L1"),
        "says nothing": (HEADER + "| A* | AIMA | yes | -- |\n", 1, "L2"),
        "a missing addon": (HEADER + "| A* | AIMA | `ai_missing` | -- |\n", 1, "L3"),
        "a missing path": (HEADER + "| A* | AIMA | `godot/addons/ai_gone` | -- |\n", 1, "L4"),
        "a missing demo": (HEADER + "| A* | AIMA | `ai_search` | `demo-gone` |\n", 1, "L5"),
    }
    failures = []
    for label, (rows, want, rule) in cases.items():
        with tempfile.TemporaryDirectory() as workspace:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                got = run(build(pathlib.Path(workspace), rows))
        if got != want or rule not in out.getvalue():
            failures.append(f"{label}: expected exit {want} with {rule or 'no finding'}, got {got}: {out.getvalue().strip()}")
    with tempfile.TemporaryDirectory() as workspace:
        if run_quiet(pathlib.Path(workspace)) != 2:
            failures.append("an empty directory: expected exit 2")
    extra = subprocess.run([sys.executable, str(pathlib.Path(__file__).resolve()), "--unknown"],
                           capture_output=True)
    if extra.returncode != 2:
        failures.append(f"unknown flag: expected exit 2, got {extra.returncode}")
    for failure in failures:
        print(failure)
    print("self-test: ok" if not failures else f"self-test: {len(failures)} failure(s)")
    return 1 if failures else 0


def run_quiet(root: pathlib.Path) -> int:
    """`run` with its printing swallowed."""
    with contextlib.redirect_stdout(io.StringIO()):
        return run(root)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parent.parent)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    return run(args.root)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
