# The game-AI literature against this kit, and a roadmap

<!-- doc-meta
half_life: concept
verified_on: 2026-11-06
tier: 0
source: https://aima.cs.berkeley.edu/contents.html
invalidated_if: a module, a demo or a source named in the table changes, or a task of the roadmap (T84-T101) lands and changes what the kit has
teaches: none
-->

> What the field's standard sources teach, set against what this kit has:
> for each technique, where the literature puts it and whether the kit has
> it -- which module, which demo. Then a roadmap the owner chooses from,
> and the questions to answer before any of it becomes a task (T73).
>
> The house rule of `docs/concepts/`: a source is cited only if it was
> opened; one read in part says which part; a figure that cannot be
> sourced is not given. Every source below was opened on 2026-10-22. Most
> were read **in part** -- a book by its published table of contents, a
> chapter by its opening pages -- and each reference says which. What
> could not be opened is listed at the end and not used. The kit's own
> research pages (`racing-ai.md`, `shooter-ai.md`, `stealth-ai.md`,
> `rts-ai.md`, `fighting-game-ai.md`, `planning-in-strategy-games.md`)
> are reused, not redone: where a row leans on one, it says so.

## The short version

- **The kit already covers most of what a game-AI course teaches about
  deciding**: search and paths, adversarial search, classical planning,
  GOAP, HTN, state machines, behaviour trees, utility choice, fuzzy
  logic, steering, perception, influence maps, tactical positions,
  supervised learning, cloning, an opponent model, and MENACE's
  reinforcement learning.
- **Its biggest gaps are the ones AIMA spends whole chapters on**: Monte
  Carlo tree search (AIMA 5.4), constraint satisfaction (ch. 6),
  probabilistic reasoning over time (ch. 14) and sequential decisions --
  MDPs, bandits, POMDPs (ch. 17). And two of the game-AI books' own
  topics: a **director** that paces a level [Booth 2009; Brewer 2021],
  and **procedural content generation** [Smith 2015; Yannakakis &
  Togelius, part III].
- **Several techniques live in one game only.** `ai_opponent` is used by
  the fighting game alone, `ai_adversarial` by checkers alone,
  `ai_rts_core` by the RTS alone (`modules/*.json`). Until a second game
  configures them, the claim of T58-T63 -- that an addon is a module any
  game can use -- is shown for them only once. `ai_fuzzy` and
  `ai_teamwork` have just gained their second: the infiltration guards
  (T69, T70).

## How to read the table

One row per technique. **Literature** is where the sources opened here put
it: AIMA by chapter and section (4th ed.), *Game AI Pro* by book and
chapter, *Artificial Intelligence and Games* (Yannakakis & Togelius,
"Y&T") by chapter, Millington's *AI for Games* by chapter title only.
**Known for** is the kind of game it is known for, with a shipped game
only where a source opened here names it. **In the kit** names a module
from `modules/*.json`, a path, or says `not in the kit`; **Demos** names
the make target that shows it. **Tier** is the `tier:` field of the kit's
own page that teaches it (README: 0 reading, 1 Python, 2 Godot); a 2 means
no page teaches it and only the Godot code shows it. For a technique the
kit lacks, it is the tier its lesson would need -- never above 1
(invariant 5). `scripts/check_literature_table.py` holds every name in the
last three columns to the repository.

### Search, paths and movement

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Uninformed search (breadth-first, depth-first) | AIMA 3.4; Millington ch. 4 | puzzles, grids | `ai_search` | `demo-search` | 0 |
| A\* and Dijkstra | AIMA 3.5-3.6; GAP1 ch. 17-18 | every game that moves | `ai_search`, `ai_core` | `demo-search`, `demo-stealth`, `demo-botmatch` | 0 |
| Faster grid search (JPS+, subgoal graphs, goal bounding) | GAP2 ch. 14-15; GAP3 ch. 22-23 | large static grids | not in the kit | -- | 1 |
| Flow fields | GAP1 ch. 23 | crowds, RTS | `ai_rts_core` | `demo-rts` | 1 |
| A cost flood to every node within a limit | GAP Online 2021 ch. 6 (*Dishonored 2*) | stealth chase, hearing round walls | `ai_search`, `godot/addons/ai_search/cost_flood.gd` | `demo-infiltration` | 1 |
| Local search and evolutionary optimisation | AIMA 4.1-4.2; Y&T 3.3, 8.2 | tuning, search-based content | not in the kit | -- | 1 |
| Steering (seek, arrive, pursue, avoid) | Millington ch. 3; Booth 2009 (reactive path following) | vehicles, crowds | `ai_steering` | `demo-steering`, `demo-racing` | 1 |
| A lookahead point and a speed profile (pure pursuit) | GAP1 ch. 38-39 (via `racing-ai.md`) | racing | `demo_racing`, `godot/demos/racing/racing_driver.gd` | `demo-racing` | 1 |
| PID control, a racing line, a heat line | GAP1 ch. 38-41 (via `racing-ai.md`) | racing | `ai_steering`, `racing3d` | `demo-racing3d` | 1 |
| Rubber-banding | GAP1 ch. 42 (via `racing-ai.md`) | racing | refused on purpose -- difficulty without a rubber band: `docs/concepts/racing-ai.md` | `demo-racing` | 1 |

