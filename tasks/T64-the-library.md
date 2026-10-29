# T64 — The library: a Python package and Godot addons others can install

Size: L · Prereqs: T60, T61, T62, T63 · Files: `python/pyproject.toml`, `godot/addons/*/`, `scripts/release.py` (or its equivalent), `modules/`, `docs/adr/`

## Goal

The last part of the owner's request of 2026-10-20: the techniques usable by
others, as a Python package and as Godot addons, generic and customisable.
T58's "The library, later" is the plan this task carries out; the ports of
T60-T62 come first because a published name is a promise, and these names
were about to change.

## The decision first -- taken by the owner

**Names.** `class_name` registers a class project-wide, and GDScript 4.7 has
no namespaces (godot-proposals #1566, open since 2020; its opening post is
the plugin case). `Unit`, `Move`, `Search`, `Hearing` will collide in
someone's game. The choice trades against invariant 1:

- **a prefix on everything** (`GakAStarSearch`) -- safe, and every reader
  pays for it on every line;
- **the generic names kept**, and the release's README saying so;
- **recommended (T58): prefix only the ports and the kernel**, the names
  most likely to collide (`GridGraph`, `Pathfinder`, `SearchGraph`,
  `AdversarialGame`, ...), and keep the algorithms' names readable
  (`AStarSearch`, `StripsPlanner`).

**Decided by the owner, 2026-10-20: the recommendation** -- prefix only the
ports and the kernel, the algorithms keep their readable names. The prefix
itself is chosen in the ADR that opens this task (before step 1), by what
the Asset Library and PyPI already hold under it.

**Still open, from T101 (wave 103):** where `AimChoice` lives. It stayed
in `ai_teamwork` when utility choice became `ai_utility`, but nothing in it
is about a team -- it is one shooter's hit model. A shooting or combat
addon, or this task's naming pass, is the owner's to choose before the
library ships `ai_teamwork`'s final shape.

## Steps

1. **The names**, as decided, in one commit per addon, with the import and
   the `.uid` files.
2. **Godot release by manifest.** Each technique's zip holds its addon
   folder, LICENSE and NOTICE (ADR 0009, `check_license.py`) and nothing
   else: no tests, no game paths, no published weights of a game. The
   builder reads `modules/<name>.json` to know what is the addon's; a
   planted case (a test file inside the addon folder) is refused. The
   Asset Library layout (`addons/<name>/`, a LICENSE at the root,
   `.gitattributes` `export-ignore`) checked against Godot's *Submitting to
   the Asset Library* for 4.7, read again on the day.
3. **Python package.** `python/pyproject.toml` with PEP 621's `[project]`
   table, the **flat** layout kept (PyPA: the src layout requires installing
   the project to run its code, and the stdlib `unittest` with no install
   step is a tier-1 promise); no `dependencies`. A build backend is named
   and pinned; `python -m build` runs in the release, not in a wave.
4. **A user's own technique plugs in** through an entry-point group,
   `gameaikit.techniques` (PyPA, *Creating and discovering plugins*), read
   by a registry that the kit's own techniques fill with a decorator
   (*Fluent Python*, 2nd ed., ch. 10's `promotion` decorator). Not namespace
   packages: they need every distribution to omit `__init__.py`, which fights
   `python/tests`' own trap.
5. **An example outside the repository**, as `make library-check`: a
   throwaway directory outside the tree, a fresh virtual environment that
   installs the wheel and imports one technique, and a blank Godot project
   that unzips one addon and runs one test of it. Either failing exits
   non-zero; a planted case (an addon zip missing a file its scripts
   `preload`) must fail it.
6. **The Python ports, by *Fluent Python***, where the package's public
   surface needs them and no further: a port a user implements is a
   `typing.Protocol` (ch. 13), a heuristic or utility a plain `Callable`
   (ch. 10), a value handed back to the user a frozen dataclass (ch. 5).
   Today's internals are not rewritten to match.
7. **ADR 0009 revisited**: what is published where, by whom, and what stays
   out (publishing itself to PyPI or the Asset Store is the owner's act, not
   this task's).

## Acceptance

```bash
make check
```

```bash
make release
```

The wheel and one addon, installed and run outside the repository (step 5):

```bash
make library-check
```

## Manual check

The owner reads one addon's zip and one wheel as a stranger would, and says
whether either needs this repository to make sense.

## Out of scope

- Uploading to PyPI or the Asset Store.
- A C# or GDExtension port.
- Tests shipped inside the addons.
