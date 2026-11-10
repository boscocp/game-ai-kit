# ai_teamwork — a team that shares the work

<!-- doc-meta
half_life: practice
verified_on: 2026-11-10
tier: 2
source: https://www.gameaipro.com/
invalidated_if: the kit's RoleArbiter, TeamCommander, TacticalPositions, SquadConfidence, SearchCoordinator or AttackTokens signatures change, or the demos that use them are renamed
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
`PassageChoice` weighs how to get past a body in the way -- wait, go round, ask a teammate to step aside, or take
another spot. And `AttackTokens` lets one or two of a group strike a target
at a time while the rest wait their turn (T154). Each keeps its numbers, so a view can show why. What one bot does
now, the errands it leaves its post for and where it aims are not here:
since T101 and T64 they are [`ai_utility`](ai_utility.md), for nothing in them is about a team. The
sources: the *Game AI Pro* chapters each class names.

## When not to use it {#when-not}

One squad, or one place to stand: nearest-first is the same answer with
less to explain. Roles that are places, not jobs -- who holds which door:
that is `TacticalPositions` with claims, not `RoleArbiter`. And a team whose
members must act in a fixed order, a breach then a sweep: that is a plan's
(`ai_planning`), not a weighing each bot makes again every decision.
Attack tokens are for a group against one target: a fight with one enemy
needs no turns, and in a stealth game the enemies should not be attacking
at all.

## Where to watch it {#watch}

- `make demo-botmatch` -- six against six. **Tab** watches the next bot:
  the discs round it are every spot it weighed, with its score. **1-3**
  switch blue's claims, commander and retreat (**shift** for red's), so you
  can watch the team with each part off. **T** takes the watched bot over.
- `make demo-infiltration` -- the guards search with `SearchCoordinator`
  and fight under `RoleArbiter`; **2** and **3** switch the coordinator and
  the arbiter, **Tab** watches the next guard.
- `AttackTokens` has no demo yet: T157's boss fight is the one that will
  show who holds a token. Until then its vectors and its suite run it.
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
| attack tokens | `AttackTokens.Config` | how many may strike at once per kind, how long between grants, how much longer when the player is busy |

## In your own project {#your-project}

### What to copy {#copy}

From the library: unzip `ai_teamwork-<version>.zip` into your project's
root, `res://` -- [using the library](using-the-library.md) has every step,
the Python wheel too. Or copy it from a checkout:

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

## Attack tokens: one attacks at a time {#attack-tokens}

A group surrounds the player, and only one or two of them strike at once;
the rest circle and wait. Kingdoms of Amalur gave the player an *attack
capacity* and each attack a weight, and a creature could pick only an
attack whose weight still fit [Dawe 2013]; DOOM (2016) keeps a count of tokens per
attack type, set by difficulty [Thompson 2018]. `AttackTokens` is that
pool, one per target:

- **A pool per kind**, `melee: 2` and `ranged: 1`, and a cost per request,
  so a heavy attack takes both melee tokens. A cost above its kind's whole
  pool is refused when it is asked -- `REFUSED_COST` -- not queued for ever.
- **Who is served next is a rule written down**, not the order the
  requests were stored in: first whoever was passed over `patience` times,
  oldest first; then the highest priority (the boss above its minions);
  then the one waiting longest; then the nearest; then a seeded hash. The
  first in that order is served or no one is: a heavy attack that does not
  fit yet is not overtaken by light ones. So every requester is served
  within `patience` grants plus the number who asked before it -- the
  suite holds that bound.
- **A token comes back in five ways**: the attack ends, the holder is
  interrupted or dies, the game revokes a whole kind at once
  (`revoke_kind`, when melee pressure starts and the ranged should stop),
  or it times out -- the net for a holder that forgot.
- **A timer spaces the grants** of each kind: a base delay, times a factor
  for the player's state -- longer when busy, shorter when idle. Both are
  data, and `delay_for(kind, state)` is there to be drawn.

```gdscript
var pool := AttackTokens.new(config)  # config.pools = {"melee": 2, "ranged": 1}
pool.request("troll", "melee", 2, 5, 3.0, now)  # cost 2, priority 5, 3 m away
for id: String in pool.step(now, "busy"):
	print(id, " may strike")
pool.release("troll", AttackTokens.ENDED, now)
```

`events` logs every grant and return with its reason, for a view to draw.
Where this sits beside rings and telegraphs, and when not to use any of
them: [concepts/action-combat-ai.md](../concepts/action-combat-ai.md).

## Deeper {#deeper}

- How action-game enemies take turns -- tokens, rings, telegraphs:
  [concepts/action-combat-ai.md](../concepts/action-combat-ai.md).
- How shooter AI is made: one bot, a team, a search:
  [concepts/shooter-ai.md](../concepts/shooter-ai.md).
- The bot match, every knob and key: [godot/botmatch.md](../godot/botmatch.md).
- What one bot does now, by utility: [ai_utility.md](ai_utility.md).
