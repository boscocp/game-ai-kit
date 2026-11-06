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

The rules, each a planted case below
------------------------------------
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
     the path global. It needs the diff, so `--paths` never takes it. Since
     T111 a name put into `test-vectors`, in its one line or by a rule of
     its own beside the family's, is read as one put into `check:`.
  6. T111's: a change that only adds a module -- its new manifest, the new
     name in a user's `depends_on`, the library's two lists gaining its
     package -- selects that module and the user, as rule 5 does a gate.
     `added_module.py` reads it, with the same rule: any doubt is global.
     The scripts, CI, the engine pin and a path nobody owns are never read
     this way.

The timing gates -- test-rts-budget, test-mcts-budget, test-inference-budget,
test-planner-benchmark, test-rts-match -- were each one module's before
T111, like any gate, so a change runs one only when it selects that module.
Under five worktrees' load they failed in almost every wave of batch 118-122
and passed alone, and they still will whenever their module is selected;
`make check` keeps all of them.

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
import added_module  # noqa: E402 -- rules 5 and 6: a change that only adds a gate or a module
import check_modules  # noqa: E402 -- the manifests and the ownership rules
from check_modules import PROSE, Module, is_under, owner_of  # noqa: E402

GODOT_TESTS = "godot/test/"
PYTHON_TESTS = "python/tests/"
# Run with any selected Godot suite: it is global, and four seconds.
GLOBAL_SUITES = ("test/project_settings_test.gd",)
# Run with any selected Python test: it holds the library's lists to the
# manifests, which rule 6 lets a change touch without selecting everything.
GLOBAL_PYTESTS = ("test_techniques",)


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
            notes.append(f"{path} only adds to {local[path]}: a gate, or the module itself")
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
        found.append(f'test-python-some PYTESTS="{" ".join([*GLOBAL_PYTESTS, *sorted(python)])}"')
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
    "c": {"module": "c", "kind": "technique", "owns": ["godot/addons/c/", "godot/test/e/"],
          "tests_depend_on": ["play"]},
    "d": {"module": "d", "kind": "example", "owns": ["godot/game/d/", "spec/play/d/"], "depends_on": ["c"]},
    "play": {"module": "play", "kind": "example", "owns": ["godot/game/play/", "scripts/fetch_play_art.py",
                                                         "python/tests/test_play.py", "spec/play/",
                                                         "spec/vectors/play/"],
             "depends_on": ["a"], "gates": ["test-play-match"], "retrain": ["N7"]},
}

