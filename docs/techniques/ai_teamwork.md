# ai_teamwork — a team that shares the work

<!-- doc-meta
half_life: practice
verified_on: 2026-10-29
tier: 2
source: https://www.gameaipro.com/
invalidated_if: the kit's RoleArbiter, TeamCommander, TacticalPositions, SquadConfidence or SearchCoordinator signatures change, or the demos that use them are renamed
teaches: shooter-ai
-->

> Português: [ai_teamwork.pt-BR.md](ai_teamwork.pt-BR.md). The words that
> stay in English are in the [glossary](glossary.pt-BR.md).

## What it decides {#what}

How a team shares the work, each part a weighing of its own:
`TeamCommander` sends squads to objectives, `TacticalPositions` picks where
a bot stands and keeps two from claiming one spot, `RoleArbiter` lets one
bot flank while the others shoot, `SearchCoordinator` splits the places to
search, `SquadConfidence` says when to attack, hold or retreat, and
`AimChoice` and `PassageChoice` weigh where to aim and how to get past a
body in the way -- wait, go round, ask a teammate to step aside, or take
another spot. Each keeps its numbers, so a view can show why. What one bot does
now, and the errands it leaves its post for, are not here: since T101 they
are [`ai_utility`](ai_utility.md), for nothing in them is about a team. The
sources: the *Game AI Pro* chapters each class names.

## When not to use it {#when-not}

One squad, or one place to stand: nearest-first is the same answer with
less to explain. Roles that are places, not jobs -- who holds which door:
that is `TacticalPositions` with claims, not `RoleArbiter`. And a team whose
members must act in a fixed order, a breach then a sweep: that is a plan's
(`ai_planning`), not a weighing each bot makes again every decision.

## Where to watch it {#watch}

- `make demo-botmatch` -- six against six. **Tab** watches the next bot:
  the discs round it are every spot it weighed, with its score. **1-3**
  switch blue's claims, commander and retreat (**shift** for red's), so you
  can watch the team with each part off. **T** takes the watched bot over.
- `make demo-infiltration` -- the guards search with `SearchCoordinator`
  and fight under `RoleArbiter`; **2** and **3** switch the coordinator and
  the arbiter, **Tab** watches the next guard.
- Which demo uses which technique, both ways: the
  [catalogue](catalogue.md).

## In this kit {#in-this-kit}

`godot/game3d/botmatch/team_tactics.gd` runs the commander and the squads'
confidence for each team, and asks `TacticalPositions` where each bot stands.
The infiltration guards share their search through
`godot/game3d/infiltration/guard_team.gd`. The knobs that matter:

| knob | where | what it changes |
|---|---|---|
| flankers | `RoleArbiter.grant(requests, use_arbiter, max_flankers)` | how many may go round at once; someone always shoots |
| claims | `TacticalPositions.choose(...)` | whether a spot another bot took is dropped |
| the commander | `TeamCommander.assign(squads, objectives, weights)` | which objective each squad is sent to, and how many fill one |
| retreat | `SquadConfidence.Thresholds` | when a squad attacks, holds or falls back, and the gap that stops it flickering |

## In your own project {#your-project}

### What to copy {#copy}

One folder: `godot/addons/ai_teamwork/`. It needs nothing else, not even
`ai_core`. Open the project once, or run `godot --headless --import`, so
Godot registers its classes. Every class reads plain numbers your game
measured -- distances, line of fire already cast -- so none needs your
scene.

### A minimal example {#example}

A squad of yours sharing out one fight. Three fighters ask to flank and one
to shoot: the arbiter grants the best flank and the others shoot; and when
the only one who can shoot asks to flank, it is kept shooting. This file is
run by `squad_example_test.gd`, and the gate holds the page equal to it.

<!-- example: godot/test/ai_teamwork/squad_example.gd -->
```gdscript
# The minimal example on docs/techniques/ai_teamwork.md, run by
# squad_example_test.gd. A squad of your own that shares one fight out:
# each fighter asks for a role, and an arbiter grants one flank at a time
# so the others keep shooting -- teamwork as a referee, not a plan.
extends Node

## At most this many go round at once.
const MAX_FLANKERS: int = 1


## The role each fighter gets, by name -- "shooter", "flanker" or "none".
## `fighters` is [{name, wants_to_flank, flank_score, can_shoot}], each a
## fact your game measured: whether a way round is open, how good it is,
## whether the fighter has a line and rounds.
func roles(fighters: Array[Dictionary]) -> Dictionary:
	var requests: Array[Dictionary] = []
	for fighter: Dictionary in fighters:
		requests.append({
			"role": RoleArbiter.FLANKER if fighter["wants_to_flank"] else RoleArbiter.SHOOTER,
			"score": fighter["flank_score"],
			"can_shoot": fighter["can_shoot"],
		})
	var granted: PackedStringArray = RoleArbiter.grant(requests, true, MAX_FLANKERS)
	var by_name: Dictionary = {}
	for index: int in range(fighters.size()):
		by_name[fighters[index]["name"]] = granted[index]
	return by_name
```

### What you implement {#implement}

Who asks for what: the requests are yours -- whether a way round is open
and how good it is, whether a fighter has a line and rounds -- and the
roles that come back are yours to act on. The other classes take the same
kind of input -- `Candidate`, `Objective`, `SquadReport` are inner classes
you fill with numbers -- and are worth reading in the order the bot match
uses them.

## Deeper {#deeper}

- How shooter AI is made: one bot, a team, a search:
  [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- The bot match, every knob and key: [godot/botmatch.md](../godot/botmatch.md).
- What one bot does now, by utility: [ai_utility.md](ai_utility.md).
