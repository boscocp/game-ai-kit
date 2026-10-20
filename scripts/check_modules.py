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
    dangerous, still wrong: a module that cannot be lifted out alone;
  * M5 a technique depending on something other than a kernel. Invariant 2,
    said in modules: someone who wants only A* copies two folders;
  * M6 a gate the manifest names that the Makefile has not got;
  * M7 a gate in `make check` that no module owns and that is not in the set
    every wave runs, or that two modules both own.

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
    "godot/.gitignore", "python/gameaikit/__init__.py", "python/tests/__init__.py",
    "python/tests/test_placeholder.py",
)

# What only a person reads. The lints that read it run on every wave anyway,
# so a change here selects no module.
PROSE = (
    "docs/", "tasks/", "README.md", "CONTRIBUTING.md", "CLAUDE.md",
    "LICENSE", "NOTICE", "VERSION", ".gitignore",
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
IMPORT_RE = re.compile(r"\bgameaikit\.(\w+)")
READ_SUFFIXES = {".gd", ".tscn", ".json", ".py"}


@dataclasses.dataclass(frozen=True)
class Module:
    """One manifest: a module's name, kind, paths, dependencies and gates."""

    name: str
    kind: str
    owns: tuple[str, ...]
    depends_on: frozenset[str]
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


def without_comments(text: str, suffix: str) -> str:
    """The text with every `#` comment removed, quotes respected.

    GDScript and Python share the comment character. A `#` inside a string --
    a colour, a URL fragment -- is kept, because what is in a string can be a
    path the code really loads.
    """
    if suffix not in (".gd", ".py"):
        return text
    kept_lines = []
    for line in text.splitlines():
        quote = ""
        for index, character in enumerate(line):
            if quote:
                quote = "" if character == quote else quote
            elif character in "\"'":
                quote = character
            elif character == "#":
                line = line[:index]
                break
        kept_lines.append(line)
    return "\n".join(kept_lines)


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
    """Repository paths this file's code names, by `res://` or by spelling."""
    paths = [f"godot/{path}" for path in RES_PATH_RE.findall(code)]
    paths += REPO_PATH_RE.findall(code)
    if suffix == ".py":
        paths += [f"python/gameaikit/{package}/" for package in IMPORT_RE.findall(code)]
    return paths


def owner_of_reach(path: str, modules: dict[str, Module]) -> str | None:
    """Who owns a path named in code, which may be a folder without its slash.

    Both spellings are tried and the longer claim wins: `godot/game/checkers`
    is the checkers folder, not a file inside `godot/game/` that happens to
    have no extension.
    """
    found = claims(path, modules) + claims(path.rstrip("/") + "/", modules)
    return max(found)[1] if found else None


def is_test(path: str) -> bool:
    """True for a test: what it reaches selects it, and binds no addon."""
    return path.startswith(TESTS)


def measured_dependencies(repo: pathlib.Path, modules: dict[str, Module],
                          tests: bool = True) -> dict[str, set[str]]:
    """What each module reaches for in other modules, read from the tree.

    With `tests` false only the module's own code counts -- what invariant 2
    is about. A technique's test may well use another technique (the learned
    policy's scenarios walk by A*); that reach still selects the test.
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
            reach[mine].add(owner_of_reach(named, modules))
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
    """M3, M4 and M5: declared dependencies are the measured ones, and legal."""
    findings = []
    for name, module in sorted(modules.items()):
        for missing in sorted(measured[name] - module.depends_on):
            findings.append(f"M3 {name} uses {missing}, and its manifest does not say so")
        for unused in sorted(module.depends_on - measured[name]):
            findings.append(f"M4 {name} declares {unused}, and nothing in it uses it")
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


def check(repo: pathlib.Path) -> list[str]:
    """Every finding for this tree, in rule order."""
    modules = load_modules(repo)
    if not modules:
        return [f"M0 no manifests under {MANIFESTS}/ -- nothing is owned, nothing selected"]
    findings = [f"M0 {name}: kind {module.kind!r} is not one of {sorted(KINDS)}"
                for name, module in sorted(modules.items()) if module.kind not in KINDS]
    findings += check_ownership(tracked_files(repo), modules)
    findings += check_dependencies(measured_dependencies(repo, modules),
                                   measured_dependencies(repo, modules, tests=False), modules)
    findings += check_gates(repo, modules)
    return findings


def run(repo: pathlib.Path, measure: bool = False) -> int:
    """Print the findings, or with `measure` the graph as the code has it."""
    if measure:
        modules = load_modules(repo)
        for name, uses in sorted(measured_dependencies(repo, modules).items()):
            print(f"{name}: {', '.join(sorted(uses)) or '-'}")
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
             "depends_on": ["a"], "gates": ["test-game-match"]},
    "twin": {"module": "twin", "kind": "example", "owns": ["python/gameaikit/twin/"],
             "depends_on": ["a"]},
}


def build(root: pathlib.Path, name: str, files: dict[str, str],
          manifests: dict[str, dict]) -> pathlib.Path:
    """A throwaway git repository holding `files` and these manifests."""
    repo = root / name
    for path, text in {**files, "Makefile": MAKEFILE_TEXT}.items():
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


def self_test() -> int:
    failures = []

    def expect(label: str, repo: pathlib.Path, code: str = "") -> None:
        findings = check(repo)
        if code and not any(finding.startswith(code) for finding in findings):
            failures.append(f"{label}: expected a {code} finding, got {findings or 'none'}")
        if not code and findings:
            failures.append(f"{label}: expected no finding, got {findings}")

    with tempfile.TemporaryDirectory() as workspace:
        root = pathlib.Path(workspace)
        expect("manifests that match the code", build(root, "good", FILES, MANIFESTS_TEXT))
        expect("no manifests at all", build(root, "none", FILES, {}), "M0")
        # Planted: a file nobody owns.
        expect("an unowned file", build(root, "unowned",
               {**FILES, "godot/game/orphan.gd": "var x := 1\n"}, MANIFESTS_TEXT), "M1")
        # Planted: two modules claiming the same folder.
        expect("a path claimed twice", build(root, "twice", FILES,
               changed(MANIFESTS_TEXT, "twin", owns=["python/gameaikit/twin/",
                                                     "godot/game/play/"])), "M2")
        # Planted: a class used and not declared -- the dependency that skips a test.
        expect("an undeclared class use", build(root, "class", FILES,
               changed(MANIFESTS_TEXT, "play", depends_on=[])), "M3")
        # Planted: a path the Python twin reads and does not declare.
        expect("an undeclared path read", build(root, "path", FILES,
               changed(MANIFESTS_TEXT, "twin", depends_on=[])), "M3")
        expect("a declared dependency nothing uses", build(root, "unused", FILES,
               changed(MANIFESTS_TEXT, "play", depends_on=["a", "core"])), "M4")
        expect("a technique leaning on an example", build(root, "technique",
               {**FILES, "godot/addons/a/a_star.gd": FILES["godot/addons/a/a_star.gd"]
                + "var play := preload('res://game/play/play.gd')\n"},
               changed(MANIFESTS_TEXT, "a", depends_on=["core", "play"])), "M5")
        expect("a gate the Makefile has not got", build(root, "ghost", FILES,
               changed(MANIFESTS_TEXT, "a", gates=["test-a-properties", "test-nothing"])), "M6")
        expect("a gate of check nobody owns", build(root, "orphan-gate", FILES,
               changed(MANIFESTS_TEXT, "play", gates=[])), "M7")

    if without_comments("var colour := '#fff'  # Grid", ".gd") != "var colour := '#fff'  ":
        failures.append("a # inside a string was taken for a comment")

    for failure in failures:
        print(f"self-test FAIL: {failure}")
    print(f"self-test: {'ok' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
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
