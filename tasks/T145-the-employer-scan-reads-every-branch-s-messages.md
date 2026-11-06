# T145 — The employer scan reads every branch's messages

Size: S · Prereqs: T112 · Files: `scripts/check_no_employer_refs.py`

## Goal

The review before the repository opens (T112, wave 143,
`docs/reviews/open-the-repository.md`, finding 9) found that
`check_no_employer_refs.py` reads every blob on every ref (`rev-list
--all`) but commit messages and identities only along `HEAD` (`git log`).
The remote held 407 commits on finished branches that `main` does not
reach, and a term in one of their messages would be published with them
and never reported. The review checked them by hand and found nothing;
the gate should not need that.

## Decisions written down first (the owner confirms in review)

- Messages and identities are read with `git log --all`, as the blobs
  are, so a branch is scanned whether or not it was merged.
- A planted case: a repository whose term sits only in a commit message
  on a branch `HEAD` does not reach. Today's gate passes it; the new one
  exits 3.
- A finding names the commit, not only the term, so a person can find
  it without reading the term out loud; the term itself is still printed
  only on the machine that holds the list, as today.

## Steps

1. Write the planted case and watch the current gate pass it.
2. Read `--all`, and name the commit in the finding.

## Acceptance

```bash
python3 scripts/check_no_employer_refs.py --self-test
python3 scripts/check_no_employer_refs.py
make lint-selftests
make lint-tasks lint-status
```

## Manual check

None: nothing on screen changes.

## Notes

- Opened by T112 (wave 143), finding 9. A script under `scripts/` is a
  global path: the wave runs all of `make check`.
