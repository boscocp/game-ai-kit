# T83 — Each checkout gets its own Godot `user://`, and a worktree its ignored files

Size: S · Prereqs: none · Files: `scripts/godot`, `scripts/bootstrap.sh`, `scripts/export.py`, `scripts/check_disk_layout.py`, `scripts/worktree_setup.py`, `Makefile`, `.gitignore`, `docs/adr/0022-a-user-dir-per-checkout.md`, `docs/godot/user-data.md`, `CLAUDE.md`, `docs/adr/0002-toolchain-on-the-large-disk.md`, `docs/howto/windows.md`, `docs/godot/exporting.md`, `godot/game/language.gd`, `godot/test/locale/language_test.gd`

## Goal

The owner's go-ahead of 2026-10-26, for a defect recorded in STATUS after
wave 82: `scripts/godot` sets `XDG_DATA_HOME` to `$toolchain/xdg` (on
Windows `APPDATA` and `LOCALAPPDATA` to the toolchain), so every git
worktree shares one `user://`. Two waves running Godot tests at once
collided -- wave 78's `effect_shards_test.gd` failed during wave 80's check
-- and since wave 88 a setting written by one checkout
(`user://settings.cfg`, the language) is read by every other.

1. **Each checkout its own `user://`**, still on the large disk. The
   decision, and what becomes of the shared `$toolchain/xdg`, in an ADR.
   Read the 4.7 documentation on `user://` and `OS.get_user_data_dir()`,
   and measure from two checkouts before relying on it; the finding goes
   in `docs/godot/` with its source and `verified_on`.
2. **A gate holds it.** `check_disk_layout.py` refuses two checkouts that
   resolve to the same `user://`, one that resolves under `$HOME`, and one
   that leaves its own checkout -- each with a planted case, and a mutation
   of the gate confirming the self-test notices.
3. **A new worktree gets the gitignored files it needs**:
   `godot/addons/gdUnit4/` and `scripts/forbidden-term-hashes.txt`, copied
   from the main checkout by one idempotent command that refuses clearly
   when the source is missing. Every agent in the waves 87-92 session
   copied them by hand, and without the term list
   `check_no_employer_refs.py` checks nothing and only says so in a note.

## Steps

1. Read the 4.7 pages (`data_paths`, `OS`, the command line), then print
   `OS.get_user_data_dir()` from two checkouts on the current wrapper:
   both say `$toolchain/xdg/godot/app_userdata/game-ai-kit`.
2. **Decide where it lives** and write the ADR: under the checkout itself,
   `.user-data/`, gitignored at the repository's root (outside `godot/`, so
   the engine never imports it). The checkout is already held on the large
   disk by D5, the directory goes when the worktree goes, and no hash or
   registry is needed to find it again. The Windows branch sets `APPDATA`
   and `LOCALAPPDATA` under the same directory, by the native path
   (`pwd -W`). `scripts/godot --gak-print-redirect` prints what it would
   set and exits, so the gate, bootstrap and `export.py` read the one
   decision instead of copying it.
3. Measure again from two checkouts: two directories, each inside its own
   checkout, and two Godot suites that write `user://` run at once from
   both.
4. **The gate**: D6 (a redirect under `$HOME`; a note on a CI runner, as
   D5), D7 (two checkouts share a redirect, or one sits inside the other's),
   D8 (a redirect outside its own checkout, or not ignored by git).
   Checkouts come from `git worktree list --porcelain`; one whose wrapper
   predates this task is a note, not a finding, since it is another
   branch's state. Planted cases for each; then delete each comparison from
   the gate in turn and watch the self-test fail.
5. **`make worktree-setup`** (`scripts/worktree_setup.py`): finds the main
   checkout from `git worktree list --porcelain`, copies what is missing,
   leaves what is present, exits 2 naming the missing source. Copies, not
   links: Godot writes `.uid` files into an addon it imports, and two
   checkouts writing one linked folder is the collision this task removes;
   and a link on Windows needs a privilege Git Bash does not have.
6. **The term list's contract, proposed and not changed.** `E0` stays a
   note: in CI the list never exists (gitignored, and no secret carries
   it), so a failure there would fail every run; for anyone but the author
   absence is the normal state (ADR 0005). The one case where absence is a
   mistake is a linked worktree whose main checkout has the list -- a
   finding there (an `E0b`) is proposed for the owner to decide; this wave
   gives the command that removes the cause instead.
7. CLAUDE.md: the trap about the term list names `make worktree-setup`,
   and the commands list it; ADR 0002, `docs/howto/windows.md` and the
   tests' comments stop saying `user://` is shared.

## Acceptance

```bash
python3 scripts/check_disk_layout.py --self-test
python3 scripts/check_disk_layout.py
python3 scripts/worktree_setup.py --self-test
python3 scripts/check_readability.py
python3 scripts/check_acceptance.py
python3 scripts/check_status.py
python3 scripts/check_no_employer_refs.py
```

## Manual check

On Windows, from Git Bash: `./scripts/godot --gak-print-redirect` prints
`APPDATA` and `LOCALAPPDATA` as `D:/...` paths inside the checkout, and
`make test-godot-some SUITES=test/locale` leaves its files under
`.user-data/appdata/Godot/app_userdata/game-ai-kit`. Not measured: this
wave was written on Linux. And after every open branch has merged or
rebased, delete the old shared `$toolchain/xdg` by hand.
