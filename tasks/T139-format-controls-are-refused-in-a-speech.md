# T139 — Format controls are refused in a speech

Size: S · Prereqs: T129 · Files: `godot/addons/ai_llm/`, `python/gameaikit/llm/`, `spec/vectors/llm/`, `godot/test/ai_llm/`, `python/tests/`, `docs/techniques/`

## Goal

The owner ratified on 2026-11-06 ("das 12 decisões pode seguir o
recomendado") item 7 of STATUS's list of that date: T129's decision 2.
R9 refuses Unicode's controls (C0, DEL, C1) and the line and paragraph
separators. Format controls -- Unicode category Cf: zero-width space and
joiners, the bidirectional marks and overrides, the soft hyphen -- still
pass. A reply can reorder what the screen shows (an override reverses the
rest of the line) or hide a secret from R11 behind a zero-width joiner.

## Decisions written down first (the owner confirms in review)

- **R9 refuses category Cf**, named by range in both twins, so neither
  depends on a Unicode table the other lacks. The list is written once
  in the rule's comment and read from the vectors.
- R11 is read again: a secret split by a format control no longer
  reaches it, since R9 refuses the speech first.
- One vector per family of range (zero-width, bidi, soft hyphen), and a
  planted R9 that passes them fails in both languages.

## Steps

1. The vectors, failing today in both languages.
2. The ranges in both validators, and the grammar's pattern beside them.
3. The technique page in both languages.

## Acceptance

```bash
make test-llm-vectors
python3 -m unittest discover -s python/tests -t python -p "test_llm*.py"
make test-godot-some SUITES="test/ai_llm"
make lint-llm-validated
make lint-tasks lint-status
```

## Manual check

None: nothing on screen changes for a reply that passes.

## Notes

- Opened from T129's review (wave 141), decision 2.
- Write the characters into vectors from a script, never through an
  editing tool, and check with `grep -P` (STATUS 2026-11-06: T129's raw
  separators).
