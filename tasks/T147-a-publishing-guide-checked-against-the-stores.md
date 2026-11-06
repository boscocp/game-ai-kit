# T147 — A publishing guide, checked against the stores

Size: M · Prereqs: T112 · Files: `docs/howto/`, `docs/adr/0009-the-release-is-built-by-hand.md`, `scripts/release.py`, `python/pyproject.toml`, `README.md`, `README.pt-BR.md`

## Goal

The owner will publish the addons to the Godot Asset Library and the
wheel `gameaikit` to PyPI once the repository is public (2026-11-06, after
T112). `make release` builds one zip per technique addon and the kernel,
and one wheel (ADR 0009), and ADR 0009 makes the upload the owner's, by
hand. Nothing says how, step by step, and one assumption has never been
checked against the stores' own rules: as far as this session recalls,
an Asset Library entry points at a repository host and a commit and the
library downloads that archive, rather than taking an uploaded zip. If
so, twenty zips are not what it installs, and the packaging may have to
change. That recollection is exactly what CLAUDE.md says to read the
documentation for before writing a rule.

## Decisions written down first (the owner confirms in review)

- **Read first, then write.** The Asset Library's submission rules (and
  the newer Asset Store's, if it accepts entries now), PyPI's packaging and
  trusted-publishing guides, and whether the name `gameaikit` is free on
  PyPI. Each finding goes in `docs/godot/` or the guide with its URL and a
  `verified_on` date.
- **One guide**, `docs/howto/publish.md`: what to run, what to check, what
  to fill in each store, in order, from a clean `main` and `make release`.
  The upload stays the owner's: no wave publishes and no workflow holds a
  token (ADR 0009).
- **If the stores' rules do not fit what `make release` builds**, the
  smallest change that fits is written here, with ADR 0009 amended; a
  larger one becomes its own task before publishing.
- **One entry per addon or one for the kit** is the owner's choice,
  brought back as a numbered item with a recommendation.

## Steps

1. Read the stores' current rules and record what they require.
2. Compare with `make release`'s output and `python/pyproject.toml`.
3. Write the guide, and change or open what does not fit.

## Acceptance

```bash
make release
make library-check
make lint-links lint-docs-freshness
make lint-tasks lint-status
```

## Manual check

The owner follows the guide on a test entry (TestPyPI first) and says
where it was unclear.

## Notes

- Opened on 2026-11-06 with the owner's order: open the repository first
  (T143, T144, this), then only T113-T115, follow-ups last.