MAKEFILE_TEXT = """\
check: check-no-engine test-a-properties test-play-match test-vectors ## Run every gate
check-no-engine: lint-one lint-no-training
import:
\t@true
wave-merge:
\t@true
test-vectors: test-a-properties lint-one ## Every vector, one family a line
\t@true
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


def write_files(repo: pathlib.Path, files: dict[str, str | None]) -> None:
    """Each file at its path, a None one deleted."""
    for path, text in files.items():
        target = repo / path
        if text is None:
            target.unlink(missing_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)


def gate_change(root: pathlib.Path, label: str, makefile: str, manifests: dict[str, dict],
                before: str = MAKEFILE_TEXT, files: dict[str, tuple] | None = None) -> Selection:
    """What a committed change from `before` to `makefile`, the manifests and `files` selects.

    A real repository and a real diff: rules 5 and 6 read the diff, so their
    planted cases must have one. `files` maps a path to its text before and
    after, either None where the file is absent.
    """
    repo = root / re.sub(r"\W+", "-", label)
    files = {**LIBRARY_FILES, **(files or {})}
    (repo / "modules").mkdir(parents=True)
    (repo / "Makefile").write_text(before)
    for name, manifest in MANIFESTS.items():
        (repo / "modules" / f"{name}.json").write_text(json.dumps(manifest, indent=2) + "\n")
    write_files(repo, {path: texts[0] for path, texts in files.items()})

    def git(*args: str) -> None:
        subprocess.run(["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@t",
                        *args], check=True, capture_output=True)

    git("init", "-q")
    git("add", "-A")
    git("commit", "-qm", "before")
    (repo / "Makefile").write_text(makefile)
    for name, manifest in manifests.items():
        (repo / "modules" / f"{name}.json").write_text(json.dumps(manifest, indent=2) + "\n")
    write_files(repo, {path: texts[1] for path, texts in files.items()})
    git("add", "-A")
    git("commit", "-qm", "after")
    modules = check_modules.load_modules(repo)
    paths = changed_paths(repo, "HEAD^1", "HEAD")
    return select(paths, modules, added_module.local_paths(repo, "HEAD^1", "HEAD", paths, modules))


def planted_neighbour_changes(play: dict) -> dict[str, tuple]:
    """Rule 5's cases from wave 77's review: a gate that runs into the lines around it."""
    wave75 = added_gate(MAKEFILE_TEXT)
    named_before = MAKEFILE_TEXT.replace("test-play-match:\n", "test-play-match: test-play-you\n")
    conditional = MAKEFILE_TEXT + "ifdef QUIET\nendif\n"
    # The kit's own shape since wave 83: a conditional above every rule.
    on_top = "ifeq ($(OS),Windows_NT)\nSHELL := bash.exe\nelse\nSHELL := /bin/bash\nendif\n" + MAKEFILE_TEXT
    inside = conditional.replace("ifdef QUIET\n", "ifdef QUIET\n" + NEW_GATE.lstrip())
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
        "a gate inside a conditional": (added_gate(inside, ""), {"play": play}, None, conditional),
        "a conditional added": (added_gate(conditional), {"play": play}),
        "a conditional above every rule": (added_gate(on_top), {"play": play}, {"play", "c"}, on_top),
        "a conditional changed": (added_gate(on_top.replace("bash.exe", "sh.exe")), {"play": play}, None, on_top),
    }


def planted_vector_changes(play: dict) -> dict[str, tuple]:
    """T111's cases: a vector family put into `test-vectors`, in either form."""
    family = NEW_GATE.replace("test-play-you", "test-play-vectors")
    one_line = MAKEFILE_TEXT.replace("lint-one ## Every", "lint-one test-play-vectors ## Every")
    vectors = {**play, "gates": [*MANIFESTS["play"]["gates"], "test-play-vectors"]}
    attach = family.replace(".PHONY: test-play-vectors\n", ".PHONY: test-play-vectors\ntest-vectors: test-play-vectors\n")
    return {
        "a name put into test-vectors": (one_line + family, {"play": vectors}, {"play", "c"}, MAKEFILE_TEXT),
        "a family attached beside its rule": (MAKEFILE_TEXT + attach, {"play": vectors}, {"play", "c"}, MAKEFILE_TEXT),
        "a name in test-vectors the change did not add": (
            MAKEFILE_TEXT.replace("lint-one ## Every", "lint-one test-play-match ## Every"), {}),
        "test-vectors reordered": (
            one_line.replace("test-a-properties lint-one test-play-vectors ##", "lint-one test-a-properties test-play-vectors ##")
            + family, {"play": vectors}),
        "a name taken out of test-vectors": (
            MAKEFILE_TEXT.replace("test-vectors: test-a-properties lint-one ##", "test-vectors: lint-one ##"), {}),
        "a name moved from check into test-vectors": (
            one_line.replace(" test-play-match test-vectors ##", " test-vectors ##").replace(
                "test-play-vectors ## Every", "test-play-vectors test-play-match ## Every") + family,
            {"play": vectors}),
        "an old target attached beside a new one": (
            MAKEFILE_TEXT + attach + "test-vectors: test-play-match\n", {"play": vectors}),
        # After a new gate's recipe, the line below would join that recipe
        # if the attaching rule did not end it.
        "an attaching rule with a recipe": (
            MAKEFILE_TEXT + family + "test-vectors: test-play-vectors\n\t@false\n", {"play": vectors}),
        "an attaching rule naming two": (
            MAKEFILE_TEXT + attach.replace("test-vectors: test-play-vectors", "test-vectors: test-play-vectors lint-one"),
            {"play": vectors}),
    }


