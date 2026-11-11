#!/usr/bin/env python3
"""Hold every module to its manifest: what it owns, and what it depends on.

The rule
--------
T58: the kit is a set of modules, each one technique or one example, and a
wave tests only the modules it touches and the ones that depend on them. That
selection is only as honest as two facts about every module -- which files it
owns, and which other modules it reaches for. Both are declared in
`modules/<name>.json`, and both are checked here against the tree:

  * M1 a tracked file under godot/, python/, spec/, data/ or tools/ that no
    module owns and that is not one of the global paths. A file nobody owns is
    a file whose change would select no test;
  * M2 a path two modules both claim with the same prefix -- longest prefix
    wins, so a tie is the only way ownership can be ambiguous;
  * M3 a dependency the code has and the manifest does not declare. This is
    the one that skips a test: change the module depended on, and the module
    that silently uses it is never selected;
  * M4 a dependency the manifest declares and the code does not have. Less
    dangerous, still wrong: a module that cannot be lifted out alone.
    Both are asked twice, because a manifest has two lists: `depends_on`,
    what the module's own code uses, and `tests_depend_on`, what only its
    tests use (ai_planning's vectors read the RTS's domain; ai_planning
    does not). The selector follows the first list on, and stops at the
    second: a change to the RTS runs ai_planning's tests, not everything
    that uses ai_planning;
  * M5 a technique depending on something other than a kernel. Invariant 2,
    said in modules: someone who wants only A* copies two folders;
  * M6 a gate the manifest names that the Makefile has not got;
  * M7 a gate in `make check` that no module owns and that is not in the set
    every wave runs, or that two modules both own;
  * M8 a test the selector cannot reach: a gdUnit4 suite not directly inside a
    test folder its module lists, or a Python test its module does not name.
    `affected.py` runs a module's tests by those entries, so a suite one
    folder deeper would never run on a wave;
  * M9 a test that uses another module's test helper without depending on
    that module's code. The selector follows a test-only use one step: if
    the league's tests borrow the tactical game's `TacticalMatch`, a change
    to whatever `TacticalMatch` uses reaches the tactical tests and stops --
    unless the league depends on the tactical code, which carries it on;
  * M10 a refit rule of `check_no_training.py` that no manifest, or two,
    names in `retrain`. A wave runs only the refits its modules name, so an
    unnamed one would run on main and never on a pull request.

What "depends on" means here, measured
--------------------------------------
Three kinds of reach, the ones this repository actually has:

  * a GDScript `class_name` used in another module's code. A class name needs
    no import (it is registered project-wide), so the name itself is the
    evidence -- the same reasoning as `check_addon_deps.py`;
  * a `res://` path, in GDScript, a scene or a JSON table;
  * a repository path in Python (`godot/addons/ai_learning/...`,
    `spec/vectors/...`): the Python twins read and write the Godot side's
    files, and no import would show it. Plus `gameaikit.<package>` imports.

Comments are not reach. `check_addon_deps.py` counts a class named in a
comment, on purpose; here that would make `ai_core` depend on the tactical
game for a sentence that explains where a type is used.

A known false positive: a Python docstring is not a comment to this gate.
A path written in one is reach (`REPO_PATH_RE`), so a docstring saying
"nothing in `godot/addons/` names this file" made `ai_llm` depend on every
addon in wave 111 (T93's review). Reworded there; the gate is unchanged,
because a docstring is also where a twin writes the path it reads.

Exit codes
----------
0   every module matches its manifest
1   findings, each printed
2   wrong usage, or a manifest that cannot be read

Usage
-----
    check_modules.py [--repo PATH]
    check_modules.py --measure [--repo PATH]   print the measured graph
    check_modules.py --self-test
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
import check_no_training  # noqa: E402 -- for the names of its refit rules
import check_workflow  # noqa: E402 -- the Makefile reader, fixed in wave 63

MANIFESTS = "modules"

# Where every tracked file must belong to a module.
SCOPE = ("godot/", "python/", "spec/", "data/", "tools/")

# What every gate stands on. A change here can change any verdict, so it
# selects everything; and a file here is owned by no module on purpose.
GLOBAL = (
    "Makefile", "mk/common.mk", "scripts/", "modules/", ".github/", ".githooks/",
    ".godot-version", "godot/project.godot", "godot/export_presets.cfg",
    "godot/addons/gdUnit4/", "godot/test/project_settings_test.gd",
    "godot/test/project_settings_test.gd.uid",
    # The shape every vectors runner checks a file against before it reads
    # one (T121): test code that every family's gate stands on.
    "godot/test/vector_shape.gd", "godot/test/vector_shape.gd.uid",
    "godot/test/vector_shape_test.gd", "godot/test/vector_shape_test.gd.uid",
    "godot/.gitignore", "python/gameaikit/__init__.py", "python/tests/__init__.py",
    "python/tests/test_placeholder.py",
    # The library's own (T64): the registry imports every technique, and the
    # project file and its attribution decide what any of them ships as.
    "python/gameaikit/techniques.py", "python/tests/test_techniques.py",
    "python/pyproject.toml", "python/LICENSE", "python/NOTICE", "python/README.md",
    # What the store was handed (T159): the release's record, read by
    # `scripts/check_published.py`, not by any module's code.
    "tools/store/", "python/tests/test_check_published.py",
)

# What only a person reads. The lints that read it run on every wave anyway,
# so a change here selects no module. The issue and pull request templates
# and the funding links are a person's too (T144), though under `.github/`:
# listed by name, so the workflows beside them stay global.
PROSE = (
    "docs/", "tasks/", "README.md", "README.pt-BR.md", "CONTRIBUTING.md", "CLAUDE.md",
    "LICENSE", "NOTICE", "VERSION", ".gitignore",
    "CODE_OF_CONDUCT.md", "SECURITY.md", "CODEOWNERS",
    ".github/ISSUE_TEMPLATE/", ".github/pull_request_template.md", ".github/FUNDING.yml",
)

KINDS = {"kernel", "technique", "example"}

# Where the tests live. What a test reaches selects it, but binds no addon.
TESTS = ("godot/test/", "python/tests/")

# Targets of `make check` that are not one module's: the lints read the whole
# tree by nature, the aggregates are split per module by the selector, and
# `import` is the engine's own preparation, run once before any of them.
AGGREGATES = {"check-no-engine", "test-godot", "test-python", "test-vectors", "import"}

CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.M)
WORD_RE = re.compile(r"\b[A-Z][A-Za-z0-9_]*\b")
RES_PATH_RE = re.compile(r"res://([\w./-]+)")
REPO_PATH_RE = re.compile(r"\b((?:godot|spec|data|python)/[\w./-]*\w)")
# The same path built by pathlib: `ROOT / "spec" / "vectors" / "menace"`.
JOINED_PATH_RE = re.compile(r"""["'](godot|spec|data|python)["']((?:\s*/\s*["'][\w.-]+["'])+)""")
JOINED_PART_RE = re.compile(r"""["']([\w.-]+)["']""")
IMPORT_RE = re.compile(r"\bgameaikit\.(\w+)")
# `from gameaikit import ngram` and `from .. import ngram`: the same reach.
FROM_PACKAGE_IMPORT_RE = re.compile(r"^\s*from\s+(?:gameaikit|\.\.)\s+import\s+(\w+)", re.M)
# `from ..ngram import ...` inside a subpackage: a sibling package.
RELATIVE_IMPORT_RE = re.compile(r"^\s*from\s+\.\.(\w+)", re.M)
# `ROOT.joinpath("spec", "pddl")`, pathlib's other spelling of a join.
JOINPATH_RE = re.compile(r"""joinpath\(\s*((?:["'][\w.-]+["']\s*,?\s*)+)\)""")
# What a gate's recipe hands the engine or a script: the vectors' folders.
RECIPE_PATH_RE = re.compile(r"\$\(CURDIR\)/([\w./-]*\w)")
READ_SUFFIXES = {".gd", ".tscn", ".json", ".py"}


