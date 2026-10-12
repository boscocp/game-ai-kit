# Status

The index. One row per task; the task file holds everything needed to do it.
The topmost `## Resuming after` section is the next session's prompt.

## Milestone 1 — the vertical slice

A playable minimum where three techniques actually decide something.

| # | Task | State | Notes |
|---|---|---|---|
| T0 | Bootstrap: pinned Godot on the large disk | done | 4.7.2-stable, SHA-512 verified |
| T1 | Gates before the code | done | 14 gates, all in `make check` |
| T2 | `ai_core` and the board | todo | grid, units, turns, no AI |
| T3 | `ai_search`: A\*, BFS, DFS, Dijkstra | todo | needs T2 |
| T4 | `ai_planning`: STRIPS, and a PDDL reader in Python | todo | needs T2 |
| T5 | Dataset and training (Python) | todo | needs T2, T3 |
| T6 | `ai_learning`: inference, and the attack/retreat decision | todo | needs T5 |
| T7 | Close the slice: docs, ADRs, `make release` | todo | needs T3, T4, T6 |

---

## Resuming after 2026-10-12 (wave 4)

**What landed.** `check_acceptance.py` and `check_status.py`, and the eight task
files T0–T7 they check. `make check` runs ten gate self-tests plus both suites,
green. T0 and T1 were written retroactively rather than excused as bootstrap
rows: their Acceptance blocks record the commands that were actually run,
including the two negative controls.

**The acceptance gate caught two bugs in itself, and then one in me.**

1. Its first non-terminating rule used a lookahead for `--headless` after the
   word `godot`. In `--path godot` the word appears twice, and the second
   occurrence has no `--headless` after it, so a correct criterion was reported
   as broken. Replaced with a per-line check that only matches Godot in command
   position, which is also easier to read.
2. Its "the assertion sits in the comment" rule required a pipe before `grep`,
   so the same mistake written without a pipe passed. Broadened.
3. Then it rejected this repository's own T3, because the Acceptance prose used
   the word "plausible". That was the rule working: Acceptance prose is exactly
   where a human verdict hides. The sentence was rewritten, not the rule.

**Two dangling references, deliberately.** T2's acceptance calls
`check_addon_deps.py` and T7's calls `check_tiers.py` and `scripts/release.py`.
None exists yet. They are named now so that writing them is part of finishing
T1, rather than something remembered later; running those tasks' acceptance
today fails on a missing file, which is the correct state for a `todo` task.

**Next, to finish T1:** `check_addon_deps.py` (invariant 2: no addon imports
another), `check_tiers.py` (invariant 5: no lesson above tier 1), then
`check_links.py` and `check_workflow.py` ported from `desk-panel`,
`CONTRIBUTING.md`, and `.github/workflows/ci.yml` running the same strings the
Makefile does. Then T2, which is the first real GDScript.

Correction to the line that was here: it predicted the link gate would flag
`github.com/boscocp/game-ai-kit`. It does not, and the prediction was wrong --
that URL appears only in `NOTICE`, which is not markdown, and inside backticks
in this file. There is no markdown link to it, so there is nothing for the gate
to follow. No exception is needed.

---

## Resuming after 2026-10-12 (wave 3)

**What landed.** Three gates: `check_readability.py` (invariant 1, mechanical
half), `check_doc_freshness.py` (the three half-life layers), and
`check_no_employer_refs.py` (tree and history). `make check` runs eight gate
self-tests plus both test suites, and is green.

**What reading the documentation first changed.** Four Godot facts were checked
against the 4.7 docs rather than assumed, and one of them was a live bug:

- a `plugin.cfg` requires an `@tool` script extending `EditorPlugin`. The
  library addons here need none, because `class_name` registers a class
  project-wide with no plugin. `check_license.py` had been using `plugin.cfg` as
  the marker for "shippable addon", so a library addon was **skipped in
  silence** -- a gate failing open. Fixed, and the self-test case inverted.
- the Asset Library does not require `plugin.cfg`, does require `LICENSE` at the
  repository root, and **does** offer Apache-2.0. The tutorial page lists a few
  licences as examples and briefly looked like it ruled Apache out; the live
  filter has it.
- `TileMapLayer`, not `TileMap` -- the latter is deprecated in 4.x.
- `AStarGrid2D` is engine core in C++ with four heuristics, which is what the
  README's "when not to use this" should point at.

All four are in `docs/godot/addon-anatomy.md` with source URLs and a
`verified_on` date. `CLAUDE.md` gained the rule: read the documentation for the
pinned version first, then measure to confirm.

**How the employer gate avoids the obvious contradiction.** A gate searching for
a company name must contain that name, and a file saying "never mention X" is a
mention of X. The repository stores **salted SHA-256 hashes** instead, with a
prefix rule so one stored term also catches its compounds. `--add-term` reads
from a hidden prompt, so adding one never puts it in a file or a shell history.
The list is seeded with a single term derived from the work email domain;
**internal repository, client and project names are not on it yet** and should
be added with `--add-term`.

**Not proven.** The readability gate has only ever seen `smoke_test.gd`, which
is exempt from its doc-comment rule. It was confirmed to find real files by
planting an untyped function there (five findings, exit 1), but it has never
run against an addon, because none exists. The employer gate's history scan
walks every blob ever committed, which is fast on four commits and has not been
timed on a real history.

