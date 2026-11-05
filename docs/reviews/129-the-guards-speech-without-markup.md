# Review: wave/129-the-guards-speech-without-markup

T116: the guard's speech without markup. `LlmValidator.SPEECH_PATTERN`, its
Python twin and `spec/llm/reply.schema.json` give `speech` a JSON-schema
`pattern`, `` ^[^"\\<>\[\]*`\x00-\x1F\x7F]{1,280}$ ``, which `json_schema()`
hands to a runtime in both twins. The validator is unchanged, R10 included.
`docs/local-llm/server.md` gains "A `pattern` on a string", and
`docs/godot/talk.md` gains "Markup, measured (T116)".

A fresh context reviewed PR #76 at head 11ea222 in a throwaway worktree.
It planted faults one at a time, ran only the narrow suite, and restored
each plant. Nothing was pushed, committed or commented. The LLM server was
not started; the measurement was read, not rerun.

**Verdict: changes requested, no blocker.** The code is right, and both
twins are held to the committed schema. A planted change to either twin's
pattern goes red. The converter claim checks out against the pinned
source. Two should-fix findings are about documentation. One is the same
class as finding 3 of review 126: `spec/llm/README.md` still says the
schema cannot say what the pattern now says, and it does not say that the
schema is now stricter than the validator. The other is that decision 3
overstates its evidence. There are two nits and three items for the owner.

## What was reviewed

The diff against main: `llm_validator.gd`, `validator.py`,
`reply.schema.json`, `llm_test.gd`, `test_llm.py`, `test_llm_vectors.py`,
the two doc pages and the STATUS row. The review also read the validator's
`R8` to `R10` in both twins, `spec/llm/README.md`, and every caller of
`json_schema()`. The only caller is `LlmConversation`, through
`HttpRuntime`.

What holds:

- **The escaping means the same in all three places.** The GDScript
  literal, the Python raw string and the JSON string all decode to the same
  15 class members: `"`, `\`, `<`, `>`, `[`, `]`, `*`, the backtick,
  `\x00-\x1F` and `\x7F`. PCRE2 (Godot's `RegEx`), Python's `re` and
  ECMA-262 read `\xHH` inside a class the same way. The tests compare the
  twins' pattern text to the committed file's, so a spelling that differs
  but means the same would still go red. That is the right strictness for
  a twin.
- **The pattern asks for exactly what R8 to R10 check, plus the quote and
  the backslash.** R8 is 1 to 280 code points, and the pattern's quantifier
  counts code points in both engines. R9 is `< 32` or `127`, and the class
  excludes `\x00-\x1F\x7F`. R10 is `MARKUP`, and every MARKUP character is
  in the class. So the schema never asks for less than the validator wants.
  It asks for more only in the quote and the backslash.
- **The converter claim is right at `b11960`.** The reviewer read
  `common/json-schema-to-grammar.cpp` and `grammars/README.md` at the tag.
  - In `common_chat_schema_converter::visit`, the string branch returns
    `_visit_pattern` before it reads `min_length` or `max_length`.
  - `_pattern_to_rule` wraps the body in literal JSON quotes,
    `"\"" (body) "\""`, and copies a class verbatim, with no JSON decoding
    layer. So `[^*]` would admit a raw `"`, `\` or newline.
  - A pattern without anchors, or with an unsupported group such as a
    lookbehind, is pushed as a warning, "accepting any string". A malformed
    pattern is an error.
  - Inside a class the converter accepts `\xHH`, `\uHHHH`, `\t \r \n \\ \"
    \[ \] \-`. So `\x00-\x1F` and `\x7F` pass.
  - The README says "Unsupported features are skipped silently", but the
    code prints a warning. `server.md` describes the code's behaviour, which
    is the right one to describe.
  - The page carries the URLs, the tag and the date, and its
    `invalidated_if` names the pattern. That meets CLAUDE.md's "check the
    documentation first" rule.
- **No over-exclusion beyond what is chosen.** Checked with Python `re`
  (`overexclude.py` in the scratch folder). These pass: pt-BR with accents
  and an em dash, typographic quotes “ ”, the typographic apostrophe ’, a
  straight apostrophe (tested by the PR), an emoji, and 280 code points of
  "ação". These are refused: tab, newline, straight quote and backslash.
  The validator already refuses a line break and a tab (R9), so the
  pattern costs nothing there. The straight quote and the backslash are
  the whole cost, and the PR names it.
- **No frame is blocked and no output is unvalidated.** The pattern only
  changes the request body. Every reply still goes through `validate`.
  `check_llm_validated.py` and `check_readability.py` exit 0.

## Mutation round

| plant | where | caught by |
|---|---|---|
| drop `*` from the class | `validator.py:71` | 3 Python tests: committed-schema equality, the MARKUP sweep, and the R10 vector case "Markdown's emphasis" |
| `{1,` to `{0,` | `validator.py:71` | 3 Python tests, including the R8 vector "An empty speech" |
| drop `\x7F` | `validator.py:71` | 3 Python tests, including the R9 vector "DEL" |
| drop the straight quote | `validator.py:71` | 2 Python tests: equality and `'He said "no".'`. Correctly not the vectors, which the validator accepts. |
| drop `*` from the class | `llm_validator.gd:57` | gdUnit `test_the_speech_in_the_schema_is_the_committed_one`: 2 failures, no `SCRIPT ERROR` |

The baseline `make test-godot-some SUITES="test/ai_llm"` ran 25 cases with
0 failures. Each plant was restored with `git checkout`, and `__pycache__`
was cleared after each Python plant. A twin mismatch cannot hide: each twin
is compared, as text, to the same committed string.

## Findings

1. **Should-fix: `spec/llm/README.md:19-21` now says the opposite of the
   schema, and the new mismatch is not written where a reader of the spec
   looks.** The README still says that the schema "cannot say ... that a
   speech holds no line break, markup or secret". It now says the first
   two. Finding 3 of review 126 was this same class: the schema and the
   validator making two different statements about one reply in the shared
   addon, without saying so. This time the mismatch is written down in
   three places:
   - the `SPEECH_PATTERN` comment in both twins;
   - the schema's `speech.description`;
   - `server.md`.

   It is not written in the README of `spec/llm/`, which a second game
   using `ai_llm` reads first. Nor is it in `json_schema()`'s doc comment
   (`llm_validator.gd:212`, `validator.py:215`), which says only "a speech
   held to SPEECH_PATTERN". Suggested fix: the README sentence should say
   that the schema asks for no line break and no markup, plus no straight
   quote and no backslash, which the validator still admits, and why
   (llama.cpp reads the pattern against the JSON text). It should also say
   that only the secret is left to the validator alone. A half-clause in
   both `json_schema()` doc comments, "stricter than the validator: no
   straight quote or backslash", closes the rest. No plant applies; this is
   prose.

2. **Should-fix: decision 3, and `docs/godot/talk.md:163-165`, overstate
   the evidence for dropping the straight quote.** The PR body says "no
   accepted speech in any of the 360 replies held a straight quote".
   talk.md says "any of the four runs". In the "pattern" and "both" runs
   (180 replies), a quote could not be produced at all, by construction.
   Only the baseline and the prompt-line runs, 180 replies on the same 30
   lines (60 distinct prompts across two languages), say anything about
   whether the guard wants a quote. The conclusion probably stands: the
   guard speaks one line, and typographic quotes remain available. The
   count should say 180, in the two runs that could show one.

## Nits

1. **`llm_validator.gd:57` writes `280` by hand.** The Python twin builds
   its pattern from `SPEECH_LIMIT` (`{1,%d}`), and the GDScript comment
   says "one to SPEECH_LIMIT characters". It is held anyway: changing the
   limit in one place and not the other trips the committed-schema
   equality in both suites (by reading; not planted). Building the string
   with `% SPEECH_LIMIT` would make the comment literally true.
2. **The gdUnit pattern test checks fewer edges than the Python one.** It
   has no 280/281 length case and no backslash case. Text equality to the
   committed pattern covers it, so this is reading, not risk.

## For the owner

1. **The pattern cannot be opted out of per game.** `SPEECH_PATTERN` is a
   const that `_shape_of` always adds. A second game whose character needs
   a straight quote, or a backslash, has no switch for it today. The
   validator would accept one, but the grammar would never produce one.
   Recommendation: leave it until such a game exists, and say so in the
   README (finding 1).
2. **PR decisions 1, 2 and 4-7.** The reviewer agrees with the
   recommendations. On decision 1, the pattern's English act-and-argument
   counts (17, 17, 17) beat the prompt line's (16, 14, 14), and the
   difference holds in all three rounds. In pt-BR the two tie on the mean
   (17.3). Shipping the grammar constraint over a request in words is the
   right call. On decision 7, the raw probe outputs are what a later
   reviewer would need to recount findings like finding 2. Committing them
   under `docs/local-llm/` is cheap.
3. **Pre-existing, outside this PR: U+2028, U+2029 and C1 controls such as
   U+0085 pass both R9 and the pattern.** A Unicode line separator is a
   line break to a `RichTextLabel`. Whether R9 should refuse it is a
   validator change for its own task, with vectors in both twins.

## What was run

- `make worktree-setup`; `git fetch origin pull/76/head`, then checked out
  detached at 11ea222.
- `./scripts/godot --headless --path godot --import`, then
  `make test-godot-some SUITES="test/ai_llm"` once at baseline and once per
  GDScript plant.
- `python3 -m unittest discover -s python/tests -t python -p "test_llm*.py"`
  once per Python plant.
- `python3 scripts/check_readability.py` and
  `python3 scripts/check_llm_validated.py`: both exit 0.
- The converter source and the grammar README, read at
  `github.com/ggml-org/llama.cpp/blob/b11960/...`.
- The worktree was left clean (`git status --short` empty).

## What was done about them

All four were handled on the branch.

1. **Should-fix, applied.** `spec/llm/README.md` now says what the
   pattern asks for (R8 to R10's length, no control character, no markup),
   that only the secret is left to the validator alone, and that the
   pattern is stricter than the validator: no straight quote and no
   backslash, with the reason. It also says that `json_schema()` always
   adds the pattern, so a game cannot opt out until a second game needs
   to. Both `json_schema()` doc comments say "stricter than the validator"
   too.
2. **Should-fix, applied.** `docs/godot/talk.md` and the PR's decision 3
   now say 180 replies: the baseline and the prompt-line runs, the only
   two in which a quote could appear.
3. **Nit 1, applied.** The GDScript constant is now built as
   `"...{1,%d}$" % SPEECH_LIMIT`. A constant expression takes `%`, and the
   suite is green with it.
4. **Nit 2, applied.** The gdUnit pattern test gains a backslash, 280 and
   281 characters.

The three owner items are in the PR body. The raw probe outputs (owner
item 2, decision 7) are not committed; the PR recommends committing them
on the owner's word.