### Adversarial search and games

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Minimax and alpha-beta | AIMA 5.2-5.3; Millington ch. 8 | board games | `ai_adversarial`, `checkers` | `run` | 0 |
| A learned evaluation (Samuel) | AIMA 5.3 (heuristic evaluation); kit's `learned-evaluation.md` | checkers | `checkers`, `python/gameaikit/checkers` | `run` | 1 |
| Monte Carlo tree search, UCT | AIMA 5.4; Browne et al. 2012; GAP2 ch. 25; GAP3 ch. 28 | Go, strategy and card games | `ai_adversarial`, `godot/addons/ai_adversarial/mcts.gd`; the XCOM mode's second enemy, `squad` | `demo-tactical` | 0 |
| Stochastic and partially observable games | AIMA 5.5-5.6 | dice, cards, fog of war | expectiminimax, `godot/addons/ai_adversarial/expectiminimax.gd`, in `ai_adversarial`, against MCTS in the XCOM mode, `squad`; fog searched on one guess (a single determinization) there, and with no reasoning over it in `rts` | `demo-tactical`, `demo-rts` | 0 |

### Constraints and content

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Constraint satisfaction (propagation, backtracking) | AIMA ch. 6; GAP2 ch. 26 | placing items and enemies in rooms | AC-3 and backtracking with MRV and LCV, seeded and twinned: `ai_constraints`; the infiltration level declared and solved: `godot/game3d/infiltration/level_constraints.gd` (T95); `docs/concepts/constraint-satisfaction.md` | `demo-infiltration` | 1 |
| Wave function collapse | mxgmn's README | tile levels (*Bad North*, *Townscaper*, *Caves of Qud*) | not in the kit | -- | 1 |
| Procedural content generation | GAP2 ch. 40; Y&T ch. 7-9 | replayability (*Elite*, per GAP2 ch. 40) | a seed's arena for tests only: `godot/test/botmatch/random_arena.gd` | -- | 1 |
| Story sifting (Felt; Winnow, incremental) | Kreminski et al. 2019 and 2021; Ryan 2018 | emergent narrative: the moments of a simulation worth retelling | Felt-style patterns over a plain event list, twinned, read-only: `ai_sifting`; the valley's chronicle: `godot/game/valley/valley_chronicle.gd`; Winnow's incremental matching is not in the kit | `demo-valley` | 1 |

### Deciding: authored behaviour and planning

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Finite state machines | Millington ch. 5; Orkin 2006 | almost every game (Orkin) | `ai_behaviour` | `demo-behaviour`, `demo-rts` | 0 |
| Behaviour trees | GAP1 ch. 6; GAP3 ch. 9, 11 | *Final Fantasy XV* (GAP3 ch. 11) | `ai_behaviour` | `demo-behaviour`, `demo-tactical` | 0 |
| Classical planning (STRIPS, PDDL, heuristics) | AIMA 11.1-11.3 | strategy | `ai_planning`, `python/gameaikit/pddl` | `demo-rts`, `demo-tactical` | 1 |
| GOAP | Orkin 2006 | *F.E.A.R.* | `ai_behaviour` | `demo-behaviour`, `demo-tactical` | 0 |
| HTN planning | AIMA 11.4; GAP1 ch. 12 | strategy, squads | `ai_behaviour` | `demo-behaviour`, `demo-rts` | 0 |
| Utility choice (scored considerations) | AIMA ch. 16; GAP1 ch. 9; GAP3 ch. 13, 31 | *Dragon Age: Inquisition* (GAP3 ch. 31); *Guild Wars 2* (via `shooter-ai.md`) | `ai_utility`, `godot/addons/ai_utility/action_choice.gd` | `demo-botmatch`, `demo-infiltration` | 1 |
| Fuzzy logic | Millington ch. 5 (via `stealth.md`) | suspicion, soft thresholds | `ai_fuzzy`, `godot/game3d/infiltration/fuzzy_from_data.gd` | `demo-stealth`, `demo-infiltration` | 0 |

