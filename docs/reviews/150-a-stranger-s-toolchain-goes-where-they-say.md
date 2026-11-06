# Review: wave/150-a-stranger-s-toolchain-goes-where-they-say

T143, from T112's finding 1: only the author could run `make bootstrap`.
The PR gives the toolchain one name, `GAK_TOOLCHAIN`. It moves the default
into the checkout as `.toolchain`, and narrows `check_disk_layout.py` so a
stranger's machine passes: D1 counts only what this repository wrote, and
D5/D6 count the home only when the toolchain is off it. It amends ADR 0002
and rewords invariant 8.

A fresh context reviewed PR #103 at head 73c505a (base e645827). It made
no commit and no comment on the PR. The coordinator relayed the findings
and decided the open options. This record was written by the implementer
on the same branch, after the review, as the routine asks.

**Verdict: changes requested. Two blockers, five should-fix, four nits.**

## What was reviewed

- The task file, `CLAUDE.md` (invariants 4, 8, 11 and 12), ADR 0002 and
  ADR 0022, and the PR body with its four questions for the owner.
- The diff: the Makefile's toolchain block and `bootstrap`,
  `scripts/check_disk_layout.py` (D1's attribution, the record, D5/D6),
  `scripts/worktree_setup.py`, `.gitignore`, `scripts/godot`, `llm`,
  `artgen`, `export.py`, both READMEs and `docs/howto/windows.md`.
- Behaviour, measured: a linked `.toolchain` in `git status`, the
  `make bootstrap TOOLCHAIN=/x` then `make menu` sequence from the task's
  Goal, empty `TOOLCHAIN=` / `GAK_TOOLCHAIN=`, and a fresh record after
  `rm -rf .toolchain`.
- Text elsewhere that still speaks of "the large disk" or the author's
  path as the default.

## Findings

1. **Blocker.** `.gitignore`'s `/.toolchain/` does not ignore a link:
   with a trailing slash the rule matches only a directory. Measured as
   `?? .toolchain` after `make worktree-setup`.
2. **Blocker.** A variable on make's command line lives one command, so
   `make bootstrap TOOLCHAIN=/x` followed by `make menu` still looked in
   `<checkout>/.toolchain`. That is the very scenario the task's Goal
   names. The Makefile comment, the commit message, the PR body and
   `windows.md` all claimed otherwise.
3. **Should.** Invariant 8's wording and the ADR amendment claim more than
   D1 holds. D1 only counts the project's own `user://` and five model
   caches; `~/.config/godot` is a note, so a `._sc_` the engine stopped
   honouring is no longer caught. The amendment also called the old
   mechanisms "unchanged and still asserted" while it quietly replaced a
   Consequences bullet.
4. **Should.** A fresh record taken after `rm -rf .toolchain && make
   bootstrap` forgives the project's own `user://`: the record launders it.
5. **Should.** `worktree_setup.py`'s Windows note printed `C:\...`, and
   the Makefile's absolute-path test refused that form.
6. **Should.** On the author's machine nothing sets `GAK_TOOLCHAIN`, so
   after the merge every worktree would look in its own empty
   `.toolchain`.
7. **Should.** Stale text:
   - `docs/howto/publish.md` (invariant 8 as "the large disk", and the
     author's path as "the Makefile's default"), and the tier-3 line of
     both READMEs;
   - ADR 0022 on D5;
   - comments in `export.py`, `godot_shards.py`, `tools/llm/llm.py` and
     `tools/artgen/` (both files), and two "small disk" strings in the
     gate;
   - one row of `windows.md`.
8. **Nit.** The `late` case planted only the Linux binary; a mutation
   that ignored `godot.exe` survived.
9. **Nit.** An empty `TOOLCHAIN=` or `GAK_TOOLCHAIN=` gave a confusing
   error, and nothing said that a path with a space is unsupported.
10. **Nit.** `attribution_cases` was 44 lines long.
11. **Nit.** The PR did not say that `TOOLCHAIN` in the environment is
    ignored on purpose, a departure from the task's "setting either
    works".
12. **Nit.** The pt-BR README translated "export templates", which the
    glossary rule keeps in English.

## What was done about them

1. `/.toolchain`, no slash, with a comment saying why. A new
   `worktree_setup.py` self-test case asks git itself (`check-ignore`,
   using the repository's real `.gitignore`) whether a linked `.toolchain`
   is ignored. Putting the slash back makes the self-test fail.
2. Option (a), the coordinator's choice. After `bootstrap.sh` succeeds,
   `make bootstrap` runs `worktree_setup.py --remember-toolchain
   "$(GAK_TOOLCHAIN)"`. That links `.toolchain` to the install when it is
   not the default and no `.toolchain` exists yet; an existing one is
   never replaced, only reported. Planted cases:
   - the link is made when bootstrap installs elsewhere;
   - no link is made for the default itself;
   - an existing `.toolchain` is kept.

   Measured end to end: `make bootstrap TOOLCHAIN=<scratch>` left the
   link, and a bare `make godot-version` and `make lint-disk-layout` then
   used it. The Makefile comment, `windows.md` and the PR body now
   describe this; the commit message of this fix says it too.
3. Row 8 of `CLAUDE.md` is now "half held", says what D1, D3/D4 and D6-D8
   hold, and names what they miss. The preamble now counts five half-held
   invariants. The amendment has a new section, "What it no longer
   sees": the `._sc_` gap, which Godot wrote the project's `user://`, and
   a cache older than the newest record. It says it supersedes the second
   Consequences bullet, and it drops the overclaim. The optional idea of
   recording Godot's folders was not taken.
4. Option (a), the coordinator's choice. The project's own `user://` is
   never forgiven, and the record holds only the model caches. Planted:
   the folder written into a record by hand is still counted. The
   residual limit for model caches is stated in the ADR.
5. The notes print `as_posix()`, and the Makefile also accepts `X:\`.
   Measured: `TOOLCHAIN=C:\tc` and `TOOLCHAIN=C:/tc` are both taken.
6. The coordinator decided this one: right after the merge it links the
   main checkout's `.toolchain` to `/mnt/games/gamedev/toolchain` and
   reruns `make worktree-setup` in the live worktrees. The step is written
   in `docs/howto/parallel-batch.md` and in the PR body.
7. Every place listed was corrected. `publish.md` now uses
   `${GAK_TOOLCHAIN:-$PWD/.toolchain}`.
8. The `late` case is now planted for both `godot` and `godot.exe`. The
   eleven mutations of the new rules, the Windows one included, are each
   rejected by the self-test.
9. Empty values count as unset, through `override`. Measured: `make
   TOOLCHAIN=` and `make GAK_TOOLCHAIN=` both use the default, and
   `TOOLCHAIN=/a GAK_TOOLCHAIN=` uses `/a`. The comment now says paths
   with a space are not supported.
10. It is split in two: `attribution_cases` (whose folder it is) and
    `record_cases` (what the record forgives).
11. The ADR amendment and the PR body now state it.
12. The pt-BR line now says "export templates".
