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
  5. T71's one exception to rule 2: a Makefile or manifest change that only
     adds gates of one module selects that module, as a change to its code
     would. `added_gates.py` reads the diff to say so, and any doubt leaves
     the path global. It needs the diff, so `--paths` never takes it.

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
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import added_gates  # noqa: E402 -- rule 5: a change that only adds a gate
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


class ChangeUnknown(Exception):
    """git could not say what changed: the base is not a commit it has."""


def changed_paths(repo: pathlib.Path, base: str, head: str | None) -> list[str]:
    """The paths a change touches, from git; with no head, the working tree too.

    `--no-renames`, because git detects renames by default and `--name-only`
    then prints the new path alone: a file moved out of the stealth game
    selected only the module it moved into, and the stealth code that still
    preloads the old path went untested. Both ends of a move are changes.
    """
    if head is not None:
        return git_answer(repo, base, "diff", "--name-only", "--no-renames", f"{base}...{head}")
    fork = fork_point(repo, base, None)
    return sorted(set(git_answer(repo, base, "diff", "--name-only", "--no-renames", fork))
                  | set(git_answer(repo, base, "ls-files", "--others", "--exclude-standard")))


def git_answer(repo: pathlib.Path, base: str, *args: str) -> list[str]:
    """git's non-empty output lines; ChangeUnknown, naming `base`, when it fails."""
    done = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if done.returncode != 0:
        raise ChangeUnknown(f"git {' '.join(args)}: {done.stderr.strip()} -- is {base!r} a "
                            "commit this clone has? (on CI: a first push, or a force push)")
    return [line for line in done.stdout.splitlines() if line]


def fork_point(repo: pathlib.Path, base: str, head: str | None) -> str:
    """Where the change began: the merge base of `base` and `head` (or HEAD)."""
    return git_answer(repo, base, "merge-base", base, head or "HEAD")[0]


def dependents(modules: dict[str, Module]) -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    """Who uses each module: by their code, and by their tests only."""
    by_code: dict[str, set[str]] = {name: set() for name in modules}
    by_tests: dict[str, set[str]] = {name: set() for name in modules}
    for name, module in modules.items():
        for other in module.depends_on:
            by_code.setdefault(other, set()).add(name)
        for other in module.tests_depend_on:
            by_tests.setdefault(other, set()).add(name)
    return by_code, by_tests


def select(paths: list[str], modules: dict[str, Module],
           local: dict[str, str] | None = None) -> Selection:
    """Rules 1-3 for each path, then every dependent, transitively.

    A module whose code uses a changed one is changed in effect, and its own
    users are followed in turn. A module whose tests alone use it has its
    tests run and is followed no further: its code is what it was. `local`
    names the global paths whose change only added a gate (rule 5), each
    with the module it selects instead.
    """
    local = local or {}
    touched, reasons, notes = set(), [], []
    for path in paths:
        if is_under(path, PROSE):
            continue
        if path in local:
            touched.add(local[path])
            notes.append(f"{path} only adds a gate of {local[path]}")
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
    by_code, by_tests = dependents(modules)
    changed, waiting = set(), sorted(touched)
    while waiting:
        name = waiting.pop()
        if name not in changed:
            changed.add(name)
            waiting.extend(sorted(by_code.get(name, ())))
    tested = {user for name in changed for user in by_tests.get(name, ())} - changed
    reasons = notes + [f"{name} changed" for name in sorted(touched)]
    reasons += [f"{name} uses a module that changed" for name in sorted(changed - touched)]
    reasons += [f"{name}'s tests use a module that changed" for name in sorted(tested)]
    return Selection(False, frozenset(changed | tested), tuple(reasons))


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
    "c": {"module": "c", "kind": "technique", "owns": ["godot/addons/c/"],
          "tests_depend_on": ["play"]},
    "d": {"module": "d", "kind": "example", "owns": ["godot/game/d/"], "depends_on": ["c"]},
    "play": {"module": "play", "kind": "example", "owns": ["godot/game/play/", "scripts/fetch_play_art.py"],
             "depends_on": ["a"], "gates": ["test-play-match"], "retrain": ["N7"]},
}