### Space, perception and teams

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Influence maps | GAP2 ch. 29-30; GAP Online 2021 ch. 6 | shooters, RPGs, strategy | three: `godot/addons/ai_perception/influence_map.gd`, `godot/addons/ai_teamwork/team_influence.gd`, `godot/game/rts/rts_influence.gd` | `demo-stealth`, `demo-botmatch`, `demo-rts` | 0 |
| Tactical position selection | GAP1 ch. 26; GAP3 ch. 24, 26 | shooters, *Paragon* (GAP3 ch. 24) | `ai_teamwork`, `godot/addons/ai_teamwork/tactical_positions.gd` | `demo-botmatch` | 1 |
| Perception: sight, hearing, light, awareness, memory | Millington ch. 10 (title); the kit's `stealth-ai.md` | stealth | `ai_perception`, `infiltration` | `demo-stealth`, `demo-behaviour`, `demo-infiltration` | 0 |
| Team coordination (claims, a commander, squads and their confidence, retreat, a search divided, roles) | AIMA 18.1 (title); the kit's `shooter-ai.md`, `stealth-ai.md` | team shooters, guards that search together | `ai_teamwork`, `godot/addons/ai_teamwork/squad_confidence.gd`, `godot/addons/ai_teamwork/search_coordinator.gd`, `godot/addons/ai_teamwork/role_arbiter.gd` | `demo-botmatch`, `demo-infiltration` | 1 |
| A frame budget | Millington ch. 9 (title) | RTS, many agents | `ai_rts_core`, `godot/addons/ai_rts_core/frame_budget.gd` | `demo-rts` | 2 |

### Uncertainty and sequential decisions

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Bayesian networks | AIMA ch. 13 | reasoning under uncertainty | discrete variables and hand-written tables, exact inference by enumeration and each sign's influence, twinned: `ai_bayes`; the guard's "is anyone there?" from a noise, a door found open and a partner gone quiet: `godot/game3d/infiltration/guard_suspicion.gd` (T115) | `demo-infiltration` | 1 |
| Tracking over time: a grid belief, HMMs, Kalman and particle filters | AIMA ch. 14; GAP Online 2021 ch. 6 | chasing an unseen player | a grid belief that spreads and is cleared where seen: `godot/addons/ai_perception/belief_map.gd`; a particle filter with a transition and a sensor model, seeded and twinned: `godot/addons/ai_perception/particle_belief.gd` (T91) | `demo-infiltration` | 1 |
| MDPs, value and policy iteration | AIMA 17.1-17.2 | small grid worlds | the maze solved in Python, its policy looked up: `python/gameaikit/mdp/`, `godot/game/maze/mdp_pac_man.gd`; `docs/concepts/mdp.md` | `demo-maze` | 1 |
| Bandits (UCB1, regret matching) | AIMA 17.3; GAP2 ch. 25 | choosing among strategies by their payoff | UCB1, and epsilon-greedy for the comparison (not regret matching), counted during one fight (ADR 0016, N13): `ai_bandit`, `godot/game/fighting/fight_bandit_opponent.gd` (T99) | `demo-fighting` | 1 |
| POMDPs | AIMA 17.4-17.5 | acting on beliefs | not in the kit | -- | 1 |
| Game theory (non-cooperative) | AIMA 18.2 | mixed strategies | not in the kit | -- | 1 |

### Learning, players and difficulty

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Supervised learning (logistic, softmax) | AIMA ch. 19; Y&T 3.5 | evaluation, decisions | `ai_learning`, `python/gameaikit/training` | `demo-skirmish`, `demo-tactical` | 1 |
| Neural networks and deep learning | AIMA ch. 21; GAP1 ch. 30; Y&T 3.6 | threat response (GAP1 ch. 30) | not in the kit | -- | 1 |
| Reinforcement learning | AIMA ch. 22; Y&T 3.7 | self-play | MENACE: `tictactoe`, `python/gameaikit/menace` | `demo-tictactoe` | 1 |
| Imitation: behaviour cloning | AIMA 22.6; the kit's `behaviour-cloning.md` | ghosts of players | `ai_learning`, `python/gameaikit/cloning` | `demo-fighting` | 1 |
| An n-gram opponent model | GAP1 ch. 48 | fighting games | `ai_opponent` | `demo-fighting` | 1 |
| Player modelling | Y&T ch. 10-12 | experience, retention | an opponent counted during one fight only (ADR 0016): `ai_opponent`; how well the person plays, counted during one bot match and setting the other team's aim from a fixed table (ADR 0016, N14): `godot/game3d/botmatch/player_model.gd` (T100) | `demo-fighting`, `demo-botmatch` | 1 |
| Difficulty as named knobs | GAP3 ch. 33 | shooters, racing, fighting | `godot/addons/ai_planning/difficulty.gd`, `racing3d`, `godot/game/fighting/fight_opponent.gd`, `godot/game/rts/rts_commander.gd` | `demo-racing3d`, `demo-tactical`, `demo-fighting`, `demo-rts` | 1 |
| A director that paces the action | Booth 2009; GAP Online 2021 ch. 7 | *Left 4 Dead*, *Warframe* | not in the kit | -- | 1 |
| Rating players and agents (a league) | the kit's `the-league.md` | ladders | `league` | `make league` | 1 |

