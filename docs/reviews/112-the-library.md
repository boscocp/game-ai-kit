# Review: wave/112-the-library

T64: the kit as a library others install. The nine ports and the kernel
prefixed `Gak` (ADR 0024), `AimChoice` moved to `ai_utility`, the release
read from the manifests, `python/pyproject.toml` and a registry of
techniques a user's package joins through an entry point, `make
library-check`, the Python ports a user meets, ADR 0009 revisited.

A fresh context reviewed the branch from head 57af4e6, reading only, with
no Godot run; c6408de (the translation hashes and the search example
pasted again, after `make check-affected` found them stale) landed while
it read.

**Verdict: changes requested, no blockers.** Four should-fix findings and
nine nits. Every one was applied on the branch or answered below.

## What was reviewed

The diff against main: the renames across `godot/`, the docs and the two
Python docstrings; the `AimChoice` move (addon, both vector readers,
`gameaikit/utility/aim.py`, seven vectors, both `derive.py`, both READMEs,
four technique pages); `pyproject.toml`, `python/README.md`, the
`python/` attribution and `check_license.py` L25-L26; `techniques.py`,
its 16 decorators and tests; `release.py`; `library_check.py` and
`stranger.gd`; the `Game` protocol and the frozen results; ADR 0024 and
0009; `check_modules.py`.

## What the reviewer found sound

- **The rename.** No unprefixed use of the nine names left in `godot/`
  code, scenes or docs; no prose hit -- "Search with the learned weights"
  in `checkers.gd` intact.
- **The move.** `aim_choice.gd` and its `.uid` moved unchanged; nothing in
  `ai_teamwork` refers to aim; `ai_utility` still depends on nothing
  (invariant 2); both `derive.py` regenerate every vector byte for byte.
- **`project_table`** refuses a pyproject that disagrees on version or
  packages, independently of the build, each case planted on its own
  commit.
- **L25, L26** have planted cases for a missing and a stale copy.
- **The registry** is tied to the technique manifests by its tests; the
  plug-in, shadowing and frozen paths are tested.
- **`Game`** is tested with a game that inherits nothing.
- **`stranger.gd`** requires its marker, not only the exit code.

## Findings, and what was done

1. **`library_check.py --self-test` had no positive control.** A Godot that
   does not start, or a venv with no pip, would fail both planted cases
   for the wrong reason and the self-test would pass. *Applied:* the
   untouched release must pass both halves first, and each planted case
   must fail naming what was taken out (`GakGridGraph`, `aim`).
2. **The README in each zip was the manifest's `about`**, written for this
   repository: "(T61)", "(ADR 0016)", "in GDScript and Python" in a zip of
   GDScript, `ai_utility`'s without aim, and the `Gak` note in addons that
   have no such class. *Applied:* every shipped manifest has a `summary`
   for a stranger; the release refuses a manifest without one (planted);
   the `Gak` note is printed only where a `class_name Gak` is.
3. **The wheel checks were weaker than claimed.** Only three examples'
   packages were checked absent, and a technique growing a subpackage
   would have been left out by both the build and its expectation, which
   agree. *Applied:* the absent packages are read from the manifests of
   kind `example`; `project_table` refuses a folder inside a technique's
   package that `pyproject.toml` does not list (planted).
4. **Steps not done or not recorded.** *Applied:* *Submitting to the Asset
   Library* (4.7) read again and recorded in `docs/godot/addon-anatomy.md`
   (`verified_on` 2026-10-30) -- the Library downloads a repository's
   archive, so `.gitattributes` `export-ignore` belongs to whatever
   repository an entry points at, a choice made when the owner publishes;
   "runs one test of it" being a script is said in ADR 0024; STATUS below.

Nits, all applied: ADR 0024's reason for the nine names reworded (the
owner's list; `GakGridGraph` is handed in, `GakGameDomain` is a sample);
the measured engine message in `addon-anatomy.md` said to be measured
again, in `make check`'s own output; `python/README.md` kept in GLOBAL only;
the freeze of `MctsResult` and `Choice` said to be shallow (the lists are
the shape the vectors compare); the test refusal described as what it is,
a gdUnit4 suite, in the code and the ADR; the lambda in the self-test made
two named functions; `python/*.egg-info/` ignored, and ADR 0009 no longer
claims the two wheels "cannot drift" -- it says what is held; two
plug-ins declaring one name refused, as a plug-in taking a kit name is.

Not changed: the README links `github.com/boscocp/game-ai-kit`, private
today. Nothing is published before the repository is public, and the
publishing is the owner's act (ADR 0009).

## Runs

After the fixes: `python -m unittest` (462 tests), the self-tests of
`release.py`, `library_check.py`, `check_license.py`, `check_modules.py`
and `check_translations_docs.py`, `make library-check`, and `make
check-affected BASE=origin/main` (it selects all of `make check`), green.
Mutations: the test refusal disabled and `stranger.gd`'s marker and route
claim changed, each caught.

## Owner decisions, with the reviewer's opinion

1. The prefix, the nine names and `AimChoice`'s home were decided on
   2026-10-30, before the code.
2. **The manual check** (task file): read one addon's zip and the wheel as a
   stranger would.
3. **How an addon reaches the Asset Library** -- a repository per addon, or
   one entry for the kit -- is for the day of publishing.