@dataclasses.dataclass(frozen=True)
class Module:
    """One manifest: a module's name, kind, paths, dependencies and gates."""

    name: str
    kind: str
    owns: tuple[str, ...]
    depends_on: frozenset[str]
    tests_depend_on: frozenset[str]
    gates: tuple[str, ...]
    retrain: tuple[str, ...]


class BadManifest(Exception):
    """A manifest that is not JSON, or lacks a field the gate needs."""


def load_modules(repo: pathlib.Path) -> dict[str, Module]:
    """Every manifest under modules/, by module name."""
    modules = {}
    for path in sorted((repo / MANIFESTS).glob("*.json")):
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
            module = Module(
                name=raw["module"], kind=raw["kind"], owns=tuple(raw["owns"]),
                depends_on=frozenset(raw.get("depends_on", [])),
                tests_depend_on=frozenset(raw.get("tests_depend_on", [])),
                gates=tuple(raw.get("gates", [])), retrain=tuple(raw.get("retrain", [])),
            )
        except (ValueError, KeyError, TypeError) as error:
            raise BadManifest(f"{path.name}: {error!r}") from error
        if module.name != path.stem:
            raise BadManifest(f"{path.name} names itself {module.name!r}")
        modules[module.name] = module
    return modules


def is_under(path: str, prefixes: tuple[str, ...]) -> bool:
    """True when `path` is one of `prefixes`, or inside one ending in a slash."""
    return any(path == prefix or (prefix.endswith("/") and path.startswith(prefix))
               for prefix in prefixes)