### Language

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| LLM agents (memory, reflection, planning) | AIMA ch. 23-24; Y&T 5.5; Park et al. 2023 | a simulated town (Park et al.) | a model as one more decider, behind a validator (memory, reflection and planning are not in the kit): `ai_llm`, its lesson in `python/gameaikit/llm/`; the text game is T94 | -- | 1 |

The LLM row's tier is its lesson's: recorded answers replayed in Python,
tier 1, as invariant 5 asks. Running a model live is tier 3 and optional.

### Agents, logic and robots: the framing chapters

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Intelligent agents (percepts, actions, an agent program) | AIMA ch. 2 | framing for every bot | framing only: the bot match's bot reads its percepts and nothing else (T67), `botmatch` | `demo-botmatch` | 1 |
| Logic and knowledge representation | AIMA ch. 7-10 | rule-based characters | not in the kit | -- | 1 |
| Robotics: perception, planning and control of motion | AIMA ch. 26 | -- | framing only: control (PID) and a measured car, `racing3d` | `demo-racing3d` | 1 |

## What the table says

1. **The decision layer is well covered; the probabilistic layer is
   not.** AIMA part IV -- chapters 12 to 18 -- is nearly absent: the kit's
   only reasoning over time under uncertainty is the guard's belief grid, which spreads
   and is cleared where seen and has no sensor model -- and, since T91, a
   particle filter beside it that has one. MCTS and bandits,
   the two that GAP2 ch. 25 presents for games, are missing too *(no
   longer: MCTS since T86, bandits since T99)*.
2. **Nothing generates content as a lesson.** The bot match makes arenas
   from a seed, but only to test that bots cope on maps they were not
   tuned on (`random_arena.gd`); no page teaches a generator. CSP and
   wave function collapse are the cheapest way in, both tier 1 *(CSP
   since T95: the infiltration level, drawn or declared)*.
3. **Nothing paces a level.** The *Left 4 Dead* director estimates each
   survivor's "emotional intensity" and removes threats when it runs high
   [Booth 2009]; *Warframe* does the same over procedural levels [Brewer
   2021]. The kit has difficulty only as fixed knobs.
4. **Three technique addons are shown in one game only** (above). That is
   a statement about the interface, not the technique: an addon used once
   may have its game's assumptions baked in, and only a second game finds
   them.

## The roadmap

Written on 2026-10-22 as T73's proposal, before the owner chose, and kept
as written. **Where the owner's answers of 2026-10-26 changed it, it is
superseded** -- the answers, after the questions, say how, and each
statement below that no longer holds is marked *(superseded)* with the
task that replaces it. Ranked by what each adds
for its size. Every entry names the invariants it touches: **6** (no
training at game time) and **7** (the LLM never blocks a frame, and its
output passes a validator). Invariant 6 is about **fitting**, not about
what is saved: a component stays inside it while every number it uses is
fixed -- written by hand, or fitted in Python and shipped -- and it only
computes a state from what it sees. ADR 0016 is the one exception, and it
covers `ai_opponent`'s n-gram table alone *(superseded: since its
amendment of 2026-10-26 it covers three named components -- the n-gram,
the bandit of T99 and the difficulty model of T100 -- and nothing else
without the owner)*, on three conditions: it only
counts (no descent), it starts empty every fight, and it can be rebuilt
from the fight's log. Sizes use the tasks' S/M/L.

### A. Techniques the kit does not have

1. **MCTS (UCT) on a board game people know.** Teaches sampling instead of
   an evaluation function, and anytime search: stop it whenever, it has
   an answer. Where: Connect Four, or Othello -- known games where minimax
   needs a good evaluation and MCTS needs none; or the tactical game as a
   second, harder home (GAP3 ch. 28 is about exactly that). It would be
   a new module beside `ai_adversarial`, with a Python twin. Tier 1. Size
   M. Invariants: none (it searches, it does not learn). *(Superseded:
   the home is an XCOM-style mode of the tactical game, T84-T87, and MCTS
   goes inside `ai_adversarial`, not beside it -- invariant 2 would make a
   separate addon copy the game interface; T86.)*