def planted_target_changes(play: dict) -> dict[str, tuple]:
    """T111's cases on a new rule: a non-gate target, and what a gate may depend on or name."""
    return {
        "a measuring target beside a gate": (
            added_gate(MAKEFILE_TEXT, NEW_GATE + ".PHONY: measure-play\nmeasure-play: import ## A table\n"
                       "\t@$(GODOT) -s res://addons/a/m.gd -- $(or $(SEEDS),200)\n"), {"play": play}, {"play", "c"},
            MAKEFILE_TEXT),
        "a gate that needs an old target that is not a gate": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.replace(": import", ": import wave-merge")), {"play": play}),
        "a recipe path climbing out of its folder": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.rstrip("\n") + " -- $(CURDIR)/spec/vectors/play/../a\n"),
            {"play": play}),
        "a gate that needs a new target": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.replace(": import", ": measure-play")
                       + "measure-play: import\n\t@$(GODOT) -s res://addons/a/m.gd\n"), {"play": play}),
    }


def module_change(**changes: object) -> dict[str, object]:
    """Wave 120's shape on the fixture, with `changes` made to it.

    A new technique `e` with its vectors, attached to `test-vectors`, and a
    measuring target beside them; `play` comes to depend on it, in prose
    and in its manifest; and the library lists gain its package.
    """
    e_manifest = {"module": "e", "kind": "technique", "about": "e",
                  "owns": ["godot/addons/e/", "python/gameaikit/e/", "python/tests/test_e.py"],
                  "gates": ["test-e-vectors"]}
    case = {
        "e": e_manifest, "e_gate": "res://addons/e/e_runner.gd",
        "play": {**MANIFESTS["play"], "about": "now with e", "depends_on": ["a", "e"]},
        "kit": ("a", "b", "e"), "packages": ("gameaikit.a", "gameaikit.e"), "group": "kit",
        "extra": {},
    }
    case.update(changes)
    makefile = MAKEFILE_TEXT + (
        ".PHONY: test-e-vectors\ntest-vectors: test-e-vectors\ntest-e-vectors: import ## e's vectors\n"
        f"\t@$(GODOT) --headless --path godot -s {case['e_gate']}\n"
        ".PHONY: measure-e\nmeasure-e: import ## A table, not a gate\n\t@$(GODOT) -s res://game/play/m.gd\n")
    files = {
        "godot/addons/e/e.gd": (None, "var e := 1\n"),
        "python/gameaikit/e/__init__.py": (None, ""),
        "python/tests/test_e.py": (None, "") if "python/tests/test_e.py" in case["e"]["owns"] else (None, None),
        "python/gameaikit/techniques.py": (library_file(), library_file(case["kit"], case["group"])),
        "python/pyproject.toml": (pyproject_file(), pyproject_file(case["packages"])),
        **case["extra"],
    }
    manifests = {"e": case["e"], "play": case["play"]}
    return {"makefile": makefile, "manifests": manifests, "files": files}


def library_file(names: tuple[str, ...] = ("a", "b"), group: str = "kit") -> str:
    """The fixture's techniques.py: its KIT_MODULES, and a line that is not the list."""
    listed = "".join(f'    "{name}",\n' for name in names)
    return f'"""The registry."""\n\nGROUP = "{group}"\n# a comment is prose\nKIT_MODULES = (\n{listed})\n'


def pyproject_file(packages: tuple[str, ...] = ("gameaikit.a",), version: str = "0.1.0") -> str:
    """The fixture's pyproject.toml: a version, and the packages one per line."""
    listed = "".join(f'    "{name}",\n' for name in ("gameaikit", *packages))
    return f'[project]\nversion = "{version}"\n\n[tool.setuptools]\npackages = [\n{listed}]\n'


