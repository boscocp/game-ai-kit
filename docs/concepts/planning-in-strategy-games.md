# How strategy games plan: the industry and the literature

<!-- doc-meta
half_life: concept
verified_on: 2026-10-18
tier: 0
source: https://web.archive.org/web/2020/https://www.cs.mun.ca/~dchurchill/publications/pdf/starcraft_survey.pdf ; https://ojs.aaai.org/index.php/AIIDE/article/view/12435/12294 ; https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf ; https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf ; https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf
invalidated_if: a survey or shipped title shows a single state-space planner running a whole RTS opponent within a frame budget, which would undo the split this page recommends
teaches: strategy-ai
-->

> What shipped strategy games and the research on them actually do to run an
> opponent, with the sources, and what this kit takes from them for the RTS
> enemy in T11 and T20. Needs nothing but reading. The planner this builds on
> is [planning](planning.md).

## The short answer

**Nobody plans the whole game in one search.** Both the shipped titles and
the research literature split an opponent into layers that work on different
time scales, and each planner they use works on a small piece of the problem.
*Which* layer plans differs. The shipped games below plan per agent or per
squad: F.E.A.R.'s soldiers, and Killzone 3's bots and squads. The RTS
research plans the build order, at the strategic layer. Everything else is
rules, scores and cheap searches.

For the RTS enemy, this kit chooses to plan **at the strategic layer only**.
That is a choice, made for an RTS's scale, and the reasons are given at the
end of this page. It is not a description of what every game does.

That changes the question. The choice between PDDL and STRIPS was never about
speed: PDDL is the language a domain is written in, and STRIPS is the model
it describes. What decides speed is **which layer plans, over how small a
problem, with what search, and how often.**

## The layers

The StarCraft survey by Ontañón and colleagues (2013) divides an RTS player
into **strategy**, **tactics** and **reactive control**. Its figure puts their
time scales at roughly three minutes, thirty seconds and one second. It also
records how few planning approaches survive real time: "the real-time
constraints of RTS games limit the planning approaches that can be applied,
HTN and case-based planning being the only ones explored so far."

Shipped games layer too, though they put the planner lower down. Killzone 3's
multiplayer bots are "set up as a three-layered hierarchy, where each layer
controls the layer below it and information flows back" (commander, squad,
individual). Both the individual bots and the squads plan with HTN -- a
squad "generates and monitors a plan using the HTN planner" -- while the
commander assigns objectives. In F.E.A.R., the planning was done per soldier,
and the squads were a simple periodic coordinator. Orkin is blunt about it: "we actually did not have any complex
squad behaviors at all in F.E.A.R." The tactics players saw emerged from the
combination.

| layer | decides | time scale | what shipped games and papers use |
|---|---|---|---|
| strategy | what to build, when to expand, when to attack | minutes | HTN commanders, build-order search, priority queues |
| tactics | where a squad goes, which region to take | tens of seconds | utility scores over regions, influence maps |
| reactive control | where one unit steps, whom it shoots | a second or less | A\*, flow fields, scripts, small budgeted searches |

## What shipped strategy games do

**Most of a shipped RTS economy is not a planner.**

- Age of Empires II's AI is a set of rules: "Facts are conditions that must
  be true for a rule to execute… Actions tell the AI player to do something."
  The rules are evaluated in periodic passes. The community reference's page
  on command performance says, of the Definitive Edition, "any script pass
  that lasts less than 20 milliseconds will not cause lag".
- Supreme Commander's base-building AI, in the community-maintained source,
  keeps a list where "A task has a priority. The tasks with the highest
  priority are evaluated first. Each task has a series of conditions
  attached", rechecked on an interval.
- 0 A.D.'s open-source Petra AI keeps production queues that compete for a
  budget. Its queue manager "picks which items to fund with resources until no
  more resources are left to distribute".

**Where a planner does appear, it works on a small problem and reruns at a
rate.**

- Each Killzone 3 bot has "a custom planner that is based on the Hierarchical
  Task Network (HTN) planner architecture". The bot reruns it "at a fixed
  rate" and keeps the new plan only if it is better. The squads' strategic path
  planners are "updated incrementally using an anytime algorithm". The shipped
  commander assigns objectives by weight, without a planner. The authors then
  expressed the commander as an HTN planner too, which the chapter lists under
  future work for later titles, not as shipped.
- Horizon Zero Dawn's AI uses "a combination of HTN planning and utility based
  decision making": the network gives the structure, and scores choose between
  options.
