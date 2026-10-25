# Review: wave/83-windows

A fresh context reviewed wave 83 at `79c5455`: the Makefile and its scripts,
written for Linux, made to run on Windows from Git Bash with GNU make for
Windows (ezwinports, a native make). The owner asked for it on 2026-10-25.
The reviewer was not allowed to edit the worktree, nor to run Godot -- a
full `make check` was running in that checkout, and Godot runs share one
user:// directory. It ran the self-tests of `check_disk_layout`,
`check_acceptance`, `check_license` and `release`, the layout gate on the
real toolchain, and experiments of its own in a temporary directory.

**Verdict: fix before merge.**

## What was reviewed

- `CLAUDE.md` (invariants 4 and 8, "check the documentation before writing
  the rule") and `docs/howto/windows.md` against the code it describes.
- The `git cat-file --batch` reader in `release.py`, against `git show` on
  every one of the 1806 files at HEAD, and in a temporary repository with a
  path with a space, a leading space, no trailing newline, an empty file, a
  binary blob holding `\nblob 3\n`, a missing path and a tree.
- The Makefile's variable precedence: command line, environment, `?=` and
  `:=` inside the `ifeq`.
- Whether each planted case in `check_disk_layout`'s self-test is refused
  for its own reason on a Windows host, not for the layout's.
- That nothing changed on Linux: every `else` branch against the old code.

## Findings

1. **A timed-out shard or merge left Godot running on Windows** (high).
   Git Bash's `exec` of a Windows program leaves bash as a stub; `kill()`
   took the stub only. Measured with a stand-in. In the merge,
   `subprocess.run(timeout=)` then reads the pipes to the end, and the
   orphan held them open: the timeout became a hang.
2. **A bare `"bash"` could be WSL's** (medium). `CreateProcess` looks in
   System32 before PATH; on a machine with WSL every shard would run
   `scripts/godot` inside Linux and exit 2.
3. **`:=` on Windows overrode the environment** (medium), where Linux's
   `?=` honours it; and the howto's sentence about `GAK_TOOLCHAIN` was
   wrong for `make bootstrap`, which reads `TOOLCHAIN`.
4. **A Windows bootstrap still fetched the 1.28 GB of export templates**
   (low), to unpack Linux's pair for an export that is not ported.
5. **A committed path holding a newline** would split the batch request
   (low, no such path exists).

Sound, by the reviewer's reading: the reader is byte for byte `git show`;
a missing path still raises; the planted cases are refused for the right
reason; Linux's branches match the old code; the hook falls back to
`python` only when `python3` fails.

## What was done about them

1. `kill_tree` uses `taskkill /T /F` on Windows; the merge writes to a file
   and waits with `wait_or_kill`, as the shards do. A planted case, Windows
   only: a stub that started a child, killed at its deadline -- the child
   must be gone. Against the old `kill()` the child was alive; with the fix
   it is not.
2. `windows_bash()` asks PATH through `shutil.which` and refuses one under
   `%SystemRoot%`, as an `OSError` the run already turns into exit 2.
3. `?=` in both branches; checked: `TOOLCHAIN=E:/tc PYTHON=py make` now
   reads `E:/tc py`, and the defaults without them. The howto says which
   name moves the install and which the scripts.
4. Skipped on Windows, with a printed note.
5. Left: no committed path holds a newline, and a refusal for one would be
   a rule with nothing to hold.

Re-run after the fixes: the self-tests of every script, `make
lint-disk-layout`, the doc gates, and the gates the full check had not
reached -- see the pull request for the numbers. One gate fails on
Windows and is left failing: `make test-rts-budget`, the RTS core's flow
fields at 1.85-2.00 ms at the 95th percentile against a 1.5 ms share,
measured idle three times; `docs/howto/windows.md` says so.
