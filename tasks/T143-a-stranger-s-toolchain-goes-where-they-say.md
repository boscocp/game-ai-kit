# T143 — A stranger's toolchain goes where they say

Size: M · Prereqs: T112 · Files: `Makefile`, `scripts/godot`, `scripts/llm`, `scripts/artgen`, `scripts/export.py`, `scripts/check_disk_layout.py`, `README.md`, `README.pt-BR.md`, `docs/adr/0002-toolchain-on-the-large-disk.md`

## Goal

The review before the repository opens (T112, wave 143,
`docs/reviews/open-the-repository.md`, finding 1) found that nobody but
the author can run `make bootstrap` as the README says. The toolchain
defaults to `/mnt/games/gamedev/toolchain` in the `Makefile` and in five
scripts. The Makefile's knob is `TOOLCHAIN` and the scripts' is
`GAK_TOOLCHAIN`, so `make bootstrap TOOLCHAIN=~/x` installs where the next
`make menu` does not look. And `make check`'s `lint-disk-layout` fails
(`D1`) on any machine where Godot has ever run from the user's home --
measured with `check_disk_layout.py --home` on a home holding
`.local/share/godot/`.

## Decisions written down first (the owner confirms in review)

- **One name.** The Makefile exports `GAK_TOOLCHAIN` from `TOOLCHAIN`, so
  every recipe and every script it calls agrees; setting either works.
- **A default that exists on anyone's machine**, inside the checkout
  (`.toolchain/`, ignored by git), as `.user-data/` already is (ADR 0022).
  The author keeps the large disk by setting `GAK_TOOLCHAIN` once in the
  environment. Whether invariant 8 stays "the large disk" or becomes "the
  toolchain directory, never the user's home" is the owner's; ADR 0002 is
  amended either way.
- **Invariant 8 is about what this repository writes.** `D1` stops
  refusing a folder in the home that existed before `make bootstrap`, or
  that this checkout's `scripts/godot` did not write; what the gate cannot
  attribute is a note, not a finding. The planted cases stay: a wrapper
  that stops redirecting is still refused.
- **The README says which systems `make bootstrap` serves** (Linux x86_64;
  Windows through `docs/howto/windows.md`; not macOS yet), and how to put
  the toolchain somewhere else.

## Steps

1. Read GNU make's documentation on `export`, then make the two names one.
2. Move the default and amend ADR 0002.
3. Narrow `D1`, with a planted case for each side of the line.
4. The README's "Getting started", in both languages.

## Acceptance

```bash
python3 scripts/check_disk_layout.py --self-test
make lint-disk-layout
make lint-selftests
make lint-workflow
make check
make lint-tasks lint-status
```

## Manual check

On a machine or a fresh user account that has never seen this
repository, and has the Godot editor installed: clone, `make bootstrap`,
`make menu`, `make check`. Each works with no variable set.

## Notes

- Opened by T112 (wave 143), finding 1. The Makefile, scripts and CI are
  global paths, so the wave runs all of `make check`, alone.
