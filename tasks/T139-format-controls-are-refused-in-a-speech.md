# T139 — Format controls are refused in a speech

Size: S · Prereqs: T129 · Files: `godot/addons/ai_llm/`, `python/gameaikit/llm/`, `spec/vectors/llm/`, `spec/llm/`, `godot/test/ai_llm/`, `python/tests/`, `docs/techniques/`, `docs/local-llm/server.md`

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
- Done in wave 161. Cf is taken from Unicode 16.0 (Python 3.14's
  table): 21 runs, 170 code points, from U+00AD to U+E007F. Both twins
  hold them as `FORMAT_CONTROLS`, and `replies.json` holds them as
  `format_controls.runs`; both suites compare their list to it, and
  Python's compares it to `unicodedata` when that table is 16.0 (skipped
  on 3.12's 15.0, not read as a disagreement). GDScript cannot build a
  constant in a loop, so its `FORMAT_CLASS` spells the runs a second
  time, and `llm_test.gd` builds it from `FORMAT_CONTROLS` and compares.
- Unassigned code points inside a block (U+2065) are not refused: the
  list is Cf as it stands, not the blocks. A later Unicode that adds a
  format control is a change to the three lists, made on purpose.
- The price, written into both comments: an emoji sequence joined by
  U+200D, a subdivision flag (tag characters) and a Persian line that
  needs U+200C are refused too.
- Ten vectors, written by a script with `chr()` and checked with
  `grep -P` (no raw format control in any changed file): zero-width
  joiner inside a secret, zero-width space, the right-to-left override,
  a bidirectional isolate, the soft hyphen, U+FEFF inside a speech, a
  tag character raw and as a surrogate-pair escape -- all R9 -- and U+200A
  and U+202F accepted. Re-dumping the file also turned the raw BOM and
  raw DEL two older cases held into escapes; they decode to the same
  cases.
- Planted, one at a time: the old validators in both twins (8 vectors
  red in each); R9 skipping the runs in Python (17 failures) and in
  GDScript (8 vectors, the gdUnit vector test); `FORMAT_CLASS` losing
  U+E0001 (gdUnit, 2 failures); R9 refusing the unassigned U+2065 in
  either twin (each one's sweep).
