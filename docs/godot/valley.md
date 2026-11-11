# The valley that remembers: what you do to its places stays done

<!-- doc-meta
half_life: practice
verified_on: 2026-11-11
tier: 2
source: https://github.com/boscocp/game-ai-kit
invalidated_if: valley_map.json, villagers.json or manners.json change, ValleyGame's session or day changes, or the valley's tests stop holding what "What the tests hold" says
teaches: none
-->

> T165's example, built on T164's record of deeds (wave 178) under ADR
> 0025. Where the idea comes from, and what it refuses, is
> [the karma and world-memory page](../concepts/karma-and-world-memory.md).
> This page says how the game puts the record to work, and what its tests
> hold.

## What it is

`make demo-valley`. A 2D, turn-based valley seen from above: a river runs
down the middle, the west village has the market and the square, the east
village the barn, the mill on its race, the orchard behind its gate and the
low field. The stone bridge and the ford are the two ways across. There is
no combat and no opponent.

Six villagers live their day -- bread, water, fruit -- one cell a turn,
48 turns a day. You may do one deed a day to a place, with the number
keys: burn the barn, pull the bridge down, dig a well in the square. Tab
follows another villager, space plays one turn, P pauses, N ends the day,
and E erases the valley's memory after you confirm with Y; the button
under the legend does the same.

## A session and a day

- **One file is kept.** Each deed goes into the record (`ValleySave`,
  `user://valley/deeds.json`), and nothing else is written. Each session
  rebuilds the world and the standing from it.
- **A session starts the day after the last deed**, the first day on an
  empty record. The days you only watched are not kept: only deeds are, and
  the overnight rules bring a deed's consequences to rest within three
  nights.
- **A day** is 48 turns, then a night (`ValleyRules.overnight`). The
  villagers start every day at home with nothing carried: nothing about
  them is kept, even within a session.
