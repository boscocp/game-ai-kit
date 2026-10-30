# 0024 — The library prefixes its ports with `Gak`, and ships only techniques

Status: accepted · 2026-10-30 (T64, wave 112; the owner's decisions of 2026-10-20 and 2026-10-30)

## Context

T64 makes the kit something others install: a zip per Godot addon, a
Python wheel. `class_name` registers a class for the whole project, and
GDScript 4.7 has no namespaces (godot-proposals #1566, open since 2020,
whose opening post is the plugin case: "Unique global class ... already
exists"). A user's game that already has a `Search` or a `Pathfinder` stops
parsing the moment one of these addons is unzipped beside it.

The owner decided on 2026-10-20 to prefix only the ports and the kernel --
the names a user's own code writes, and the most likely to collide -- and to
keep the algorithms' names readable, because a prefix on every line is paid
by every reader (invariant 1).

## Decision

**The prefix is `Gak`** (game-ai-kit), chosen on 2026-10-30 after looking
on the day: the Godot Asset Library's search returned nothing for `gak` or
`game ai kit`; on PyPI `gameaikit` was free and `gak` taken, which does not
matter, since Python has modules and needs no prefix.

**Prefixed are the nine classes a user extends or hands in**, measured as
the ones this repository itself extends or implements:

| was | now | addon |
|---|---|---|
| `GridGraph` | `GakGridGraph` | `ai_core` |
| `Pathfinder` | `GakPathfinder` | `ai_core` |
| `SearchGraph` | `GakSearchGraph` | `ai_search` |
| `Search` | `GakSearch` | `ai_search` |
| `AdversarialGame` | `GakAdversarialGame` | `ai_adversarial` |
| `GameDomain` | `GakGameDomain` | `ai_planning` |
| `LlmRuntime` | `GakLlmRuntime` | `ai_llm` |
| `SteeringBehaviour` | `GakSteeringBehaviour` | `ai_steering` |
| `RtsController` | `GakRtsController` | `ai_rts_core` |

Every other name -- `AStarSearch`, `StripsPlanner`, `Hearing` -- stays, and
the release's README says what to do on a collision with one of those: the
user renames the addon's `class_name` line and its uses inside that one
addon folder, a search-and-replace that touches nothing of theirs. File
names do not change.

**`AimChoice` moves to `ai_utility`** (the owner, 2026-10-30): it is one
shooter's choice by expected worth, the same kind of thing as
`ActionChoice` and `ErrandChoice`, and nothing in it is about a team.

**What ships is the techniques.** An addon zip holds the files its manifest
(`modules/<name>.json`) owns under `godot/addons/<name>/`, plus LICENSE,
NOTICE and VERSION; a test file inside the addon folder is refused, not
dropped. The wheel holds the Python packages owned by modules of kind
`technique`, not the examples' (`checkers`, `maze`, `tactical`, ...),
which are the kit's games, not its library.

**The Python names stay.** A wheel installs `gameaikit.search`; Python's
modules are the namespace GDScript lacks.

## Alternatives

- **A prefix on everything.** Safe, and every reader pays on every line.
  Rejected by the owner on 2026-10-20.
- **No prefix, the README warns.** Cheapest, and the first collision is the
  user's to find, in a parse error naming a class they never wrote.
- **`Gaik` or `AiKit`.** Offered to the owner on 2026-10-30; `Gak` taken as
  the shortest that reads as this kit's.

## Consequences

- A user's subclass reads `extends GakSearch`, and the algorithms they
  instantiate read as the book does: `AStarSearch.new()`.
- The prefixed names are a promise: renaming one after a release breaks
  every game that extends it.
- A tenth port added later must be prefixed in the wave that adds it. No
  gate holds that yet: `check_readability.py` does not know which classes
  are ports.