def claims(path: str, modules: dict[str, Module]) -> list[tuple[int, str]]:
    """Each module whose `owns` covers `path`, with the length of its prefix."""
    found = []
    for module in modules.values():
        for prefix in module.owns:
            if is_under(path, (prefix,)):
                found.append((len(prefix), module.name))
    return found


def owner_of(path: str, modules: dict[str, Module]) -> str | None:
    """The module that owns `path`: the longest prefix wins; None if nobody."""
    found = claims(path, modules)
    return max(found)[1] if found else None


def global_claim(path: str) -> int:
    """How long the global prefix covering `path` is; 0 when none does."""
    return max((len(prefix) for prefix in GLOBAL if is_under(path, (prefix,))), default=0)


def is_global(path: str, modules: dict[str, Module]) -> bool:
    """True when the global set claims `path` more closely than any module.

    The same longest-prefix rule as between modules: `scripts/` is global,
    and `scripts/fetch_rts_art.py`, named in the RTS's manifest, is the RTS's.
    """
    found = claims(path, modules)
    return global_claim(path) > (max(found)[0] if found else 0)


def tracked_files(repo: pathlib.Path) -> list[str]:
    """Every file git tracks, as a repository-relative path."""
    done = subprocess.run(["git", "-C", str(repo), "ls-files"],
                          capture_output=True, text=True, check=True)
    return done.stdout.splitlines()


def comment_start(line: str) -> int:
    """Where the `#` comment of one line begins, or its length if it has none.

    Quotes are respected, and a backslash inside a quote escapes the next
    character: without that, `"a \\"#"` ended the string early and cut off
    everything after it, a path included.
    """
    quote, escaped = "", False
    for index, character in enumerate(line):
        if escaped:
            escaped = False
        elif quote and character == "\\":
            escaped = True
        elif quote:
            quote = "" if character == quote else quote
        elif character in "\"'":
            quote = character
        elif character == "#":
            return index
    return len(line)


def without_comments(text: str, suffix: str) -> str:
    """The text with every `#` comment removed, quotes respected.

    GDScript and Python share the comment character. A `#` inside a string --
    a colour, a URL fragment -- is kept, because what is in a string can be a
    path the code really loads.
    """
    if suffix not in (".gd", ".py"):
        return text
    return "\n".join(line[:comment_start(line)] for line in text.splitlines())


def class_owners(repo: pathlib.Path, files: list[str],
                 modules: dict[str, Module]) -> dict[str, str]:
    """Every `class_name` in the tree, mapped to the module that declares it."""
    owners = {}
    for path in files:
        if path.endswith(".gd"):
            owner = owner_of(path, modules)
            text = (repo / path).read_text(encoding="utf-8")
            for name in CLASS_NAME_RE.findall(text):
                if owner:
                    owners[name] = owner
    return owners


def reached_paths(code: str, suffix: str) -> list[str]:
    """Repository paths this file's code names: `res://`, spelled, or joined.

    Python reaches the Godot side three ways, all of them here: a path
    spelled out, a path joined with pathlib's `/`, and an import -- absolute
    (`gameaikit.ngram`) or relative from a sibling package (`from ..ngram`).
    """
    paths = [f"godot/{path}" for path in RES_PATH_RE.findall(code)]
    paths += REPO_PATH_RE.findall(code)
    if suffix == ".py":
        for root, rest in JOINED_PATH_RE.findall(code):
            paths.append("/".join([root, *JOINED_PART_RE.findall(rest)]))
        for arguments in JOINPATH_RE.findall(code):
            paths.append("/".join(JOINED_PART_RE.findall(arguments)))
        packages = (IMPORT_RE.findall(code) + RELATIVE_IMPORT_RE.findall(code)
                    + FROM_PACKAGE_IMPORT_RE.findall(code))
        paths += [f"python/gameaikit/{package}/" for package in packages]
    return paths


