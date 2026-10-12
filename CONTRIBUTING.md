# Contributing

## The short version

```bash
make bootstrap
make hooks                              # opt in; git does not run hooks from a clone
make wave-start BRANCH=wave/07-a-slug
# work
make check
# get the diff reviewed by someone, or something, that did not write it
# write docs/reviews/07-a-slug.md
make wave-merge
```

## Reviews land before the merge, not after

This is the one rule the rest of the apparatus depends on. Every gate in
`scripts/` exists because the same person writing the code, the test and the
check will write the same misunderstanding into all three. A review in a fresh
context is what breaks that, and a review after the merge breaks nothing — it
produces a follow-up issue, which is not the same thing.

The rule is enforced in two places rather than stated in one:

- `.githooks/pre-commit` refuses a commit on `main`;
- `make wave-merge` refuses a branch with no `docs/reviews/<slug>.md`, and
  refuses a record whose sections are empty.

It is enforced because it was already broken once, here, in this repository's
first four waves. A sentence in a guide would not have stopped that.

## Every acceptance criterion is a command with an exit code

A game is visual, and that is exactly where "it looks like it works" turns into
debt. Anything that needs a person to look goes under `## Manual check`, where
nothing pretends to have an exit code. `check_acceptance.py` enforces the
distinction.

Before trusting a criterion, run it against the commit *before* your change. If
it is already green there, it is not testing what you think.

## Every gate is born with a case it must reject

A gate that only knows how to go green is the most expensive defect in a
repository, because nobody investigates a green. So every `scripts/check_*.py`
carries a `--self-test` with planted cases, and `make lint-selftests` finds them
by glob rather than by a list — a gate left out of a list is a gate that
silently stops running.

When you add one, ask it the question that catches most of them: *does this pass
on an empty tree?*

## The code is teaching material before it is a library

If a passage is fast and unreadable, it loses to the slow and readable one, and
the exception needs a benchmark rather than an opinion. `check_readability.py`
holds the mechanical half — function length, nesting, type annotations, doc
comments on public functions. The half it cannot hold is yours: does the file
read in the order the algorithm is explained, and does its header say when *not*
to use it?

## Check the documentation before writing the rule

Before writing a gate or a line of code that depends on how Godot behaves, read
the official documentation for the version in `.godot-version`, then measure to
confirm. Three things in this repository were wrong because that order was
reversed. Findings go in `docs/godot/` with the source URL and a `verified_on`
date.

## Commit messages

Conventional commits, lowercase, imperative, 80 characters or fewer in the
subject. `scripts/check_commit_msg.py` checks the shape, never the content. The
body is for *why*; it can be long.

**No tooling byline, anywhere.** Commits, pull request titles and pull request
bodies carry one author and no assistant attribution — no `Co-Authored-By:`, no
"Generated with", no robot emoji. This is checked in two places, because a hook
cannot see a pull request: `.githooks/commit-msg` locally, and a CI step that
reads the PR's title and body through `env:` and runs them through the same
script. A squash merge turns that PR body into a commit message on `main`, which
is exactly why it is checked there rather than trusted.

## The CLAUDE.md files

They are instructions for coding agents. A human never needs to read one, and
anything in them that a contributor needs to know is a bug in this file.
