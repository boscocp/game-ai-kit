# 0009 — The release is built by hand, from committed files

Status: accepted · 2026-10-13 (T7)

## Context

T7 asks for `make release`: one zip per addon, a Python wheel, and proof that
every artifact carries `LICENSE` and `NOTICE`. The ordinary way to build a
wheel is a build backend -- setuptools, hatchling -- installed with pip. The
Python here is standard library only, and CI's tier-1 job asserts that by
having no install step.

## Decision

`scripts/release.py` writes every artifact itself, with `zipfile`:

- an addon zip has one top folder named after the addon, with the root
  `LICENSE` and `NOTICE` and a `VERSION` file beside the code;
- the wheel is a pure `py3-none-any` zip with `METADATA`, `WHEEL` and
  `RECORD` written out, and the attribution in `.dist-info/licenses/`, where
  PEP 639 puts it;
- only files `git ls-files` lists are shipped, so the release contains nothing
  a commit does not;
- every entry has a fixed date and mode, and the build is byte-for-byte
  reproducible.

The build does not get to say it attributed anything. `check_license.py`
opens every archive and looks, and `release.py --skip-notice` builds a release
that must fail it, once per artifact.

## Alternatives considered

- **A `pyproject.toml` and `python -m build`.** The standard path. Rejected:
  it needs an install step this project's tier 1 promises not to have, to
  write three short text files.
- **Ship source only.** Rejected: an addon zip is what the Asset Library and a
  person installing one addon by hand both want.

## Consequences

- A packaging standard that changes (a new metadata version, a new rule about
  licence files) is this script's to follow; nothing upgrades it for free.
- Writing the wheel found a hole in the licence gate: it never opened a
  `.whl`, so a wheel without NOTICE passed. It does now (rule L9).
- The addon zips do not bundle `ai_core`. Installing `ai_search` means
  unzipping two archives, which is invariant 2 made visible rather than hidden.