def owners_of_reach(path: str, modules: dict[str, Module], files: list[str]) -> set[str]:
    """Who owns a path named in code, which may be a folder without its slash.

    Both spellings are tried and the longer claim wins: `godot/game/checkers`
    is the checkers folder, not a file inside `godot/game/`. A folder nobody
    claims whole -- `spec/pddl`, whose files belong to the tactical game and
    the RTS one by one -- is reached through every module owning a file in
    it. It used to be dropped, and a change to the tactics domain then
    selected neither of the two gates that read it.
    """
    found = claims(path, modules) + claims(path.rstrip("/") + "/", modules)
    if found:
        return {max(found)[1]}
    folder = path.rstrip("/") + "/"
    if folder in TESTS or not folder.startswith(SCOPE):
        # The whole of godot/test/ named at once is a test's planted bad
        # folder (`"res://test"`), not a reach into every module's tests.
        return set()
    return {owner_of(file, modules) for file in files if file.startswith(folder)} - {None}


def recipe(makefile_text: str, target: str) -> str:
    """The command lines of one Makefile target, its comments left out."""
    lines = makefile_text.splitlines()
    for number, line in enumerate(lines):
        if re.match(rf"^{re.escape(target)}:", line):
            body = []
            for command in lines[number + 1:]:
                if not command.startswith("\t"):
                    break
                if not command.lstrip().startswith("@#"):
                    body.append(command)
            return "\n".join(body)
    return ""


def recipe_reach(repo: pathlib.Path, modules: dict[str, Module],
                 files: list[str]) -> dict[str, set[str]]:
    """What each module's gates hand their scripts, read from the Makefile.

    `make test-planning-vectors` passes `$(CURDIR)/spec/pddl` to the engine:
    a reach no file of ai_planning spells, measured where it is written.
    """
    text = (repo / "Makefile").read_text(encoding="utf-8")
    reach: dict[str, set[str]] = {name: set() for name in modules}
    for name, module in modules.items():
        for gate in module.gates:
            commands = recipe(text, gate)
            named = RECIPE_PATH_RE.findall(commands)
            named += [f"godot/{path}" for path in RES_PATH_RE.findall(commands)]
            named += [f"python/gameaikit/{package}/" for package in IMPORT_RE.findall(commands)]
            for path in named:
                reach[name] |= owners_of_reach(path, modules, files)
    return reach


def is_test(path: str) -> bool:
    """True for a test: what it reaches selects it, and binds no addon."""
    return path.startswith(TESTS)


def measured_dependencies(repo: pathlib.Path, modules: dict[str, Module],
                          tests: bool = True) -> dict[str, set[str]]:
    """What each module reaches for in other modules, read from the tree.

    With `tests` false only the module's own code counts -- what invariant 2
    is about. A technique's test may well use another technique (the learned
    policy's scenarios walk by A*); that reach still selects the test, and so
    does what its gates' recipes hand the engine.
    """
    files = [path for path in tracked_files(repo) if (repo / path).is_file()]
    owners = class_owners(repo, files, modules)
    reach: dict[str, set[str]] = {name: set() for name in modules}
    for path in files:
        mine = owner_of(path, modules)
        suffix = pathlib.PurePath(path).suffix
        if mine is None or suffix not in READ_SUFFIXES or (is_test(path) and not tests):
            continue
        code = without_comments((repo / path).read_text(encoding="utf-8"), suffix)
        if suffix == ".gd":
            reach[mine] |= {owners[word] for word in WORD_RE.findall(code) if word in owners}
        for named in reached_paths(code, suffix):
            reach[mine] |= owners_of_reach(named, modules, files)
    if tests:
        for name, more in recipe_reach(repo, modules, files).items():
            reach[name] |= more
    for name in reach:
        reach[name] -= {name, None}
    return reach


def check_ownership(files: list[str], modules: dict[str, Module]) -> list[str]:
    """M1 and M2: every scoped file owned once, by the longest claim."""
    findings = []
    for path in files:
        if is_global(path, modules) or not path.startswith(SCOPE):
            continue
        found = claims(path, modules)
        if not found:
            findings.append(f"M1 {path} is owned by no module")
            continue
        longest = max(length for length, _ in found)
        tied = sorted(name for length, name in found if length == longest)
        if len(tied) > 1:
            findings.append(f"M2 {path} is claimed equally by {', '.join(tied)}")
    return findings


