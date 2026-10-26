# T75 — Technique pages in two languages: every other technique

Size: M · Prereqs: T74 · Files: `docs/techniques/`, `godot/test/ai_*/`, `README.md`

## Goal

The owner, 2026-10-22: "explicando brevemente cada técnica utilizada, como
usar ela num jogo em outro repo … cada técnica genérica como configurar ela
no jogo na demo ou no jogo da pessoa que for utilizar." (the whole request
is quoted in T74.)

T74 fixed the page's shape, its gate, the glossary and the first pages
(`ai_core`, `ai_search`, `ai_steering`, `ai_behaviour`). This task writes
the rest in both languages, in T74's shape, with nothing new to decide: a
page here that needs a rule T74 did not foresee goes back to T74's
decisions and changes them there.

## Steps

1. **The remaining technique modules**, English then pt-BR, each with its
   minimal example in `godot/test/<addon>/`: `ai_adversarial`,
   `ai_fuzzy`, `ai_learning`, `ai_opponent`, `ai_perception`,
   `ai_planning`, `ai_rts_core`, `ai_teamwork`.
2. **The four declared in `non_module_techniques.json`** (T74): MENACE,
   the learned checkers evaluation, behaviour cloning, the racing driver.
   Their "in your own project" section is the Python side: train or
   regenerate in Python, infer in GDScript (invariant 6).
3. **An addon that cannot be wired outside its demo** in a few lines is a
   finding: write it down in the page and in `tasks/STATUS.md` as a
   follow-up, rather than hiding it behind a long example.
4. **Empty T74's "still to write" list**: from here the gate requires a
   page in both languages for every technique module.
5. **The README's "What it covers" table** links each row's technique page
   in both languages.

## Acceptance

```bash
python3 scripts/check_translations_docs.py
python3 scripts/check_doc_freshness.py
python3 scripts/check_no_employer_refs.py
make test-godot-some SUITES="test/ai_adversarial test/ai_fuzzy test/ai_learning test/ai_opponent test/ai_perception test/ai_planning test/ai_rts_core test/ai_teamwork test/tictactoe test/checkers test/fighting test/demo_racing"
make lint-tasks lint-status
```

## Manual check

Pick two pt-BR pages: does each read as Portuguese written for a Brazilian
developer, and does its minimal example match what the demo shows?