- F.E.A.R.'s GOAP uses "A\* to plan sequences of actions as well as to plan
  paths". Orkin lists four changes to STRIPS: a cost per action, no explicit
  add and delete lists, and procedural preconditions and effects.
- At the studio that shipped both, a forward HTN beat GOAP on speed. Humphreys
  writes that it "allowed the HTN planner in Transformers: Fall of Cybertron to
  be considerably faster than our GOAP system used in Transformers: War for
  Cybertron". He also notes that "GOAP and STRIPS planner variants" "use a
  backward search", from the goal, while HTN works forward from the current
  state. That is what lets an HTN return a partial plan. This kit's own
  `StripsPlanner` searches forward, from the start, so this kit reads his
  remark as being about the regression planners GOAP is built on, not every
  STRIPS planner.
- Van der Sterren's chapter on multi-unit manoeuvres warns that "GOAP and, to
  a lesser extent, standard HTN planners struggle to search efficiently in such
  a large state-space": one search over a whole army does not scale.

**Attack timing and targets are scored, not planned.** Dill's spatial
reasoning chapter, from the RTS Kohan II, scores regions: "we launch our
attacks against regions". On a map whose terrain can change, he says the
regions would have to be recomputed, that this is not simple and "neither is
likely to run in a single frame", and that "you're going to have to
timeslice the calculations". Mark's modular
influence maps stay cheap by stamping precomputed templates.

**A bounded search can still be slow to ship.** Total War: Rome II's campaign
AI used Monte Carlo tree search, and it was bounded: Tommy Thompson writes
that "the MCTS is limited such that it doesn't search all the way to the
goal", looking "one turn ahead before starting random playouts", and that "the
anytime property of the algorithm ensures we will still get a useful and
intelligent decision". Even so, "the campaign AI took quite a long time to
make its decisions in the launch build", and the game was patched
aggressively for several weeks after launch. The
article does not give a cause. The lesson worth taking is narrower than
"unbounded search is slow": a budget per decision has to be measured on the
shipping game, not assumed from the algorithm.

## What the research does

**Build orders as an anytime search** (Churchill and Buro, 2011). Depth-first
branch and bound with an admissible lower bound plays StarCraft build orders
in real time. Three choices make it fit:

- gathering is folded into income rates, "0.045 minerals per worker per
  frame", rather than searched as actions;
- the search jumps to the next moment an action becomes legal, instead of
  stepping frame by frame;
- "since this is an any-time algorithm we can halt the search at any point and
  return the best solution so far".

It replans in increments, such as 60-second horizons in 15-second steps.

**General numeric planners lost on exactly this problem.** PDDL 2.1 (Fox and
Long, 2003) adds numbers at level 2 and durative actions at level 3; the
kit's domain is level 1. Chan and colleagues wrote the RTS
resource-production problem in PDDL 2.1. Their workshop paper reports, from
their earlier work, that general temporal planners (SAPA, MIPS-XXL, SGPlan,
LPG, LPG-td and TM-LPSAT) were tried and "none of them could satisfactorily
solve the RTS resource production problem". Their own planner, built for the
domain and paired with a scheduler, ran under a time limit they set at 0.1
seconds a search, and 0.5 for the harder problems.

**The standard way to make a STRIPS search fast is a heuristic**, the same lesson
as A\* over Dijkstra, applied to worlds:

- h_max and h_add (Bonet and Geffner, 2001) estimate the distance to the goal
  from the costs of its subgoals. "The max heuristic unlike the additive
  heuristic is admissible", so it keeps the plan shortest; h_add guides
  harder and gives that up.
- FF (Hoffmann and Nebel, 2001) estimates the distance "by ignoring delete
  lists" and counting the actions of the relaxed plan.
- Fast Downward (Helmert, 2006) first translates the task into multi-valued
  variables, which is worth knowing about and more than a teaching kit needs.

**HTN** (SHOP2: Nau and colleagues, 2003) plans by decomposing tasks with
methods the designer writes, and "generates the steps of each plan in the same
order that those steps will later be executed, so it knows the current state".
Kelly, Botea and Koenig (2008) start from the constraint every game has, "the
CPU and memory resources available to game AI modules at runtime are scarce",
and their answer is to do the HTN planning *offline*, before the game runs.