2. **A director that paces a level.** Teaches adapting the game, not the
   enemy: measure intensity, then build up, peak, relax [Booth 2009].
   Where: the infiltration level (T70) or the bot match -- the director
   decides when and where guards or bots arrive. Tier 1 (the intensity
   curve is a Python twin). Size M. **Invariant 6**: a director stays
   inside it while every number it uses -- how much intensity a hit adds,
   how fast it decays, the peak, how long to relax -- is fixed, and it
   only computes the players' intensity from what it sees and fits
   nothing. Booth's design is that: a value raised by damage, decaying
   over time, against thresholds [Booth 2009].
3. **Tracking an unseen player: a particle filter over the belief grid.**
   Teaches AIMA ch. 14 on a problem the kit already has: T69's belief
   spreads blindly; a particle filter moves hypotheses by the player's
   possible motion and weighs them by what each guard did *not* see.
   Where: the infiltration level, as a switch beside the belief (the
   "it finds you sooner" claim measured again). Tier 1. Size M.
   Invariants: none.
4. **CSP, then wave function collapse, for levels.** Teaches declaring
   what a solution is instead of how to find it [Foged & Horswill 2015],
   and WFC as a CSP [mxgmn]. Where: generated infiltration levels or
   tactical maps, with a gate that every generated level is solvable.
   Tier 1. Size M (CSP) + S (WFC on top). Invariants: none. *(Now: CSP in
   the infiltration level, T95; WFC on maps for the tactical game's XCOM
   mode, T96.)*
5. **MDP and value iteration on a small grid game.** Teaches the step from
   search to sequential decisions under chance (AIMA ch. 17). Where: a
   known small game -- *Frozen Lake*-style ice, or a Pac-Man maze with
   one ghost. Tier 1. Size S. **Invariant 6**: value iteration runs in
   Python and the policy is shipped, as the kit's other models are.
   *(Now: the Pac-Man maze, T97 and T98, size M each.)*
6. **Bandits to choose among scripted strategies.** Teaches exploration
   against exploitation (AIMA 17.3; GAP2 ch. 25). Where: the fighting
   game's opponent picking among its fixed plans, or the RTS commander
   among build orders. Tier 1. Size S. **Invariant 6, squarely**: a
   bandit learns from payoffs at game time. It needs a new decision by
   the owner extending ADR 0016 to it, on the same three conditions:
   counts only, empty at the start of every fight, rebuildable from the
   fight's log. *(Decided: ADR 0016's amendment of 2026-10-26; the
   fighting opponent, T99.)*
7. **`ai_llm`.** Teaches an LLM as one more decider, behind a validator.
   Where: the tactical game's orders, or a guard's spoken report in the
   infiltration level. Tier 3 to run for real, with a tier-1 lesson
   through recorded answers. Size L. **Invariant 7** throughout: never
   on the frame, and nothing it says becomes an action without passing a
   validator. *(Superseded: its example is the owner's own idea, a text
   game where you talk your way past a guard, T92-T94, not the tactical
   game's orders.)*
8. **Player modelling for difficulty.** Teaches estimating skill from
   play (Y&T ch. 10-12; GAP3 ch. 33 on accuracy). Where: any demo with
   difficulty knobs. **Invariant 6**: a player model that estimates skill
   during play is learning at game time, whether it saves anything or not
   -- ADR 0016 covers only the n-gram table. Any version needs a new
   decision by the owner extending ADR 0016 to it, on the same three
   conditions (counts only, empty at the start, rebuildable from a log);
   a model fitted in Python from recordings and shipped fixed needs none.
   *(Superseded: "ADR 0016 covers only the n-gram table" no longer holds;
   the owner extended it to this model on the same three conditions --
   its amendment of 2026-10-26 -- and its home is the bot match, T100.)*

### B. A second game for a technique the kit has

*(Of these, only B.2 (T88) and B.6 (T101) are on the roadmap, as the
owner answered; B.1 was done in T70; B.3, B.4 and B.5 are not tasks.)*

1. **`ai_teamwork` in the infiltration level** -- done in T70 (wave
   80): the guards use its utility choice, and it gained a search
   coordinator and a role arbiter. Listed to show the shape of a second
   use: what the bot match had assumed came out when the guards used it.
2. **`ai_adversarial` in a second board game** -- the same game as A.1,
   so MCTS and alpha-beta face the same position. What it shows: whether
   `GakAdversarialGame` is an interface or checkers' shape. Done in T88
   (wave 136), as expectiminimax in the XCOM mode: the interface held --
   the searches and the squad's game needed nothing it did not already
   say, `outcomes` included.
3. **`ai_opponent` outside the fighting game** -- an n-gram predicting a
   rock-paper-scissors player, or the RTS commander predicting the
   player's next build. What it shows: whether the predictor assumes
   fighting-game inputs. Invariant 6 holds: it counts during one match.
4. **`ai_rts_core`'s flow fields for a crowd elsewhere** -- the bot
   match's respawns, or a tower defence. What it shows: whether the flow
   field needs the RTS world.
5. **One interface for the kit's three influence maps.** Today there are
   three, each with its own rule: the RTS's (`rts_influence.gd`, key I in
   `make demo-rts`), where influence **adds up** -- two squads hold a
   region twice as firmly; `ai_perception`'s, where a cell keeps the
   **strongest watcher**, because two guards watching one cell make it no
   more watched; and `ai_teamwork`'s team influence in the bot match.
   What a shared interface would show: whether the combining rule is the
   only difference, so that one map with a pluggable rule serves a
   strategic and a tactical game [Mark 2015].