def check_dependencies(measured: dict[str, set[str]], code_only: dict[str, set[str]],
                       modules: dict[str, Module]) -> list[str]:
    """M3, M4 and M5: both declared lists are the measured ones, and legal."""
    findings = []
    for name, module in sorted(modules.items()):
        tests_only = measured[name] - code_only[name]
        for kind, declared, found in (("code", module.depends_on, code_only[name]),
                                      ("tests", module.tests_depend_on, tests_only)):
            field = "depends_on" if kind == "code" else "tests_depend_on"
            for missing in sorted(found - declared):
                findings.append(f"M3 {name}'s {kind} use {missing}, and {field} does not say so")
            for unused in sorted(declared - found):
                findings.append(f"M4 {name}'s {field} names {unused}, and its {kind} do not use it")
        if module.kind == "technique":
            for other in sorted(code_only[name]):
                if other in modules and modules[other].kind != "kernel":
                    findings.append(f"M5 technique {name} depends on {other}, "
                                    f"a {modules[other].kind}, not a kernel")
    return findings


def every_check_gate(makefile: pathlib.Path) -> set[str]:
    """`make check`'s targets, with its aggregates opened one level."""
    gates = set()
    for target in check_workflow.target_prerequisites(makefile, "check"):
        gates.add(target)
        if target in AGGREGATES:
            gates |= check_workflow.target_prerequisites(makefile, target)
    return gates


def always_run(makefile: pathlib.Path) -> set[str]:
    """The gates every wave runs whatever it touched: the whole-tree lints."""
    lints = {gate for gate in every_check_gate(makefile) if gate.startswith("lint-")}
    return lints | {"lint-modules"}


def check_gates(repo: pathlib.Path, modules: dict[str, Module]) -> list[str]:
    """M6 and M7: each gate of `make check` belongs to the lints or to one module."""
    makefile = repo / "Makefile"
    targets = check_workflow.make_targets(makefile)
    findings = []
    owned: dict[str, list[str]] = {}
    for name, module in sorted(modules.items()):
        for gate in module.gates:
            owned.setdefault(gate, []).append(name)
            if gate not in targets:
                findings.append(f"M6 {name} names `make {gate}`, which the Makefile has not got")
    free = AGGREGATES | always_run(makefile)
    for gate in sorted(every_check_gate(makefile) - free):
        if gate not in owned:
            findings.append(f"M7 `make {gate}` is in `make check` and no module owns it")
    for gate, owners in sorted(owned.items()):
        if len(owners) > 1:
            findings.append(f"M7 `make {gate}` is owned by {', '.join(owners)}")
    return findings


def helper_uses(repo: pathlib.Path, files: list[str],
                modules: dict[str, Module]) -> set[tuple[str, str]]:
    """(user, owner) for each test that uses another module's test helper.

    A helper is a class declared in a test file, or a test file named by
    path; the user is the module owning the test that uses it.
    """
    helpers = {}
    for path in files:
        if path.endswith(".gd") and is_test(path):
            for name in CLASS_NAME_RE.findall((repo / path).read_text(encoding="utf-8")):
                helpers[name] = owner_of(path, modules)
    uses = set()
    for path in files:
        mine = owner_of(path, modules)
        if not is_test(path) or mine is None or not path.endswith((".gd", ".py")):
            continue
        code = without_comments((repo / path).read_text(encoding="utf-8"), pathlib.PurePath(path).suffix)
        found = {helpers[word] for word in WORD_RE.findall(code) if word in helpers}
        found |= {owner_of(named, modules) for named in reached_paths(code, ".gd") if is_test(named)}
        uses |= {(mine, owner) for owner in found if owner not in (mine, None)}
    return uses


def check_helpers(repo: pathlib.Path, files: list[str], modules: dict[str, Module]) -> list[str]:
    """M9: a borrowed test helper comes with a code dependency on its module."""
    return [f"M9 {user}'s tests use {owner}'s test helpers, and {user} does not depend "
            f"on {owner}'s code -- a change behind the helper would stop at {owner}"
            for user, owner in sorted(helper_uses(repo, files, modules))
            if owner not in modules[user].depends_on]


def check_refits(modules: dict[str, Module]) -> list[str]:
    """M10: each refit rule is named by exactly one module."""
    findings = []
    for rule in check_no_training.RETRAINING:
        named = sorted(name for name, module in modules.items() if rule in module.retrain)
        if len(named) != 1:
            findings.append(f"M10 refit {rule} is named by {', '.join(named) or 'no module'}; "
                            "exactly one must name it, or a wave never runs it")
    return findings


