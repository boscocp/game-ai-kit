"""Read a change to the Makefile or a manifest: did it only add a gate?

What it does
------------
T71. `affected.py` treats the Makefile and `modules/*.json` as global, and
rightly: every gate stands on them. But adding a gate touches both -- a new
target, its name in `check:`, its name in a module's `gates` -- and wave 75
ran all of `make check`, about nine minutes, for one racing gate. This reads
the diff of those two files, not only their paths, and says when the whole
change to one of them is gates added to one module.

What counts as only adding a gate
---------------------------------
Any doubt is global. A Makefile hunk is accepted only when it is one of:

  * lines added, none removed: whole new `test-...` targets -- `.PHONY`,
    the rule, its recipe -- whose recipe names files one module owns, and
    the first line after them is not a recipe line (an insertion in the
    middle of another target's recipe would take its tail);
  * the `check:` list, the same words in the same order with new targets'
    names put in.

A manifest is accepted only when nothing but its `gates` changed, the old
list is the start of the new one, and every name appended is a target the
same change added for that module. Anything else -- a removed line, a
changed recipe, a variable, an include, a manifest that is new -- is not
read further: the path stays global.

Used by `affected.py`, which holds the planted cases.
"""

from __future__ import annotations

import dataclasses
import json
import pathlib
import re
import subprocess

from check_modules import Module, is_global, owner_of

MAKEFILE = "Makefile"
MANIFESTS = "modules/"
HUNK_HEADER = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")
# Any rule of the old Makefile, so a "new" target is truly new.
ANY_RULE = re.compile(r"^([^\s:#=$]+):(?!=)")
# A gate's rule: a `test-` name, prerequisites that are plain names, and
# the `## help` comment the Makefile gives every target.
RULE = re.compile(r"^(test-[a-z0-9-]+):(?![=:])((?:\s+[a-z0-9-]+)*)\s*(##.*)?$")
PHONY = re.compile(r"^\.PHONY:\s+(test-[a-z0-9-]+)\s*$")
# The only variables a new recipe may use, and the paths it can name.
VARIABLES = {"$(GODOT)", "$(PYTHON)", "$(CURDIR)"}
GODOT_PATH = re.compile(r"res://([\w./-]+)")
REPO_PATH = re.compile(r"(?:\$\(CURDIR\)/|(?<![\w/.]))((?:scripts|python|spec)/[\w./-]+)")


@dataclasses.dataclass
class Hunk:
    """One `-U0` hunk: the line it starts at in the new file, and its lines."""

    new_start: int
    removed: list[str] = dataclasses.field(default_factory=list)
    added: list[str] = dataclasses.field(default_factory=list)


def git_lines(repo: pathlib.Path, *args: str) -> list[str] | None:
    """git's output as lines, or None when git could not answer."""
    done = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    return done.stdout.splitlines() if done.returncode == 0 else None


def file_at(repo: pathlib.Path, commit: str | None, path: str) -> list[str] | None:
    """`path`'s lines at `commit`, or on disk when it is None; None if absent."""
    if commit is not None:
        return git_lines(repo, "show", f"{commit}:{path}")
    on_disk = repo / path
    return on_disk.read_text(encoding="utf-8").splitlines() if on_disk.is_file() else None


def parse_hunks(diff: list[str]) -> list[Hunk] | None:
    """The hunks of a `-U0` diff of one file; None on anything unexpected.

    The lines before the first hunk are git's header (`diff --git`, `---`,
    `+++`) and are skipped. After it, a line that is neither a header, a
    removal nor an addition -- "No newline at end of file" -- is a doubt.
    """
    hunks: list[Hunk] = []
    for line in diff:
        header = HUNK_HEADER.match(line)
        if header:
            hunks.append(Hunk(int(header.group(1))))
        elif not hunks:
            continue
        elif line.startswith("-"):
            hunks[-1].removed.append(line[1:])
        elif line.startswith("+"):
            hunks[-1].added.append(line[1:])
        else:
            return None
    return hunks


def new_gates(hunk: Hunk, new_lines: list[str], known: set[str]) -> dict[str, list[str]] | None:
    """The targets an added-only hunk defines, with their recipes; None if not only that.

    `known` is every target the old Makefile had: a rule for one of those is
    a change to it, not an addition. A recipe line before any rule in the
    hunk belongs to an old target, so it is refused like any other line.
    """
    gates: dict[str, list[str]] = {}
    current = None
    for line in hunk.added:
        rule, phony = RULE.match(line), PHONY.match(line)
        if line.startswith("\t") and current is not None:
            gates[current].append(line)
        elif rule and rule.group(1) not in known and rule.group(1) not in gates:
            current = rule.group(1)
            gates[current] = []
        elif not (line.strip() == "" or (phony and phony.group(1) not in known)):
            return None
    after = hunk.new_start - 1 + len(hunk.added)
    following = next((line for line in new_lines[after:] if line.strip()), "")
    if hunk.removed or not gates or following.startswith("\t"):
        return None
    return gates


