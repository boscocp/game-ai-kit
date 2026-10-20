#!/usr/bin/env python3
"""Choose what a change has to test: its modules, and every module that uses them.

What it does
------------
T58. A wave used to run all of `make check` twice, nine minutes each, for
modules it never touched. This reads the change from git, finds the module
that owns each path (`modules/<name>.json`, held to the code by
`check_modules.py`), adds every module that depends on one of those -- and
the ones that depend on *them* -- and prints the make targets that test
exactly that. It is what Nx calls `affected` and Bazel `rdeps`, in the
standard library and short enough to read.

The four rules, each a planted case below
-----------------------------------------
It fails towards running more, never less:

  1. A path no module owns selects everything, and says which path did it.
     "I do not know whose this is" is never "nobody needs testing".
  2. A global path selects everything: the scripts, the Makefile, CI, the
     engine pin, the manifests themselves -- what every gate stands on.
  3. Prose selects no module: `docs/`, `tasks/`, the README. The lints that
     read it run on every wave anyway.
  4. An empty change still runs the lints. Invariant 4 asks of every gate
     whether it passes on an empty scene; this one would, and must not.

Exit codes
----------
0   printed (or, with --run, every selected target passed)
1   --run: a selected target failed
2   wrong usage, git could not answer, or a manifest cannot be read

Usage
-----
    affected.py --base REF [--head REF] [--targets | --explain | --run]
    affected.py --paths FILE [--targets | --explain | --run]   (- for stdin)
    affected.py --self-test

Without --head the change is the working tree against the merge base of REF,
uncommitted and untracked files included: what you are about to commit.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_modules  # noqa: E402 -- the manifests and the ownership rules
from check_modules import PROSE, Module, is_under, owner_of  # noqa: E402

GODOT_TESTS = "godot/test/"
PYTHON_TESTS = "python/tests/"
# Run with any selected Godot suite: it is global, and four seconds.
GLOBAL_SUITES = ("test/project_settings_test.gd",)


@dataclasses.dataclass(frozen=True)
class Selection:
    """What a change selects: every module, or these, and why."""

    everything: bool
    modules: frozenset[str]
    reasons: tuple[str, ...]


def changed_paths(repo: pathlib.Path, base: str, head: str | None) -> list[str]:
    """The paths a change touches, from git; with no head, the working tree too."""
    def git(*args: str) -> list[str]:
        done = subprocess.run(["git", "-C", str(repo), *args],
                              capture_output=True, text=True, check=True)
        return [line for line in done.stdout.splitlines() if line]

    if head is not None:
        return git("diff", "--name-only", f"{base}...{head}")
    fork = git("merge-base", base, "HEAD")[0]
    return sorted(set(git("diff", "--name-only", fork))
                  | set(git("ls-files", "--others", "--exclude-standard")))


def dependents(modules: dict[str, Module]) -> dict[str, set[str]]:
    """For each module, the modules that declare it as a dependency."""
    used_by: dict[str, set[str]] = {name: set() for name in modules}
    for name, module in modules.items():
        for other in module.depends_on:
            used_by.setdefault(other, set()).add(name)
    return used_by


def select(paths: list[str], modules: dict[str, Module]) -> Selection:
    """Rules 1-3 for each path, then every dependent, transitively."""
    touched, reasons = set(), []
    for path in paths:
        if is_under(path, PROSE):
            continue
        if check_modules.is_global(path, modules):
            reasons.append(f"{path} is global: every gate stands on it")
            continue
        owner = owner_of(path, modules)
        if owner is None:
            reasons.append(f"{path} is owned by no module")
            continue
        touched.add(owner)
    if reasons:
        return Selection(True, frozenset(modules), tuple(reasons))
    used_by, chosen, waiting = dependents(modules), set(), sorted(touched)
    while waiting:
        name = waiting.pop()
        if name not in chosen:
            chosen.add(name)
            waiting.extend(sorted(used_by.get(name, ())))
    reasons = [f"{name} changed" for name in sorted(touched)]
    reasons += [f"{name} uses a module that changed" for name in sorted(chosen - touched)]
    return Selection(False, frozenset(chosen), tuple(reasons))


def owned_tests(repo: pathlib.Path, module: Module) -> tuple[list[str], list[str]]:
    """A module's gdUnit4 suite folders and its Python test modules."""
    suites, python = [], []
    for prefix in module.owns:
        if prefix.startswith(GODOT_TESTS) and any((repo / prefix).glob("*_test.gd")):
            suites.append(prefix.removeprefix("godot/").rstrip("/"))
        elif prefix.startswith(PYTHON_TESTS) and prefix.endswith(".py"):
            python.append(pathlib.PurePath(prefix).stem)
    return suites, python


def targets(repo: pathlib.Path, selection: Selection,
            modules: dict[str, Module]) -> list[str]:
    """The make targets, in order: lints, refits, Python, the gates, Godot."""
    if selection.everything:
        return ["check"]
    makefile = repo / "Makefile"
    lints = sorted(check_modules.always_run(makefile) - {"lint-no-training"})
    chosen = [modules[name] for name in sorted(selection.modules)]
    retrain = sorted({rule for module in chosen for rule in module.retrain})
    suites, python = [], []
    for module in chosen:
        module_suites, module_python = owned_tests(repo, module)
        suites += module_suites
        python += module_python
    found = lints + [f'lint-no-training-some RETRAIN="{",".join(retrain)}"']
    if python:
        found.append(f'test-python-some PYTESTS="{" ".join(sorted(python))}"')
    found += sorted({gate for module in chosen for gate in module.gates})
    if suites:
        found.append(f'test-godot-some SUITES="{" ".join([*GLOBAL_SUITES, *sorted(suites)])}"')
    return found


