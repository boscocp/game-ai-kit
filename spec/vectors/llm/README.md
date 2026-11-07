# Conformance vectors: what a model's reply may contain

<!-- doc-meta
half_life: structure
verified_on: 2026-11-07
tier: 1
source: https://github.com/boscocp/game-ai-kit
invalidated_if: the reply's shape changes, or a refusal code changes meaning
teaches: none
-->

> One rule set, two validators, and the file that says they refuse the
> same replies.

A game reads a model's reply through `ai_llm`'s `LlmValidator`; the tier-1
lesson replays one through `gameaikit.llm.validator`. `replies.json`
declares one game -- its intents and their arguments, its fallback line, its
secret -- and lists raw replies, each exactly as a runtime would hand it
over (`raw`), claiming one of two things:

- `refused`: the code of the first rule it breaks, R1 to R11 -- the code
  only, because the sentences are each language's own;
- `accepted`: the speech, intent and argument the game may act on.

`make test-llm-vectors` runs both halves: `python/tests/test_llm_vectors.py`
and `godot/test/ai_llm/llm_vectors_runner.gd` (the gdUnit suite
`llm_test.gd` reads the file too). Both also plant a wrong claim and watch
it fail, and the Python side checks that every code from R1 to R11 has a
case: a rule with no case could be deleted from either language with both
suites green. This is where "every refusal is refused by both validators" is
held -- by running them; `check_llm_validated.py`, which reads code and runs
nothing, cannot.

`format_controls` lists Unicode's format controls (category Cf, Unicode
16.0) as runs of code points: what R9 refuses beside the controls and the
line separators (T139). Each validator names the same runs by hand, so
neither leans on a Unicode table the other lacks, and both suites compare
their list to this one. Python's also compares it to its own Unicode table
when that table is the version named here, and is skipped on another.

## Where the two parsers had to be made to agree

Measured on Godot 4.7.2 and Python 3, each now a case: Godot's JSON parser
accepts a trailing comma and the numbers `01` and `1.`, which Python's
refuses, so `LlmValidator` refuses them itself, outside strings; Python's
keeps a lone UTF-16 surrogate and `NaN`, which Godot's refuses, so
`gameaikit.llm` refuses them; a surrogate pair written as escapes is one
character to both (U+E0041, a tag character, is a case); both keep the last
of a key written twice;
both count a speech's length in characters, so 280 `ã` pass. Found by
review, each a case too: a `\u0000` escape becomes U+FFFD in Godot and a
real NUL in Python, so both refuse it before parsing (R1); lists nested a
thousand deep make Godot's parser give up and not Python's, so both stop at
32 (R1); and `"İ".lower()` is two characters in Python and one in Godot, so
secrets are found folding A to Z only -- a secret's other letters must
match as written.

## Where the cases came from

Written by hand, one rule broken per reply, each beside the sentence saying
why that rule exists, and generated into the file once -- 280 characters
are not typed. None came from a model: T94's recordings will, and a reply
from one that the two validators disagree on belongs here.
