# 0004 — gdUnit4 is installed, not vendored

Status: accepted · 2026-10-12 (T1)

## Context

The project needs a test framework that runs headless. gdUnit4 is the mature
choice for Godot 4. Installing it means copying an `addons/gdUnit4/` folder into
the project, and the obvious thing to do with a folder in a repository is to
commit it.

Committing it adds **509 files** of someone else's code. This repository's whole
premise is that you can read it: invariant 1 says the code is teaching material
before it is a library. A reader browsing `godot/addons/` would find one folder
of theirs for every folder of mine, and every history-wide scan — including the
gate that will check for employer references — would walk those 509 files
forever.

## Decision

`make bootstrap` downloads gdUnit4, pinned by tag and verified by SHA-256, and
writes `.pinned-version` next to it. `godot/addons/gdUnit4/` is gitignored.

## Alternatives considered

- **Vendor it.** `git clone && make test-godot` would work with no network, and
  the pin would be exact by construction. Rejected: the cost to readability and
  to every history scan outweighs an offline clone, and bootstrap already
  requires the network to fetch Godot itself.
- **A git submodule.** Keeps the history clean and the pin exact. Rejected:
  submodules are a recurring source of confusion for contributors who did not
  choose them, and this buys nothing over a SHA-verified download.
- **Write a small test runner instead.** Tempting, and more in character for a
  teaching repository. Rejected as scope: a test framework is not what this
  project is teaching, and gdUnit4's failure reporting is better than what a
  weekend would produce. Revisit only if gdUnit4 becomes an obstacle.

## Consequences

- A fresh clone must run `make bootstrap` before `make test-godot`. CI does the
  same, which means CI exercises the bootstrap path on every run.
- gdUnit4 is pinned by the **source archive** SHA-256, not a release asset: the
  project publishes no release binaries.
- `check_license.py` carries a declared `VENDORED` table. gdUnit4 is listed
  there even though it is not committed, because it is on disk at check time and
  must keep its own MIT licence and never wear this project's NOTICE.
- gdUnit4 refuses headless mode without `--ignoreHeadlessMode`, because Godot
  does not deliver `InputEvent` headlessly. Tests here must assert logic, never
  simulated input.