MAKEFILE_TEXT = """\
check: check-no-engine test-a-properties test-play-match ## Run every gate
check-no-engine: lint-one lint-no-training
lint-one:
\t@true
lint-no-training:
\t@true
test-a-properties:
\t@true
# a note inside the recipe
\t@true
test-play-match:
\t@true
WORDS = one \\
  two
"""

# Wave 75's shape, on the fixture: a new gate of `play`, its name put into
# `check:`, and appended to `play`'s manifest.
NEW_GATE = """
.PHONY: test-play-you
test-play-you: import ## You drive (planted)
\t@$(GODOT) --headless --path godot -s res://game/play/you_gate.gd
"""


def rename_case(root: pathlib.Path) -> list[str]:
    """Planted: a file moved between modules is a change to both of them."""
    repo = root / "renamed"
    (repo / "godot/game/one").mkdir(parents=True)
    (repo / "godot/game/one/x.gd").write_text("var moved := true\n" * 20)

    def git(*args: str) -> None:
        subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t",
                        *args], check=True, capture_output=True)

    git("init", "-q")
    git("add", "-A")
    git("commit", "-qm", "one")
    (repo / "godot/game/two").mkdir()
    git("mv", "godot/game/one/x.gd", "godot/game/two/x.gd")
    git("commit", "-qm", "two")
    paths = changed_paths(repo, "HEAD^1", "HEAD")
    if paths != ["godot/game/one/x.gd", "godot/game/two/x.gd"]:
        return [f"a move between modules: expected both paths, got {paths}"]
    return []


def added_gate(makefile: str, gate: str = NEW_GATE, listed: str = "test-play-you") -> str:
    """The fixture Makefile with `gate` appended and `listed` put into `check:`."""
    first, rest = makefile.split("\n", 1)
    return f"{first.replace(' ##', f' {listed} ##', 1)}\n{rest}{gate}"


def gate_change(root: pathlib.Path, label: str, makefile: str,
                manifests: dict[str, dict], before: str = MAKEFILE_TEXT) -> Selection:
    """What a committed change from `before` to `makefile`, and to the manifests, selects.

    A real repository and a real diff: rule 5 reads the diff, so its
    planted cases must have one.
    """
    repo = root / re.sub(r"\W+", "-", label)
    (repo / "modules").mkdir(parents=True)
    (repo / "Makefile").write_text(before)
    for name, manifest in MANIFESTS.items():
        (repo / "modules" / f"{name}.json").write_text(json.dumps(manifest, indent=2) + "\n")

    def git(*args: str) -> None:
        subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t",
                        *args], check=True, capture_output=True)

    git("init", "-q")
    git("add", "-A")
    git("commit", "-qm", "before")
    (repo / "Makefile").write_text(makefile)
    for name, manifest in manifests.items():
        (repo / "modules" / f"{name}.json").write_text(json.dumps(manifest, indent=2) + "\n")
    git("commit", "-qam", "after")
    modules = check_modules.load_modules(repo)
    paths = changed_paths(repo, "HEAD^1", "HEAD")
    return select(paths, modules, added_gates.local_paths(repo, "HEAD^1", "HEAD", paths, modules))


