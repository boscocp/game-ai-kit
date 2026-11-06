# Review: wave/151-contributing-for-someone-outside-the-waves

T144 rewrites `CONTRIBUTING.md` for someone outside the waves (a fork's
pull request first, the waves last), and adds what desk-panel, the
owner's public repository, carries: the Contributor Covenant 2.1, a
`SECURITY.md`, `CODEOWNERS`, a bug and an idea issue template with
`config.yml`, and a pull request template. By the owner's word during the
wave it also adds a support section to both READMEs (GitHub Sponsors, then
a Pix key) and `.github/FUNDING.yml`. The new root files, the templates
and `FUNDING.yml` became prose to `affected.py`, by name.

A fresh context reviewed PR #104 at head ae19457 (base origin/main
e645827). **Verdict: approve once the four should-fix findings are
fixed. No blocker; four should-fix, four nits.**

## What was reviewed

- The task file, `CLAUDE.md`'s invariants, desk-panel's files the task
  names, and the PR's title and body.
- The diff: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `CODEOWNERS`, `.github/ISSUE_TEMPLATE/`,
  `.github/pull_request_template.md`, `.github/FUNDING.yml`, both READMEs,
  and the PROSE list in `scripts/check_modules.py` with its self-test
  cases in `scripts/affected.py`.
- Each claim in `CONTRIBUTING.md` and `SECURITY.md` against the scripts it
  names: `affected.py`, `check_translations_docs.py`,
  `check_no_training.py`, the pre-commit hook and the download targets.

## Findings

1. **Should.** `CONTRIBUTING.md`'s table put "the Python package or its
   tests" at tier 1 with `make check-no-engine`. False: a comment in
   `python/gameaikit/{maze,racing,tactical,pddl}` selects 17 modules with
   Godot suites, and `__init__.py` or `techniques.py` select everything.
2. **Should.** A change in one language makes `check_translations_docs.py`
   report D5 (a stale `translation_of`), and D8 if a code block changed,
   so the contributor's own check goes red; the page did not say so, nor
   who updates the hash, nor that a code block must change in both files.
   Same in the pull request template.
3. **Should.** `SECURITY.md` and `config.yml` implied private
   vulnerability reporting arrives with a public repository. It does not:
   the owner enables it per repository.
4. **Should.** The tier-2 path depends on PR #103 (T143): today
   `lint-disk-layout` fails for a stranger off the large disk. After the
   rebase, the table's engine row should say what the README's Getting
   started says about the supported systems.
5. **Nit.** `make hooks` also enables the pre-commit hook, which refuses a
   commit on `main` and points at the owner's wave commands.
6. **Nit.** `SECURITY.md` named four download targets; there are more
   (`fighter-sheets`, `artgen-bootstrap`).
7. **Nit.** With blank issues off and no Discussions, a question has
   nowhere to go; say it goes in as an issue, through the idea template.
8. **Nit.** The training exceptions are named in ADR 0016 and held by
   `check_no_training.py` as N9, N13 and N14, not by the ADR alone.

## What was done about them

1. The table splits docs from the Python package. The Python row says to
   run `make affected BASE=upstream/main` first, and a paragraph says why a
   Python change is not always tier 1: run `make check-affected` with the
   engine, or `make check-no-engine` and say in the pull request that the
   engine's tests did not run. Confirmed with
   `affected.py --paths` on `python/gameaikit/tactical/__init__.py`.
2. The languages section names D5 and D8, says a changed code block
   changes in both files, and that a one-language change leaves D5 red on
   purpose: the contributor says so and the owner updates the twin, or
   sets `translation_of:` to the hash the message prints. The pull request
   template says the same, and still passes `check_pr_message.py`.
3. Both now say "once the repository is public and private vulnerability
   reporting is enabled on it"; `config.yml` points at the email in
   `SECURITY.md` meanwhile. Enabling it goes on the owner's opening list.
4. Rebased on #103 (T143, c18d475): the engine row now says what the
   README's Getting started says -- Linux on x86_64, or Windows through
   Git Bash, not macOS yet -- and the note on `./scripts/godot` says
   `make bootstrap` installs into `.toolchain/` or `GAK_TOOLCHAIN`.
5. Step 3 of the fork flow says the hook refuses a commit on `main`, to
   work on a branch, and that its message's wave commands can be ignored.
6. `SECURITY.md` says "every target that downloads -- such as" and lists
   six, and that each is meant to refuse a file whose hash differs.
7. `CONTRIBUTING.md` says a question goes in as an issue, through the
   idea template. Blank issues stay off, with no Discussions (the owner's
   to confirm).
8. The rule now reads: counts kept during one fight or match, starting
   empty, never saved, named in ADR 0016 and held by
   `scripts/check_no_training.py` as N9, N13 and N14.
