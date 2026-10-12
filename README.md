# game-ai-kit

Teaching AI in games, one readable piece at a time.

A set of Godot 4 addons you can take **one at a time**, plus a small turn-based
strategy game where each of them actually decides something. The code is written
to be read: if a passage is fast and unreadable, it loses to the slow and
readable one.

> Status: early. The first vertical slice (board + A\* + STRIPS + logistic
> regression) is being built. Nothing is published to the Asset Library yet.

## What it covers

| piece | what it decides in the game |
|---|---|
| `ai_search` | A\*, BFS, DFS, Dijkstra — how a unit gets there |
| `ai_planning` | STRIPS — *to attack I need a unit; to have a unit I need resources* |
| `ai_learning` | logistic regression — attack or retreat; linear regression — which target is closer to falling |
| `ai_llm` | a local model as an advisor, with everything it says validated before it becomes an action |

Machine learning is applied to **specific pieces**, never to the whole game.
That is the point. A logistic regression that decides *attack or retreat* has
weights you can print and explain. A neural network that plays the whole game
teaches nothing.

## Will it run on my machine?

Four tiers. **No lesson lives only in the expensive tier.**

| tier | you need | you can |
|---|---|---|
| **0** | nothing | read `docs/concepts/` — the algorithms and why they work |
| **1** | Python 3 (already on Linux and macOS) | run the planner, train the regressions, read the weights. Standard library only — **no pip, no numpy, no install step** |
| **2** | Godot 4 (~130 MB, runs on integrated graphics) | play the game, open the demos, modify the addons |
| **3** | a GPU with some VRAM | run a local LLM for real |

The game targets 1280×720 at 60 fps on integrated graphics, using the
Compatibility (OpenGL) renderer. There are no 3D nodes and no large assets.

The LLM addon ships three transports — `replay` (recorded responses, needs
nothing, and is the default in the demos), `ollama`, and any OpenAI-compatible
endpoint. The replay transport is not a consolation prize: it is the same object
the tests use as a fixture, and it teaches the part that matters most, which is
**validating a model's output before it becomes an action**.

## Getting started

```bash
make bootstrap   # downloads the pinned Godot to the large disk, SHA-512 verified
make check       # every gate
make godot-version
```

Tier 1 needs none of that:

```bash
python3 -m unittest discover -s python/tests -t python
```

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
