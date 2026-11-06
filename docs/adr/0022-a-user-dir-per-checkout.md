# 0022 — Each checkout has its own `user://`, inside it

Status: accepted · 2026-10-26 (T83)

Amends ADR 0002's second mechanism: where `XDG_DATA_HOME` points, not
whether.

## Context

ADR 0002 pointed `XDG_DATA_HOME` (on Windows `APPDATA` and `LOCALAPPDATA`)
at the toolchain, to keep `user://` off the small disk. That made it one
directory for every checkout of the repository. Once waves ran in parallel
git worktrees, that stopped being harmless: gdUnit4 deletes `user://tmp`
after every suite, so a suite ending in one worktree deleted the files a test
in another was using -- wave 78's effects shards test failed that way during
wave 80's check -- and since wave 88 the language a person picks in one
checkout (`user://settings.cfg`) is the one every other starts in. Measured
and written in `docs/godot/user-data.md`.

## Decision

`scripts/godot` points the redirect inside its own checkout, at
`.user-data/` at the repository's root, ignored by git:
`XDG_DATA_HOME=<checkout>/.user-data/xdg` on Linux, `APPDATA` and
`LOCALAPPDATA` under `<checkout>/.user-data/` on Windows.

- **On the large disk** because the checkout is: `check_disk_layout.py`'s
  D5 refuses a repository under `$HOME` when the toolchain is on another
  disk (amended by T143, ADR 0002's amendment; on one disk it is a note).
- **At the root, not under `godot/`**, so the engine never scans it as part
  of the project.
- **Found without a lookup.** No hash and no registry: the path *is* the
  checkout.
- **Goes with the worktree.** Removing a worktree removes its `user://`;
  nothing is left behind to collect.
- **One place decides it.** `scripts/godot --gak-print-redirect` prints the
  redirect; bootstrap, `export.py` and the gate ask it.

## Alternatives considered

- **Under the toolchain, keyed by a short hash of the checkout's path**
  (`$toolchain/userdata/<hash>`). Also per checkout and on the large disk,
  but a removed worktree leaves its directory behind for good, a moved
  checkout gets a new one silently, and nobody can tell which hash is
  whose without recomputing it. Rejected for those three.
- **`application/config/custom_user_dir_name`.** Lives in `project.godot`,
  which every checkout shares; it cannot tell them apart.
- **A command-line option.** Godot 4.7 has none for the user data directory.
- **Leave it shared and make every test use unique names.** The tests
  already do; gdUnit4's own `user://tmp` cleanup does not, and neither does
  a person's saved language.

## Consequences

- `git clean -fdx` now deletes a checkout's `user://` too: logs, test
  leftovers and the saved language. Nothing there is meant to survive.
- **The old shared directory**, `$toolchain/xdg` (16 MB of logs and probes
  on 2026-10-26), is no longer written once a branch has this change. It is
  not deleted by this wave: branches cut before it still write there until
  they rebase or merge. The gate notes those checkouts by name. When none
  is left, the owner deletes `$toolchain/xdg` by hand.
- `check_disk_layout.py` holds the decision: D6 (under home), D7 (two
  checkouts sharing one), D8 (outside its checkout, inside `godot/`, or not
  ignored by git). They are findings for the checkout running the gate,
  and D7 for a pair it belongs to. The same problem in another worktree
  is a note, because that worktree is another branch's state, often
  mid-wave (the review).
- A folder inside the tree that tools write to is now inside the tree the
  repo-wide gates walk. `check_readability.py` read a gdUnit4 mock under a
  reviewer's `.user-data/`, and `make check` failed on main. It and
  `check_no_training.py` now skip every folder below their root whose name
  starts with a dot: `.user-data/`, `.claude/worktrees/` (other checkouts),
  `.godot/` and `.git/`. That is a rule about names, not about git. It
  needs no git, so it holds inside a self-test's temporary tree, and no
  tracked `.gd` lives in a dot folder. It asks only the parts below the
  root, so a checkout that itself sits under `.claude/worktrees/` is still
  read.
- A worktree also needs the ignored files the main checkout has --
  gdUnit4 and the term list -- and `make worktree-setup` copies them
  (T83).
- On Windows the path is written by `pwd -W` as `D:/...`, the form the
  toolchain path already took. Not yet measured there; T83's manual check.
