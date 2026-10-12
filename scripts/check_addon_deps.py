#!/usr/bin/env python3
"""Keep each addon independently installable.

The rule
--------
Invariant 2: no addon depends on another addon. The only thing any of them may
reach for is `ai_core`, which holds types and interfaces and no logic. Someone
who wants only A* copies two folders and is done.

The dependency that has no path in it
-------------------------------------
Catching `preload("res://addons/other/x.gd")` is the easy half. The half that
matters is `class_name`: a class declared in one addon is registered across the
whole project, so a file in `ai_planning` can write `AStarSearch.find_path(...)`
with no import, no path, and nothing to grep for except the name itself. It
works perfectly in this repository and breaks the moment someone installs one
addon without the other -- which is the thing this invariant promises.

So the check is: collect every `class_name` each addon declares, then report an
addon that mentions a class another addon owns.

What it deliberately does not do
--------------------------------
It does not parse GDScript. A class name inside a comment or a string counts as
a mention, because the cost of being wrong in that direction is a sentence
rewritten, and the cost of the other direction is an addon that does not work
when installed alone.

Exit codes
----------
0   every addon stands alone
1   a cross-addon dependency (each one printed)
2   wrong usage, or a path that cannot be read

Usage
-----
    check_addon_deps.py [--addons PATH]
    check_addon_deps.py --self-test
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

# The one addon everything may depend on: types and interfaces, no logic.
SHARED = "ai_core"

# Third-party addons this project does not author and does not ship.
VENDORED = {"gdUnit4"}

CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RES_PATH_RE = re.compile(r'res://addons/([A-Za-z0-9_]+)/')


def addon_dirs(addons: pathlib.Path) -> list[pathlib.Path]:
    """Every addon this project authors."""
    if not addons.is_dir():
        return []
    return [
        path for path in sorted(addons.iterdir())
        if path.is_dir() and path.name not in VENDORED
    ]


def declared_classes(addon: pathlib.Path) -> set[str]:
    """Every `class_name` this addon registers project-wide."""
    names = set()
    for path in sorted(addon.rglob("*.gd")):
        names.update(CLASS_NAME_RE.findall(path.read_text(encoding="utf-8")))
    return names


def check(addons: pathlib.Path) -> list[str]:
    """Report any addon that reaches into another."""
    folders = addon_dirs(addons)
    if not folders:
        # The addons arrive in T2. An absence now is the project's real state,
        # not a defect -- but it is printed on every run rather than passing in
        # silence, so nobody reads this gate's green as evidence of anything.
        print(f"A0 note: no addons under {addons} yet -- this gate inspected nothing")
        return []

    owner_of: dict[str, str] = {}
    for addon in folders:
        for name in declared_classes(addon):
            owner_of[name] = addon.name

    findings = []
    for addon in folders:
        for path in sorted(addon.rglob("*.gd")):
            text = path.read_text(encoding="utf-8")
            relative = path.relative_to(addons.parent.parent)

            # The easy half: a resource path naming another addon.
            for referenced in sorted(set(RES_PATH_RE.findall(text))):
                if referenced not in (addon.name, SHARED) and referenced not in VENDORED:
                    findings.append(
                        f"A1 {relative} loads from addons/{referenced}/; "
                        f"only {SHARED} may be shared"
                    )

            # The half with no path in it: a class another addon registers.
            own = declared_classes(addon)
            for name, owner in sorted(owner_of.items()):
                if owner in (addon.name, SHARED) or name in own:
                    continue
                if re.search(rf"\b{re.escape(name)}\b", text):
                    findings.append(
                        f"A2 {relative} mentions {name}, which {owner} declares; "
                        f"installing {addon.name} alone would break"
                    )
    return findings


def run(addons: pathlib.Path) -> int:
    findings = check(addons)
    for finding in findings:
        print(finding)
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


def self_test() -> int:
    failures = []

    def expect(label: str, got: int, want: int) -> None:
        if got != want:
            failures.append(f"{label}: expected exit {want}, got {got}")

    def quiet(addons: pathlib.Path) -> int:
        with contextlib.redirect_stdout(io.StringIO()):
            return run(addons)

    def build(root: pathlib.Path, name: str, files: dict[str, str]) -> pathlib.Path:
        addons = root / name / "godot" / "addons"
        for relative, text in files.items():
            path = addons / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        return addons

    core = "class_name GridGraph\nextends RefCounted\n"
    search = "class_name AStarSearch\nextends RefCounted\n\n\nfunc find_path() -> Array:\n\treturn []\n"

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)

        # Two addons, each using only ai_core. This is the shape the project
        # promises, and it must pass.
        expect("independent addons", quiet(build(root, "good", {
            "ai_core/grid_graph.gd": core,
            "ai_search/astar.gd": search + "\n\nvar graph: GridGraph\n",
            "ai_planning/strips.gd": "class_name StripsPlanner\nextends RefCounted\n\nvar graph: GridGraph\n",
        })), 0)

        # No addons yet is the project's real state before T2: a printed note,
        # not a finding. What proves the gate can still fail is every case
        # below it.
        empty = root / "empty" / "godot" / "addons"
        empty.mkdir(parents=True)
        expect("no addons yet", quiet(empty), 0)

        # Planted: a resource path into another addon.
        expect("preload across addons", quiet(build(root, "preload", {
            "ai_core/grid_graph.gd": core,
            "ai_search/astar.gd": search,
            "ai_planning/strips.gd":
                'class_name StripsPlanner\nextends RefCounted\n\n'
                'const Search := preload("res://addons/ai_search/astar.gd")\n',
        })), 1)

        # Planted: the dependency with no path in it. This is the one that
        # works in the repository and breaks on install.
        expect("class_name across addons", quiet(build(root, "classname", {
            "ai_core/grid_graph.gd": core,
            "ai_search/astar.gd": search,
            "ai_planning/strips.gd":
                "class_name StripsPlanner\nextends RefCounted\n\n\n"
                "func plan() -> Array:\n\treturn AStarSearch.new().find_path()\n",
        })), 1)

        # Depending on ai_core is the whole point and must not be a finding.
        expect("depends on ai_core only", quiet(build(root, "oncore", {
            "ai_core/grid_graph.gd": core,
            "ai_search/astar.gd": search + "\n\nvar graph: GridGraph\n",
        })), 0)

        # Loading from your own addon is ordinary.
        expect("loads from itself", quiet(build(root, "self", {
            "ai_core/grid_graph.gd": core,
            "ai_search/astar.gd":
                search + '\nconst Helper := preload("res://addons/ai_search/helper.gd")\n',
            "ai_search/helper.gd": "class_name AStarHelper\nextends RefCounted\n",
        })), 0)

        # The vendored test framework is not ours and is not shipped.
        expect("references gdUnit4", quiet(build(root, "vendored", {
            "ai_core/grid_graph.gd": core,
            "ai_search/astar.gd":
                search + '\nconst Suite := preload("res://addons/gdUnit4/src/GdUnitTestSuite.gd")\n',
        })), 0)

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
    parser.add_argument("--addons", default=None)
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
    addons = pathlib.Path(args.addons) if args.addons else repo / "godot" / "addons"

    try:
        return run(addons)
    except OSError as error:
        print(f"check_addon_deps: cannot read a file: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
