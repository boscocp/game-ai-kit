# game-ai-kit

Teaching AI in games, one readable piece at a time.

> Em português: [README.pt-BR.md](README.pt-BR.md).

A set of Godot 4 addons you can take **one at a time**, plus small games,
most of them versions of games you know, where each of them actually decides
something. The code is written to be read: if a passage is fast and
unreadable, it loses to the slow and readable one.

> Status: every technique in the table below has a page explaining it, in
> English and Portuguese, and at least one demo where it decides something;
> `make menu` opens them all. Nothing is published to the Godot Asset Store
> or PyPI yet; `make release` builds the zips and the wheel, and
> [docs/howto/publish.md](docs/howto/publish.md) is how they will be published.

## What it covers

<!-- catalogue:summary -->
<!-- written by scripts/catalogue.py: edit the inputs, then `make catalogue` -->

The AI is what this kit is about, so here it is both ways round, generated from the modules' manifests and the menu's cards. ● the demo's own code uses the technique; ◐ it reaches it through another example's code. [The catalogue](docs/techniques/catalogue.md) has the whole matrix, the keys that show each decision, and how the marks are measured.

| technique | what it decides | algorithms | where to watch it |
| --- | --- | --- | --- |
| [ai_adversarial](docs/techniques/ai_adversarial.md) | the best move against someone who answers | minimax with alpha-beta, Monte Carlo tree search, expectiminimax with a hand-written evaluation | ● [`make run`](docs/techniques/catalogue.md#run), ● [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical) |
| [ai_bandit](docs/techniques/ai_bandit.md) | which option to try next? | a bandit, UCB1 | ● [`make demo-fighting`](docs/techniques/catalogue.md#demo-fighting) |
| [ai_behaviour](docs/techniques/ai_behaviour.md) | what to do next | state machine, behaviour tree, GOAP, HTN | ● [`make demo-behaviour`](docs/techniques/catalogue.md#demo-behaviour), ● [`make demo-rts`](docs/techniques/catalogue.md#demo-rts), ● [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical) |
| [ai_constraints](docs/techniques/ai_constraints.md) | what must hold, and a solver that finds it | constraint satisfaction, AC-3 and backtracking, wave function collapse | ● [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration), ● [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical) |
| [ai_fuzzy](docs/techniques/ai_fuzzy.md) | how much, by degrees | fuzzy logic | ● [`make demo-stealth`](docs/techniques/catalogue.md#demo-stealth), ● [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration), ◐ [`make demo-behaviour`](docs/techniques/catalogue.md#demo-behaviour) |
| [ai_learning](docs/techniques/ai_learning.md) | using what Python learned | a regression trained in Python, the ghost's case lookup | ◐ [`make demo-skirmish`](docs/techniques/catalogue.md#demo-skirmish), ● [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical), ● [`make demo-fighting`](docs/techniques/catalogue.md#demo-fighting) |
| [ai_llm](docs/techniques/ai_llm.md) | a language model behind a validator | a language model reading discourse acts, behind a validator | ● [`make demo-talk`](docs/techniques/catalogue.md#demo-talk) |
| [ai_opponent](docs/techniques/ai_opponent.md) | what will the player do next? | n-gram | ● [`make demo-fighting`](docs/techniques/catalogue.md#demo-fighting) |
| [ai_perception](docs/techniques/ai_perception.md) | what a guard sees, hears and believes | vision cone with line of sight and hearing, influence map, vision shape with light and hearing, awareness, belief map | ● [`make demo-stealth`](docs/techniques/catalogue.md#demo-stealth), ● [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.md#demo-botmatch), ● [`make demo-behaviour`](docs/techniques/catalogue.md#demo-behaviour) |
| [ai_planning](docs/techniques/ai_planning.md) | the steps to a goal nobody wrote down | STRIPS over PDDL | ● [`make demo-rts`](docs/techniques/catalogue.md#demo-rts), ● [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical) |
| [ai_rts_core](docs/techniques/ai_rts_core.md) | many units, one frame | flow fields | ● [`make demo-rts`](docs/techniques/catalogue.md#demo-rts) |
| [ai_search](docs/techniques/ai_search.md) | finding a route | A*, BFS, DFS, Dijkstra | ● [`make demo-skirmish`](docs/techniques/catalogue.md#demo-skirmish), ● [`make demo-search`](docs/techniques/catalogue.md#demo-search), ● [`make demo-stealth`](docs/techniques/catalogue.md#demo-stealth), ● [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.md#demo-botmatch), ● [`make demo-behaviour`](docs/techniques/catalogue.md#demo-behaviour) |
| [ai_steering](docs/techniques/ai_steering.md) | which way to push, and how hard | seek, arrive, pursue, avoid, PID controller, heat line | ● [`make demo-steering`](docs/techniques/catalogue.md#demo-steering), ● [`make demo-racing`](docs/techniques/catalogue.md#demo-racing), ● [`make demo-racing3d`](docs/techniques/catalogue.md#demo-racing3d) |
| [ai_teamwork](docs/techniques/ai_teamwork.md) | a team that shares the work | a shared search, role arbiter, tactical positions with claims, team commander over influence, squad confidence and retreat in waves | ● [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.md#demo-botmatch) |
| [ai_utility](docs/techniques/ai_utility.md) | weighing every option at once | utility-weighed actions | ● [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration), ● [`make demo-botmatch`](docs/techniques/catalogue.md#demo-botmatch), ● [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical) |
| [MENACE](docs/techniques/menace.md) | the matchbox machine that learns noughts and crosses | MENACE's matchboxes | ● [`make demo-tictactoe`](docs/techniques/catalogue.md#demo-tictactoe) |
| [Learned evaluation](docs/techniques/learned_evaluation.md) | scoring a position by weights fitted to results | a learned evaluation | ● [`make run`](docs/techniques/catalogue.md#run) |
| [Behaviour cloning](docs/techniques/behaviour_cloning.md) | the fighter that plays like you | behaviour cloning | ● [`make demo-fighting`](docs/techniques/catalogue.md#demo-fighting) |
| [The racing driver](docs/techniques/racing_driver.md) | a point ahead, a speed profile, no rubber band | pure pursuit, speed profile | ● [`make demo-racing`](docs/techniques/catalogue.md#demo-racing), ● [`make demo-racing3d`](docs/techniques/catalogue.md#demo-racing3d) |

| demo | like | the AI in it |
| --- | --- | --- |
| [`make run`](docs/techniques/catalogue.md#run) Checkers | checkers, you against the computer | ● [ai_adversarial](docs/techniques/ai_adversarial.md): minimax with alpha-beta; ● [Learned evaluation](docs/techniques/learned_evaluation.md): a learned evaluation |
| [`make demo-skirmish`](docs/techniques/catalogue.md#demo-skirmish) The skirmish | a small Advance Wars battle | ◐ [ai_learning](docs/techniques/ai_learning.md): a regression trained in Python; ● [ai_search](docs/techniques/ai_search.md): A* |
| [`make demo-tictactoe`](docs/techniques/catalogue.md#demo-tictactoe) Noughts and crosses | tic-tac-toe, against Michie's matchbox machine | ● [MENACE](docs/techniques/menace.md): MENACE's matchboxes; inside the example: perfect play by minimax |
| [`make demo-search`](docs/techniques/catalogue.md#demo-search) Four searches | the click-to-move of any strategy game, slowed down to one cell at a time | ● [ai_search](docs/techniques/ai_search.md): BFS, DFS, Dijkstra, A* |
| [`make demo-stealth`](docs/techniques/catalogue.md#demo-stealth) Stealth | the top-down stealth of the first Metal Gear | ● [ai_fuzzy](docs/techniques/ai_fuzzy.md): fuzzy logic; ● [ai_perception](docs/techniques/ai_perception.md): vision cone with line of sight and hearing, influence map; ● [ai_search](docs/techniques/ai_search.md): A* |
| [`make demo-steering`](docs/techniques/catalogue.md#demo-steering) Steering | the enemies of an action game chasing and stopping, one force at a time | ● [ai_steering](docs/techniques/ai_steering.md): seek, arrive, pursue, avoid |
| [`make demo-racing`](docs/techniques/catalogue.md#demo-racing) Racing | Micro Machines, seen from above, the AI in the same car as yours | ● [ai_steering](docs/techniques/ai_steering.md): seek; ● [The racing driver](docs/techniques/racing_driver.md): pure pursuit, speed profile |
| [`make demo-racing3d`](docs/techniques/catalogue.md#demo-racing3d) Racing in 3D | Gran Turismo, on tyres that slip | ● [ai_steering](docs/techniques/ai_steering.md): PID controller, heat line; ● [The racing driver](docs/techniques/racing_driver.md): speed profile, pure pursuit; inside the example: measured grip |
| [`make demo-infiltration`](docs/techniques/catalogue.md#demo-infiltration) Infiltration | Metal Gear Solid, in third person | ● [ai_constraints](docs/techniques/ai_constraints.md): constraint satisfaction, AC-3 and backtracking; ● [ai_fuzzy](docs/techniques/ai_fuzzy.md): fuzzy logic; ● [ai_perception](docs/techniques/ai_perception.md): vision shape with light and hearing, awareness, belief map; ● [ai_search](docs/techniques/ai_search.md): A*; ● [ai_teamwork](docs/techniques/ai_teamwork.md): a shared search, role arbiter; ● [ai_utility](docs/techniques/ai_utility.md): utility-weighed actions; inside the example: a director pacing the threats by intensity |
| [`make demo-botmatch`](docs/techniques/catalogue.md#demo-botmatch) Bot match | a bot match in Unreal Tournament or Counter-Strike | ● [ai_perception](docs/techniques/ai_perception.md); ● [ai_search](docs/techniques/ai_search.md): A*; ● [ai_teamwork](docs/techniques/ai_teamwork.md): tactical positions with claims, team commander over influence, squad confidence and retreat in waves; ● [ai_utility](docs/techniques/ai_utility.md): utility-weighed actions |
| [`make demo-behaviour`](docs/techniques/catalogue.md#demo-behaviour) One guard, four ways to decide | a guard on its rounds, as in Metal Gear or Thief | ● [ai_behaviour](docs/techniques/ai_behaviour.md): state machine, behaviour tree, GOAP, HTN; ◐ [ai_fuzzy](docs/techniques/ai_fuzzy.md); ● [ai_perception](docs/techniques/ai_perception.md); ● [ai_search](docs/techniques/ai_search.md) |
| [`make demo-rts`](docs/techniques/catalogue.md#demo-rts) Real-time strategy | StarCraft or Age of Empires, against a commander that plans | ● [ai_behaviour](docs/techniques/ai_behaviour.md): HTN, state machine; ● [ai_planning](docs/techniques/ai_planning.md): STRIPS over PDDL; ● [ai_rts_core](docs/techniques/ai_rts_core.md): flow fields; inside the example: priority queue of wishes, utility over regions, influence map |
| [`make demo-tactical`](docs/techniques/catalogue.md#demo-tactical) Tactics | Advance Wars, or XCOM | ● [ai_adversarial](docs/techniques/ai_adversarial.md): Monte Carlo tree search, expectiminimax with a hand-written evaluation; ● [ai_behaviour](docs/techniques/ai_behaviour.md): state machine, behaviour tree, GOAP, HTN; ● [ai_constraints](docs/techniques/ai_constraints.md): wave function collapse; ● [ai_learning](docs/techniques/ai_learning.md): a regression trained in Python; ● [ai_planning](docs/techniques/ai_planning.md): STRIPS over PDDL; ● [ai_utility](docs/techniques/ai_utility.md): utility-weighed actions; inside the example: hand-written rules, lookahead with exact odds, influence map |
| [`make demo-maze`](docs/techniques/catalogue.md#demo-maze) Pac-Man, a small maze | Pac-Man, you against Blinky | inside the example: a target tile and the shortest straight line, value iteration, an MDP's policy |
| [`make demo-talk`](docs/techniques/catalogue.md#demo-talk) Talk your way past the guard | Suck Up!, talking your way in | ● [ai_llm](docs/techniques/ai_llm.md): a language model reading discourse acts, behind a validator |
| [`make demo-fighting`](docs/techniques/catalogue.md#demo-fighting) Fighting, training mode | Street Fighter's training mode, against a dummy that learns how you play | ● [ai_bandit](docs/techniques/ai_bandit.md): a bandit, UCB1; ● [ai_learning](docs/techniques/ai_learning.md): the ghost's case lookup; ● [ai_opponent](docs/techniques/ai_opponent.md): n-gram; ● [Behaviour cloning](docs/techniques/behaviour_cloning.md): behaviour cloning; inside the example: hand-written rules, reaction delay |

<!-- /catalogue:summary -->

`ai_llm` -- a language model as one more decider, with everything it says
validated before it becomes an action ([its page](docs/techniques/ai_llm.md))
-- has its addon, its validator, a local runtime and a text game that uses
them, `make demo-talk`: its recorded lines need no GPU, and live typing
needs the tier 3 server below.

`ai_core` sits under all of them, and is small on purpose: the grid
(`GakGridGraph`), the pathfinder interface (`GakPathfinder`) and one seeded
generator (`GakXorshift`). Take any one addon
and `ai_core` with it, and nothing else. The examples' own board -- its
state, units, moves and the `DecisionPolicy` typed on them -- is in
`godot/game/board/`, the examples' kernel (ADR 0021).

Machine learning is applied to **specific pieces**, never to the whole game.
That is the point. A logistic regression that decides *attack or retreat* has
weights you can print and explain. A neural network that plays the whole game
teaches nothing.

## Will it run on my machine?

Four tiers. **No lesson lives only in the expensive tier.**

| tier | you need | you can |
|---|---|---|
| **0** | nothing | read `docs/concepts/` — the algorithms and why they work |
| **1** | Python 3.12 or later -- check with `python3 --version`; macOS's own and some Linux LTS releases (Ubuntu 22.04, Debian 12) are older | read a PDDL domain and check it, train the regressions, read the weights. Standard library only — **no pip, no numpy, no install step** |
| **2** | Godot 4 (~130 MB, runs on integrated graphics) | play the game, open the demos, modify the addons |
| **2, in 3D** | Godot 4 and integrated graphics that draw a 3D scene (measured: about 1,000 fps for the 3D test arena on a Radeon 610M, 1280×720 -- a 2022 chip, newer than the 2015 floor below; nothing older was measured) | the 3D examples in `godot/game3d/`, with `make assets-3d` for their models or plain shapes without; their decisions run on snapshots with Python twins, so the lesson is tier 1 (ADR 0018) |
| **3** | a GPU with some VRAM | run a local LLM for real, through `ai_llm`'s `HttpRuntime`: `make llm-bootstrap` installs llama.cpp's server and a model in the toolchain, each file by sha256 (about 5 GB; measured on 12 GB of VRAM, a reply in under a second), `make llm-serve` runs it, `make llm-smoke` checks it (see [docs/local-llm/](docs/local-llm/bakeoff.md)); generate your own art with a local image model (`make artgen-bootstrap`, then `make artgen`; see [the how-to](docs/howto/generate-art.md)). Optional: the CC0 art is committed and is the default, so nothing needs this tier |

The game targets 1280×720 at 60 fps on integrated graphics, using the
Compatibility (OpenGL) renderer. The 2D kit has no 3D nodes and no large
assets; the 3D examples live apart in `godot/game3d/`, on the same renderer,
and their models are downloaded, never committed (ADR 0018).

The LLM addon has two runtimes — `RecordedRuntime` (recorded replies,
needing nothing) and `HttpRuntime` (a local OpenAI-compatible server; see
tier 3 above). The recorded one is not a consolation prize: it is what the
tests use, and it teaches the part that matters most, which is
**validating a model's output before it becomes an action**.

## What you will see

`make menu` opens on all of them, each with a card saying what its AI
decides, which techniques decide it and what to watch; the cards live in
[`godot/menu/catalogue.json`](godot/menu/catalogue.json).

<!-- Recordings pending: headless Godot rasterises nothing, so no command in
this repository can capture one. Recording them is a person's job. -->

**Checkers** (`make run`). You are red and move first, against the computer
as white. Click a piece and the squares it can reach turn green -- a
multi-jump one hop per click, the pieces it will take crossed out. When a
capture is compulsory, the pieces that can take are ringed. On white's turn
the board shows every move it considered, with its value -- white's lead at
the end of the line it expects -- and the pink arrow is what it will play.
The panel lists them best first and spells out that line. Space plays the
move. Keys 1–6 set how far it looks, and the panel says how many positions
that cost and how many replies alpha-beta skipped.

**The skirmish** (`make demo-skirmish`). A 12×8 board, a wall down the
middle with rough ground on either side, and two nodes worth taking. Red is
yours: click a unit,
click a neighbouring cell, space ends the turn. Blue is played by the trained
models, and under the status line each blue unit says what it decided and the
number it decided on. End your first turn without moving and it says: *unit 3
attacks unit 2: p(win) 0.97 at or above 0.50*, and *unit 4 retreats from unit
2: p(win) 0.33 below 0.50*.

**Noughts and crosses** (`make demo-tictactoe`). MENACE, Donald Michie's
1961 machine of matchboxes and beads, plays crosses and moves first. On its
turn every empty square shows how many beads its box holds for that move,
and the chance of drawing one. Space draws. Keys 1–4 swap in the machine
after 10, 100, 1,000 or 10,000 games of training -- done beforehand in
Python -- and M shows what perfect play makes of each square.

**The search demo** (`make demo-search`). Four searches on a board you can
paint. Keys 1–4 choose the algorithm, space reveals the next cell it
expanded, enter reveals the rest. On the first board breadth-first walks
through the mud; Dijkstra goes round having spread out in rings; A\* goes
round having expanded 90 cells to Dijkstra's 125. Then change it: left-drag
paints wall, mud or open ground (W, M, G), right-drag erases, the dots drag,
and B steps through a maze, an open field and a trap for depth-first. Every
change searches again, and a goal walled off is answered "no route".

**Tactics** (`make demo-tactical`). Turns in the style of Advance Wars, you
as red against the computer as blue, over a river with one bridge and a
slow ford at each end. Click a
unit and everywhere it can reach lights up; click a lit cell and it walks
there and greys out until your next turn. Z takes back, space ends the turn.
W has a unit wait. Blue moves second, and starts with one more shield for
it. Blue plays by rules -- build what beats the most of your pieces, walk
every unit at your workshop -- and C hands it to the planner, the learned
policy, or one of three difficulty levels (easy, normal, hard) that differ
only in how much they think -- never in what they are given; S swaps sides,
so you can play blue against the computer as red. Each of the computer's
decisions is drawn in pink, with why, before space plays it (enter plays
the rest).
Click an enemy in reach to attack it, once a turn: a fight is dice, the
counter table and cover tilt it -- attacking at even health, a piece the
table favours wins about 19 fights in 20 -- and the loser is removed. Bolt towers fire
by themselves at the start of their side's turn. Two flags are control
points: a side with a walker on one and no enemy beside it is paid 2 more at
the start of its turn. The other side's threat map -- every cell it could
strike next turn, by path, so the river blocks it -- is tinted red; T hides
it. Destroy the enemy workshop -- a siege, one blow an
attack -- to win; after 40 rounds the higher score wins (workshop health,
then point-turns held, then what is left standing), and only an equal
score is a draw.

The other demos -- stealth, steering, racing in 2D and 3D, infiltration,
the bot match, the guard's four ways to decide, real-time strategy, the
Pac-Man maze, the talk game and the fighting dummy -- are described in
[the catalogue](docs/techniques/catalogue.md), each with the keys
that show its decision. No demo has a recording yet.

## Getting started

Tier 1, with nothing but Python:

```bash
python3 -m unittest discover -s python/tests -t python
PYTHONPATH=python python3 -m gameaikit.tactical.report   # what the models learned
```

Tier 2, with the engine:

```bash
make bootstrap     # downloads the pinned Godot and its Linux export templates into .toolchain/, SHA-512 verified
make menu          # every example on one menu: a card says what its AI decides and how; Esc comes back
make run           # checkers against minimax and alpha-beta
make demo-skirmish # the learned policy plays blue on the skirmish board
make demo-tictactoe # MENACE, the matchbox machine, at four ages of training
make demo-search   # the four searches on a board you can paint
make demo-tactical # Advance Wars style turns against the computer, at three levels
make check         # every gate
```

`make bootstrap` serves Linux on x86_64, and Windows through Git Bash: the
same targets, [the how-to](docs/howto/windows.md). Not macOS yet: there it
would fetch the Linux build. It puts about 1.5 GB (Godot, and the export
templates `make export` needs) in `.toolchain/` inside the clone, ignored by
git, and writes nothing into your home's own folders. To keep it elsewhere
-- another disk, one copy for several clones -- set one variable, before
`make bootstrap`; every target and script reads it:

```bash
export GAK_TOOLCHAIN=/path/to/toolchain
```

To change the kit, read [CONTRIBUTING.md](CONTRIBUTING.md). `tasks/` and
`docs/reviews/` are the project's working history -- why each piece was
built and what its review found -- and a reader after one technique can
skip them.

## Using one addon in your own project

```bash
make release       # dist/: one zip per addon, the Python wheel, and the menu as a Linux executable
```

Publishing them is the owner's, by hand: [docs/howto/publish.md](docs/howto/publish.md).

`make export` alone builds the executable into `dist/game-ai-kit-linux/`
and starts it headless before it counts; `make release` zips it with
`LICENSE` and `NOTICE` beside the binary, and only when it was exported from
the commit at HEAD with nothing uncommitted.

Unzip `ai_core-<version>.zip` and the addon you want into your project's
`res://addons/`. There is no plugin to enable: every class registers itself
with `class_name`. Each zip carries `LICENSE`, `NOTICE` and `VERSION`, and the
release step refuses to call a build good until a separate gate has opened
every archive and found them. The decisions behind all this are in
[`docs/adr/`](docs/adr/).

The whole way, both halves -- unzip, import, a first decision in your
scene, the wheel, training in Python for the game to read -- is
[using the library](docs/techniques/using-the-library.md)
([em português](docs/techniques/using-the-library.pt-BR.md)), and
`make library-check` follows it step by step outside the repository.

## Licence, and what the credit actually obliges

Apache-2.0. Use it in a commercial game, modify it, ship it.

Redistribution must carry `LICENSE` and `NOTICE`, which is how the author's name
travels with the code — in practice it shows up on a third-party-licenses
screen. Being straight about it: **the licence does not oblige a line in your
game's credits.** The one that does (the Attribution Assurance License) is
obscure enough that using it would cost every user to buy a credit nobody grants
willingly.

So the credit is a request, not a requirement. If the kit helped, this is enough:

```
AI routines: game-ai-kit by Adalberto Pereira
```

## When not to use this

The addons are written for clarity, not for throughput. The A\* here is slower
than an implementation with a tuned binary heap and flattened arrays. If you are
pathfinding for hundreds of units per frame, use Godot's built-in `AStarGrid2D`
— and then come back here to understand what it is doing.

## Acknowledgements

The predecessor of this project was
[Intelligent-Agent-SDK](https://github.com/boscocp/Intelligent-Agent-SDK) (2020,
Unity, C#), itself following *Artificial Intelligence: A Modern Approach*. The
algorithms are the book's; the mistakes are mine.
