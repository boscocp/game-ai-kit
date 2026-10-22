# Review: tasks/teaching-docs-and-roadmap

A fresh context reviewed the task files T73-T78 at `1ca21b2`, written for
the owner's request of 2026-10-22: teaching documentation in English and
Brazilian Portuguese, the demos localised with a pt-BR option, a
catalogue of the games and their techniques, how to use the library, and
-- in parallel -- the game-AI literature against this kit, turned into a
roadmap. It was not allowed to edit the worktree. It ran
`make lint-tasks lint-status` and `check_no_employer_refs.py`, both green,
checked every demo, module and file the tasks name against the repo, and
opened the Godot 4.7 internationalisation pages the tasks lean on.

**Verdict: fix before merge.** Every part of the request lands in a task
and the order holds, but two gates as written could not pass, or could
not catch what they claim.

## What was reviewed

- `CLAUDE.md` (invariants 1-7 and 13, the documentation-first rule), T71
  and T72 for the shape, the six tasks and the STATUS diff.
- Each named file, target and count against the repository: 13 demos;
  `docs/godot/examples.md` covering 6 of them; the addons used by one game.
- The Godot claims against the 4.7 docs: the CSV format, `--language`,
  `OS.get_locale_language()`, automatic Control translation, the POT
  template, placeholders.
- Planted cases, prereqs, sizes, tiers, invariant 2.

## Findings

1. **The localisation gate's planted case could not fail** (high): Godot
   translates a Label whose text is a key by itself, and the 14 decision
   overlays are drawn with `draw_string`, which a walk over Labels never sees.
2. **`docs/techniques/` failed `check_doc_freshness.py`** (high): an
   undeclared folder, so three tasks' acceptance could not pass.
3. Twelve technique pages where there are 11 technique modules (medium).
4. Examples in `godot/test/techniques/`, which no module owns (medium).
5. Translated headings compared byte for byte (medium).
6. Translation files and their tests owned by no module (medium).
7. `--language` and `--fixed-fps` per gdUnit suite, which
   `test-godot-some` cannot pass (medium).
8. A second name for T64's `library-check`, and no planted case (medium).
9. The docs task above L and the localisation task above M (medium).
10. New gates not wired into the Makefile and `make check` (low).
11. The roadmap silent on invariants 6 and 7 (low).
12. The CSV choice's reasons and the docs' `?context` caveat, and a BOM
    (low).
13. "Portuguese runs about a fifth longer", with no source (low).
14. "The known game it is like" with no input to come from (low).
15. The README, the entry point, left English only (low).

## What was done about them

All fifteen applied in `e6d9ec6`. The tasks are now T73-T80: the
literature and roadmap (T73, now), technique pages split in two (T74 the
shape, the gate, a glossary and four pages; T75 the rest), the catalogue
with `README.pt-BR.md` (T76), the library page reusing `library-check`
with a planted step (T77), and localisation split in three (T78 the
mechanism, a static scan of `draw_string`, `.text =`, `set_text` and
`Label3D` literals without `tr()` -- a planted case each -- and a headless
`-s` check of what Controls show after measuring auto-translation first;
T79 the turn-based demos; T80 the real-time and 3D ones). The freshness
gate gains a `techniques` layer; headings are compared by anchors;
examples live in their addon's test folder; CSVs are owned per module;
each gate is wired into `make check` and `lint-selftests`; roadmap entries
name invariants 6 and 7; the unsourced number was dropped. The owner's
decisions -- side-by-side pages, `docs/concepts/` and `docs/godot/` left
English, CSV keyed by the English text, the system language by default --
are written at the top of T74 and T78 for the owner to confirm.
`make lint-tasks lint-status` and `check_no_employer_refs.py` pass.
