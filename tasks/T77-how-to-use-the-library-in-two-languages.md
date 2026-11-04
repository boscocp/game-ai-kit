# T77 — How to use the library, in two languages

Size: S · Prereqs: T64, T75 · Files: `docs/techniques/`, `scripts/`, `Makefile`, `README.md`

## Goal

The owner, 2026-10-22: "como usar a lib." (the whole request is quoted in T74.)

T64 makes the kit a library: addon zips filtered by manifest, and a
`pyproject.toml` for the Python twins. This task writes how a person uses
it, in English and pt-BR, after T64 says what "install" means. Until then
T74's and T75's pages say "copy the folders", which is what works today.

## Steps

1. **One page, two languages** (`docs/techniques/using-the-library.md`
   and `.pt-BR.md`, under T74's gate):
   - what the library is: the kernel (`ai_core`), the technique addons,
     the ports each expects (`SearchGraph`, `DecisionPolicy`, …), and what
     is deliberately not in it (the examples, the art);
   - installing one addon into a Godot 4 project, from the release zip and
     by copying, and what `class_name` registration needs (an import:
     CLAUDE.md's trap, said for a reader who has never seen this repo);
   - installing the Python side, and training or regenerating weights in
     Python while GDScript only infers (invariant 6);
   - versions: the pinned Godot (`.godot-version`), what the library
     promises to keep stable, and the licence and NOTICE (invariant 9).
2. **The page is what T64's `make library-check` runs**: that check
   already installs the wheel and one addon outside the repository. Extend
   it to follow the page's steps and run T74's minimal example there --
   the real portability proof, since inside `godot/` every `class_name` is
   already registered. Each step on the page is marked so the check can
   list them; a planted case -- a step on the page the check does not run
   -- must fail.
3. **T74's and T75's pages** switch their "in your own project" section
   from "copy the folders" to the library, keeping the copy as the
   alternative.

## What the work found (wave 118)

Details, none changing what the task asks:

- **`DecisionPolicy` is not a port.** No class of that name exists; the
  ports a user's code names are ADR 0024's nine `Gak` names, and the page
  lists those.
- **The second example lives in `scripts/library/`**, not in an addon's
  test folder: it reads `res://chance_model.json`, which only the page's
  Python step writes, so only `make library-check` can run it. The
  translations gate still holds the page's block equal to the file (D9).
- **The check takes the page's steps, not their order on the page.** It
  unzips all three addons first and imports once; a reader unzips
  `ai_learning` later and imports again. The step list itself must match
  exactly, in both languages.
- **The non-module pages** (MENACE, behaviour cloning, the learned
  evaluation, the racing driver) say which half is in the library and that
  the rest -- an example's code -- stays a copy.

## Acceptance

```bash
python3 scripts/check_translations_docs.py
python3 scripts/check_doc_freshness.py
make library-check
make lint-tasks lint-status
```

## Manual check

On a machine that has never cloned this repository, follow the pt-BR page
from a fresh Godot project: does a technique decide something in your own
scene, with nothing else needed?
