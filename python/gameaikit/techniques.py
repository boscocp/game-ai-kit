"""Every technique the kit offers, and every one a user's package adds.

The kit's own techniques are listed here by a decorator on the object a
user calls first -- `MonteCarloSearch`, `read_fcl`, `choose` -- the way
*Fluent Python* (2nd ed., ch. 10) fills its `promos` list with a
`@promotion` decorator: the list cannot forget a technique, because the
technique writes itself into it where it is defined.

A user's own technique plugs in without touching this package, through the
entry-point group `gameaikit.techniques` (PyPA, *Creating and discovering
plugins*). Their `pyproject.toml` says:

    [project.entry-points."gameaikit.techniques"]
    my-search = "my_package.search:MySearch"

and `available()` lists it beside the kit's. Not namespace packages: they
need every distribution to leave out `__init__.py`, and `python/tests`
needs its own (CLAUDE.md, "A test runner that finds nothing").

    from gameaikit import techniques
    for name, found in techniques.available().items():
        print(name, "--", found.about)
"""

from __future__ import annotations

import dataclasses
import importlib
from collections.abc import Callable
from importlib import metadata
from typing import Any, TypeVar

GROUP = "gameaikit.techniques"

#: The kit's modules whose import fills `KIT`. Only techniques: the
#: examples' packages (`checkers`, `maze`, ...) are games, not the library.
#: `training` is named by its module, for it has no `__init__.py` to
#: import the rest.
KIT_MODULES = (
    "adversarial", "fuzzy", "llm", "ngram", "pddl", "perception",
    "search", "steering", "teamwork", "training.descent", "utility",
)

Entry = TypeVar("Entry", bound=Callable[..., Any])


@dataclasses.dataclass(frozen=True)
class Technique:
    """One technique: its name, a line on what it decides, and what to call.

    Frozen, because it is handed to the user and a registry whose entries
    can be changed by whoever reads them is not one (*Fluent Python*, ch. 5).
    `source` is "gameaikit" for the kit's own, else the distribution that
    declared the entry point.
    """

    name: str
    about: str
    entry: Callable[..., Any]
    source: str = "gameaikit"


#: The kit's own, by name, filled as each package is imported.
KIT: dict[str, Technique] = {}


def technique(name: str, about: str) -> Callable[[Entry], Entry]:
    """Register the decorated class or function as the kit's technique `name`.

    Returns the object unchanged, so decorating changes nothing a caller
    sees. Two techniques under one name is a mistake in the kit, refused at
    import rather than one silently replacing the other.
    """
    def register(entry: Entry) -> Entry:
        if name in KIT and KIT[name].entry is not entry:
            raise ValueError(f"two techniques are named {name!r}")
        KIT[name] = Technique(name, about, entry)
        return entry
    return register


def kit() -> dict[str, Technique]:
    """The kit's own techniques, after importing every module that defines one."""
    for module in KIT_MODULES:
        importlib.import_module(f"gameaikit.{module}")
    return dict(KIT)


def plugged_in(entry_points: list[metadata.EntryPoint] | None = None) -> dict[str, Technique]:
    """The techniques other installed distributions declare, by name.

    `entry_points` is for a test to hand in its own; left out, the
    installed distributions are read. An entry point that loads a
    `Technique` keeps it; anything else callable is wrapped, its docstring's
    first line taken as what it decides.
    """
    found = metadata.entry_points(group=GROUP) if entry_points is None else entry_points
    plugged: dict[str, Technique] = {}
    for point in found:
        loaded = point.load()
        source = point.dist.name if point.dist is not None else "unknown"
        if isinstance(loaded, Technique):
            plugged[point.name] = dataclasses.replace(loaded, source=source)
        else:
            plugged[point.name] = Technique(point.name, _first_line(loaded), loaded, source)
    return plugged


def available(entry_points: list[metadata.EntryPoint] | None = None) -> dict[str, Technique]:
    """Every technique: the kit's and the plugged-in ones, sorted by name.

    A plug-in may not take a name the kit already uses: it would hide the
    kit's technique from every caller in the process, so it is refused.
    """
    every = kit()
    for name, plugged in plugged_in(entry_points).items():
        if name in every:
            raise ValueError(f"{plugged.source} declares {name!r}, which the kit already names")
        every[name] = plugged
    return dict(sorted(every.items()))


def _first_line(entry: object) -> str:
    """The first line of `entry`'s docstring, or "" when it has none."""
    lines = (entry.__doc__ or "").strip().splitlines()
    return lines[0] if lines else ""
