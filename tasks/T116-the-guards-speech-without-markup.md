# T116 — The guard's speech without markup: a schema or a prompt, measured

Size: S · Prereqs: T94 · Files: `godot/addons/ai_llm/`, `godot/test/ai_llm/`, `python/gameaikit/llm/`, `spec/llm/`, `spec/vectors/llm/`, `python/tests/`, `godot/game/talk/`, `spec/talk/`, `python/gameaikit/talk/`, `docs/godot/talk.md`, `docs/local-llm/`
Requires: a local model

## Goal

The owner ratified on 2026-11-05 ("todas conforme recomendado") the
recommendation of STATUS's item A3: a small follow-up that measures a
schema or a prompt forbidding markup in the guard's speech.

After T94 the main refusal left is R10: the validator refuses a speech
holding one of `MARKUP` (`<>[]*` and the backtick, in
`python/gameaikit/llm/validator.py`). Ministral likes `*emphasis*`. On
the bake-off's 30 lines, the shipped schema left 9 R10 in 90 replies in
English and 3 in Portuguese (`docs/godot/talk.md`, the table of T94's
measurement). The schema does not forbid `*`, and neither does T93's
prompt. A refused reply costs the person a turn's fallback line.

## Decisions written down first

_The owner ratified only the item quoted above. The decisions below are this session's proposal, written on 2026-11-05; the wave that takes the task confirms them, or brings them back to the owner._

- **Measure before shipping.** Two candidates, each measured the way T94
  measured `anyOf`: the 30 lines, the pinned model and build, three rounds
  a language, through `godot/test/ai_llm/live_probe.gd`.
  - a schema that forbids the characters, for instance a `pattern` on
    `speech`, if the pinned `llama-server` honours it under
    `strict: true` (read its documentation for the pinned tag first, then
    measure);
  - a line in the prompt that asks for plain speech.
- **Ship only what the numbers favour.** It ships if R10 falls and
  neither the valid count nor "act and argument right" falls. If neither
  candidate wins, nothing ships, and the table says so.
- **The validator stays as it is.** R10 is still the check: a schema is
  a request to the model, not a guarantee (invariant 7).

## Steps

1. Read what the pinned server documents about `pattern` in a JSON
   schema, and write what it says into `docs/local-llm/server.md`, with
   its URL and date.
2. Measure both candidates, and add their rows to the table in
   `docs/godot/talk.md`.
3. If one wins, change it in both languages (the schema's twin or the
   prompt), and its vectors.

## Acceptance

```bash
python3 -m unittest discover -s python/tests -t python -p "test_llm*.py"
python3 -m unittest discover -s python/tests -t python -p "test_talk*.py"
make test-llm-vectors
make test-talk-vectors
make test-godot-some SUITES="test/ai_llm test/talk"
python3 scripts/check_llm_validated.py
python3 scripts/check_readability.py
make lint-tasks lint-status
```

## Manual check

Run the measurement with `make llm-serve` up. The table's new rows are a
person's reading of three rounds a language: does R10 fall without the
other columns falling?

## Notes

- Shares no folder with T88 or T96.