def planted_neighbour_changes(play: dict) -> dict[str, tuple]:
    """Rule 5's cases from wave 77's review: a gate that runs into the lines around it."""
    wave75 = added_gate(MAKEFILE_TEXT)
    named_before = MAKEFILE_TEXT.replace("test-play-match:\n", "test-play-match: test-play-you\n")
    conditional = MAKEFILE_TEXT + "ifdef QUIET\nendif\n"
    return {
        "a trailing backslash on the new recipe": (
            added_gate(MAKEFILE_TEXT, "").replace("test-play-match:", NEW_GATE.lstrip().rstrip("\n")
                                                  + " \\\ntest-play-match:"), {"play": play}),
        "a backslash on the line before": (
            added_gate(MAKEFILE_TEXT, "").replace("WORDS = one \\\n", "WORDS = one \\\n" + NEW_GATE.lstrip()),
            {"play": play}),
        "a line joined into check": (
            wave75.replace("gate\ncheck-no-engine:", "gate check-no-engine:"), {"play": play}),
        "a name put in after check's comment": (
            MAKEFILE_TEXT.replace("every gate\n", "every gate test-play-you\n", 1) + NEW_GATE, {"play": play}),
        "a name the old Makefile used": (added_gate(named_before), {"play": play}, None, named_before),
        "a conditional in the Makefile": (added_gate(conditional), {"play": play}, None, conditional),
    }


def planted_gate_changes() -> dict[str, tuple]:
    """Rule 5's cases: (new Makefile, changed manifests, modules or None, old Makefile)."""
    play = {**MANIFESTS["play"], "gates": [*MANIFESTS["play"]["gates"], "test-play-you"]}
    wave75 = added_gate(MAKEFILE_TEXT)
    other_module = NEW_GATE.replace("res://game/play/", "res://addons/a/")
    return {
        **planted_neighbour_changes(play),
        "a new gate of play": (wave75, {"play": play}, {"play", "c"}, MAKEFILE_TEXT),
        "and another recipe changed": (
            wave75.replace("\t@true\ntest-play-match", "\t@false\ntest-play-match"), {"play": play}),
        "a gate of play running a's file": (added_gate(MAKEFILE_TEXT, other_module), {"play": play}),
        "a target removed": (MAKEFILE_TEXT.replace("test-play-match:\n\t@true\n", ""), {}),
        "a variable": (wave75.replace("check-no-engine:", "GODOT := elsewhere\ncheck-no-engine:"), {"play": play}),
        "an unreadable line": (added_gate(MAKEFILE_TEXT, NEW_GATE + "vpath %.gd godot\n"), {"play": play}),
        "inside another recipe": (
            added_gate(MAKEFILE_TEXT, "").replace("# a note inside the recipe\n",
                                                  "# a note inside the recipe\n" + NEW_GATE.lstrip()),
            {"play": play}),
        "before a comment inside another recipe": (
            added_gate(MAKEFILE_TEXT, "").replace("\t@true\n# a note", "\t@true\n" + NEW_GATE.lstrip() + "# a note"),
            {"play": play}),
        "a gate added and its module's owns changed": (
            wave75, {"play": {**play, "owns": [*play["owns"], "godot/game/play2/"]}}),
        "a gate added and a dependency changed": (wave75, {"play": {**play, "depends_on": ["a", "b"]}}),
        "an old recipe line swapped for a gate": (
            added_gate(MAKEFILE_TEXT, "").replace("test-play-match:\n\t@true\n", "test-play-match:\n" + NEW_GATE),
            {"play": play}),
        "a gate running two modules' files": (
            added_gate(MAKEFILE_TEXT, NEW_GATE + "\t@$(GODOT) -s res://addons/a/x.gd\n"), {}),
        "a recipe with another variable": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.replace("--path godot", "--path $(ELSEWHERE)")), {}),
        "a second rule for an old target": (
            MAKEFILE_TEXT + NEW_GATE.replace(".PHONY: test-play-you\n", "").replace(
                "test-play-you", "test-play-match"), {}),
        "a gate put in, another taken out of check": (wave75.replace(" test-a-properties", "", 1), {"play": play}),
    }


