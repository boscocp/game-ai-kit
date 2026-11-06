# Review: wave/143-a-review-before-the-repository-opens

T112 reviews the whole repository before it is made public. It adds
`docs/reviews/open-the-repository.md` (twelve findings, a blocks / does
not block split, four follow-up tasks), opens T142 to T145 with their
STATUS rows, and lands three fixes smaller than a sentence: the thirteen
technique pages' catalogue lines in both languages (with new pt-BR
`translation_of` hashes), the art credit in `NOTICE` and `python/NOTICE`,
and `CLAUDE.md`'s invariant-13 row.

A fresh context reviewed PR #93 at head fe8ce83 (base f6f9c2c), reading
the diff with `git show` and running the lints in a throwaway detached
worktree, since removed. It made no commit, push or PR comment.

**Verdict: approve with fixes. No blocker, three should-fix findings and
four nits.** Every blocking finding of the report was checked against
the code and holds. The in-wave fixes are right. The gaps are in what the
report says it checked: one claim about platforms is wrong, two archive
hashes were never re-verified and are not said to be, and the report
does not show what it read where it found nothing.

## What was reviewed

- T112's "Decisions" and "What it reads", item by item, against the
  report.
- Finding 1 against the code: `Makefile:21` (`TOOLCHAIN ?=
  /mnt/games/...`), `Makefile:47` (the only place `GAK_TOOLCHAIN` is
  passed), `scripts/godot:41`, `scripts/llm:26`, `scripts/artgen:22`,
  `scripts/export.py:64`, `scripts/check_disk_layout.py:99` and `:113`
  (D1 on any `~/.local/share/godot`), `.github/workflows/ci.yml:80`,
  `:89`. All hold.
- Finding 2 against `README.md:12-14`, `:66-69`, `:90`, `:126`, `:175`,
  `README.pt-BR.md:90`, `python/pyproject.toml:19`,
  `docs/techniques/ai_llm.md:8`, `:48-49`, `ai_llm.pt-BR.md:52`. All hold.
- Finding 6 against `CONTRIBUTING.md:1-15`, `:76-82`, and `.github/`
  (only `workflows/ci.yml`). Holds.
- Finding 9 against `scripts/check_no_employer_refs.py:254` (`git log`
  along HEAD) and the `rev-list --all` below it. Holds.
- Finding 7: `git ls-remote` shows 106 heads before this wave (107 with
  it). 66 are contained in `origin/main` and 39 are heads of merged pull
  requests. The 7 `worktree-agent-*` heads are among the 66. The
  repository's description is empty, it has no topics and
  `deleteBranchOnMerge` is false. Holds.
- Finding 10: every ADR status line read. 0023 is the only `proposed`.
- `NOTICE` against `godot/assets/LICENCES.md`. Apart from
  `godot/assets/`, no image, sound, model or font is committed.
  `NOTICE` and `python/NOTICE` are byte-identical.
- The invariant-13 row against `scripts/check_demos.py`'s docstring,
  `Makefile:120,164-165,702-706` and `godot/test/menu/demo_overlays.gd`.
- The 26 catalogue links: each anchor exists in `catalogue.md` /
  `catalogue.pt-BR.md`.
- T142 to T145 against `tasks/T135-*.md`'s shape. Every make target
  their acceptance names exists in the Makefile.
- Invariant 11: the commit's message and identity, the PR title and body
  (`make lint-pr-message`, `check_commit_msg.py`, both exit 0), and
  `git log --all` for trailers (none; the one hit is prose describing the
  rule).
- Run at fe8ce83: `check_status.py`, `check_links.py`,
  `check_translations_docs.py`, `check_doc_freshness.py`,
  `check_demos.py`, `make lint-tasks lint-status lint-links`: exit 0
  each. `make check` was not rerun here (the PR reports it).

## Findings

1. **should fix** -- `docs/reviews/open-the-repository.md:59-60`: "which
   systems `make bootstrap` supports (Linux x86_64 only,
   `scripts/bootstrap.sh:41`)". `scripts/bootstrap.sh:31-41` has a
   Windows (Git Bash) branch that installs the win64 zip, and
   `Makefile:15-16` sets a Windows `TOOLCHAIN`. T143's own decision
   already says it correctly. Fix: "Linux x86_64 and Windows through Git
   Bash (`scripts/bootstrap.sh:35`); not macOS".