def explain(selection: Selection) -> str:
    """Why this selection, one reason a line."""
    head = "everything" if selection.everything else (
        ", ".join(sorted(selection.modules)) or "no module, only the lints")
    return "\n".join([f"selected: {head}", *(f"  {reason}" for reason in selection.reasons)])


def run_targets(repo: pathlib.Path, chosen: list[str]) -> int:
    """One `make` for all of them, so a shared prerequisite (`import`) runs once."""
    words = []
    for target in chosen:
        name, _, variable = target.partition(" ")
        words.append(name)
        if variable:
            key, _, value = variable.partition("=")
            words.append(f"{key}={value.strip(chr(34))}")
    names = [word for word in words if "=" not in word]
    settings = [word for word in words if "=" in word]
    print(f"affected: make {' '.join(names)}", flush=True)
    done = subprocess.run(["make", "--no-print-directory", "-C", str(repo), *names, *settings])
    return 0 if done.returncode == 0 else 1


# --- self-test -------------------------------------------------------------


MANIFESTS = {
    "core": {"module": "core", "kind": "kernel", "owns": ["godot/addons/core/"]},
    "a": {"module": "a", "kind": "technique", "owns": ["godot/addons/a/", "godot/test/a/"],
          "depends_on": ["core"], "gates": ["test-a-properties"]},
    "b": {"module": "b", "kind": "technique", "owns": ["godot/addons/b/"]},
    "play": {"module": "play", "kind": "example", "owns": ["godot/game/play/", "scripts/fetch_play_art.py"],
             "depends_on": ["a"], "gates": ["test-play-match"], "retrain": ["N7"]},
}

MAKEFILE_TEXT = """\
check: check-no-engine test-a-properties test-play-match
check-no-engine: lint-one lint-no-training
lint-one:
\t@true
lint-no-training:
\t@true
test-a-properties:
\t@true
test-play-match:
\t@true
"""


def self_test() -> int:
    failures = []

    def expect(label: str, paths: list[str], everything: bool, chosen: set[str]) -> None:
        got = select(paths, modules)
        if got.everything != everything or (not everything and set(got.modules) != chosen):
            failures.append(f"{label}: expected {'everything' if everything else sorted(chosen)}, "
                            f"got {explain(got)!r}")

    with tempfile.TemporaryDirectory() as workspace:
        repo = pathlib.Path(workspace)
        (repo / "modules").mkdir()
        for name, manifest in MANIFESTS.items():
            (repo / "modules" / f"{name}.json").write_text(json.dumps(manifest))
        (repo / "Makefile").write_text(MAKEFILE_TEXT)
        (repo / "godot/test/a").mkdir(parents=True)
        (repo / "godot/test/a/a_test.gd").write_text("extends GdUnitTestSuite\n")
        modules = check_modules.load_modules(repo)

        expect("a technique and what uses it", ["godot/addons/a/x.gd"], False, {"a", "play"})
        expect("the kernel, transitively", ["godot/addons/core/grid.gd"], False, {"core", "a", "play"})
        expect("a technique nobody uses", ["godot/addons/b/x.gd"], False, {"b"})
        # Planted, rule 1: a path no manifest claims.
        expect("an unowned path", ["godot/addons/a/x.gd", "godot/new/thing.gd"], True, set())
        # Planted, rule 2: what every gate stands on.
        expect("a script", ["scripts/check_x.py"], True, set())
        expect("a manifest", ["modules/a.json"], True, set())
        # A file a manifest names inside a global folder is that module's:
        # the longest claim wins, as it does between modules.
        expect("a module's own script", ["scripts/fetch_play_art.py"], False, {"play"})
        # Rule 3: prose alone selects no module.
        expect("prose", ["docs/reviews/63.md", "tasks/STATUS.md"], False, set())

        # Planted, rule 4: an empty change is not an empty run.
        empty = targets(repo, select([], modules), modules)
        if "lint-one" not in empty:
            failures.append(f"an empty change ran no lint: {empty}")
        chosen = targets(repo, select(["godot/addons/a/x.gd"], modules), modules)
        for want in ("test-a-properties", "test-play-match", 'lint-no-training-some RETRAIN="N7"',
                     'test-godot-some SUITES="test/project_settings_test.gd test/a"'):
            if want not in chosen:
                failures.append(f"a change to a: {want!r} missing from {chosen}")
        if "lint-no-training" in chosen:
            failures.append("the full refit ran for a change that asked for one")

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parent.parent)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--base")
    source.add_argument("--paths", help="read the changed paths from a file, - for stdin")
    parser.add_argument("--head")
    show = parser.add_mutually_exclusive_group()
    show.add_argument("--targets", action="store_true")
    show.add_argument("--explain", action="store_true")
    show.add_argument("--run", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        return 2 if exit_request.code else 0
    if args.self_test:
        return self_test()
    if not (args.base or args.paths):
        print("affected: say what changed, with --base REF or --paths FILE", file=sys.stderr)
        return 2
    try:
        modules = check_modules.load_modules(args.repo)
        if args.paths:
            stream = sys.stdin if args.paths == "-" else open(args.paths, encoding="utf-8")
            paths = [line.strip() for line in stream if line.strip()]
        else:
            paths = changed_paths(args.repo, args.base, args.head)
    except (check_modules.BadManifest, OSError, subprocess.CalledProcessError) as error:
        print(f"affected: {error}", file=sys.stderr)
        return 2
    selection = select(paths, modules)
    chosen = targets(args.repo, selection, modules)
    if args.run:
        print(explain(selection))
        return run_targets(args.repo, chosen)
    print("\n".join(chosen) if args.targets else explain(selection))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
