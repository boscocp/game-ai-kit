# 0009 — The release is built by hand, from committed files

Status: accepted · 2026-10-13 (T7); revisited 2026-10-30 (T64)

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
- paths and bytes are both read from the commit at `HEAD` (`git ls-tree`,
  `git show`), so an edit, a staged file or an untracked one cannot ship. The
  first version listed tracked paths and read the bytes off disk, and a review
  shipped an uncommitted edit through it;
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

## Revisited · 2026-10-30 (T64, wave 112)

T64 makes the release a library others install, and this decision was to be
read again at that moment. It stands, with three changes.

**What is published where.** One zip per technique addon and the kernel,
`ai_core`, for the Godot Asset Library or a person unzipping by hand; one
wheel, `gameaikit`, for PyPI. Nothing else: not the examples, the menu
executable (which ships beside them in `dist/` for a person to play, and is
not a library), the tests, or a game's trained weights.

**By whom.** Uploading to PyPI or the Asset Library is the owner's act, by
hand, from a `make release` on a clean `main`. No wave publishes, and no
workflow holds a token that could.

**What changed.**

- The release reads the manifests (ADR 0024): an addon folder that no
  technique or kernel manifest owns is refused, so is a test inside an addon
  folder, and each zip gains a README written from its manifest -- the
  Asset Library asks for a readme in the plugin folder.
- `python/pyproject.toml` (PEP 621) now exists, for a person who runs `pip
  install ./python`; it names setuptools, pinned, as its backend. The
  release still writes the wheel by hand, as decided above, but from that
  file's metadata, and refuses when the file's name, version, Python floor
  or package list disagrees with VERSION and the manifests, or a technique
  holds a folder the file does not list. That holds what the two ways to
  get the wheel are built from; nothing builds with setuptools and compares
  the results, which would need setuptools installed. `python/` carries LICENSE and NOTICE
  of its own, the root's bytes, because PEP 639's `license-files` may name
  nothing above the project folder (`check_license.py` L25, L26).
- The wheel holds only the technique packages. Until now it held every
  package under `python/gameaikit/`, the examples' too.

`make library-check` installs the wheel in a fresh virtual environment and
unzips two addons into a blank Godot project, both outside the repository,
and runs each; its planted case is a zip missing the file a script needs.
