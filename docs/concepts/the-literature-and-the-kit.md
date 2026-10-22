# The game-AI literature against this kit, and a roadmap

<!-- doc-meta
half_life: concept
verified_on: 2026-10-22
tier: 0
source: https://aima.cs.berkeley.edu/contents.html
invalidated_if: a module, a demo or a source named in the table changes, or the owner answers the questions at the end and the roadmap is written as tasks
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
- **Several techniques live in one game only.** `ai_teamwork` is used by
  the bot match alone, `ai_opponent` by the fighting game alone,
  `ai_adversarial` by checkers alone, `ai_rts_core` by the RTS alone
  (`modules/*.json`). Until a second game configures them, the claim of
  T58-T63 -- that an addon is a module any game can use -- is shown for
  them only once. `ai_fuzzy` has just gained its second (the infiltration
  guards, T69).

## How to read the table

One row per technique. **Literature** is where the sources opened here put
it: AIMA by chapter and section (4th ed.), *Game AI Pro* by book and
chapter, *Artificial Intelligence and Games* (Yannakakis & Togelius,
"Y&T") by chapter, Millington's *AI for Games* by chapter title only.
**Known for** is the kind of game it is known for, with a shipped game
only where a source opened here names it. **In the kit** names a module
from `modules/*.json`, a path, or says `not in the kit`; **Demos** names
the make target that shows it. **Tier** is the lowest tier where the kit
teaches it (README: 0 reading, 1 Python, 2 Godot), or -- for a technique
the kit lacks -- the tier it would need. `scripts/check_literature_table.py`
holds every name in the last three columns to the repository.

### Search, paths and movement

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Uninformed search (breadth-first, depth-first) | AIMA 3.4; Millington ch. 4 | puzzles, grids | `ai_search` | `demo-search` | 0 |
| A\* and Dijkstra | AIMA 3.5-3.6; GAP1 ch. 17-18 | every game that moves | `ai_search`, `ai_core` | `demo-search`, `demo-stealth`, `demo-botmatch` | 0 |
| Faster grid search (JPS+, subgoal graphs, goal bounding) | GAP2 ch. 14-15; GAP3 ch. 22-23 | large static grids | not in the kit | -- | 1 |
| Flow fields | GAP1 ch. 23 | crowds, RTS | `ai_rts_core` | `demo-rts` | 1 |
| A cost flood to every node within a limit | GAP Online 2021 ch. 6 (*Dishonored 2*) | stealth chase, hearing round walls | `ai_search`, `godot/addons/ai_search/cost_flood.gd` | -- | 1 |
| Local search and evolutionary optimisation | AIMA 4.1-4.2; Y&T 3.3, 8.2 | tuning, search-based content | not in the kit | -- | 1 |
| Steering (seek, arrive, pursue, avoid) | Millington ch. 3; Booth 2009 (reactive path following) | vehicles, crowds | `ai_steering` | `demo-steering`, `demo-racing` | 0 |
| PID control, a racing line, a heat line | GAP1 ch. 38-41 (via `racing-ai.md`) | racing | `ai_steering`, `racing3d` | `demo-racing3d` | 1 |

### Adversarial search and games

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Minimax and alpha-beta | AIMA 5.2-5.3; Millington ch. 8 | board games | `ai_adversarial`, `checkers` | `run` | 1 |
| A learned evaluation (Samuel) | AIMA 5.3 (heuristic evaluation); kit's `learned-evaluation.md` | checkers | `checkers`, `python/gameaikit/checkers` | `run` | 1 |
| Monte Carlo tree search, UCT | AIMA 5.4; Browne et al. 2012; GAP2 ch. 25; GAP3 ch. 28 | Go, strategy and card games | not in the kit | -- | 1 |
| Stochastic and partially observable games | AIMA 5.5-5.6 | dice, cards, fog of war | not in the kit | -- | 1 |

### Constraints and content

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Constraint satisfaction (propagation, backtracking) | AIMA ch. 6; GAP2 ch. 26 | placing items and enemies in rooms | not in the kit | -- | 1 |
| Wave function collapse | mxgmn's README | tile levels (*Bad North*, *Townscaper*, *Caves of Qud*) | not in the kit | -- | 1 |
| Procedural content generation | GAP2 ch. 40; Y&T ch. 7-9 | replayability (*Elite*, per GAP2 ch. 40) | a seed's arena for tests only: `godot/test/botmatch/random_arena.gd` | -- | 1 |

