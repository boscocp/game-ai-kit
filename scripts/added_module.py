"""Read a change that adds a module: is that all it did to the global paths?

What it does
------------
T111. Rule 5 (`added_gates.py`) reads a Makefile or a manifest whose
change only adds gates. A wave that adds a technique touches more global
paths than those: a new manifest, the new name in the `depends_on` of the
module that uses it, and the library's two lists -- `KIT_MODULES` in
`python/gameaikit/techniques.py` and `packages` in `python/pyproject.toml`.
Each one alone was enough to run all of `make check`, and wave 120 (T95)
touched all of them for one addon and the level that uses it. This reads
those files too, and says when the whole change to each is that module
being added.

What counts as only adding a module
-----------------------------------
Any doubt is global, as in rule 5:

  * a new manifest, `modules/<name>.json`, absent at the
    fork, none of whose `owns` covers a file the fork had -- so no old file
    changes owner -- and whose every gate is one the Makefile's change
    added for it. It selects its own module.
  * a changed manifest: `added_gates.manifest_gates`, told which modules
    are new.
  * `KIT_MODULES`, or `packages`, gaining only the packages of one new
    module, in the old order otherwise, and the rest of the file the same:
    techniques.py compared as Python syntax, so a comment is prose, and
    pyproject.toml as TOML. The module must own a Python test, so a Python
    test runs, and `test_techniques` -- which holds both lists to the
    manifests -- runs with every Python selection (affected.py). It selects
    that module.

Used by `affected.py`, which holds the planted cases.
"""

from __future__ import annotations

import ast
import pathlib
import tomllib

from added_gates import MAKEFILE, MANIFESTS, file_at, git_lines, makefile_gates, manifest_gates, read_json
from check_modules import Module, is_under

TECHNIQUES = "python/gameaikit/techniques.py"
PYPROJECT = "python/pyproject.toml"
PACKAGE_ROOT = "python/gameaikit/"
PYTHON_TESTS = "python/tests/"


def new_module(repo: pathlib.Path, fork: str, head: str | None, path: str,
               added: dict[str, str], tracked: list[str]) -> str | None:
    """The module a manifest new in this change declares; None on any doubt.

    `added` is each gate the Makefile's change added, with its module, and
    `tracked` every file the fork had.
    """
    name = path.removeprefix(MANIFESTS).removesuffix(".json")
    if not (path.startswith(MANIFESTS) and path.endswith(".json")) or file_at(repo, fork, path) is not None:
        return None
    manifest = read_json(file_at(repo, head, path))
    if manifest is None:
        return None
    owns, gates = manifest.get("owns"), manifest.get("gates", [])
    if not (isinstance(owns, list) and owns and all(isinstance(prefix, str) for prefix in owns)):
        return None
    if any(is_under(old, tuple(owns)) for old in tracked) or not isinstance(gates, list):
        return None
    return name if all(added.get(gate) == name for gate in gates) else None


def born_packages(repo: pathlib.Path, head: str | None, born: dict[str, str]) -> dict[str, str]:
    """Each new module's Python package, by its dotted name under gameaikit.

    Only a module that owns a Python test has its package read, so a
    selection that takes it also runs Python, and `test_techniques` with it.
    """
    found = {}
    for path, name in born.items():
        owns = (read_json(file_at(repo, head, path)) or {}).get("owns", [])
        if not any(prefix.startswith(PYTHON_TESTS) for prefix in owns):
            continue
        for prefix in owns:
            if prefix.startswith(PACKAGE_ROOT) and prefix.endswith("/") and prefix.count("/") == 3:
                found[prefix[len(PACKAGE_ROOT):-1]] = name
    return found


def kit_modules(lines: list[str] | None) -> tuple[str, list[str]] | None:
    """techniques.py as syntax with `KIT_MODULES` emptied, and its names; None if unread."""
    try:
        tree = ast.parse("\n".join(lines)) if lines is not None else None
    except SyntaxError:
        return None
    for node in tree.body if tree else []:
        if isinstance(node, ast.Assign) and isinstance(node.value, ast.Tuple) \
                and [getattr(target, "id", None) for target in node.targets] == ["KIT_MODULES"]:
            names = [item.value for item in node.value.elts
                     if isinstance(item, ast.Constant) and isinstance(item.value, str)]
            if len(names) != len(node.value.elts):
                return None
            node.value.elts = []
            return ast.dump(tree), names
    return None


def packages_list(lines: list[str] | None) -> tuple[dict, list[str]] | None:
    """pyproject.toml without `packages`, and `packages` as package names; None if unread."""
    try:
        table = tomllib.loads("\n".join(lines)) if lines is not None else None
    except tomllib.TOMLDecodeError:
        return None
    packages = (table or {}).get("tool", {}).get("setuptools", {}).pop("packages", None)
    if not (isinstance(packages, list) and all(isinstance(name, str) for name in packages)):
        return None
    return table, [name.removeprefix("gameaikit.") for name in packages]


def listed_module(before: tuple | None, after: tuple | None, packages: dict[str, str]) -> str | None:
    """The one new module a list gained the packages of; None if it changed anything else."""
    if before is None or after is None or before[0] != after[0]:
        return None
    was, now = before[1], after[1]
    gained = [name for name in now if name not in was]
    # A name no new module owns comes out as the owner None: one owner too
    # many, or the only one, and either way no module is returned.
    owners = {packages.get(name) for name in gained}
    if not gained or [name for name in now if name not in gained] != was \
            or len(owners) != 1:
        return None
    return owners.pop()


def local_paths(repo: pathlib.Path, fork: str, head: str | None, paths: list[str],
                modules: dict[str, Module]) -> dict[str, str]:
    """Each global path whose whole change only added gates or a module, with what it selects.

    The Makefile selects one module when its new gates all belong to it;
    several modules, or none the reader is sure of, and it stays global. A
    manifest, new or changed, selects its own module; a library list, the
    module whose package it gained.
    """
    found: dict[str, str] = {}
    added = makefile_gates(repo, fork, head, modules) if MAKEFILE in paths else None
    if added and len(set(added.values())) == 1:
        found[MAKEFILE] = next(iter(added.values()))
    tracked = git_lines(repo, "ls-tree", "-r", "--name-only", fork)
    born = {} if tracked is None else {
        path: name for path in paths if (name := new_module(repo, fork, head, path, added or {}, tracked))}
    found.update(born)
    for path in paths:
        name = path.removeprefix(MANIFESTS).removesuffix(".json")
        if not path.startswith(MANIFESTS) or name not in modules or path in born:
            continue
        appended = manifest_gates(repo, fork, head, path, frozenset(born.values()))
        if appended is not None and all((added or {}).get(gate) == name for gate in appended):
            found[path] = name
    packages = born_packages(repo, head, born)
    for path, read in ((TECHNIQUES, kit_modules), (PYPROJECT, packages_list)):
        chosen = listed_module(read(file_at(repo, fork, path)), read(file_at(repo, head, path)), packages) \
            if path in paths else None
        if chosen is not None:
            found[path] = chosen
    return found
