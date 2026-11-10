# T140 — A server's refusal is cleaned as a speech is

Size: S · Prereqs: T139 · Files: `godot/addons/ai_llm/http_runtime.gd`, `godot/test/ai_llm/`

## Goal

The owner ratified on 2026-11-06 item 8 of STATUS's list of that date:
T129's decision 3. `HttpRuntime._error_of` shows the server's own words
when it refuses a request, and turns into a space only C0 and DEL. C1,
the line and paragraph separators, and (after T139) the format controls
reach the screen, though R9 refuses every one of them in a speech.

## Decisions written down first (the owner confirms in review)

- **One list of what may not be shown.** `_error_of` asks the validator's
  own test (the one R9 uses), rather than a second spelling of it.
- Each refused character still becomes a space, and the result is still
  cut to `ERROR_LENGTH`.

## Steps

1. A test that fails today: a refusal with C1, U+2028 and a bidi
   override shows none of them.
2. `_error_of` through the validator's test.

## Acceptance

```bash
make test-godot-some SUITES="test/ai_llm"
make lint-llm-validated
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

None: a refusal is rare, and its words are the server's.

## Notes

- Opened from T129's review (wave 141), decision 3. After T139, so the
  test it reuses already refuses format controls.
- Done in wave 165. R9's test is public as `LlmValidator.is_refused_by_r9`,
  and the Python twin is renamed `is_refused_by_r9` with it, as wave 161's
  review asked (finding 1). The new test failed before the change with
  every one of its eight characters shown, C1, the separators and four
  format controls. `llm_validator.gd` is 386 of its 400 lines.