def gate_cases(root: pathlib.Path) -> list[str]:
    """Rule 5: wave 75's shape selects its module; each doubt selects everything."""
    failures = []
    for label, case in planted_gate_changes().items():
        makefile, manifests, chosen, before = case if len(case) == 4 else (*case, None, MAKEFILE_TEXT)
        got = gate_change(root, label, makefile, manifests, before)
        if (chosen is None) != got.everything or (chosen and set(got.modules) != chosen):
            failures.append(f"rule 5, {label}: expected {sorted(chosen) if chosen else 'everything'}, "
                            f"got {explain(got)!r}")
    return failures


def target_cases(repo: pathlib.Path, modules: dict[str, Module]) -> list[str]:
    """Rule 4 and the targets: an empty change, a technique, everything."""
    failures = []
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
    if targets(repo, select(["scripts/x.py"], modules), modules) != ["check"]:
        failures.append("selecting everything did not come out as `make check`")
    return failures


def self_test() -> int:
    """Each of the four rules against a planted case, and a move between modules."""
    failures = []

    def expect(label: str, paths: list[str], everything: bool, chosen: set[str]) -> None:
        got = select(paths, modules)
        if got.everything != everything or (not everything and set(got.modules) != chosen):
            failures.append(f"{label}: expected {'everything' if everything else sorted(chosen)}, "
                            f"got {explain(got)!r}")

    with tempfile.TemporaryDirectory() as workspace:
        repo = pathlib.Path(workspace) / "kit"
        (repo / "modules").mkdir(parents=True)
        for name, manifest in MANIFESTS.items():
            (repo / "modules" / f"{name}.json").write_text(json.dumps(manifest))
        (repo / "Makefile").write_text(MAKEFILE_TEXT)
        (repo / "godot/test/a").mkdir(parents=True)
        (repo / "godot/test/a/a_test.gd").write_text("extends GdUnitTestSuite\n")
        modules = check_modules.load_modules(repo)

        expect("a technique and what uses it", ["godot/addons/a/x.gd"], False, {"a", "play", "c"})
        expect("the kernel, transitively", ["godot/addons/core/grid.gd"], False,
               {"core", "a", "play", "c"})
        # c's tests read play; d uses c's code. A change to play runs c's
        # tests, and stops there: c's code did not change, so d is not run.
        expect("a test-only use stops the walk", ["godot/game/play/p.gd"], False, {"play", "c"})
        expect("a technique nobody uses", ["godot/addons/b/x.gd"], False, {"b"})
        expect("an unowned path", ["godot/addons/a/x.gd", "godot/new/thing.gd"], True, set())
        expect("a script", ["scripts/check_x.py"], True, set())
        expect("a manifest", ["modules/a.json"], True, set())
        # Rule 5 reads the diff; a list of paths has none, so it stays global.
        expect("the Makefile, by its path alone", ["Makefile"], True, set())
        expect("a module's own script", ["scripts/fetch_play_art.py"], False, {"play", "c"})
        expect("prose", ["docs/reviews/63.md", "tasks/STATUS.md"], False, set())
        failures += target_cases(repo, modules)
        failures += rename_case(pathlib.Path(workspace))
        failures += gate_cases(pathlib.Path(workspace))

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Parse the command line; exit 2 when it, git or a manifest cannot answer."""
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
        local = {}
        if args.paths:
            stream = sys.stdin if args.paths == "-" else open(args.paths, encoding="utf-8")
            paths = [line.strip() for line in stream if line.strip()]
        else:
            paths = changed_paths(args.repo, args.base, args.head)
            fork = fork_point(args.repo, args.base, args.head)
            local = added_gates.local_paths(args.repo, fork, args.head, paths, modules)
    except (check_modules.BadManifest, ChangeUnknown, OSError) as error:
        print(f"affected: {error}", file=sys.stderr)
        return 2
    selection = select(paths, modules, local)
    chosen = targets(args.repo, selection, modules)
    if args.run:
        print(explain(selection))
        return run_targets(args.repo, chosen)
    print("\n".join(chosen) if args.targets else explain(selection))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