def check_selectable(files: list[str], modules: dict[str, Module]) -> list[str]:
    """M8: every test sits where `affected.py` looks for its module's tests."""
    findings = []
    for path in files:
        owner = owner_of(path, modules)
        if owner is None or is_global(path, modules):
            continue
        listed = modules[owner].owns
        name = pathlib.PurePath(path).name
        if path.startswith("godot/test/") and name.endswith("_test.gd"):
            if path.rsplit("/", 1)[0] + "/" not in listed:
                findings.append(f"M8 {path}: {owner} lists no test folder holding it directly")
        elif path.startswith("python/tests/") and name.startswith("test_") and path not in listed:
            findings.append(f"M8 {path}: {owner} does not name this Python test")
    return findings


def check(repo: pathlib.Path) -> list[str]:
    """Every finding for this tree, in rule order."""
    modules = load_modules(repo)
    if not modules:
        return [f"M0 no manifests under {MANIFESTS}/ -- nothing is owned, nothing selected"]
    findings = [f"M0 {name}: kind {module.kind!r} is not one of {sorted(KINDS)}"
                for name, module in sorted(modules.items()) if module.kind not in KINDS]
    findings += check_ownership(tracked_files(repo), modules)
    findings += check_selectable(tracked_files(repo), modules)
    findings += check_helpers(repo, [path for path in tracked_files(repo) if (repo / path).is_file()],
                              modules)
    findings += check_refits(modules)
    findings += check_dependencies(measured_dependencies(repo, modules),
                                   measured_dependencies(repo, modules, tests=False), modules)
    findings += check_gates(repo, modules)
    return findings


def run(repo: pathlib.Path, measure: bool = False) -> int:
    """Print the findings, or with `measure` the graph as the code has it."""
    if measure:
        modules = load_modules(repo)
        code = measured_dependencies(repo, modules, tests=False)
        for name, uses in sorted(measured_dependencies(repo, modules).items()):
            tests_only = sorted(uses - code[name])
            print(f"{name}: code {', '.join(sorted(code[name])) or '-'}; "
                  f"tests only {', '.join(tests_only) or '-'}")
        return 0
    findings = check(repo)
    for finding in findings:
        print(finding)
    if not findings:
        print(f"check_modules: ok -- {len(load_modules(repo))} modules")
    return 1 if findings else 0


# --- self-test -------------------------------------------------------------


MAKEFILE_TEXT = """\
check: check-no-engine test-godot test-a-properties \\
       test-game-match ## Every gate
check-no-engine: lint-one test-python
lint-one:
\t@true
test-python:
\t@true
test-godot:
\t@true
test-a-properties:
\t@true
test-game-match:
\t@true
"""

FILES = {
    "godot/addons/core/grid.gd": "class_name Grid\nextends RefCounted\n",
    "godot/addons/a/a_star.gd": "class_name AStar\nvar grid: Grid\n",
    "godot/game/play/play.gd": "var search := AStar.new()\n# Grid is mentioned here\n",
    "python/gameaikit/twin/read.py": "PATH = 'godot/addons/a/a_star.gd'\n",
}

MANIFESTS_TEXT = {
    "core": {"module": "core", "kind": "kernel", "owns": ["godot/addons/core/"]},
    "a": {"module": "a", "kind": "technique", "owns": ["godot/addons/a/"],
          "depends_on": ["core"], "gates": ["test-a-properties"]},
    "play": {"module": "play", "kind": "example", "owns": ["godot/game/play/"],
             "depends_on": ["a"], "gates": ["test-game-match"],
             "retrain": list(check_no_training.RETRAINING)},
    "twin": {"module": "twin", "kind": "example", "owns": ["python/gameaikit/twin/"],
             "depends_on": ["a"]},
}


def build(root: pathlib.Path, name: str, files: dict[str, str],
          manifests: dict[str, dict], makefile: str = MAKEFILE_TEXT) -> pathlib.Path:
    """A throwaway git repository holding `files` and these manifests."""
    repo = root / name
    for path, text in {**files, "Makefile": makefile}.items():
        (repo / path).parent.mkdir(parents=True, exist_ok=True)
        (repo / path).write_text(text)
    (repo / MANIFESTS).mkdir()
    for module, manifest in manifests.items():
        (repo / MANIFESTS / f"{module}.json").write_text(json.dumps(manifest))
    subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
    return repo