**Search belongs in combat too, with a hard budget.** Churchill, Saffidine and
Buro (2012) ran their combat search with 5 ms an episode, because "the 2011
StarCraft AI Competition allowed for 50ms of processing per game logic frame".
Ontañón's NaïveMCTS (2013) handles the combinatorial branching of many units
moving at once, which is a tactical problem, not a build-order one.

## What this kit takes from it

1. **The RTS enemy plans at the strategy layer only -- this kit's choice.**
   The shipped games above put their planners on agents and squads, which
   suits a handful of soldiers. An RTS has an army, and van der Sterren warns
   that planners "struggle to search efficiently" over many units. Its
   research plans the build order instead. So the commander plans over a small
   domain of goals and abstracted resources. Tactics are utility scores over
   regions and influence maps, and units use A\* and flow fields. T25's
   league is where a team that plans lower down can show this choice was
   wrong.
2. **The economy under the plan is priority queues.** That is what AoE II,
   Supreme Commander and 0 A.D. do, and it is the honest baseline any planner
   has to beat.
3. **The planner gets a heuristic and a budget.** Breadth-first stays as the
   readable first version in `ai_planning`. The RTS version adds h_max (still
   shortest) or h_add (faster, not shortest), a state held as bits, a budget
   per call, and the best plan so far when the budget runs out. Which heuristic
   wins on this kit's domain is measured in T11, not assumed -- and T11
   measured it, on the tactical domain over 28 boards from real games:

   | search | worlds visited | ms a plan |
   |---|---:|---:|
   | breadth-first, strings | 6094 | 5.71 |
   | breadth-first, bits | 6094 | 0.76 |
   | A\* with h_max, bits | 169 | 0.55 |
   | A\* with h_add, bits | 169 | 0.54 |

   The two guesses tie: the domain's plans are short and nearly unique, so
   h_add has nothing to wander into. The game uses h_max, which costs the same
   and keeps the plan shortest. The table is printed by
   `test/planner_benchmark.gd`.
4. **Resources are abstracted, not given to a numeric planner.** Income as a
   rate and time jumping to the next legal action, after Churchill and Buro.
   The PDDL stays at level 1, and a level 2 or 3 version is documentation,
   because the general planners for those levels lost on this problem.
5. **It replans on a cadence and on failure.** A fixed rate as Killzone 3's
   bots use, periodic passes as AoE II's rules use, plus invalidation, with the
   work spread across frames. A plan computed for the next three minutes does
   not need recomputing every sixteenth of a second.
6. **HTN goes beside GOAP and STRIPS in T15.** One studio moved from GOAP to
   HTN for speed, and the comparison is the lesson. Whether the RTS
   commander ends up HTN or heuristic STRIPS is T20's measurement to make.

These are recorded as a decision in [ADR 0010](../adr/0010-the-rts-enemy-plans-at-the-top.md).

## Sources

Every source below was opened on 2026-10-13, and each quotation above was
checked against its text.

**Shipped games and practitioners**

- Orkin, J. (2006). *Three States and a Plan: The A.I. of F.E.A.R.* GDC 2006.
  <https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf>
- Humphreys, T. (2013). *Exploring HTN Planners through Example.* Game AI Pro,
  ch. 12. <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf>
- Straatman, R., Verweij, T., Champandard, A., Morcus, R., Kleve, H. (2013).
  *Hierarchical AI for Multiplayer Bots in Killzone 3.* Game AI Pro, ch. 29.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf>
- van der Sterren, W. (2013). *Hierarchical Plan-Space Planning for Multi-unit
  Combat Maneuvers.* Game AI Pro, ch. 13.
  <https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter13_Hierarchical_Plan-Space_Planning_for_Multi-unit_Combat_Maneuvers.pdf>
- Dill, K. (2015). *Spatial Reasoning for Strategic Decision Making.* Game AI
  Pro 2, ch. 31. <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter31_Spatial_Reasoning_for_Strategic_Decision_Making.pdf>
- Mark, D. (2015). *Modular Tactical Influence Maps.* Game AI Pro 2, ch. 30.
  <https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter30_Modular_Tactical_Influence_Maps.pdf>
- Guerrilla Games (2017). *The AI of Horizon Zero Dawn.*
  <https://www.guerrilla-games.com/read/the-ai-of-horizon-zero-dawn>
- Thompson, T. (2018). *Revolutionary Warfare: The AI of Total War, Part 3.*
  Game Developer. <https://www.gamedeveloper.com/design/revolutionary-warfare-the-ai-of-total-war-part-3->
