# game-ai-kit — standing instructions

Teaching AI in games, one readable piece at a time. Godot 4 addons you can take
one at a time, plus a small turn-based strategy game where they actually decide
something.

## The invariants

Every one of these has a gate. An invariant without a gate is prose, and prose
does not hold: a rule violated twice becomes a script.

1. **The code is teaching material before it is a library.** When this conflicts
   with any other rule below, this one wins. See "Readable by a person".
2. **No addon depends on another addon**, only on `ai_core` (types and
   interfaces, no logic). Someone who wants only A\* copies two folders.
3. **Every acceptance criterion is a command with an exit code.** A game is
   visual, and that is exactly where "looks like it works" becomes debt.
   Anything needing human eyes lives under `## Manual check` and does not
   pretend to have an exit code.
4. **Every gate is born with a planted case it must reject.** A gate that only
   knows how to go green is the most expensive defect, because nobody
   investigates a green. Ask of each one: *does this pass on an empty scene?*
5. **No lesson requires hardware above tier 1.** See the tiers in the README.
6. **No training at game time.** Python trains and emits weights; GDScript only
   infers.
7. **The LLM never blocks a frame, and nothing it returns becomes an action
   without passing a validator.**
8. **The whole toolchain lives on the large disk.** Nothing in `$HOME`.
9. **Every published artifact carries LICENSE and NOTICE.**
10. **Nothing from the author's employer enters this repo** — no name, no
    internal measurement, no file copied from a private repository, no
    work-domain example. The examples here are games.

## Commands

```bash
make bootstrap     # install the pinned Godot on the large disk, SHA-verified
make check         # every gate; this is what CI runs
make test-python   # stdlib unittest, no install step
make test-godot    # headless
make godot-version # what is pinned vs what is installed
make hooks         # opt in to .githooks
./scripts/godot …  # the ONLY way to invoke Godot (see below)
```

## Readable by a person

This project exists to be read. If a passage is fast and unreadable, it loses
to the slow and readable one, and the exception needs a benchmark, not an
opinion.

- function ≤ 40 lines, nesting ≤ 3, addon file ≤ 400 lines;
- every public function has a doc comment saying **what** and **why**, never
  paraphrasing the code. A comment that repeats the line below it is a finding;
- no single-letter names, except a short allowlist declared in the gate: `g`,
  `h`, `f` in heuristic search are the literature's names and renaming them
  hurts the reader who came from the book;
- static types everywhere (`var x: int`, `-> void`). Godot does not require it;
  without it you lose parse-time checking, autocompletion and speed, and the
  reader loses the signature;
- no invented abbreviations: `distance`, not `dst`.

Not mechanically checkable, so it belongs in review and under `## Manual check`:
the algorithm file reads top to bottom like the pseudocode in the book, and each
addon opens with a 5–10 line header saying what it solves, the complexity, and
**when not to use it**.

## Check the documentation before writing the rule

Measuring a behaviour by crashing into it works, and it is still the expensive
way round. Before writing a rule, a gate or a line of code that depends on how
Godot behaves, **read the official documentation for the version in
`.godot-version`**, then measure to confirm. Three things in this repository
were wrong because that order was reversed:

- a rule was nearly written claiming Godot's exit code carries no information
  (it propagates: parse error 1, `quit(3)` 3);
- `make test-godot` ran a form that cannot work and popped a desktop dialog
  under `--headless`;
- `check_license.py` used `plugin.cfg` as the marker for a shippable addon,
  when the library addons here correctly have none -- `class_name` registers a
  class project-wide with no plugin at all.

Findings that survive both steps go in `docs/godot/`, with the source URL and a
`verified_on` date, because that is the layer with a six-month half-life.

## Traps that have already cost time

- **`make` collapses every failure to exit 2.** The scripts are careful to
  separate `1` (findings) from `2` (usage/unreadable) and, in one case, `3`
  (something in git history). When you need that distinction, call the script
  directly — `python3 scripts/check_x.py` — not through its make target.
- **Godot's self-contained mode is not enough on its own.** `._sc_` beside the
  binary redirects editor data, settings and export templates. It does **not**
  redirect the project's `user://` directory: measured on 4.7.2, a bare
  `--headless --import` still recreated `~/.local/share/godot/app_userdata/`.
  `XDG_DATA_HOME` covers that. Both live in `scripts/godot`, which is why
  nothing calls the binary directly. See `docs/adr/0002`.
- **A test runner that finds nothing also exits 0.** `python/tests` needs its
  `__init__.py` for `discover -t python` to import it; without it the suite
  errors, and the day it stops erroring it may simply be finding nothing.

## How to resume work

Read `tasks/STATUS.md`. Its topmost `## Resuming after` section is the next
session's prompt. Then open only the task file you are about to do.