def changed(manifests: dict[str, dict], module: str, **fields) -> dict[str, dict]:
    """A copy of the manifests with one module's fields replaced."""
    copy = json.loads(json.dumps(manifests))
    copy[module].update(fields)
    return copy


def manifest_cases(root: pathlib.Path, expect) -> None:
    """The rules about what a manifest says: kinds, ownership, gates, tests."""
    expect("manifests that match the code", build(root, "good", FILES, MANIFESTS_TEXT))
    expect("no manifests at all", build(root, "none", FILES, {}), "M0")
    expect("a kind nobody defined", build(root, "kind", FILES,
           changed(MANIFESTS_TEXT, "twin", kind="library")), "M0")
    expect("an unowned file", build(root, "unowned",
           {**FILES, "godot/game/orphan.gd": "var x := 1\n"}, MANIFESTS_TEXT), "M1")
    expect("a path claimed twice", build(root, "twice", FILES, changed(
        MANIFESTS_TEXT, "twin", owns=["python/gameaikit/twin/", "godot/game/play/"])), "M2")
    expect("a gate the Makefile has not got", build(root, "ghost", FILES,
           changed(MANIFESTS_TEXT, "a", gates=["test-a-properties", "test-nothing"])), "M6")
    expect("a gate of check nobody owns", build(root, "orphan-gate", FILES,
           changed(MANIFESTS_TEXT, "play", gates=[])), "M7")
    expect("a gate two modules own", build(root, "two-gate", FILES,
           changed(MANIFESTS_TEXT, "twin", gates=["test-game-match"])), "M7")
    deep = {**FILES, "godot/test/play/deep/x_test.gd": "extends GdUnitTestSuite\n"}
    expect("a suite one folder below its module's", build(root, "deep", deep, changed(
        MANIFESTS_TEXT, "play", owns=["godot/game/play/", "godot/test/play/"])), "M8")
    expect("a refit nobody names", build(root, "refit-none", FILES,
           changed(MANIFESTS_TEXT, "play", retrain=[])), "M10")
    expect("a refit named twice", build(root, "refit-twice", FILES,
           changed(MANIFESTS_TEXT, "twin", retrain=["N7"])), "M10")
    python_test = {**FILES, "python/tests/test_twin.py": "import unittest\n"}
    expect("a Python test owned by a folder", build(root, "pyfolder", python_test, changed(
        MANIFESTS_TEXT, "twin", owns=["python/gameaikit/twin/", "python/tests/"])), "M8")