- AoE2 AI Scripting Encyclopedia (community reference, Definitive Edition):
  rules, <https://airef.github.io/resources/articles/intro-to-commands.html>,
  and command performance,
  <https://airef.github.io/resources/articles/command-performance.html>
- 0 A.D. Petra AI, `PETRA.QueueManager` API documentation.
  <https://docs.wildfiregames.com/javascript/petra/PETRA.QueueManager.html>
- FAForever, `lua/sim/BuilderManager.lua` (community-maintained Supreme
  Commander: Forged Alliance source, not the original shipped code).
  <https://raw.githubusercontent.com/FAForever/fa/develop/lua/sim/BuilderManager.lua>

**Research**

- Ontañón, S., Synnaeve, G., Uriarte, A., Richoux, F., Churchill, D., Preuss,
  M. (2013). *A Survey of Real-Time Strategy Game AI Research and Competition
  in StarCraft.* IEEE TCIAIG 5(4). Author PDF, archived:
  <https://web.archive.org/web/2020/https://www.cs.mun.ca/~dchurchill/publications/pdf/starcraft_survey.pdf>
- Robertson, G., Watson, I. (2014). *A Review of Real-Time Strategy Game AI.*
  AI Magazine 35(4). <https://ojs.aaai.org/aimagazine/index.php/aimagazine/article/download/2478/2457>
- Churchill, D., Buro, M. (2011). *Build Order Optimization in StarCraft.*
  AIIDE 7. <https://ojs.aaai.org/index.php/AIIDE/article/view/12435/12294>
- Chan, H., Fern, A., Ray, S., Wilson, N., Ventura, C. (2007). *Extending
  Online Planning for Resource Production in Real-Time Strategy Games with
  Search.* ICAPS 2007 workshop. The comparison with general planners it
  quotes is from the same authors' earlier ICAPS 2007 paper, *Online Planning
  for Resource Production in Real-Time Strategy Games*, which was not opened.
  <https://icaps07-satellite.icaps-conference.org/workshop8/Extending%20Online%20Planning%20for%20Resource%20Production%20in%20Real-Time%20Strategy%20Games%20with%20Search.pdf>
- Hoffmann, J., Nebel, B. (2001). *The FF Planning System.* JAIR 14.
  <https://arxiv.org/abs/1106.0675>
- Bonet, B., Geffner, H. (2001). *Planning as heuristic search.* Artificial
  Intelligence 129. <https://www.cs.uky.edu/~sgware/reading/papers/bonet2001planning.pdf>
- Helmert, M. (2006). *The Fast Downward Planning System.* JAIR 26.
  <https://arxiv.org/abs/1109.6051>
- Nau, D., Au, T., Ilghami, O., Kuter, U., Murdock, J., Wu, D., Yaman, F.
  (2003). *SHOP2: An HTN Planning System.* JAIR 20.
  <https://arxiv.org/abs/1106.4869>
- Kelly, J., Botea, A., Koenig, S. (2008). *Offline Planning with Hierarchical
  Task Networks in Video Games.* AIIDE 4 (abstract only checked).
  <https://ojs.aaai.org/index.php/AIIDE/article/view/18673>
- Fox, M., Long, D. (2003). *PDDL2.1: An Extension to PDDL for Expressing
  Temporal Planning Domains.* JAIR 20. <https://arxiv.org/abs/1106.4561>
- Churchill, D., Saffidine, A., Buro, M. (2012). *Fast Heuristic Search for
  RTS Game Combat Scenarios.* AIIDE 8.
  <https://cdn.aaai.org/ojs/12527/12527-52-16049-1-2-20201228.pdf>
- Ontañón, S. (2013). *The Combinatorial Multi-Armed Bandit Problem and Its
  Application to Real-Time Strategy Games.* AIIDE 9.
  <https://ojs.aaai.org/index.php/AIIDE/article/download/12681/12529/16198>

**Looked for and not verified**, so nothing above rests on them: the StarCraft
II built-in AI, Company of Heroes, Planetary Annihilation, Ashes of the
Singularity, the Mark and Dill utility talk at GDC 2010 (the Vault requires a
login), Orkin's own GOAP page (it no longer exists), and forum threads on
gamedev.net, which refused the request. A gap worth stating: no peer-reviewed
head-to-head of HTN against classical planning in games turned up. The
comparison here rests on the surveys and on Humphreys' report from one studio.