6. **Utility choice as its own addon** -- done in T101 (wave 103).
   `ActionChoice` and `ErrandChoice` lived in `ai_teamwork`, though
   nothing in them is about teams, and the bot match and the infiltration
   guards both use them. They are `ai_utility` now, with their Python
   twins and vectors, unchanged, so a game takes utility choice without
   taking teamwork.

### A new game, or the ones there are?

*(Superseded on 2026-10-26: no Connect Four or Othello. MCTS and B.2 go
to an XCOM-style mode of the tactical game -- a mode, not a new game;
bandits to the fighting game; `ai_llm` to a new text game; the MDP to a
small Pac-Man maze. The paragraph below is T73's proposal.)*

Most entries fit a demo that exists: the infiltration level takes the
director, the particle filter and the generated levels; the tactical game
takes MCTS, bandits and `ai_llm`. Two need a new game, both small and
known: **Connect Four or Othello** (A.1, B.2), and **a small maze game**
for MDPs (A.5). The owner's rule -- build on games people already know --
points to those over anything invented.

## Perguntas para o dono / Questions for the owner

Responda por número; as tarefas são escritas depois das respostas.
Answer by number; the tasks are written after the answers.

1. **pt-BR:** Quais entradas da parte A entram no roadmap, e em que ordem?
   A recomendação é A.1 (MCTS), A.2 (diretor), A.3 (filtro de partículas).
   **en:** Which entries of part A go on the roadmap, and in what order?
   The recommendation is A.1 (MCTS), A.2 (director), A.3 (particle filter).
2. **pt-BR:** Para MCTS e um segundo jogo de tabuleiro: Lig 4 (Connect
   Four), Othello, ou o jogo tático?
   **en:** For MCTS and a second board game: Connect Four, Othello, or the
   tactical game?
3. **pt-BR:** Bandits (A.6) aprendem com o resultado durante o jogo. Você
   estende a exceção da ADR 0016 a eles, nas mesmas três condições (só
   contagens, vazio no começo de cada luta, reconstruível a partir do log
   da luta), ou ficam de fora?
   **en:** Bandits (A.6) learn from payoffs at game time. Do you extend
   ADR 0016's exception to them, on the same three conditions (counts
   only, empty at the start of every fight, rebuildable from the fight's
   log), or do they stay out?
4. **pt-BR:** Modelagem do jogador para dificuldade (A.8) é aprender
   durante o jogo, salvando ou não. Ela fica de fora, entra só como um
   modelo treinado em Python a partir de gravações e enviado fixo, ou
   você estende a ADR 0016 a ela nas mesmas três condições?
   **en:** Player modelling for difficulty (A.8) is learning at game time,
   whether it saves anything or not. Does it stay out, come in only as a
   model fitted in Python from recordings and shipped fixed, or do you
   extend ADR 0016 to it on the same three conditions?
5. **pt-BR:** Quais "segundo jogo" da parte B entram? A recomendação é B.2
   junto com A.1, e B.6 (utilidade como addon próprio).
   **en:** Which "second game" entries of part B go in? The recommendation
   is B.2 together with A.1, and B.6 (utility as its own addon).
6. **pt-BR:** Um jogo novo pequeno de labirinto para MDP (A.5) vale a
   pena, ou o MDP fica só como página e Python, sem demo?
   **en:** Is a small new maze game for MDPs (A.5) worth it, or does the
   MDP stay a page and Python, with no demo?
7. **pt-BR:** `ai_llm` (A.7; a lição no tier 1, rodar ao vivo no tier 3)
   entra agora no roadmap ou continua para depois da biblioteca (T64)?
   **en:** Does `ai_llm` (A.7; its lesson at tier 1, running live at
   tier 3) go on the roadmap now, or wait until after the library (T64)?

## Respostas do dono / The owner's answers (2026-10-26)

**pt-BR:** O dono respondeu às sete perguntas em 2026-10-26. As tarefas
estão em `tasks/` e na seção "The roadmap after T73" de `tasks/STATUS.md`;
cada decisão em aberto nelas está escrita para o dono confirmar na revisão.

