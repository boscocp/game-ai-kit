# T20 — The RTS demo

Size: L · Prereqs: T19, T12, T15 · Files: `godot/game/rts/`

## Split (2026-10-20)

Split by the owner's decision of 2026-10-19, at the line T25's recordings
draw. **This task** is everything a match needs before a person's play is a
reference: the game, the map, the economy, the units, fog, the Bos Wars art,
the three layers with the commander on top, and the difficulty levels on
T12's strength axis -- steps 1 to 6, and the first half of step 7. **T55**
is the rest of step 7: the human-likeness axis in real time (a reaction
delay drawn from recorded play, a cap on actions per minute), T25's league
on this board, and its cost meter on screen. Those need T25's twenty
recordings and nothing here does, so T25 is no longer this task's prereq.

## Goal

The real-time strategy demo: build orders, unit counters, fog of war, and the
planner from T11 running against the clock instead of against a turn.

Last on purpose. It needs the tactical content from T10, the honest difficulty
ladder from T12, the second core from T19, and everything the three earlier
games taught about making an AI legible. Built first, it would have been a
large pile of code with no lesson in it.

## The minimum game

Built backwards from the AIs: each feature is here because some technique has
nothing interesting to decide without it, and nothing is here for any other
reason.

| the AI | is only interesting if the game has | without it |
|---|---|---|
| rules and priority queues | an economy with more than one thing to spend on at once | a linear script |
| FSM and behaviour tree | units whose state changes: gather, defend, retreat, chase | one state, nothing to see |
| STRIPS, GOAP, HTN | a chain of dependencies paid from one contested bank, and a population cap | a two-step plan any rule matches |
| utility and influence maps | regions worth different things: expansions, a chokepoint | nowhere to choose to attack |
| A\* and flow fields | terrain with costs, obstacles, and groups moving together | a straight line does it |
| the learned model (T6) | fights whose outcome is uncertain and depends on numbers, terrain and reinforcement | nothing to predict |
| human-likeness (T25) | gains its clock measures with real time, and its scouting with fog of war | only the turn-based measures |

**What it has:**

1. **Economy**: two resources, as in Churchill and Buro's StarCraft build
   orders, so that spending is a trade. Workers that gather them, and a
   population cap that forces a supply building, which lengthens the
   dependency chain without new rules.
2. **Production**: a base, a barracks and **one** technology building that
   unlocks the third combat unit. Everything takes time to build, and that
   time is what makes a build order a decision.
3. **Units**: a worker and **three** combat units in a rock-paper-scissors
   counter table, taken from T10's five. Three are enough for countering and
   scouting to pay off in real time.
4. **Map**: two starting bases, two or three expansions with resources, one
   chokepoint, and terrain with costs. That is the least that makes
   "expand", "attack where" and flow fields real choices.
5. **Fog of war and scouting**, and T10's tower that sees, which is how a
   side buys vision without spending a unit. Without them there is no
   uncertainty, the influence maps have nothing to estimate, and the scouting
   half of the human-likeness test disappears.
6. **Combat**: damage, range and health, with a little randomness drawn from
   the match seed. No special abilities.
7. **An end**: destroying the base, or a time limit with a stated tiebreak.
   The league needs every match to finish.

**What it leaves out, on purpose:** air and naval units, heroes, active
abilities, formations, a tech tree deeper than one building, and diplomacy.
Each is work that gives none of the AIs above a new decision. One of them
comes back only with a task that names the AI it is for.

## Art: referenced, never committed

Decided by the owner on 2026-10-19: the RTS's pictures are **referenced and
kept out of the repository**, with a link for whoever wants them -- not even
crops are committed, unlike the fighters (ADR 0015). The set is **Bos Wars
2.8** (GPL-2.0-or-later, sci-fi, three-quarter view), chosen for being the
one free set found with a worker, infantry, base, barracks and resources,
animated in five mirrored directions (move, attack or build, die), with
the player's colour in palette indexes 208-211. Because nothing of it is
redistributed, its GPL never enters this Apache-2.0 tree.

