# T76 — How to use the library, in two languages

Size: S · Prereqs: T64, T74 · Files: `docs/techniques/`, `README.md`

## Goal

The owner, 2026-10-22: "como usar a lib." (the whole request is quoted in T74.)

T64 makes the kit a library: addon zips filtered by manifest, and a
`pyproject.toml` for the Python twins. This task writes how a person uses
it, in English and pt-BR, after T64 says what "install" means. Until then
T74's pages say "copy the folders", which is what works today.

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
2. **Run it outside the repo**, as T64's acceptance does: the page's steps
   are scripted into a headless check that installs one addon into an empty
   project in a temporary folder and runs T74's minimal example there. A
   step on the page the script does not run is a finding.
3. **T74's pages** switch their "in your own project" section from "copy
   the folders" to the library, keeping the copy as the alternative.

## Acceptance

```bash
python3 scripts/check_translations_docs.py
python3 scripts/check_doc_freshness.py
make test-library-outside
make lint-tasks lint-status
```

## Manual check

On a machine that has never cloned this repository, follow the pt-BR page
from a fresh Godot project: does a technique decide something in your own
scene, with nothing else needed?