**Next:** `check_acceptance.py` and `check_status.py` (port from `desk-panel`,
and note that the former has **no** `--self-test` there -- the port must gain
one, and its non-terminating-command rules are about `adb` and a Python server,
which here means a Godot invocation without `--headless`). Then
`check_addon_deps.py`, `check_tiers.py`, `check_links.py`, `check_workflow.py`,
CONTRIBUTING.md and the CI workflow. After that, T2.

---

## Resuming after 2026-10-12 (wave 2)

**What landed.** gdUnit4 v6.2.2 installed by `make bootstrap`, pinned by tag and
verified by SHA-256. Two tests in `godot/test/smoke_test.gd`, and
`make test-godot` is now part of `make check`. The licence gate learned to tell
a third-party addon from one of ours.

**A decision reversed before it became history.** gdUnit4 was first vendored
into the repository. Staging it showed **509 files** of someone else's code
about to enter a repository whose premise is that you can read it. Switched to
install-at-bootstrap and gitignored; `docs/adr/0004` records why, including the
alternatives (submodule, writing a small runner) and what it costs: a fresh
clone must bootstrap before it can test.

**Three things the previous section got wrong, found by running them.**

1. `make test-godot` did not work. It ran `--path godot --quit` on a project
   with no main scene, which exits 1 -- and, despite `--headless`, popped a
   **zenity dialog** on the desktop. Replaced with a script entry point.
2. A rule was about to be written claiming Godot's exit code carries no
   information. Measured instead, and it is false: a parse error exits 1 and
   `quit(3)` exits 3. Godot propagates. The rule was not written.
3. gdUnit4 **refuses headless mode** unless given `--ignoreHeadlessMode`,
   because Godot does not deliver `InputEvent` there. That is now a standing
   constraint: a test in this repo must never depend on simulated input.

**What the licence gate found.** Vendoring gdUnit4 made `check_license.py` fire:
it would have required this project's NOTICE inside someone else's addon. The
gate now has a declared `VENDORED` table -- a vendored addon must carry its own
licence and must **not** carry ours, since our NOTICE in their folder claims
authorship we do not have. Declared one by one, never inferred.

**Still not proven.** The test suite has two tests and neither touches a line of
this project's own code, because none exists yet. What proves the runner can
fail is the planted failure: changing `2 + 2 == 4` to `== 5` gives exit 100, and
restoring it gives 0. Re-run that before trusting any future green.

**Known dangling reference.** `NOTICE` and `README.md` point at
`https://github.com/boscocp/game-ai-kit`, which returns 404 -- the repository is
local only, with no remote and nothing published. When `check_links.py` lands it
will flag this; the URL is the intended home, so it belongs in the link
exceptions file with that reason, not removed.

**Next:** the gates still missing -- `check_acceptance.py`, `check_status.py`,
`check_readability.py`, `check_no_employer_refs.py`, `check_tiers.py`,
`check_doc_freshness.py`, `check_addon_deps.py`, `check_links.py`,
`check_workflow.py` -- then CONTRIBUTING.md and the CI workflow. Note that
`desk-panel`'s `check_acceptance.py` has no `--self-test`; the port must gain
one, and its non-terminating-command rules need replacing (they are about `adb`
and a Python server; here the equivalent is a Godot invocation without
`--headless`).

---

## Resuming after 2026-10-12 (wave 1)

**What landed.** The repository exists at `/mnt/games/gamedev/game-ai-kit`, on
the large disk. Godot 4.7.2-stable is installed under
`/mnt/games/gamedev/toolchain/`, downloaded and verified by SHA-512. `make check`
is green with four gates: `check_disk_layout.py`, `check_renderer.py`,
`check_license.py` and the `bootstrap.sh` usage self-test. Three ADRs are
written (engine, toolchain layout, licence). LICENSE, NOTICE, README and
CLAUDE.md are in place.

**What the bootstrap found.** Enabling Godot's self-contained mode was assumed
to be enough to keep the toolchain off the small disk. It is not: with `._sc_`
in place, a bare `--headless --import` still recreated
`~/.local/share/godot/app_userdata/`. `XDG_DATA_HOME` covers the gap. Both
mechanisms now live in `scripts/godot`, and `check_disk_layout.py` asserts both.
Recorded in `docs/adr/0002`.

**What is not proven.** No Godot test has ever run — `make test-godot` only
opens and quits the project, because gdUnit4 is not installed yet. No GDScript
exists at all, so `check_renderer.py` has found nothing because there is nothing
to find; its self-test is what proves it can fail. `make` collapses every recipe
failure to exit 2, so a gate's own exit codes must be read by calling the script
directly.

**Next:** finish T1. `check_commit_msg.py` is done and the hook is live
(`make hooks`); it blocks assistant attribution in both forms, so overriding the
machine's global hook costs nothing. The gates still missing are
`check_acceptance.py`, `check_status.py`, `check_readability.py`,
`check_no_employer_refs.py`, `check_tiers.py`, `check_doc_freshness.py`,
`check_addon_deps.py`, `check_links.py`, `check_workflow.py`. Port the first
few from `desk-panel`, which is the only repository code is ported from here.

### What is still only true on this desk

- The toolchain path `/mnt/games/gamedev/toolchain` is this machine's layout.
  `GAK_TOOLCHAIN` overrides it, but nobody has run the gate with that override.
- `gdtoolkit` (gdformat/gdlint) has not been tried. Python here is 3.14.7 and
  `pip` is absent; if gdtoolkit cannot be installed, the GDScript formatting
  gate is deliberately left out of M1 and recorded in an ADR, rather than
  becoming a `continue-on-error`.
