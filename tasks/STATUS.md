# Status

The index. One row per task; the task file holds everything needed to do it.
The topmost `## Resuming after` section is the next session's prompt.

## Milestone 1 — the vertical slice

A playable minimum where three techniques actually decide something.

| # | Task | State | Notes |
|---|---|---|---|
| T0 | Bootstrap: pinned Godot on the large disk | **done** | 4.7.2-stable, SHA-512 verified |
| T1 | Gates before the code | wip | 5 of ~12 written; gdUnit4 wired |
| T2 | `ai_core` and the board | todo | grid, units, turns, no AI |
| T3 | `ai_search`: A\*, BFS, DFS, Dijkstra | todo | needs T2 |
| T4 | `ai_planning`: STRIPS, and a PDDL reader in Python | todo | needs T2 |
| T5 | Dataset and training (Python) | todo | needs T2, T3 |
| T6 | `ai_learning`: inference, and the attack/retreat decision | todo | needs T5 |
| T7 | Close the slice: docs, ADRs, `make release` | todo | needs T3, T4, T6 |

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
