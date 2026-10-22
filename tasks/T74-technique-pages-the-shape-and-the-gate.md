# T74 — Technique pages in two languages: the shape, the gate, the first three

Size: M · Prereqs: T70 · Files: `docs/techniques/`, `scripts/check_translations_docs.py`, `scripts/check_doc_freshness.py`, `Makefile`, `godot/test/ai_search/`, `godot/test/ai_steering/`, `godot/test/ai_behaviour/`

## Goal

The owner, 2026-10-22, in their words: "depois de tudo, quero uma tarefa pra
parte didática, uma documentação em PT-br e ingles, localizado, e localizar
os jogos tbm pra deixar as demos com opcao de mudar pra PT br. explicando
brevemente cada técnica utilizada, como usar ela num jogo em outro repo. um
sumário com todos jogos/demos e quais técnicas de IA tem em cada jogo. como
usar a lib. cada técnica genérica como configurar ela no jogo na demo ou no
jogo da pessoa que for utilizar."

The request is split: the page shape, its gate and the first three pages
here; the other pages in T75; the catalogue of demos in T76; how to use
the library in T77; the games' language switch in T78 to T80. It comes
after the current work (T69, T70), so the stealth addons it documents exist.

Today the teaching lives in `docs/concepts/` (why an algorithm works) and
`docs/godot/` (how it was built here), in English, one page per lesson
rather than per addon. Nothing tells a reader with their own Godot project
how to take `ai_search` and use it. That is the gap: **one short page per
technique**, the same shape every time, in both languages.

## Decisions written down first (the owner confirms them in review)

- **Layout**: `docs/techniques/<module>.md` (English) beside
  `docs/techniques/<module>.pt-BR.md`. One folder, a suffix, so a page and
  its translation sit next to each other in a listing and in a diff.
- **The existing `docs/concepts/` and `docs/godot/` pages stay English**,
  linked from the technique pages, not translated. Translating them is a
  later choice of the owner's, not part of this request.
- **Keeping the two in step**: the translation carries
  `translation_of: <sha256 of the English page's body>` in its `doc-meta`;
  the gate recomputes it, and a translation whose source changed since is
  stale and fails, naming both files. Translated headings cannot be
  compared as text, so each heading carries an explicit anchor that is the
  same in both languages (`## Quando não usar {#when-not}`), and the gate
  compares the sequence of heading levels and anchors. Code blocks are
  compared byte for byte; code is not translated, and its comments are
  English once.
- **Which pages**: one per module of kind `technique` in `modules/*.json`
  -- eleven today, `ai_adversarial` to `ai_teamwork` -- plus the techniques
  that live in Python only and are shown in a demo (MENACE, the learned
  checkers evaluation, behaviour cloning) and the racing driver in
  `godot/demos/racing/`. Those four are declared once, in
  `docs/techniques/non_module_techniques.json`, which T76's catalogue reads
  too. `ai_core` and `board` are kernels, not techniques: `ai_core` gets
  one short page (the grid and the pathfinder port every addon stands on);
  `board` does not, being the examples' own kernel (ADR 0021).

## Steps

1. **A layer for the folder**: `scripts/check_doc_freshness.py`'s
   `FOLDER_LAYER` knows only `concepts`, `godot`, `local-llm` and `howto`,
   so a page in `docs/techniques/` fails it today. Add `techniques:
   practice`, with a case in its self-test.
2. **The page's shape**, the same for every technique, short enough to read
   in five minutes:
   - what it decides, in two or three sentences, and one book reference;
   - **when not to use it** (the addon header already says; reuse it);
   - where to watch it: the demos that use it (from the manifests) and the
     key that shows its decision (invariant 13);
   - **in this kit**: the scene or script that configures it in a demo, and
     the knobs that matter, as a short table;
   - **in your own project**: the folders to copy (the addon and
     `ai_core`, per invariant 2), or the library once T64 lands; then a
     minimal example -- a few lines of GDScript wiring it into a scene that
     is not this kit's, with the interface it expects you to implement
     (`SearchGraph`, `DecisionPolicy`, a percept record…);
   - the deeper pages: `docs/concepts/…`, `docs/godot/…`.
3. **A glossary**, `docs/techniques/glossary.pt-BR.md`: the terms that stay
   English where Brazilian developers use them (*pathfinding*, *behaviour
   tree*, GOAP, A\*), each with a short gloss, fixed once for T75 and T78.
4. **The gate**, `scripts/check_translations_docs.py`, `--self-test`, exit
   codes 0/1/2, with planted cases it must reject: a technique module with
   no English page; an English page with no pt-BR page; a stale
   `translation_of`; a heading level or anchor that differs; a code block
   that differs; a minimal example whose block differs from its file.
   Until T75 the module list is checked only for the pages that exist plus
   an explicit "still to write" list, so this task can land green; T75
   empties that list.
5. **The minimal examples are run, not only read**: each lives in the
   addon's own test folder (`godot/test/<addon>/`, owned by the addon's
   manifest), and a gdUnit case loads it into an empty scene and checks it
   decides something. The page includes the file's text; the gate checks
   the block equals the file. This is not the portability proof -- inside
   `godot/` every `class_name` is already registered -- that is T77's run
   outside the repository.
6. **The first three pages, both languages**: `ai_search`, `ai_steering`
   and `ai_behaviour` -- a grid, a continuous space and a decision
   structure, so the shape is tried on three kinds of technique before T75
   writes the rest -- and `ai_core`'s short page.
7. **Wire the gate in**: a `Makefile` target, in `make check`, and its
   self-test in `make lint-selftests`.
8. Invariants 9 and 10 hold for the new pages: `check_no_employer_refs.py`
   runs on them, and the examples are games.

## Acceptance

```bash
python3 scripts/check_translations_docs.py
python3 scripts/check_translations_docs.py --self-test
python3 scripts/check_doc_freshness.py
python3 scripts/check_doc_freshness.py --self-test
python3 scripts/check_no_employer_refs.py
make test-godot-some SUITES="test/ai_search test/ai_steering test/ai_behaviour"
make lint-tasks lint-status
```

## Manual check

A Brazilian reader who knows Godot but not this kit: does the pt-BR page
read as Portuguese written for them, not a translation? Following only the
`ai_search` page, can they wire it into a fresh Godot project?
