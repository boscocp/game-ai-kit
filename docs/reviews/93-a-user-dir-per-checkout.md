# Review: wave/93-a-user-dir-per-checkout

A fresh context reviewed T83 at 0d76dc4 (PR #32). That head pointed
`user://` inside each checkout (`.user-data/`, ADR 0022), added D6-D8 to
`check_disk_layout.py`, and added `make worktree-setup`. The reviewer ran
the wrapper and the gates, ran Godot with an empty redirect, and mutated the
gate.

**Verdict: no blockers; four should-fix and nits, to be applied before the
merge.** The branch was then rebased on main at 44e3f88 (wave 89).

## Findings

1. **A checkout failed because of another worktree** (should-fix).
   - D6 and D8 ran for every checkout `git worktree list` names, and all
     of them counted toward this checkout's exit.
   - D7 fired for pairs that did not include this checkout.
   - In this repository agents change their own `scripts/godot` mid-wave,
     so checkout A would go red because of agent B's work.
2. **`ignored_by_git` had no planted case** (should-fix, invariant 4).
   - Every case passed `ignored=lambda: True` or `False`.
   - Mutated to `return True`, it left `--self-test` green.
3. **An empty redirect was not refused** (should-fix, invariant 8).
   - `bootstrap.sh` read the redirect through `mapfile < <(...)`, and
     `set -e` does not see a failure inside a process substitution.
   - `export.py` did not check the exit code, and a line without `=` raised
     `ValueError`.
   - Measured by the reviewer: Godot run with no `XDG_DATA_HOME` creates
     `~/.local/share/godot/app_userdata/`.
4. **`.user-data/` sits inside the tree the repo-wide gates walk**
   (should-fix, and it had already happened).
   - `make check` on main failed. `check_readability.py`'s
     `rglob("*.gd")` from the repo root reached
     `.claude/worktrees/<reviewer>/.user-data/xdg/.../tmp/mock/planted.gd`,
     a gdUnit4 mock left behind by a killed run.
   - Two holes: `.user-data/` itself, and the main checkout's gates
     reading every other worktree under `.claude/worktrees/`. The second
     was older, and became certain to fire.
5. **Nits:**
   - `said()` matched a printed line starting "D6 " rather than D6 being
     a finding, so turning the finding into a `print` would still pass.
   - `read_redirect` let `TimeoutExpired` escape.
   - Whether a wrapper was safe to run was decided by the flag's text
     appearing anywhere, comments included; there was no case for a
     wrapper that must not be run.
   - `worktree_setup.py`:
     - an interrupted `copytree` left a partial gdUnit4 that the next run
       reported as present;
     - the copied gdUnit4 was not compared with `bootstrap.sh`'s tag;
     - in the main checkout it exited 0 even with both files missing;
     - a bare main repository got an unclear message.
   - The `ignored` parameters had no type.
   - D8 did not refuse a redirect under `godot/`, which ADR 0022 rules out.
   - The D7 note listed 19 paths on one line.
   - CLAUDE.md's `make worktree-setup` comment was one column off.

Sound, by the reviewer's reading:
- The redirect was measured through both wrappers, and nothing appeared
  under `~` after `--import`.
- The root cause of the wave 80 failure is confirmed: gdUnit4 calls
  `clear_tmp()` at `GdUnitTestSuiteAfterStage.gd:24` after every suite.
- `--gak-print-redirect` collides with no Godot flag, and it is handled
  before the toolchain check.
- A wrapper that predates T83 is never executed.
- The Windows branch's quoting (`pwd -W`, `APPDATA`, `LOCALAPPDATA`) reads
  correct, though it is unmeasured.
- Ten mutations of the gate were killed.

## What was done about them

1. **Findings are this checkout's alone.**
   - `check_user_dirs(repo, ...)` makes D6 and D8 findings only for the
     checkout running the gate, and D7 only for a pair it belongs to.
   - The same problems elsewhere print as `D6 note, another checkout: ...`.
   - This checkout's own wrapper failing to answer is a D8 finding. It is
     the one the gate is about.
   - Planted on both sides: two other checkouts sharing one directory,
     another checkout under home, another not ignored, and another that
     predates T83 are each a note (exit 0); this checkout in a shared pair,
     or silent, fails.
2. **`ignored_by_git` is held by real git.**
   - The self-test runs `git init` on two temporary checkouts that hold
     the real `scripts/godot` and a `.gitignore` of `/.user-data/`.
   - It asserts that `.user-data/xdg` is ignored and that `scripts/` is not.
   - It runs the real-wrapper case with the real `ignored_by_git`.
3. **Bootstrap and export refuse an empty or failed redirect.**
   - `bootstrap.sh` captures the answer with `$( )`, which `pipefail` and
     `set -e` do see, and exits 2 on empty output.
   - `export.py`'s `redirect_from` raises `Refused` on a nonzero exit or
     on no `NAME=PATH` line.
   - Three new self-test cases (14 in all): one sound answer, one empty,
     one failed.
4. **The repo-wide scanners skip dot folders below their root.**
   - `scripts/` was grepped for `rglob` and `os.walk`. Only
     `check_readability.py` and `check_no_training.py` walk from a root
     that can hold `.user-data/` or `.claude/`. The rest walk `godot/`,
     `docs/`, an addon, or `git ls-files`.
   - Both now skip any folder below their root whose name starts with a
     dot: `.user-data/`, `.claude/worktrees/`, `.godot/`, `.git/`.
   - Chosen over "every gitignored path" because it needs no git, so it
     holds in a self-test's temporary tree, and no tracked `.gd` lives in
     a dot folder (the only tracked ones are `.githooks/` and `.github/`).
   - Only the parts below the root are asked. Asking the absolute parts, as
     the gdUnit4 exclusion did, would skip every file of a checkout that
     itself lives under `.claude/worktrees/`, which is where this wave was
     written.
   - Planted in `check_readability.py`: a `.gd` under `.user-data/.../tmp/mock`
     and one under `.claude/worktrees/someone-else/` are not read, and a
     checkout under `.claude/worktrees/` still is.
   - `check_no_training.py` reads only `godot/`, so `.user-data/` and
     `.claude/` never reached it. The two cases first planted there were
     inert: the mutation round showed it, because the dot rule deleted
     survived. Its case is now `godot/.godot/`, the one dot folder in its
     reach, and that mutation is killed.
   - On the real tree with a planted `.gd` in this checkout's `.user-data/`
     and one in `.claude/worktrees/planted/`, main's `check_readability.py`
     reported both, and this branch's is green.
5. **Nits:**
   - `said()` asks `all_findings()`, the list, not the printed lines.
     D6 is planted alone (home the checkout's parent's folder, the
     directory inside the checkout and ignored).
   - A timeout is an `OSError`, so exit 2.
   - A wrapper runs only when its code holds the line
     `if [[ "${1:-}" == "--gak-print-redirect" ]]`. Planted: a wrapper
     naming the flag in a comment, which would `touch` a file if run, is not
     run and leaves nothing.
   - `worktree_setup.py`:
     - it copies to a `.<name>.partial` sibling and renames, clearing a
       stale one first;
     - it says when the copied gdUnit4's `.pinned-version` is not the tag
       this checkout's `bootstrap.sh` pins;
     - run in the main checkout, it exits 2 if a needed file is missing
       there;
     - a bare main repository is named as such;
     - each is planted.
   - `Ignored = Callable[[Path, Path], bool]`.
   - D8 refuses a redirect inside `godot/`.
   - The D7 note gives a count and names three.
   - CLAUDE.md lists `make worktree-setup` with the wave commands, in
     their column.

Mutation round after the fixes, 23 mutations, each one alone, against
its script's own `--self-test`: **23 killed**. They cover:
- the gate: D7 overlap, D8 outside, D6 turned into a print, D8 not
  ignored, D8 empty, D8 under `godot/`, `ignored_by_git` returning True,
  other checkouts' D6/D8 counted as findings, every D7 a finding, no D7 a
  finding, this checkout's silent wrapper skipped, and the flag matched
  by text;
- the wrapper changed back to the toolchain;
- each scanner's dot rule, and asking absolute parts (four);
- the setup script: a direct copy, the pin never compared, the main
  checkout always passing, and a bare repository unseen;
- export ignoring the exit code, and export accepting an empty answer.

Re-run after the fixes. `make check` was first left out by the owner's
instruction, then asked for by the coordinator once main had failed it:

| Command | Result |
|---|---|
| `check_disk_layout.py --self-test` | ok |
| `check_disk_layout.py` | 0; one note: 18 other checkouts predate T83 |
| `worktree_setup.py --self-test` | ok |
| `export.py --self-test` | 14 cases, 0 failures |
| `check_readability.py --self-test` | ok |
| `check_readability.py`, with planted `.gd` in `.user-data/` and `.claude/worktrees/` | 0 (main's version: findings on the plant) |
| `check_no_training.py --self-test` | ok |
| `check_no_training.py`, with the same plants | 1 before the N5 fix (main's N5 only); 0 after it |
| `make lint-tasks lint-status` | 0 |
| `check_no_employer_refs.py` | 0, with the term list present |
| `check_doc_freshness.py`, `check_links.py` | 0 |
| `make -k check 2>&1 \| grep -E '^make: \*\*\*'` | prints nothing; `make -k check` exit 0 |

## Added at the coordinator's request: N5's false positive

`make -k check` on main (6905e16) failed two lints. One was
lint-readability (finding 4). The other was lint-no-training: `N5
godot/game/tictactoe/tictactoe_panel.gd:142 changes a bead count`.

- That line continues a Lua-style dictionary literal that wave 91 (T79)
  added for `.format()`: `bead = overlay["bead"], total = overlay["total"]}`.
- N5's "bare reassignment" pattern, `(?:^|;|:)\s*\w*bead\w*\s*=(?!=)`,
  matched the key at the start of the line. The file is main's,
  unchanged here, and main's own copy of the gate reports it.

Fixed in the gate rather than the panel, because the gate can be made
precise:
- GDScript has no braces around blocks, and the code view has blanked
  strings and comments. So a `{` still open at the start of a line opens a
  dictionary.
- `open_braces` tracks that depth line by line. On a line that begins
  inside one, `DICT_KEY_RE` takes off the leading `name =` key only. The
  rest of the line is still read by every pattern, so a write in a value
  is still a write.

Planted in the self-test:
- Read as clean: wave 91's two-line literal with a `bead = ...` key, and a
  multi-line `show({ beads = count, box = 4, })`.
- Still N5: `bead = 3` on the line after a literal closes, `beads[move] +=
  1` after a one-line literal, and `bead = beads.append(1)` inside a
  literal.

Four mutations were killed: the key never taken off, the whole line taken
off, every line treated as inside a literal, and a literal never closing.