def recipe_owner(recipe: list[str], modules: dict[str, Module]) -> str | None:
    """The one module owning every file a recipe names; None on any doubt."""
    text = "\n".join(recipe)
    if set(re.findall(r"\$\([^)]*\)", text)) - VARIABLES:
        return None
    paths = [f"godot/{found}" for found in GODOT_PATH.findall(text)] + REPO_PATH.findall(text)
    owners = {owner_of(path, modules) for path in paths}
    if not paths or len(owners) != 1 or any(is_global(path, modules) for path in paths):
        return None
    return owners.pop()


def logical_start(lines: list[str], index: int) -> int:
    """The first physical line of the logical Makefile line holding `index`."""
    while index > 0 and lines[index - 1].endswith("\\"):
        index -= 1
    return index


def check_list_names(hunk: Hunk, new_lines: list[str]) -> list[str] | None:
    """The names a hunk put into the `check:` list; None if it did anything else."""
    first = hunk.new_start - 1
    if not hunk.removed or not hunk.added or first < 0:
        return None
    starts = {logical_start(new_lines, first + offset) for offset in range(len(hunk.added))}
    if len(starts) != 1 or not new_lines[starts.pop()].startswith("check:"):
        return None
    old_words = " ".join(hunk.removed).split()
    new_words = " ".join(hunk.added).split()
    put_in = [word for word in new_words if word not in old_words]
    if not put_in or [word for word in new_words if word not in put_in] != old_words:
        return None
    return put_in


def makefile_gates(repo: pathlib.Path, fork: str, head: str | None,
                   modules: dict[str, Module]) -> dict[str, str] | None:
    """Each gate the Makefile's change added, with its module; None unless that is all.

    Every hunk must be new gates or names put into `check:`, every new gate
    must have one owning module, and every name put into `check:` must be a
    gate this same change added.
    """
    old = file_at(repo, fork, MAKEFILE)
    new = file_at(repo, head, MAKEFILE)
    ends = [fork] if head is None else [fork, head]
    hunks = parse_hunks(git_lines(repo, "diff", "-U0", "--no-renames", *ends, "--", MAKEFILE) or [])
    if old is None or new is None or not hunks:
        return None
    known = {match.group(1) for match in map(ANY_RULE.match, old) if match}
    added, listed = {}, []
    for hunk in hunks:
        gates, names = new_gates(hunk, new, known), check_list_names(hunk, new)
        if gates is None and names is None:
            return None
        added.update(gates or {})
        listed += names or []
    owners = {name: recipe_owner(recipe, modules) for name, recipe in added.items()}
    if None in owners.values() or not set(listed) <= set(owners):
        return None
    return owners


def manifest_gates(repo: pathlib.Path, fork: str, head: str | None, path: str) -> list[str] | None:
    """The gate names a manifest's change appended; None if it changed anything else."""
    old, new = file_at(repo, fork, path), file_at(repo, head, path)
    if old is None or new is None:
        return None
    try:
        before, after = json.loads("\n".join(old)), json.loads("\n".join(new))
    except ValueError:
        return None
    old_gates, new_gates_list = before.pop("gates", []), after.pop("gates", [])
    if before != after or new_gates_list[:len(old_gates)] != old_gates:
        return None
    return new_gates_list[len(old_gates):] or None


def local_paths(repo: pathlib.Path, fork: str, head: str | None, paths: list[str],
                modules: dict[str, Module]) -> dict[str, str]:
    """Each global path whose whole change only added gates, with the module it selects.

    A manifest selects its own module when every name it appended is a gate
    the Makefile's change added for that module. The Makefile selects one
    module when its new gates all belong to it; several modules, or none
    the reader is sure of, and it stays global.
    """
    found: dict[str, str] = {}
    added = makefile_gates(repo, fork, head, modules) if MAKEFILE in paths else None
    if added and len(set(added.values())) == 1:
        found[MAKEFILE] = next(iter(added.values()))
    for path in paths:
        name = path.removeprefix(MANIFESTS).removesuffix(".json")
        if not path.startswith(MANIFESTS) or name not in modules:
            continue
        appended = manifest_gates(repo, fork, head, path)
        if appended and added and all(added.get(gate) == name for gate in appended):
            found[path] = name
    return found