LIBRARY_FILES = {"python/gameaikit/techniques.py": (library_file(), library_file()),
                 "python/pyproject.toml": (pyproject_file(), pyproject_file()),
                 "godot/addons/b/b.gd": ("var b := 1\n", "var b := 1\n")}


def planted_module_changes() -> dict[str, tuple]:
    """Rule 6's cases: wave 120's shape selects its modules; each doubt selects everything."""
    def case(chosen: set[str] | None, **changes: object) -> tuple:
        built = module_change(**changes)
        return built["makefile"], built["manifests"], chosen, MAKEFILE_TEXT, built["files"]

    e_manifest = module_change()["manifests"]["e"]
    return {
        "a new module, its vectors, its user and the library lists": case({"e", "play", "c"}),
        "a new module owning an old file": case(None, e={**e_manifest, "owns": [*e_manifest["owns"], "godot/addons/b/"]}),
        "a new module naming a gate nobody added": case(None, e={**e_manifest, "gates": ["test-e-other"]}),
        "a new module's gate running another's file": case(None, e_gate="res://addons/a/runner.gd"),
        "a dependency on a module that is not new": case(
            None, play={**MANIFESTS["play"], "depends_on": ["a", "e", "b"]}),
        "a dependency dropped as a new one comes": case(None, play={**MANIFESTS["play"], "depends_on": ["e"]}),
        "the registry gaining a name no new module owns": case(None, kit=("a", "b", "e", "zz")),
        "the registry reordered": case(None, kit=("b", "a", "e")),
        "the registry's file changed beyond its list": case(None, group="other"),
        "the packages gaining a name no new module owns": case(None, packages=("gameaikit.a", "gameaikit.e", "gameaikit.zz")),
        "the project file changed beyond its list": case(None, extra={"python/pyproject.toml": (
            pyproject_file(), pyproject_file(("gameaikit.a", "gameaikit.e"), "0.2.0"))}),
        "the lists gaining a module with no Python test": case(
            None, e={**e_manifest, "owns": e_manifest["owns"][:2]}),
        # Wave 123's review: what a new manifest must not take, each owned
        # by nobody at the fork, so only the shapes can refuse it.
        "a new module owning a file in another's vector folder": case(None, e=owning("spec/vectors/a/zz.json")),
        "a new module owning a CI workflow": case(None, e=owning(".github/workflows/zz.yml")),
        "a new module owning a package that shadows the registry": case(
            None, e=owning("python/gameaikit/techniques/")),
        "a new module owning the engine's override": case(None, e=owning("godot/override.cfg")),
        "a new module's shape another module claims": case(None, e=owning("godot/test/e/")),
        "a new module of kind example": case(None, e={**e_manifest, "kind": "example"}),
    }


def owning(extra: str) -> dict:
    """Wave 120's new manifest, owning one path more."""
    e_manifest = module_change()["manifests"]["e"]
    return {**e_manifest, "owns": [*e_manifest["owns"], extra]}


def shape_cases() -> list[str]:
    """Rule 6's package shapes: one that would shadow a module file is refused."""
    failures = []
    shadow = ["python/gameaikit/techniques/"]
    if added_module.owns_only_its_shapes(shadow, "techniques", {}, ["python/gameaikit/techniques.py"]):
        failures.append("rule 6 took a package folder shadowing techniques.py")
    if not added_module.owns_only_its_shapes(shadow, "techniques", {}, []):
        failures.append("rule 6 refused a technique's own new package")
    return failures


