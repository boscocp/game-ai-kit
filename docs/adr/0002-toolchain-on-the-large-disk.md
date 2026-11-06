# 0002 — The toolchain lives on the large disk, by two mechanisms

Status: accepted, amended · 2026-10-12 (T0; amended 2026-11-06 by T143 -- see the amendment at the end)

## Context

The development machine has 24 GB free on the disk holding `$HOME` and 156 GB
on the other one. Godot's export templates alone exceed 1 GB, and the import
cache grows on its own. Putting the toolchain in `$HOME` would fill the small
disk within a few export cycles.

## Decision

Everything — the editor binary, editor data, export templates, the project's
`user://` directory and the repository itself — lives under
`/mnt/games/gamedev/`. Two mechanisms are needed, and both are set by
`scripts/godot`, which is the only way this repo invokes the engine:

1. an empty `._sc_` file beside the binary turns on **self-contained mode**,
   which redirects editor settings, cache and export templates to
   `editor_data/` next to the executable;
2. `XDG_DATA_HOME` pointed at the toolchain directory, which redirects the
   project's `user://` data. **Amended by ADR 0022 (T83):** it now points
   inside each checkout, at its own `.user-data/`, because one directory
   under the toolchain was shared by every git worktree.

## Alternatives considered

- **`._sc_` alone.** This was the original plan. Rejected by measurement: on
  Godot 4.7.2, with `._sc_` in place, a single `--headless --import` still
  created `~/.local/share/godot/app_userdata/game-ai-kit/`. Self-contained mode
  covers *editor* data; a project's `user://` is not editor data.
- **A symlink from `~/.local/share/godot` to the large disk.** Works, but it is
  invisible, survives no fresh clone, and gives a contributor on a different
  layout nothing. Rejected.
- **Trusting documentation instead of checking.** The documentation's phrasing
  ("all editor data, settings and cache") is accurate and still does not answer
  the question that mattered.

## Consequences

- Nothing calls the Godot binary directly. `scripts/godot` also refuses to run
  if the installed version does not match `.godot-version`.
- `check_disk_layout.py` asserts both mechanisms, and fails on an *empty*
  leftover directory too: an empty directory means a mechanism stopped working,
  and the files follow the directory.
- A contributor on another machine overrides `GAK_TOOLCHAIN`; the gate takes the
  same variable, so their layout is checked as strictly as this one.

## Amendment, 2026-11-06 (T143): a stranger's toolchain goes where they say

**Context.** The review before the repository opens (T112,
`docs/reviews/open-the-repository.md`, finding 1) found that only the author
could run `make bootstrap`: five scripts and the Makefile defaulted to
`/mnt/games/gamedev/toolchain`; the Makefile's knob was `TOOLCHAIN` and the
scripts' `GAK_TOOLCHAIN`, so `make bootstrap TOOLCHAIN=/x` installed where
the next `make menu` did not look; and `check_disk_layout.py` refused any
home holding `~/.local/share/godot/` -- every machine where a Godot has
ever run -- and any clone in the home (D5).

**Decision.** Proposed by T143; the owner confirms in review.

1. **One name.** `GAK_TOOLCHAIN` is the toolchain everywhere. The Makefile
   copies `TOOLCHAIN=...` from its command line into it and exports it, so
   every recipe of that command, and every script a recipe calls, sees the
   same place. A command-line variable lives one command, so `make
   bootstrap` then links the checkout's `.toolchain` to where it installed,
   unless one is there already: `make bootstrap TOOLCHAIN=/x` followed by a
   bare `make menu` finds `/x`. `TOOLCHAIN` in the environment is not read,
   a deliberate departure from the task's "setting either works": other
   builds set that name. Two different values on one command line, or a
   relative path, stop `make` before any recipe runs; an empty value is
   unset.
2. **A default that exists on anyone's machine:** the checkout's own
   `.toolchain`, ignored by git, as `.user-data/` is (ADR 0022).
   `make worktree-setup` links a worktree's `.toolchain` to the main
   checkout's, so worktrees share one toolchain as they did before. The
   author keeps the large disk by setting `GAK_TOOLCHAIN` once in the
   environment, or by making the main checkout's `.toolchain` a link to it.
3. **Invariant 8 is about what this repository writes**, and reads now
   "the toolchain lives in its own directory, never in the user's home
   folders" -- the second of the two wordings the task left to the owner.
   It is **half held**, and CLAUDE.md's table says so. What
   `check_disk_layout.py` asks:
   - **D1** counts this project's own `user://` in the home
     (`app_userdata/<config/name>` under Godot's data folder), always, and
     the five model caches `scripts/artgen` and `scripts/llm` redirect,
     unless they were there before `make bootstrap`. `make bootstrap`
     records, once, which of those caches the home held
     (`home-before-bootstrap.txt` in the toolchain); a toolchain that
     already held Godot gets a record that forgives nothing. Godot's other
     folders (`~/.config/godot`, another project's `user://`) belong to
     whatever Godot the person runs, and are a note.
   - **D5 and D6** (the checkout and its `user://` under the home) are
     findings only when the toolchain is outside the home -- when the person
     has put this repository's large part on another disk, the checkout
     belongs there too. A toolchain in the home (a clone in the home with
     its `.toolchain`, a CI runner's temp folder) means one disk, and they
     are notes.
   - `scripts/artgen` and `scripts/llm` no longer refuse a toolchain under
     `$HOME`; they still refuse a cache pointed outside the toolchain.
4. **The README says which systems `make bootstrap` serves**: Linux x86_64;
   Windows through Git Bash (`docs/howto/windows.md`); not macOS, where it
   would fetch the Linux build.

**What it no longer sees.**

- *`._sc_` that stops being honoured.* D3 and D4 still ask that the marker
  and `editor_data/` are beside the binary; they cannot ask that the
  engine reads them. Until T143 an editor folder appearing in the home was
  a finding; now `~/.config/godot` is a note, because any Godot the person
  runs writes it. An engine update that ignored `._sc_` would write there
  unseen.
- *Which Godot wrote the project's own `user://`.* It is counted whoever
  wrote it: a person who opens `godot/project.godot` in their own editor
  writes it there and fails D1. Nothing in the folder says which Godot
  made it; the finding says to open the editor through `./scripts/godot
  --path godot -e`, which redirects it. It is never forgiven by a record,
  so `rm -rf .toolchain && make bootstrap` cannot launder it.
- *A model cache older than the newest record.* A toolchain deleted and
  bootstrapped again writes a fresh record, which forgives a cache that
  leaked before it.

**Consequences.** This amendment supersedes the second bullet of
Consequences above: an empty leftover folder in the home is a finding only
for this project's own `user://` and the model caches. The first and third
bullets stand. The title stays: on the author's machine the toolchain is
on the large disk, by `GAK_TOOLCHAIN` or a `.toolchain` link.
