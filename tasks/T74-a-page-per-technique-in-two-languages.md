# T74 — A page per technique, in English and Brazilian Portuguese

Size: L · Prereqs: T70 · Files: `docs/techniques/`, `scripts/check_translations_docs.py`, `README.md`

## Goal

The owner, 2026-10-22, in their words: "depois de tudo, quero uma tarefa pra
parte didática, uma documentação em PT-br e ingles, localizado, e localizar
os jogos tbm pra deixar as demos com opcao de mudar pra PT br. explicando
brevemente cada técnica utilizada, como usar ela num jogo em outro repo. um
sumário com todos jogos/demos e quais técnicas de IA tem em cada jogo. como
usar a lib. cada técnica genérica como configurar ela no jogo na demo ou no
jogo da pessoa que for utilizar."

This task is the per-technique half. The catalogue of demos is T75, how to
use the library is T76, and the games' own language switch is T77 and T78.
It comes after the current work (T69, T70), so the stealth addons it
documents exist.

Today the teaching lives in `docs/concepts/` (why an algorithm works) and
`docs/godot/` (how it was built here), in English, one page per lesson
rather than per addon. Nothing tells a reader with their own Godot project
how to take `ai_search` and use it. That is the gap: **one short page per
technique**, the same shape every time, in both languages.

## Decisions written down first (the owner confirms them in review)

- **Layout**: `docs/techniques/<module>.md` (English) beside
  `docs/techniques/<module>.pt-BR.md`. One folder, a suffix, so a page and
  its translation sit next to each other in a listing and in a diff. The
  existing `docs/concepts/` and `docs/godot/` pages stay English and are
  linked, not translated, in this task.
- **Keeping the two in step**: the translation carries
  `translation_of: <sha256 of the English page's body>` in its `doc-meta`.
  The gate recomputes the hash; a translation whose source changed since is
  stale and fails, naming both files. The two must also have the same
  headings in the same order, and the same code blocks byte for byte. The
  code is not translated. Its comments are written in English once.
- **Which pages**: one per module of kind `technique` in `modules/*.json`
  (twelve today: `ai_adversarial` … `ai_teamwork`, `ai_core` as the
  kernel), plus the techniques that live in Python only and are shown in a
  demo (MENACE, the learned checkers evaluation, behaviour cloning). The
  gate reads the list from the manifests, so a new addon without a page
  fails.

## Steps

1. **The page's shape**, the same for every technique, short enough to read
   in five minutes:
   - what it decides, in two or three sentences, and the one book reference;
   - **when not to use it** (the addon header already says; reuse it);
   - where to watch it: the demos that use it (from the manifests) and the
     key that shows its decision (invariant 13);
   - **in this kit**: the scene or script that configures it in a demo, and
     the knobs that matter, as a short table;
   - **in your own project**: the folders to copy (the addon and
     `ai_core`, per invariant 2), or the library once T64 lands; then a
     minimal example -- a few lines of GDScript that wire it into a scene
     that is not this kit's, with the interface it expects you to
     implement (`SearchGraph`, `DecisionPolicy`, a percept record…);
   - the deeper pages: `docs/concepts/…`, `docs/godot/…`.
2. **The minimal examples are run, not only read**: each one lives as a
   file under `godot/test/techniques/` that a headless script loads into an
   empty scene, outside every example's folder, and checks it decides
   something. The page includes the file's text, and the gate checks the
   page's block equals the file (invariant 3: an example in prose that
   stopped compiling is a finding). This is also a small portability test
   for each addon: an addon that cannot be wired outside its demo is a
   finding to report, not to paper over.
3. **Write the English pages**, then **the pt-BR pages**. The translation
   is written, not machine-pasted. Terms the field uses in English stay in
   English where Brazilian developers use them (*pathfinding*, *behaviour
   tree*, *GOAP*), with a short gloss the first time. A small glossary
   (`docs/techniques/glossary.pt-BR.md`) fixes the choices once.
4. **The gate**, `scripts/check_translations_docs.py`, with `--self-test`
   and planted cases it must reject: a technique module with no English
   page; an English page with no pt-BR page; a stale `translation_of`; a
   heading missing from the translation; a code block that differs; a
   minimal example whose block differs from its file. Exit codes 0/1/2 as
   the other scripts.
5. **The README's "What it covers" table** links each row's technique page
   in both languages.
6. Invariants 9 and 10 hold for the new pages: `check_no_employer_refs.py`
   runs on them, and the examples are games.

## Acceptance

```bash
python3 scripts/check_translations_docs.py
python3 scripts/check_translations_docs.py --self-test
python3 scripts/check_doc_freshness.py
python3 scripts/check_readability.py
python3 scripts/check_no_employer_refs.py
make test-godot-some SUITES="test/techniques"
make lint-tasks lint-status
```

## Manual check

A Brazilian reader who knows Godot but not this kit: does the pt-BR page
read as Portuguese written for them, not a translation? Following only the
page, can they wire the technique into a fresh Godot project in under
fifteen minutes?
