# T142 — The first page says what is true today

Size: S · Prereqs: T112 · Files: `README.md`, `README.pt-BR.md`, `docs/techniques/ai_llm.md`, `docs/techniques/ai_llm.pt-BR.md`

## Goal

The review before the repository opens (T112, wave 143,
`docs/reviews/open-the-repository.md`, finding 2) read the README as a
stranger would, and it contradicts itself: its status line describes the
first vertical slice while the table below it lists 19 techniques and 16
demos; it says `ai_llm`'s runtime and game are "still to come" while it
links `make demo-talk`; "What you will see" covers 5 of the 16 demos; tier
1 says "Python 3" where the code needs 3.12; and task ids (T27, T93, T94)
appear where a stranger cannot resolve them. `ai_llm.md` still says "No
demo yet", which its own `invalidated_if` names.

## Decisions written down first (the owner confirms in review)

- **The README stays short, and the catalogue carries the demos.** "What
  you will see" keeps a paragraph each for the few demos it describes, and
  ends with one line pointing at `docs/techniques/catalogue.md` for the
  rest, instead of growing to sixteen paragraphs.
- **No task or wave id on the first page.** What a sentence needs from a
  task, it says in words.
- **Tier 1 says "Python 3.12 or later"**, in both languages, matching
  `python/pyproject.toml`.
- **The README links `CONTRIBUTING.md` and `docs/howto/windows.md`**, and
  says in one line that `tasks/` and `docs/reviews/` are the project's
  working history, which a reader after one technique can skip.
- `ai_llm.md` and its pt-BR twin say where the demo is (`make demo-talk`)
  and keep the replay command as the tier-1 way in.

## Steps

1. Rewrite the status line, the `ai_llm` paragraph and the end of "What you
   will see" in `README.md`; the tier 1 row in both READMEs.
2. Remove the task ids from both READMEs' prose.
3. Correct `ai_llm`'s "Where to watch it" in both languages.

## Acceptance

```bash
make lint-translations-docs
make lint-links lint-tiers lint-glossary
make lint-catalogue
make lint-tasks lint-status
```

## Manual check

A person who has never seen the repository reads `README.md` top to
bottom and finds nothing the rest of the page or the menu contradicts.

## Notes

- Opened by T112 (wave 143), finding 2. Finding 3's catalogue lines were
  fixed in that wave.
