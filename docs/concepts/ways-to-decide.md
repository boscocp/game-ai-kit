# Four ways to decide: one guard, written four times

<!-- doc-meta
half_life: concept
verified_on: 2026-10-19
tier: 0
source: book:Steve Rabin (ed.), "Game AI Pro", CRC Press, 2013 -- ch. 12 (Humphreys, HTN planners)
invalidated_if: WaysToDecide's table, a guard in godot/demos/behaviour/, or the measurements in test/behaviour_test.gd change
teaches: ways-to-decide
-->

> What `make demo-behaviour` shows: the same guard, on the stealth room,
> written as a state machine, a behaviour tree, GOAP and an HTN, swapped
> with keys 1-4 while it walks. Reading only. The code is
> [`ai_behaviour`](../../godot/addons/ai_behaviour/), the guards are in
> [`godot/demos/behaviour/`](../../godot/demos/behaviour/), and the table
> below is `WaysToDecide`'s, which the demo shows beside the brain playing.

## Why one guard four times

Every comparison of these techniques on the internet compares four
different agents, and then the agent is what differs. Here the four guards
know the same facts (what `Suspicion` and the senses say, see
[stealth](stealth.md)) and choose among the same deeds, so where they behave
differently, **the way of deciding is what differs**.

## The four, and the seam each one shows

- **A state machine** is a handful of states and the arrows between them.
  Nothing changes until an arrow's condition fires, so it *snaps*. Its
  states each name their own exits, so behaviour two states share is written
  twice.
- **A behaviour tree** is asked again from its root every turn. Built from
  reusable parts and good at reacting, it cannot commit: the guard turned
  back the moment suspicion dipped, and in 300 turns on the demo's loop it
  never got far enough to chase.
- **GOAP**, goal-oriented action planning, searches *backwards* from a goal
  for the cheapest chain of actions, and does it again every turn. With one
  way to each goal, as this guard has, its search finds what the tree was
  told: the same deed on every one of 300 turns.
- **An HTN**, a hierarchical task network, breaks a task into the steps a
  designer wrote and carries on down the method it chose. It kept going to
  look as suspicion faded, looked, chased and caught.

## When each is the right answer

| way | right when | what it costs |
|---|---|---|
| state machine | a few states, each with a clear way out | shared behaviour written twice |
| behaviour tree | reusable parts, re-judged every tick | it cannot commit |
| GOAP | many ways to a goal; find the cheap one | a search every replan, backwards, no partial plan |
| HTN | the designer knows the order, and wants it kept | every order is one somebody wrote |
| STRIPS (`ai_planning`) | a chain nobody wrote down, searched forwards | a search over the whole world, bounded by a budget |

STRIPS is not written as a guard; it plans the tactical board (see
[planning in strategy games](planning-in-strategy-games.md)), where the same
four ways also play as teams, measured in [the league](the-league.md).

## What the measurements say, and do not

In four moments of the guard's day GOAP took 2 to 3 worlds off its frontier
and the HTN 2 to 3 tasks. In time, the HTN took about 6 to 8 microseconds a
plan and GOAP about 6 to 16. That is these two implementations -- much of
GOAP's extra is how this one keeps its frontier -- and a guard this small
cannot say which *way of searching* is faster in general.

## When not to use this table

As a rule. It is about this guard. A game whose agents look nothing like a
guard should measure its own.
