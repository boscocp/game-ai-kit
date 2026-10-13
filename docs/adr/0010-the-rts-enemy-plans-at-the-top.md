# 0010 — The RTS enemy plans at the top, with a heuristic, on a cadence

Status: proposed · 2026-10-13 (written before T11; T11 and T20 measure it, and
it is accepted or amended on what they find)

## Context

`ai_planning` is a breadth-first STRIPS planner over a domain also written in
PDDL. That is right for teaching and for its eight-fact domain, where it visits
14 worlds. An RTS opponent has numeric resources, build times, many units and
a clock that does not wait. Over boolean facts alone, breadth-first visits
up to two to the power of their number, and numeric resources make the space
unbounded unless they are abstracted. `WorldState.key()` also sorts and joins
strings for every world generated, twice per world.

The question "PDDL or STRIPS, which is faster" has no answer, because they are
not alternatives: PDDL is the language and STRIPS the model it describes. The
real question is which layer plans, over how small a problem, with what search,
and how often. The sources are in
[planning in strategy games](../concepts/planning-in-strategy-games.md).

## Decision

1. **Only the strategy layer plans.** It plans over goals and abstracted
   resources, never over the whole army. Tactics are utility scores over
   regions and influence maps, and units use A\* and flow fields. The layers
   are the StarCraft survey's. Putting the only planner at the top is *this
   kit's* choice for an RTS: the shipped games cited plan per agent or per
   squad (F.E.A.R., Killzone 3, Horizon), which suits a handful of agents
   rather than an army, while the RTS research plans the build order.
2. **Under the plan, the economy is priority queues.** That is what AoE II,
   Supreme Commander and 0 A.D. ship. It is also the baseline a planner has to
   beat before it earns its cost.
3. **The planner gains a heuristic, a bit-packed state and a budget.**
   Breadth-first stays in `ai_planning` as the readable first version. The
   strategic planner adds h_max (admissible, so still shortest) or h_add
   (faster, not shortest), chosen by measurement in T11. Each call has a
   budget, and when the budget runs out the call returns the best plan so far.
4. **Resources are abstracted, not handed to a numeric planner.** Income is a
   rate, and the search jumps to the next moment an action becomes legal
   (Churchill and Buro, 2011). The PDDL stays at level 1, because general
   PDDL 2.1 planners lost on this exact problem (Chan et al., 2007).
5. **Replanning happens on a cadence and on failure**, never every frame, and
   the work is spread across frames, as Killzone 3 does.
6. **HTN is built beside GOAP and STRIPS in T15.** At one studio a forward
   HTN was considerably faster than GOAP (Humphreys, 2013), and HTN is the
   other answer the literature gives. Which one the RTS commander uses is
   T20's measurement.

## Alternatives considered

- **Breadth-first STRIPS over the whole game.** Rejected: van der Sterren
  (2013) reports GOAP and HTN struggling on a multi-unit state space, and none
  of the shipped titles found runs one search over everything.
- **A general PDDL 2.1 planner, at runtime or as the reference.** Rejected for
  runtime: it is an external process, not GDScript, and not reachable at tier
  1. Chan et al. report that SAPA, MIPS-XXL, SGPlan, LPG, LPG-td and TM-LPSAT
  could not satisfactorily solve RTS resource production. One stays useful *offline*, to check a level 1 domain.
- **A planner per unit or per squad, as in F.E.A.R. and Killzone 3.** Not
  chosen for the RTS. Those games plan for a handful of agents, and Orkin says
  F.E.A.R. had no complex squad behaviours at all. An RTS has an army whose
  economy and build order need deciding by somebody. GOAP and HTN are still
  taught in T15, and T25's league can field a team that plans low down, which
  is how this choice gets tested rather than assumed.
- **Rules and priority queues only, no planner.** This is what most shipped
  RTS economies are, and it is kept as the baseline. Rejected as the whole
  answer: planning is the lesson this kit is building towards, and Churchill
  and Buro show it works on the build-order subproblem.

## Consequences

- T11 gains a measurement: worlds visited and milliseconds per plan, with
  breadth-first against each heuristic and string keys against bits, on the
  real domain. Its number decides point 3.
- T15 gains HTN as a fourth way to decide.
- T19's frame budget covers the planner's slice of each frame, not only
  movement.
- T20's commander is the planner at the top of three layers. Its economy is
  priority queues, and the match test asserts the budget per planning call.
- If T11 or T20 measures this design and it does not hold, this ADR is amended
  with the number, not quietly worked around.