### Deciding: authored behaviour and planning

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Finite state machines | Millington ch. 5; Orkin 2006 | almost every game (Orkin) | `ai_behaviour` | `demo-behaviour`, `demo-rts` | 0 |
| Behaviour trees | GAP1 ch. 6; GAP3 ch. 9, 11 | *Halo 2* (cited in GAP1 ch. 6), *Final Fantasy XV* | `ai_behaviour` | `demo-behaviour`, `demo-tactical` | 0 |
| Classical planning (STRIPS, PDDL, heuristics) | AIMA 11.1-11.3 | strategy | `ai_planning`, `python/gameaikit/pddl` | `demo-rts`, `demo-tactical` | 1 |
| GOAP | Orkin 2006 | *F.E.A.R.* | `ai_behaviour` | `demo-behaviour`, `demo-tactical` | 0 |
| HTN planning | AIMA 11.4; GAP1 ch. 12 | strategy, squads | `ai_behaviour` | `demo-behaviour`, `demo-rts` | 0 |
| Utility choice (scored considerations) | AIMA ch. 16; GAP1 ch. 9; GAP3 ch. 13, 31 | *Dragon Age: Inquisition* (GAP3 ch. 31); *Guild Wars 2* (via `shooter-ai.md`) | `ai_teamwork`, `godot/addons/ai_teamwork/action_choice.gd` | `demo-botmatch` | 1 |
| Fuzzy logic | the kit's `stealth.md` (no source opened here places it) | suspicion, soft thresholds | `ai_fuzzy` | `demo-stealth` | 1 |

### Space, perception and teams

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Influence maps | GAP2 ch. 29-30; GAP Online 2021 ch. 6 | shooters, RPGs, strategy | `ai_perception`, `godot/addons/ai_perception/influence_map.gd`, `godot/addons/ai_teamwork/team_influence.gd` | `demo-stealth`, `demo-botmatch` | 1 |
| Tactical position selection | GAP1 ch. 26; GAP3 ch. 24, 26 | shooters, *Paragon* (GAP3 ch. 24) | `ai_teamwork`, `godot/addons/ai_teamwork/tactical_positions.gd` | `demo-botmatch` | 1 |
| Perception: sight, hearing, light, awareness, memory | Millington ch. 10 (title); the kit's `stealth-ai.md` | stealth | `ai_perception`, `infiltration` | `demo-stealth`, `demo-behaviour` | 1 |
| Team coordination (claims, a commander, squads) | AIMA 18.1, 18.3 (titles); the kit's `shooter-ai.md` | team shooters | `ai_teamwork` | `demo-botmatch` | 1 |
| A frame budget | Millington ch. 9 (title) | RTS, many agents | `ai_rts_core`, `godot/addons/ai_rts_core/frame_budget.gd` | `demo-rts` | 2 |

### Uncertainty and sequential decisions

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| Bayesian networks | AIMA ch. 13 | reasoning under uncertainty | not in the kit | -- | 1 |
| Tracking over time: a grid belief, HMMs, Kalman and particle filters | AIMA ch. 14; GAP Online 2021 ch. 6 | chasing an unseen player | a grid belief that spreads and is cleared where seen: `godot/addons/ai_perception/belief_map.gd` | -- | 1 |
| MDPs, value and policy iteration | AIMA 17.1-17.2 | small grid worlds | not in the kit | -- | 1 |
| Bandits (UCB1, regret matching) | AIMA 17.3; GAP2 ch. 25 | choosing among strategies by their payoff | not in the kit | -- | 1 |
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
| Player modelling | Y&T ch. 10-12 | experience, retention | an opponent counted during one fight only (ADR 0016): `ai_opponent` | `demo-fighting` | 1 |
| Difficulty as named knobs | GAP3 ch. 33; GAP1 ch. 42 (via `racing-ai.md`) | shooters, racing | `godot/addons/ai_planning/difficulty.gd`, `racing3d` | `demo-racing3d`, `demo-tactical` | 1 |
| A director that paces the action | Booth 2009; GAP Online 2021 ch. 7 | *Left 4 Dead*, *Warframe* | not in the kit | -- | 1 |
| Rating players and agents (a league) | the kit's `the-league.md` | ladders | `league` | `make league` | 1 |

