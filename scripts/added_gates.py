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

  * lines added, none removed: whole new targets -- `.PHONY`, the rule,
    its recipe -- named nowhere in the old Makefile and depending only on
    names it held; a `test-...` one is a gate, and its recipe must name
    files one module owns, while any other (a `measure-` table) is in no
    gate and selects nothing; not joined to a neighbour by a `\\`, and
    with no old recipe line after them (an insertion in the middle of
    another target's recipe would take its tail);
  * a new gate attaching itself to `test-vectors` by a rule of its own,
    `test-vectors: test-x-vectors`, with no recipe (T111);
  * the `check:` or the `test-vectors:` list, the same words in the same
    order with new gates' names put in before its `##` comment, both sides
    inside that one line.

A conditional, a `define` or an `include` makes what a line means depend
on lines the hunk does not show. So the Makefile is global when one of
those lines changed, or when a hunk does not come after the last of them.
It used to be global when it had any: wave 83 gave it one, at the top, to
pick Windows' shell, and from then until T111 no Makefile change was read
by this rule at all -- the planted cases had no such line, and stayed green.

A manifest is accepted only when nothing but its `gates` changed, the old
list is the start of the new one, and every name appended is a target the
same change added for that module -- or, since T111, its prose (`about`,
`summary`) and the names of modules new in the same change added to its
`depends_on` or `tests_depend_on`. Anything else -- a removed line, a
changed recipe, a variable, an include -- is not read further: the path
stays global. A manifest that is new is `added_module.py`'s to read.

Used by `added_module.py` and so by `affected.py`, which holds the planted
cases.
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
HUNK_HEADER = re.compile(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@")
# Every word of the old Makefile, so a "new" target is truly new.
WORD = re.compile(r"[\w.-]+")
# Make's conditionals, multi-line variables and includes: a line between
# them means something the hunk alone does not show, so none is read.
DIRECTIVE = re.compile(r"^\s*-?(define|endef|ifeq|ifneq|ifdef|ifndef|else|endif|include)\b")
# A new target's rule: a plain name, prerequisites that are plain names, and
# the `## help` comment the Makefile gives every target. A `test-` name is a
# gate, which a module owns; any other (a `measure-` table, a demo) is in no
# gate, so the change is read for what it does to the gates only.
RULE = re.compile(r"^([a-z][a-z0-9-]*):(?![=:])((?:\s+[a-z0-9-]+)*)\s*(##.*)?$")
PHONY = re.compile(r"^\.PHONY:\s+([a-z][a-z0-9-]*)\s*$")
# A vector family naming itself beside its rule (T111): one prerequisite,
# no comment, no recipe -- make reads it as one more name in the list.
ATTACH = re.compile(r"^test-vectors:\s+(test-[a-z0-9-]+)\s*$")
# The lists a new gate's name may be put into, each one logical line.
LISTS = ("check:", "test-vectors:")
# What a manifest may change and still only be adding (T111): the prose a
# person reads, and the edges that may gain a module new in the same change.
PROSE_KEYS = ("about", "summary")
EDGES = ("depends_on", "tests_depend_on")
# The only variables a new recipe may use, and the paths it can name.
VARIABLES = {"$(GODOT)", "$(PYTHON)", "$(CURDIR)"}
GODOT_PATH = re.compile(r"res://([\w./-]+)")
REPO_PATH = re.compile(r"(?:\$\(CURDIR\)/|(?<![\w/.]))((?:scripts|python|spec)/[\w./-]+)")


@dataclasses.dataclass
class Hunk:
    """One `-U0` hunk: the lines it starts at in the old and new file, and its lines."""

    old_start: int
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
            hunks.append(Hunk(int(header.group(1)), int(header.group(2))))
        elif not hunks:
            continue
        elif line.startswith("-"):
            hunks[-1].removed.append(line[1:])
        elif line.startswith("+"):
            hunks[-1].added.append(line[1:])
        else:
            return None
    return hunks


@dataclasses.dataclass
class Added:
    """What one added-only hunk defines: its targets with their recipes, and
    the names it attached to `test-vectors` by a rule of their own."""

    recipes: dict[str, list[str]] = dataclasses.field(default_factory=dict)
    attached: list[str] = dataclasses.field(default_factory=list)

    def gates(self) -> dict[str, list[str]]:
        """The new `test-` targets: what a module's manifest can name."""
        return {name: recipe for name, recipe in self.recipes.items() if name.startswith("test-")}


def prerequisites_allowed(target: str, prerequisites: list[str], known: set[str]) -> bool:
    """True when a new rule depends only on old names, and a new gate only on gates or `import`."""
    if not set(prerequisites) <= known:
        return False
    return not target.startswith("test-") or all(
        name == "import" or name.startswith("test-") for name in prerequisites)


def new_targets(hunk: Hunk, new_lines: list[str], known: set[str]) -> Added | None:
    """The targets an added-only hunk defines; None if it does anything else.

    `known` is every word of the old Makefile: a name already used there --
    as a rule, a prerequisite, one of several targets -- is not new, and a
    new rule may depend only on names it held. A new gate may depend only on
    `import` and old `test-` targets, as every gate does (wave 123's
    review): an old `wave-merge` or `solve-maze` would merge a pull request
    or rewrite another module's files inside the gate. A recipe line before any rule in the hunk
    belongs to an old target, and one after an attaching rule would be a
    second recipe for `test-vectors`: both are refused. And the hunk must
    not run into its neighbours: no `\\` on its last line or on the line
    before it, and no old recipe line after it -- make skips blank and
    comment lines inside a recipe, so the search does too.
    """
    before = new_lines[hunk.new_start - 2] if hunk.new_start >= 2 else ""
    if hunk.removed or before.endswith("\\") or (hunk.added and hunk.added[-1].endswith("\\")):
        return None
    found, current = Added(), None
    for line in hunk.added:
        attach, rule, phony = ATTACH.match(line), RULE.match(line), PHONY.match(line)
        if line.startswith("\t") and current is not None:
            found.recipes[current].append(line)
        elif attach:
            found.attached.append(attach.group(1))
            current = None
        elif rule and rule.group(1) not in known | set(found.recipes) \
                and prerequisites_allowed(rule.group(1), rule.group(2).split(), known):
            current = rule.group(1)
            found.recipes[current] = []
        elif not (line.strip() == "" or (phony and phony.group(1) not in known)):
            return None
    after = hunk.new_start - 1 + len(hunk.added)
    following = next((line for line in new_lines[after:]
                      if line.strip() and not line.strip().startswith("#")), "")
    if not (found.recipes or found.attached) or following.startswith("\t"):
        return None
    return found


def path_owner(path: str, modules: dict[str, Module]) -> str | None:
    """The module owning a path a recipe names, a file or a folder; None on doubt.

    A folder is named without its slash -- every vector gate hands Godot
    `$(CURDIR)/spec/vectors/<family>` -- and is read as everything inside
    it: the module owning it whole, and None when any other module claims a
    prefix inside it.
    """
    owner = owner_of(path, modules)
    if owner is not None:
        return owner
    owner = owner_of(f"{path}/", modules)
    inside = {module.name for module in modules.values()
              for prefix in module.owns if prefix.startswith(f"{path}/")}
    return owner if inside <= {owner} else None


def recipe_owner(recipe: list[str], modules: dict[str, Module]) -> str | None:
    """The one module owning every file a recipe names; None on any doubt."""
    text = "\n".join(recipe)
    if set(re.findall(r"\$\([^)]*\)", text)) - VARIABLES:
        return None
    paths = [f"godot/{found}" for found in GODOT_PATH.findall(text)] + REPO_PATH.findall(text)
    owners = {path_owner(path, modules) for path in paths}
    # A `..` climbs out of the folder that names the owner (wave 123's review).
    if not paths or len(owners) != 1 or any(is_global(path, modules) or ".." in path for path in paths):
        return None
    return owners.pop()


def logical_start(lines: list[str], index: int) -> int:
    """The first physical line of the logical Makefile line holding `index`."""
    while index > 0 and lines[index - 1].endswith("\\"):
        index -= 1
    return index


def inside_list(lines: list[str], first: int, count: int) -> str | None:
    """Which of LISTS lines `first` to `first + count - 1` all lie in; None if not one."""
    if first < 0 or count == 0:
        return None
    starts = {logical_start(lines, first + offset) for offset in range(count)}
    start = lines[starts.pop()] if len(starts) == 1 else ""
    return next((name for name in LISTS if start.startswith(name)), None)


def check_list_names(hunk: Hunk, old_lines: list[str], new_lines: list[str]) -> list[str] | None:
    """The names a hunk put into `check:` or `test-vectors:`; None if it did anything else.

    Both sides of the hunk must lie inside the same one of those lines,
    before and after, so a neighbouring line cannot be joined into it and
    lost, nor a name moved from one list to the other; the
    words must be the old ones in order with names put in; and every name
    must come before the `## help` comment, where it would be prose.
    """
    was = inside_list(old_lines, hunk.old_start - 1, len(hunk.removed))
    if was is None or inside_list(new_lines, hunk.new_start - 1, len(hunk.added)) != was:
        return None
    old_words = " ".join(hunk.removed).split()
    new_words = " ".join(hunk.added).split()
    put_in = [word for word in new_words if word not in old_words]
    comment = next((index for index, word in enumerate(new_words) if word.startswith("#")), len(new_words))
    if not put_in or [word for word in new_words if word not in put_in] != old_words \
            or any(new_words.index(word) > comment for word in put_in):
        return None
    return put_in


def after_directives(old: list[str], new: list[str], hunks: list[Hunk]) -> bool:
    """True when every hunk comes after the last directive line, before and after.

    So no directive line changed either: a hunk that touched one would
    start at or above it. A hunk that only adds lines starts at the old line
    it follows, so one placed right after the last directive is refused
    too: a doubt.
    """
    def last(lines: list[str]) -> int:
        return max((index + 1 for index, line in enumerate(lines) if DIRECTIVE.match(line)), default=0)

    return all(hunk.old_start > last(old) and hunk.new_start > last(new) for hunk in hunks)


def makefile_gates(repo: pathlib.Path, fork: str, head: str | None,
                   modules: dict[str, Module]) -> dict[str, str] | None:
    """Each gate the Makefile's change added, with its module; None unless that is all.

    Every hunk must be new targets or names put into a list, every new gate
    must have one owning module, and every name put into a list -- or
    attached to `test-vectors` by its own rule -- must be a gate this same
    change added. A new target that is not a gate needs no owner: no gate
    runs it, and a gate cannot depend on it.
    """
    old = file_at(repo, fork, MAKEFILE)
    new = file_at(repo, head, MAKEFILE)
    ends = [fork] if head is None else [fork, head]
    hunks = parse_hunks(git_lines(repo, "diff", "-U0", "--no-renames", *ends, "--", MAKEFILE) or [])
    if old is None or new is None or not hunks or not after_directives(old, new, hunks):
        return None
    known = set(WORD.findall("\n".join(old)))
    added, listed = {}, []
    for hunk in hunks:
        targets, names = new_targets(hunk, new, known), check_list_names(hunk, old, new)
        if targets is None and names is None:
            return None
        added.update(targets.gates() if targets else {})
        listed += (targets.attached if targets else []) + (names or [])
    owners = {name: recipe_owner(recipe, modules) for name, recipe in added.items()}
    if None in owners.values() or not set(listed) <= set(owners):
        return None
    return owners


def read_json(lines: list[str] | None) -> dict | None:
    """A manifest's object, or None when it is absent or not a JSON object."""
    try:
        found = json.loads("\n".join(lines)) if lines is not None else None
    except ValueError:
        return None
    return found if isinstance(found, dict) else None


def manifest_gates(repo: pathlib.Path, fork: str, head: str | None, path: str,
                   born: frozenset[str] = frozenset()) -> list[str] | None:
    """The gate names a manifest's change appended; None if it changed anything else.

    Its prose may change too, and its edges may gain modules `born` in this
    same change -- the old list, in its order, once those names are taken
    out. A new module is selected anyway, so a new edge to it takes nothing
    away from what runs.
    """
    before, after = read_json(file_at(repo, fork, path)), read_json(file_at(repo, head, path))
    if before is None or after is None:
        return None
    for key in PROSE_KEYS:
        before.pop(key, None)
        after.pop(key, None)
    for key in EDGES:
        was, now = before.pop(key, []), after.pop(key, [])
        if not isinstance(now, list) or [name for name in now if name not in born] != was:
            return None
    old_gates, new_gates_list = before.pop("gates", []), after.pop("gates", [])
    if before != after or new_gates_list[:len(old_gates)] != old_gates:
        return None
    return new_gates_list[len(old_gates):]
