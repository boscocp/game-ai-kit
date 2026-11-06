# Review: wave/141, T129 -- line separators are refused in a speech

T129, from T116's review: R9 refused C0 and DEL only, so a reply holding
U+2028, U+2029 or NEXT LINE (U+0085) passed the validator and broke the
line a game shows. The PR widens R9, in `LlmValidator` and in
`gameaikit.llm.validator`, to every Unicode control (Cc: C0, DEL, C1) and the
two separators. It widens `SPEECH_PATTERN` and `spec/llm/reply.schema.json`
by the same characters, adds seven vectors, a Python sweep over every code
point and a gdUnit sweep below U+3000, and a section in
`docs/local-llm/server.md` on how llama.cpp's converter reads the new class.

A fresh context reviewed PR #88 at head 0dc1551 against `origin/main`
18cfabe. It read the diff, the task, the PR body and T138's review record,
and ran narrow checks and planted changes in a throwaway worktree. It made no
commit, push or PR comment.

**Verdict: changes requested, no blocker.** The code is right and the size
of the change is right. Both validators and both patterns agree on every
code point, the vectors cite Unicode rather than the code, and every
planted leak went red. The two should-fix findings are both one defect:
the separators the PR meant to keep out of the files are in several of
them, as invisible bytes, where a reader was meant to see the escape
`\u2028`. One nit follows.

## What was reviewed

- The whole diff: `llm_validator.gd`, `validator.py`, `llm_test.gd`,
  `test_llm.py`, `test_llm_vectors.py`, `replies.json`,
  `reply.schema.json`, `spec/llm/README.md`, `docs/local-llm/server.md`,
  the task file and the STATUS row.
- The bytes of every changed file, searched for U+0080 to U+009F, U+2028
  and U+2029 written raw (`grep -P`, `cat -A`, `xxd`).