### Language

| Technique | Literature | Known for | In the kit | Demos | Tier |
|---|---|---|---|---|---|
| LLM agents (memory, reflection, planning) | AIMA ch. 23-24; Y&T 5.5; Park et al. 2023 | a simulated town (Park et al.) | not in the kit (an ai\_llm addon is planned, README tier 3) | -- | 3 |

## What the table says

1. **The decision layer is well covered; the probabilistic layer is
   not.** AIMA part IV -- chapters 12 to 18 -- is nearly absent: the kit's
   only reasoning over time under uncertainty is the guard's belief grid, which spreads
   and is cleared where seen and has no sensor model. MCTS and bandits,
   the two that GAP2 ch. 25 presents for games, are missing too.
2. **Nothing generates content as a lesson.** The bot match makes arenas
   from a seed, but only to test that bots cope on maps they were not
   tuned on (`random_arena.gd`); no page teaches a generator. CSP and
   wave function collapse are the cheapest way in, both tier 1.
3. **Nothing paces a level.** The *Left 4 Dead* director estimates each
   survivor's "emotional intensity" and removes threats when it runs high
   [Booth 2009]; *Warframe* does the same over procedural levels [Brewer
   2021]. The kit has difficulty only as fixed knobs.
4. **Four technique addons are shown in one game only** (above). That is
   a statement about the interface, not the technique: an addon used once
   may have its game's assumptions baked in, and only a second game finds
   them.

## The roadmap

The owner chooses; nothing below is a task yet. Ranked by what each adds
for its size. Every entry names the invariants it touches: **6** (no
training at game time; ADR 0016's count during one fight is the only
exception the owner has made) and **7** (the LLM never blocks a frame,
and its output passes a validator). Sizes use the tasks' S/M/L.

### A. Techniques the kit does not have

1. **MCTS (UCT) on a board game people know.** Teaches sampling instead of
   an evaluation function, and anytime search: stop it whenever, it has
   an answer. Where: Connect Four, or Othello -- known games where minimax
   needs a good evaluation and MCTS needs none; or the tactical game as a
   second, harder home (GAP3 ch. 28 is about exactly that). It would be
   a new module beside `ai_adversarial`, with a Python twin. Tier 1. Size
   M. Invariants: none (it searches, it does not learn).
2. **A director that paces a level.** Teaches adapting the game, not the
   enemy: measure intensity, then build up, peak, relax [Booth 2009].
   Where: the infiltration level (T70) or the bot match -- the director
   decides when and where guards or bots arrive. Tier 1 (the intensity
   curve is a Python twin). Size M. **Invariant 6**: a director reads the
   player's state now and keeps nothing between sessions; it must be
   written so, and said so -- it adapts, it does not learn.
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
   Tier 1. Size M (CSP) + S (WFC on top). Invariants: none.
5. **MDP and value iteration on a small grid game.** Teaches the step from
   search to sequential decisions under chance (AIMA ch. 17). Where: a
   known small game -- *Frozen Lake*-style ice, or a Pac-Man maze with
   one ghost. Tier 1. Size S. **Invariant 6**: value iteration runs in
   Python and the policy is shipped, as the kit's other models are.
6. **Bandits to choose among scripted strategies.** Teaches exploration
   against exploitation (AIMA 17.3; GAP2 ch. 25). Where: the fighting
   game's opponent picking among its fixed plans, or the RTS commander
   among build orders. Tier 1. Size S. **Invariant 6, squarely**: a
   bandit learns from payoffs at game time. It fits only inside ADR
   0016's exception -- counts kept for one fight, starting empty, never
   saved -- and that needs the owner's word.
7. **`ai_llm`.** Teaches an LLM as one more decider, behind a validator.
   Where: the tactical game's orders, or a guard's spoken report in the
   infiltration level. Tier 3 to run for real, with a tier-1 lesson
   through recorded answers. Size L. **Invariant 7** throughout: never
   on the frame, and nothing it says becomes an action without passing a
   validator.