- **One deed a day, and only one that changes something.** A deed is
  offered only when it would change a fact of today's world; shutting the
  shut gate is neither offered nor kept, so the standing cannot be farmed
  (T164's review, finding 4). The check needs the world of that day, which
  the record and the save never see, so it lives in `ValleyGame.offered`
  and `ValleyGame.act`.
- **The one-deed-a-day rule is the game's, not the record's.**
  `ValleyGame.act` refuses a second deed today, and a session starts on the
  last deed's day plus one, so the game never writes two deeds on one day.
  `DeedLog` itself accepts them -- two deeds on one day from a hand-edited
  file are read, by T164's design -- because the record keeps what was done,
  not the rules of the game that did it.
- **The record's refusals stay English.** `DeedLog`'s and `ValleySave`'s
  refusals are diagnostics about a file format, like `BoardState`'s about a
  move: tests and the vectors read their words. Where one reaches the
  screen it is quoted verbatim inside a translated frame ("Recusado:
  {why}"). They are marked `# not shown` for `lint-translations-game`,
  which is imprecise -- they are shown, untranslated by design; a marker for
  that is a cross-cutting change left for a later wave. The game's own
  refusals in `ValleyGame.act` are reached only through the API: the screen
  acts on offered deeds only.

## How a villager decides

`ValleyVillager.decide(facts)` receives the world's facts and nothing else;
the rest is its own state of the day. Each time it is free, or a deed
changes the world, it decides in three steps:

1. **A\*** (`ai_search`, over `ai_core`'s grid) from where it stands to
   every place an action is done at. The grid is built from the facts: the
   river is blocked, the bridge open while `bridge.standing` holds, the
   ford while `ford.footbridge` does. A place with no route is a fact too:
   `market.reachable` false.
2. **GOAP** (`ai_behaviour`) for each goal left, over seven actions in
   `villagers.json`: `buy_bread` at the market, or `take_wheat`,
   `grind_wheat`, `bake_bread` from the barn to the mill to home;
   `draw_from_well` or `draw_from_river`; `pick_fruit`. Each costs its walk
   plus its work, so GOAP finds the cheaper way today, and the other when
   the first is shut.
3. **`ActionChoice`** (`ai_utility`) scores the goals left: a goal with no
   plan scores 0, a dearer plan less.

A plan's cost is an approximation of its route: each action is priced by
the walk from where the villager stands when it plans, not from the place
of the step before. That keeps GOAP's action costs fixed during one search,
which its A\* over plans needs, and on a map this small it orders the plans
as the real routes would. A test holds that the walk decides: with the
footbridge built and the bridge down, Ana bakes and Clara buys, and the
case turns red when the walk is planted as 0.

**Why GOAP and not the HTN.** The two ways to bread are found by a search
over action costs that come from A\*'s routes, so the plan changes by
itself when a route closes. An HTN would need a designer to write each way
as a method, in order of preference; and the order changes with where the
villager lives and which crossing is up, which is exactly what the costs
already say.

No villager reads another, nor the player's standing. They walk through
each other, and nobody queues: that would need them to read one another,
which ADR 0025 refuses.

## What it shows

- **The deed to the plan.** The panel follows one villager: every fact it
  reads that a deed or a night changed, with the reason the world keeps for
  it; the places it cannot reach; its goal and plan; its A\* search. On the
  ground, the search's expanded cells in yellow, its frontier in cyan, its
  route in white, and a ring on where it is going. Pull the bridge down and
  end the day: Ana's search fills the east bank and stops at the water, and
  her bread is `take_wheat -> grind_wheat -> bake_bread` instead of
  `buy_bread`.
- **The deeds to a manner.** Under it, the ferryman, the merchant and the
  priestess: the virtue their rule read, its value, the deeds that made it
  (numbered in the record), and what it sets against the usual -- "fear 5
  (deeds 1, 2) -> asks 8 coins, 4 as a rule".

## The three people

`manners.json` gives each a list of rules read top to bottom; the first
that holds sets the person's consequence and greeting. A rule names the
world's facts it needs and a virtue's least value; the last needs nothing.
The thresholds this wave chose:

| who | stands at | sets | rules, in order |
|---|---|---|---|
| ferryman | ford | price, usually 4 | fear 5: 8; bridge down and care 4: 2; else 4 |
| merchant | market | price, usually 2 | no bread: 0; fear 4: 5; care 3: 1; else 2 |
| priestess | square | door | fear 6: shut; care 3: open; else shut |

Each also sets a greeting. Those are the only consequences `standing.json`
allows; none is a challenge. You carry no purse in this first version: the
price is what you are asked, shown, not paid.

## What the tests hold

`make test-godot-some SUITES="test/valley"`:

- `three_sessions_test.gd`, the acceptance: a seeded, scripted player plays
  three sessions of three days on a save under `user://tmp/`, on three
  seeds. Session 3's world is the one the test's own copy of the deeds
  rebuilds, facts and reasons, and the one the file rebuilds; the folder
  holds one file, a header and one `{day, verb, place}` a line, with no
  virtue, villager or plan step in it; erasing returns to day one, in the
  session and in the next; a second load gives every villager the same
  plans. Not vacuous: each session keeps a deed, and
  session 3's world is not the first day's.
- `valley_game_test.gd`: shutting the shut gate refused five days running,
  standing unmoved, nothing on disk; every deed offered changes a fact and
  every other does not; one deed a day; `decide` and `step` take one
  argument, `facts`, a Dictionary; a villager decides the same alone or
  among others; the bridge down sends Ana to bake her own bread, with the
  chain the panel shows; a new well draws Elisa from the river; a burnt
  barn leaves nobody a plan for bread; the bridge pulled down under an east
  villager on the west bank strands it there, no route over the gone
  bridge and no engine error; the walk decides who bakes and who buys; a
  dearer plan scores less; no day can offer more deeds than there are
  number keys; every manner sets only the
  consequences `standing.json` lists; fear 5 doubles the ferryman's price,
  naming deeds 1 and 2.
- `make test-demo-overlays` steps the scene and requires `chain`, `plan`,
  `frontier`, `expanded`, `care`, `fear` and `deeds` in the overlay.

## Manual check

- Play two sessions. Burn the bridge in the first, and in the second see
  the villages live with it and the overlay say why.
- Dig the well and watch the west village draw water at the square the
  next day, where it walked to the river before.
- Read the panel in pt-BR: the reasons, the deeds and the greetings are
  Portuguese; the facts, goals and plan steps stay as the code names them.
