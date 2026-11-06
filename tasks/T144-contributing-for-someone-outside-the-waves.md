# T144 — Contributing, for someone outside the waves

Size: M · Prereqs: T112, T142 · Files: `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CODEOWNERS`, `README.md`, `README.pt-BR.md`

## Goal

The review before the repository opens (T112, wave 143,
`docs/reviews/open-the-repository.md`, finding 6) found that
`CONTRIBUTING.md` describes the author's own wave flow: a contributor cuts
`wave/07-a-slug`, writes `docs/reviews/07-a-slug.md`, runs `make
wave-merge` -- push access, wave numbers and a review record an outsider
cannot produce. It does not describe a fork's pull request, which tier a
change needs, or how a pt-BR page is kept in step with its English one.
There is no issue template, no pull request template, no code of conduct
and no `SECURITY.md`.

## Decisions written down first (the owner confirms in review)

- **Two readers, two sections.** "Contributing" for an outsider comes
  first: fork, a branch named anything, the checks for the tier the change
  touches (`make check-affected BASE=origin/main` with the engine, the
  Python tests and lints without it), a pull request. The owner's review
  is the fresh context invariant 12 asks for, so an outsider writes no
  review record and needs no wave number. The wave flow stays, below,
  under its own heading, for whoever works with push access.
- **Keeping the languages in step**, said plainly: a technique page and
  its `.pt-BR.md` twin change in the same pull request; code and
  docstrings stay English; an English term kept on a pt-BR page is in
  `docs/techniques/glossary.pt-BR.md`; `make lint-translations-docs` and
  `make lint-glossary` hold it. A contributor who writes only one language
  says so, and the twin is a follow-up, not a refusal.
- **Modelled on the owner's public repository desk-panel** (the owner,
  2026-11-06: "Quanto às questões de contribuição podemos seguir o modelo
  do meu repo desk-panel"). Its `CODE_OF_CONDUCT.md` (the Contributor
  Covenant, as its authors wrote it), `CONTRIBUTING.md`, `SECURITY.md`,
  `CODEOWNERS`, `.github/ISSUE_TEMPLATE/` (bug, feature, `config.yml`)
  and `.github/PULL_REQUEST_TEMPLATE.md` are the shape to follow; the
  content is this kit's: tiers, demos and addons, both languages. Nothing
  of desk-panel's own (its devices, its server) is copied.
- **The code of conduct** is desk-panel's, the same version, unchanged,
  with this repository's contact.
- **`SECURITY.md`** says where to report a vulnerability privately
  (GitHub's private reporting, once the repository is public) and that
  the scope is the kit's code, not the games' balance.
- **Templates are short**: an issue says which demo or addon, what was
  expected and what happened, the tier and the system; a pull request says
  what changed, which checks ran, and whether both languages changed. The
  PR template carries no byline and nothing `check_pr_message.py` refuses.

## Steps

1. Ask the owner which code of conduct, and the contact it names.
2. Rewrite `CONTRIBUTING.md` and link it from both READMEs.
3. The templates and `SECURITY.md`.

## Acceptance

```bash
make lint-links
PR_TITLE="docs: a template check" PR_BODY="$(cat .github/pull_request_template.md)" python3 scripts/check_pr_message.py
make lint-workflow
make lint-tasks lint-status
```

## Manual check

Someone who has never contributed here reads `CONTRIBUTING.md` and opens
a pull request from a fork without asking a question the page answers.

## Notes

- Opened by T112 (wave 143), finding 6. T112's notes expected no
  `CONTRIBUTING.md`; there is one, written for waves.
