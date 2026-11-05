# 0024 — The library prefixes its ports with `Gak`, and ships only techniques

Status: accepted, amended · 2026-10-30 (T64, wave 112; the owner's decisions of 2026-10-20 and 2026-10-30; amended on the owner's decision of 2026-11-05 -- see the amendment at the end)

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

**Prefixed are the nine classes a user's code names as a type** -- the
ports a game extends or implements (`GakPathfinder`, `GakSearch`,
`GakAdversarialGame`, ...), the kernel's grid it hands in, and
`GakGameDomain`, the planning domain a reader copies to write their own --
the owner's list of 2026-10-30, which is not "every class this repository
extends": nothing extends `GakGridGraph`, and `GakGameDomain` is a
concrete sample with static functions:

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
NOTICE, VERSION and a README written from the manifest's `summary` -- a
line for a stranger, where `about` is for this repository's reader; a
gdUnit4 suite inside the addon folder is refused, not dropped.

**"Runs one test of it", outside the repository, is a script, not a
suite.** Tests do not ship and a blank project has no gdUnit4, so `make
library-check` runs `scripts/library/stranger.gd` there: the route the
`ai_search` page shows, required to print its marker as well as to exit 0. The wheel holds the Python packages owned by modules of kind
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

## Pending (T109, wave 122) -- answered on 2026-11-05

ADR 0021's amendment of 2026-10-29 puts a seeded generator, `Xorshift`, in
the kernel. Two of its consequences touch this record and wait on the
owner: the wheel now ships `gameaikit.core`, the kernel's package, which
the techniques import; and `Xorshift` is a kernel class without the
prefix. See "Pending the owner" at the end of ADR 0021. The owner answered
both on 2026-11-05; see the amendment below.

## Amended (2026-11-05): what 0.1.0 promises, and the kernel in the wheel

**What was decided.** On 2026-11-05 the owner answered the numbered lists
in `tasks/STATUS.md` with "todas conforme recomendado": each item as its
recommendation said. Three items touch this record (items 2, 6 and 7 of
the list of 2026-11-04).

**0.1.0 promises only the nine `Gak` names** (item 2). The names in the
table above are the promise in "Consequences": renaming one after a
release breaks every game that extends it. Every other name -- a class, a
method, a Python function -- may change below 1.0. The guide
(`docs/techniques/using-the-library.md`, T77) said so first; this record
now says it too.

**The wheel ships `gameaikit.core`** (item 7). This amends "What ships is
the techniques", and the title's "ships only techniques", for the
wheel: it holds the packages of modules of kind `technique`, and the
kernel's package, `gameaikit.core`. That is not a choice while the code
stands as it is: the shipped `gameaikit.adversarial`, `bandit` and
`perception` import `gameaikit.core` (ADR 0021's amendment of 2026-10-29),
and a wheel without it would not import. The examples' packages still do
not ship. `scripts/release.py` has accepted the kernel's package since
T109.

**`Xorshift` becomes `GakXorshift`** (item 6), before anything is
published. That is task T120, not done by this amendment. When it lands,
its wave adds the row to the table above. Whether the promise of 0.1.0
then covers ten names, not nine, was not part of the answer: T120 asks.

**What does not follow from it.** Nothing else is prefixed, and nothing
else enters the wheel, on the strength of this amendment.
