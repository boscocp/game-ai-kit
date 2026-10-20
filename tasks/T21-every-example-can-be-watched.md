# T21 — Every example can be watched

Size: M · Prereqs: T2 · Files: `godot/demos/`, `godot/game/`, `Makefile`

## Goal

A person can open any example in this kit and **see the AI deciding**, not just
see what it decided afterwards.

That is the standing rule for every example from here on. It is not a testing
rule — a gate cannot look at a screen, and this task does not pretend
otherwise. It is a rule about what an example *is*: a window somebody can open,
with the AI's reasoning drawn on it.

The kit has already been burned twice by not having it. T8 exists because the
owner ran `make run` and could not tell what he was looking at. The wave 08
review found the search demo covering the mud band with its own expansion
rectangles — the one thing that demo exists to show — at exactly the moment the
picture completed.

**What a gate can and cannot do here, measured rather than assumed.** On the
pinned engine, `--headless` uses the dummy rendering driver: nothing is
rasterised and `Viewport.get_texture().get_image()` returns null. There is no
`xvfb` in the toolchain either. So no command in this repository can look at a
picture. What a command *can* check is that the example exists, loads, runs a
decision, and puts the decision somewhere a person would see it. The seeing
stays a person's job, and lives under `## Manual check` where this project puts
things that need eyes.

## Steps

1. One `make demo-<name>` per example, listed in `make help`. `make run` and
   `make demo-search` are the two that exist; the convention is written down
   once and every later example follows it.
2. **The decision on screen, not only the outcome.** Each example draws what
   the AI is reasoning *with*: the search draws its frontier and what it
   expanded, the planner draws the plan and which step it is on, the learned
   policy draws the probability it computed, the racing AI draws its line and
   its lookahead point. A demo that shows only the result teaches the result.
3. A step control. Space advances one decision, so a person can stop on the
   frame where the AI did something surprising and read why. A demo that only
   plays at full speed cannot be argued with.
4. A legend, because a coloured square means nothing to somebody who did not
   write it.
5. A `## Manual check` section in every example's task, saying what a person
   should be able to see and what would count as failing.

## Acceptance

```bash
make test-godot
python3 scripts/check_demos.py
```

`check_demos.py` holds the half that can be held: every example has a make
target, every target names a scene that exists, every scene loads, and every
one of them exposes the decision overlay this task requires. It fails on an
example that has no window, and on a window with nothing of the AI on it.

```bash
./scripts/godot --headless --path godot -s res://test/menu/demo_overlays.gd
```

That script steps each demo through its first decisions headless and asserts
the overlay was populated — that the frontier array is not empty after a search
step, that the plan has steps on it, that the probability is a number. It does
not assert anything is visible, because it cannot.

## Manual check

Open each demo and answer one question per example: **can you tell what the AI
is about to do, and why, before it does it?** If you can only tell afterwards,
the example fails this task regardless of what the gates say.