1. "todos" -- todas as entradas da parte A, primeiro as três recomendadas:
   MCTS (T84-T89), o diretor (T90), o filtro de partículas (T91); depois
   `ai_llm` (T92-T94), CSP e WFC (T95, T96), o MDP (T97, T98), bandits
   (T99) e a modelagem do jogador (T100).
2. "será que pode ser estilo X-com?" -- confirmado: um **modo** estilo
   XCOM do jogo tático, no mesmo módulo `board`, não um jogo novo nem uma
   reescrita do tático atual. O modo entra pelo próprio cartão e pela
   própria cena do jogo tático, com o mesmo estado (`BoardState`), o mesmo
   mapa, as mesmas peças e teclas; o que muda é o conjunto de regras: tiro
   com chance de acerto, cobertura, duas ações, névoa (T84, T85). O MCTS
   joga nele (T86, T87) e o alpha-beta o enfrenta como expectiminimax
   (T88).
3. "faz o recomendado pensando em didática de IA" -- a pergunta não
   recomendava nenhuma das duas respostas; a emenda da ADR 0016 lê as
   palavras do dono como **estender** a exceção ao bandit, nas três
   condições; o dono confirmou essa leitura em 2026-10-29, como
   recomendado (a T99 escreve a regra N13).
4. Opção 3 -- a ADR 0016 se estende ao modelo do jogador para dificuldade
   nas mesmas três condições (T100 escreve a regra N14). A exceção cobre
   três componentes, pelo nome; qualquer outro precisa de nova decisão.
5. "segue o recomendado" -- B.2 junto com A.1 (T88) e B.6, utilidade como
   addon próprio (T101).
6. Um labirinto pequeno estilo **Pac-Man** (T97), iteração de valor em
   Python e a política enviada pronta (T98).
7. `ai_llm` "entra agora", não depois da T64. O exemplo é ideia do dono:
   "algum exemplo de jogo textual de narrativa que envolve algum desafio
   narrativo de conversar com um agente por texto rodando uma LLM local"
   (T94); o addon e o portão da invariante 7 em T92, o runtime local em T93.

**en:** The owner answered the seven questions on 2026-10-26. The tasks
are in `tasks/` and in `tasks/STATUS.md`'s "The roadmap after T73"
section; every open decision in them is written down for the owner to
confirm in review.

1. "todos" -- every entry of part A, the recommended three first: MCTS
   (T84-T89), the director (T90), the particle filter (T91); then `ai_llm`
   (T92-T94), CSP and WFC (T95, T96), the MDP (T97, T98), bandits (T99)
   and player modelling (T100).
2. "será que pode ser estilo X-com?" -- confirmed: an XCOM-style **mode**
   of the tactical game on the same `board` module, not a new game and not
   a rewrite of the existing tactical game. The mode is entered from the
   tactical game's own card and scene, on the same state (`BoardState`),
   map, pieces and keys; what changes is the ruleset: a shot with a hit
   chance, cover, two actions, fog (T84, T85). MCTS plays it (T86, T87)
   and alpha-beta faces it as expectiminimax (T88).
3. "faz o recomendado pensando em didática de IA" -- the question
   recommended neither answer; ADR 0016's amendment reads the owner's
   words as **extend** the exception to the bandit, on its three
   conditions; the owner confirmed that reading on 2026-10-29, as
   recommended (T99 writes rule N13).
4. Option 3 -- ADR 0016 extends to the player model for difficulty on the
   same three conditions (T100 writes rule N14). The exception covers
   three components by name; any other needs a new decision.
5. "segue o recomendado" -- B.2 together with A.1 (T88), and B.6, utility
   choice as its own addon (T101).
6. A small **Pac-Man**-style maze (T97), value iteration in Python and the
   policy shipped (T98).
7. `ai_llm` "entra agora", not after T64. Its example is the owner's own
   idea -- a text narrative game whose challenge is talking, by text, to an
   agent run by a local LLM (T94); the addon and invariant 7's gate in
   T92, the local runtime in T93.

## Could not be checked

Not used above:

- Buckland, *Programming Game AI by Example* (2004): the publisher's page
  refused the fetch, and no table of contents was opened.
- The *AI Game Programming Wisdom* series: no table of contents opened.
- Isla, "Handling Complexity in the Halo 2 AI", GDC 2005: not opened.
  GAP1 ch. 6 cites it as [Isla 05] in its introduction; the part of the
  chapter read does not name the game, so *Halo 2* is not used above.
- Mark, "Building a Better Centaur: AI at Massive Scale", GDC 2015: the
  GDC Vault page needs a login; [Mark 2015] above is the GAP2 chapter.