def planted_recipe_changes(play: dict) -> dict[str, tuple]:
    """Rule 5's cases on what a new gate's recipe names; and a manifest's prose."""
    return {
        "a gate running two modules' files": (
            added_gate(MAKEFILE_TEXT, NEW_GATE + "\t@$(GODOT) -s res://addons/a/x.gd\n"), {}),
        # Every vector gate names its folder without the slash (T111).
        "a gate reading its module's folder": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.rstrip("\n") + " -- $(CURDIR)/spec/vectors/play\n"),
            {"play": play}, {"play", "c"}, MAKEFILE_TEXT),
        "a gate reading a folder another module has a part of": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.rstrip("\n") + " -- $(CURDIR)/spec/play\n"), {"play": play}),
        "a recipe with another variable": (
            added_gate(MAKEFILE_TEXT, NEW_GATE.replace("--path godot", "--path $(ELSEWHERE)")), {}),
        # Intended: prose a person reads selects only the module it describes.
        "a manifest whose prose alone changed": (
            MAKEFILE_TEXT, {"play": {**MANIFESTS["play"], "about": "reworded"}}, {"play", "c"}, MAKEFILE_TEXT),
    }


def planted_gate_changes() -> dict[str, tuple]:
    """Rule 5's cases: (new Makefile, changed manifests, modules or None, old Makefile)."""
    play = {**MANIFESTS["play"], "gates": [*MANIFESTS["play"]["gates"], "test-play-you"]}
    wave75 = added_gate(MAKEFILE_TEXT)
    other_module = NEW_GATE.replace("res://game/play/", "res://addons/a/")
    return {
        **planted_neighbour_changes(play),
        **planted_vector_changes(play),
        **planted_target_changes(play),
        **planted_recipe_changes(play),
        **planted_module_changes(),
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
        "a second rule for an old target": (
            MAKEFILE_TEXT + NEW_GATE.replace(".PHONY: test-play-you\n", "").replace(
                "test-play-you", "test-play-match"), {}),
        "a gate put in, another taken out of check": (wave75.replace(" test-a-properties", "", 1), {"play": play}),
    }


def gate_cases(root: pathlib.Path) -> list[str]:
    """Rule 5: wave 75's shape selects its module; each doubt selects everything."""
    failures = []
    for label, case in planted_gate_changes().items():
        makefile, manifests, chosen, before, files = (*case, *(None, MAKEFILE_TEXT, {})[len(case) - 2:])
        got = gate_change(root, label, makefile, manifests, before, files)
        if (chosen is None) != got.everything or (chosen and set(got.modules) != chosen):
            failures.append(f"rules 5 and 6, {label}: expected {sorted(chosen) if chosen else 'everything'}, "
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
                 'test-godot-some SUITES="test/project_settings_test.gd test/a"',
                 'test-python-some PYTESTS="test_techniques test_play"'):
        if want not in chosen:
            failures.append(f"a change to a: {want!r} missing from {chosen}")
    if "lint-no-training" in chosen:
        failures.append("the full refit ran for a change that asked for one")
    # A module's gate -- a timing one is no different -- runs only with it.
    elsewhere = targets(repo, select(["godot/addons/b/x.gd"], modules), modules)
    if any(gate in elsewhere for gate in ("test-a-properties", "test-play-match")):
        failures.append(f"a change to b ran another module's gate: {elsewhere}")
    if targets(repo, select(["scripts/x.py"], modules), modules) != ["check"]:
        failures.append("selecting everything did not come out as `make check`")
    return failures


def self_test() -> int:
    """Each rule against a planted case, and a move between modules."""
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
        expect("the contribution templates", [".github/ISSUE_TEMPLATE/bug.yml",
               ".github/pull_request_template.md", ".github/FUNDING.yml", "SECURITY.md"],
               False, set())
        expect("a workflow beside the templates", [".github/workflows/ci.yml"], True, set())
        failures += target_cases(repo, modules)
        failures += rename_case(pathlib.Path(workspace))
        failures += gate_cases(pathlib.Path(workspace)) + shape_cases()

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
            local = added_module.local_paths(args.repo, fork, args.head, paths, modules)
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
