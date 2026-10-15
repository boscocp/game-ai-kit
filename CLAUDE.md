# game-ai-kit — standing instructions

Teaching AI in games, one readable piece at a time. Godot 4 addons you can take
one at a time, plus a small turn-based strategy game where they actually decide
something.

## The invariants

An invariant without a gate is prose, and prose does not hold: a rule violated
twice becomes a script. This section used to claim every invariant had one. It
did not, and a review said so. Four are still prose or only half held -- 4, 6,
7 and 13 -- and they are marked. **Marked, not quietly dropped**: an unenforced
rule you know about is worth keeping, and one you believe is enforced is worse
than none.

| | gate |
|---|---|
| 1 readable | `check_readability.py` |
| 2 addon independence | `check_addon_deps.py` — fully held since wave 7, when there was a second addon for it to inspect |
| 3 acceptance is a command | `check_acceptance.py` |
| 4 gate rejects a planted case | `make lint-selftests` runs them; that each one *has* a planted case is still read by a person |
| 5 no lesson above tier 1 | `check_tiers.py`, via each page's `teaches:` field |
| 6 no training at game time | **none yet** -- `check_no_training.py`, named in T6 |
| 7 LLM output validated | **none yet** -- arrives with the addon |
| 8 toolchain on the large disk | `check_disk_layout.py` |
| 9 LICENSE and NOTICE ship | `check_license.py` |
| 10 nothing from the employer | `check_no_employer_refs.py` |
| 11 no tooling byline | `check_commit_msg.py`, `check_pr_message.py` |
| 12 branch per wave, review first | `.githooks/pre-commit`, `check_branch_base.py` |
| 13 every example can be watched | **none yet** -- `check_demos.py`, named in T21 |

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
   infers. One exception, decided by the owner: an opponent model may count
   what it sees during one fight, starting empty and never saved (ADR 0016,
   rule N9).
7. **The LLM never blocks a frame, and nothing it returns becomes an action
   without passing a validator.**
8. **The whole toolchain lives on the large disk.** Nothing in `$HOME`.
9. **Every published artifact carries LICENSE and NOTICE.**
10. **Nothing from the author's employer enters this repo** — no name, no
    internal measurement, no file copied from a private repository, no
    work-domain example. The examples here are games.
11. **No tooling byline in a commit, a PR title or a PR body.** One author.
    Enforced by `.githooks/commit-msg` and, because a hook cannot see a pull
    request, by a CI step that checks the PR's own title and body.
12. **One branch per wave, and the review lands before the merge.** Not after.
    The reviewer is a context that did not write the code — the same head
    writing the code, the test and the check is the symmetry everything else
    here exists to break. `.githooks/pre-commit` refuses a commit on `main`,
    and `make wave-merge` refuses a branch with no review record.

13. **Every example can be watched, and shows the decision rather than only the
    outcome.** A person opens it and sees what the AI is about to do and why --
    the search's frontier, the planner's current step, the probability the
    learned policy computed, the line the racing AI is steering to. An example
    that shows only the result teaches only the result.

    This one is deliberately **not** fully gateable, and pretending otherwise
    would be worse than leaving it open. Measured on the pinned engine:
    `--headless` uses the dummy rendering driver, nothing is rasterised, and
    `Viewport.get_texture().get_image()` returns null -- so no command in this
    repository can look at a picture. `check_demos.py` holds the half that can
    be held (the example exists, its scene loads, the decision overlay is
    populated) and the seeing stays a person's job, under `## Manual check`.

## Commands

```bash
make wave-start BRANCH=wave/NN-slug   # cut a branch from a current main
make wave-merge                       # merge it, once reviewed
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
- **A new `class_name` is invisible until the project is imported.** Write a new
  `.gd` with a `class_name`, run `make test-godot`, and every file that uses it
  fails with `Could not find type "X" in the current scope` — which reads like a
  typo and is not one. The global class list is a cache under `godot/.godot/`.
  Run `./scripts/godot --headless --path godot --import` once after adding a
  class, and the `.uid` file it writes beside the script is committed with it.
- **A failing gdUnit4 suite hides the tests after it.** It stops at the first
  failing test in that file, and the ones it never ran are not counted as
  skipped. So the case count in a *red* run is not the number of tests in the
  file. Measured on v6.2.2; see `docs/godot/addon-anatomy.md`.
- **The forbidden-term list is untracked and a checkout can delete it.**
  `scripts/forbidden-term-hashes.txt` is gitignored (ADR 0005), but it was
  *tracked* until wave 6 — so checking out anything older and coming back
  removes it from disk, and `check_no_employer_refs.py` then cheerfully reports
  that it checked nothing. The note it prints on every run is the only warning
  you get. Restore it with
  `git show d11fc91:scripts/forbidden-term-hashes.txt > scripts/forbidden-term-hashes.txt`,
  or rebuild it with `--add-term`.

## How to resume work

Read `tasks/STATUS.md`. Its topmost `## Resuming after` section is the next
session's prompt. Then open only the task file you are about to do.
