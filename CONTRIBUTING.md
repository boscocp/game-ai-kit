# Contributing

This kit exists to be read. Each addon is a technique from the books, written
so a person can follow it top to bottom, and each example game is there so you
can watch that technique decide something. A contribution is welcome when it
keeps that true. The mechanical half of "readable" is checked by commands
below, so nobody has to argue about it by hand; the other half is what review
is for.

There are two ways in, and this page has a section for each:

- **[From a fork](#contributing-from-a-fork)**, for anyone. No push access, no
  wave number, no review record to write.
- **[With push access](#working-with-push-access-the-waves)**, the owner's own
  flow, in numbered waves.

Everyone here follows the [code of conduct](CODE_OF_CONDUCT.md). A
vulnerability is reported privately, as [SECURITY.md](SECURITY.md) says, never
in a public issue. A question goes in as an issue too, through the idea
template: there is no separate forum.

## What the kit accepts

- **Bug reports, from anybody**, through the bug template: which demo, addon or
  command, what you expected, what happened, the tier and your system.
- **Fixes and clearer code** in an addon, an example or the Python trainer.
  A passage made easier to read is a contribution here, not a cosmetic one.
- **Technique pages**, in English, in Portuguese, or both
  ([below](#keeping-the-two-languages-in-step)).
- **A new technique or example**: open an issue with the idea template first.
  It is where the conversation about where it fits happens, before anyone
  spends an evening on it.

What it does not accept, each a rule the kit holds on purpose, argued in
[docs/adr/](docs/adr/) rather than an oversight:

- a lesson that needs hardware above **tier 1** to learn from (the tiers are
  in the [README](README.md#will-it-run-on-my-machine));
- an addon that depends on another addon -- only on `ai_core`, so someone who
  wants A\* copies two folders;
- training while the game runs: Python trains and writes weights, GDScript
  only infers. The few exceptions -- counts kept during one fight or match,
  starting empty, never saved -- are named in ADR 0016, and
  `scripts/check_no_training.py` holds them as its rules N9, N13 and N14;
- an LLM reply that becomes an action without a validator, or a frame that
  waits on one;
- a dependency in `python/`, which uses the standard library only: tier 1
  has no install step.

## Contributing from a fork

1. **Fork** the repository on GitHub and clone your fork. Add this one as
   `upstream`, so the checks can compare your branch with it:

   ```bash
   git remote add upstream https://github.com/boscocp/game-ai-kit.git
   git fetch upstream
   ```

2. **A branch named anything**, cut from `upstream/main`. You need no wave
   number; that numbering is the owner's bookkeeping.
3. **Optionally, the hooks**: `make hooks` runs the commit-message check on
   every commit, so a message the pull request would refuse is refused
   locally first. It also refuses a commit on `main`: work on a branch (its
   message points at the owner's wave commands, which you can ignore).
4. **Make the change**, and run the checks for the tier it touches
   ([next section](#which-checks-for-which-change)).
5. **Open a pull request** against `main`. The template asks what changed and
   why, which checks ran, and whether both languages changed.

The owner reviews every pull request. That review is the fresh pair of eyes
the waves below write a record for, so a pull request from a fork needs no
`docs/reviews/` file: whatever it finds is answered on your branch, and the
owner merges once it is green.

## Which checks for which change

The README's tiers say what each kind of change needs installed.

| what you changed | install | run |
|---|---|---|
| docs, a technique page | Python 3.12 or later (tier 1) | `make check-no-engine` |
| the Python package or its tests | Python (tier 1), and Godot if the next paragraph says so | `make affected BASE=upstream/main` first, then as it says |
| an addon, an example, a GDScript test | Godot, through `make bootstrap` (tier 2) | `make check-affected BASE=upstream/main` |
| the gates themselves, the Makefile, CI | Godot (tier 2) | the same: it selects every gate |

`make check-no-engine` is every lint and the Python tests: no engine, no
install step. `make check-affected` adds the engine's tests of the modules
your change touches, and of every module that uses them; `make affected
BASE=upstream/main` prints which, and why. A change to a script, the
Makefile or CI selects all of them, which is what `make check` runs.

A change in `python/` is not always tier 1. Many Python folders belong to a
module that also holds GDScript, and its users are examples with Godot
suites: even a comment in `python/gameaikit/tactical/` selects them, and a change
to `python/gameaikit/__init__.py` or `techniques.py` selects everything. Run
`make affected BASE=upstream/main`: if it names modules, run
`make check-affected BASE=upstream/main` with the engine, or run
`make check-no-engine` and say in the pull request that the engine's tests
did not run -- the owner's run covers them.

Three things that will save you time:

- **Godot is only ever run through `./scripts/godot`** (or a make target),
  never the binary directly: the wrapper keeps the engine's settings beside
  its binary and the project's `user://` inside the checkout, out of your
  home folder. `make bootstrap` installs the
  pinned version, checked by SHA-512.
- **A new file needs an owner.** Every file under `godot/`, `python/`,
  `spec/`, `data/` and `tools/` belongs to a module in `modules/*.json`, and
  `make lint-modules` refuses one nobody owns. A new test goes in
  `godot/test/<module>/` or `python/tests/`.
- **One lint reads a list kept outside the repository** (ADR 0005). On your
  clone it prints a note that it checked nothing; the owner's run is the one
  that counts for it.

When a check fails and you cannot see why, say so in the pull request and
paste its output. A red check explained is more useful than a green one
nobody ran.

## Keeping the two languages in step

The technique pages under `docs/techniques/` exist in English and in
Brazilian Portuguese, `<name>.md` beside `<name>.pt-BR.md`.

- **A page and its twin change in the same pull request.** The pt-BR page
  records a hash of the English one in its `translation_of:` field, so
  `make lint-translations-docs` notices the day they drift (finding D5), and
  it also compares their sections and code blocks.
- **Code, comments and docstrings stay in English**, in both, and code blocks
  are the same byte for byte (finding D8): a changed code block is changed in
  both files, whichever language you write.
- **An English term kept on a pt-BR page** -- *pathfinding*, *steering* --
  is in italics the first time and listed in
  [the glossary](docs/techniques/glossary.pt-BR.md); `make lint-glossary`
  holds that.
- **If you write only one language, say so** in the pull request. The twin is
  a follow-up, not a reason to refuse your change. Expect
  `make lint-translations-docs` to go red with D5 on that page: leave it red
  and say so, and the owner updates the twin. If you did update the twin, the
  message prints the new hash; set `translation_of:` to it.

An issue or a pull request may be written in either language.

## What the code is held to

### Teaching material before it is a library

If a passage is fast and unreadable, it loses to the slow and readable one,
and the exception needs a benchmark rather than an opinion.
`check_readability.py` holds the mechanical half: functions of 40 lines or
fewer, nesting of 3 or less, static types everywhere, a doc comment on every
public function saying what and why, no single-letter names beyond the
literature's `g`, `h` and `f`, no invented abbreviations. The half it cannot
hold is the review's: does the file read in the order the algorithm is
explained, and does its header say when *not* to use it?

### Every acceptance criterion is a command with an exit code

A game is visual, and that is exactly where "it looks like it works" turns
into debt. Anything that needs a person to look goes under `## Manual check`,
where nothing pretends to have an exit code. `check_acceptance.py` enforces
the distinction.

Before trusting a criterion, run it against the commit *before* your change.
If it is already green there, it is not testing what you think.

### Every example can be watched

A demo shows what the AI is about to do and why -- the search's frontier, the
planner's step, the probability the policy computed -- not only the outcome.
`make lint-demos` checks that the overlay is populated; whether it teaches is
for a person to see, so say in the pull request whether you opened the demo.

### Every gate is born with a case it must reject

A gate that only knows how to go green is the most expensive defect in a
repository, because nobody investigates a green. So every
`scripts/check_*.py` carries a `--self-test` with planted cases, and
`make lint-selftests` finds them by glob rather than by a list. When you add
one, ask it: *does this pass on an empty tree?*

### Check the documentation before writing the rule

Before writing a gate or a line of code that depends on how Godot behaves,
read the official documentation for the version in `.godot-version`, then
measure to confirm. Findings go in `docs/godot/` with the source URL and a
`verified_on` date.

## Commit messages

Conventional commits, lowercase, imperative, 80 characters or fewer in the
subject; the types are `feat`, `fix`, `docs`, `test`, `chore`, `refactor` and
`ci`. `scripts/check_commit_msg.py` checks the shape, never the content. The
body is for *why*; it can be long.

**No tooling byline, anywhere.** Commits, pull request titles and pull
request bodies carry one author and no assistant attribution -- no
`Co-Authored-By:`, no "Generated with", no robot emoji. The hook checks
commits locally, and `scripts/check_pr_message.py` checks a pull request's
title and body, because a squash merge turns that body into a commit message
on `main`. Leave the title room for the " (#NN)" the merge appends.

## Working with push access: the waves

This is the owner's flow, for whoever works with push access. A contributor
from a fork can skip it.

```bash
make bootstrap
make hooks                                  # opt in; git does not run hooks from a clone
make wave-start BRANCH=wave/07-a-slug       # a branch per wave, from a current main
# work
make check-affected BASE=origin/main
# push, open a pull request, have it reviewed by someone, or something,
# that did not write it; write docs/reviews/07-a-slug.md
make wave-merge                             # squash-merges the pull request
```

Each wave closes a task file in `tasks/`, indexed by `tasks/STATUS.md`.

### Reviews land before the merge, not after

This is the one rule the rest of the apparatus depends on. Every gate in
`scripts/` exists because the same person writing the code, the test and the
check will write the same misunderstanding into all three. A review in a
fresh context is what breaks that, and a review after the merge breaks
nothing -- it produces a follow-up issue, which is not the same thing.

The rule is enforced rather than stated:

- `.githooks/pre-commit` refuses a commit on `main`;
- `make wave-merge` refuses a branch with no `docs/reviews/<slug>.md`, and
  refuses a record whose sections are empty.

It is enforced because it was already broken once, here, in this
repository's first four waves. A sentence in a guide would not have stopped
that.

## The CLAUDE.md files

They are instructions for coding agents. A person never needs to read one,
and anything in them that a contributor needs to know is a bug in this file.
