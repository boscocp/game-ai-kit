# T24 — One window for every example

Size: M · Prereqs: T21 · Files: `godot/menu/`, `godot/demos/`, `godot/game/`, `Makefile`, `scripts/check_demos.py`, `scripts/release.py`

## Goal

One executable that opens on a menu of every example in the kit. Pick one and
read a short explanation of the AI techniques it uses, then play it, then come
back to the menu without closing anything. Today each example is its own
`make` target, and a person has to know the target exists before they can see
the example at all.

The menu is a catalogue, not a game, and should look like one: legible,
consistent and quick to read, with nothing elaborate. Every example after this
one arrives through it.

**What a card says.** Three things, in this order:

1. **What the AI decides here**, in one sentence a person who has never read
   the code can follow -- *where each unit walks*, *which building to raise
   next*, *whether to take this fight*.
2. **The techniques, by name**, each with one line on the part it plays. For
   the RTS (T20) that is at least a commander planning over the PDDL domain
   (the build order), priority queues (the economy), utility over influence
   maps (where squads go and what the fog hides), A\* (one unit's route) and
   flow fields (a group's movement). That is what ADR 0010 and T19-T20 say
   they use. The card lists what the scene actually runs, not what the genre
   suggests.
3. **What to watch**: the one thing on screen that shows the decision, from
   T21's overlay -- *the frontier spreading*, *the plan's current step lit*.

And a link to the example's `docs/concepts/` page, for the reader who wants
the reason behind the sentence.

**Honest about PDDL.** The game does not parse PDDL in a frame; `ai_planning`
plans in GDScript over a domain the Python reader also reads (T4, T11). A card
that says "PDDL" says what the domain is written in, and the explanation must
not suggest the game reads a `.pddl` file at runtime unless, by then, it does.

## Steps

1. **A catalogue as data**, in one file under `godot/menu/`. Each entry holds
   the title, the scene, the `make demo-<name>` target, the sentence, the
   techniques with their lines, what to watch, and the docs page. The menu
   reads it, and so does `check_demos.py`. A list kept in two places is a list
   that will one day differ.
2. **The menu scene**: the examples down one side, the selected card on the
   other, and a play button. It works by keyboard as well as by mouse. It
   follows what T8 measured about legibility: contrast, text size, nothing
   small in a corner of a large window.
3. **Back to the menu from any example**, on Escape, with the example freed.
   That makes it a rule every example obeys: none of them calls `quit()`
   itself, and none assumes it is the main scene.
4. **`make menu`** opens it during development, and becomes the project's main
   scene. `make run` and every `make demo-<name>` keep working and open one
   example directly, which is still the fastest way to work on one.
5. **`make export`**: a Linux x86_64 build of the menu, into `dist/`. The
   export templates are installed by `make bootstrap`, pinned and
   SHA-verified, on the large disk (invariant 8; ADR 0002 already measured
   them at over 1 GB). Other platforms only once this one works, and each one
   as its own decision.
6. **`make release`** ships the executable as one more zip, with `LICENSE` and
   `NOTICE` beside the binary. The licence gate already opens every archive in
   `dist/` (invariant 9).
7. **The standing rule, extended.** From this task on, an example with no
   catalogue entry fails `check_demos.py`, and so does an entry with no
   example. T21 made every example watchable; this makes every example
   reachable.

## Acceptance

```bash
make check
python3 scripts/check_demos.py
./scripts/godot --headless --path godot -s res://test/menu_walk.gd
make export
make release
python3 scripts/check_license.py
```

`check_demos.py` gains the catalogue's half. Every `make demo-<name>` target
has exactly one entry and every entry has a target. Every entry's scene
exists and loads, and every entry has its sentence, at least one technique
and its docs page, with the page existing. It also checks every technique a
card names against the scene's scripts: a card saying A\* for a scene that
never references `AStarSearch` fails. That is the half of "honest" a command
can hold. Each rule is born with a planted case it rejects.

`menu_walk.gd` opens the menu headless and, for every entry, selects it,
plays it, steps the example through its first decision, sends Escape and
asserts the menu is back with the example freed. An example that cannot be
left, or that leaks its nodes, fails here.

`make export` exits non-zero if the templates are missing or do not match
their pinned hash. Its last step runs the exported binary with `--headless`
for a few frames and asserts it exits 0, so a build that does not even start
does not reach `dist/`.

## Manual check

Hand the executable to someone who has not seen the kit. Ask them to open
three examples and, for each, say in their own words what the AI decides and
which technique decides it, using only the card and the screen. If they need
the code or the docs to answer, the card is the part that needs rewriting.

Open every example from the menu and come back. Nothing should flicker or
carry over from the last example, and no card may name a technique the
example does not visibly use.