- Agreement, measured over every code point except the surrogates, in
  both languages. Python: the validator (`why_speech_is_wrong == ""`)
  against `re.fullmatch(SPEECH_PATTERN)`, and the committed schema's pattern
  against the code's. Godot 4.7.2: `LlmValidator` against
  `RegEx.create_from_string(SPEECH_PATTERN)`, from U+0001 to U+10FFFF (a
  throwaway script, removed). Both disagree only on `"` and `\`, the
  documented place where the pattern is stricter.
- Everything `str.splitlines()` treats as a line break (`\n \v \f \r`,
  U+001C to U+001E, U+0085, U+2028, U+2029): R9 refuses each one.
- The llama.cpp claim in `server.md` was checked for wording, not
  re-read in the source at `b11960`.

Checks, all exit 0: `python3 -m unittest discover -s python/tests -t python
-p "test_llm*.py"` (21 tests, OK); `make test-llm-vectors` (67 cases, 0
failures, both halves); `python3 scripts/check_llm_validated.py --self-test`
(ok); `make test-godot-some SUITES="test/ai_llm"` (48 cases, 0 failures, no
`SCRIPT ERROR`). That suite starts `fake_llm_server.py` through
`LlmLocalServer`. Afterwards `pgrep -af` for the fake, `server_ends` and
`llama-server` found nothing.

## Planted

Each was applied alone to the PR's head, run, then restored with `git
checkout` and `__pycache__` cleared.

| plant | caught by |
|---|---|
| Python R9 lets U+2029 through | Python: 3 failures (vectors, the Unicode sweep) |
| Python R9 lets U+0085 through | Python: 3 failures |
| GDScript R9 lets U+2029 through | Godot vectors runner, 1 failure; gdUnit `test_every_vector_case_gets_the_answer_it_claims` |
| GDScript R9 lets U+0085 through | the same two |
| `LINE_SEPARATORS` loses U+2029 in GDScript (R9 and the pattern) | the same two |
| Python pattern loses U+2029 | Python: 4 failures (schema equality, pattern sweeps) |
| GDScript pattern loses U+2029 | gdUnit `test_the_speech_in_the_schema_is_the_committed_one` |
| the schema alone loses U+2029 | Python schema equality, and the same gdUnit test |
| the schema alone lets U+0085 through | the same two |

None survived. The schema cannot drift alone: both languages compare it
to their own pattern.

## Findings

### 1. should-fix: the escape the docs name is an invisible character

`docs/local-llm/server.md:185`, `docs/local-llm/server.md:188` and
`spec/llm/README.md:29` (all new in this PR) each meant to write the
escape `\u2028` inside backticks. What the files hold is the separator
itself, bytes `e2 80 a8`. A reader sees "The model cannot write the escape
`` ` ` `` either", "not as `` ` ` ``", and "Godot's `RegEx` refuses a
`` ` ` `` in a pattern". The sentence that explains why the escape is not
used has lost the escape. The PR body has the same four holes (its "What
changed", the heading "Why characters and not", the converter section and
decision 1). It also says "no file has an invisible character in it",
which is true of the code files and not of the docs.

The same thing happened to this review's own shell commands and to this
record's first draft: a `\u2028` typed in a command or a file
arrived as the character. Whatever wrote these
lines probably did the same, so a check is worth more than care.

Fix: write `` `\u2028` `` in those three lines, and the same in the PR
body. Then run `grep -nP '[\x{2028}\x{2029}\x{80}-\x{9F}]'` over the
changed files and expect only the two vectors in finding 2, or none once
that is applied.

### 2. should-fix: two vectors hold the separator raw

`spec/vectors/llm/replies.json:319` and `:329` write U+2028 and U+2029 as
raw bytes inside the file. On screen, in the diff, on GitHub and in most
editors, the case reads `"Evening. Well?"` or `"Evening.Well?"`, so nothing
tells a reader what it tests. VS Code's default
(`editor.unusualLineTerminators: prompt`) offers to delete such characters
when the file is opened. If someone accepts, the case becomes an accepted
speech, the vector goes red, and the cause is invisible. The U+0085 case
at `:334` and the U+009F case are written the readable way: a file-level
`\u0085`, which `json.load` decodes, so `raw` still holds the character
itself. Its "why" still says "written as itself" and is true.

Fix: write the two the same way, `Evening.\u2028Well?` and
`Evening.\u2029Well?` with one backslash in the file. `raw` decodes to
the same string, so the cases test the same thing. The U+2028 case "as
JSON's escape" (`\\u2028`, two backslashes) is a different case and stays.

### 3. nit: the task's own Goal has the same hole

`tasks/T129-line-separators-are-refused-in-a-speech.md:24` ("reads
`` ` ` `` in a class as the character") is from 686da8c, before this wave,
and has the same raw U+2028. The PR already edits the file, so fixing it
costs one line.

## The owner's decisions

1. **Separators as characters in the pattern, not `\u2028`.** Agree. The
   measured refusals (Godot's PCRE2 refuses `\u`; Python's `re` refuses
   `\x{...}`) leave the character as the one spelling every reader takes
   the same way. The full-range sweeps above confirm it in both engines.
   The code files spell it with a language escape, so the cost is only in
   prose, which is findings 1 to 3.
2. **Format controls (Cf) still pass.** Agree, as a separate task. Zero-width
   characters and bidi overrides do not break a line, so they are not
   R9's job. They can still reorder or hide what a person reads, so the
   new task should decide between R9 and a new rule, with vectors.
3. **`HttpRuntime` cleans a refusal reason of C0 and DEL only.** Agree, as a
   small follow-up after the merge. Reusing R9's predicate keeps one
   definition of "breaks a line".
4. **`docs/techniques/ai_llm*.md` and `docs/godot/talk.md` keep "a line
   break or control character".** Agree. It is still true now that both
   words are wider, and T120 owns `docs/techniques/` in this batch.
5. **The converter read at `b11960`, not measured.** Agree. The section
   says so in its first paragraph ("Nothing was measured against a
   model") and cites both source files with a date. Measure it the next
   time the server is up for something else.

## What was done about them

All three were applied on the branch, in one commit. Every replacement was
written by a script that builds the backslash with `chr(92)`, and the bytes
were checked afterwards.

1. **Should-fix, applied.** `docs/local-llm/server.md:185` and `:188` and
   `spec/llm/README.md:29` now hold the six characters `\u2028` in
   backticks. The PR body's four places were fixed the same way.
2. **Should-fix, applied.** The U+2028 and U+2029 cases in
   `spec/vectors/llm/replies.json` are written as file-level JSON escapes,
   one backslash each, as the U+0085 case is. Loaded with `json.loads`
   before and after, the file decodes to the same cases, so `raw` still
   holds the character itself. `make test-llm-vectors` is still 67 cases,
   0 failures.
3. **Nit, applied.** `tasks/T129-line-separators-are-refused-in-a-speech.md:24`
   holds the escape too.

A search for raw U+0080 to U+009F, U+2028 and U+2029 over every file the
PR touches, the PR body and this record now finds nothing. The two
validator sources never held the character raw: they spell it with their
own language's escape, which the language decodes.

The owner's five decisions stand as the PR recommends them; the reviewer
agreed with each.