Its roster lands on the minimum game almost one for one: `engineer` the
worker; `assault`, `bazoo` and `grenadier` (or `tank`) the three counters;
`vault` the base; `camp` the barracks; `vehiclefactory` the technology
building; `powerplant` the supply; `radar` the tower that sees. Sheets
checked on 2026-10-19 from
`https://sources.debian.org/data/main/b/boswars/2.8-2/units/` (sha256):

| file | size | sha256 |
|---|---|---|
| `engineer/unit_engineer.png` | 280 x 728, 56 px cells | `52adfb9bdb0bf7abc31c87e006dd28020bc783eb9b326356400e2c9f48c7defc` |
| `assault/unit_assault.png` | 320 x 640 | `a387274229fb3d5c8657032e31c6094cb2b447e8372e259d1a27ee0f771b61da` |
| `vault/vault.png` | 1180 x 832, building stages | `e14bc0f501edc579a4466520a1b61be6753f8336e116f19500aa87c30c5d7b71` |
| `radar/radar.png` | 64 x 768 | `9cf66e77a5a237e2d38a233e5fe49166fb4f9692ba386e9436c376663e1d43f7` |

What this task owes it: an ADR (the rule, the source, every file's URL and
sha256); a make target that downloads into a gitignored folder and refuses
a file whose hash differs; and a game that draws plain shapes when the
folder is empty, so CI and a fresh checkout run without it. Rejected:
Wyrmsun's CC0 collection (its units are 46 x 38 icons, not sprites),
Kenney's two RTS packs (no animation), Tiny Swords (no redistribution, and
not needed now, but its terms would bar even a mirror).

## Steps

1. The minimum game above, on the real-time core, built from T10's content.
   Its terrain is kept, with water impassable to all three units, since the
   type that crossed it is not among them. Three of its five unit types are
   kept, and of its two towers only the one that sees. Its one producer and
   one upgrade become the four buildings above, and its one resource becomes
   two, each for the reason the list gives. What changes is time.
2. **Three layers, as ADR 0010 sets out**: a commander that plans, squads
   that score, units that move. Only the commander plans. Squads choose
   regions by utility over the influence maps (Dill's Kohan II chapter);
   units take A\* or a flow field.
3. **The economy as priority queues** under the commander, which is what AoE
   II, Supreme Commander and 0 A.D. ship. A commander that does not beat the
   queues alone has not earned its cost, and the match test says which.
4. Build orders as plans: the PDDL domain at level 1, with resources as income
   rates and time jumping to the next legal action rather than stepping frame
   by frame (Churchill and Buro, 2011). It is replanned on T11's cadence
   against a world that does not wait, and that difference from T11 is the
   lesson of the task. Whether the commander is T11's heuristic STRIPS or
   T15's HTN is measured here, and ADR 0010 is amended with the answer.
5. Fog of war, which makes planning under uncertainty real rather than
   theoretical, and which the influence maps from T14 already know how to draw.
6. Group movement with the flow fields from T19.
7. The difficulty levels from T12, still not cheating: a level changes how
   the commander and the squads think, never what a side sees, earns or may
   order. *Moved to T55 by the split:* the human-likeness axis from T25 and
   the knobs only a clock makes possible -- a reaction delay drawn from
   recorded human play, and a cap on actions per minute in the spirit of
   AlphaStar's -- with T25's league on this board, adding actions per
   minute and reaction time to its human-likeness measures, and its meter
   showing each team's share of T19's frame budget.

## Acceptance

```bash
make check
```

```bash
./scripts/godot --headless --path godot -s res://test/rts/rts_match.gd
```

That script plays a full AI-against-AI match headless with a fixed seed and
asserts it terminates, that the winner is consistent across runs, that the
frame budget from T19 held throughout, and that no single planning call
exceeded its budget. It also plays the commander against the priority queues
alone and prints the win rate. A match that only works when somebody is
watching is not a match that works.

## Manual check

Play a full game against the middle difficulty. It should lose to a good player
and beat a careless one, and when it loses you should be able to say what it
got wrong.