8. **Player modelling for difficulty.** Teaches estimating skill from
   play (Y&T ch. 10-12; GAP3 ch. 33 on accuracy). Where: any demo with
   difficulty knobs. **Invariant 6**: as asked, it is learning at game
   time and outside ADR 0016. Only a version that models the player
   within one session and saves nothing could be written without a new
   decision by the owner.

### B. A second game for a technique the kit has

1. **`ai_teamwork` in the infiltration level** -- already happening:
   T70 adds a search coordinator and a role arbiter there (in review).
   What the second use shows: whether claims and a commander are about
   teams or about the bot match's arena.
2. **`ai_adversarial` in a second board game** -- the same game as A.1,
   so MCTS and alpha-beta face the same position. What it shows: whether
   `AdversarialGame` is an interface or checkers' shape.
3. **`ai_opponent` outside the fighting game** -- an n-gram predicting a
   rock-paper-scissors player, or the RTS commander predicting the
   player's next build. What it shows: whether the predictor assumes
   fighting-game inputs. Invariant 6 holds: it counts during one match.
4. **`ai_rts_core`'s flow fields for a crowd elsewhere** -- the bot
   match's respawns, or a tower defence. What it shows: whether the flow
   field needs the RTS world.
5. **Influence maps shared by the RTS and the bot match.** Today there
   are two (`influence_map.gd` in `ai_perception`, `team_influence.gd` in
   `ai_teamwork`). What it shows: whether one interface serves a strategic
   and a tactical map [Mark 2015].
6. **Utility choice as its own addon.** `ActionChoice` and `ErrandChoice`
   live in `ai_teamwork`, though nothing in them is about teams. Moving
   them out, used by the bot match and the infiltration guards, would
   show they are general.

### A new game, or the ones there are?

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
   autoriza estender a exceção da ADR 0016 (contar durante uma luta,
   começando vazio, nunca salvo) a eles, ou ficam de fora?
   **en:** Bandits (A.6) learn from payoffs at game time. Do you extend
   ADR 0016's exception (counted during one fight, starting empty, never
   saved) to them, or do they stay out?
4. **pt-BR:** Modelagem do jogador para dificuldade (A.8): fica de fora,
   ou só a versão que não salva nada entre sessões?
   **en:** Player modelling for difficulty (A.8): out, or only the version
   that saves nothing between sessions?
5. **pt-BR:** Quais "segundo jogo" da parte B entram? A recomendação é B.2
   junto com A.1, e B.6 (utilidade como addon próprio).
   **en:** Which "second game" entries of part B go in? The recommendation
   is B.2 together with A.1, and B.6 (utility as its own addon).
6. **pt-BR:** Um jogo novo pequeno de labirinto para MDP (A.5) vale a
   pena, ou o MDP fica só como página e Python, sem demo?
   **en:** Is a small new maze game for MDPs (A.5) worth it, or does the
   MDP stay a page and Python, with no demo?
7. **pt-BR:** `ai_llm` (A.7, tier 3) entra agora no roadmap ou continua
   para depois da biblioteca (T64)?
   **en:** Does `ai_llm` (A.7, tier 3) go on the roadmap now, or wait
   until after the library (T64)?

## Could not be checked

Not used above:

- Buckland, *Programming Game AI by Example* (2004): the publisher's page
  refused the fetch, and no table of contents was opened.
- The *AI Game Programming Wisdom* series: no table of contents opened.
- Isla, "Handling Complexity in the Halo 2 AI", GDC 2005: not opened;
  *Halo 2* appears above only as GAP1 ch. 6 cites it.
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
  2nd ed., Springer, 2025. The table of contents only ("Y&T").
  <https://gameaibook.org/toc/>
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
  AI Pro, 2013, ch. 6; the introduction.
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
- mxgmn. *WaveFunctionCollapse*, README on GitHub; read in full.
  <https://github.com/mxgmn/WaveFunctionCollapse>
- Humphreys, T. "Exploring HTN Planners through Example." Game AI Pro,
  2013, ch. 12; the introduction.
  <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter12_Exploring_HTN_Planners_through_Example.pdf>
- Mark, D. "Modular Tactical Influence Maps." Game AI Pro 2, 2015,
  ch. 30; the introduction (Mark 2015).
  <http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter30_Modular_Tactical_Influence_Maps.pdf>
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
