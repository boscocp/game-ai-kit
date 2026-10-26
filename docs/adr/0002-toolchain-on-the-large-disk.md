# 0002 — The toolchain lives on the large disk, by two mechanisms

Status: accepted · 2026-10-12 (T0)

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