- HTN in *Killzone* and *Horizon Zero Dawn*: no developer source opened
  for this page (see `shooter-ai.md` for Killzone's tactics).
- *Game AI Pro 360*: not opened as a collection; its chapters are the
  three books' and the online editions'.

## References

All opened on 2026-10-22.

Textbooks, by their published contents:

- Russell, S., Norvig, P. *Artificial Intelligence: A Modern Approach*,
  4th ed. The full table of contents, with section titles for chapters
  3-6, 11, 14, 17, 18, 21-24 and 26; no chapter text read.
  <https://aima.cs.berkeley.edu/contents.html>
- Yannakakis, G. N., Togelius, J. *Artificial Intelligence and Games*,
  2nd ed., Springer, 2025. The table of contents only ("Y&T"); the
  edition and year are from the book's home page, which calls it "This
  second edition of the 2018 textbook", not from the contents page.
  <https://gameaibook.org/toc/>, <https://gameaibook.org/>
- Millington, I. *AI for Games*, 3rd ed., CRC Press, 2019. Chapter titles
  only, from the publisher's page.
  <https://www.routledge.com/AI-for-Games/Millington/p/book/9781138483972>
- Rabin, S. (ed.) *Game AI Pro* 1-3 and the Online Edition 2021: the
  index of chapters ("GAP1", "GAP2", "GAP3", "GAP Online 2021"); chapters
  named but not opened are cited by title only.
  <https://www.gameaipro.com/>

Chapters and papers, the first pages read:

- Booth, M. "The AI Systems of Left 4 Dead." Valve, 2009; slides read in
  part: the goals, path following and the director's pacing.
  <https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf>
- Brewer, D. "Managing Pacing in Procedural Levels in Warframe." Game AI
  Pro Online Edition 2021, ch. 7; the introduction.
  <http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter07_Managing_Pacing_in_Procedural_Levels_in_Warframe.pdf>
- Browne, C. et al. "A Survey of Monte Carlo Tree Search Methods." IEEE
  Transactions on Computational Intelligence and AI in Games 4(1), 2012;
  the abstract and introduction.
  <https://turing.iimas.unam.mx/~luis/cursos/IA2022-1/lecturas/SurveyMCTS.pdf>
- Champandard, A. J., Dunstan, P. "The Behavior Tree Starter Kit." Game
  AI Pro, 2013, ch. 6; the introduction (section 6.1) only.
  <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter06_The_Behavior_Tree_Starter_Kit.pdf>
- Couvidou, L. "Flooding the Influence Map for Chase in Dishonored 2."
  Game AI Pro Online Edition 2021, ch. 6; the introduction.
  <http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter06_Flooding_the_Influence_Map_for_Chase_in_Dishonored_2.pdf>
- Foged, L., Horswill, I. "Rolling Your Own Finite-Domain Constraint
  Solver." Game AI Pro 2, 2015, ch. 26; the introduction.
  <http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter26_Rolling_Your_Own_Finite-Domain_Constraint_Solver.pdf>
- Graham, D. "An Introduction to Utility Theory." Game AI Pro, 2013,
  ch. 9; the first two sections.
  <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf>
- Humphreys, T. "Exploring HTN Planners through Example." Game AI Pro,
  2013, ch. 12; the introduction.
  <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf>
- Mark, D. "Modular Tactical Influence Maps." Game AI Pro 2, 2015,
  ch. 30; the introduction (Mark 2015).
  <http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter30_Modular_Tactical_Influence_Maps.pdf>
- mxgmn. *WaveFunctionCollapse*, README on GitHub; read in full.
  <https://github.com/mxgmn/WaveFunctionCollapse>
- Ocio Barriales, S. "Using Your Combat AI Accuracy to Balance
  Difficulty." Game AI Pro 3, 2017, ch. 33; the introduction.
  <http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter33_Using_Your_Combat_AI_Accuracy_to_Balance_Difficulty.pdf>
- Orkin, J. "Three States and a Plan: The A.I. of F.E.A.R." GDC 2006;
  the first two pages.
  <https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf>
- Park, J. S. et al. "Generative Agents: Interactive Simulacra of Human
  Behavior." arXiv:2304.03442, 2023; the abstract.
  <https://arxiv.org/abs/2304.03442>
- Smith, G. "Procedural Content Generation: An Overview." Game AI Pro 2,
  2015, ch. 40; the introduction (Smith 2015).
  <http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter40_Procedural_Content_Generation_An_Overview.pdf>
- Sturtevant, N. R. "Monte Carlo Tree Search and Related Algorithms for
  Games." Game AI Pro 2, 2015, ch. 25; the introduction and background.
  <http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter25_Monte_Carlo_Tree_Search_and_Related_Algorithms_for_Games.pdf>
