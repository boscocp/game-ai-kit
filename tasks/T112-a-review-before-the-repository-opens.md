# T112 — A review before the repository opens

Size: M · Prereqs: T87, T88, T94, T96, T110, T111, T120 · Files: `docs/reviews/`, `tasks/`, `README.md`, `README.pt-BR.md`, `CONTRIBUTING.md`, `.github/`

## Goal

The repository is private today. Since 2026-10-22, CI has been off until
it goes public, and an Asset Library entry needs a public repository. The
owner asked on 2026-11-04 for one review of the whole repository before
it opens to the community. The review is read as a stranger would read
it: someone who arrives from a search, wants one technique, and has
never seen the waves.

## Decisions written down first

_The decisions below are this session's proposal, written on 2026-11-04; the owner has not ratified them. The wave that takes the task confirms them, or brings them back to the owner._

- **A report, not a rewrite.** The review writes
  `docs/reviews/open-the-repository.md`. That report holds a finding list
  with file:line and severity, and a list of follow-up tasks. A fix
  smaller than a sentence may land in the same wave. Anything larger
  becomes its own task.
- **Done by a context that wrote none of it** (rule 12), reading cold.
- **What it reads, at least:**
  - the README in both languages, as a first page;
  - every technique page and the guide (T77);
  - every ADR's status line;
  - the invariants table, against what the gates hold;
  - LICENSE, NOTICE and third-party art (ADR on Bos Wars and the sprite
    packs: are the URL and sha256 still right?);
  - invariant 10 across the history (`check_no_employer_refs.py` over
    every commit, not only the tree);
  - secrets in the history;
  - stale worktrees and branches on the remote;
  - the size of the history.
- **What a community needs that is missing:** `CONTRIBUTING.md` (the wave
  flow, made light for an outsider: no wave numbers required); an issue
  and PR template; a code of conduct (the owner chooses which); how
  pt-BR and en are kept in step; and what "tier 1" means for a
  contributor's machine.
- **The owner decides the opening itself.** The review lists what blocks
  it and what does not. Making the repository public, turning CI back on
  (`gh workflow enable ci`) and publishing to PyPI and the Asset Library
  are the owner's, after the review.

## Steps

1. Run every gate (`make check`, `make library-check`, `make release`
   dry), and `check_no_employer_refs.py` over the whole history.
2. Read as above, and write the report.
3. Open the follow-up tasks it names. Write the owner's list, one
   numbered list with a recommendation each.

## Acceptance

```bash
make check
make library-check
python3 scripts/check_no_employer_refs.py
make lint-tasks lint-status lint-links
```

## Manual check

The owner reads the report's blocking list and decides, item by item.

## Notes

- **T120 is a prereq since 2026-11-05.** The owner ratified STATUS's
  2026-11-04 item B6: `GakXorshift`, before anything is published.
