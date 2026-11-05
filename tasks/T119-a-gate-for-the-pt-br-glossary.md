# T119 — A gate for the pt-BR glossary: an English term in italics is defined

Size: S · Prereqs: T77 · Files: `scripts/`, `Makefile`, `docs/techniques/glossary.pt-BR.md`, `docs/techniques/`, `README.pt-BR.md`

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's 2026-11-04 item B4: a small task for a gate on
the glossary rule. An italicised English term in a pt-BR page must be in
the glossary.

The rule is the glossary's own (`docs/techniques/glossary.pt-BR.md`, its
opening paragraphs): a term kept in English is in italics the first time
a page uses it, and the glossary lists it and says what it means. It is
prose today. T77's review (`docs/reviews/118-how-to-use-the-library.md`,
finding 5) found four italicised terms the glossary did not list, in 25
lines, and said no gate would have caught them.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **What it reads:** every tracked `*.pt-BR.md`, and the glossary's
  table, first column, each term and each spelling separated by `/` or
  `,` (the glossary puts several in one row).
- **What counts as a term:** an italic span outside code, compared in
  the singular, as the glossary says ("Um termo no plural ... está aqui no
  singular"). A plural form is reduced by a short declared rule, not by
  guessing.
- **What it cannot tell:** whether an italic span is English. A
  Portuguese word in italics for emphasis, and a book or paper title,
  are italics too. Measure first: list every italic span not in the
  glossary on today's pages. Then choose between an allowlist declared
  in the gate (titles, emphasis), or a page convention for titles. Say
  which, and why, in the gate's docstring.
- **Planted cases first** (invariant 4): an undefined English term, a
  plural of a defined one, a span inside code, and an empty page set,
  which must fail rather than pass.

## Steps

1. Measure today's italic spans that the glossary does not list.
2. Write `scripts/check_glossary.py` with `--self-test`, exits 0, 1, 2.
3. Fix what it finds on today's pages: a missing glossary row, or a term
   that should not be italic.
4. A `lint-` target, in `check:` and in `lint-selftests`, and a row in
   CLAUDE.md's gate list only if the invariants table names this rule.

## Acceptance

```bash
python3 scripts/check_glossary.py --self-test
python3 scripts/check_glossary.py
make lint-selftests
python3 scripts/check_translations_docs.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Read the allowlist, if there is one: is each entry truly a title or
Portuguese emphasis, and not an English term let through?

## Notes

- Shares `docs/techniques/` with T88 (the `ai_adversarial` pages) and
  T96 (the technique pages). This task may add glossary rows or remove
  italics on any pt-BR page, so it does not run beside either.
