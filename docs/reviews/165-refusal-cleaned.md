# Review: wave/165-refusal-cleaned

T140, the owner's list item 8 of 2026-11-06 (T129's decision 3).
`HttpRuntime._error_of` showed the server's own words for a refused
request and turned only C0 and DEL into spaces, so C1, the line and
paragraph separators and the format controls reached the screen, though R9
refuses each of them in a speech. The PR makes R9's test public as
`LlmValidator.is_refused_by_r9`, has `_error_of` ask it, renames the
Python twin to match, and adds one test.

A fresh context reviewed PR #122 at head a685c6f. **Verdict: approve, no
blocker and no should: two nits.**

## What was reviewed

- The PR title and body, the task file, its two decisions and its
  acceptance.
- `git diff origin/main...origin/wave/165-refusal-cleaned`: six files,
  `http_runtime.gd`, `llm_validator.gd`, `llm_test.gd`, `validator.py`,
  the STATUS row and the task Notes.
- Every caller of the old and the new name, in GDScript, Python, the
  specs, the docs and the scripts.
- The acceptance commands, run here: `make test-godot-some
  SUITES="test/ai_llm"` (50 cases, 0 failures, no SCRIPT ERROR),
  `make lint-llm-validated`, `python3 scripts/check_readability.py`,
  `make lint-tasks`, `make lint-status`, `make test-llm-vectors`: all 0.
- `make check-affected BASE=origin/main`: 0. Its six SCRIPT ERROR lines
  are all `demo_overlays.gd:226`'s planted `step_decision` crash, and
  nothing else.
- The planted case, measured: `_error_of`'s test put back to
  `unicode_at(0) < 32 or unicode_at(0) == 127`, the suite fails with 9
  failures, the exact-string assertion and one per character for all
  eight refused characters. Restored, it is green again.

## Findings

1. **Nit.** `_error_of`'s comment now says the text is "held to what a
   speech may show". It is held to R9 and R10 only. R8's limit is not
   the speech's (`ERROR_LENGTH` is 160), and R11, a secret, is not asked
   at all. The sentence claims more than the function does. Proposed fix:
   "held to what R9 and R10 allow in a speech".
2. **Nit.** The STATUS row says "wave 165:" where the recent rows say
   "wave 161 (#115):". Proposed fix: "wave 165 (#122):", so the row leads
   to the pull request, as its neighbours do.

## Not findings

- **`_error_of` refuses exactly what R9 refuses.** It calls the very
  function `why_speech_is_wrong` calls, so the two cannot drift. Each
  refused character still becomes a space and markup is still dropped,
  in that order, as before. The result is still cut to `ERROR_LENGTH`.
  The 503 path ("the server is not ready") goes through the same function,
  so it is cleaned too.
- **The test is real, and it is strong enough.** It asserts the exact
  string, so a cleaner that dropped a character instead of spacing it
  would fail too. Its eight characters cover each class the old code let
  through: two C1s (NEL and CSI), both separators, and four format
  controls (an override, the soft hyphen, ZWJ and the BOM). C0 and DEL
  stay with the older test above it.
- **The Python rename is consistent.** `is_refused_by_r9` has one caller,
  `why_speech_is_wrong`, and nothing else in `python/`, `spec/`, `docs/`
  or `scripts/` used the old name. It is not in `gameaikit.llm.__all__`,
  and it does not need to be. Its behaviour is covered by the R9 vectors
  through `why_speech_is_wrong`, and `make test-llm-vectors` is green.
- **Readability.** `llm_validator.gd` is 386 of 400 lines, recorded in
  the task Notes and the PR body. No function grew. The public function
  has a `##` doc comment that says what it is and why it is public.
- **Invariant 2 holds.** `HttpRuntime` and `LlmValidator` are both in
  `ai_llm`. No addon gained a dependency.
- **Invariant 7 holds.** The refusal is text shown to the player, never
  an action, and it is now cleaned by the validator's own list.
- **Nothing else changed.** The diff is the six files the task and its
  Notes name.
- **R11 on a refusal** is out of scope here. llama.cpp's error sentences
  name the request's fault, not its prompt. If a later runtime echoed the
  prompt, that would be its own task.
- The PR title and body carry no tooling byline.

## What was done about them

1. Applied. `_error_of`'s comment now says the text is "held to what R9
   and R10 allow in a speech", and calls the markup list R10's, so it
   claims no more than the function does.
2. Applied. The STATUS row for T140 reads "wave 165 (#122):", as its
   neighbours do.