def measurement_cases(root: pathlib.Path, expect) -> None:
    """The rules about what the code reaches: each way of reaching, planted."""
    expect("an undeclared class use", build(root, "class", FILES,
           changed(MANIFESTS_TEXT, "play", depends_on=[])), "M3")
    expect("an undeclared path read", build(root, "path", FILES,
           changed(MANIFESTS_TEXT, "twin", depends_on=[])), "M3")
    joined = {**FILES, "python/gameaikit/twin/read.py": 'A = ROOT / "godot" / "addons" / "a"\n'}
    expect("a path joined by pathlib", build(root, "joined", joined,
           changed(MANIFESTS_TEXT, "twin", depends_on=[])), "M3")
    relative = {**FILES, "python/gameaikit/twin/read.py": "from ..other import thing\n"}
    other = {**MANIFESTS_TEXT, "other": {"module": "other", "kind": "example",
                                          "owns": ["python/gameaikit/other/"]}}
    expect("a relative import of a sibling package", build(
        root, "relative", {**relative, "python/gameaikit/other/x.py": "X = 1\n"}, other), "M3")
    # Planted: the gap the wave's review found. A folder owned file by file,
    # reached only through a gate's recipe, as spec/pddl was.
    by_file = changed(MANIFESTS_TEXT, "play", owns=["godot/game/play/", "spec/pddl/one.json"])
    recipe_reach_text = MAKEFILE_TEXT.replace(
        "test-a-properties:\n\t@true\n", "test-a-properties:\n\t@run -- $(CURDIR)/spec/pddl\n")
    expect("a folder reached by a gate's recipe", build(
        root, "recipe", {**FILES, "spec/pddl/one.json": "{}\n"}, by_file, recipe_reach_text), "M3")
    expect("a declared dependency nothing uses", build(root, "unused", FILES,
           changed(MANIFESTS_TEXT, "play", depends_on=["a", "core"])), "M4")
    for label, line in (("an import from the package", "from gameaikit import other\n"),
                        ("an import from the parent", "from .. import other\n"),
                        ("a joinpath", 'X = ROOT.joinpath("python", "gameaikit", "other")\n')):
        expect(label, build(root, label.replace(" ", "-"), {
            **FILES, "python/gameaikit/twin/read.py": line, "python/gameaikit/other/x.py": "X = 1\n"},
            {**MANIFESTS_TEXT, "other": {"module": "other", "kind": "example",
                                         "owns": ["python/gameaikit/other/"]}}), "M3")
    # The whole test root named at once is a planted bad folder in a test,
    # not a reach into every module's tests.
    # A module with no dependency at all, so any reach it gains is a finding.
    expect("res://test named as a whole", build(root, "test-root", {
        **FILES, "godot/test/lone/lone_test.gd": 'var bad := "res://test"\n',
        "godot/test/a/a_test.gd": "var x := 1\n"}, {
            **changed(MANIFESTS_TEXT, "a", owns=["godot/addons/a/", "godot/test/a/"]),
            "lone": {"module": "lone", "kind": "example", "owns": ["godot/test/lone/"]}}))
    # Planted: a test borrowing another module's helper, with no code dependency.
    helper = {**FILES, "godot/test/a/a_match.gd": "class_name AMatch\n",
              "godot/test/twin/twin_test.gd": "var match := AMatch.new()\n"}
    borrowed = changed(changed(MANIFESTS_TEXT, "a", owns=["godot/addons/a/", "godot/test/a/"]),
                       "twin", owns=["python/gameaikit/twin/", "godot/test/twin/"],
                       depends_on=["a"])
    expect("a borrowed helper with a code dependency", build(root, "helper-ok", helper, borrowed))
    expect("a borrowed helper with none", build(root, "helper", helper, changed(
        borrowed, "twin", depends_on=[], tests_depend_on=["a"])), "M9")
    # Planted: a test's reach declared as the code's, and the reverse.
    tested = {**FILES, "godot/test/play/play_test.gd": "var grid := Grid.new()\n"}
    test_folder = ["godot/game/play/", "godot/test/play/"]
    expect("a test's reach declared as the code's", build(root, "as-code", tested, changed(
        MANIFESTS_TEXT, "play", owns=test_folder, depends_on=["a", "core"])), "M4")
    expect("a test's reach declared nowhere", build(root, "test-reach", tested, changed(
        MANIFESTS_TEXT, "play", owns=test_folder)), "M3")
    expect("a test's reach declared as such", build(root, "test-ok", tested, changed(
        MANIFESTS_TEXT, "play", owns=test_folder, tests_depend_on=["core"])))
    expect("a technique leaning on an example", build(root, "technique",
           {**FILES, "godot/addons/a/a_star.gd": FILES["godot/addons/a/a_star.gd"]
            + "var play := preload('res://game/play/play.gd')\n"},
           changed(MANIFESTS_TEXT, "a", depends_on=["core", "play"])), "M5")


def comment_cases() -> list[str]:
    """`#` inside a string is not a comment, escaped quote or not."""
    failures = []
    for line, kept in (("var colour := '#fff'  # Grid", "var colour := '#fff'  "),
                       ('s = "a \\"#" + "godot/x"  # c', 's = "a \\"#" + "godot/x"  ')):
        if without_comments(line, ".gd") != kept:
            failures.append(f"comment stripping: {line!r} became {without_comments(line, '.gd')!r}")
    return failures


def self_test() -> int:
    """Every rule against a planted case it must reject, and one good tree."""
    failures = comment_cases()

    def expect(label: str, repo: pathlib.Path, code: str = "") -> None:
        findings = check(repo)
        if code and not any(finding.startswith(code) for finding in findings):
            failures.append(f"{label}: expected a {code} finding, got {findings or 'none'}")
        if not code and findings:
            failures.append(f"{label}: expected no finding, got {findings}")

    with tempfile.TemporaryDirectory() as workspace:
        manifest_cases(pathlib.Path(workspace), expect)
        measurement_cases(pathlib.Path(workspace), expect)
    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    """Parse the command line; exit 2 for a usage error or a broken manifest."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parent.parent)
    parser.add_argument("--measure", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    try:
        args = parser.parse_args(argv)
    except SystemExit as exit_request:
        return 2 if exit_request.code else 0
    if args.self_test:
        return self_test()
    try:
        return run(args.repo, measure=args.measure)
    except (BadManifest, OSError, subprocess.CalledProcessError) as error:
        print(f"check_modules: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
