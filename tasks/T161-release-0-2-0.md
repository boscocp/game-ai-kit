# T161 — Release 0.2.0

Size: S · Prereqs: T160, T162, T158, T140, T141, T146, T148, T121 · Files: `VERSION`, `python/pyproject.toml`, `tools/store/published.json`, `docs/howto/publish.md`, `README.md`, `README.pt-BR.md`

## Goal

The store and PyPI have 0.1.0. Since that upload the addons gained
`ai_bayes`, the learned tree and forest, the flock rules and `rts_crowd`.
The boss-fight batch will add attack tokens and rings. The follow-ups will
fix what earlier waves left open. 0.2.0 ships all of that at once.

## Decisions written down first

_The owner decided on 2026-11-10 that the new version goes to the store only
after the boss-fight batch (T154-T158) and the remaining follow-ups. The
rest is this session's proposal._

- **Built from the tag, never from a working tree.** The wave bumps
  `VERSION`, tags `v0.2.0`, and builds from that tag. Then it records the
  zip's sha256 in `tools/store/published.json` with `provenance: v0.2.0`.
- **What changed is written for the person installing**, in the release
  notes and on the store page: the new addons and classes, by name.
- **The owner uploads** to the store and to PyPI. The wave prepares
  everything, then runs `make check-published` against the uploaded file
  once the store serves it.

## Acceptance

```bash
make check
make release
make library-check
make check-published
```

## Manual check

- The owner uploads to the store and PyPI. Then they install from the
  editor's AssetLib tab into an empty project.
