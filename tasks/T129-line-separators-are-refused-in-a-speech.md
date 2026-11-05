# T129 — Line separators are refused in a speech

Size: S · Prereqs: T116 · Files: `godot/addons/ai_llm/`, `godot/test/ai_llm/`, `python/gameaikit/llm/`, `python/tests/`, `spec/llm/`, `spec/vectors/llm/`, `docs/local-llm/server.md`

## Goal

The owner ratified on 2026-11-05 ("1 a 12 conforme recomendado") item 9 of
STATUS's second 2026-11-05 list, from T116's review
(`docs/reviews/129-the-guards-speech-without-markup.md`).

R9 refuses a speech with a line break or another control character, and
`SPEECH_PATTERN` leaves out `\x00-\x1F` and `\x7F`. But U+2028 (line
separator), U+2029 (paragraph separator) and the C1 controls
(U+0080-U+009F, U+0085 among them) pass both. A model that writes one
gets a speech that breaks the line on screen, and the validator calls it
one line.

## Decisions written down first

- **R9 learns them, in both twins.** The same code, R9, for the same
  reason: the speech is more than one line or holds a control character.
- **The pattern learns them too**, so the schema and the validator stay
  as T116 left them: the schema no looser than the validator. Whether the
  pinned server's grammar converter reads ` ` in a class as the
  character is measured first, as `server.md` measured the rest.

## Steps

1. Vectors that fail today: U+2028, U+2029 and U+0085 in a speech,
   refused as R9, in `spec/vectors/llm/`.
2. R9 in `LlmValidator` and `validator.py`; the pattern in both twins and
   in `reply.schema.json`.
3. The converter's reading, measured or read from its source, on
   `server.md` with the tag and the date.

## Acceptance

```bash
make test-llm-vectors
make test-talk-vectors
make test-godot-some SUITES="test/ai_llm"
python3 -m unittest discover -s python/tests -t python -p "test_llm*.py"
python3 scripts/check_llm_validated.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Notes

- Shares `godot/addons/ai_llm/` and `spec/llm/` with no open task.