2. **should fix** -- `docs/reviews/open-the-repository.md:226-236`
   (finding 12) and the "What was run" row: "every third-party URL ...
   13 of 16", and "every reachable hash matches". `LICENCES.md` names two
   more archive hashes that the sixteen do not include:
   `puny-characters.zip` (OpenGameArt, reachable) and
   `kenney_racing-pack.zip`. The report neither verifies them nor says
   they were skipped, so "every reachable hash" overclaims. Fix: download
   and hash `puny-characters.zip`. Add the racing pack zip to the manual
   check, next to the other kenney.nl items.

3. **should fix** -- the report as a whole, against T112's "What it reads".
   An item that turned up a finding is visible. An item that turned up
   nothing is not: every technique page, the T77 library guide
   (`using-the-library.md` is cited once, for a Python version), and the
   community items "how pt-BR and en are kept in step" and "what tier 1
   means for a contributor's machine" (these two are folded into
   finding 6 and T144). Invariant 1 of this repository is that green is
   not trusted without a record. Fix: add a short "What was read" list
   under "What was run", one line per T112 item, saying read and the
   finding number, or "nothing found".

4. **nit** -- `open-the-repository.md:84-85`: the quoted `invalidated_if`
   reads "this page does not change". `ai_llm.md:8` says "this page does
   not name it". Fix: quote it exactly.

5. **nit** -- `open-the-repository.md:151-153`, and owner's list item 4
   in the PR body: "66 ... 39 ... and 7 are named `worktree-agent-*`"
   reads as 112 branches. The 7 are among the 66. Fix: "of which 7 are
   named ...".

6. **nit** -- the PR body's owner's list. Items 8 and 9 say "Decide
   whether ..." and give no recommendation, which T112's step 3 asks of
   each item. Item 6 ("Run T145 before opening") contradicts the
   report's "Does not block" list, which places T145 below the line.
   Fix: give 8 and 9 a recommendation (e.g. 8: keep history, use the
   no-reply address for future commits). For item 6, either move T145
   above the line in the report or say "recommended, not blocking".

7. **nit** -- the report's "What was run" table has no row for
   invariant 11 across the history. It is clean: I ran `git log --all`
   for `Co-Authored-By` and "Generated with" lines and found nothing.
   Because the 39 unmerged branch heads become public with the
   repository, the row is worth adding.

No finding against the fixes themselves. The art credit now matches
`LICENCES.md` (Kenney's five packs, Shade's Puny Characters,
Puffolotti's Mustermann 2, all CC0). The pt-BR hashes pass
`check_translations_docs.py`. The invariant-13 row says exactly what
`check_demos.py` and `demo_overlays.gd` hold. No secret, credential or
employer term was seen in the diff.

## What was done about them

All seven were applied on the same branch, in
`docs/reviews/open-the-repository.md` and the PR body.

1. Fixed: finding 1 now says Linux x86_64, and Windows through Git Bash
   (`scripts/bootstrap.sh:34`). On macOS the script would fetch the Linux
   build.
2. Fixed: `puny-characters.zip` was downloaded from OpenGameArt and
   matches `LICENCES.md`'s sha256. Its four walking sheets match the
   committed files byte for byte. "What was run" now says 14 of 18.
   `kenney_racing-pack.zip` joins the other kenney.nl items in the manual
   check, and no way round the 403 was tried.
3. Fixed: a "What was read" section lists each T112 item, with its
   finding number or "nothing found". It covers the technique pages, the
   T77 guide, how pt-BR and en are kept in step, and tier 1 for a
   contributor.
4. Fixed: the quote now reads "this page does not name it", as
   `ai_llm.md:8` says.
5. Fixed: the report says the 7 `worktree-agent-*` heads are among the 66.
   Owner's item 4 is reworded the same way.
6. Fixed: T145 stays below the line. The report and owner's item 6 both
   say "recommended before opening, not blocking". Items 8 and 9 now
   carry a recommendation each.
7. Fixed: "What was run" has an invariant-11 row. `git log --all` was
   rerun for `Co-Authored-By:`, "Generated with" and the robot emoji, and
   found 0.
