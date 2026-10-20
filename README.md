# game-ai-kit

Teaching AI in games, one readable piece at a time.

A set of Godot 4 addons you can take **one at a time**, plus a small turn-based
strategy game where each of them actually decides something. The code is written
to be read: if a passage is fast and unreadable, it loses to the slow and
readable one.

> Status: the first vertical slice is complete -- a board, four searches, a
> STRIPS planner and two trained regressions, each with a page explaining it.
> Nothing is published to the Asset Library yet; `make release` builds the zips.

## What it covers

| piece | what it decides | where you see it | read |
|---|---|---|---|
| `ai_adversarial` | minimax and alpha-beta — the best move, *given that the opponent replies as well as it can* | plays white in `make run`, and draws every move it considered with its value | [why](docs/concepts/minimax.md) |
| learned checkers evaluation, in `python/gameaikit/checkers/` | logistic regression on self-play results -- what a position is worth to the search | E in `make run` switches white to it, and the panel shows each count's share of the score | [why](docs/concepts/learned-evaluation.md) |
| MENACE, in `python/gameaikit/menace/` | reinforcement learning with 304 matchboxes — which move in noughts and crosses | plays crosses in `make demo-tictactoe`, its beads on every square | [why](docs/concepts/menace.md) |
| `ai_search` | A\*, BFS, DFS, Dijkstra — how a unit gets there | routes blue's units in `make demo-skirmish` | [why](docs/concepts/search.md) · [how](docs/godot/search.md) |
| `ai_planning` | STRIPS — *to attack I need a unit; to have a unit I need resources* | C in `make demo-tactical` hands blue to a plan that decides what to buy -- the forge, then a ram for the siege -- listed step by step, with the pieces it counts on numbered on the board | [why](docs/concepts/planning.md) · [how](docs/godot/planning.md) |
| `ai_behaviour` | a state machine, a behaviour tree, GOAP and an HTN -- the same guard written four ways, and a table of when each is right | `make demo-behaviour`: 1-4 swap the guard's brain mid-round, and the screen shows its state, its tree's path, or its plan | [the table](godot/addons/ai_behaviour/ways_to_decide.gd) · [why](docs/concepts/planning-in-strategy-games.md) |
| `ai_learning` | logistic regression — attack or retreat; linear regression — which target is closer to falling | plays blue in `make demo-skirmish`, and says why on screen | [why](docs/concepts/learning.md) · [how](docs/godot/learning.md) |
| `ai_opponent` | an n-gram over the player's actions -- what you do after what, counted during the fight | the "learner" modes of `make demo-fighting`, its table and its guess on the panel | [ADR 0016](docs/adr/0016-an-opponent-model-counts-during-the-fight.md) |
| behaviour cloning, in `python/gameaikit/cloning/` and `ai_learning` | a softmax model and two ghosts fitted to a recorded player -- what it would do here | the "ghost" and "clone" modes of `make demo-fighting`; `make record-fights` records you | [why, and what it bought](docs/concepts/behaviour-cloning.md) -- on the owner's nine fights the n-gram guessed best, and a person could not tell the clone, the ghosts and the learner apart |
| `ai_rts_core` | the state an RTS needs: a world that mutates a fixed tick at a time, flow fields shared by a whole army, one door for every command, each side shown only its own fogged snapshot, and a match that replays from its seed | no demo yet -- T20 builds it; `make test-rts-simulation` plays a scripted match headless, at some 65 times real time | [ADR 0019](docs/adr/0019-two-cores-one-that-copies-one-that-mutates.md) -- why there are two cores |
| `ai_steering` | seek, arrive, pursue and avoid -- not which cell, but which way to push and how hard, right now | `make demo-steering`: four vehicles, the force each asks for drawn as an arrow; seek overshoots forever, arrive stops | [why](docs/concepts/steering.md) |
| `ai_llm` | a local model as an advisor, with everything it says validated before it becomes an action | **not written**, and no task scheduled yet | -- |

`ai_core` sits under all of them: the board, the units, and the two interfaces
the others implement. Take any one addon and `ai_core` with it, and nothing
else.

Machine learning is applied to **specific pieces**, never to the whole game.
That is the point. A logistic regression that decides *attack or retreat* has
weights you can print and explain. A neural network that plays the whole game
teaches nothing.

## Will it run on my machine?

Four tiers. **No lesson lives only in the expensive tier.**

| tier | you need | you can |
|---|---|---|
| **0** | nothing | read `docs/concepts/` — the algorithms and why they work |
| **1** | Python 3 (already on Linux and macOS) | read a PDDL domain and check it, train the regressions, read the weights. Standard library only — **no pip, no numpy, no install step** |
| **2** | Godot 4 (~130 MB, runs on integrated graphics) | play the game, open the demos, modify the addons |
| **3** | a GPU with some VRAM | run a local LLM for real, once `ai_llm` exists; generate your own art with a local image model (`make artgen-bootstrap`, then `make artgen`; see [the how-to](docs/howto/generate-art.md)). Optional: the CC0 art is committed and is the default, so nothing needs this tier |

The game targets 1280×720 at 60 fps on integrated graphics, using the
Compatibility (OpenGL) renderer. There are no 3D nodes and no large assets.

The plan for the LLM addon, when it is written, is three transports —
`replay` (recorded responses, needing nothing, the default in the demos),
`ollama`, and any OpenAI-compatible endpoint. Replay is not a consolation
prize: it is the same object the tests use as a fixture, and it teaches the
part that matters most, which is **validating a model's output before it
becomes an action**.

## What you will see

`make menu` opens on all of them, each with a card saying what its AI
decides, which techniques decide it and what to watch; the cards live in
[`godot/menu/catalogue.json`](godot/menu/catalogue.json).

<!-- Recordings pending: headless Godot rasterises nothing, so no command in
this repository can capture one. Recording them is a person's job; see the
manual check in tasks/T7-close-the-slice.md. -->

**Checkers** (`make run`). You are red and move first, against the computer
as white. Click a piece and the squares it can reach turn green -- a
multi-jump one hop per click, the pieces it will take crossed out. When a
capture is compulsory, the pieces that can take are ringed. On white's turn
the board shows every move it considered, with its value -- white's lead at
the end of the line it expects -- and the pink arrow is what it will play.
The panel lists them best first and spells out that line. Space plays the
move. Keys 1–6 set how far it looks, and the panel says how many positions
that cost and how many replies alpha-beta skipped.

**The skirmish** (`make demo-skirmish`). Until T27 this was `make run`. A 12×8 board, a wall down the middle with rough
ground on either side, and two nodes worth taking. Red is yours: click a unit,
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

*Recordings of all five are still to be made.*

## Getting started

Tier 1, with nothing but Python:

```bash
python3 -m unittest discover -s python/tests -t python
PYTHONPATH=python python3 -m gameaikit.training.report   # what the models learned
```

Tier 2, with the engine:

```bash
make bootstrap     # downloads the pinned Godot and its Linux export templates to the large disk, SHA-512 verified
make menu          # every example on one menu: a card says what its AI decides and how; Esc comes back
make run           # checkers against minimax and alpha-beta
make demo-skirmish # the learned policy plays blue on the skirmish board
make demo-tictactoe # MENACE, the matchbox machine, at four ages of training
make demo-search   # the four searches on a board you can paint
make demo-tactical # Advance Wars style turns against the computer, at three levels
make check         # every gate
```

## Using one addon in your own project

```bash
make release       # dist/: one zip per addon, the Python wheel, and the menu as a Linux executable
```

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
